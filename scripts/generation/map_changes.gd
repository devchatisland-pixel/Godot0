class_name MapChanges
extends RefCounted
## Hand changes asked on the finished map (after the budget, the overhaul and every other pass).
## A building is named by its kind and the top-left cell of its lot, as ManualEdits does, so the
## edits do not depend on the building numbers (the numbers in the comments are those of the map
## when the changes were asked). Run once, last of the building edits.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

## Buildings taken away: kind and top-left cell of the lot. The lots stay empty.
const DELETED := [
	["HOSPITAL", Vector2i(163, 218)],         # B-00830 clinic
	["GAS_STATION", Vector2i(198, 218)],      # B-00796
	["QUARTER_BLDG", Vector2i(198, 223)],     # B-00534
	["QUARTER_BLDG", Vector2i(188, 247)],     # B-00515
	["MAIN_HOSPITAL", Vector2i(243, 201)],    # B-00831 (its ambulance goes with it)
	["POLICE", Vector2i(237, 213)],           # B-00823 (and its neon)
	["MCDONALDS", Vector2i(160, 106)],        # B-01056
	["POLICE", Vector2i(195, 236)],           # B-00824
	["CEMETERY", Vector2i(150, 255)],         # B-01256
	# The island of the BT tower: the ruin, the halls and the yards round it.
	["INDUSTRIAL", Vector2i(44, 88)], ["INDUSTRIAL", Vector2i(39, 90)],
	["INDUSTRIAL", Vector2i(27, 96)], ["INDUSTRIAL", Vector2i(24, 91)],
	["INDUSTRIAL_YARD", Vector2i(30, 86)], ["INDUSTRIAL_YARD", Vector2i(25, 88)],
	["INDUSTRIAL_YARD", Vector2i(25, 86)], ["INDUSTRIAL_YARD", Vector2i(35, 86)],
	# The billboard of the prison island (the jail is walled by PrisonCompound, no fence).
	["BILLBOARD", Vector2i(47, 47)],          # B-01273
]

## Landmark towers and skyscrapers downtown that are all drawn as the New York Times building
## (B-00817 stays as it is).
const NY_TIMES := "ny_buildings.glb: ny_times"
const TO_NY_TIMES := [
	["LANDMARK", Vector2i(167, 160)], ["LANDMARK", Vector2i(163, 155)],
	["SKYSCRAPER", Vector2i(158, 151)], ["SKYSCRAPER", Vector2i(163, 165)],
	["LANDMARK", Vector2i(163, 169)], ["LANDMARK", Vector2i(155, 155)],
	["SKYSCRAPER", Vector2i(159, 158)], ["SKYSCRAPER", Vector2i(143, 174)],
]

## The radio tower model of the port replaces the two old procedural towers (the radio tower of the
## city and the BT tower), at the same size; a red light on the first, a green one on the second.
const RADIO_TOWER := "port_towers.glb: tower_radio"
const RADIO_TOWER_SCALE := 1.4
const TOWERS := [["TELECOM_TOWER", Vector2i(104, 184)], ["BT_TOWER", Vector2i(32, 89)]]

## Kinds the free spots are filled with ("the nearest same buildings").
const REGULAR: Array[int] = [Kind.HOUSE, Kind.APARTMENT, Kind.SHOP, Kind.OFFICE, Kind.POOR_BLDG,
		Kind.QUARTER_BLDG]
const HOUSES: Array[int] = [Kind.HOUSE]

## The stadium moves beside the east highway (rows 190 to 192 reach the east coast): a free
## square of land south of it, reached by a new street from the highway.
const STADIUM_AT := Vector2i(262, 199)
const STADIUM_SIZE := Vector2i(11, 9)
const STADIUM_ROAD_FROM_Y := 193

## The main hospital takes the south-west corner of the old stadium block.
const HOSPITAL_SIZE := Vector2i(4, 5)


