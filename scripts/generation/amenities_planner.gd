class_name AmenitiesPlanner
extends RefCounted
## Ground details added once the whole map is built, written into two layers of CityData:
##   deco  the central park (paths from the streets to the fountain, a ring round the lake,
##         benches, flowerbeds, a playground) and the boardwalk of the red district;
##   edge  how close a cell is to the border between desert and meadow, so the colours
##         blend and dry tufts and rocks can be scattered there.
## Nothing here moves a building: only free cells are used.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Values of CityData.deco.
const PATH := 1
const BENCH_X := 2
const BENCH_Z := 3
const FLOWER := 4
const PLAY := 5          # a cell of the playground (no trees)
const PLAY_CENTER := 6   # the top-left cell of the middle 2x2 of the playground (draws it)
const BOARD := 7
const BOARD_LAMP := 8
const FENCE_X := 9      # a piece of fence along X
const FENCE_Z := 10     # a piece of fence along Z

## Half-width of the area searched for the park round its lake.
const PARK_REACH := 48
## Boardwalk: width in cells inland of the sand, how far from the red district it goes,
## and a lamp every this many cells (a hash picks them).
const BOARD_WIDTH := 2
const BOARD_REACH := 14
const LAMP_EVERY := 7
## Biome border: how many cells the blend reaches on each side.
const EDGE_REACH_MEADOW := 4
const EDGE_REACH_DESERT := 3

var _data: CityData
var _taken := PackedByteArray()


static func apply(data: CityData) -> void:
	var p := AmenitiesPlanner.new()
	p._data = data
	p._run()


func _run() -> void:
	_taken.resize(_data.size * _data.size)
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.EMPTY:
			continue
		var r := _data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_taken[_data.idx(x, y)] = 1
	_park()
	_boardwalk()
	_biome_edge()
	_fences()


# --- Central park ---------------------------------------------------------------------------
func _park() -> void:
	var lake := Rect2i()
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.POND:
			lake = _data.building_rect(b)
	if lake.size.x <= 0:
		return
	var c := lake.get_center()
	# The park: the park ground (and its crossing paths) round the lake.
	var park := Rect2i(c, Vector2i.ONE)
	for y in range(c.y - PARK_REACH, c.y + PARK_REACH):
		for x in range(c.x - PARK_REACH, c.x + PARK_REACH):
			if _data.in_bounds(x, y) and _data.zone[_data.idx(x, y)] == Zone.PARK:
				park = park.expand(Vector2i(x, y))
	# Two wide paths cross the park through the lake; a ring path goes round the lake.
	for x in range(park.position.x, park.end.x):
		_path(Vector2i(x, c.y - 1))
		_path(Vector2i(x, c.y))
	for y in range(park.position.y, park.end.y):
		_path(Vector2i(c.x - 1, y))
		_path(Vector2i(c.x, y))
	var ring := lake.grow(2)
	for x in range(ring.position.x, ring.end.x):
		_path(Vector2i(x, ring.position.y))
		_path(Vector2i(x, ring.end.y - 1))
	for y in range(ring.position.y, ring.end.y):
		_path(Vector2i(ring.position.x, y))
		_path(Vector2i(ring.end.x - 1, y))
	# Diagonal paths from the corners of the ring to the corners of the park.
	for s in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var corner := Vector2i(ring.position.x if s.x < 0 else ring.end.x - 1,
				ring.position.y if s.y < 0 else ring.end.y - 1)
		var p := corner
		while park.has_point(p):
			_path(p)
			_path(p + Vector2i(s.x, 0))
			p += s
	# Benches along the arms of the cross, on both sides, every six cells.
	for k in range(6, PARK_REACH, 6):
		for sgn in [-1, 1]:
			_put(Vector2i(c.x + sgn * k, c.y - 2), BENCH_X)
			_put(Vector2i(c.x + sgn * (k + 3), c.y + 1), BENCH_X)
			_put(Vector2i(c.x - 2, c.y + sgn * k), BENCH_Z)
			_put(Vector2i(c.x + 1, c.y + sgn * (k + 3)), BENCH_Z)
	# Flowerbeds in the four quarters, a playground in the first quarter with room for it.
	for o in [Vector2i(-9, -7), Vector2i(8, -7), Vector2i(-9, 6), Vector2i(8, 6)]:
		for dy in 2:
			for dx in 2:
				_put(c + o + Vector2i(dx, dy), FLOWER)
	# The playground: the free 3x3 square of park ground closest to the lake, 5+ cells away.
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(park.position.y, park.end.y - 2):
		for x in range(park.position.x, park.end.x - 2):
			var d := Vector2(x + 1 - c.x, y + 1 - c.y).length()
			if d >= 5.0 and d < best_d and _play_free(Vector2i(x, y)):
				best_d = d
				best = Vector2i(x, y)
	if best.x >= 0:
		for dy in 3:
			for dx in 3:
				_data.deco[_data.idx(best.x + dx, best.y + dy)] = PLAY
		_data.deco[_data.idx(best.x + 1, best.y + 1)] = PLAY_CENTER


