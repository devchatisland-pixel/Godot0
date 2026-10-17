extends SceneTree
## Renders one PNG per model name listed in a text file (one name per line), as the game draws it.
## Run: godot --rendering-driver opengl3 --resolution 320x320 --script res://tools/render_zone_models.gd -- <names.txt> <out_dir>
## File names: the model name with every character outside a-z 0-9 turned into "_" (see safe_name).


static func safe_name(model: String) -> String:
	var s := model.to_lower()
	var out := ""
	for c in s:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return out


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var wanted: PackedStringArray = FileAccess.get_file_as_string(a[0]).split("\n", false)
	var out_dir := a[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass

	FarmMeshes.build_all(lib)
	var scene := Node3D.new()
	get_root().add_child(scene)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.add_child(cam)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	scene.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.45, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	scene.add_child(env)
	var mi := MeshInstance3D.new()
	scene.add_child(mi)

	var done := 0
	var missing := []
	for line in wanted:
		var model := line.strip_edges()
		var id := lib.names.find(model)
		if id < 0:
			id = lib.named_id(model)
		if id < 0 and model.begins_with("shop:"):
			id = MapShops.mesh_id(lib, model.substr(5))
		if id < 0 and model.begins_with("veh:"):
			id = MapVehicles.mesh_id(lib, model.substr(4))
		if id < 0 or lib.meshes[id] == null:
			missing.append(model)
			continue
		mi.mesh = lib.meshes[id]
		var box := mi.mesh.get_aabb()
		var m := maxf(box.size.x, maxf(box.size.y, box.size.z))
		if m <= 0.0:
			missing.append(model)
			continue
		var s := 2.0 / m
		mi.transform = Transform3D(Basis.from_scale(Vector3(s, s, s)), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s)
		cam.size = 3.4
		cam.position = Vector3(0, 1.0, 0) + cam.global_transform.basis.z * 20.0
		for i in 3:
			await process_frame
		get_root().get_texture().get_image().save_png("%s/%s.png" % [out_dir, safe_name(model)])
		done += 1
	print("[Render] %d images, missing: %s" % [done, missing])
	quit()
