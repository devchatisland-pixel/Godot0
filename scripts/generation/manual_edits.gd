class_name ManualEdits
extends RefCounted
## Hand-made corrections to single buildings, applied once the whole map is generated
## (CityGenerator). An entry does not name a cell or a building number, which change with
## every rebuild of the map: it names a `kind` and a place `near` (a cell of the first map,
## 272 cells; MapLayout scales it), and applies to the nearest building of that kind that no
## other entry took. How many buildings of each kind there are is not decided here:
## BuildingBudget clears the surplus afterwards (and never one that an entry changed).
##   facing   0 north, 1 east, 2 south, 3 west (the side of the front)
##   scale    size factor of the model, 1 = as placed
##   scale_abs  absolute scale of the model, 1 = its own size (ignores the lot)
##   replace  name of the Kind the building becomes (it keeps its lot and its facing)
##   delete   true = nothing is drawn any more
##   park     true = the cells of the lot become park ground (trees grow there; use with delete)
##   size     [w, h] the new size of the lot, from the same top-left cell (when the ground is free)
##   shift    cells the lot moves by, on the first map (when the ground is free)
##   old_ground  zone name given back to the cells the building leaves when its lot changes
##            (the cells it enters take the ground of the building)
##   model    name of the model to draw, as the library names it (e.g. "building-type-n.glb")
##   clear_quay  radius: sand instead of quay ground (rocky = 2) within that many cells of the building
##   sign     name of a ModelCatalog.Cat (a neon sign); BuildingExtras.SIGNS says where it goes
##   lay      true = a flat model (crop field) is laid along `facing` instead of the long side

## Edit index -> building number it was applied to (filled by `apply`; read by the tests
## and by BuildingBudget).
static var resolved := {}
## Building numbers deleted by DELETED_AT (filled by `delete_by_hand`):
## they win over an entry of EDITS that changed the same building (read by the tests).
static var hand_deleted := {}

const EDITS := [
	{"kind": "CRANE", "near": Vector2i(132, 165), "facing": 1},
	# Drawn at 0.45 of its 8x8 lot; finish() shrinks the lot to its middle 4x4 (same model size).
	{"kind": "CINEMA_MAIN", "near": Vector2i(139, 143), "scale": 0.9},
	{"kind": "BANK", "near": Vector2i(139, 157), "scale": 0.6},
	# A hotel becomes a park with trees, another one the city hall.
	{"kind": "HOTEL", "near": Vector2i(164, 129), "delete": true, "park": true},
	{"kind": "HOTEL", "near": Vector2i(120, 129), "replace": "CITY_HALL", "size": [3, 5]},
	{"kind": "HOTEL", "near": Vector2i(100, 166), "facing": 3},
	{"kind": "HOTEL", "near": Vector2i(170, 164), "scale_abs": 1.0},
	{"kind": "HOTEL", "near": Vector2i(123, 210), "facing": 2},
	{"kind": "HOTEL", "near": Vector2i(154, 214), "facing": 2},
	{"kind": "AIRBASE", "near": Vector2i(69, 113), "shift": Vector2i(6, -5), "size": [5, 16], "facing": 1,
		"old_ground": "DESERT"},
	{"kind": "PHARMACY", "near": Vector2i(150, 166), "facing": 2},
	{"kind": "SHOP", "near": Vector2i(110, 71), "replace": "BURGER_KING"},
	{"kind": "HOSPITAL", "near": Vector2i(160, 139), "replace": "MAIN_HOSPITAL", "scale_abs": 1.0},
	{"kind": "SHOP", "near": Vector2i(137, 102), "facing": 1, "replace": "HOUSE",
		"model": "building-type-n.glb", "sign": "NEON_CONTROLLER"},
	{"kind": "POLICE", "near": Vector2i(171, 154), "sign": "NEON_PACMAN"},
	{"kind": "POLICE_HQ", "near": Vector2i(118, 148), "scale": 0.75},
	{"kind": "QUARTER_BLDG", "near": Vector2i(165, 208), "replace": "HOSPITAL"},
	{"kind": "LIGHTHOUSE", "near": Vector2i(93, 202), "clear_quay": 6},
	{"kind": "OUTPOST", "near": Vector2i(80, 134), "shift": Vector2i(0, -33)},
	{"kind": "FIRE_STATION", "near": Vector2i(150, 140), "scale": 1.12},
	{"kind": "POST_OFFICE", "near": Vector2i(133, 152), "scale": 1.12},
	# Shopping center: a casino stands in a park where it was.
	{"kind": "SHOPPING_CENTER", "near": Vector2i(100, 138), "replace": "CASINO", "size": [3, 3],
		"old_ground": "PARK"},
	# Business pack eateries in the central city: shops become 3 restaurants, 2 pizzerias, 1 burger bar, 4 cafes.
	{"kind": "SHOP", "near": Vector2i(138, 149), "replace": "RESTAURANT"},
	{"kind": "SHOP", "near": Vector2i(135, 146), "replace": "RESTAURANT"},
	{"kind": "SHOP", "near": Vector2i(142, 152), "replace": "RESTAURANT"},
	{"kind": "SHOP", "near": Vector2i(140, 150), "replace": "PIZZA_SHOP"},
	{"kind": "SHOP", "near": Vector2i(136, 152), "replace": "PIZZA_SHOP"},
	{"kind": "SHOP", "near": Vector2i(138, 143), "replace": "BURGER_SHOP"},
	{"kind": "SHOP", "near": Vector2i(134, 152), "replace": "CAFE"},
	{"kind": "SHOP", "near": Vector2i(146, 151), "replace": "CAFE"},
	{"kind": "SHOP", "near": Vector2i(144, 142), "replace": "CAFE"},
	{"kind": "SHOP", "near": Vector2i(147, 148), "replace": "CAFE"},
	# The corn field of the farm next to the tractor faces west.
	{"kind": "FIELD", "near": Vector2i(196, 174), "facing": 3, "lay": true},
]

