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
##   far west       the urban island (UrbanIslandPlanner) and the BT tower islet
##   far north-west the prison island
## The work is shared: ExtensionSpots (free ground), ExtensionRoads (highways and
## links), ExtensionFeatures (single places) and UrbanIslandPlanner.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Round districts: centre and radii in cells of the big map (desert, industrial zone,
## farmland and forest are in ExtensionFeatures).
const POOR := {"at": Vector2(122, 76), "r": Vector2(18, 10)}
const QUARTER := {"at": Vector2(138, 211), "r": Vector2(36, 17)}
## Land cells within this distance of the sea in the forest patch become a wide beach.
const SAND_BAND := 6
## Where the ferris wheel stands (6x6 plot, at the south beach).
const FERRIS_TARGET := Vector2i(146, 221)
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

## Buildings placed per kind (all the helpers together).
var counts := {}
var block_count := 0

var _cfg: CityConfig
var _data: CityData
var _island: ExtensionIsland
var _rng: RandomNumberGenerator
var _districts: DistrictPlanner
var _lots: LotPlanner
var _services: ServicePlanner
var _spots: ExtensionSpots
var _roads: ExtensionRoads
var _urban: UrbanIslandPlanner
var _core_used := PackedByteArray()
var _ferris := Rect2i()


func _init(cfg: CityConfig, data: CityData, island: ExtensionIsland, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_rng = rng
	_spots = ExtensionSpots.new(cfg, data, island, rng)
	_roads = ExtensionRoads.new(data, island, _spots)


func build() -> void:
	_districts = DistrictPlanner.new(_cfg, _data, _island)
	_districts.plan()
	# Cells the core city uses (buildings, parks, plots, ...): off limits.
	_core_used.resize(_data.zone.size())
	for i in _core_used.size():
		_core_used[i] = 0 if _spots.is_open(i) else 1
	_paint_new_land()
	_roads.begin()
	_roads.build_east_highway()
	_roads.build_west_highway()
	_paint_open_areas()
	_ferris = _spots.find_plot(FERRIS_TARGET, Vector2i(6, 6), QUARTER)
	_urban = UrbanIslandPlanner.new(_cfg, _data, _island, _districts, _roads)
	_urban.choose_plots()

	# Streets of the poor district and the red quarter (free land only).
	var road_planner := RoadPlanner.new(_cfg, _data, _island, _districts, _rng)
	var zones := PackedByteArray()
	var plans := [
		{"mask": _spots.blob_mask(POOR), "zone": Zone.POOR, "limits": Vector2i(4, 8), "reserved": [] as Array[Rect2i]},
		{"mask": _spots.blob_mask(QUARTER), "zone": Zone.QUARTER, "limits": Vector2i(4, 9),
				"reserved": [_ferris] as Array[Rect2i]},
	]
	for d in plans:
		var mask: PackedByteArray = d["mask"]
		road_planner.free_mask = mask
		var before := road_planner.blocks.size()
		road_planner.build_region(_spots.mask_bounds(mask), d["limits"], d["reserved"])
		var kept: Array[Rect2i] = []
		for b in range(before, road_planner.blocks.size()):
			if _spots.mostly_free(road_planner.blocks[b], mask):
				kept.append(road_planner.blocks[b])
		road_planner.blocks = road_planner.blocks.slice(0, before)
		road_planner.blocks.append_array(kept)
		for k in kept.size():
			zones.append(d["zone"])
		var area := _spots.mask_bounds(mask)
		_districts.anchors[_anchor_name(d["zone"])] = Vector2(area.get_center())
		_roads.link(_roads.road_nearest_to_city(area))
	block_count = road_planner.blocks.size()
	_urban.plan_roads()
	block_count += _urban.block_count
	_roads.spines(ExtensionFeatures.INDUSTRIAL)
	_roads.link(_roads.road_nearest_to_city(_spots.blob_rect(ExtensionFeatures.INDUSTRIAL)))
	_roads.link(_roads.land_nearest_to_city(_spots.blob_rect(ExtensionFeatures.FARM)))
	_urban.link_places()

	# Lots (never over what the core already built), zoning, public buildings.
	_lots = LotPlanner.new(_cfg, _data, _districts, _rng)
	for i in _core_used.size():
		if _core_used[i] == 1:
			_lots.owner[i] = -2
	_lots.build(road_planner.blocks, zones)
	_paint_blocks(road_planner.blocks, zones)
	_services = ServicePlanner.new(_cfg, _data, _districts, _lots)
	_spots.lots = _lots
	_spots.services = _services
	_services.build_specs(SPECS, road_planner.blocks, zones)
	if _ferris.size.x > 0:
		_spots.claim(_ferris, Kind.FERRIS_WHEEL, 2, Zone.CIVIC)
	_urban.build_places(_lots, _services)

	var features := ExtensionFeatures.new(_data, _island, _spots, _rng)
	features.build_all(_districts.forest)
	_services.finish()
	for k in _services.counts:
		counts[k] = counts.get(k, 0) + _services.counts[k]
	for k in _urban.counts:
		counts[k] = counts.get(k, 0) + _urban.counts[k]


func _anchor_name(zone: int) -> String:
	return {Zone.POOR: "poor_center", Zone.QUARTER: "quarter_south_center"}.get(zone, "ext_%d" % zone)


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
			elif _island.is_urban_island(x, y) or _island.is_tower_islet(x, y):
				_data.zone[i] = Zone.URBAN
			else:
				_data.zone[i] = Zone.ISLET


## Desert and industrial ground reach the sea without a beach; the forest keeps a wide one.
func _paint_open_areas() -> void:
	_paint(ExtensionFeatures.DESERT, Zone.DESERT, 0, true)
	_paint(ExtensionFeatures.INDUSTRIAL, Zone.INDUSTRIAL, 0, true)
	_paint(ExtensionFeatures.FARM, Zone.FARM, 0, false)
	_paint(ExtensionFeatures.FOREST, Zone.NATURE, 225, false)
	_sand_band(ExtensionFeatures.FOREST)
	_thin_core_forest()


func _paint(b: Dictionary, zone: int, forest: int, to_sea: bool) -> void:
	var rect := _spots.blob_rect(b)
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, _data.size)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, _data.size)):
			var i := _data.idx(x, y)
			if not _spots.in_blob(b, x, y) or not _spots.is_open(i) or _data.road[i] != 0:
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
	var rect := _spots.blob_rect(b)
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, _data.size)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, _data.size)):
			var i := _data.idx(x, y)
			if not _spots.in_blob(b, x, y, 0.35) or _data.terrain[i] != Terrain.LAND or not _spots.is_open(i):
				continue
			if _spots.near_water(x, y, SAND_BAND):
				_data.zone[i] = Zone.SAND
				_data.forest[i] = 0


## The core's north-east forest stays dense only around its mountain; the rest thins to meadow.
func _thin_core_forest() -> void:
	var area := _districts.forest
	var mountain := Vector2i(-1, -1)
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.MOUNTAIN:
			mountain = _data.building_rect(b).get_center()
	var center := Vector2(mountain) if mountain.x >= 0 else Vector2(area.get_center())
	var noise := FastNoiseLite.new()
	noise.seed = _cfg.seed + 31
	noise.frequency = 0.045
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			if _data.zone[i] != Zone.NATURE or _data.forest[i] < 200:
				continue
			var d := Vector2((x - center.x) / 22.0, (y - center.y) / 18.0).length() \
					+ noise.get_noise_2d(x * 2.0, y * 2.0) * 0.3
			if d > 1.0:
				_data.forest[i] = 70


func _paint_blocks(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	for b in blocks.size():
		var r := blocks[b]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := _data.idx(x, y)
				if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _lots.owner[i] != -2:
					_data.zone[i] = zones[b]
