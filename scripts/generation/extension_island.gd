class_name ExtensionIsland
extends IslandShaper
## The big map around the finished city. The core island (the city as it was
## before the extension) sits in the middle with its exact coastline; lobes of
## land are added around it for the new districts, plus three palm islets and
## a prison island far from the shore. Terrain, mainland and forest are then
## worked out for the whole map, keeping what the core already has.

## How ragged the coast of the big island is, compared with the core island.
const COAST_ROUGHNESS := 0.5

## The finished core city and its elevation, embedded at `offset` cells.
var core: CityData
var core_height := PackedFloat32Array()
var offset := 72


func shape() -> void:
	_build_extended_elevation()
	_classify_terrain()
	_find_mainland()
	_build_forest()


func is_buildable(x: int, y: int) -> bool:
	return is_mainland(x, y) or (is_urban_island(x, y) and _data.terrain[y * _data.size + x] == CityTypes.Terrain.LAND)


func is_urban_island(x: int, y: int) -> bool:
	var p := Vector2(x, y)
	if _ellipse_t(p, MapLayout.blob("urban")["at"], MapLayout.blob("urban")["r"], 0.0) < 1.15:
		return true
	return _ellipse_t(p, MapLayout.blob("urban_north")["at"], MapLayout.blob("urban_north")["r"], 0.0) < 1.15


func is_tower_islet(x: int, y: int) -> bool:
	return _ellipse_t(Vector2(x, y), MapLayout.blob("tower_islet")["at"], MapLayout.blob("tower_islet")["r"], 0.0) < 1.15


func is_prison_island(x: int, y: int) -> bool:
	return _ellipse_t(Vector2(x, y), MapLayout.blob("prison")["at"], MapLayout.blob("prison")["r"], MapLayout.blob("prison")["turn"]) < 1.12


## True where (x, y) lies on land in the core city's own grid.
func core_land_at(x: int, y: int) -> bool:
	var cx := x - offset
	var cy := y - offset
	return cx >= 0 and cy >= 0 and cx < core.size and cy < core.size \
			and core.terrain[cy * core.size + cx] >= CityTypes.Terrain.BEACH


# --- Elevation --------------------------------------------------------------------------
func _build_extended_elevation() -> void:
	var size := _data.size
	height.resize(size * size)
	height.fill(-1.0)
	for y in core.size:
		for x in core.size:
			height[(y + offset) * size + x + offset] = core_height[y * core.size + x]
	var coast := FastNoiseLite.new()
	coast.seed = _cfg.seed + 4242
	coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	coast.fractal_octaves = 4
	coast.frequency = 4.0 / float(_cfg.core_size)
	var main_at: Vector2 = MapLayout.blob("main")["at"]
	var main_r: Vector2 = MapLayout.blob("main")["r"]
	for y in size:
		for x in size:
			var t := _ellipse_t(Vector2(x, y), main_at, main_r, 0.0)
			_raise(x, y, 1.0 - t * t + coast.get_noise_2d(x, y) * _cfg.coast_noise * COAST_ROUGHNESS)
	for lobe in [MapLayout.blob("urban"), MapLayout.blob("urban_north"), MapLayout.blob("tower_islet")]:
		_rough_lobe(coast, lobe["at"], lobe["r"])
	for it in MapLayout.palm_islets():
		_islet(coast, it["at"], Vector2(it["r"], it["r"]), 0.0, 0.3, 0.05, 3.0)
	_islet(coast, MapLayout.blob("prison")["at"], MapLayout.blob("prison")["r"], MapLayout.blob("prison")["turn"], 0.4, 0.15, 2.7)
	for y in size:
		for x in size:
			var edge := minf(minf(x, y), minf(size - 1 - x, size - 1 - y))
			var i := y * size + x
			if edge < 6:
				height[i] = minf(height[i], -0.3 + edge * 0.03)


## A lobe of land: a rounded ellipse with a slightly ragged coast.
func _raise_lobe(coast: FastNoiseLite, at: Vector2, r: Vector2) -> void:
	var size := _data.size
	for y in range(maxi(int(at.y - r.y * 1.3), 0), mini(int(at.y + r.y * 1.3), size)):
		for x in range(maxi(int(at.x - r.x * 1.4), 0), mini(int(at.x + r.x * 1.4), size)):
			var t := _ellipse_t(Vector2(x, y), at, r, 0.0)
			_raise(x, y, 1.0 - t * t + coast.get_noise_2d(x * 1.4, y * 1.4) * 0.12)


