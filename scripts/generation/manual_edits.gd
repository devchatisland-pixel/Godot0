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

## Edit index -> building number it was applied to (filled by `apply`; read by the tests
## and by BuildingBudget).
static var resolved := {}

const EDITS := [
	{"kind": "CRANE", "near": Vector2i(132, 165), "facing": 1},
	{"kind": "CINEMA_MAIN", "near": Vector2i(139, 143), "scale": 0.45},
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
	{"kind": "BURGER_JOINT", "near": Vector2i(110, 153), "scale_abs": 1.0},
	{"kind": "QUARTER_BLDG", "near": Vector2i(165, 208), "replace": "HOSPITAL"},
	{"kind": "LIGHTHOUSE", "near": Vector2i(93, 202), "clear_quay": 6},
	{"kind": "OUTPOST", "near": Vector2i(80, 134), "shift": Vector2i(0, -33)},
	{"kind": "FIRE_STATION", "near": Vector2i(150, 140), "scale": 1.12},
	{"kind": "POST_OFFICE", "near": Vector2i(133, 152), "scale": 1.12},
	# Shopping center: a casino stands in a park where it was.
	{"kind": "SHOPPING_CENTER", "near": Vector2i(100, 138), "replace": "CASINO", "size": [3, 3],
		"old_ground": "PARK"},
]

## Kinds taken away everywhere: the pirate ships (the ones at sea are only made after the
## other edits), the airport, the urban ghetto block and the wings of the prison.
const DELETED_KINDS := ["PIRATE_SHIP", "AIRPORT", "RUSSIAN", "PRISON_WING"]

## The beach hut nearest to this cell of the first map goes into the forest next to the desert.
const HUT_FROM := Vector2i(191, 65)
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
## What only exists once the props are placed: the kinds taken away, the hut in the forest
## and the balloons (added at the end of the building list).
static func apply_late(data: CityData) -> void:
	for kind_name in DELETED_KINDS:
		var kind: int = CityTypes.Kind[kind_name]
		for b in data.building_count():
			if data.b_kind[b] == kind:
				data.b_kind[b] = CityTypes.Kind.EMPTY
	_move_hut(data)
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


## The beach hut nearest to HUT_FROM moves to the densest free 2x2 forest spot of the map that
## has desert within 6 cells, the nearest one to where it was on a tie (the pier, if any, stays
## on the beach). The desert is in the west, far from the east beach the hut stood on.
static func _move_hut(data: CityData) -> void:
	var from := MapLayout.scaled(HUT_FROM)
	var id := _nearest(data, "BEACH_HUT", from)
	if id < 0:
		return
	var taken := {}
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY or b == id:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[Vector2i(x, y)] = true
	var best := Vector2i(-1, -1)
	var best_key := -INF
	for y in range(2, data.size - 3):
		for x in range(2, data.size - 3):
			var forest := 0
			var ok := true
			for dy in 2:
				for dx in 2:
					var cx := x + dx
					var cy := y + dy
					var i := data.idx(cx, cy)
					if data.terrain[i] != CityTypes.Terrain.LAND or data.zone[i] != CityTypes.Zone.NATURE \
							or data.road[i] != 0 or taken.has(Vector2i(cx, cy)):
						ok = false
						break
					forest += data.forest[i]
				if not ok:
					break
			if not ok or forest < 4 * 120:
				continue
			var desert := false
			for dy in range(-6, 8):
				for dx in range(-6, 8):
					if data.zone_at(x + dx, y + dy) == CityTypes.Zone.DESERT:
						desert = true
			if not desert:
				continue
			var key := float(forest) - Vector2(x - from.x, y - from.y).length() * 2.0
			if key > best_key:
				best_key = key
				best = Vector2i(x, y)
	if best.x < 0:
		push_warning("[Edits] no forest spot near the desert for the beach hut")
		return
	data.set_building_rect(id, Rect2i(best, Vector2i(2, 2)))
