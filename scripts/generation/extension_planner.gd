class_name ExtensionPlanner
extends RefCounted
## Everything around the finished city (see ExtensionIsland for the land).
## Nothing of the core city is moved or changed: roads and lots only go on
## free land. Districts are round blobs (ellipses with a wobbly edge), not
## squares, and special places are kept far from each other on purpose.
##   west coast     the desert with the secret base, and south of it the
##                  industrial zone and its port: both touch the sea, no beach
##   north          the small poor district right behind the skyscrapers
##   north-east     a forest with three mountains, a wide beach on its coast
##   south          the red quarter grows towards the beach
##   south-east     the one farmland district
##   far west       the urban island (towers and night skylines, no trees)
##   far north-west the prison island

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Round districts: centre and radii in cells of the big map.
const DESERT := {"at": Vector2(78, 128), "r": Vector2(22, 36)}
const INDUSTRIAL := {"at": Vector2(84, 182), "r": Vector2(22, 19)}
const POOR := {"at": Vector2(122, 76), "r": Vector2(18, 10)}
const QUARTER := {"at": Vector2(138, 211), "r": Vector2(36, 17)}
const FARM := {"at": Vector2(202, 190), "r": Vector2(24, 32)}
const FOREST := {"at": Vector2(178, 62), "r": Vector2(34, 17)}
## Land cells within this distance of the sea in the forest patch become a wide beach.
const SAND_BAND := 6
## Where the ferris wheel stands (6x6 plot, at the south beach) and the skyline plots of the urban island.
const FERRIS_TARGET := Vector2i(146, 221)
## Plots of the urban island: the nuclear plant with its little industry, and the airport.
const NUCLEAR_PLOT := Vector2i(18, 13)
const AIRPORT_PLOT := Vector2i(20, 32)
## The smallest palm islet: the pirate grave stands on it, the pirate ship lies off its coast.
const PIRATE_ISLET := Vector2i(250, 92)
const NUCLEAR_TARGET := Vector2i(28, 101)
const AIRPORT_TARGET := Vector2i(28, 152)
## The 8 buildings of the industrial zone: sizes in cells.
const FACTORY_SIZES := [Vector2i(7, 4), Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 3),
		Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 3), Vector2i(3, 3)]