func _path(p: Vector2i) -> void:
	if not _data.in_bounds(p.x, p.y):
		return
	var i := _data.idx(p.x, p.y)
	var z := _data.zone[i]
	if (z == Zone.PARK or z == Zone.CIVIC) and _data.road[i] == 0 and _taken[i] == 0:
		_data.deco[i] = PATH


## Puts `value` on a free park cell (not a path, not a building).
func _put(p: Vector2i, value: int) -> void:
	if not _data.in_bounds(p.x, p.y):
		return
	var i := _data.idx(p.x, p.y)
	if _data.zone[i] == Zone.PARK and _data.road[i] == 0 and _taken[i] == 0 and _data.deco[i] == 0:
		_data.deco[i] = value


## True when the 3x3 square at `at` (top-left) is all free park ground.
func _play_free(at: Vector2i) -> bool:
	for dy in 3:
		for dx in 3:
			var i := _data.idx(at.x + dx, at.y + dy)
			if _data.zone[i] != Zone.PARK or _data.road[i] != 0 or _taken[i] == 1 or _data.deco[i] != 0:
				return false
	return true


# --- Boardwalk of the red district --------------------------------------------------------------
func _boardwalk() -> void:
	var quarter := Rect2i()
	var found := false
	for y in _data.size:
		for x in _data.size:
			if _data.zone[_data.idx(x, y)] == Zone.QUARTER:
				quarter = Rect2i(x, y, 1, 1) if not found else quarter.expand(Vector2i(x, y))
				found = true
	if not found:
		return
	var area := quarter.grow(BOARD_REACH)
	for y in range(maxi(area.position.y, 1), mini(area.end.y, _data.size - 1)):
		for x in range(maxi(area.position.x, 1), mini(area.end.x, _data.size - 1)):
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 or _taken[i] == 1 \
					or _data.deco[i] != 0:
				continue
			var z := _data.zone[i]
			if z != Zone.QUARTER and z != Zone.NATURE and z != Zone.SAND:
				continue
			if _near_beach(x, y, BOARD_WIDTH):
				_data.deco[i] = BOARD_LAMP if CityTypes.hash2(x, y, 31) % LAMP_EVERY == 0 else BOARD


## True when a sandy (not rocky) beach cell is within `dist` cells.
func _near_beach(x: int, y: int, dist: int) -> bool:
	for dy in range(-dist, dist + 1):
		for dx in range(-dist, dist + 1):
			if _data.in_bounds(x + dx, y + dy):
				var j := _data.idx(x + dx, y + dy)
				if _data.terrain[j] == Terrain.BEACH and _data.rocky[j] == 0:
					return true
	return false


