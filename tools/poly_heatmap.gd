extends SceneTree
## Triangle budget of the whole map, for the polygon heatmap.
## Run (needs a renderer, not --headless, to read MultiMesh transforms):
##   godot --path . --rendering-driver opengl3 --script res://tools/poly_heatmap.gd
## Writes user://poly_heatmap.json (path printed at the end):
##   width/height    grid size in cells (city map + fog island to the east)
##   cells           triangles per cell (row-major), near LOD, everything drawn
##   parcels         one entry per city building: rect, kind, model, triangles, instances
##   extras          totals of the nodes outside the city grid (fog island, bridges, roadblocks)
## Python then draws it: python3 tools/poly_heatmap.py

var _tris := {}


func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(10) < 1.0:
		pass
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	PublicMeshes.build_all(lib)
	MilitaryMeshes.build_all(lib)
	FarmMeshes.build_all(lib)

	var w := int(data.fog.origin.x) + FogIslandShaper.SIZE if data.fog != null else data.size
	var h := data.size
	var cells := PackedFloat32Array()
	cells.resize(w * h)

	# City buildings: everything a building places goes on its parcel.
	var parcels := []
	for i in data.building_count():
		var batch := InstanceBatch.new()
		BuildingPlacer.place(data, lib, i, batch, false)
		var tris := 0
		var inst := 0
		for id in batch.transforms:
			var n: int = batch.transforms[id].size() / 12
			tris += _mesh_tris(lib.meshes[id]) * n
			inst += n
		var r := data.building_rect(i)
		var per := float(tris) / float(maxi(1, r.get_area()))
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x < w and y < h:
					cells[y * w + x] += per
		var pk := BuildingPlacer.pick_for(data, lib, i)
		parcels.append({"id": i, "rect": [r.position.x, r.position.y, r.size.x, r.size.y],
				"kind": CityTypes.Kind.keys()[data.b_kind[i]],
				"model": lib.model_name(pk["id"]) if pk.has("id") else "",
				"tris": tris, "instances": inst})

	# Ground: roads, street lights, forests, palms... by the cell of each instance.
	var ground_tris := 0
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			var batch := InstanceBatch.new()
			GroundPlacer.place_cells(data, lib, data.chunk_rect(cx, cy), batch)
			for id in batch.transforms:
				var t := _mesh_tris(lib.meshes[id])
				var buf: PackedFloat32Array = batch.transforms[id]
				for k in range(0, buf.size(), 12):
					_add(cells, w, h, buf[k + 3], buf[k + 11], t)
					ground_tris += t

	# Nodes outside the grid logic: fog island, bridges, roadblocks.
	var extras := {}
	var fog := FogIsland.new()
	fog.build(cfg, data, lib)
	extras["fog_island"] = _walk(fog, cells, w, h)
	var wb := WestBridge.new()
	wb.build(data, lib)
	extras["west_bridge"] = _walk(wb, cells, w, h)
	var rb := Roadblocks.new()
	rb.build(data, lib)
	extras["roadblocks"] = _walk(rb, cells, w, h)
	extras["ground"] = ground_tris

	var out := {"width": w, "height": h, "city_size": data.size, "chunk": data.chunk_size,
			"cells": Array(cells), "parcels": parcels, "extras": extras,
			"water": Array(_water(data, w, h))}
	var f := FileAccess.open("user://poly_heatmap.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("written ", ProjectSettings.globalize_path("user://poly_heatmap.json"))
	quit()


## Land mask (1 land, 0 sea) of the city grid, for the background of the map.
func _water(data: CityData, w: int, h: int) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(w * h)
	for y in h:
		for x in mini(w, data.size):
			m[y * w + x] = 1 if data.is_land(x, y) else 0
	var fog := data.fog
	if fog != null:
		for y in FogIslandShaper.SIZE:
			for x in FogIslandShaper.SIZE:
				var gx := int(fog.origin.x) + x
				var gy := int(fog.origin.y) + y
				if gx >= 0 and gy >= 0 and gx < w and gy < h and fog.elevation[y * FogIslandShaper.SIZE + x] > 128:
					m[gy * w + gx] = 1
	return m


func _add(cells: PackedFloat32Array, w: int, h: int, x: float, z: float, t: int) -> void:
	var cx := floori(x)
	var cz := floori(z)
	if cx >= 0 and cz >= 0 and cx < w and cz < h:
		cells[cz * w + cx] += t


## Adds the triangles of every mesh under `node` over the cells its box covers.
func _walk(node: Node, cells: PackedFloat32Array, w: int, h: int) -> int:
	var total := 0
	for c in node.get_children():
		total += _walk(c, cells, w, h)
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = c.multimesh
			if mm == null or mm.mesh == null:
				continue
			var t := _mesh_tris(mm.mesh)
			var aabb := mm.mesh.get_aabb()
			var n := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			for k in n:
				_spread(cells, w, h, _xform(c) * mm.get_instance_transform(k) * aabb, t)
			total += t * n
		elif c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mesh := (c as MeshInstance3D).mesh
			var t := _mesh_tris(mesh)
			_spread(cells, w, h, _xform(c) * mesh.get_aabb(), t)
			total += t
	return total


## Shares `t` triangles between the cells under the box.
func _spread(cells: PackedFloat32Array, w: int, h: int, box: AABB, t: int) -> void:
	var x0 := clampi(floori(box.position.x), 0, w - 1)
	var z0 := clampi(floori(box.position.z), 0, h - 1)
	var x1 := clampi(floori(box.end.x), 0, w - 1)
	var z1 := clampi(floori(box.end.z), 0, h - 1)
	var per := float(t) / float((x1 - x0 + 1) * (z1 - z0 + 1))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			cells[z * w + x] += per


## Transform of `node` from its top Node3D (the tree is not running yet).
func _xform(node: Node) -> Transform3D:
	var t := Transform3D()
	var n := node
	while n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _mesh_tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var key := mesh.get_instance_id()
	if _tris.has(key):
		return _tris[key]
	var t := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			t += idx.size() / 3
		else:
			t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_tris[key] = t
	return t
