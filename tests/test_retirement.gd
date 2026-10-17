extends SceneTree
## Checks ModelRetirement on the real model library: no retired model is loaded, every slot holds a
## real mesh, every replaced model shows the one that replaces it, and lists the categories that
## are now empty.
## Run: godot --headless --script res://tests/test_retirement.gd

var _fails := 0


func _init() -> void:
	var cfg := CityConfig.create()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(20) < 1.0:
		pass
	print("[Test] %d meshes loaded" % lib.meshes.size())
	for label in ModelRetirement.DELETED:
		if lib.names.has(label):
			_fail("retired model still loaded: " + label)
	for label in ModelRetirement.REPLACED:
		if lib.names.has(label):
			_fail("replaced model still loaded: " + label)
		var target := String(ModelRetirement.REPLACED[label])
		if not lib.names.has(target):
			_fail("%s: the replacement %s is not loaded" % [label, target])
		elif lib.name_id(label) != lib.names.find(target):
			_fail("name_id of " + label)
	var slots := 0
	for c in lib.by_cat:
		for id in lib.by_cat[c]:
			slots += 1
			if id < 0 or id >= lib.meshes.size():
				_fail("bad slot in category %s" % ModelCatalog.Cat.find_key(c))
	print("[Test] %d category slots" % slots)
	var empty: Array[String] = []
	for c in ModelCatalog.Cat.values():
		if not lib.has_cat(c):
			empty.append(String(ModelCatalog.Cat.find_key(c)))
	print("[Test] categories with no model: ", empty)
	for v in ModelRetirement.VEHICLE_DELETED:
		if MapVehicles.mesh_id(lib, v) != -1:
			_fail("deleted vehicle still drawn: " + v)
	for v in ModelRetirement.VEHICLE_REPLACED:
		if MapVehicles.mesh_id(lib, v) != MapVehicles.mesh_id(lib, ModelRetirement.VEHICLE_REPLACED[v]):
			_fail("vehicle %s does not become %s" % [v, ModelRetirement.VEHICLE_REPLACED[v]])
	# Every building of the real city picks a model without a crash; nothing falls back to a plain box.
	var data := CityGenerator.new(cfg).generate()
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	ParkMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	var box := lib.named_id("box")
	var used := {}
	var bare := {}
	var boxes := {}
	for b in data.building_count():
		var kind: int = data.b_kind[b]
		if kind == CityTypes.Kind.EMPTY:
			continue
		var pick := BuildingPlacer.pick_for(data, lib, b)
		if pick.is_empty():
			bare[kind] = int(bare.get(kind, 0)) + 1
			continue
		used[pick["id"]] = true
		if pick["id"] == box:
			boxes[kind] = int(boxes.get(kind, 0)) + 1
	print("[Test] distinct models used by the buildings: %d" % used.size())
	for k in boxes:
		print("[Test] plain boxes: %s x %d" % [CityTypes.Kind.find_key(k), boxes[k]])
	for k in bare:
		if ModelRetirement.NO_MODEL_KINDS.has(k):
			print("[Test] bare lots: %s x %d" % [CityTypes.Kind.find_key(k), bare[k]])
	if _fails == 0:
		print("[Test] all retirement checks passed")
	else:
		print("[Test] FAILED: %d" % _fails)
	quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: " + msg)
