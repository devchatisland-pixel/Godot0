extends SceneTree
## Renders a numbered contact sheet of the objects inside a model pack.
## Run: godot --rendering-driver opengl3 --resolution 2000x1400 --script res://tools/model_sheet.gd -- <pack.glb> <out.png> [start] [count]

const CELL := 2.4


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var start := int(a[2]) if a.size() > 2 else 0
	var count := int(a[3]) if a.size() > 3 else 48
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(a[0], state) != OK:
		push_error("cannot load " + a[0])
		quit(1)
		return
	var root: Node = doc.generate_scene(state)
	get_root().add_child(root)
	await process_frame # the tree is only ready after the first frame
	var groups := _groups(root)
	print("[Sheet] ", a[0].get_file(), ": ", groups.size(), " objects")
	var scene := Node3D.new()
	get_root().add_child(scene)
	var n := mini(count, groups.size() - start)
	var cols := ceili(sqrt(float(n) * 1.5))
	for k in n:
		var g: Node3D = groups[start + k]
		var box := _aabb(g)
		if box.size == Vector3.ZERO:
			continue
		var m := maxf(box.size.x, maxf(box.size.y, box.size.z))
		var s := 2.0 / m
		var pos := Vector3((k % cols) * CELL, 0, (k / cols) * CELL)
		var holder := Node3D.new()
		scene.add_child(holder)
		var old := g.global_transform
		g.get_parent().remove_child(g)
		holder.add_child(g)
		var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		g.global_transform = Transform3D(Basis.from_scale(Vector3(s, s, s)), pos - base * s) * old
		print("[Sheet] #%d %s  %.1f x %.1f x %.1f" % [start + k, g.name, box.size.x, box.size.y, box.size.z])
		var label := Label3D.new()
		label.text = "%d %s" % [start + k, String(g.name).substr(0, 14)]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.009
		label.no_depth_test = true
		label.modulate = Color.YELLOW
		label.outline_size = 12
		label.position = pos + Vector3(0.0, 0.05, 1.15)
		scene.add_child(label)
	var rows := ceili(float(n) / cols)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(cols, rows) * CELL * 0.85
	get_root().add_child(cam)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	var mid := Vector3(cols * CELL * 0.5, 0, rows * CELL * 0.5) - Vector3(CELL, 0, CELL) * 0.5
	cam.global_position = mid + cam.global_transform.basis.z * 100.0
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	get_root().add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.45, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	get_root().add_child(env)
	for i in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(a[1])
	quit()


## The objects of a pack: children of the first node that has several children.
func _groups(root: Node) -> Array[Node3D]:
	var n := root
	while n.get_child_count() == 1 and not (n.get_child(0) is MeshInstance3D):
		n = n.get_child(0)
	var out: Array[Node3D] = []
	for c in n.get_children():
		if c is Node3D:
			out.append(c)
	return out


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(n):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
