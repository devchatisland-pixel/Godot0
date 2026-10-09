class_name ExtensionPlanner
extends RefCounted
## The new districts around the finished city (see ExtensionIsland for the
## land they stand on). Nothing of the core city is moved or changed: every
## cell the core uses is left alone, roads and lots only go on free land.
##   west          a second desert next to Las Vegas, with mesas, ranches and
##                 oil pumps, and the poor district of panel blocks
##   south-west    the industrial zone
##   south         the red quarter grows (same lots, more variety)
##   south-east    farmland: crop fields and farms
##   north         mountains and forest
##   far north-west the prison island

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Areas without streets (cells of the big map).
const WEST_DESERT := Rect2i(8, 66, 38, 34)
const MOUNTAIN := Rect2i(52, 12, 56, 38)
const FARM := Rect2i(120, 132, 38, 40)
## Districts with streets: area, zone and block limits (short, long side).
const DISTRICTS := [
	{"rect": Rect2i(8, 102, 38, 24), "zone": Zone.POOR, "limits": Vector2i(4, 9)},
	{"rect": Rect2i(14, 128, 46, 30), "zone": Zone.INDUSTRIAL, "limits": Vector2i(5, 12)},
	{"rect": Rect2i(64, 136, 60, 36), "zone": Zone.QUARTER, "limits": Vector2i(4, 9)},
]
## Buildings placed in the blocks of the districts.
const SPECS := [
	{"kind": Kind.RUSSIAN, "size": Vector2i(4, 4), "count": 1, "near": "poor_center",
		"zones": [Zone.POOR]},
]

var counts := {}
var block_count := 0

var _cfg: CityConfig
var _data: CityData
var _island: ExtensionIsland
var _rng: RandomNumberGenerator
var _districts: DistrictPlanner
var _lots: LotPlanner
var _services: ServicePlanner
var _core_used := PackedByteArray()