## Kinds taken away everywhere: the airport, the urban ghetto block and the wings of the prison.
const DELETED_KINDS := ["AIRPORT", "RUSSIAN", "PRISON_WING"]

## Other buildings taken away by hand: kind and top-left cell of the lot on the final map.
const DELETED_AT := [
	["BALLOON", Vector2i(250, 141)],
	["HOTEL", Vector2i(206, 302)],
	["HOTEL", Vector2i(182, 301)],
	["PIER", Vector2i(138, 291)],
	["SHOP", Vector2i(172, 185)],
	["SHOP", Vector2i(170, 190)],
	["SHOP", Vector2i(170, 191)],
	["BILLBOARD", Vector2i(168, 187)],
	["OIL_PUMP", Vector2i(93, 168)],
	["BILLBOARD", Vector2i(260, 85)],
	["BILLBOARD", Vector2i(276, 256)],
	["TANK", Vector2i(100, 143)],
	["INDUSTRIAL", Vector2i(28, 94)],
	["INDUSTRIAL", Vector2i(38, 94)],
	["INDUSTRIAL", Vector2i(29, 83)],
	["INDUSTRIAL_YARD", Vector2i(32, 86)],
	["INDUSTRIAL_YARD", Vector2i(28, 88)],
	["INDUSTRIAL_YARD", Vector2i(37, 86)],
	["BOAT", Vector2i(167, 338)],
	["BOAT", Vector2i(21, 300)],
	["OIL_PUMP", Vector2i(121, 140)],
	["OUTPOST", Vector2i(122, 145)],
	["BURGER_KING", Vector2i(164, 102)],
	["NIGHTCLUB", Vector2i(128, 171)],
	["NIGHTCLUB", Vector2i(121, 178)],
	["PHARMACY", Vector2i(167, 203)],
]
## Buildings turned by hand: kind, top-left cell of the lot on the final map, facing (0 N, 1 E, 2 S, 3 W).
const TURNED_AT := [
	["MAIN_HOSPITAL", Vector2i(243, 201), 2],
	["MAIN_HOSPITAL", Vector2i(167, 195), 2],
]
## Buildings taken away by hand once the buildings are final (in `finish`, after the burger
## joints became McDonald's): kind and top-left cell of the lot on the final map.
const DELETED_LATE := [
	["MCDONALDS", Vector2i(237, 202)],
	["APARTMENT", Vector2i(175, 216)],
]
## Cleared lots that get a farm building back: top-left cell, model (as the library names it).
const FARM_BUILDINGS_AT := [
	[Vector2i(265, 283), "outpost.glb: water_tank"],
]
## Oil pumps added side by side with the one whose lot starts at OIL_FIELD (to its east, else
## its west).
const OIL_FIELD := Vector2i(99, 209)
const EXTRA_OIL_PUMPS := 2
## Small shops round the main cinema (it stood alone in its block): how many, lot size.
const CINEMA_SHOPS := 4
const CINEMA_SHOP_SIZE := Vector2i(2, 2)
## The fire station whose front yard is cleared for its fire truck (VehicleSites).
const MAIN_FIRE_STATION := Vector2i(229, 177)
## How far in front of it no tree grows (cells).
const FIRE_YARD_DEPTH := 5