static func apply(data: CityData) -> Dictionary:
	var report := {}
	report["deleted"] = _delete_all(data)
	report["towers"] = _radio_towers(data)
	report["ny_times"] = _ny_times(data)
	report["stadium"] = _move_stadium_and_hospital(data)
	report["police_hq"] = _move_police_hq(data)
	report["un_hq"] = _move_un_hq(data)
	report["hotel"] = _move_hotel(data)
	report["church"] = _replace_by_neighbours(data, "CHURCH", Vector2i(243, 214), HOUSES)
	report["school"] = _replace_by_neighbours(data, "SCHOOL", Vector2i(180, 156), REGULAR)
	report["jail"] = _clear_jail_ground(data)
	report["second"] = _second_wave(data)
	return report


# --- Deleting -----------------------------------------------------------------------------

static func _delete_all(data: CityData) -> int:
	var n := 0
	for d in DELETED:
		var b := _find(data, d[0], d[1])
		if b >= 0:
			_clear(data, b)
			n += 1
	return n


## The building of `kind_name` whose lot starts at `cell`, or -1 (with a warning).
static func _find(data: CityData, kind_name: String, cell: Vector2i) -> int:
	var kind: int = Kind[kind_name]
	for b in data.building_count():
		if data.b_kind[b] == kind and data.building_rect(b).position == cell:
			return b
	push_warning("[MapChanges] no %s at %s" % [kind_name, cell])
	return -1


static func _clear(data: CityData, b: int) -> void:
	data.b_kind[b] = Kind.EMPTY
	data.b_sign[b] = 0
	data.b_more_signs.erase(b)
	data.b_model.erase(b)


# --- Models -------------------------------------------------------------------------------

static func _radio_towers(data: CityData) -> int:
	var n := 0
	for t in TOWERS:
		var b := _find(data, t[0], t[1])
		if b >= 0:
			data.b_model[b] = RADIO_TOWER
			data.b_scale[b] = RADIO_TOWER_SCALE
			n += 1
	return n


static func _ny_times(data: CityData) -> int:
	var n := 0
	for t in TO_NY_TIMES:
		var b := _find(data, t[0], t[1])
		if b >= 0:
			data.b_kind[b] = Kind.LANDMARK
			data.b_model[b] = NY_TIMES
			n += 1
	return n


# --- Moving a building --------------------------------------------------------------------

## Building `b` takes the place `dest`: every other building that stands there is taken away, the
## ground of the place becomes civic land without trees and the building turns to the street
## (to the side `prefer` when a street touches it).
## Returns the place it left.
static func _relocate(data: CityData, b: int, dest: Rect2i, prefer: int = -1) -> Rect2i:
	var old := data.building_rect(b)
	for o in data.building_count():
		if o != b and data.b_kind[o] != Kind.EMPTY and data.building_rect(o).intersects(dest):
			_clear(data, o)
	data.set_building_rect(b, dest)
	for y in range(dest.position.y, dest.end.y):
		for x in range(dest.position.x, dest.end.x):
			data.zone[data.idx(x, y)] = Zone.CIVIC
			data.forest[data.idx(x, y)] = 0
	data.b_facing[b] = _front(data, dest, data.b_facing[b] if prefer < 0 else prefer)
	data.b_sign_facing[b] = data.b_facing[b]
	return old


