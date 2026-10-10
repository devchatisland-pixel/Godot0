class_name BuildingBudget
extends RefCounted
## How many buildings of each kind the map holds, whatever its size: the numbers of the first
## map (272 cells). The planners lay out a few lots too many on a bigger map; this pass, the
## last one before the ground details, clears the surplus of every kind (the cleared lots stay
## as bare ground) and adds the few that are missing where a rule says how.
## The buildings that a hand edit changed are never cleared (ManualEdits.kept).

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

const BUDGET := {
	"AIRBASE": 1, "APARTMENT": 68, "BALLOON": 4, "BANK": 1, "BEACH_HUT": 6, "BILLBOARD": 9,
	"BOAT": 12, "BT_TOWER": 1, "BUNKER": 1, "BURGER_JOINT": 5, "BURGER_KING": 2, "BUS_STOP": 6,
	"CASINO": 3, "CEMETERY": 2, "CHURCH": 1, "CINEMA_MAIN": 1, "CITY_HALL": 1, "COOLING_HALL": 1,
	"CRANE": 2, "DRIVE_IN": 1, "FACTORY_BLDG": 8, "FERRIS_WHEEL": 1, "FIELD": 17,
	"FIRE_STATION": 4, "FIRE_TRUCK": 2, "FOUNTAIN": 1, "FUTURE_BLDG": 11, "GARDEN": 10,
	"GAS_STATION": 2, "GRAVE": 1, "HOSPITAL": 3, "HOTEL": 6, "HOUSE": 186, "INDUSTRIAL": 28,
	"INDUSTRIAL_YARD": 147, "LANDMARK": 7, "LIGHTHOUSE": 6, "MAIN_HOSPITAL": 2, "MAIN_SCHOOL": 1,
	"MCDONALDS": 1, "MESA": 2, "MOUNTAIN": 3, "NIGHTCLUB": 12, "NUCLEAR_PLANT": 2, "OFFICE": 53,
	"OIL_PUMP": 5, "OUTPOST": 10, "PHARMACY": 3, "PIER": 5, "PLAZA": 5, "POLICE": 4,
	"POLICE_HQ": 1, "POND": 1, "POOR_BLDG": 39, "POST_OFFICE": 3, "PRISON": 1,
	"QUARTER_BLDG": 173, "SAT_DISH": 6, "SCHOOL": 3, "SHOP": 239, "SKYSCRAPER": 43, "STADIUM": 1,
	"TANK": 2, "TELECOM_TOWER": 1, "UFO": 1, "UN_HQ": 1, "URBAN_BLDG": 69, "WATCHTOWER": 2,
}

## Kinds that may be added when there are too few: the lot size and the zones they stand in.
const ADD := {
	"INDUSTRIAL": {"size": Vector2i(3, 2), "zones": [Zone.INDUSTRIAL]},
	"INDUSTRIAL_YARD": {"size": Vector2i(2, 2), "zones": [Zone.INDUSTRIAL]},
	"FIELD": {"size": Vector2i(5, 5), "zones": [Zone.FARM]},
	"OUTPOST": {"size": Vector2i(2, 2), "zones": [Zone.FARM]},
	"OIL_PUMP": {"size": Vector2i(2, 2), "zones": [Zone.DESERT]},
}


## Returns {"cleared": {kind: n}, "added": {kind: n}, "missing": {kind: n}}.
static func apply(data: CityData) -> Dictionary:
	var names := CityTypes.Kind.keys()
	var by_kind := {}
	for b in data.building_count():
		var k: String = names[data.b_kind[b]]
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(b)
	var kept := ManualEdits.kept()
	var roadless := {}
	for b in MapAudit.lots_without_road(data):
		roadless[b] = true
	var out := {"cleared": {}, "added": {}, "missing": {}}
	for k: String in BUDGET:
		var ids: Array = by_kind.get(k, [])
		var want: int = BUDGET[k]
		if ids.size() > want:
			out["cleared"][k] = _clear(data, ids, ids.size() - want, kept, roadless)
		elif ids.size() < want:
			var added := _add(data, k, want - ids.size()) if ADD.has(k) else 0
			if added > 0:
				out["added"][k] = added
			if ids.size() + added < want:
				out["missing"][k] = want - ids.size() - added
	if not out["missing"].is_empty():
		push_warning("[Budget] too few buildings: %s" % out["missing"])
	return out


## Clears `count` buildings of `ids`: first the ones that stand on no street, then spread
## over the map (in the order of a hash of their place); the ones changed by hand last.
static func _clear(data: CityData, ids: Array, count: int, kept: Dictionary, roadless: Dictionary) -> int:
	var order := ids.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		if kept.has(a) != kept.has(b):
			return kept.has(b)
		if roadless.has(a) != roadless.has(b):
			return roadless.has(a)
		var ra := data.building_rect(a).position
		var rb := data.building_rect(b).position
		var ha := CityTypes.hash2(ra.x, ra.y, 9173)
		var hb := CityTypes.hash2(rb.x, rb.y, 9173)
		return ha < hb if ha != hb else a < b)
	var n := 0
	for b: int in order:
		if n >= count or kept.has(b):
			break
		data.b_kind[b] = Kind.EMPTY
		n += 1
	return n


## Adds up to `count` buildings of `kind_name` on free ground of its zones, one cell apart
## from everything, nearest to the buildings of that kind (or to the middle of the zone).
static func _add(data: CityData, kind_name: String, count: int) -> int:
	var rule: Dictionary = ADD[kind_name]
	var size: Vector2i = rule["size"]
	var zones: Array = rule["zones"]
	var kind: int = Kind[kind_name]
	var built := PackedByteArray()
	built.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.in_bounds(x, y):
					built[data.idx(x, y)] = 1
	var spots: Array[Vector2i] = []
	for y in range(1, data.size - size.y - 1):
		for x in range(1, data.size - size.x - 1):
			if zones.has(int(data.zone[data.idx(x, y)])) and _free(data, built, Rect2i(x, y, size.x, size.y), zones):
				spots.append(Vector2i(x, y))
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return CityTypes.hash2(a.x, a.y, 4409) < CityTypes.hash2(b.x, b.y, 4409))
	var added := 0
	for p in spots:
		if added >= count:
			break
		var r := Rect2i(p, size)
		if not _free(data, built, r, zones):
			continue
		data.add_building(r, kind, 2, CityTypes.hash2(p.x, p.y, 77) & 0x7fffffff, 0.5)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				built[data.idx(x, y)] = 1
		added += 1
	return added


## `r` and the ring round it are dry land of `zones`, without road nor building.
static func _free(data: CityData, built: PackedByteArray, r: Rect2i, zones: Array) -> bool:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			var i := data.idx(x, y)
			if built[i] == 1 or data.road[i] != 0 or data.terrain[i] != Terrain.LAND \
					or not zones.has(int(data.zone[i])):
				return false
	return true
