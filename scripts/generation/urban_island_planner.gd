class_name UrbanIslandPlanner
extends RefCounted
## The urban island west of the main island, planned along its length (the camera
## looks from the south-east, so on screen the north end is the right end and the
## south end the left one):
##   north end  the nuclear plant, alone on its rows: no streets, no towers. Its
##              cooling towers and hall stand beside it, a small yard behind.
##   middle     the tower city (streets and lots). The strip in front of the
##              plant, as the camera sees it, only gets low industrial buildings.
##   south end  the airport. Nothing at all is built in front of it.
## Next to the south end lies a tiny industrial islet with the BT tower in its middle.
## The island has its own random numbers (seed + SEED_OFFSET): changing it does not
## move anything on the other districts.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## The nuclear plant: where the search for its plot starts, the plot (plant + yard) and
## the rows of the plot taken by the plant itself.
const PLANT_TARGET := Vector2i(30, 96)
const PLANT_PLOT := Vector2i(18, 13)
const PLANT_ROWS := 7
## Rows above this (north end) get no streets and no lots.
const NUCLEAR_END := 111
## The airport plots tried in turn, and the column where the search starts.
const AIRPORT_PLOTS := [Vector2i(20, 32), Vector2i(18, 28), Vector2i(16, 24)]
const AIRPORT_COLUMN := 30
## Cells either side of the camera's line of sight that stay free of towers.
const SIGHT_MARGIN := 2
## Block size limits of the tower city and the seed offset of the island.
const LIMITS := Vector2i(9, 16)
const SEED_OFFSET := 901

## Buildings placed, per kind.
var counts := {}
var block_count := 0
## The plot of the plant (with its yard) and the plot of the airport (empty when none fits).
var plant := Rect2i()
var airport := Rect2i()

var _cfg: CityConfig
var _data: CityData
var _island: ExtensionIsland
var _districts: DistrictPlanner
var _roads: ExtensionRoads
var _rng := RandomNumberGenerator.new()
var _spots: ExtensionSpots
var _blocks: Array[Rect2i] = []
var _zones := PackedByteArray()


func _init(cfg: CityConfig, data: CityData, island: ExtensionIsland, districts: DistrictPlanner,
		roads: ExtensionRoads) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_districts = districts
	_roads = roads
	_rng.seed = cfg.seed + SEED_OFFSET
	_spots = ExtensionSpots.new(cfg, data, island, _rng)


# --- Plots ----------------------------------------------------------------------------------
## Finds the plots of the plant and the airport (before any road is laid).
func choose_plots() -> void:
	var u: Dictionary = ExtensionIsland.URBAN
	var tip := int(Vector2(u["at"]).y + Vector2(u["r"]).y)
	for size in AIRPORT_PLOTS:
		airport = _spots.find_plot(Vector2i(AIRPORT_COLUMN, tip - 4 - size.y / 2), size, {})
		if airport.size.x > 0:
			break
	plant = _spots.find_plot(PLANT_TARGET, PLANT_PLOT, {})


## The rows kept free of streets and lots at the north end.
func nuclear_rect() -> Rect2i:
	return Rect2i(0, 0, ExtensionIsland.URBAN_COLUMNS, NUCLEAR_END)


# --- Streets ---------------------------------------------------------------------------------
## Streets and blocks of the tower city, joined to the highway of the west bridge.
func plan_roads() -> void:
	var mask := _urban_mask()
	var area := _spots.mask_bounds(mask)
	if area.size.x <= 0:
		return
	var planner := RoadPlanner.new(_cfg, _data, _island, _districts, _rng)
	planner.free_mask = mask
	var reserved: Array[Rect2i] = [nuclear_rect()]
	if airport.size.x > 0:
		reserved.append(airport)
	planner.build_region(area, LIMITS, reserved)
	for b in planner.blocks:
		if _spots.mostly_free(b, mask):
			_blocks.append(b)
	block_count = _blocks.size()
	_districts.anchors["urban_center"] = Vector2(area.get_center())
	_roads.link(_roads.road_nearest_to_city(area))
	_roads.adopt(mask)


## Free land of the island outside the nuclear rows.
func _urban_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(_data.size * _data.size)
	for y in range(NUCLEAR_END, _data.size):
		for x in range(0, ExtensionIsland.URBAN_COLUMNS):
			var i := _data.idx(x, y)
			if _island.is_urban_island(x, y) and _data.terrain[i] == Terrain.LAND and _data.road[i] == 0:
				mask[i] = 1
	return mask


## Each big plot gets a street to the network.
func link_places() -> void:
	for r in [plant, airport]:
		if r.size.x > 0:
			_roads.link(_land_beside(r))


## A land cell touching the plot (west side first, then south, east and north).
func _land_beside(r: Rect2i) -> int:
	var c := r.get_center()
	for p in [Vector2i(r.position.x - 1, c.y), Vector2i(c.x, r.end.y), Vector2i(r.end.x, c.y),
			Vector2i(c.x, r.position.y - 1)]:
		if _data.in_bounds(p.x, p.y) and _data.terrain[_data.idx(p.x, p.y)] == Terrain.LAND:
			return _data.idx(p.x, p.y)
	return -1


