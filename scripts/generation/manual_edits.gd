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
##   replace  name of the Kind the building becomes (it keeps its lot and its facing)
##   delete   true = nothing is drawn any more

const EDITS := [
	{"id": 676, "kind": "CRANE", "at": Vector2i(132, 165), "facing": 1},
	{"id": 646, "kind": "CINEMA_MAIN", "at": Vector2i(139, 143), "scale": 0.75},
	{"id": 652, "kind": "BANK", "at": Vector2i(139, 157), "scale": 0.8},
	{"id": 662, "kind": "HOTEL", "at": Vector2i(164, 129), "facing": 3, "scale": 0.85},
	{"id": 661, "kind": "HOTEL", "at": Vector2i(100, 166), "facing": 3},
	{"id": 663, "kind": "HOTEL", "at": Vector2i(120, 129), "replace": "CITY_HALL"},
	{"id": 657, "kind": "PHARMACY", "at": Vector2i(150, 166), "facing": 2},
	{"id": 699, "kind": "SHOP", "at": Vector2i(110, 71), "replace": "BURGER_KING"},
	{"id": 741, "kind": "POOR_BLDG", "at": Vector2i(122, 82), "delete": true},
	{"id": 667, "kind": "BURGER_JOINT", "at": Vector2i(92, 136), "delete": true},
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
		if e.has("facing"):
			data.b_facing[id] = e["facing"]
		if e.has("scale"):
			data.b_scale[id] = e["scale"]
		if e.has("replace"):
			data.b_kind[id] = CityTypes.Kind[e["replace"]]
		if e.get("delete", false):
			data.b_kind[id] = CityTypes.Kind.EMPTY
		applied += 1
	return applied
