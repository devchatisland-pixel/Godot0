class_name UrbanFill
extends RefCounted
## Towers on the free land south of the airport: the sight clearing of the urban island
## planner leaves it empty, and the south end looked unfinished. The towers are added at
## the very end of the building list, so no building number moves.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
## Lot sizes tried, biggest first.
const SIZES := [3, 2]
## Free cells between two towers.
const GAP := 1


## Adds the towers; returns how many.
static func apply(data: CityData) -> int:
	var airport := Rect2i()
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	for b in data.building_count():
		var r := data.building_rect(b)
		if data.b_kind[b] == Kind.AIRPORT:
			airport = r
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[data.idx(x, y)] = 1
	if airport.size.x <= 0:
		return 0
	var added := 0
	# Big lots first, then smaller towers in what is left.
	for lot in SIZES:
		var y := airport.end.y + 1
		while y + lot <= data.size:
			var x := 0
			while x + lot <= MapLayout.cells("urban_columns"):
				var r := Rect2i(x, y, lot, lot)
				if _free(data, taken, r):
					var seed := CityTypes.hash2(x, y, 901)
					var facing := 1 if (seed >> 7) & 1 == 1 else 2
					data.add_building(r, Kind.URBAN_BLDG, facing, seed, 0.5)
					for yy in range(r.position.y - GAP, r.end.y + GAP):
						for xx in range(r.position.x - GAP, r.end.x + GAP):
							if data.in_bounds(xx, yy):
								taken[data.idx(xx, yy)] = 1
					added += 1
					x += lot + GAP
				else:
					x += 1
			y += 1
	return added


static func _free(data: CityData, taken: PackedByteArray, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := data.idx(x, y)
			if taken[i] == 1 or data.road[i] != 0 or data.terrain[i] != CityTypes.Terrain.LAND \
					or data.zone[i] != Zone.URBAN:
				return false
	return true
