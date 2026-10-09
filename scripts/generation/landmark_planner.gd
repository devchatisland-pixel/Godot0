class_name LandmarkPlanner
extends RefCounted
## Landmarks that are not in a city block: the lake and paths of the central
## park, the airbase, bunker, telecom station, mesa and ranch of the desert,
## the prison island, the road to the Golden Gate bridge and two lighthouses.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind

## Coast directions (grid) where lighthouses stand: west (Vegas side) and east.
const LIGHTHOUSE_DIRS := [Vector2(-0.75, 0.65), Vector2(1.0, 0.15)]

var _data: CityData
var _districts: DistrictPlanner
var _island: IslandShaper
var _services: ServicePlanner
var _lots: LotPlanner


func _init(data: CityData, districts: DistrictPlanner, island: IslandShaper,
		services: ServicePlanner, lots: LotPlanner) -> void:
	_data = data
	_districts = districts
	_island = island
	_services = services
	_lots = lots


func build() -> void:
	_build_park()
	_build_desert()
	_build_prison()
	_build_bridge_road()
	_build_lighthouses()


# --- Central park: a lake with a fountain and two crossing paths ---------------------
func _build_park() -> void:
	var park := _districts.park
	if park.size.x < 8 or park.size.y < 8:
		return
	var c := park.get_center()
	for x in range(park.position.x, park.end.x):
		_paint_path(x, c.y)
	for y in range(park.position.y, park.end.y):
		_paint_path(c.x, y)
	var lake := Rect2i(c.x - 3, c.y - 2, 6, 4)
	if _services.is_free_land(lake):
		_services.claim(lake, Kind.POND, 2, Zone.CIVIC)


func _paint_path(x: int, y: int) -> void:
	var i := _data.idx(x, y)
	if _data.zone[i] == Zone.PARK:
		_data.zone[i] = Zone.CIVIC


# --- Desert: military airbase, bunker, telecom station, mesa and a lone ranch ---------
## Airbase sizes tried from the biggest (runway along X).
const AIRBASE_SIZES := [Vector2i(16, 5), Vector2i(14, 5), Vector2i(12, 4)]


func _build_desert() -> void:
	var desert := _districts.desert
	var sum := Vector2.ZERO
	var count := 0
	for y in range(desert.position.y, desert.end.y):
		for x in range(desert.position.x, desert.end.x):
			if _data.zone[_data.idx(x, y)] == Zone.DESERT:
				sum += Vector2(x, y)
				count += 1
	if count < 40:
		return
	var c := Vector2i(sum / count)
	for size in AIRBASE_SIZES:
		var base := _find_spot(c + Vector2i(-size.x / 2, -7), size, Zone.DESERT, 12, 1)
		if base.size.x > 0:
			_services.claim(base, Kind.AIRBASE, 2, Zone.CIVIC)
			break
	var tower := _find_spot(c + Vector2i(-4, 3), Vector2i(2, 2), Zone.DESERT, 10, 1)
	if tower.size.x > 0:
		_services.claim(tower, Kind.TELECOM_TOWER, 2, Zone.CIVIC)
		for o in [Vector2i(3, -1), Vector2i(3, 2), Vector2i(0, 3)]:
			var dish := _find_spot(tower.position + o, Vector2i(2, 2), Zone.DESERT, 3)
			if dish.size.x > 0:
				_services.claim(dish, Kind.SAT_DISH, 3, Zone.CIVIC)
	var mesa := _find_spot(c + Vector2i(8, 1), Vector2i(6, 4), Zone.DESERT, 10, 1)
	if mesa.size.x > 0:
		_services.claim(mesa, Kind.MESA, 2)
	var bunker := _find_spot(c + Vector2i(4, 6), Vector2i(3, 3), Zone.DESERT, 8, 2)
	if bunker.size.x > 0:
		_services.claim(bunker, Kind.BUNKER, 2, Zone.CIVIC)
	_build_outpost(c + Vector2i(-6, 9))


## A lone ranch: a few barns and trailers far apart from each other.
func _build_outpost(center: Vector2i) -> void:
	var spots := [Vector2i(0, 0), Vector2i(-7, -3), Vector2i(6, 2)]
	for i in spots.size():
		var r := _find_spot(center + spots[i], Vector2i(2, 2), Zone.DESERT, 4, 2)
		if r.size.x > 0:
			_services.claim(r, Kind.OUTPOST, 2, -1, i * 3)