# --- Lots and places ---------------------------------------------------------------------------
## Lots of the tower city, the airport, the plant with its cooling towers, the BT islet.
func build_places(lots: LotPlanner, services: ServicePlanner) -> void:
	_spots.lots = lots
	_spots.services = services
	_clear_sight(lots, airport)
	_zones.resize(_blocks.size())
	for b in _blocks.size():
		var c := _blocks[b].get_center()
		_zones[b] = Zone.INDUSTRIAL if _in_front(plant, c.x, c.y, SIGHT_MARGIN) else Zone.URBAN
	lots.build(_blocks, _zones, _rng)
	_paint_blocks(lots)
	if airport.size.x > 0:
		_spots.claim(airport, Kind.AIRPORT, 2, Zone.URBAN)
	_build_plant()
	_build_tower_islet()
	for k in _spots.counts:
		counts[k] = counts.get(k, 0) + _spots.counts[k]


## True when the cell lies on a line of sight from `rect` towards the camera (the camera
## looks from +x +y: whatever stands on those cells hides the rect), `margin` cells wide.
func _in_front(rect: Rect2i, x: int, y: int, margin: int) -> bool:
	if rect.size.x <= 0 or x < rect.position.x - margin or y < rect.position.y - margin:
		return false
	var d := x - y
	return d >= rect.position.x - (rect.end.y - 1) - margin and d <= rect.end.x - 1 - rect.position.y + margin


## Nothing may be built in front of the rect: the lots are refused there.
func _clear_sight(lots: LotPlanner, rect: Rect2i) -> void:
	if rect.size.x <= 0:
		return
	for y in range(rect.position.y, _data.size):
		for x in range(rect.position.x, ExtensionIsland.URBAN_COLUMNS):
			if _in_front(rect, x, y, SIGHT_MARGIN) and not rect.has_point(Vector2i(x, y)):
				var i := _data.idx(x, y)
				if lots.owner[i] == -1:
					lots.owner[i] = -2


func _paint_blocks(lots: LotPlanner) -> void:
	for b in _blocks.size():
		var r := _blocks[b]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := _data.idx(x, y)
				if _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and lots.owner[i] != -2:
					_data.zone[i] = _zones[b]


# --- The plant ---------------------------------------------------------------------------------
## The nuclear plant in the north rows of its plot, two cooling towers and their hall on
## its east side (or west when there is no room), and a little industrial yard behind.
func _build_plant() -> void:
	if plant.size.x <= 0:
		return
	var body := Rect2i(plant.position, Vector2i(plant.size.x, PLANT_ROWS))
	_spots.claim(body, Kind.NUCLEAR_PLANT, 2, Zone.URBAN)
	# One tower on each side when both fit, the hall below the east tower.
	_place_beside(body, Vector2i(5, 5), Kind.COOLING_TOWER, [1, -1], 0)
	_place_beside(body, Vector2i(5, 5), Kind.COOLING_TOWER, [-1, 1], 0)
	_place_beside(body, Vector2i(7, 3), Kind.COOLING_HALL, [1, -1], PLANT_ROWS + 1)
	var yard := Rect2i(plant.position + Vector2i(0, PLANT_ROWS + 1), Vector2i(plant.size.x, plant.size.y - PLANT_ROWS - 1))
	var k := 0
	for r in _spots.spots(yard, Zone.URBAN, Vector2i(2, 2), 4, 3.5, 0, 300):
		_spots.claim(r, Kind.INDUSTRIAL_YARD, 2, Zone.URBAN, k)
		k += 1
	for r in _spots.spots(yard, Zone.URBAN, Vector2i(3, 2), 2, 6.0, 0, 300):
		_spots.claim(r, Kind.INDUSTRIAL, 2, Zone.URBAN, k)
		k += 1


## Claims a `size` plot beside the plant, `drop` rows down: on the sides in the order given
## (1 = east, -1 = west), the first free spot wins.
func _place_beside(body: Rect2i, size: Vector2i, kind: int, sides: Array, drop: int) -> void:
	for side in sides:
		var x: int = body.end.x + 1 if side > 0 else body.position.x - size.x - 1
		var r := _spots.find_spot(Vector2i(x, body.position.y + drop), size, Zone.URBAN, 3, 1)
		if r.size.x > 0:
			_spots.claim(r, kind, 2, Zone.URBAN, 0)
			return


# --- The BT tower islet --------------------------------------------------------------------------
## The tower in the middle of its islet, which is an industrial zone: three satellite
## dishes round it (like the radio tower of the desert) and two little yards.
func _build_tower_islet() -> void:
	var at := Vector2i(ExtensionIsland.TOWER_ISLET["at"])
	var tower := _spots.find_spot(at - Vector2i(1, 1), Vector2i(3, 3), Zone.INDUSTRIAL, 3, 0)
	if tower.size.x <= 0:
		return
	_spots.claim(tower, Kind.BT_TOWER, 2, Zone.INDUSTRIAL, 0)
	for o in [Vector2i(4, -1), Vector2i(4, 2), Vector2i(0, 4)]:
		var dish := _spots.find_spot(tower.position + o, Vector2i(2, 2), Zone.INDUSTRIAL, 2, 0)
		if dish.size.x > 0:
			_spots.claim(dish, Kind.SAT_DISH, 3, Zone.INDUSTRIAL)
	var k := 0
	for o in [Vector2i(-4, -1), Vector2i(-4, 2)]:
		var yard := _spots.find_spot(tower.position + o, Vector2i(2, 2), Zone.INDUSTRIAL, 2, 0)
		if yard.size.x > 0:
			_spots.claim(yard, Kind.INDUSTRIAL_YARD, 2, Zone.INDUSTRIAL, k)
			k += 1
