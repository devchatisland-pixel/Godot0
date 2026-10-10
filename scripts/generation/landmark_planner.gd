class_name LandmarkPlanner
extends RefCounted
## Landmarks that are not in a city block: the lake and paths of the central
## park, the one mountain of the north-east forest, the road to the Golden
## Gate bridge and the lighthouses.

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
	_build_mountain()
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


# --- The one mountain, in the middle of its forest ------------------------------------------
func _build_mountain() -> void:
	var area := _districts.forest
	var c := area.get_center()
	var r := _find_spot(c + Vector2i(-4, -4), Vector2i(8, 8), Zone.NATURE, MapLayout.span(14))
	if r.size.x > 0:
		_services.claim(r, Kind.MOUNTAIN, 2, -1, 16)


# --- Road to the Golden Gate bridge (east coast) ---------------------------------------------
## Rows (island units) where the bridge may leave the island.
const BRIDGE_ROWS := Vector2(-0.3, 0.3)


## The east highway: three lanes from a street that crosses its row (so that the highway
## starts at a proper junction) to the east shore; the bridge to the fog island starts there
## (CityData.bridge). The lots in its way are removed.
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
		# A street that only runs along the row is no junction: such rows come last.
		if not _crosses(road, y):
			cost += 1000.0
		if cost < best_cost:
			best_cost = cost
			best = Vector3i(y, road, coast)
	if best.x < 0:
		return
	for x in range(best.y + 1, best.z + 1):
		for dy in range(-1, 2):
			var y := best.x + dy
			if dy != 0 and not (_island.is_mainland(x, y) and _data.terrain[_data.idx(x, y)] >= CityTypes.Terrain.BEACH):
				continue
			_services.clear_cell(x, y)
			_data.road[_data.idx(x, y)] = CityTypes.ROAD_AVENUE
	_data.bridge = Vector2i(best.z + 1, best.x)


## True when the road at (x, y) crosses the three rows of the highway and goes on beyond them.
func _crosses(x: int, y: int) -> bool:
	return _data.is_road(x, y - 1) and _data.is_road(x, y + 1) \
			and (_data.is_road(x, y - 2) or _data.is_road(x, y + 2))


## No public building nor plot on the way to the coast.
func _path_is_clear(y: int, from_x: int, to_x: int) -> bool:
	for x in range(from_x, to_x + 1):
		for dy in [-1, 1]:
			var side := _lots.owner[_data.idx(x, y + dy)]
			if side >= 0 and CityTypes.is_service(_data.b_kind[side]):
				return false
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