## A lobe with a natural coast, like the prison island: bays and capes cut by two layers of
## noise. The noise only ever cuts inwards (the land stays inside 1.15 of the ellipse, where
## the zone tests of the island look), and never on the lots of the nuclear plants
## (UrbanIslandRebuild.PLANT_LOTS), which keep their place.
## Strength and frequency (times the coast noise) of the two layers, and the most a cape may
## add (the land stays inside 1.15 of the ellipse: 1 - 1.15^2 + 0.3 < 0).
const ROUGH_COAST := Vector2(0.4, 0.16)
const ROUGH_FREQ := Vector2(2.7, 6.5)
const ROUGH_CAPE := 0.3
## The middle of a lobe (t below this) and a strip along the spine of the urban island (from
## the middle of its south lobe to the middle of its north lobe, this many cells either side)
## are never cut, so the island stays in one piece.
const ROUGH_CORE := 0.6
const SPINE_HALF_WIDTH := 6.0


func _rough_lobe(coast: FastNoiseLite, at: Vector2, r: Vector2) -> void:
	var size := _data.size
	var keep: Array[Rect2i] = []
	for lot: Rect2i in UrbanIslandRebuild.PLANT_LOTS:
		keep.append(lot.grow(3))
	var spine_a: Vector2 = MapLayout.blob("urban")["at"]
	var spine_b: Vector2 = MapLayout.blob("urban_north")["at"]
	for y in range(maxi(int(at.y - r.y * 1.3), 0), mini(int(at.y + r.y * 1.3), size)):
		for x in range(maxi(int(at.x - r.x * 1.4), 0), mini(int(at.x + r.x * 1.4), size)):
			var t := _ellipse_t(Vector2(x, y), at, r, 0.0)
			var n := minf(coast.get_noise_2d(x * ROUGH_FREQ.x, y * ROUGH_FREQ.x) * ROUGH_COAST.x 					+ coast.get_noise_2d(x * ROUGH_FREQ.y + 311.0, y * ROUGH_FREQ.y) * ROUGH_COAST.y, ROUGH_CAPE)
			if t < ROUGH_CORE:
				n = maxf(n, 0.0)
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, spine_a, spine_b)) < SPINE_HALF_WIDTH:
				n = maxf(n, 0.15)
			for k in keep:
				if k.has_point(Vector2i(x, y)):
					n = maxf(n, 0.15)
			_raise(x, y, 1.0 - t * t + n)


func _islet(coast: FastNoiseLite, at: Vector2, r: Vector2, turn: float, lift: float,
		rough: float, freq: float) -> void:
	var size := _data.size
	for y in range(maxi(int(at.y - r.y * 1.6), 0), mini(int(at.y + r.y * 1.6), size)):
		for x in range(maxi(int(at.x - r.x * 1.6), 0), mini(int(at.x + r.x * 1.6), size)):
			var t := _ellipse_t(Vector2(x, y), at, r, turn)
			_raise(x, y, (1.0 - t * t) * lift + coast.get_noise_2d(x * freq, y * freq) * rough)


func _raise(x: int, y: int, e: float) -> void:
	var i := y * _data.size + x
	height[i] = maxf(height[i], e)


## Distance from the centre of a turned ellipse, 1 on its border.
func _ellipse_t(p: Vector2, at: Vector2, r: Vector2, turn: float) -> float:
	var d := (p + Vector2(0.5, 0.5) - at).rotated(-turn)
	return Vector2(d.x / r.x, d.y / r.y).length()


# --- Shores and forests: only new land, the core keeps its own -----------------------------
func _mark_rocky_shores() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = _cfg.seed + 33
	noise.frequency = 6.0 / float(_cfg.core_size)
	for y in _data.size:
		for x in _data.size:
			var i := y * _data.size + x
			if _data.terrain[i] != CityTypes.Terrain.BEACH or core_land_at(x, y):
				continue
			if noise.get_noise_2d(x, y) > 0.15 or is_prison_island(x, y):
				_data.rocky[i] = 1


func _build_forest() -> void:
	var size := _data.size
	var noise := FastNoiseLite.new()
	noise.seed = _cfg.seed + 77
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 3
	noise.frequency = 9.0 / float(_cfg.core_size)
	for y in size:
		for x in size:
			var i := y * size + x
			if core_land_at(x, y):
				continue # keep the forest of the core
			if _data.terrain[i] != CityTypes.Terrain.LAND:
				_data.forest[i] = 0
				continue
			var f := noise.get_noise_2d(x, y) * 0.5 + 0.5
			f = clampf((f - 0.35) * 1.8 + (height[i] - 0.15), 0.0, 1.0)
			_data.forest[i] = int(f * 255.0)
