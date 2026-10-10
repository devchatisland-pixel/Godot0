class_name ExtensionFeatures
extends RefCounted
## Single places of the extension, set on free land after the roads and lots:
## the desert with the secret base, the industrial zone and its port, farm
## fields, the extra mountains, the pirate grave, the prison compound, the
## lighthouses and the two watchtowers of the forests.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

## Round districts: centre and radii in cells of the big map.
const DESERT := {"at": Vector2(78, 128), "r": Vector2(22, 36)}
const INDUSTRIAL := {"at": Vector2(84, 182), "r": Vector2(22, 19)}
const FARM := {"at": Vector2(202, 190), "r": Vector2(24, 32)}
const FOREST := {"at": Vector2(178, 62), "r": Vector2(34, 17)}
## The smallest palm islet: the pirate grave stands on it, the pirate ship lies off its coast.
const PIRATE_ISLET := Vector2i(250, 92)
## The 8 buildings of the industrial zone: sizes in cells.
const FACTORY_SIZES := [Vector2i(7, 4), Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 3),
		Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 3), Vector2i(3, 3)]
const AIRBASE_SIZES := [Vector2i(16, 5), Vector2i(14, 5), Vector2i(12, 4)]
## Watchtowers: the forest density (0..255) a tower needs at its centre.
const WATCHTOWER_FOREST := 150

var _data: CityData
var _island: ExtensionIsland
var _spots: ExtensionSpots
var _rng: RandomNumberGenerator


func _init(data: CityData, island: ExtensionIsland, spots: ExtensionSpots, rng: RandomNumberGenerator) -> void:
	_data = data
	_island = island
	_spots = spots
	_rng = rng


## The order matters: every step takes the random numbers the previous one left.
func build_all(core_forest: Rect2i) -> void:
	build_desert()
	build_industrial()
	build_farms()
	build_watchtowers(core_forest)
	build_mountains()
	build_pirate_islet()
	build_prison()
	build_lighthouses()


# --- Desert -----------------------------------------------------------------------------------
## The desert next to Las Vegas: the secret base (airbase, bunker, radio station), mesas,
## ranches and oil pumps, far apart from each other.
func build_desert() -> void:
	var c := Vector2i(DESERT["at"])
	for size in AIRBASE_SIZES:
		var r := _spots.find_spot(c + Vector2i(-size.x / 2, -14), size, Zone.DESERT, 16, 2)
		if r.size.x > 0:
			_spots.claim(r, Kind.AIRBASE, 2, Zone.CIVIC)
			break
	var bunker := _spots.find_spot(c + Vector2i(2, 14), Vector2i(3, 3), Zone.DESERT, 12, 3)
	if bunker.size.x > 0:
		_spots.claim(bunker, Kind.BUNKER, 2, Zone.CIVIC)
	var tower := _spots.find_spot(c + Vector2i(-6, 4), Vector2i(2, 2), Zone.DESERT, 12, 2)
	if tower.size.x > 0:
		_spots.claim(tower, Kind.TELECOM_TOWER, 2, Zone.CIVIC)
		for o in [Vector2i(4, -1), Vector2i(4, 3), Vector2i(0, 4)]:
			var d := Rect2i(tower.position + o, Vector2i(2, 2))
			if _spots.spot_free(d, Zone.DESERT, 0):
				_spots.claim(d, Kind.SAT_DISH, 3, Zone.CIVIC)
	var rect := _spots.blob_rect(DESERT)
	for r in _spots.spots(rect, Zone.DESERT, Vector2i(6, 4), 2, 20.0, 1):
		_spots.claim(r, Kind.MESA, 2)
	var i := 0
	for r in _spots.spots(rect, Zone.DESERT, Vector2i(2, 2), 3, 14.0, 2):
		_spots.claim(r, Kind.OUTPOST, 2, -1, i * 3)
		i += 1
	for r in _spots.spots(rect, Zone.DESERT, Vector2i(2, 2), 7, 9.0, 1):
		_spots.claim(r, Kind.OIL_PUMP, 2)


