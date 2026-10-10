class_name PropSites
extends RefCounted
## Props added to the finished map, all at the end of the building list (no number moves):
##   - the forest fire truck (CCF) in the north-east forest,
##   - one billboard in every zone of the map,
##   - the hot air balloon, floating over the north-east,
##   - buildings behind the main cinema and a fountain in front of it,
##   - many container stacks round the cranes of the industrial port.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## Where the search for the fire truck starts, and the forest density it needs.
const TRUCK_AT := Vector2i(172, 70)
const FOREST_MIN := 150
## The flying saucer: far from the city and from the secret base, in the south of the desert.
const UFO_AT := Vector2i(64, 152)
## The balloon (cell of its centre; it floats, see BuildingPlacer.KIND_LIFT).
const BALLOON_AT := Vector2i(206, 44)
## Zones with fewer cells than this get no billboard.
const BILLBOARD_MIN_CELLS := 40
## Container yards on the BT tower islet (a few only).
const ISLET_YARDS := 8
## Container yards round each crane: reach in cells.
const PORT_REACH := 26

var _data: CityData
var _taken := PackedByteArray()


static func apply(data: CityData) -> Dictionary:
	var p := PropSites.new()
	p._data = data
	p._taken.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] != Kind.EMPTY:
			p._mark(data.building_rect(b))
	# The cinema first: its fountain must not lose its place to a billboard.
	var cinema := p._cinema()
	var grave := p._graveyard()
	return {"cinema": cinema, "graveyard": grave, "plant": p._plant(), "truck": p._fire_truck(), "billboards": p._billboards(), "balloon": p._balloon(),
			"containers": p._containers(), "post": p._post_offices(),
			"ufo": p._ufo_and_tanks(), "islet": p._islet(), "vegas": p._vegas()}


