extends SceneTree
## Bakes what the game would otherwise build at every start, into res://baked/:
##   city.bin    the generated city (CityBake) with the plans of its vehicles and props;
##   models.res  the model library with every model file loaded and merged (BakedModels),
##               the vehicles, shops and props of the map included; the meshes the map never
##               draws are saved empty;
##   chunks.bin  what every chunk draws, near and far (ChunkBake).
## Run once the project is imported (a renderer is needed to merge the meshes):
##   godot --path . --rendering-driver opengl3 --script res://tools/bake.gd [-- --patch-export]
## With --patch-export, the model files and textures the baked library does not need are added
## to the exclude filter of the web presets (export_presets.cfg), so they are not exported.
## docker/Dockerfile runs it before the web export: a build always bakes the current code.

## Folders of model files and their textures (what is not needed there is not exported).
const MODEL_DIRS := ["res://FREEMODELS", "res://vehicles", "res://shops/models", "res://props"]
const PRESETS := "res://export_presets.cfg"


func _init() -> void:
	var cfg := CityConfig.create()
	var t0 := Time.get_ticks_msec()
	var data := CityGenerator.new(cfg).generate()
	var err := CityBake.save(data, cfg)
	if err != OK:
		_fail("cannot write %s: %s" % [CityBake.PATH, error_string(err)])
		return
	print("[Bake] city: generated and planned in %d ms, %d KB written to %s" % [Time.get_ticks_msec() - t0,
			FileAccess.get_file_as_bytes(CityBake.PATH).size() / 1024, CityBake.PATH])

	# Every model file, then the models loaded by name when the map is built.
	var t1 := Time.get_ticks_msec()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(20) < 1.0:
		pass
	var nodes: Array[Node] = [MapVehicles.new(), MapShops.new(), Roadblocks.new()]
	for node in nodes:
		node.call("build", data, lib)
	var files := lib.meshes.size()
	# The procedural meshes, as at start; then every chunk and every other part of the map is
	# built once, and the meshes they use are listed.
	preload("res://scripts/core/main.gd").build_procedural(lib)
	var used := _used_meshes(data, lib, cfg, nodes)
	for node in nodes:
		node.free()
	var kb := _lighten(lib, files, used)
	print("[Bake] models: vertex data of the drawn models %d KB -> %d KB" % [kb.x, kb.y])
	err = lib.save_bake(cfg, files, used)
	if err != OK:
		_fail("cannot write %s: %s" % [ModelLibrary.BAKE_PATH, error_string(err)])
		return
	var drawn := 0
	for id in used:
		if int(id) < files:
			drawn += 1
	print("[Bake] models: %d meshes of model files loaded in %d ms (%d drawn by the map), %d procedural, %d KB written to %s" % [
			files, Time.get_ticks_msec() - t1, drawn, lib.meshes.size() - files,
			FileAccess.get_file_as_bytes(ModelLibrary.BAKE_PATH).size() / 1024, ModelLibrary.BAKE_PATH])

	# Read back, to be sure the game can.
	var t2 := Time.get_ticks_msec()
	var back := CityBake.load_city(cfg)
	if back == null or MapAudit.data_hash(back) != MapAudit.data_hash(data):
		_fail("the baked city does not read back the same")
		return
	var check := ModelLibrary.new()
	var res := ResourceLoader.load(ModelLibrary.BAKE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BakedModels
	if not check.use_bake(res, cfg):
		_fail("the baked models do not read back")
		return
	print("[Bake] read back in %d ms: same city (hash), %d meshes" % [Time.get_ticks_msec() - t2, check.meshes.size()])

	# What every chunk draws, with the library as the game has it once started (the night
	# lights add the halos of the signs); after the save above, so the library file keeps the
	# materials as they were.
	var t3 := Time.get_ticks_msec()
	NightWindows.apply(lib)
	err = ChunkBake.save(data, lib)
	if err != OK:
		_fail("cannot write %s: %s" % [ChunkBake.PATH, error_string(err)])
		return
	print("[Bake] chunks: placed in %d ms, %d KB written to %s" % [Time.get_ticks_msec() - t3,
			FileAccess.get_file_as_bytes(ChunkBake.PATH).size() / 1024, ChunkBake.PATH])

	if "--patch-export" in OS.get_cmdline_user_args():
		_patch_export()
	quit()


## Lighter models for the game: the surfaces of the models of files the map draws keep their
## positions, normals, colours, UVs and indices, compressed (Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES,
## as the importer does), without tangents, second UVs or bones; their materials lose the
## normal, roughness, metallic and occlusion maps (nothing of it shows at the scale of the map,
## the curated packs have none), so these textures are not loaded either. Returns the vertex
## data before and after, in KB.
func _lighten(lib: ModelLibrary, files: int, used: Dictionary) -> Vector2i:
	var before := 0
	var after := 0
	var mats := {}
	for id in used:
		if int(id) >= files or not lib.meshes[id] is ArrayMesh:
			continue
		var mesh: ArrayMesh = lib.meshes[id]
		var out := ArrayMesh.new()
		for s in mesh.get_surface_count():
			before += _vertex_bytes(mesh.surface_get_arrays(s), false)
			var arrays := mesh.surface_get_arrays(s)
			for a in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS,
					Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[a] = null
			# The compressed layout packs the normal with the position: only with normals.
			var flags := Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if arrays[Mesh.ARRAY_NORMAL] != null else 0
			out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, flags)
			out.surface_set_material(out.get_surface_count() - 1, _light_material(mesh.surface_get_material(s), mats))
			after += _vertex_bytes(arrays, true)
		lib.meshes[id] = out
	return Vector2i(before / 1024, after / 1024)