## Buildings placed in the blocks of the districts.
const SPECS := [
	{"kind": Kind.RUSSIAN, "size": Vector2i(4, 4), "count": 1, "near": "poor_center",
		"zones": [Zone.POOR]},
	# The red district: the two burger restaurants and the other five hotels (variants 4..8).
	{"kind": Kind.MCDONALDS, "size": Vector2i(3, 3), "count": 1, "near": "quarter_south_center",
		"zones": [Zone.QUARTER]},
	{"kind": Kind.BURGER_KING, "size": Vector2i(4, 4), "count": 1, "near": "quarter_south_center",
		"zones": [Zone.QUARTER]},
	# The drive-in cinema, a bit wider than before.
	{"kind": Kind.DRIVE_IN, "size": Vector2i(5, 4), "count": 1, "near": "quarter_south_center",
		"zones": [Zone.QUARTER]},
	# The poor district has its own burger restaurant.
	{"kind": Kind.BURGER_JOINT, "size": Vector2i(3, 2), "count": 1, "near": "poor_center",
		"zones": [Zone.POOR]},
	{"kind": Kind.HOTEL, "size": Vector2i(3, 3), "seed_base": 4, "variants": true, "same_gap": 12.0,
		"force_facing": 1,
		"near": ["quarter_south_center", "quarter_south_center", "quarter_south_center",
				"quarter_south_center", "quarter_south_center"], "zones": [Zone.QUARTER]},
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
var _shape := FastNoiseLite.new()
var _ferris := Rect2i()
var _clusters: Array[Rect2i] = []


func _init(cfg: CityConfig, data: CityData, island: ExtensionIsland, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_rng = rng
	_shape.seed = cfg.seed + 31
	_shape.frequency = 0.045


func build() -> void:
	_districts = DistrictPlanner.new(_cfg, _data, _island)
	_districts.plan()
	# Cells the core city uses (buildings, parks, plots, ...): off limits.
	_core_used.resize(_data.zone.size())
	for i in _core_used.size():
		_core_used[i] = 0 if _is_open(i) else 1
	_paint_new_land()
	_network = _data.road.duplicate()
	_build_east_highway()
	_build_west_highway()
	_paint_open_areas()
	_ferris = _find_plot(FERRIS_TARGET, Vector2i(6, 6), QUARTER)
	_clusters.append(_find_plot(NUCLEAR_TARGET, NUCLEAR_PLOT, {}))
	_clusters.append(_find_plot(AIRPORT_TARGET, AIRPORT_PLOT, {}))

	# Streets of the poor district, the red quarter and the urban island (free land only).
	var roads := RoadPlanner.new(_cfg, _data, _island, _districts, _rng)
	var zones := PackedByteArray()
	var plans := [
		{"mask": _blob_mask(POOR), "zone": Zone.POOR, "limits": Vector2i(4, 8), "reserved": [] as Array[Rect2i]},
		{"mask": _blob_mask(QUARTER), "zone": Zone.QUARTER, "limits": Vector2i(4, 9),
				"reserved": [_ferris] as Array[Rect2i]},
		{"mask": _urban_mask(), "zone": Zone.URBAN, "limits": Vector2i(9, 16), "reserved": _clusters},
	]
	for d in plans:
		var mask: PackedByteArray = d["mask"]
		roads.free_mask = mask
		var before := roads.blocks.size()
		roads.build_region(_mask_bounds(mask), d["limits"], d["reserved"])
		var kept: Array[Rect2i] = []
		for b in range(before, roads.blocks.size()):
			if _mostly_free(roads.blocks[b], mask):
				kept.append(roads.blocks[b])
		roads.blocks = roads.blocks.slice(0, before)
		roads.blocks.append_array(kept)
		for k in kept.size():
			zones.append(d["zone"])
		var area := _mask_bounds(mask)
		_districts.anchors[_anchor_name(d["zone"])] = Vector2(area.get_center())
		_link(_road_nearest_to_city(area))
	block_count = roads.blocks.size()
	_spines(INDUSTRIAL)
	_link(_road_nearest_to_city(_blob_rect(INDUSTRIAL)))
	_link(_land_nearest_to_city(_blob_rect(FARM)))
	_link_urban_clusters()

	# Lots (never over what the core already built), zoning, public buildings.
	_lots = LotPlanner.new(_cfg, _data, _districts, _rng)
	for i in _core_used.size():
		if _core_used[i] == 1:
			_lots.owner[i] = -2
	_lots.build(roads.blocks, zones)
	_paint_blocks(roads.blocks, zones)
	_services = ServicePlanner.new(_cfg, _data, _districts, _lots)
	_services.build_specs(SPECS, roads.blocks, zones)
	if _ferris.size.x > 0:
		_claim(_ferris, Kind.FERRIS_WHEEL, 2, Zone.CIVIC)
	_build_nuclear_plant(_clusters[0])
	if _clusters[1].size.x > 0:
		_claim(_clusters[1], Kind.AIRPORT, 2, Zone.URBAN)

	_build_desert()
	_build_industrial()
	_build_farms()
	_build_mountains()
	_build_pirate_islet()
	_build_prison()
	_build_lighthouses()
	_services.finish()
	for k in _services.counts:
		counts[k] = counts.get(k, 0) + _services.counts[k]


func _anchor_name(zone: int) -> String:
	return {Zone.POOR: "poor_center", Zone.QUARTER: "quarter_south_center",
			Zone.URBAN: "urban_center"}.get(zone, "ext_%d" % zone)


# --- Round shapes --------------------------------------------------------------------------
## True when the cell is inside the blob (an ellipse with a wobbly edge).
func _in_blob(b: Dictionary, x: int, y: int, grow: float = 0.0) -> bool:
	var at: Vector2 = b["at"]
	var r: Vector2 = b["r"]
	var n := Vector2((float(x) + 0.5 - at.x) / r.x, (float(y) + 0.5 - at.y) / r.y)
	return n.length() + _shape.get_noise_2d(x, y) * 0.22 < 1.0 + grow


func _blob_rect(b: Dictionary) -> Rect2i:
	var at: Vector2 = b["at"]
	var r: Vector2 = b["r"]
	return Rect2i(Vector2i((at - r * 1.15).round()), Vector2i((r * 2.3).round()))


## Free cells (open land, no road) inside the blob.
func _blob_mask(b: Dictionary) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(_data.size * _data.size)
	var rect := _blob_rect(b)
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, _data.size)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, _data.size)):
			var i := _data.idx(x, y)
			if _in_blob(b, x, y) and _data.terrain[i] == Terrain.LAND and _is_open(i) and _data.road[i] == 0:
				mask[i] = 1
	return mask


