extends SceneTree
## MapChanges: the deleted buildings are gone, the stadium stands by the east highway with a street
## to it, the moved buildings are where they were sent, the towers use the radio tower model.
##   godot --headless --path . --script res://tests/test_map_changes.gd

const Kind := CityTypes.Kind

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _at(data: CityData, kind: int, cell: Vector2i) -> int:
	for b in data.building_count():
		if data.b_kind[b] == kind and data.building_rect(b).position == cell:
			return b
	return -1


func _count_in(data: CityData, kind: int, area: Rect2i) -> int:
	var n := 0
	for b in data.building_count():
		if data.b_kind[b] == kind and data.building_rect(b).intersects(area):
			n += 1
	return n


func _init() -> void:
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()

	for d in MapChanges.DELETED:
		_check(_at(data, Kind[d[0]], d[1]) < 0, "deleted: %s at %s" % [d[0], d[1]])

	# The stadium: beside the east highway (rows 190 to 192), reached by a street from it.
	var st := -1
	for b in data.building_count():
		if data.b_kind[b] == Kind.STADIUM:
			st = b
	_check(st >= 0, "one stadium")
	var r := data.building_rect(st)
	_check(r.position == MapChanges.STADIUM_AT and data.b_facing[st] == 0, "stadium at %s facing north" % r.position)
	var x := r.position.x + r.size.x / 2
	var street := true
	for y in range(MapChanges.STADIUM_ROAD_FROM_Y, r.position.y):
		street = street and data.road[data.idx(x, y)] == CityTypes.ROAD_STREET
	_check(street, "a street runs from the highway to the stadium")
	_check((data.road[data.idx(x, MapChanges.STADIUM_ROAD_FROM_Y - 1)] & 3) == CityTypes.ROAD_AVENUE, "the street starts on the highway")
	_check(_count_in(data, Kind.BALLOON, r) >= 1, "the balloon floats over the new stadium")

	# The main hospital stands in the old stadium block, the old place of the hospital is built on.
	var hosp := -1
	for b in data.building_count():
		if data.b_kind[b] == Kind.MAIN_HOSPITAL:
			hosp = b
	_check(hosp >= 0 and data.building_rect(hosp).position == Vector2i(155, 229), "main hospital in the old stadium block")
	_check(_count_in(data, Kind.MAIN_HOSPITAL, Rect2i(167, 195, 4, 5)) == 0, "nothing of the hospital left at 167,195")
	_check(_at(data, Kind.POLICE_HQ, Vector2i(233, 231)) >= 0, "police headquarters on the old gas station")
	_check(_at(data, Kind.UN_HQ, Vector2i(164, 116)) >= 0, "United Nations at 164,116")
	_check(_at(data, Kind.HOTEL, Vector2i(238, 306)) >= 0, "hotel on the red district lot")
	_check(_count_in(data, Kind.CHURCH, Rect2i(243, 214, 4, 5)) == 0, "no church at 243,214")
	_check(_count_in(data, Kind.SCHOOL, Rect2i(180, 156, 3, 3)) == 0, "no school at 180,156")

	var towers := 0
	for b in data.building_count():
		if data.b_kind[b] in [Kind.TELECOM_TOWER, Kind.BT_TOWER] and data.b_model.get(b, "") == MapChanges.RADIO_TOWER:
			towers += 1
	_check(towers == 2, "both old towers use the radio tower model (%d)" % towers)

	var plan := VehicleSites.plan(data, MapVehicles.lengths_m())
	var gone := true
	for p in plan:
		gone = gone and not ModelEdits.vehicle_removed_at(p["id"], p["at"])
	_check(gone, "no vehicle left at a removed place")

	print("TEST %s" % ("FAILED" if _fails > 0 else "PASSED"))
	quit(1 if _fails > 0 else 0)
