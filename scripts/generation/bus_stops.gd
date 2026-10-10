class_name BusStops
extends RefCounted
## Bus shelters (the second, green one of the Brisbane pack) beside the roads, not too many:
## most of them along the two three-lane highways, some on the avenues of the country side
## and a few in the city. Added at the end of the building list.

const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Distance between two stops along a highway, and between any two stops elsewhere (cells).
const HIGHWAY_GAP := 26
const AVENUE_GAP := 30
## How many stops on the avenues outside and inside the middle of the city.
const OUTER_MAX := 9
const CENTER_MAX := 4
## The middle of the city, in cells round the middle of the map.
const CENTER_RADIUS := 26.0


static func apply(data: CityData) -> int:
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[data.idx(x, y)] = 1
	var stops: Array[Vector2i] = []
	# Highways: rows where three avenue cells lie one above the other.
	var last_x := -1000
	for x in range(data.size):
		for y in range(1, data.size - 1):
			if not (_avenue(data, x, y - 1) and _avenue(data, x, y) and _avenue(data, x, y + 1)):
				continue
			if (data.road[data.idx(x, y)] & CityTypes.ROAD_BRIDGE_FLAG) != 0:
				continue
			if absi(x - last_x) < HIGHWAY_GAP and last_x > -1000:
				continue
			# South verge first, then north.
			for side in [2, -2]:
				if _stop(data, taken, Vector2i(x, y + side), 0 if side > 0 else 2, stops):
					last_x = x
					break
	# Avenues of the map: single-cell avenues, spread by hash.
	var cands: Array = []
	for y in range(2, data.size - 2):
		for x in range(2, data.size - 2):
			var i := data.idx(x, y)
			if (data.road[i] & 3) != CityTypes.ROAD_AVENUE or (data.road[i] & CityTypes.ROAD_BRIDGE_FLAG) != 0:
				continue
			var m := data.road_mask(x, y)
			if m == (CityTypes.DIR_E | CityTypes.DIR_W) or m == (CityTypes.DIR_N | CityTypes.DIR_S):
				cands.append(Vector2i(x, y))
	cands.sort_custom(func(a, b): return CityTypes.hash2(a.x, a.y, 55) < CityTypes.hash2(b.x, b.y, 55))
	var middle := Vector2(data.size, data.size) * 0.5
	var outer := 0
	var center := 0
	for c: Vector2i in cands:
		var inside := Vector2(c).distance_to(middle) < CENTER_RADIUS
		if (inside and center >= CENTER_MAX) or (not inside and outer >= OUTER_MAX):
			continue
		var m := data.road_mask(c.x, c.y)
		var horizontal := m == (CityTypes.DIR_E | CityTypes.DIR_W)
		var verge := c + (Vector2i(0, 1) if horizontal else Vector2i(1, 0))
		var facing := 0 if horizontal else 3
		if _stop(data, taken, verge, facing, stops):
			if inside:
				center += 1
			else:
				outer += 1
	return stops.size()


static func _avenue(data: CityData, x: int, y: int) -> bool:
	return (data.road[data.idx(x, y)] & 3) == CityTypes.ROAD_AVENUE


## Puts a stop on `cell` (2x1 along the road) when it is free and far from the others.
static func _stop(data: CityData, taken: PackedByteArray, cell: Vector2i, facing: int,
		stops: Array[Vector2i]) -> bool:
	for s in stops:
		if Vector2(s).distance_to(Vector2(cell)) < AVENUE_GAP * 0.8:
			return false
	# The shelter is long along the road: 2 wide for a road along X, 2 tall for one along Z.
	var along_x := facing == 0 or facing == 2
	var r := Rect2i(cell, Vector2i(2, 1) if along_x else Vector2i(1, 2))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if taken[i] == 1 or data.road[i] != 0 or data.terrain[i] != Terrain.LAND:
				return false
	data.add_building(r, Kind.BUS_STOP, facing, CityTypes.hash2(cell.x, cell.y, 31), 0.5)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			taken[data.idx(x, y)] = 1
	stops.append(cell)
	return true