## Buildings drawn at another size by hand: kind, top-left cell of the lot, size factor.
const RESIZED_AT := [
	["BOAT", Vector2i(211, 40), 0.5],
]

## A balloon floats over the mountain nearest to this cell of the first map (and over the
## stadium and the north-east corner of the central park).
const BALLOON_MOUNTAIN := Vector2i(177, 101)


## Applies every entry; returns how many were applied.
static func apply(data: CityData) -> int:
	var applied := 0
	resolved.clear()
	var used := {}
	for n in EDITS.size():
		var e: Dictionary = EDITS[n]
		var id := _nearest(data, e["kind"], MapLayout.scaled(e["near"]), used)
		if id < 0:
			push_warning("[Edits] no %s for the edit near %s: skipped" % [e["kind"], e["near"]])
			continue
		used[id] = true
		resolved[n] = id
		var r := data.building_rect(id)
		var lot := r
		if e.has("shift"):
			lot.position += MapLayout.scaled(e["shift"])
		if e.has("size"):
			lot.size = Vector2i(e["size"][0], e["size"][1])
		if lot != r and not _lot_is_free(data, id, lot):
			# Not enough room for the wanted lot: what fits inside the old one, where it was.
			lot = Rect2i(r.position, Vector2i(mini(lot.size.x, r.size.x), mini(lot.size.y, r.size.y)))
		if lot != r:
			_move_ground(data, r, lot, e.get("old_ground", ""))
			data.set_building_rect(id, lot)
		if e.has("facing"):
			data.b_facing[id] = e["facing"]
		if e.has("scale"):
			data.b_scale[id] = e["scale"]
		if e.has("scale_abs"):
			data.b_scale[id] = -float(e["scale_abs"])
		if e.has("clear_quay"):
			_clear_quay(data, lot, int(e["clear_quay"]))
		if e.has("model"):
			data.b_model[id] = e["model"]
		if e.get("lay", false):
			data.b_lay[id] = 1
		if e.has("sign"):
			data.b_sign[id] = ModelCatalog.Cat[e["sign"]]
		if e.has("replace"):
			data.b_kind[id] = CityTypes.Kind[e["replace"]]
		if e.get("delete", false):
			data.b_kind[id] = CityTypes.Kind.EMPTY
		if e.get("park", false):
			for y in range(lot.position.y, lot.end.y):
				for x in range(lot.position.x, lot.end.x):
					data.zone[data.idx(x, y)] = CityTypes.Zone.PARK
		applied += 1
	return applied


## Building numbers the entries changed and that must stay (BuildingBudget does not clear them).
static func kept() -> Dictionary:
	var out := {}
	for n in resolved:
		if not EDITS[n].get("delete", false):
			out[resolved[n]] = true
	return out


## The building of `kind_name` nearest to `at` that is not in `used`, or -1.
static func _nearest(data: CityData, kind_name: String, at: Vector2i, used: Dictionary = {}) -> int:
	var kind: int = CityTypes.Kind[kind_name]
	var best := -1
	var best_d := INF
	for b in data.building_count():
		if data.b_kind[b] != kind or used.has(b):
			continue
		var d := Vector2(data.building_rect(b).position).distance_to(Vector2(at))
		if d < best_d:
			best_d = d
			best = b
	return best


