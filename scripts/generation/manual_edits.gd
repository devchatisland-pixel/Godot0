class_name ManualEdits
extends RefCounted
## Hand-made corrections to single buildings, applied once the whole map is generated
## (CityGenerator). The building number is the one shown in the information bubble
## (B-00676 is id 676). Nothing is renumbered: a deleted building stays in the list as
## Kind.EMPTY, so the numbers of all the others never move.
##
## Every entry names the `kind` and the lot `at` (top-left cell) that must be there: when
## a change of the generation moves the numbers, the entry is skipped with a warning
## instead of altering some other building.
##   facing   0 north, 1 east, 2 south, 3 west (the side of the front)
##   scale    size factor of the model, 1 = as placed
##   scale_abs  absolute scale of the model, 1 = its own size (ignores the lot)
##   replace  name of the Kind the building becomes (it keeps its lot and its facing)
##   delete   true = nothing is drawn any more
##   rect     [x, y, w, h] the new lot (it must be free: take the buildings away first)
##   move_to  new top-left cell of the lot, same size (must be free)
##   old_ground  zone name given back to the cells the building leaves when its lot changes
##            (the cells it enters take the ground of the building)
##   sign     name of a ModelCatalog.Cat (a neon sign); BuildingExtras.SIGNS says where it goes

const EDITS := [
	{"id": 676, "kind": "CRANE", "at": Vector2i(132, 165), "facing": 1},
	{"id": 646, "kind": "CINEMA_MAIN", "at": Vector2i(139, 143), "scale": 0.45},
	{"id": 652, "kind": "BANK", "at": Vector2i(139, 157), "scale": 0.6},
	{"id": 662, "kind": "HOTEL", "at": Vector2i(164, 129), "facing": 3, "scale": 0.7},
	{"id": 661, "kind": "HOTEL", "at": Vector2i(100, 166), "facing": 3},
	{"id": 214, "kind": "SHOP", "at": Vector2i(120, 132), "delete": true},
	{"id": 215, "kind": "SHOP", "at": Vector2i(121, 132), "delete": true},
	{"id": 663, "kind": "HOTEL", "at": Vector2i(120, 129), "replace": "CITY_HALL", "rect": [120, 129, 3, 5]},
	{"id": 664, "kind": "HOTEL", "at": Vector2i(170, 164), "scale_abs": 1.0},
	{"id": 901, "kind": "HOTEL", "at": Vector2i(123, 210), "facing": 2},
	{"id": 1058, "kind": "OIL_PUMP", "at": Vector2i(73, 109), "move_to": Vector2i(82, 108)},
	{"id": 1047, "kind": "AIRBASE", "at": Vector2i(69, 113), "rect": [75, 108, 5, 16], "facing": 1,
		"old_ground": "DESERT"},
	{"id": 657, "kind": "PHARMACY", "at": Vector2i(150, 166), "facing": 2},
	{"id": 699, "kind": "SHOP", "at": Vector2i(110, 71), "replace": "BURGER_KING"},
	{"id": 741, "kind": "POOR_BLDG", "at": Vector2i(122, 82), "delete": true},
	{"id": 667, "kind": "BURGER_JOINT", "at": Vector2i(92, 136), "delete": true},
	{"id": 693, "kind": "HOSPITAL", "at": Vector2i(160, 139), "replace": "MAIN_HOSPITAL", "scale_abs": 1.0},
	{"id": 995, "kind": "FUTURE_BLDG", "at": Vector2i(36, 137), "delete": true},
	{"id": 927, "kind": "FUTURE_BLDG", "at": Vector2i(11, 142), "delete": true},
	{"id": 985, "kind": "FUTURE_BLDG", "at": Vector2i(23, 143), "delete": true},
	{"id": 257, "kind": "SHOP", "at": Vector2i(137, 102), "facing": 1, "sign": "NEON_CONTROLLER"},
	{"id": 685, "kind": "POLICE", "at": Vector2i(171, 154), "sign": "NEON_PACMAN"},
	{"id": 653, "kind": "FIRE_STATION", "at": Vector2i(150, 140), "scale": 1.12},
	{"id": 654, "kind": "POST_OFFICE", "at": Vector2i(133, 152), "scale": 1.12},
]


## Applies every entry; returns how many were applied.
static func apply(data: CityData) -> int:
	var names := CityTypes.Kind.keys()
	var applied := 0
	for e in EDITS:
		var id: int = e["id"]
		if id >= data.building_count():
			push_warning("[Edits] B-%05d does not exist" % id)
			continue
		var r := data.building_rect(id)
		if names[data.b_kind[id]] != e["kind"] or r.position != e["at"]:
			push_warning("[Edits] B-%05d is %s at %s, not %s at %s: skipped" % [
					id, names[data.b_kind[id]], r.position, e["kind"], e["at"]])
			continue
		var lot := r
		if e.has("rect"):
			var a: Array = e["rect"]
			lot = Rect2i(a[0], a[1], a[2], a[3])
		elif e.has("move_to"):
			lot = Rect2i(e["move_to"], r.size)
		if lot != r:
			if not _lot_is_free(data, id, lot):
				push_warning("[Edits] B-%05d: the lot %s is not free: skipped" % [id, lot])
				continue
			_move_ground(data, r, lot, e.get("old_ground", ""))
			data.set_building_rect(id, lot)
		if e.has("facing"):
			data.b_facing[id] = e["facing"]
		if e.has("scale"):
			data.b_scale[id] = e["scale"]
		if e.has("scale_abs"):
			data.b_scale[id] = -float(e["scale_abs"])
		if e.has("sign"):
			data.b_sign[id] = ModelCatalog.Cat[e["sign"]]
		if e.has("replace"):
			data.b_kind[id] = CityTypes.Kind[e["replace"]]
		if e.get("delete", false):
			data.b_kind[id] = CityTypes.Kind.EMPTY
		applied += 1
	return applied


## True when `lot` is dry land and no other (not cleared) building stands on it.
static func _lot_is_free(data: CityData, id: int, lot: Rect2i) -> bool:
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if not data.in_bounds(x, y) or data.terrain[data.idx(x, y)] != CityTypes.Terrain.LAND:
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
