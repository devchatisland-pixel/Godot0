extends SceneTree
## Checks that the vehicles, the shops and the roadblock pieces are clickable: they are all
## registered with the BuildingPicker, and a tap on a shop selects it.
## Run: godot --headless --script res://tests/test_pick_props.gd

var _fails := 0


func _init() -> void:
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass

	var holder := Node3D.new()
	root.add_child(holder)
	var cam := IsoCamera.new()
	holder.add_child(cam)
	cam.current = true
	var roadblocks := Roadblocks.new()
	holder.add_child(roadblocks)
	roadblocks.build(data, lib)
	var vehicles := MapVehicles.new()
	holder.add_child(vehicles)
	vehicles.build(data, lib)
	var shops := MapShops.new()
	holder.add_child(shops)
	shops.build(data, lib)

	var picker := BuildingPicker.new()
	holder.add_child(picker)
	picker.setup(cam, data, lib)
	var nv := picker.add_props(vehicles)
	var ns := picker.add_props(shops)
	var nr := picker.add_props(roadblocks)
	var meshes := 0
	for n in [vehicles, shops, roadblocks]:
		for c in n.get_children():
			if c is MeshInstance3D:
				meshes += 1
	print("[Test] clickable: %d vehicles, %d shops, %d roadblock pieces (%d meshes)" % [nv, ns, nr, meshes])
	if nv + ns + nr != meshes:
		_fail("some meshes are not clickable")
	if nv == 0 or ns != MapShops.catalog().size() or nr == 0:
		_fail("missing clickable things")

	# Tap on the first shop, through the camera.
	var shop := shops.get_child(0) as MeshInstance3D
	var c := (shop.transform * shop.mesh.get_aabb()).get_center()
	cam.setup(cfg, data.size, c, 30.0)
	await process_frame
	await process_frame
	var screen := cam.unproject_position(c)
	picker._on_tap(screen)
	print("[Test] tap on %s -> selected_prop %d" % [shop.name, picker.selected_prop])
	if picker.selected_prop < 0:
		_fail("a tap on a shop selects nothing")
	else:
		var info: Dictionary = picker._props[picker.selected_prop]["info"]
		print("[Test] info: %s" % BuildingInfo.to_text(info))
		if not String(info["uid"]).begins_with("S-"):
			_fail("the tap selected %s, not the shop" % info["uid"])
	print("[Test] %s" % ("FAILED: %d" % _fails if _fails > 0 else "all pick checks passed"))
	quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: ", msg)
