class_name RoadPlanner
extends RefCounted
## Lays out the road network by recursively splitting the mainland into blocks
## (binary space partition). The first splits become avenues that cross the
## whole island; deeper splits become local streets. Blocks are the leaves.

const MAX_BRIDGE := 7          # longest water crossing turned into a bridge
const AVENUE_DEPTH := 3        # splits shallower than this are avenues
const MIN_HALF := 2            # smallest block side created by a split

var _cfg: CityConfig
var _data: CityData
var _island: IslandShaper
var _districts: DistrictPlanner
var _rng: RandomNumberGenerator

## Interior rectangles of all city blocks (cells between roads).
var blocks: Array[Rect2i] = []


func _init(cfg: CityConfig, data: CityData, island: IslandShaper,
		districts: DistrictPlanner, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_districts = districts
	_rng = rng


func build() -> void:
	var bounds := _mainland_bounds()
	_split(bounds, 0)
	_trim_dead_ends()
	blocks = blocks.filter(func(r: Rect2i) -> bool: return _has_land(r))


# --- BSP ----------------------------------------------------------------------------
func _split(r: Rect2i, depth: int) -> void:
	if r.size.x < 1 or r.size.y < 1:
		return
	var c := Vector2(r.get_center())
	if depth >= 2 and _max_density(r) < _cfg.urban_threshold:
		return # countryside: no local streets
	if not _has_land(r):
		return
	var lim := _districts.block_limits(c.x, c.y)
	var short_side := mini(r.size.x, r.size.y)
	var long_side := maxi(r.size.x, r.size.y)
	var vertical: bool # true = split line runs along Y (cuts the X axis)
	if long_side > lim.y:
		vertical = r.size.x >= r.size.y
	elif short_side > lim.x:
		vertical = r.size.x < r.size.y
	else:
		blocks.append(r)
		return
	var length := r.size.x if vertical else r.size.y
	if length < MIN_HALF * 2 + 1:
		blocks.append(r)
		return
	var lo := MIN_HALF
	var hi := length - MIN_HALF - 1
	var cut := clampi(int(round(length * _rng.randf_range(0.38, 0.62))), lo, hi)
	var road_type := CityTypes.ROAD_AVENUE if depth < AVENUE_DEPTH else CityTypes.ROAD_STREET
	if vertical:
		var x := r.position.x + cut
		_draw_line(Vector2i(x, r.position.y), Vector2i(0, 1), r.size.y, road_type)
		_split(Rect2i(r.position.x, r.position.y, cut, r.size.y), depth + 1)
		_split(Rect2i(x + 1, r.position.y, r.size.x - cut - 1, r.size.y), depth + 1)
	else:
		var y := r.position.y + cut
		_draw_line(Vector2i(r.position.x, y), Vector2i(1, 0), r.size.x, road_type)
		_split(Rect2i(r.position.x, r.position.y, r.size.x, cut), depth + 1)
		_split(Rect2i(r.position.x, y + 1, r.size.x, r.size.y - cut - 1), depth + 1)


## Draws a road line on land. Short water gaps become bridges, long ones are skipped.
func _draw_line(start: Vector2i, step: Vector2i, length: int, road_type: int) -> void:
	var run_start := -1 # first water cell of the current water run
	var seen_land := false
	for i in length:
		var p := start + step * i
		var land := _island.is_mainland(p.x, p.y) \
				and _data.terrain[_data.idx(p.x, p.y)] == CityTypes.Terrain.LAND
		if land:
			if run_start >= 0 and seen_land and i - run_start <= MAX_BRIDGE:
				for j in range(run_start, i):
					var q := start + step * j
					_set_road(q, road_type | CityTypes.ROAD_BRIDGE_FLAG)
			run_start = -1
			seen_land = true
			_set_road(p, road_type)
		elif run_start < 0:
			run_start = i


func _set_road(p: Vector2i, value: int) -> void:
	var i := _data.idx(p.x, p.y)
	var old := _data.road[i]
	# Avenues win over streets where lines cross.
	if old == 0 or (value & 3) > (old & 3):
		_data.road[i] = value


# --- Clean up ----------------------------------------------------------------------------
## Removes stubs of 1-2 cells that lead nowhere (left over by coast cuts).
func _trim_dead_ends() -> void:
	var size := _data.size
	for pass_i in 2:
		var removed := 0
		for y in size:
			for x in size:
				var i := y * size + x
				if _data.road[i] == 0:
					continue
				var m := _data.road_mask(x, y)
				if m == 0 or _is_short_stub(x, y, m):
					_data.road[i] = 0
					removed += 1
		if removed == 0:
			break


func _is_short_stub(x: int, y: int, mask: int) -> bool:
	# A dead end whose only neighbour is itself a dead end or a bridge.
	for d in 4:
		if mask == 1 << d:
			var o := CityTypes.FACING_OFFSETS[d]
			var nm := _data.road_mask(x + o.x, y + o.y)
			var bridge := _data.road[_data.idx(x, y)] & CityTypes.ROAD_BRIDGE_FLAG
			return nm == (1 << ((d + 2) % 4)) or bridge != 0
	return false


# --- Helpers ---------------------------------------------------------------------------------
func _mainland_bounds() -> Rect2i:
	var size := _data.size
	var mn := Vector2i(size, size)
	var mx := Vector2i(-1, -1)
	for y in range(0, size):
		for x in range(0, size):
			if _island.mainland[y * size + x] == 1:
				mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
				mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	if mx.x < 0:
		return Rect2i()
	return Rect2i(mn, mx - mn + Vector2i.ONE)


## Highest density sampled over a rectangle (big rects may be urban on one side only).
func _max_density(r: Rect2i) -> float:
	var best := 0.0
	var step := maxi(2, maxi(r.size.x, r.size.y) / 8)
	for y in range(r.position.y, r.end.y + 1, step):
		for x in range(r.position.x, r.end.x + 1, step):
			best = maxf(best, _districts.density(x, y))
	return best


func _has_land(r: Rect2i) -> bool:
	var step := maxi(1, mini(r.size.x, r.size.y) / 4)
	for y in range(r.position.y, r.end.y, step):
		for x in range(r.position.x, r.end.x, step):
			if _island.is_mainland(x, y) and _data.terrain[_data.idx(x, y)] == CityTypes.Terrain.LAND:
				return true
	return false