## Free cells of the urban island.
func _urban_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(_data.size * _data.size)
	for y in _data.size:
		for x in range(0, 60):
			var i := _data.idx(x, y)
			if _island.is_urban_island(x, y) and _data.terrain[i] == Terrain.LAND and _data.road[i] == 0:
				mask[i] = 1
	return mask


func _mask_bounds(mask: PackedByteArray) -> Rect2i:
	var mn := Vector2i(_data.size, _data.size)
	var mx := Vector2i(-1, -1)
	for i in mask.size():
		if mask[i] == 1:
			var x := i % _data.size
			var y := i / _data.size
			mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
			mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	return Rect2i(mn, mx - mn + Vector2i.ONE) if mx.x >= 0 else Rect2i()


## A block counts when most of its cells are free.
func _mostly_free(r: Rect2i, mask: PackedByteArray) -> bool:
	var free := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			free += mask[_data.idx(x, y)]
	return free * 4 >= r.get_area() * 3


# --- Land and zones -------------------------------------------------------------------------
## New land that the core did not have: meadows on the mainland, the islands.
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
			elif _island.is_urban_island(x, y):
				_data.zone[i] = Zone.URBAN
			else:
				_data.zone[i] = Zone.ISLET


## Desert and industrial ground reach the sea without a beach; the forest keeps a wide one.
func _paint_open_areas() -> void:
	_paint(DESERT, Zone.DESERT, 0, true)
	_paint(INDUSTRIAL, Zone.INDUSTRIAL, 0, true)
	_paint(FARM, Zone.FARM, 0, false)
	_paint(FOREST, Zone.NATURE, 225, false)
	_sand_band(FOREST)
	_thin_core_forest()


func _paint(b: Dictionary, zone: int, forest: int, to_sea: bool) -> void:
	var rect := _blob_rect(b)
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, _data.size)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, _data.size)):
			var i := _data.idx(x, y)
			if not _in_blob(b, x, y) or not _is_open(i) or _data.road[i] != 0:
				continue
			var land := _data.terrain[i] == Terrain.LAND
			if not land and not (to_sea and _data.terrain[i] == Terrain.BEACH):
				continue
			_data.zone[i] = zone
			if not land:
				_data.rocky[i] = 2 # the land colour reaches the sea (quay, dunes)
			if forest > 0:
				_data.forest[i] = forest
			elif zone != Zone.NATURE:
				_data.forest[i] = 0


## A wide strip of sand where the forest meets the sea.
func _sand_band(b: Dictionary) -> void:
	var rect := _blob_rect(b)
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, _data.size)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, _data.size)):
			var i := _data.idx(x, y)
			if not _in_blob(b, x, y, 0.35) or _data.terrain[i] != Terrain.LAND or not _is_open(i):
				continue
			if _near_water(x, y, SAND_BAND):
				_data.zone[i] = Zone.SAND
				_data.forest[i] = 0


func _near_water(x: int, y: int, dist: int) -> bool:
	for dy in range(-dist, dist + 1):
		for dx in range(-dist, dist + 1):
			if dx * dx + dy * dy > dist * dist or not _data.in_bounds(x + dx, y + dy):
				continue
			if _data.terrain[_data.idx(x + dx, y + dy)] < Terrain.BEACH:
				return true
	return false


