class_name ExtensionPlanner
extends RefCounted
## Everything around the finished city (see ExtensionIsland for the land).
## Nothing of the core city is moved or changed: roads and lots only go on
## free land. Special places are kept far from each other on purpose.
##   west          the desert next to Las Vegas, with the secret base ("area 51"),
##                 mesas, ranches and oil pumps; the industrial zone (exactly 8
##                 different buildings) beside it
##   north         the poor district, just behind the skyscrapers
##   south         the red quarter grows towards the beach, with the ferris wheel
##   all around    farmland: fields and farms spread over the whole island,
##                 never next to the desert, and patches of forest
##   far north-west the prison island

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Areas without streets inside (cells of the big map).
const DESERT := Rect2i(34, 112, 56, 62)
const INDUSTRIAL := Rect2i(58, 180, 44, 24)
## The poor district: small, right behind the skyscrapers.
const POOR := Rect2i(108, 76, 30, 18)
## The red quarter grows south, down to the beach; the ferris wheel has its own plot.
const QUARTER := Rect2i(112, 190, 76, 46)
const FERRIS_PLOT := Rect2i(156, 226, 6, 6)
## Farmland patches spread over the island (none near the desert) and forests.
const FARMS := [
	Rect2i(28, 48, 52, 52), Rect2i(100, 22, 60, 44), Rect2i(168, 26, 62, 50),
	Rect2i(214, 70, 50, 50), Rect2i(216, 152, 52, 52), Rect2i(150, 214, 56, 28),
	Rect2i(212, 206, 34, 30), Rect2i(30, 196, 26, 36),
]
const FORESTS := [Rect2i(84, 18, 40, 28), Rect2i(236, 104, 30, 32), Rect2i(60, 212, 30, 24)]
## The 8 buildings of the industrial zone: sizes in cells.
const FACTORY_SIZES := [Vector2i(7, 4), Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 3),
		Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 3), Vector2i(3, 3)]
## Buildings placed in the blocks of the districts.
const SPECS := [
	{"kind": Kind.RUSSIAN, "size": Vector2i(4, 4), "count": 1, "near": "poor_center",
		"zones": [Zone.POOR]},
]
const AIRBASE_SIZES := [Vector2i(16, 5), Vector2i(14, 5), Vector2i(12, 4)]

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
var _network := PackedByteArray()