# --- Prison island: cellhouse in the middle, lighthouse on the shore ---------------------
const PRISON_SIZES := [Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 3)]


func _build_prison() -> void:
	if _island.prison_radius <= 0.0:
		return
	var c := Vector2i(_island.prison_center.round())
	# Facing the city (south-east of the island).
	for size in PRISON_SIZES:
		var cell := _find_spot(c - size / 2, size, Zone.PRISON, 3)
		if cell.size.x > 0:
			_services.claim(cell, Kind.PRISON, 2)
			break
	var light := _find_spot(c + Vector2i(-3, -4), Vector2i.ONE, Zone.PRISON, 3)
	if light.size.x > 0:
		_services.claim(light, Kind.LIGHTHOUSE, 2)


# --- Road to the Golden Gate bridge (east coast) ---------------------------------------------
## Rows (island units) where the bridge may leave the island.
const BRIDGE_ROWS := Vector2(-0.3, 0.3)


## Extends the street closest to the east coast up to the shore; the bridge
## to the fog island starts there (CityData.bridge).
func _build_bridge_road() -> void:
	var y0 := int(_districts.to_cells(Vector2(0, BRIDGE_ROWS.x)).y)
	var y1 := int(_districts.to_cells(Vector2(0, BRIDGE_ROWS.y)).y)
	var mid := (y0 + y1) / 2
	var best := Vector3i(-1, -1, -1)
	var best_cost := INF
	for y in range(y0, y1 + 1):
		var coast := -1
		for x in range(_data.size - 1, 0, -1):
			if _island.is_mainland(x, y):
				coast = x
				break
		var road := -1
		for x in range(coast, 0, -1):
			if _data.road[_data.idx(x, y)] != 0:
				road = x
				break
		if coast < 0 or road < 0 or not _path_is_clear(y, road + 1, coast):
			continue
		var cost := float(coast - road) + absf(y - mid) * 0.3
		if cost < best_cost:
			best_cost = cost
			best = Vector3i(y, road, coast)
	if best.x < 0:
		return
	for x in range(best.y + 1, best.z + 1):
		_services.clear_cell(x, best.x)
		_data.road[_data.idx(x, best.x)] = CityTypes.ROAD_AVENUE
	_data.bridge = Vector2i(best.z + 1, best.x)


## No public building nor plot on the way to the coast.
func _path_is_clear(y: int, from_x: int, to_x: int) -> bool:
	for x in range(from_x, to_x + 1):
		var owner := _lots.owner[_data.idx(x, y)]
		if owner >= 0 and CityTypes.is_service(_data.b_kind[owner]):
			return false
		if _data.zone[_data.idx(x, y)] == Zone.CIVIC:
			return false
	return true


# --- Lighthouses ---------------------------------------------------------------------------
func _build_lighthouses() -> void:
	var center := Vector2(_data.centers[0])
	for dir in LIGHTHOUSE_DIRS:
		var best := Vector2i(-1, -1)
		var best_score := -INF
		for y in _data.size:
			for x in _data.size:
				var i := _data.idx(x, y)
				if not _island.is_mainland(x, y) or _data.road[i] != 0 or _lots.owner[i] >= 0:
					continue
				var score := (Vector2(x, y) - center).dot(dir)
				if score > best_score:
					best_score = score
					best = Vector2i(x, y)
		if best.x >= 0:
			_services.claim(Rect2i(best, Vector2i.ONE), Kind.LIGHTHOUSE, 2)


# --- Helpers -------------------------------------------------------------------------------
## Closest free rectangle of `size` around `near` whose cells are all in `zone`,
## keeping `margin` free cells around it (buildings not glued to each other).
func _find_spot(near: Vector2i, size: Vector2i, zone: int, max_radius: int = 10,
		margin: int = 0) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(near + Vector2i(dx, dy), size)
				if _fits(r.grow(margin), zone, margin):
					return r
	return Rect2i()


## True when every cell is free land of `zone`; the outer `margin` ring only
## has to be free of buildings.
func _fits(r: Rect2i, zone: int, margin: int = 0) -> bool:
	var inner := r.grow(-margin)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if margin > 0 and not inner.has_point(Vector2i(x, y)):
				if _data.in_bounds(x, y) and _lots.owner[_data.idx(x, y)] >= 0:
					return false
				continue
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.zone[i] != zone or _data.road[i] != 0 or _lots.owner[i] >= 0 \
					or _data.terrain[i] != CityTypes.Terrain.LAND:
				return false
	return true
