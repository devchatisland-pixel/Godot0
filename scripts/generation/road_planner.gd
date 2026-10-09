class_name RoadPlanner
extends RefCounted
## Lays out the road network by recursively splitting the mainland into blocks
## (binary space partition). The first splits become avenues that cross the
## island; deeper splits become local streets. Blocks are the leaves.
## Reserved areas (the park and the desert) are cut out first: their borders
## become ring roads and no street goes through them.

const MAX_BRIDGE := 5          # longest water crossing turned into a bridge
const AVENUE_DEPTH := 2        # splits shallower than this are avenues
const MIN_HALF := 2            # smallest block side created by a free split

var _cfg: CityConfig
var _data: CityData
var _island: IslandShaper
var _districts: DistrictPlanner
var _rng: RandomNumberGenerator
var _reserved: Array[Rect2i] = []

## Interior rectangles of all city blocks (cells between roads).
var blocks: Array[Rect2i] = []
## Extension mode (new districts around the finished city): roads are only
## drawn on cells flagged 1 in this mask, and blocks use the given limits
## instead of the district anchors.
var free_mask := PackedByteArray()
var limits_override := Vector2i.ZERO


func _init(cfg: CityConfig, data: CityData, island: IslandShaper,
		districts: DistrictPlanner, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_districts = districts
	_rng = rng


func build() -> void:
	_reserved = _districts.exclusions()
	_split(_mainland_bounds(), 0)
	_trim_dead_ends()
	blocks = blocks.filter(func(r: Rect2i) -> bool: return _has_land(r))


# --- BSP ----------------------------------------------------------------------------
func _split(r: Rect2i, depth: int) -> void:
	if r.size.x < 1 or r.size.y < 1 or not _has_land(r):
		return
	for e in _reserved:
		if e.encloses(r):
			return # inside the park or the desert
	var forced := _reserved_cut(r)
	var vertical: bool # true = split line runs along Y (cuts the X axis)
	var cut: int
	if forced.x >= 0:
		vertical = forced.y == 1
		cut = forced.x
	else:
		var c := Vector2(r.get_center())
		var lim := limits_override if limits_override.x > 0 else _districts.block_limits(c.x, c.y)
		if maxi(r.size.x, r.size.y) > lim.y:
			vertical = r.size.x >= r.size.y
		elif mini(r.size.x, r.size.y) > lim.x:
			vertical = r.size.x < r.size.y
		else:
			blocks.append(r)
			return
		var length := r.size.x if vertical else r.size.y
		if length < MIN_HALF * 2 + 1:
			blocks.append(r)
			return
		cut = clampi(int(round(length * _rng.randf_range(0.38, 0.62))), MIN_HALF, length - MIN_HALF - 1)
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


## A cut along the border of a reserved area crossing `r`, as (offset, vertical)
## or (-1, 0) when none. Taking these cuts first turns the borders into ring roads.
func _reserved_cut(r: Rect2i) -> Vector2i:
	for e in _reserved:
		if not e.intersects(r):
			continue
		for x in [e.position.x - 1, e.end.x]:
			if x >= r.position.x and x < r.end.x:
				return Vector2i(x - r.position.x, 1)
		for y in [e.position.y - 1, e.end.y]:
			if y >= r.position.y and y < r.end.y:
				return Vector2i(y - r.position.y, 0)
	return Vector2i(-1, 0)


## Draws a road line on land. Short water gaps become bridges, long ones are skipped.
func _draw_line(start: Vector2i, step: Vector2i, length: int, road_type: int) -> void:
	var run_start := -1 # first water cell of the current water run
	var seen_land := false
	for i in length:
		var p := start + step * i
		if _is_reserved(p):
			run_start = -1
			seen_land = false
			continue
		var land := _island.is_mainland(p.x, p.y) \
				and _data.terrain[_data.idx(p.x, p.y)] == CityTypes.Terrain.LAND
		if land:
			if run_start >= 0 and seen_land and i - run_start <= MAX_BRIDGE:
				for j in range(run_start, i):
					_set_road(start + step * j, road_type | CityTypes.ROAD_BRIDGE_FLAG)
			run_start = -1
			seen_land = true
			_set_road(p, road_type)
		elif run_start < 0:
			run_start = i


func _is_reserved(p: Vector2i) -> bool:
	for e in _reserved:
		if e.has_point(p):
			return true
	return not free_mask.is_empty() and free_mask[_data.idx(p.x, p.y)] == 0


func _set_road(p: Vector2i, value: int) -> void:
	var i := _data.idx(p.x, p.y)
	var old := _data.road[i]
	# Avenues win over streets where lines cross.
	if old == 0 or (value & 3) > (old & 3):
		_data.road[i] = value


## Extension mode: splits `area` into blocks and draws its roads (the first
## splits are avenues, deeper ones streets). Dead ends are trimmed inside `area` only.
func build_region(area: Rect2i, limits: Vector2i, reserved: Array[Rect2i] = [],
		start_depth: int = 1) -> void:
	_reserved = reserved
	limits_override = limits
	var before := blocks.size()
	_split(area, start_depth)
	_trim_dead_ends(area)
	var fresh := blocks.slice(before).filter(func(r: Rect2i) -> bool: return _has_land(r))
	blocks = blocks.slice(0, before)
	blocks.append_array(fresh)


# --- Clean up ----------------------------------------------------------------------------
## Removes isolated cells and stubs of 1-2 cells that lead nowhere (inside `area`).
func _trim_dead_ends(area: Rect2i = Rect2i()) -> void:
	var size := _data.size
	var x0 := 0
	var y0 := 0
	var x1 := size
	var y1 := size
	if area.size.x > 0:
		x0 = maxi(area.position.x, 0)
		y0 = maxi(area.position.y, 0)
		x1 = mini(area.end.x, size)
		y1 = mini(area.end.y, size)
	for pass_i in 2:
		var removed := 0
		for y in range(y0, y1):
			for x in range(x0, x1):
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
	for y in size:
		for x in size:
			if _island.mainland[y * size + x] == 1:
				mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
				mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	if mx.x < 0:
		return Rect2i()
	return Rect2i(mn, mx - mn + Vector2i.ONE)


func _has_land(r: Rect2i) -> bool:
	var step := maxi(1, mini(r.size.x, r.size.y) / 4)
	for y in range(r.position.y, r.end.y, step):
		for x in range(r.position.x, r.end.x, step):
			if _island.is_mainland(x, y) and _data.terrain[_data.idx(x, y)] == CityTypes.Terrain.LAND:
				return true
	return false