func _init(cfg: CityConfig, data: CityData, island: ExtensionIsland, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_rng = rng


func build() -> void:
	_districts = DistrictPlanner.new(_cfg, _data, _island)
	_districts.plan()
	# Cells the core city uses (buildings, parks, plots, its own desert): off limits.
	_core_used.resize(_data.zone.size())
	for i in _core_used.size():
		_core_used[i] = 0 if _is_open(i) else 1
	_paint_new_land()
	_paint_open_areas()
	var core_roads := _data.road.duplicate()

	# Streets of the districts, only on free land.
	var roads := RoadPlanner.new(_cfg, _data, _island, _districts, _rng)
	roads.free_mask = _free_mask()
	var zones := PackedByteArray()
	for d in DISTRICTS:
		var before := roads.blocks.size()
		roads.build_region(d["rect"], d["limits"])
		for b in range(before, roads.blocks.size()):
			zones.append(d["zone"])
		_districts.anchors[_anchor_name(d["zone"])] = Vector2(Rect2i(d["rect"]).get_center())
	block_count = roads.blocks.size()
	for d in DISTRICTS:
		_link_to_city(d["rect"], core_roads)

	# Lots (never over what the core already built), zoning, public buildings.
	_lots = LotPlanner.new(_cfg, _data, _districts, _rng)
	for i in _core_used.size():
		if _core_used[i] == 1:
			_lots.owner[i] = -2
	_lots.build(roads.blocks, zones)
	_paint_blocks(roads.blocks, zones)
	_services = ServicePlanner.new(_cfg, _data, _districts, _lots)
	_services.build_specs(SPECS, roads.blocks, zones)

	_build_west_desert()
	_build_mountains()
	_build_farms()
	_build_beach_stalls()
	_build_prison()
	_services.finish()
	for k in _services.counts:
		counts[k] = counts.get(k, 0) + _services.counts[k]


func _anchor_name(zone: int) -> String:
	return {Zone.POOR: "poor_center", Zone.INDUSTRIAL: "industrial_center",
			Zone.QUARTER: "quarter_south_center"}.get(zone, "ext_%d" % zone)


# --- Land and zones -------------------------------------------------------------------------
## New land that the core did not have: meadows on the mainland, islets, the prison island.
func _paint_new_land() -> void:
	for y in _data.size:
		for x in _data.size:
			var i := _data.idx(x, y)
			if _data.terrain[i] < Terrain.BEACH or _data.zone[i] != Zone.NONE:
				continue
			if _island.is_mainland(x, y):
				_data.zone[i] = Zone.NATURE
			elif _island.is_prison_island(x, y):
				_data.zone[i] = Zone.PRISON
			else:
				_data.zone[i] = Zone.ISLET


## The desert, the farmland and the mountain forest (no streets inside).
func _paint_open_areas() -> void:
	_paint(WEST_DESERT, Zone.DESERT, 0)
	_paint(FARM, Zone.FARM, 0)
	_paint(MOUNTAIN, Zone.NATURE, 225)


func _paint(area: Rect2i, zone: int, forest: int) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or not _is_open(i):
				continue
			_data.zone[i] = zone
			if forest > 0:
				_data.forest[i] = forest
			elif zone != Zone.NATURE:
				_data.forest[i] = 0


## Free for the extension: land that is not used by the core (or by a district).
func _is_open(i: int) -> bool:
	return _data.zone[i] == Zone.NONE or _data.zone[i] == Zone.NATURE


func _free_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(_data.size * _data.size)
	for i in mask.size():
		mask[i] = 1 if _is_open(i) and _data.road[i] == 0 else 0
	return mask


func _paint_blocks(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	for b in blocks.size():
		var r := blocks[b]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := _data.idx(x, y)
				if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _lots.owner[i] != -2:
					_data.zone[i] = zones[b]


# --- Roads to the city ----------------------------------------------------------------------
## Joins the streets of a district to the nearest road of the old city with
## the shortest way over free land (breadth first search over the grid).
func _link_to_city(area: Rect2i, core_roads: PackedByteArray) -> void:
	var start := -1
	var best := INF
	var center := Vector2(area.get_center())
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var i := _data.idx(x, y)
			if _data.road[i] != 0 and core_roads[i] == 0:
				var d := center.distance_squared_to(Vector2(x, y))
				if d < best:
					best = d
					start = i
	if start < 0:
		return
	var n := _data.size * _data.size
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-2)
	prev[start] = -1
	var queue := PackedInt32Array([start])
	var head := 0
	var goal := -1
	while head < queue.size() and goal < 0:
		var cur := queue[head]
		head += 1
		var cx := cur % _data.size
		var cy := cur / _data.size
		for o in CityTypes.FACING_OFFSETS:
			var nx := cx + o.x
			var ny := cy + o.y
			if not _data.in_bounds(nx, ny):
				continue
			var ni := _data.idx(nx, ny)
			if prev[ni] != -2 or _data.terrain[ni] != Terrain.LAND:
				continue
			if core_roads[ni] != 0:
				prev[ni] = cur
				goal = ni
				break
			if _data.road[ni] == 0 and not _is_open(ni) and _data.zone[ni] != Zone.DESERT:
				continue
			prev[ni] = cur
			queue.append(ni)
	var at := goal
	while at >= 0 and prev[at] >= 0:
		if _data.road[at] == 0:
			_data.road[at] = CityTypes.ROAD_AVENUE
		at = prev[at]


# --- Features ---------------------------------------------------------------------------------
func _build_west_desert() -> void:
	for r in _spots(WEST_DESERT, Zone.DESERT, Vector2i(6, 4), 3, 13.0, 1):
		_claim(r, Kind.MESA, 2)
	var i := 0
	for r in _spots(WEST_DESERT, Zone.DESERT, Vector2i(2, 2), 4, 9.0, 2):
		_claim(r, Kind.OUTPOST, 2, -1, i * 3)
		i += 1
	for r in _spots(WEST_DESERT, Zone.DESERT, Vector2i(2, 2), 9, 6.0, 1):
		_claim(r, Kind.OIL_PUMP, 2)


func _build_mountains() -> void:
	var i := 0
	for r in _spots(MOUNTAIN, Zone.NATURE, Vector2i(7, 7), 11, 7.5, 0, 1500):
		_claim(r, Kind.MOUNTAIN, 2, -1, i * 8)
		i += 1


## Farm houses and barns, then crop fields tiled over the rest, with a path of
## bare soil between them.
func _build_farms() -> void:
	var yards: Array[Rect2i] = _spots(FARM, Zone.FARM, Vector2i(2, 2), 3, 16.0, 2, 900)
	var k := 0
	for y in yards:
		_claim(y, Kind.OUTPOST, 2, Zone.CIVIC, k * 3)
		k += 1
		for o in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0)]:
			var r := Rect2i(y.position + o, Vector2i(2, 2))
			if _spot_free(r, Zone.FARM, 0):
				_claim(r, Kind.OUTPOST, 2, Zone.CIVIC, k * 3 + 1)
				k += 1
				break
	var y := FARM.position.y + 1
	while y + 4 < FARM.end.y:
		var h := _rng.randi_range(4, 6)
		var x := FARM.position.x + 1
		while x + 4 < FARM.end.x:
			var w := _rng.randi_range(5, 8)
			var field := _shrink_to_fit(x, y, mini(w, FARM.end.x - x - 1), h)
			if field.size.x > 0:
				_claim(field, Kind.FIELD, 2, Zone.FARM, _rng.randi())
			x += w + 1
		y += h + 1