## True when `lot` is dry land and no other (not cleared) building stands on it.
static func _lot_is_free(data: CityData, id: int, lot: Rect2i) -> bool:
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if not data.in_bounds(x, y) or data.terrain[data.idx(x, y)] != CityTypes.Terrain.LAND \
					or data.road[data.idx(x, y)] != 0:
				return false
	for b in data.building_count():
		if b != id and data.b_kind[b] != CityTypes.Kind.EMPTY and data.building_rect(b).intersects(lot):
			return false
	return true


## The ground follows the lot: the new cells get the zone of the building, the cells it
## leaves go back to `old_ground` (when given).
static func _move_ground(data: CityData, old: Rect2i, lot: Rect2i, old_ground: String) -> void:
	var zone := data.zone[data.idx(old.position.x, old.position.y)]
	if old_ground != "":
		for y in range(old.position.y, old.end.y):
			for x in range(old.position.x, old.end.x):
				if not lot.has_point(Vector2i(x, y)):
					data.zone[data.idx(x, y)] = CityTypes.Zone[old_ground]
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			data.zone[data.idx(x, y)] = zone


## Quay ground (the land colour reaching the sea) within `radius` cells of `lot` becomes sand.
static func _clear_quay(data: CityData, lot: Rect2i, radius: int) -> void:
	for y in range(lot.position.y - radius, lot.end.y + radius):
		for x in range(lot.position.x - radius, lot.end.x + radius):
			if data.in_bounds(x, y) and data.rocky[data.idx(x, y)] == 2:
				data.rocky[data.idx(x, y)] = 0


# --- After the props ----------------------------------------------------------------------------
## What only exists once the props are placed: the kinds taken away and the balloons
## (added at the end of the building list).
static func apply_late(data: CityData) -> void:
	for kind_name in DELETED_KINDS:
		var kind: int = CityTypes.Kind[kind_name]
		for b in data.building_count():
			if data.b_kind[b] == kind:
				data.b_kind[b] = CityTypes.Kind.EMPTY
	for c in _balloon_cells(data):
		data.add_building(Rect2i(c - Vector2i(1, 1), Vector2i(3, 3)), CityTypes.Kind.BALLOON, 2, 1, 0.5)


