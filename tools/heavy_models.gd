extends SceneTree
## What every model drawn by the map costs, with a thumbnail of the heavy ones, for the
## performance sheets (tools/heavy_models.py draws them into docs/new_models/themes).
## Run (a renderer is needed): godot --rendering-driver opengl3 --script res://tools/heavy_models.gd -- <out dir>
## Writes <out>/heavy_models.json and <out>/thumbs/<id>.png.

const THUMB := 256
const PICK := 24


func _init() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://heavy"
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("thumbs"))
	var cfg := CityConfig.create()
	var data := CityBake.load_city(cfg)
	if data == null:
		data = CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(20) < 1.0:
		pass
	var nodes: Array[Node] = [MapVehicles.new(), MapShops.new(), Roadblocks.new()]
	for n in nodes:
		n.call("build", data, lib)
	var files := lib.meshes.size()
	preload("res://scripts/core/main.gd").build_procedural(lib)
	NightWindows.apply(lib)
	var fog := FogIsland.new()
	fog.build(cfg, data, lib)
	var bridge := WestBridge.new()
	bridge.build(data, lib)
	nodes.append(fog)
	nodes.append(bridge)

	# Uses of every mesh: the chunks (near) and the other nodes of the map.
	var uses := {}
	var side := data.chunks_per_side()
	for i in side * side:
		var batch := InstanceBatch.new()
		for id in data.chunk_buildings[i]:
			BuildingPlacer.place(data, lib, id, batch, false)
		GroundPlacer.place_cells(data, lib, data.chunk_rect(i % side, i / side), batch)
		for id in batch.transforms:
			uses[id] = uses.get(id, 0) + batch.transforms[id].size() / 12
	var ids := {}
	for i in lib.meshes.size():
		ids[lib.meshes[i]] = i
	for n in nodes:
		_count(n, ids, uses)

	var rows := []
	for id in uses:
		if int(id) >= files:
			continue   # procedural meshes: made in code, light
		var mesh: Mesh = lib.meshes[id]
		var tex := _textures(mesh)
		var px := 0
		for t: Texture2D in tex:
			px += t.get_width() * t.get_height()
		rows.append({"id": id, "name": lib.model_name(id), "tris": _tris(mesh), "uses": uses[id],
				"tex_px": px, "tex": tex.map(func(t: Texture2D) -> String: return "%s %dx%d" % [t.resource_path.get_file(), t.get_width(), t.get_height()])})
	for r in rows:
		r["total"] = int(r["tris"]) * int(r["uses"])
	# The heavy ones: most triangles drawn, heaviest models, biggest textures.
	var chosen := {}
	for key in ["total", "tris", "tex_px"]:
		rows.sort_custom(func(a, b) -> bool: return a[key] > b[key])
		for r in rows.slice(0, PICK):
			chosen[r["id"]] = true
	await process_frame
	for id in chosen:
		await _thumb(lib.meshes[id], out_dir.path_join("thumbs/%d.png" % id))
	var f := FileAccess.open(out_dir.path_join("heavy_models.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"models": rows, "pictured": chosen.keys()}, "\t"))
	f.close()
	print("[Heavy] %d models measured, %d pictured, written to %s" % [rows.size(), chosen.size(), out_dir])
	quit()


func _count(node: Node, ids: Dictionary, uses: Dictionary) -> void:
	if node is MeshInstance3D and ids.has((node as MeshInstance3D).mesh):
		var id: int = ids[(node as MeshInstance3D).mesh]
		uses[id] = uses.get(id, 0) + 1
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		var mm := (node as MultiMeshInstance3D).multimesh
		if ids.has(mm.mesh):
			uses[ids[mm.mesh]] = uses.get(ids[mm.mesh], 0) + mm.instance_count
	for c in node.get_children():
		_count(c, ids, uses)


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _textures(mesh: Mesh) -> Array:
	var out := []
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m is BaseMaterial3D:
			for t in [m.albedo_texture, m.normal_texture, m.emission_texture, m.roughness_texture, m.metallic_texture, m.ao_texture]:
				if t != null and not out.has(t):
					out.append(t)
	return out


## Renders `mesh` seen from the map's camera angle on a light background.
func _thumb(mesh: Mesh, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(THUMB, THUMB)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("eef1f5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.95)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 22, 0)
	vp.add_child(sun)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	vp.add_child(mi)
	var box := mesh.get_aabb()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.size = maxf(box.size.length(), 0.01) * 1.05
	cam.position = box.get_center() + cam.transform.basis.z * (box.size.length() * 4.0 + 10.0)
	cam.far = box.size.length() * 10.0 + 100.0
	vp.add_child(cam)
	cam.current = true
	get_root().add_child(vp)
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png(path)
	vp.queue_free()