static func _move_stadium_and_hospital(data: CityData) -> Dictionary:
	var st := _find_any(data, Kind.STADIUM)
	var hosp := _find(data, "MAIN_HOSPITAL", Vector2i(167, 195))
	if st < 0 or hosp < 0:
		return {}
	var old := data.building_rect(st)
	var site := Rect2i(STADIUM_AT, STADIUM_SIZE)
	_clear_trees(data, site.grow(1))
	_relocate(data, st, site)
	# The balloon over the stadium follows it.
	for b in data.building_count():
		if data.b_kind[b] == Kind.BALLOON and old.has_point(data.building_rect(b).get_center()):
			data.set_building_rect(b, Rect2i(site.get_center() - Vector2i(1, 1), Vector2i(3, 3)))
	data.b_facing[st] = 0
	data.b_sign_facing[st] = 0
	# The new street from the highway to the front of the stadium.
	var x := site.position.x + site.size.x / 2
	var road := 0
	for y in range(STADIUM_ROAD_FROM_Y, site.position.y):
		var i := data.idx(x, y)
		data.road[i] = CityTypes.ROAD_STREET
		data.forest[i] = 0
		data.rocky[i] = 0
		road += 1
	# The old place: the main hospital in its south-west corner, the rest of the block filled with
	# the buildings round it; the old place of the hospital is filled as well.
	var spot := Rect2i(old.position.x, old.end.y - HOSPITAL_SIZE.y, HOSPITAL_SIZE.x, HOSPITAL_SIZE.y)
	var hosp_old := _relocate(data, hosp, spot)
	var filled := _fill(data, Rect2i(old.position, Vector2i(old.size.x, old.size.y - HOSPITAL_SIZE.y)))
	filled += _fill(data, Rect2i(spot.end.x, spot.position.y, old.end.x - spot.end.x, spot.size.y))
	filled += _fill(data, hosp_old)
	return {"road_cells": road, "filled": filled}


static func _move_police_hq(data: CityData) -> int:
	var hq := _find(data, "POLICE_HQ", Vector2i(167, 210))
	var gas := _find(data, "GAS_STATION", Vector2i(233, 231))
	if hq < 0 or gas < 0:
		return 0
	var dest := data.building_rect(gas)
	return _fill(data, _relocate(data, hq, dest))


## The United Nations take the four lots of the poor district block where the shop stood.
static func _move_un_hq(data: CityData) -> int:
	var un := _find(data, "UN_HQ", Vector2i(213, 176))
	var shop := _find(data, "SHOP", Vector2i(167, 119))
	if un < 0 or shop < 0:
		return 0
	var size := data.building_rect(un).size
	return _fill(data, _relocate(data, un, Rect2i(Vector2i(164, 116), size), 1))


## The hotel replaces the red district building; what it leaves of the lot, and its old place, are filled.
static func _move_hotel(data: CityData) -> int:
	var hotel := _find(data, "HOTEL", Vector2i(213, 234))
	var quarter := _find(data, "QUARTER_BLDG", Vector2i(238, 306))
	if hotel < 0 or quarter < 0:
		return 0
	var lot := data.building_rect(quarter)
	var size := data.building_rect(hotel).size
	var spot := Rect2i(lot.position, Vector2i(mini(size.x, lot.size.x), mini(size.y, lot.size.y)))
	_clear(data, quarter)
	var old := _relocate(data, hotel, spot)
	var n := _fill(data, old)
	if lot.size.y > spot.size.y:
		n += _fill(data, Rect2i(lot.position.x, spot.end.y, lot.size.x, lot.end.y - spot.end.y))
	return n


static func _replace_by_neighbours(data: CityData, kind_name: String, cell: Vector2i, kinds: Array[int]) -> int:
	var b := _find(data, kind_name, cell)
	if b < 0:
		return 0
	var r := data.building_rect(b)
	_clear(data, b)
	return _fill(data, r, kinds)


static func _find_any(data: CityData, kind: int) -> int:
	for b in data.building_count():
		if data.b_kind[b] == kind:
			return b
	return -1


# --- Filling a free place -----------------------------------------------------------------

## Fills `area` with lots like the nearest buildings of `kinds`: the lots are cut like the nearest
## one and take the kind, the model, the size factor and the ground of the three nearest in turn.
## Returns how many lots were made.
static func _fill(data: CityData, area: Rect2i, kinds: Array[int] = REGULAR) -> int:
	if area.size.x <= 0 or area.size.y <= 0:
		return 0
	var templates := _nearest(data, area, kinds, 3)
	if templates.is_empty():
		return 0
	var t0 := data.building_rect(templates[0])
	var cols := maxi(1, roundi(float(area.size.x) / t0.size.x))
	var rows := maxi(1, roundi(float(area.size.y) / t0.size.y))
	var n := 0
	for ry in rows:
		var y0 := area.position.y + area.size.y * ry / rows
		var y1 := area.position.y + area.size.y * (ry + 1) / rows
		for cx in cols:
			var x0 := area.position.x + area.size.x * cx / cols
			var x1 := area.position.x + area.size.x * (cx + 1) / cols
			var t: int = templates[n % templates.size()]
			_stamp(data, Rect2i(x0, y0, x1 - x0, y1 - y0), t)
			n += 1
	return n


