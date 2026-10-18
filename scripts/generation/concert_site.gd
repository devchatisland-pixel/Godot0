class_name ConcertSite
extends RefCounted
## The concert camp in the nature near the north-east beach: a square of sand with
## the festival stage, floodlights and stands (drawn by BuildingExtras), and an
## earth footpath to the nearest street: no road reaches it, people come on foot.
## Added at the end of the building list, so no number moves. Whatever stood on the square
## (trees, a beach hut, a billboard...) is taken away.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## How far the square may slide from its place to find dry ground.
const MAX_SHIFT := 8
## Zones the camp may cover (nature, the beach strip, open land).
const ZONES: Array[int] = [Zone.NONE, Zone.NATURE, Zone.SAND]
const SEED := 1


## Adds the camp and its footpath; returns the building number, -1 when there is no room.
static func apply(data: CityData) -> int:
	var from := MapLayout.point("concert_from")
	var to := MapLayout.point("concert_to")
	var want := Rect2i(from, to - from + Vector2i.ONE)
	var r := _find_square(data, want)
	if r.size.x == 0:
		push_warning("[Concert] no dry ground near %s" % want)
		return -1
	_clear(data, r)
	var facing := _facing(data, r)
	var b := data.add_building(r, Kind.CONCERT, facing, SEED, 0.0)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := data.idx(x, y)
			data.deco[i] = AmenitiesPlanner.MUD
			data.forest[i] = 0
	var gate := gate_cell(r, facing)
	var steps := _footpath(data, gate + CityTypes.FACING_OFFSETS[facing])
	print("[Concert] camp at %s facing %s, footpath of %d cells" % [r, ["N", "E", "S", "W"][facing], steps])
	return b


## The cell of the camp's edge, in the middle of its front side, where the footpath arrives.
static func gate_cell(r: Rect2i, facing: int) -> Vector2i:
	var c := r.position + r.size / 2
	match facing:
		0: return Vector2i(c.x, r.position.y)
		1: return Vector2i(r.end.x - 1, c.y)
		2: return Vector2i(c.x, r.end.y - 1)
		_: return Vector2i(r.position.x, c.y)


## The wanted square, or the closest one of the same size on dry ground of the allowed zones.
static func _find_square(data: CityData, want: Rect2i) -> Rect2i:
	for radius in MAX_SHIFT + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(want.position + Vector2i(dx, dy), want.size)
				if _square_ok(data, r):
					return r
	return Rect2i()


static func _square_ok(data: CityData, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if data.terrain[i] < Terrain.BEACH or data.road[i] != 0 or not ZONES.has(int(data.zone[i])):
				return false
	return true


## Buildings on the square are taken away (they stay in the list as EMPTY).
static func _clear(data: CityData, r: Rect2i) -> void:
	for b in data.building_count():
		if data.b_kind[b] != Kind.EMPTY and data.building_rect(b).intersects(r):
			data.b_kind[b] = Kind.EMPTY


## The stage turns its back to the sea and its front (and the gate) to the city.
static func _facing(data: CityData, r: Rect2i) -> int:
	var to_city := Vector2(data.size, data.size) * 0.5 - Vector2(r.get_center())
	if absf(to_city.x) > absf(to_city.y):
		return 1 if to_city.x > 0.0 else 3
	return 2 if to_city.y > 0.0 else 0


## Shortest way over free dry land from `start` to the nearest road; its cells become the
## footpath (earth, no trees). Returns the number of cells, 0 when no road is in reach.
static func _footpath(data: CityData, start: Vector2i) -> int:
	if not data.in_bounds(start.x, start.y):
		return 0
	var taken := PackedByteArray()
	taken.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var br := data.building_rect(b)
		for y in range(br.position.y, br.end.y):
			for x in range(br.position.x, br.end.x):
				if data.in_bounds(x, y):
					taken[data.idx(x, y)] = 1
	var first := data.idx(start.x, start.y)
	if data.road[first] != 0:
		return 0
	if taken[first] == 1 or data.terrain[first] < Terrain.BEACH:
		return 0
	var prev := PackedInt32Array()
	prev.resize(data.size * data.size)
	prev.fill(-2)
	prev[first] = -1
	var queue := PackedInt32Array([first])
	var head := 0
	var goal := -1
	while head < queue.size() and goal < 0:
		var cur := queue[head]
		head += 1
		for o in CityTypes.FACING_OFFSETS:
			var nx := cur % data.size + o.x
			var ny := cur / data.size + o.y
			if not data.in_bounds(nx, ny):
				continue
			var ni := data.idx(nx, ny)
			if prev[ni] != -2 or data.terrain[ni] < Terrain.BEACH or taken[ni] == 1:
				continue
			prev[ni] = cur
			if data.road[ni] != 0:
				goal = cur
				break
			queue.append(ni)
	if goal < 0:
		return 0
	var steps := 0
	var at := goal
	while at >= 0:
		if data.deco[at] == 0:
			data.deco[at] = AmenitiesPlanner.TRAIL
		data.forest[at] = 0
		steps += 1
		at = prev[at]
	return steps