## Over the stadium, over the north-east corner of the central park, over a mountain.
static func _balloon_cells(data: CityData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stadium := _nearest(data, "STADIUM", Vector2i(data.size / 2, data.size / 2))
	if stadium >= 0:
		out.append(data.building_rect(stadium).get_center())
	# The central park is the biggest group of park cells: its corner is taken on the rows
	# and columns that hold the most of them.
	var lo := Vector2i(data.size, data.size)
	var hi := Vector2i(-1, -1)
	var middle := Vector2i(data.size / 2, data.size / 2)
	var reach := data.size / 4
	for y in range(middle.y - reach, middle.y + reach):
		for x in range(middle.x - reach, middle.x + reach):
			if data.zone_at(x, y) == CityTypes.Zone.PARK and data.road[data.idx(x, y)] == 0:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x >= 0:
		out.append(Vector2i(hi.x - 1, lo.y + 1))
	var mountain := _nearest(data, "MOUNTAIN", MapLayout.scaled(BALLOON_MOUNTAIN))
	if mountain >= 0:
		out.append(data.building_rect(mountain).get_center())
	return out


# --- The secret base and the motorhome trade places ----------------------------------------------
## Free room kept round the base lot: its fence (3 cells) and the tanks outside the gates.
const BASE_MARGIN := 7


## The secret base moves to the clearest spot of the desert (where the motorhome used to
## stand; VehicleSites now puts the motorhome in the south of the desert). Run after `apply`,
## before the props (the tanks of the gates and the fence follow the base). False when no
## spot of the desert has room for the base.
static func swap_base(data: CityData) -> bool:
	var base := _nearest(data, "AIRBASE", Vector2i(data.size / 2, data.size / 2))
	if base < 0:
		return false
	var old := data.building_rect(base)
	for c in VehicleSites.desert_spots(data, base):
		var lot := Rect2i(c - old.size / 2, old.size)
		if not _lot_is_free(data, base, lot.grow(BASE_MARGIN)) or not _all_desert(data, lot.grow(BASE_MARGIN)):
			continue
		var zone := data.zone[data.idx(old.position.x, old.position.y)]
		for y in range(old.position.y, old.end.y):
			for x in range(old.position.x, old.end.x):
				data.zone[data.idx(x, y)] = CityTypes.Zone.DESERT
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				data.zone[data.idx(x, y)] = zone
		data.set_building_rect(base, lot)
		return true
	push_warning("[Edits] no room in the desert for the secret base: it stays where it is")
	return false


static func _all_desert(data: CityData, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if data.zone[data.idx(x, y)] != CityTypes.Zone.DESERT:
				return false
	return true


## Deletes the buildings of DELETED_AT, resizes those of RESIZED_AT (run after the urban island is rebuilt).
## Returns how many were found.
static func delete_by_hand(data: CityData) -> int:
	var found := 0
	hand_deleted.clear()
	for b in data.building_count():
		var at := data.building_rect(b).position
		for d in DELETED_AT:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and at == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
				found += 1
		for d in RESIZED_AT:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and at == d[1]:
				data.b_scale[b] = d[2]
				found += 1
	return found


## Last hand changes, once the buildings are final: houses that face west turn east, the
## cleared lots of FARM_BUILDINGS_AT get a farm building back, and no tree grows in the front
## yard of the main fire station. Returns how many houses turned.
static func finish(data: CityData) -> int:
	var turned := 0
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.HOUSE and data.b_facing[b] == 3:
			data.b_facing[b] = 1
			turned += 1
		for f in FARM_BUILDINGS_AT:
			if data.b_kind[b] == CityTypes.Kind.EMPTY and data.building_rect(b).position == f[0]:
				data.b_kind[b] = CityTypes.Kind.OUTPOST
				data.b_model[b] = f[1]
				data.b_facing[b] = 2
	for b in data.building_count():
		for t in TURNED_AT:
			if data.b_kind[b] == CityTypes.Kind[t[0]] and data.building_rect(b).position == t[1]:
				data.b_facing[b] = t[2]
	# Every burger joint becomes a McDonald's.
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.BURGER_JOINT:
			data.b_kind[b] = CityTypes.Kind.MCDONALDS
	for b in data.building_count():
		for d in DELETED_LATE:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and data.building_rect(b).position == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
	_add_oil_pumps(data)
	_cinema_shops(data)
	# The main police station: its front yard is paved like its lot (its patrol car parks there).
	var hq := _nearest(data, "POLICE_HQ", Vector2i(data.size / 2, data.size / 2))
	if hq >= 0:
		for c in front_yard(data, hq, 1):
			data.zone[data.idx(c.x, c.y)] = CityTypes.Zone.CIVIC
			data.forest[data.idx(c.x, c.y)] = 0
	var fs := _nearest(data, "FIRE_STATION", MAIN_FIRE_STATION)
	if fs >= 0:
		# No forest grows on the ground in front of it (across the road too).
		for c in front_yard(data, fs, FIRE_YARD_DEPTH, 1):
			data.forest[data.idx(c.x, c.y)] = 0
	return turned


## EXTRA_OIL_PUMPS oil pumps in a row with the pump at OIL_FIELD, on free desert.
static func _add_oil_pumps(data: CityData) -> void:
	var pump := _nearest(data, "OIL_PUMP", OIL_FIELD)
	if pump < 0:
		return
	var r := data.building_rect(pump)
	var added := 0
	for side in [1, -1]:
		var k := 1
		while added < EXTRA_OIL_PUMPS and k <= EXTRA_OIL_PUMPS:
			var lot := Rect2i(r.position + Vector2i(side * k * r.size.x, 0), r.size)
			if not _lot_is_free(data, -1, lot):
				break
			data.add_building(lot, CityTypes.Kind.OIL_PUMP, 2, data.b_seed[pump] + k * side, 0.5)
			added += 1
			k += 1
	if added < EXTRA_OIL_PUMPS:
		push_warning("[Edits] only %d oil pumps added beside the one at %s" % [added, OIL_FIELD])


## The main cinema stood alone in the middle of its big square lot: the lot shrinks to the
## middle half (the model keeps its size: the edit draws it at 0.9 of the smaller lot) and
## small shops stand in the corners of the square, facing outwards.
static func _cinema_shops(data: CityData) -> void:
	var cinema := _nearest(data, "CINEMA_MAIN", Vector2i(data.size / 2, data.size / 2))
	if cinema < 0:
		return
	var r := data.building_rect(cinema)
	if r.size.x < 6 or r.size.y < 6:
		return
	var inner := Rect2i(r.position + r.size / 4, r.size / 2)
	data.set_building_rect(cinema, inner)
	var s := CINEMA_SHOP_SIZE
	var corners := [[r.position, 0], [Vector2i(r.end.x - s.x, r.position.y), 0],
			[Vector2i(r.position.x, r.end.y - s.y), 2], [r.end - s, 2]]
	for k in mini(CINEMA_SHOPS, corners.size()):
		var lot := Rect2i(corners[k][0], s)
		if not _lot_is_free(data, -1, lot):
			continue
		var c := lot.get_center()
		var b := data.add_building(lot, CityTypes.Kind.SHOP, corners[k][1], CityTypes.hash2(c.x, c.y, 717), 0.3)
		data.b_scale[b] = 0.8


## Free cells (no road) up to `depth` cells in front of building `b`, `widen` cells wider than
## the lot on each side.
static func front_yard(data: CityData, b: int, depth: int, widen: int = 0) -> Array[Vector2i]:
	var r := data.building_rect(b)
	var o := CityTypes.FACING_OFFSETS[data.b_facing[b]]
	var out: Array[Vector2i] = []
	for y in range(r.position.y - depth, r.end.y + depth):
		for x in range(r.position.x - depth, r.end.x + depth):
			var c := Vector2i(x, y)
			if r.has_point(c) or not data.in_bounds(x, y) or data.road[data.idx(x, y)] != 0:
				continue
			# On the front side: beyond the lot that way, level with it the other way.
			var ahead := (o.x > 0 and x >= r.end.x) or (o.x < 0 and x < r.position.x) 					or (o.y > 0 and y >= r.end.y) or (o.y < 0 and y < r.position.y)
			var level := (o.x != 0 and y >= r.position.y - widen and y < r.end.y + widen) 					or (o.y != 0 and x >= r.position.x - widen and x < r.end.x + widen)
			if ahead and level:
				out.append(c)
	return out


# --- The bunker beside the secret base -------------------------------------------------------------
## The bunker moves just outside the fence of the secret base (east side first, then north),
## its front turned away from the base. Run after swap_base, before the props.
static func move_bunker(data: CityData) -> bool:
	var base := _nearest(data, "AIRBASE", Vector2i(data.size / 2, data.size / 2))
	var bunker := _nearest(data, "BUNKER", Vector2i(data.size / 2, data.size / 2))
	if base < 0 or bunker < 0:
		return false
	var ring: Rect2i = AmenitiesPlanner.base_fence(data.building_rect(base))["rect"]
	var old := data.building_rect(bunker)
	var c := ring.get_center()
	var tries := [
		[Rect2i(ring.end.x + 1, c.y - old.size.y / 2, old.size.x, old.size.y), 1],
		[Rect2i(c.x - old.size.x / 2, ring.position.y - old.size.y - 1, old.size.x, old.size.y), 0],
		[Rect2i(ring.end.x + 1, ring.position.y, old.size.x, old.size.y), 1],
	]
	for t in tries:
		var lot: Rect2i = t[0]
		if not _lot_is_free(data, bunker, lot.grow(1)):
			continue
		var outside := data.zone_at(old.position.x - 1, old.position.y)
		_move_ground(data, old, lot, CityTypes.Zone.keys()[outside])
		data.set_building_rect(bunker, lot)
		data.b_facing[bunker] = t[1]
		return true
	push_warning("[Edits] no room for the bunker beside the secret base")
	return false
