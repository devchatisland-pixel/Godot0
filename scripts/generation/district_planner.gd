class_name DistrictPlanner
extends RefCounted
## Decides where the city is dense: a downtown, a few town centers and a port
## with industry. Gives every block its zone.

const Zone := CityTypes.Zone

var _cfg: CityConfig
var _data: CityData
var _island: IslandShaper
var _rng: RandomNumberGenerator
var _noise := FastNoiseLite.new()

var main_center := Vector2.ZERO
var port_center := Vector2(-9999, -9999)
var port_radius := 0.0
var _radii := PackedFloat32Array()


func _init(cfg: CityConfig, data: CityData, island: IslandShaper, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_rng = rng
	_noise.seed = cfg.seed + 501
	_noise.frequency = 6.0 / float(data.size)
	_noise.fractal_octaves = 2


# --- Centers -----------------------------------------------------------------------
func plan_centers() -> void:
	var size := _data.size
	var mid := Vector2(size, size) * 0.5
	# Downtown: well inside the land, close to the map center.
	var best := -INF
	for y in range(0, size, 4):
		for x in range(0, size, 4):
			if not _island.is_mainland(x, y):
				continue
			var score := _island.elevation_at(x, y) - Vector2(x, y).distance_to(mid) / size
			if score > best:
				best = score
				main_center = Vector2(x, y)
	_add_center(main_center, 1.0, size * 0.16)

	# Secondary town centers, spread out across the mainland.
	var min_dist := size * 0.2
	for i in _cfg.sub_centers:
		var pick := _farthest_land_point(min_dist, 0.12)
		if pick.x < 0.0:
			break
		_add_center(pick, _rng.randf_range(0.55, 0.72), size * _rng.randf_range(0.08, 0.11))

	_plan_port()


func _add_center(p: Vector2, weight: float, radius: float) -> void:
	_data.centers.append(p)
	_data.center_weights.append(weight)
	_radii.append(radius)


## Random mainland point that is far from existing centers.
func _farthest_land_point(min_dist: float, min_height: float) -> Vector2:
	var best := Vector2(-1, -1)
	var best_d := min_dist
	for attempt in 300:
		var x := _rng.randi_range(0, _data.size - 1)
		var y := _rng.randi_range(0, _data.size - 1)
		if not _island.is_mainland(x, y) or _island.elevation_at(x, y) < min_height:
			continue
		var p := Vector2(x, y)
		var d := INF
		for c in _data.centers:
			d = minf(d, c.distance_to(p))
		if d > best_d:
			best_d = d
			best = p
	return best


## Port + industrial area on a coast far from downtown.
func _plan_port() -> void:
	var size := _data.size
	var best := -INF
	for y in range(0, size, 3):
		for x in range(0, size, 3):
			if not _island.is_mainland(x, y) or _data.terrain[y * size + x] != CityTypes.Terrain.BEACH:
				continue
			var p := Vector2(x, y)
			var d := p.distance_to(main_center)
			if d < size * 0.18 or d > size * 0.38:
				continue
			var score := -absf(d - size * 0.26) + _rng.randf() * 10.0
			if score > best:
				best = score
				port_center = p
	port_radius = size * 0.1


# --- Density ---------------------------------------------------------------------------
## 0..1 urban intensity at a cell.
func density(x: float, y: float) -> float:
	var p := Vector2(x, y)
	var d := 0.0
	for i in _data.centers.size():
		var r := _radii[i]
		var t := p.distance_to(_data.centers[i]) / r
		d = maxf(d, _data.center_weights[i] * exp(-t * t * 0.5))
	d += _noise.get_noise_2d(x, y) * 0.08
	return clampf(d, 0.0, 1.0)


func is_industrial(x: float, y: float) -> bool:
	return Vector2(x, y).distance_to(port_center) < port_radius


# --- Block sizes used by the road planner --------------------------------------------------
## Returns Vector2i(short_max, long_max) interior size for a block at density d.
func block_limits(x: float, y: float) -> Vector2i:
	var d := density(x, y)
	if is_industrial(x, y):
		return Vector2i(8, 14)
	if d > 0.86:
		return Vector2i(5, 9)
	if d > 0.62:
		return Vector2i(4, 11)
	if d > 0.4:
		return Vector2i(5, 12)
	return Vector2i(4, 15)


# --- Zoning -------------------------------------------------------------------------------
func zone_for_block(r: Rect2i) -> int:
	var c := Vector2(r.get_center())
	var d := density(c.x, c.y)
	if d < _cfg.urban_threshold:
		return Zone.NATURE
	if is_industrial(c.x, c.y) and d < 0.75:
		return Zone.INDUSTRIAL
	if d > 0.86:
		return Zone.DOWNTOWN
	if d > 0.62:
		return Zone.COMMERCIAL
	if d > 0.4:
		return Zone.APARTMENT
	return Zone.SUBURBAN


## Zones every block, adds a central park and a few neighbourhood parks.
func assign_zones(blocks: Array[Rect2i]) -> PackedByteArray:
	var zones := PackedByteArray()
	zones.resize(blocks.size())
	var central_park := -1
	var central_best := INF
	var park_spots: Array[Vector2] = []
	for i in blocks.size():
		var r := blocks[i]
		var z := zone_for_block(r)
		var c := Vector2(r.get_center())
		var d := density(c.x, c.y)
		# Central park: a big block near downtown but not in its very core.
		if r.get_area() >= 36 and d > 0.55 and d < 0.86:
			var dist := c.distance_to(main_center)
			if dist > _data.size * 0.04 and dist < central_best:
				central_best = dist
				central_park = i
		if z in [Zone.APARTMENT, Zone.SUBURBAN, Zone.COMMERCIAL]:
			var h := CityTypes.hashf(r.position.x, r.position.y, _cfg.seed)
			if h < _cfg.park_chance and _far_from(park_spots, c, 25.0):
				z = Zone.PARK
				park_spots.append(c)
		zones[i] = z
	if central_park >= 0:
		zones[central_park] = Zone.PARK
	return zones


func _far_from(points: Array[Vector2], p: Vector2, dist: float) -> bool:
	for q in points:
		if q.distance_to(p) < dist:
			return false
	return true


## Writes block zones to the cell grid; the remaining land becomes nature.
func paint_zones(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	var size := _data.size
	for i in size * size:
		var land := _data.terrain[i] >= CityTypes.Terrain.BEACH
		_data.zone[i] = Zone.NATURE if land and _data.road[i] == 0 else Zone.NONE
	for b in blocks.size():
		var r := blocks[b]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := y * size + x
				if _data.terrain[i] == CityTypes.Terrain.LAND and _data.road[i] == 0:
					_data.zone[i] = zones[b]
