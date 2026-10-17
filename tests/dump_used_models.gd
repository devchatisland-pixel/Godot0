extends SceneTree
## Which models of the library are really drawn: every chunk of the city is built (near and far, as
## the streamer does) and every part of the map the game sets up at start (fog island, continent,
## roadblocks, vehicles, shops, fences...); the meshes found are mapped back to the library models.
## Writes one line per library model: name, used (1/0), category, triangles, memory in MB (mesh + textures),
## bounding box (position x y z, size x y z).
##   godot --headless --path . --script res://tests/dump_used_models.gd -- <out.tsv>


func _init() -> void:
	var out := "user://used_models.tsv"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.lookahead = 0
	lib.skip_unused = false
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	PublicMeshes.build_all(lib)
	MilitaryMeshes.build_all(lib)
	NavLights.build_all(lib)
	FarmMeshes.build_all(lib)
	ParkMeshes.build_all(lib)
	var used := {}
	# Every chunk, near and far.
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			for far in [false, true]:
				var batch := InstanceBatch.new()
				for b in data.chunk_buildings[cy * side + cx]:
					BuildingPlacer.place(data, lib, b, batch, far)
				if not far:
					GroundPlacer.place_cells(data, lib, data.chunk_rect(cx, cy), batch)
				for id in batch.transforms:
					used[id] = true
	# The parts of the map set up once (as Main._start_city does).
	var holder := Node3D.new()
	root.add_child(holder)
	if data.fog != null:
		var fi := FogIsland.new()
		holder.add_child(fi)
		fi.build(cfg, data, lib)
		var fb := FogBase.new()
		holder.add_child(fb)
		fb.build(data, lib)
		for e in fb.picks:
			_mark_mesh(lib, e["mesh"], used)
	if data.continent != null:
		var co := Continent.new()
		holder.add_child(co)
		co.build(cfg, data, lib, null)
	for n in [WestBridge.new(), Roadblocks.new(), MapVehicles.new(), MapShops.new(), MapFences.new(),
			MapWoodFences.new(), MapClubCycles.new(), PrisonCompound.new()]:
		holder.add_child(n)
		n.build(data, lib)
	_scan(holder, lib, used)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_line("model\tused\tcategory\ttriangles\tmemory_mb\taabb\tsource")
	for id in lib.meshes.size():
		var name := lib.model_name(id)
		if name == "":
			continue
		var mesh := lib.meshes[id]
		var cat := lib.cats[id]
		var bb := lib.bounds[id]
		f.store_line("%s\t%d\t%s\t%d\t%.3f\t%.4f %.4f %.4f %.4f %.4f %.4f\t%s" % [name,
				int(used.has(id) or _shared_used(lib, id, used)),
				ModelCatalog.Cat.keys()[cat] if cat >= 0 else "", _triangles(mesh), _memory_mb(mesh),
				bb.position.x, bb.position.y, bb.position.z, bb.size.x, bb.size.y, bb.size.z, lib.sources.get(id, "")])
	f.close()
	print("[Used] %d of %d models drawn -> %s" % [used.size(), lib.meshes.size(), ProjectSettings.globalize_path(out)])
	quit(0)


## A model whose mesh is shared with a drawn one (two slots of the same model) counts as drawn.
func _shared_used(lib: ModelLibrary, id: int, used: Dictionary) -> bool:
	for u in used:
		if u is int and u >= 0 and u < lib.meshes.size() and lib.meshes[u] == lib.meshes[id]:
			return true
	return false


func _mark_mesh(lib: ModelLibrary, mesh: Mesh, used: Dictionary) -> void:
	if mesh == null:
		return
	for id in lib.meshes.size():
		if lib.meshes[id] == mesh:
			used[id] = true


func _scan(n: Node, lib: ModelLibrary, used: Dictionary) -> void:
	if n is MeshInstance3D:
		_mark_mesh(lib, (n as MeshInstance3D).mesh, used)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		_mark_mesh(lib, (n as MultiMeshInstance3D).multimesh.mesh, used)
	for c in n.get_children():
		_scan(c, lib, used)


static func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var t := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


## Vertices (position, normal, uv, tangent: 48 bytes), indices (4 bytes) and every texture of its
## materials (RGBA with mipmaps: x 4 x 1.33), textures counted once per model.
static func _memory_mb(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var bytes := 0.0
	var tex := {}
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		bytes += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 48.0
		if a[Mesh.ARRAY_INDEX] != null:
			bytes += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 4.0
		var mat := mesh.surface_get_material(s)
		if mat is BaseMaterial3D:
			for p in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_EMISSION, BaseMaterial3D.TEXTURE_NORMAL,
					BaseMaterial3D.TEXTURE_ORM, BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC]:
				var t := (mat as BaseMaterial3D).get_texture(p)
				if t != null and not tex.has(t):
					tex[t] = true
					bytes += t.get_width() * t.get_height() * 4.0 * 1.33
	return bytes / 1048576.0