# --- Industrial zone and port -----------------------------------------------------------------
## Exactly 8 different buildings (variant 0..7), and the port: container yards
## and two cranes on the quay.
func build_industrial() -> void:
	var rect := _spots.blob_rect(INDUSTRIAL)
	for i in FACTORY_SIZES.size():
		var r := _spots.spots_one(rect, Zone.INDUSTRIAL, FACTORY_SIZES[i], 1)
		if r.size.x > 0:
			_spots.claim(r, Kind.FACTORY_BLDG, 2, -1, i)
	var quay: Array[Rect2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _spots.near_water(x, y, 3) and _data.in_bounds(x, y) \
					and _data.zone[_data.idx(x, y)] == Zone.INDUSTRIAL:
				var r := Rect2i(x, y, 2, 2)
				if _spots.spot_free(r, Zone.INDUSTRIAL, 0) and not quay.any(func(q: Rect2i) -> bool:
						return Vector2(q.get_center()).distance_to(Vector2(r.get_center())) < 5.0):
					quay.append(r)
	var cranes := 0
	for k in quay.size():
		if cranes < 2 and k % 3 == 1:
			_spots.claim(quay[k], Kind.CRANE, 2)
			cranes += 1
		elif k % 3 != 1:
			_spots.claim(quay[k], Kind.INDUSTRIAL_YARD, 2, -1, k)


# --- Farms --------------------------------------------------------------------------------------
## Farm houses and barns, then crop fields tiled over the one farmland district.
func build_farms() -> void:
	var rect := _spots.blob_rect(FARM)
	var k := 0
	for yard in _spots.spots(rect, Zone.FARM, Vector2i(2, 2), 4, 14.0, 2, 600):
		_spots.claim(yard, Kind.OUTPOST, 2, Zone.CIVIC, k * 3)
		k += 1
		var side := Rect2i(yard.position + Vector2i(3, 0), Vector2i(2, 2))
		if _spots.spot_free(side, Zone.FARM, 0):
			_spots.claim(side, Kind.OUTPOST, 2, Zone.CIVIC, k * 3 + 1)
			k += 1
	var y := rect.position.y
	while y < rect.end.y:
		var h := _rng.randi_range(4, 6)
		var x := rect.position.x
		while x < rect.end.x:
			var w := _rng.randi_range(5, 8)
			var field := _shrink_to_fit(x, y, w, h)
			if field.size.x > 0:
				_spots.claim(field, Kind.FIELD, 2, Zone.FARM, _rng.randi())
			x += w + 1
		y += h + 1


## The biggest field starting at (x, y), at most w x h, that fits on the free farmland.
func _shrink_to_fit(x: int, y: int, w: int, h: int) -> Rect2i:
	for dw in range(0, w - 3):
		for dh in range(0, h - 3):
			var r := Rect2i(x, y, w - dw, h - dh)
			if _spots.spot_free(r, Zone.FARM, 0):
				return r
	return Rect2i()


# --- Watchtowers --------------------------------------------------------------------------------
## Two wooden lookouts, each in the thick of a forest: one in the north-east wood and
## one in the forest of the old city. A tower needs a free 3x3 plot of dense forest.
func build_watchtowers(core_forest: Rect2i) -> void:
	var starts: Array[Vector2i] = [Vector2i(FOREST["at"]) + Vector2i(-10, 6), core_forest.get_center()]
	for k in starts.size():
		var r := _forest_spot(starts[k], Vector2i(3, 3), 16)
		if r.size.x > 0:
			_spots.claim(r, Kind.WATCHTOWER, 2, -1, k)


## The free plot of nature ground nearest to `near` whose centre has a dense forest.
func _forest_spot(near: Vector2i, size: Vector2i, max_radius: int) -> Rect2i:
	for radius in max_radius + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var r := Rect2i(near + Vector2i(dx, dy), size)
				var c := r.get_center()
				if not _data.in_bounds(c.x, c.y) or _data.forest[_data.idx(c.x, c.y)] < WATCHTOWER_FOREST:
					continue
				if _spots.spot_free(r, Zone.NATURE, 1):
					return r
	return Rect2i()


# --- Mountains, islet, prison ---------------------------------------------------------------------
## Two more mountains next to the one of the core, in the forest.
func build_mountains() -> void:
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
		var r := _spots.find_spot(first + o - Vector2i(4, 4), Vector2i(8, 8), Zone.NATURE, 8, 0)
		if r.size.x > 0:
			_spots.claim(r, Kind.MOUNTAIN, 2, -1, seeds[i])
			i += 1


## The pirate grave on the smallest islet, and the pirate ship anchored just off its coast.
func build_pirate_islet() -> void:
	var grave := _spots.find_spot(PIRATE_ISLET, Vector2i.ONE, Zone.ISLET, 3, 0)
	if grave.size.x > 0:
		_spots.claim(grave, Kind.GRAVE, 2)
	var ship := _spots.find_water(PIRATE_ISLET + Vector2i(-9, 4), Vector2i(7, 3), 8)
	if ship.size.x > 0:
		_spots.claim(ship, Kind.PIRATE_SHIP, 2)


## The prison compound: a big cellhouse, stone wings, a villa and lighthouses.
func build_prison() -> void:
	var c := Vector2i(ExtensionIsland.PRISON["at"])
	var main := Rect2i()
	for size in [Vector2i(11, 8), Vector2i(10, 7), Vector2i(9, 6), Vector2i(7, 5)]:
		main = _spots.find_spot(c - size / 2, size, Zone.PRISON, 6, 0)
		if main.size.x > 0:
			break
	if main.size.x > 0:
		_spots.claim(main, Kind.PRISON, 2)
	var wings := [Vector2i(3, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 3)]
	var offsets := [Vector2i(-6, -5), Vector2i(7, -6), Vector2i(-8, 3), Vector2i(8, 6), Vector2i(-3, 9), Vector2i(12, -1)]
	for i in wings.size():
		var near: Vector2i = (main.position if main.size.x > 0 else c) + offsets[i]
		var r := _spots.find_spot(near, wings[i], Zone.PRISON, 5, 0)
		if r.size.x > 0:
			_spots.claim(r, Kind.PRISON_WING, 2, -1, i)


# --- Lighthouses ----------------------------------------------------------------------------------
## Four on the coast of the main island, spread round it, and two at the ends of the prison
## island. Each one stands on a dry cell with the sea less than three cells away.
func build_lighthouses() -> void:
	var main_at: Vector2 = ExtensionIsland.MAIN["at"]
	for deg in [135.0, 235.0, 330.0, 60.0]:
		var cell := _coast_cell(main_at, Vector2.from_angle(deg_to_rad(deg)), false)
		if cell.x >= 0:
			_spots.claim(Rect2i(cell, Vector2i.ONE), Kind.LIGHTHOUSE, 2)
	var prison_at: Vector2 = ExtensionIsland.PRISON["at"]
	var turn: float = ExtensionIsland.PRISON["turn"]
	for sign in [-1.0, 1.0]:
		var cell := _coast_cell(prison_at, Vector2.from_angle(turn) * sign, true)
		if cell.x >= 0:
			_spots.claim(Rect2i(cell, Vector2i.ONE), Kind.LIGHTHOUSE, 2)


## The free coast cell furthest in direction `dir` from `center`: dry, open meadow or
## sand (or the prison island), with the sea within two cells.
func _coast_cell(center: Vector2, dir: Vector2, prison: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for y in _data.size:
		for x in _data.size:
			var i := _data.idx(x, y)
			if _data.terrain[i] != Terrain.LAND or _data.road[i] != 0 or _spots.lots.owner[i] != -1:
				continue
			var z := _data.zone[i]
			if prison:
				if z != Zone.PRISON:
					continue
			elif not ((z == Zone.NATURE or z == Zone.SAND or z == Zone.FARM) and _island.is_mainland(x, y)):
				continue
			var score := (Vector2(x, y) - center).dot(dir)
			if score > best_score and _spots.near_water(x, y, 2):
				best_score = score
				best = Vector2i(x, y)
	return best
