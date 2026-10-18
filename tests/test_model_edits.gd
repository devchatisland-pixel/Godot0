extends SceneTree
## ModelEdits: no boat left, removed models flagged, replaced models share the mesh of their
## replacement, removed vehicles never planned.
##   godot --headless --path . --script res://tests/test_model_edits.gd

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _init() -> void:
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass

	var boats := 0
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.BOAT:
			boats += 1
	_check(boats == 0, "no boat left (%d)" % boats)

	for label in ModelEdits.REMOVED:
		var id := lib.names.find(label)
		_check(id >= 0 and lib.is_removed(id), "removed: " + label)
		_check(id >= 0 and lib.meshes[id].get_surface_count() == 0, "  data freed: " + label)

	var map := ModelEdits.replaced()
	for label in map:
		var id := lib.names.find(label)
		var target := lib.names.find(map[label])
		_check(id >= 0 and target >= 0 and lib.meshes[id] == lib.meshes[target] and not lib.is_removed(target),
				"replaced: %s -> %s" % [label, map[label]])

	var plan := VehicleSites.plan(data, MapVehicles.lengths_m())
	var bad := 0
	for p in plan:
		if ModelEdits.vehicle_removed(p["id"]):
			bad += 1
	_check(bad == 0, "no removed vehicle planned (%d of %d)" % [bad, plan.size()])
	for v in FogBaseSites.plan():
		if v.has("veh"):
			_check(not ModelEdits.vehicle_removed(v["veh"]), "fog base keeps no removed vehicle: " + v["veh"])
	for id in ModelEdits.REMOVED_VEHICLES:
		_check(not MapVehicles.entry(id).is_empty(), "catalog knows " + id)

	print("TEST %s" % ("FAILED" if _fails > 0 else "PASSED"))
	quit(1 if _fails > 0 else 0)