# --- Border between the desert and the meadows -------------------------------------------------
## Breadth first from the border cells: edge = 4 at the border, 1 at the farthest cell.
func _biome_edge() -> void:
	var n := _data.size * _data.size
	var queue := PackedInt32Array()
	var dist := PackedByteArray()
	dist.resize(n)
	for y in range(1, _data.size - 1):
		for x in range(1, _data.size - 1):
			var i := _data.idx(x, y)
			var z := _data.zone[i]
			if _data.terrain[i] != Terrain.LAND or (z != Zone.DESERT and z != Zone.NATURE):
				continue
			for o in CityTypes.FACING_OFFSETS:
				var zn := _data.zone[_data.idx(x + o.x, y + o.y)]
				if (z == Zone.DESERT and zn == Zone.NATURE) or (z == Zone.NATURE and zn == Zone.DESERT):
					dist[i] = 1
					queue.append(i)
					break
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var d := dist[i]
		var desert := _data.zone[i] == Zone.DESERT
		var reach := EDGE_REACH_DESERT if desert else EDGE_REACH_MEADOW
		if d >= reach:
			continue
		var x := i % _data.size
		var y := i / _data.size
		for o in CityTypes.FACING_OFFSETS:
			if not _data.in_bounds(x + o.x, y + o.y):
				continue
			var j := _data.idx(x + o.x, y + o.y)
			if dist[j] == 0 and _data.zone[j] == _data.zone[i] and _data.terrain[j] == Terrain.LAND:
				dist[j] = d + 1
				queue.append(j)
	for i in n:
		if dist[i] != 0:
			var reach := EDGE_REACH_DESERT if _data.zone[i] == Zone.DESERT else EDGE_REACH_MEADOW
			var closeness := reach + 1 - dist[i]
			_data.edge[i] = closeness | (0x80 if _data.zone[i] == Zone.DESERT else 0)


# --- Fences -------------------------------------------------------------------------------------------
## The fence round the secret base: the lot of the airbase grown by 3 cells, with a gate in the
## middle of the west side and one in the middle of the south side (cells just inside the fence).
static func base_fence(base: Rect2i) -> Dictionary:
	var ring := base.grow(3)
	var west := Vector2i(ring.position.x, ring.get_center().y)
	var south := Vector2i(ring.get_center().x, ring.end.y - 1)
	return {"rect": ring, "gates": [west, south]}


func _fences() -> void:
	# The secret base.
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.AIRBASE:
			var f := base_fence(_data.building_rect(b))
			var gates: Array = f["gates"]
			_fence_ring(f["rect"], [gates[0], gates[0] + Vector2i(0, 1), gates[1], gates[1] + Vector2i(1, 0)])
	# The facility of the BT tower islet: everything built on the islet, grown by one cell.
	var islet := Rect2i()
	var any := false
	var at := Vector2i(ExtensionIsland.TOWER_ISLET["at"])
	for b in _data.building_count():
		var r := _data.building_rect(b)
		if _data.b_kind[b] != Kind.EMPTY and absi(r.get_center().x - at.x) < 16 and absi(r.get_center().y - at.y) < 10:
			islet = r if not any else islet.merge(r)
			any = true
	if any:
		_fence_ring(islet.grow(1), [])


## Fence cells along the border of `ring` on dry, free cells, except the `gaps`.
func _fence_ring(ring: Rect2i, gaps: Array) -> void:
	for x in range(ring.position.x, ring.end.x):
		_fence_cell(Vector2i(x, ring.position.y), FENCE_X, gaps)
		_fence_cell(Vector2i(x, ring.end.y - 1), FENCE_X, gaps)
	for y in range(ring.position.y + 1, ring.end.y - 1):
		_fence_cell(Vector2i(ring.position.x, y), FENCE_Z, gaps)
		_fence_cell(Vector2i(ring.end.x - 1, y), FENCE_Z, gaps)


func _fence_cell(p: Vector2i, value: int, gaps: Array) -> void:
	if gaps.has(p) or not _data.in_bounds(p.x, p.y):
		return
	var i := _data.idx(p.x, p.y)
	if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _taken[i] == 0 and _data.deco[i] == 0:
		_data.deco[i] = value