func _init(cfg: CityConfig, data: CityData, island: ExtensionIsland, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_rng = rng


func build() -> void:
	_districts = DistrictPlanner.new(_cfg, _data, _island)
	_districts.plan()
	# Cells the core city uses (buildings, parks, plots, its forest road...): off limits.
	_core_used.resize(_data.zone.size())
	for i in _core_used.size():
		_core_used[i] = 0 if _is_open(i) else 1
	_paint_new_land()
	_network = _data.road.duplicate()
	_build_highway()
	_paint_open_areas()

	# Streets of the poor district and of the red quarter, only on free land.
	var roads := RoadPlanner.new(_cfg, _data, _island, _districts, _rng)
	roads.free_mask = _free_mask()
	var zones := PackedByteArray()
	var plans := [
		{"rect": POOR, "zone": Zone.POOR, "limits": Vector2i(4, 8), "reserved": [] as Array[Rect2i]},
		{"rect": QUARTER, "zone": Zone.QUARTER, "limits": Vector2i(4, 9), "reserved": [FERRIS_PLOT] as Array[Rect2i]},
	]
	for d in plans:
		var before := roads.blocks.size()
		roads.build_region(d["rect"], d["limits"], d["reserved"])
		for b in range(before, roads.blocks.size()):
			zones.append(d["zone"])
		var area: Rect2i = d["rect"]
		_districts.anchors[_anchor_name(d["zone"])] = Vector2(area.get_center())
		_link(_road_nearest_to_city(area))
	block_count = roads.blocks.size()
	for area in [DESERT, INDUSTRIAL]:
		_ring_road(area)
		_link(_road_nearest_to_city(area.grow(1)))
	for area in FARMS:
		_link(_land_nearest_to_city(area))

	# Lots (never over what the core already built), zoning, public buildings.
	_lots = LotPlanner.new(_cfg, _data, _districts, _rng)
	for i in _core_used.size():
		if _core_used[i] == 1:
			_lots.owner[i] = -2
	_lots.build(roads.blocks, zones)
	_paint_blocks(roads.blocks, zones)
	_services = ServicePlanner.new(_cfg, _data, _districts, _lots)
	_services.build_specs(SPECS, roads.blocks, zones)
	_claim_ferris_wheel()
	_build_drive_in_if_missing(roads.blocks, zones)

	_build_desert()
	_build_industrial()
	_build_farms()
	_build_beach_stalls()
	_build_prison()
	_services.finish()
	for k in _services.counts:
		counts[k] = counts.get(k, 0) + _services.counts[k]


func _anchor_name(zone: int) -> String:
	return {Zone.POOR: "poor_center", Zone.QUARTER: "quarter_south_center"}.get(zone, "ext_%d" % zone)


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


## Desert, industrial ground, farmland and forests (no streets inside).
func _paint_open_areas() -> void:
	_paint(DESERT, Zone.DESERT, 0)
	_paint(INDUSTRIAL, Zone.INDUSTRIAL, 0)
	for a in FARMS:
		_paint(a, Zone.FARM, 0)
	for a in FORESTS:
		_paint(a, Zone.NATURE, 225)


func _paint(area: Rect2i, zone: int, forest: int) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or not _is_open(i) or _data.road[i] != 0:
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


# --- Highway to the Golden Gate bridge ------------------------------------------------------
## Three lanes wide, like the bridge: from the end of the core's road to the east
## coast. The bridge starts where the highway reaches the water.
func _build_highway() -> void:
	var start := _data.bridge
	if start.x < 0:
		return
	var x := start.x
	var last := x
	while x < _data.size - 2 and _data.terrain[_data.idx(x, start.y)] == Terrain.LAND:
		for dy in range(-1, 2):
			var i := _data.idx(x, start.y + dy)
			if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _is_open(i):
				_data.road[i] = CityTypes.ROAD_AVENUE
				_network[i] = 1
		last = x
		x += 1
	_data.bridge = Vector2i(last + 1, start.y)


# --- Roads to the city ----------------------------------------------------------------------
func _road_nearest_to_city(area: Rect2i) -> int:
	var center := Vector2(_data.size, _data.size) * 0.5
	return _nearest(area, center, true)


func _land_nearest_to_city(area: Rect2i) -> int:
	var center := Vector2(_data.size, _data.size) * 0.5
	return _nearest(area, center, false)


## The road cell (or free land cell) of `area` closest to `target`, -1 when none.
func _nearest(area: Rect2i, target: Vector2, want_road: bool) -> int:
	var best := -1
	var best_d := INF
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			var ok := (_data.road[i] != 0 and _network[i] == 0) if want_road \
					else (_data.terrain[i] == Terrain.LAND and _data.road[i] == 0)
			if ok:
				var d := target.distance_squared_to(Vector2(x, y))
				if d < best_d:
					best_d = d
					best = i
	return best


## Joins `start` to the road network with the shortest way over free land
## (breadth first search). Everything on the way becomes part of the network.
func _link(start: int) -> void:
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
			if _network[ni] != 0:
				prev[ni] = cur
				goal = ni
				break
			var z := _data.zone[ni]
			if _data.road[ni] == 0 and z != Zone.NONE and z != Zone.NATURE and z != Zone.DESERT \
					and z != Zone.FARM and z != Zone.INDUSTRIAL:
				continue
			prev[ni] = cur
			queue.append(ni)
	if goal < 0:
		return
	var at := goal
	while at >= 0:
		if _data.road[at] == 0:
			_data.road[at] = CityTypes.ROAD_STREET
		_network[at] = 1
		at = prev[at]


## A road all around `area` (on free land), like the ring roads of the park.
func _ring_road(area: Rect2i) -> void:
	var ring := area.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			if area.has_point(Vector2i(x, y)) or not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			if _data.terrain[i] == Terrain.LAND and _is_open(i) and _data.road[i] == 0:
				_data.road[i] = CityTypes.ROAD_AVENUE


# --- Features ---------------------------------------------------------------------------------
func _claim_ferris_wheel() -> void:
	if _spot_free_plot(FERRIS_PLOT):
		_claim(FERRIS_PLOT, Kind.FERRIS_WHEEL, 2, Zone.CIVIC)


func _spot_free_plot(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 or _lots.owner[i] == -2:
				return false
	return true


## Only when the core's red quarter had no room for it.
func _build_drive_in_if_missing(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.DRIVE_IN:
			return
	_services.build_specs([{"kind": Kind.DRIVE_IN, "size": Vector2i(4, 3), "count": 1,
			"near": "quarter_south_center", "zones": [Zone.QUARTER]}], blocks, zones)


## The desert next to Las Vegas: the secret base (airbase, bunker, radio station), mesas,
## ranches and oil pumps, far apart from each other.
func _build_desert() -> void:
	var c := DESERT.get_center()
	for size in AIRBASE_SIZES:
		var r := _find_spot(c + Vector2i(-size.x / 2, -8), size, Zone.DESERT, 16, 2)
		if r.size.x > 0:
			_claim(r, Kind.AIRBASE, 2, Zone.CIVIC)
			break
	var bunker := _find_spot(c + Vector2i(14, 10), Vector2i(3, 3), Zone.DESERT, 12, 3)
	if bunker.size.x > 0:
		_claim(bunker, Kind.BUNKER, 2, Zone.CIVIC)
	var tower := _find_spot(c + Vector2i(-14, 14), Vector2i(2, 2), Zone.DESERT, 12, 2)
	if tower.size.x > 0:
		_claim(tower, Kind.TELECOM_TOWER, 2, Zone.CIVIC)
		for o in [Vector2i(4, -1), Vector2i(4, 3), Vector2i(0, 4)]:
			var d := Rect2i(tower.position + o, Vector2i(2, 2))
			if _spot_free(d, Zone.DESERT, 0):
				_claim(d, Kind.SAT_DISH, 3, Zone.CIVIC)
	for r in _spots(DESERT, Zone.DESERT, Vector2i(6, 4), 2, 20.0, 1):
		_claim(r, Kind.MESA, 2)
	var i := 0
	for r in _spots(DESERT, Zone.DESERT, Vector2i(2, 2), 3, 14.0, 2):
		_claim(r, Kind.OUTPOST, 2, -1, i * 3)
		i += 1
	for r in _spots(DESERT, Zone.DESERT, Vector2i(2, 2), 8, 9.0, 1):
		_claim(r, Kind.OIL_PUMP, 2)


## The industrial zone: exactly 8 different buildings (variant 0..7) and a few yards.
func _build_industrial() -> void:
	for i in FACTORY_SIZES.size():
		var r := _spots_one(INDUSTRIAL, Zone.INDUSTRIAL, FACTORY_SIZES[i], 1)
		if r.size.x > 0:
			_claim(r, Kind.FACTORY_BLDG, 2, -1, i)
	for k in 4:
		var y := _spots_one(INDUSTRIAL, Zone.INDUSTRIAL, Vector2i(2, 2), 0)
		if y.size.x > 0:
			_claim(y, Kind.INDUSTRIAL_YARD, 2, -1, k)


## Farm houses and barns, then crop fields tiled over each patch of farmland.
func _build_farms() -> void:
	var k := 0
	for area: Rect2i in FARMS:
		for yard in _spots(area, Zone.FARM, Vector2i(2, 2), 2, 16.0, 2, 500):
			_claim(yard, Kind.OUTPOST, 2, Zone.CIVIC, k * 3)
			k += 1
			var side := Rect2i(yard.position + Vector2i(3, 0), Vector2i(2, 2))
			if _spot_free(side, Zone.FARM, 0):
				_claim(side, Kind.OUTPOST, 2, Zone.CIVIC, k * 3 + 1)
				k += 1
		var y := area.position.y + 1
		while y + 4 < area.end.y:
			var h := _rng.randi_range(4, 6)
			var x := area.position.x + 1
			while x + 4 < area.end.x:
				var w := _rng.randi_range(5, 8)
				var field := _shrink_to_fit(x, y, mini(w, area.end.x - x - 1), h)
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


## Ice cream and food stalls on the meadow behind the beaches, spread along the coast.
func _build_beach_stalls() -> void:
	var placed: Array[Vector2] = []
	var i := 0
	for y in range(8, _data.size - 8):
		for x in range(8, _data.size - 8):
			if placed.size() >= 10 or CityTypes.hash2(x, y, 55) % 9 != 0 or not _beach_edge(x, y):
				continue
			var c := Vector2(x, y)
			if placed.any(func(p: Vector2) -> bool: return p.distance_to(c) < 18.0):
				continue
			var r := Rect2i(x, y, 1, 1)
			if _spot_free(r, Zone.NATURE, 0) or _spot_free(r, Zone.FARM, 0):
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


## One free rectangle of `size` somewhere in `area`, or an empty one.
func _spots_one(area: Rect2i, zone: int, size: Vector2i, margin: int) -> Rect2i:
	var spots := _spots(area, zone, size, 1, 0.0, margin, 400)
	return spots[0] if not spots.is_empty() else Rect2i()


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