## Bytes of the vertex arrays of a surface (estimate: floats, or the compressed layout).
func _vertex_bytes(arrays: Array, compressed: bool) -> int:
	var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per := 0
	per += 8 if compressed else 12
	if arrays[Mesh.ARRAY_NORMAL] != null:
		per += 4 if compressed else 12
	if arrays[Mesh.ARRAY_TANGENT] != null:
		per += 16
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		per += 4 if compressed else 8
	if arrays[Mesh.ARRAY_TEX_UV2] != null:
		per += 8
	if arrays[Mesh.ARRAY_COLOR] != null:
		per += 4 if compressed else 16
	var idx = arrays[Mesh.ARRAY_INDEX]
	return n * per + (idx.size() * 4 if idx != null else 0)


func _light_material(mat: Material, done: Dictionary) -> Material:
	if not mat is BaseMaterial3D:
		return mat
	if done.has(mat):
		return done[mat]
	var m: BaseMaterial3D = mat.duplicate()
	m.normal_enabled = false
	m.normal_texture = null
	m.roughness_texture = null
	m.metallic_texture = null
	m.ao_enabled = false
	m.ao_texture = null
	m.heightmap_enabled = false
	m.heightmap_texture = null
	m.clearcoat_enabled = false
	m.rim_enabled = false
	m.anisotropy_enabled = false
	m.subsurf_scatter_enabled = false
	m.refraction_enabled = false
	m.detail_enabled = false
	done[mat] = m
	return m


## Mesh ids drawn by the chunks (near and far), the fog island, the bridges and the nodes
## already built (vehicles, shops, roadblocks): {id: true}.
func _used_meshes(data: CityData, lib: ModelLibrary, cfg: CityConfig, built: Array[Node]) -> Dictionary:
	var used := {}
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			for far in [false, true]:
				var batch := InstanceBatch.new()
				for id in data.chunk_buildings[cy * side + cx]:
					BuildingPlacer.place(data, lib, id, batch, far)
				if not far:
					GroundPlacer.place_cells(data, lib, data.chunk_rect(cx, cy), batch)
				for id in batch.transforms:
					used[int(id)] = true
	var extra: Array[Node] = built.duplicate()
	var fog := FogIsland.new()
	fog.build(cfg, data, lib)
	var bridge := WestBridge.new()
	bridge.build(data, lib)
	extra.append(fog)
	extra.append(bridge)
	var ids := {}
	for i in lib.meshes.size():
		ids[lib.meshes[i]] = i
	for node in extra:
		_collect(node, ids, used)
	fog.free()
	bridge.free()
	return used


func _collect(node: Node, ids: Dictionary, used: Dictionary) -> void:
	var mesh: Mesh = null
	if node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
	if mesh != null and ids.has(mesh):
		used[ids[mesh]] = true
	for c in node.get_children():
		_collect(c, ids, used)


# --- What the web export leaves out -----------------------------------------------------------
## Adds to the exclude filter of every preset the imported files of MODEL_DIRS that the baked
## library does not depend on: model files (their meshes are in the library) and the textures
## of models the map does not draw.
func _patch_export() -> void:
	var needed := {}
	for dep in ResourceLoader.get_dependencies(ModelLibrary.BAKE_PATH):
		needed[String(dep).get_slice("::", 2) if String(dep).contains("::") else String(dep)] = true
	var drop: PackedStringArray = []
	for dir in MODEL_DIRS:
		_unneeded(dir, needed, drop)
	var text := FileAccess.get_file_as_string(PRESETS)
	var lines := text.split("\n")
	for i in lines.size():
		if lines[i].begins_with("exclude_filter=\""):
			var old := lines[i].trim_prefix("exclude_filter=\"").trim_suffix("\"")
			lines[i] = "exclude_filter=\"%s\"" % ", ".join(PackedStringArray([old]) + drop)
	var f := FileAccess.open(PRESETS, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("[Bake] export: %d model files and textures left out (%d files needed by the baked models)" % [
			drop.size(), needed.size()])


func _unneeded(dir: String, needed: Dictionary, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null or FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for sub in d.get_directories():
		_unneeded(dir.path_join(sub), needed, out)
	for file in d.get_files():
		if not file.ends_with(".import"):
			continue
		var path := dir.path_join(file.trim_suffix(".import"))
		if not needed.has(path):
			out.append(path.trim_prefix("res://"))


func _fail(text: String) -> void:
	push_error("[Bake] " + text)
	quit(1)