## The `count` nearest buildings of `kinds` to the middle of `area` (not inside it).
static func _nearest(data: CityData, area: Rect2i, kinds: Array[int], count: int) -> Array[int]:
	var mid := Vector2(area.position) + Vector2(area.size) * 0.5
	var found: Array = []
	for b in data.building_count():
		if not kinds.has(data.b_kind[b]):
			continue
		var r := data.building_rect(b)
		if r.intersects(area) or r.get_area() < 4:
			continue
		found.append([(Vector2(r.position) + Vector2(r.size) * 0.5).distance_to(mid), b])
	found.sort_custom(func(a, c): return a[0] < c[0])
	var out: Array[int] = []
	for i in mini(count, found.size()):
		out.append(found[i][1])
	return out


## A new lot `lot` like building `t`.
static func _stamp(data: CityData, lot: Rect2i, t: int) -> void:
	var facing := _front(data, lot, data.b_facing[t])
	var seed := CityTypes.hash2(lot.position.x, lot.position.y, data.b_seed[t])
	var b := data.add_building(lot, data.b_kind[t], facing, seed, data.b_height[t])
	data.b_scale[b] = data.b_scale[t]
	if data.b_model.has(t):
		data.b_model[b] = data.b_model[t]
	var zone := data.zone_at(data.building_rect(t).position.x, data.building_rect(t).position.y)
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			data.zone[data.idx(x, y)] = zone
			data.forest[data.idx(x, y)] = 0


## The side of `lot` that looks at a street: `prefer` when a road touches it, else the first side
## that has one.
static func _front(data: CityData, lot: Rect2i, prefer: int) -> int:
	for k in 4:
		var f := (prefer + k) % 4
		if _road_on_side(data, lot, f):
			return f
	return prefer


static func _road_on_side(data: CityData, lot: Rect2i, side: int) -> bool:
	match side:
		0:
			for x in range(lot.position.x, lot.end.x):
				if data.is_road(x, lot.position.y - 1):
					return true
		1:
			for y in range(lot.position.y, lot.end.y):
				if data.is_road(lot.end.x, y):
					return true
		2:
			for x in range(lot.position.x, lot.end.x):
				if data.is_road(x, lot.end.y):
					return true
		_:
			for y in range(lot.position.y, lot.end.y):
				if data.is_road(lot.position.x - 1, y):
					return true
	return false


