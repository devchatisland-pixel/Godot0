class_name LandmarkPlanner
extends RefCounted
## Landmarks that are not in a city block: the lake and paths of the central
## park, the telecom station, mesa and outpost of the desert, and two
## lighthouses on the coast.

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


# --- Desert: telecom tower, satellite dishes and a mesa --------------------------------
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
	var tower := _find_spot(c + Vector2i(-3, 2), Vector2i(2, 2), Zone.DESERT)
	if tower.size.x > 0:
		_services.claim(tower, Kind.TELECOM_TOWER, 2, Zone.CIVIC)
		for o in [Vector2i(4, -1), Vector2i(4, 3), Vector2i(0, 4)]:
			var dish := _find_spot(tower.position + o, Vector2i(2, 2), Zone.DESERT, 3)
			if dish.size.x > 0:
				_services.claim(dish, Kind.SAT_DISH, 3, Zone.CIVIC)
	var mesa := _find_spot(c + Vector2i(6, -5), Vector2i(6, 4), Zone.DESERT)
	if mesa.size.x > 0:
		_services.claim(mesa, Kind.MESA, 2)
	_build_outpost(c + Vector2i(-2, 7))


## A small settlement of barns, ranch houses, trailers and a water tank.
func _build_outpost(center: Vector2i) -> void:
	var spots := [Vector2i(0, 0), Vector2i(3, -1), Vector2i(-3, 1), Vector2i(1, 3),
			Vector2i(-2, -3), Vector2i(4, 2), Vector2i(-4, -1), Vector2i(2, -4)]
	for i in spots.size():
		var r := _find_spot(center + spots[i], Vector2i(2, 2), Zone.DESERT, 3)
		if r.size.x > 0:
			# Facing the settlement centre, like houses around a yard.
			var d := center - r.position
			var facing := 2
			if absi(d.x) > absi(d.y):
				facing = 1 if d.x > 0 else 3
			elif d.y != 0:
				facing = 2 if d.y > 0 else 0
			_services.claim(r, Kind.OUTPOST, facing, -1, i)


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
## Closest free rectangle of `size` around `near` whose cells are all in `zone`.
func _find_spot(near: Vector2i, size: Vector2i, zone: int, max_radius: int = 10) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(near + Vector2i(dx, dy), size)
				if _fits(r, zone):
					return r
	return Rect2i()


func _fits(r: Rect2i, zone: int) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.zone[i] != zone or _data.road[i] != 0 or _lots.owner[i] >= 0 \
					or _data.terrain[i] != CityTypes.Terrain.LAND:
				return false
	return true