## The biggest field starting at (x, y), at most w x h, that fits on the free farmland.
func _shrink_to_fit(x: int, y: int, w: int, h: int) -> Rect2i:
	for dw in range(0, w - 3):
		for dh in range(0, h - 3):
			var r := Rect2i(x, y, w - dw, h - dh)
			if _spot_free(r, Zone.FARM, 0):
				return r
	return Rect2i()


## Ice cream and food stalls on the meadow behind the beaches of the south coast.
func _build_beach_stalls() -> void:
	var placed: Array[Vector2] = []
	var i := 0
	for y in range(112, 185):
		for x in range(40, 160):
			if placed.size() >= 14 or not _beach_edge(x, y):
				continue
			var c := Vector2(x, y)
			if placed.any(func(p: Vector2) -> bool: return p.distance_to(c) < 6.0):
				continue
			var r := Rect2i(x, y, 1, 1)
			if _spot_free(r, Zone.NATURE, 0):
				placed.append(c)
				_claim(r, Kind.STALL, 2, -1, i * 5)
				i += 1


## A dry cell with sea sand to the south or east: where the camera sees a stall from the front.
func _beach_edge(x: int, y: int) -> bool:
	if not _data.in_bounds(x + 1, y + 1) or _data.terrain[_data.idx(x, y)] != Terrain.LAND:
		return false
	return _data.terrain[_data.idx(x, y + 1)] == Terrain.BEACH or _data.terrain[_data.idx(x + 1, y)] == Terrain.BEACH


## The prison compound: a big cellhouse, stone wings, a villa and lighthouses.
func _build_prison() -> void:
	var c := Vector2i(ExtensionIsland.PRISON["at"])
	var main := _find_spot(c + Vector2i(-3, -2), Vector2i(7, 5), Zone.PRISON, 7, 0)
	if main.size.x > 0:
		_claim(main, Kind.PRISON, 2)
	var wings := [Vector2i(3, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 3)]
	var offsets := [Vector2i(-8, -6), Vector2i(4, -7), Vector2i(-10, 1), Vector2i(6, 4), Vector2i(-3, 7), Vector2i(10, -2)]
	for i in wings.size():
		var near: Vector2i = (main.position if main.size.x > 0 else c) + offsets[i]
		var r := _find_spot(near, wings[i], Zone.PRISON, 5, 0)
		if r.size.x > 0:
			_claim(r, Kind.PRISON_WING, 2, -1, i)
	for o in [Vector2i(-11, -5), Vector2i(10, 4)]:
		var r := _find_spot(c + o, Vector2i.ONE, Zone.PRISON, 4, 0)
		if r.size.x > 0:
			_claim(r, Kind.LIGHTHOUSE, 2)


# --- Helpers ------------------------------------------------------------------------------------
func _claim(r: Rect2i, kind: int, facing: int, zone: int = -1, seed: int = -1) -> void:
	_services.claim(r, kind, facing, zone, seed)
	counts[kind] = counts.get(kind, 0) + 1


## Random free rectangles of `size` in `area` (cells of `zone`), at least `gap`
## apart and with `margin` free cells around them.
func _spots(area: Rect2i, zone: int, size: Vector2i, count: int, gap: float, margin: int,
		tries: int = 600) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for t in tries:
		if out.size() >= count:
			break
		var r := Rect2i(_rng.randi_range(area.position.x, maxi(area.end.x - size.x, area.position.x)),
				_rng.randi_range(area.position.y, maxi(area.end.y - size.y, area.position.y)), size.x, size.y)
		if not _spot_free(r, zone, margin):
			continue
		var c := Vector2(r.get_center())
		if out.any(func(q: Rect2i) -> bool: return Vector2(q.get_center()).distance_to(c) < gap):
			continue
		out.append(r)
	return out


## Closest free rectangle around `near` (same test as _spots).
func _find_spot(near: Vector2i, size: Vector2i, zone: int, max_radius: int, margin: int) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(near + Vector2i(dx, dy), size)
				if _spot_free(r, zone, margin):
					return r
	return Rect2i()


func _spot_free(r: Rect2i, zone: int, margin: int) -> bool:
	for y in range(r.position.y - margin, r.end.y + margin):
		for x in range(r.position.x - margin, r.end.x + margin):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			var inside := r.has_point(Vector2i(x, y))
			if inside:
				if _data.terrain[i] != Terrain.LAND or _data.zone[i] != zone \
						or _data.road[i] != 0 or _lots.owner[i] != -1:
					return false
			elif _data.road[i] != 0 or _lots.owner[i] >= 0:
				return false
	return true