func _mark(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _data.in_bounds(x, y):
				_taken[_data.idx(x, y)] = 1


## All cells of `r` are dry, free, without road; `zone` >= 0 also asks for that zone.
func _free(r: Rect2i, zone: int = -1, in_park: bool = false) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _taken[i] == 1 or _data.road[i] != 0 or _data.terrain[i] != Terrain.LAND:
				return false
			if _data.zone[i] == Zone.PARK and not in_park: # no building in the big central park
				return false
			if zone >= 0 and _data.zone[i] != zone:
				return false
	return true


func _add(r: Rect2i, kind: int, facing: int, seed: int) -> void:
	_data.add_building(r, kind, facing, seed, 0.5)
	_mark(r)


## The first free rectangle of `size` around `near` (rings of growing radius).
func _near(near: Vector2i, size: Vector2i, zone: int, reach: int, in_park: bool = false) -> Rect2i:
	for radius in reach + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(near + Vector2i(dx, dy) - size / 2, size)
				if _free(r, zone, in_park):
					return r
	return Rect2i()


# --- Fire truck, balloon, billboards --------------------------------------------------------------
func _fire_truck() -> int:
	for radius in 24:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(TRUCK_AT + Vector2i(dx, dy), Vector2i(2, 3))
				var c := r.get_center()
				if _data.in_bounds(c.x, c.y) and _data.forest[_data.idx(c.x, c.y)] >= FOREST_MIN \
						and _free(r, Zone.NATURE):
					_add(r, Kind.FIRE_TRUCK, 2, 1)
					return 1
	return 0


func _balloon() -> int:
	var r := Rect2i(BALLOON_AT - Vector2i(1, 1), Vector2i(3, 3))
	_add(r, Kind.BALLOON, 2, 1)
	return 1


## One billboard in each zone: the free 3x2 spot closest to the middle of the zone.
func _billboards() -> int:
	var sum := {}
	var count := {}
	for y in _data.size:
		for x in _data.size:
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND:
				continue
			var z := int(_data.zone[i])
			if z == Zone.NONE or z == Zone.ISLET:
				continue
			sum[z] = sum.get(z, Vector2.ZERO) + Vector2(x, y)
			count[z] = count.get(z, 0) + 1
	var placed := 0
	for z in count:
		if count[z] < BILLBOARD_MIN_CELLS:
			continue
		var c := Vector2i((sum[z] as Vector2) / float(count[z]))
		var r := _near_in_zone(c, Vector2i(3, 2), z)
		if r.size.x > 0:
			_add(r, Kind.BILLBOARD, 2, z)
			placed += 1
	return placed


## Like `_near`, searched over a wider square and requiring the zone.
func _near_in_zone(near: Vector2i, size: Vector2i, zone: int) -> Rect2i:
	var best := Rect2i()
	var best_d := INF
	for dy in range(-30, 31):
		for dx in range(-30, 31):
			var r := Rect2i(near + Vector2i(dx, dy), size)
			var d := Vector2(dx, dy).length()
			if d < best_d and _free(r, zone):
				best_d = d
				best = r
	return best


# --- The main cinema ------------------------------------------------------------------------------
func _cinema() -> int:
	var cinema := Rect2i()
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.CINEMA_MAIN:
			cinema = _data.building_rect(b)
	if cinema.size.x <= 0:
		return 0
	var placed := 0
	# A fountain in front of it (the front is the south side).
	var fountain := _near(Vector2i(cinema.get_center().x, cinema.end.y + 3), Vector2i(2, 2), -1, 10, true)
	if fountain.size.x > 0:
		_add(fountain, Kind.FOUNTAIN, 2, 1)
		placed += 1
	else:
		# The city is built right up to the cinema: the nearest small lot in front of it
		# becomes the fountain (its number stays).
		var at := Vector2(cinema.get_center().x, cinema.end.y + 3)
		var best := -1
		var best_d := 9.0
		for b in _data.building_count():
			var k: int = _data.b_kind[b]
			var r := _data.building_rect(b)
			if (k == Kind.SHOP or k == Kind.OFFICE or k == Kind.APARTMENT or k == Kind.HOUSE) 					and r.size.x >= 2 and r.size.y >= 2 and r.position.y >= cinema.end.y:
				var d := Vector2(r.get_center()).distance_to(at)
				if d < best_d:
					best_d = d
					best = b
		if best >= 0:
			_data.b_kind[best] = Kind.FOUNTAIN
			placed += 1
	# Buildings behind it: rows of offices north of the cinema.
	for size: int in [3, 2]:
		var y: int = cinema.position.y - size - 1
		while y > cinema.position.y - 16:
			var x: int = cinema.position.x - 6
			while x < cinema.end.x + 6:
				var r := Rect2i(x, y, size, size)
				if _free(r):
					_add(r, Kind.OFFICE, 2, CityTypes.hash2(x, y, 646))
					placed += 1
					x += size + 1
				else:
					x += 1
			y -= size + 1
	return placed


# --- The industrial port ---------------------------------------------------------------------------
## 2x2 container yards (three stacks and one on top each; their seed is a multiple of 3, which
## the yards read as "containers") on every free industrial cell round the cranes, with an
## aisle every fourth column.
func _containers() -> int:
	var cranes: Array[Vector2i] = []
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.CRANE and _data.zone_at(_data.building_rect(b).position.x,
				_data.building_rect(b).position.y) == Zone.INDUSTRIAL:
			cranes.append(_data.building_rect(b).get_center())
	if cranes.is_empty():
		return 0
	var placed := 0
	for c in cranes:
		for y in range(c.y - PORT_REACH, c.y + PORT_REACH):
			for x in range(c.x - PORT_REACH, c.x + PORT_REACH):
				# An aisle every seventh column and row keeps the stacks in blocks.
				if x % 7 == 6 or y % 7 == 6 or Vector2(x - c.x, y - c.y).length() > PORT_REACH:
					continue
				var r := Rect2i(x, y, 2, 2)
				if _free(r, Zone.INDUSTRIAL):
					_add(r, Kind.INDUSTRIAL_YARD, 2, (CityTypes.hash2(x, y, 5) & 0xfffff) * 3)
					placed += 1
	return placed


# --- Two more post offices ---------------------------------------------------------------------------
## Same size as the one of the city (3x2): one in the poor district and one in the red district.
## Every lot there is built, so the closest lot of at least 3x2 becomes the post office
## (the number of the building stays).
func _post_offices() -> int:
	var placed := 0
	for spec: Array in [[Vector2i(122, 76), Zone.POOR], [Vector2i(138, 211), Zone.QUARTER]]:
		var best := -1
		var best_d := INF
		for b in _data.building_count():
			var r := _data.building_rect(b)
			var k: int = _data.b_kind[b]
			if k != Kind.SHOP and k != Kind.POOR_BLDG and k != Kind.QUARTER_BLDG and k != Kind.OFFICE:
				continue
			if _data.zone_at(r.position.x, r.position.y) != spec[1]:
				continue
			if not ((r.size.x >= 3 and r.size.y >= 2) or (r.size.x >= 2 and r.size.y >= 3)):
				continue
			var d := Vector2(r.get_center()).distance_to(Vector2(spec[0]))
			if d < best_d:
				best_d = d
				best = b
		if best >= 0:
			_data.b_kind[best] = Kind.POST_OFFICE
			placed += 1
	return placed


# --- The secret base: UFO on the ground and tanks at the gates ---------------------------------------
func _ufo_and_tanks() -> int:
	var base := Rect2i()
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.AIRBASE:
			base = _data.building_rect(b)
	if base.size.x <= 0:
		return 0
	var placed := 0
	var ufo := _near_in_zone(UFO_AT, Vector2i(3, 3), Zone.DESERT)
	if ufo.size.x > 0:
		_add(ufo, Kind.UFO, 2, 1)
		placed += 1
	# A tank just outside each gate of the fence (west and south side).
	var fence := AmenitiesPlanner.base_fence(base)
	var west := fence["gates"][0] as Vector2i
	var south := fence["gates"][1] as Vector2i
	for spec in [[west + Vector2i(-4, 1), Vector2i(3, 2), 3], [south + Vector2i(1, 3), Vector2i(2, 3), 2]]:
		var r := _near_in_zone(spec[0], spec[1], Zone.DESERT)
		if r.size.x > 0:
			_add(r, Kind.TANK, spec[2], 1)
			placed += 1
	return placed


# --- The BT tower islet: a crane and many containers -----------------------------------------------------
func _islet() -> int:
	var at := Vector2i(ExtensionIsland.TOWER_ISLET["at"])
	var placed := 0
	# A crane at the water's edge, on the south side of the islet.
	for dy in range(8, 0, -1):
		var r := Rect2i(at.x - 2, at.y + dy - 1, 2, 2)
		if _free(r, Zone.INDUSTRIAL) and _near_water(r.position.x, r.position.y, 2):
			_add(r, Kind.CRANE, 2, 1)
			placed += 1
			break
	var yards := 0
	for y in range(at.y - 4, at.y + 5):
		for x in range(at.x - 8, at.x + 9):
			if yards >= ISLET_YARDS or x % 7 == 6 or y % 7 == 6:
				continue
			var r := Rect2i(x, y, 2, 2)
			if _free(r, Zone.INDUSTRIAL):
				yards += 1
				_add(r, Kind.INDUSTRIAL_YARD, 2, (CityTypes.hash2(x, y, 9) & 0xfffff) * 3)
				placed += 1
	return placed


func _near_water(x: int, y: int, dist: int) -> bool:
	for dy in range(-dist, dist + 2):
		for dx in range(-dist, dist + 2):
			if _data.in_bounds(x + dx, y + dy) and _data.terrain[_data.idx(x + dx, y + dy)] < Terrain.BEACH:
				return true
	return false


# --- Las Vegas: more buildings in the free lots ---------------------------------------------------------
func _vegas() -> int:
	var placed := 0
	for size: int in [3, 2]:
		for y in range(0, _data.size - size):
			for x in range(0, _data.size - size):
				var i := _data.idx(x, y)
				if _data.zone[i] != Zone.ENTERTAINMENT or _taken[i] == 1:
					continue
				var r := Rect2i(x, y, size, size)
				if _free(r, Zone.ENTERTAINMENT) and _faces_street(r):
					_add(r, Kind.OFFICE if size == 3 else Kind.SHOP, _street_side(r), CityTypes.hash2(x, y, 88))
					placed += 1
	return placed


## The side of `r` that touches a road, -1 when none.
func _street_side(r: Rect2i) -> int:
	return LotPlanner.road_facing(_data, r, CityTypes.hash2(r.position.x, r.position.y, 3), true)


func _faces_street(r: Rect2i) -> bool:
	return _street_side(r) >= 0


# --- The graveyard on the tiny islet of the south -------------------------------------------------------
func _graveyard() -> int:
	var r := _near(Vector2i(151, 256), Vector2i(3, 2), -1, 3)
	if r.size.x <= 0:
		return 0
	_add(r, Kind.CEMETERY, 2, 1)
	return 1


# --- The nuclear plant: more containers and a fire truck ---------------------------------------------------
func _plant() -> int:
	var plant := Rect2i()
	for b in _data.building_count():
		if _data.b_kind[b] == Kind.NUCLEAR_PLANT and (plant.size.x <= 0 or _data.building_rect(b).size.x > plant.size.x):
			plant = _data.building_rect(b)
	if plant.size.x <= 0:
		return 0
	var placed := 0
	var yards := 0
	for y in range(plant.position.y + 6, plant.end.y + 14):
		for x in range(plant.position.x - 6, plant.end.x + 10):
			if yards >= 14 or x % 7 == 6 or y % 7 == 6:
				continue
			var r := Rect2i(x, y, 2, 2)
			if _free(r, Zone.URBAN):
				_add(r, Kind.INDUSTRIAL_YARD, 2, (CityTypes.hash2(x, y, 12) & 0xfffff) * 3)
				yards += 1
				placed += 1
	var truck := _near(Vector2i(plant.position.x - 3, plant.end.y + 3), Vector2i(2, 3), Zone.URBAN, 8)
	if truck.size.x > 0:
		_add(truck, Kind.FIRE_TRUCK, 2, 2)
		placed += 1
	return placed
