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

	# Second wave.
	for c in MapChanges.SKYLINE_DELETED:
		_check(_at(data, Kind.SKYLINE_BLDG, c) < 0, "skyline tower deleted at %s" % c)
	var logo := _at(data, Kind.SKYLINE_BLDG, MapChanges.LOGO_TOWER)
	_check(logo >= 0 and data.b_sign[logo] == ModelCatalog.Cat.SIGN_WINDOWS, "Windows logo on the tower at 58,137")
	var from := _at(data, Kind.SKYLINE_BLDG, MapChanges.ROOF_NEON_FROM)
	var to := _at(data, Kind.SKYLINE_BLDG, MapChanges.ROOF_NEON_TO)
	_check(from >= 0 and to >= 0 and not data.b_more_signs.has(from) and data.b_more_signs.has(to), "roof neon moved")
	var pac := _at(data, Kind.SKYLINE_BLDG, MapChanges.PACMAN_TOWER)
	_check(pac >= 0 and data.b_sign[pac] == ModelCatalog.Cat.NEON_PACMAN, "pacman neon")
	var eiffel := _at(data, Kind.CASINO, MapChanges.EIFFEL_AT)
	_check(eiffel >= 0 and data.b_model.get(eiffel, "") == MapChanges.EIFFEL_MODEL, "Eiffel tower on the office lot")
	_check(data.zone_at(MapChanges.EIFFEL_AT.x, MapChanges.EIFFEL_AT.y) == CityTypes.Zone.PARK, "grass under the Eiffel tower")
	_check(_at(data, Kind.INDUSTRIAL, MapChanges.CRANE_AT) < 0, "original crane deleted")
	_check(_count_in(data, Kind.INDUSTRIAL, Rect2i(125, 257, 4, 7)) == 3, "three big tanks where the power plant was")
	_check(_at(data, Kind.DRIVE_IN, MapChanges.DRIVE_IN_LOT.position) >= 0, "drive-in moved north of the quarter")
	_check(data.road[data.idx(MapChanges.DRIVE_IN_ROAD_X, MapChanges.DRIVE_IN_ROAD_TO_Y - 1)] != 0, "street to the drive-in")
	_check(_at(data, Kind.FERRIS_WHEEL, MapChanges.WHEEL_LOT.position) >= 0, "Ferris wheel moved")
	var hotel := _at(data, Kind.HOTEL, MapChanges.HOTEL_EAST)
	_check(hotel >= 0 and data.b_facing[hotel] == 1, "hotel looks east")
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass
	for m in [MapChanges.EIFFEL_MODEL, MapChanges.QUARTER_MODEL, MapChanges.FACTORY_MODEL, MapChanges.BIG_TANK_MODEL,
			MapChanges.CRANE_MODEL, "port_tanks.glb: tank_oil", MapChanges.RADIO_TOWER, MapChanges.NY_TIMES]:
		_check(lib.names.find(m) >= 0, "library has " + m)

	print("TEST %s" % ("FAILED" if _fails > 0 else "PASSED"))
	quit(1 if _fails > 0 else 0)