static func _clear_trees(data: CityData, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if data.in_bounds(x, y):
				data.forest[data.idx(x, y)] = 0


# --- The jail -----------------------------------------------------------------------------

## The walled jail (PrisonCompound) stands on its island: no tree, no other building inside its walls.
static func _clear_jail_ground(data: CityData) -> int:
	var n := 0
	for b in data.building_count():
		if data.b_kind[b] != Kind.PRISON:
			continue
		var walls := PrisonCompound.square(data, data.building_rect(b)).grow(1.0)
		var sq := Rect2i(Vector2i(walls.position.floor()), Vector2i(walls.size.ceil()))
		_clear_trees(data, sq)
		for o in data.building_count():
			if o != b and data.b_kind[o] != Kind.EMPTY and sq.encloses(data.building_rect(o)) \
					and data.b_kind[o] != Kind.LIGHTHOUSE:
				_clear(data, o)
				n += 1
	return n


# --- Second wave: skyline, Eiffel tower, port, red district ------------------------------------------

## Night skyline towers taken away (urban island, column 67).
const SKYLINE_DELETED := [Vector2i(67, 187), Vector2i(67, 183), Vector2i(67, 179), Vector2i(67, 191)]
## The Windows logo on the east wall of this tower (B-01660).
const LOGO_TOWER := Vector2i(58, 137)
## The roof neon of the tower B-01690 moves to the tower B-01640; the bar neon of B-01696 is a pacman.
const ROOF_NEON_FROM := Vector2i(67, 170)
const ROOF_NEON_TO := Vector2i(49, 166)
const PACMAN_TOWER := Vector2i(67, 195)

## The Eiffel tower stands on the office B-00015 (the model of the old map, drawn at an absolute
## scale for a 4x6 lot); the ground under it is grass (a park).
const EIFFEL_AT := Vector2i(132, 171)
const EIFFEL_MODEL := "eiffel_tower.glb: eiffel_tower"
const EIFFEL_SCALE := 0.26

## Port: the crane B-01736 is copied onto the hall B-01717 and the shed B-01743, then taken away.
const CRANE_AT := Vector2i(135, 239)
const CRANE_MODEL := "port_towers.glb: tower_crane"
const CRANE_SPOTS := [Rect2i(119, 257, 4, 7), Rect2i(116, 262, 2, 2)]
const PORT_DELETED := [
	["INDUSTRIAL", Vector2i(116, 262)], ["INDUSTRIAL", Vector2i(119, 257)],   # B-01743, B-01717 (crane)
	["INDUSTRIAL", Vector2i(125, 257)],                                       # B-01719, three big tanks
	["INDUSTRIAL", Vector2i(141, 257)], ["INDUSTRIAL", Vector2i(146, 254)], ["INDUSTRIAL", Vector2i(140, 242)],
	["INDUSTRIAL", Vector2i(137, 250)], ["INDUSTRIAL", Vector2i(124, 238)],
	["INDUSTRIAL", Vector2i(119, 242)], ["INDUSTRIAL", Vector2i(126, 242)],
]
const BIG_TANK_MODEL := "port_tanks.glb: tank_big"
const BIG_TANK_LOTS := [Rect2i(125, 257, 4, 2), Rect2i(125, 259, 4, 2), Rect2i(125, 261, 4, 3)]
## The oil tank B-01747 and two more stand in a row beside the spheres B-01734 (119,232).
const OIL_TANK_AT := Vector2i(131, 241)
const OIL_TANK_LOTS := [Rect2i(122, 232, 1, 2), Rect2i(123, 232, 1, 2), Rect2i(124, 232, 1, 2)]
## The factory hall B-01721 is drawn as the factory hall B-01718.
const FACTORY_MODEL := "port_halls.glb: hall_factory_1"
const FACTORY_AT := Vector2i(120, 253)

## Red district: the drive-in goes north of the quarter building B-00927 (free forest ground) with
## a street down to the street at row 277; the wood ground beside B-00969 is cleared and the
## Ferris wheel stands on it; the hotel B-01060 looks east; three quarter buildings share a model.
const DRIVE_IN_AT := Vector2i(190, 305)
const DRIVE_IN_LOT := Rect2i(178, 271, 5, 4)
const DRIVE_IN_ROAD_X := 180
const DRIVE_IN_ROAD_TO_Y := 277
const WHEEL_AT := Vector2i(203, 309)
const WHEEL_LOT := Rect2i(181, 310, 6, 6)
const WOOD_CLEARED := Rect2i(168, 310, 23, 7)
const HOTEL_EAST := Vector2i(175, 288)
const QUARTER_MODEL := "quarter.glb: quarter_40_b"
const QUARTER_SAME := [Vector2i(178, 301), Vector2i(210, 290), Vector2i(187, 305)]


static func _second_wave(data: CityData) -> Dictionary:
	var n := {}
	for c in SKYLINE_DELETED:
		var b := _find(data, "SKYLINE_BLDG", c)
		if b >= 0:
			_clear(data, b)
	var logo := _find(data, "SKYLINE_BLDG", LOGO_TOWER)
	if logo >= 0:
		data.b_sign[logo] = ModelCatalog.Cat.SIGN_WINDOWS
		data.b_sign_facing[logo] = 1
	var from := _find(data, "SKYLINE_BLDG", ROOF_NEON_FROM)
	var to := _find(data, "SKYLINE_BLDG", ROOF_NEON_TO)
	if from >= 0 and to >= 0:
		data.b_more_signs[to] = data.b_more_signs.get(from, [])
		data.b_more_signs.erase(from)
		if data.b_sign[to] == 0:
			data.b_sign_facing[to] = 1
	var pac := _find(data, "SKYLINE_BLDG", PACMAN_TOWER)
	if pac >= 0:
		data.b_sign[pac] = ModelCatalog.Cat.NEON_PACMAN
	n["eiffel"] = _eiffel(data)
	n["port"] = _port(data)
	n["red_district"] = _red_district(data)
	return n


static func _eiffel(data: CityData) -> int:
	var b := _find(data, "OFFICE", EIFFEL_AT)
	if b < 0:
		return 0
	var lot := data.building_rect(b)
	data.b_kind[b] = Kind.CASINO
	data.b_model[b] = EIFFEL_MODEL
	data.b_scale[b] = -EIFFEL_SCALE
	data.b_facing[b] = 2
	data.b_sign[b] = 0
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			data.zone[data.idx(x, y)] = Zone.PARK
			data.forest[data.idx(x, y)] = 0
	return 1


## A new industrial lot drawn as `model`.
static func _industrial(data: CityData, lot: Rect2i, model: String, facing: int) -> int:
	var b := data.add_building(lot, Kind.INDUSTRIAL, facing, 1, 0.5)
	data.b_model[b] = model
	return b


static func _port(data: CityData) -> int:
	var crane := _find(data, "INDUSTRIAL", CRANE_AT)
	var oil := _find(data, "INDUSTRIAL", OIL_TANK_AT)
	var factory := _find(data, "INDUSTRIAL", FACTORY_AT)
	for d in PORT_DELETED:
		var b := _find(data, d[0], d[1])
		if b >= 0:
			_clear(data, b)
	var n := 0
	if crane >= 0:
		for lot in CRANE_SPOTS:
			_industrial(data, lot, CRANE_MODEL, 1)
			n += 1
		_clear(data, crane)
	for lot in BIG_TANK_LOTS:
		_industrial(data, lot, BIG_TANK_MODEL, 2)
		n += 1
	if oil >= 0:
		for lot in OIL_TANK_LOTS:
			_industrial(data, lot, "port_tanks.glb: tank_oil", 1)
			n += 1
		_clear(data, oil)
	if factory >= 0:
		data.b_model[factory] = FACTORY_MODEL
		n += 1
	return n


static func _red_district(data: CityData) -> int:
	var n := 0
	var drive := _find(data, "DRIVE_IN", DRIVE_IN_AT)
	if drive >= 0:
		_clear_trees(data, DRIVE_IN_LOT.grow(1))
		_relocate(data, drive, DRIVE_IN_LOT, 2)
		data.b_facing[drive] = 2
		for y in range(DRIVE_IN_LOT.end.y, DRIVE_IN_ROAD_TO_Y):
			var i := data.idx(DRIVE_IN_ROAD_X, y)
			data.road[i] = CityTypes.ROAD_STREET
			data.forest[i] = 0
			data.rocky[i] = 0
		n += 1
	var wheel := _find(data, "FERRIS_WHEEL", WHEEL_AT)
	if wheel >= 0:
		for y in range(WOOD_CLEARED.position.y, WOOD_CLEARED.end.y):
			for x in range(WOOD_CLEARED.position.x, WOOD_CLEARED.end.x):
				if data.is_land(x, y):
					data.forest[data.idx(x, y)] = 0
		_relocate(data, wheel, WHEEL_LOT, 0)
		n += 1
	var hotel := _find(data, "HOTEL", HOTEL_EAST)
	if hotel >= 0:
		data.b_facing[hotel] = 1
		data.b_sign_facing[hotel] = 1
		n += 1
	for c in QUARTER_SAME:
		var b := _find(data, "QUARTER_BLDG", c)
		if b >= 0:
			data.b_model[b] = QUARTER_MODEL
			n += 1
	return n