## The core's north-east forest stays dense only around its mountain; the rest thins to meadow.
func _thin_core_forest() -> void:
	var area := _districts.forest
	var mountain := Vector2i(-1, -1)
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.MOUNTAIN:
			mountain = _data.building_rect(b).get_center()
	var center := Vector2(mountain) if mountain.x >= 0 else Vector2(area.get_center())
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			if _data.zone[i] != Zone.NATURE or _data.forest[i] < 200:
				continue
			var d := Vector2((x - center.x) / 22.0, (y - center.y) / 18.0).length() \
					+ _shape.get_noise_2d(x * 2.0, y * 2.0) * 0.3
			if d > 1.0:
				_data.forest[i] = 70


## Free for the extension: land that is not used by the core (or by a district).
func _is_open(i: int) -> bool:
	return _data.zone[i] == Zone.NONE or _data.zone[i] == Zone.NATURE


func _paint_blocks(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	for b in blocks.size():
		var r := blocks[b]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := _data.idx(x, y)
				if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _lots.owner[i] != -2:
					_data.zone[i] = zones[b]


# --- Highways -------------------------------------------------------------------------------
## East: three lanes wide, like the Golden Gate: from the end of the core's road
## to the coast. The bridge starts where the highway reaches the water.
func _build_east_highway() -> void:
	var start := _data.bridge
	if start.x < 0:
		return
	var x := start.x
	var last := x
	while x < _data.size - 2 and _data.terrain[_data.idx(x, start.y)] == Terrain.LAND:
		_lane(x, start.y)
		last = x
		x += 1
	_data.bridge = Vector2i(last + 1, start.y)


## West: from the west-most street of the core to the west coast, then over the
## metal bridge to the urban island. Rows are tried from the one with the
## west-most road; the way west of it must be free.
func _build_west_highway() -> void:
	var rows := []
	for y in range(112, 156):
		for x in range(_data.size):
			if _data.road[_data.idx(x, y)] != 0:
				rows.append([x, y])
				break
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for cand in rows:
		var y: int = cand[1]
		var x: int = cand[0]
		var coast := _clear_way_west(x, y)
		if coast < 0:
			continue
		for cx in range(coast, x):
			_lane(cx, y)
		# First land of the urban island on the same row (east coast of the island).
		var urban := -1
		for ux in range(coast - 2, 0, -1):
			if _data.terrain[_data.idx(ux, y)] == Terrain.LAND and _island.is_urban_island(ux, y):
				urban = ux
				break
		if urban < 0:
			return
		for ux in range(urban, maxi(urban - 12, 1), -1):
			if _data.terrain[_data.idx(ux, y)] == Terrain.LAND:
				_lane(ux, y)
		_data.west_bridge = Vector3i(coast, urban, y)
		return


## The last land column (west-most) of the way west from (x, y), or -1 when blocked.
func _clear_way_west(x: int, y: int) -> int:
	var last := -1
	for cx in range(x - 1, 0, -1):
		var i := _data.idx(cx, y)
		if _data.terrain[i] != Terrain.LAND:
			return last
		if not _is_open(i) or _data.road[i] != 0:
			return -1
		last = cx
	return -1


## One column of the three-lane highway (the middle lane is the row itself).
func _lane(x: int, y: int) -> void:
	for dy in range(-1, 2):
		if not _data.in_bounds(x, y + dy):
			continue
		var i := _data.idx(x, y + dy)
		if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and (_is_open(i) or _data.zone[i] == Zone.URBAN):
			_data.road[i] = CityTypes.ROAD_AVENUE
			_network[i] = 1


# --- Roads to the city ----------------------------------------------------------------------
func _road_nearest_to_city(area: Rect2i) -> int:
	var center := Vector2(_data.size, _data.size) * 0.5
	return _nearest(area, center, true)


func _land_nearest_to_city(area: Rect2i) -> int:
	var center := Vector2(_data.size, _data.size) * 0.5
	return _nearest(area, center, false)


## The road cell (or free farm cell) of `area` closest to `target`, -1 when none.
func _nearest(area: Rect2i, target: Vector2, want_road: bool) -> int:
	var best := -1
	var best_d := INF
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			var ok := (_data.road[i] != 0 and _network[i] == 0) if want_road \
					else (_data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _data.zone[i] == Zone.FARM)
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
			if _data.road[ni] == 0 and not _link_zone(z):
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


func _link_zone(z: int) -> bool:
	return z == Zone.NONE or z == Zone.NATURE or z == Zone.DESERT or z == Zone.FARM \
			or z == Zone.INDUSTRIAL or z == Zone.URBAN or z == Zone.SAND


## A cross of streets through the middle of a blob (the industrial zone).
func _spines(b: Dictionary) -> void:
	var at: Vector2 = b["at"]
	var r: Vector2 = b["r"]
	for x in range(int(at.x - r.x), int(at.x + r.x) + 1):
		_street_cell(x, int(at.y), b)
	for y in range(int(at.y - r.y), int(at.y + r.y) + 1):
		_street_cell(int(at.x), y, b)


func _street_cell(x: int, y: int, b: Dictionary) -> void:
	var i := _data.idx(x, y)
	if _in_blob(b, x, y) and _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 \
			and _data.zone[i] == Zone.INDUSTRIAL:
		_data.road[i] = CityTypes.ROAD_STREET
		_network[i] = 1


## Each skyline plot of the urban island gets a street to the others.
func _link_urban_clusters() -> void:
	for r in _clusters:
		if r.size.x > 0:
			_link(_data.idx(r.position.x - 1, r.get_center().y))


# --- Features ---------------------------------------------------------------------------------
## The nuclear plant in the north part of its plot; the rest of the plot is a little
## industrial yard: containers, barrels, a truck, and two small factories.
func _build_nuclear_plant(plot: Rect2i) -> void:
	if plot.size.x <= 0:
		return
	_claim(Rect2i(plot.position, Vector2i(plot.size.x, 7)), Kind.NUCLEAR_PLANT, 2, Zone.URBAN)
	var yard := Rect2i(plot.position + Vector2i(0, 8), Vector2i(plot.size.x, plot.size.y - 8))
	var k := 0
	for r in _spots(yard, Zone.URBAN, Vector2i(2, 2), 4, 3.5, 0, 300):
		_claim(r, Kind.INDUSTRIAL_YARD, 2, Zone.URBAN, k)
		k += 1
	for r in _spots(yard, Zone.URBAN, Vector2i(3, 2), 2, 6.0, 0, 300):
		_claim(r, Kind.INDUSTRIAL, 2, Zone.URBAN, k)
		k += 1


## A free 6x6-like plot closest to `target` whose cells are all dry open land; for a
## blob given, the whole plot must be inside it.
func _find_plot(target: Vector2i, size: Vector2i, blob: Dictionary) -> Rect2i:
	for radius in 30:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _plot_ok(r, blob):
					return r
	return Rect2i()


func _plot_ok(r: Rect2i, blob: Dictionary) -> bool:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 \
					or not (_is_open(i) or _data.zone[i] == Zone.URBAN):
				return false
			if not blob.is_empty() and not _in_blob(blob, x, y):
				return false
			# Cluster plots stay on the urban island, ferris wheel plots on the main one.
			if blob.is_empty() and not _island.is_urban_island(x, y):
				return false
	return true


## A free plot of open meadow closest to `target` (no road, margin of one cell).
func _find_open_plot(target: Vector2i, size: Vector2i) -> Rect2i:
	for radius in 24:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _open_plot_ok(r):
					return r
	return Rect2i()


func _open_plot_ok(r: Rect2i) -> bool:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 or _data.zone[i] != Zone.NATURE:
				return false
	return true


## Marks the plot as taken (civic ground), so roads and other buildings keep off it.
func _reserve(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_data.zone[_data.idx(x, y)] = Zone.CIVIC


## Free rectangle of open water closest to `target`.
func _find_water(target: Vector2i, size: Vector2i, max_radius: int) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(target + Vector2i(dx, dy) - size / 2, size)
				if _water_ok(r):
					return r
	return Rect2i()


func _water_ok(r: Rect2i) -> bool:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if not _data.in_bounds(x, y) or _data.terrain[_data.idx(x, y)] >= Terrain.BEACH:
				return false
	return true


## The desert next to Las Vegas: the secret base (airbase, bunker, radio station), mesas,
## ranches and oil pumps, far apart from each other.
func _build_desert() -> void:
	var c := Vector2i(DESERT["at"])
	for size in AIRBASE_SIZES:
		var r := _find_spot(c + Vector2i(-size.x / 2, -14), size, Zone.DESERT, 16, 2)
		if r.size.x > 0:
			_claim(r, Kind.AIRBASE, 2, Zone.CIVIC)
			break
	var bunker := _find_spot(c + Vector2i(2, 14), Vector2i(3, 3), Zone.DESERT, 12, 3)
	if bunker.size.x > 0:
		_claim(bunker, Kind.BUNKER, 2, Zone.CIVIC)
	var tower := _find_spot(c + Vector2i(-6, 4), Vector2i(2, 2), Zone.DESERT, 12, 2)
	if tower.size.x > 0:
		_claim(tower, Kind.TELECOM_TOWER, 2, Zone.CIVIC)
		for o in [Vector2i(4, -1), Vector2i(4, 3), Vector2i(0, 4)]:
			var d := Rect2i(tower.position + o, Vector2i(2, 2))
			if _spot_free(d, Zone.DESERT, 0):
				_claim(d, Kind.SAT_DISH, 3, Zone.CIVIC)
	for r in _spots(_blob_rect(DESERT), Zone.DESERT, Vector2i(6, 4), 2, 20.0, 1):
		_claim(r, Kind.MESA, 2)
	var i := 0
	for r in _spots(_blob_rect(DESERT), Zone.DESERT, Vector2i(2, 2), 3, 14.0, 2):
		_claim(r, Kind.OUTPOST, 2, -1, i * 3)
		i += 1
	for r in _spots(_blob_rect(DESERT), Zone.DESERT, Vector2i(2, 2), 7, 9.0, 1):
		_claim(r, Kind.OIL_PUMP, 2)


## The industrial zone: exactly 8 different buildings (variant 0..7), and its port:
## container yards and two cranes on the quay.
func _build_industrial() -> void:
	var rect := _blob_rect(INDUSTRIAL)
	for i in FACTORY_SIZES.size():
		var r := _spots_one(rect, Zone.INDUSTRIAL, FACTORY_SIZES[i], 1)
		if r.size.x > 0:
			_claim(r, Kind.FACTORY_BLDG, 2, -1, i)
	var quay: Array[Rect2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _near_water(x, y, 3) and _data.in_bounds(x, y) and _data.zone[_data.idx(x, y)] == Zone.INDUSTRIAL:
				var r := Rect2i(x, y, 2, 2)
				if _spot_free(r, Zone.INDUSTRIAL, 0) and not quay.any(func(q: Rect2i) -> bool:
						return Vector2(q.get_center()).distance_to(Vector2(r.get_center())) < 5.0):
					quay.append(r)
	var cranes := 0
	for k in quay.size():
		if cranes < 2 and k % 3 == 1:
			_claim(quay[k], Kind.CRANE, 2)
			cranes += 1
		elif k % 3 != 1:
			_claim(quay[k], Kind.INDUSTRIAL_YARD, 2, -1, k)


## Farm houses and barns, then crop fields tiled over the one farmland district.
func _build_farms() -> void:
	var rect := _blob_rect(FARM)
	var k := 0
	for yard in _spots(rect, Zone.FARM, Vector2i(2, 2), 4, 14.0, 2, 600):
		_claim(yard, Kind.OUTPOST, 2, Zone.CIVIC, k * 3)
		k += 1
		var side := Rect2i(yard.position + Vector2i(3, 0), Vector2i(2, 2))
		if _spot_free(side, Zone.FARM, 0):
			_claim(side, Kind.OUTPOST, 2, Zone.CIVIC, k * 3 + 1)
			k += 1
	var y := rect.position.y
	while y < rect.end.y:
		var h := _rng.randi_range(4, 6)
		var x := rect.position.x
		while x < rect.end.x:
			var w := _rng.randi_range(5, 8)
			var field := _shrink_to_fit(x, y, w, h)
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


## Two more mountains next to the one of the core, in the forest.
func _build_mountains() -> void:
	var first := Vector2i(-1, -1)
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.MOUNTAIN:
			first = _data.building_rect(b).get_center()
	if first.x < 0:
		first = Vector2i(FOREST["at"])
	# Right beside the big one, on its far side from the city (north and east).
	var seeds := [100, 108]
	var i := 0
	for o in [Vector2i(15, -6), Vector2i(3, -17)]:
		var r := _find_spot(first + o - Vector2i(4, 4), Vector2i(8, 8), Zone.NATURE, 8, 0)
		if r.size.x > 0:
			_claim(r, Kind.MOUNTAIN, 2, -1, seeds[i])
			i += 1


## The pirate grave on the smallest islet, and the pirate ship anchored just off its coast.
func _build_pirate_islet() -> void:
	var grave := _find_spot(PIRATE_ISLET, Vector2i.ONE, Zone.ISLET, 3, 0)
	if grave.size.x > 0:
		_claim(grave, Kind.GRAVE, 2)
	var ship := _find_water(PIRATE_ISLET + Vector2i(-9, 4), Vector2i(7, 3), 8)
	if ship.size.x > 0:
		_claim(ship, Kind.PIRATE_SHIP, 2)


## The prison compound: a big cellhouse, stone wings, a villa and lighthouses.
func _build_prison() -> void:
	var c := Vector2i(ExtensionIsland.PRISON["at"])
	var main := Rect2i()
	for size in [Vector2i(11, 8), Vector2i(10, 7), Vector2i(9, 6), Vector2i(7, 5)]:
		main = _find_spot(c - size / 2, size, Zone.PRISON, 6, 0)
		if main.size.x > 0:
			break
	if main.size.x > 0:
		_claim(main, Kind.PRISON, 2)
	var wings := [Vector2i(3, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 3)]
	var offsets := [Vector2i(-6, -5), Vector2i(7, -6), Vector2i(-8, 3), Vector2i(8, 6), Vector2i(-3, 9), Vector2i(12, -1)]
	for i in wings.size():
		var near: Vector2i = (main.position if main.size.x > 0 else c) + offsets[i]
		var r := _find_spot(near, wings[i], Zone.PRISON, 5, 0)
		if r.size.x > 0:
			_claim(r, Kind.PRISON_WING, 2, -1, i)


# --- Lighthouses ---------------------------------------------------------------------------------
## Four on the coast of the main island, spread round it, and two at the ends of the prison
## island. Each one stands on a dry cell with the sea less than three cells away.
func _build_lighthouses() -> void:
	var main_at: Vector2 = ExtensionIsland.MAIN["at"]
	for deg in [135.0, 235.0, 330.0, 60.0]:
		var cell := _coast_cell(main_at, Vector2.from_angle(deg_to_rad(deg)), false)
		if cell.x >= 0:
			_claim(Rect2i(cell, Vector2i.ONE), Kind.LIGHTHOUSE, 2)
	var prison_at: Vector2 = ExtensionIsland.PRISON["at"]
	var turn: float = ExtensionIsland.PRISON["turn"]
	for sign in [-1.0, 1.0]:
		var cell := _coast_cell(prison_at, Vector2.from_angle(turn) * sign, true)
		if cell.x >= 0:
			_claim(Rect2i(cell, Vector2i.ONE), Kind.LIGHTHOUSE, 2)


## The free coast cell furthest in direction `dir` from `center`: dry, open meadow or
## sand (or the prison island), with the sea within two cells.
func _coast_cell(center: Vector2, dir: Vector2, prison: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for y in _data.size:
		for x in _data.size:
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 or _lots.owner[i] != -1:
				continue
			var z := _data.zone[i]
			if prison:
				if z != Zone.PRISON:
					continue
			elif not ((z == Zone.NATURE or z == Zone.SAND or z == Zone.FARM) and _island.is_mainland(x, y)):
				continue
			var score := (Vector2(x, y) - center).dot(dir)
			if score > best_score and _near_water(x, y, 2):
				best_score = score
				best = Vector2i(x, y)
	return best


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
