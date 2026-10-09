class_name ExtensionIsland
extends IslandShaper
## The big map around the finished city. The core island (the city as it was
## before the extension) sits in the middle with its exact coastline; lobes of
## land are added around it for the new districts, plus three palm islets and
## a prison island far from the shore. Terrain, mainland and forest are then
## worked out for the whole map, keeping what the core already has.

## Lobes of land: centre and radii in cells of the big map.
const LOBES := [
	{"at": Vector2(30, 98), "r": Vector2(22, 32)},    # west: desert, poor district
	{"at": Vector2(42, 140), "r": Vector2(28, 18)},   # south-west: industrial zone
	{"at": Vector2(80, 32), "r": Vector2(32, 24)},    # north: mountains and forest
	{"at": Vector2(94, 152), "r": Vector2(30, 18)},   # south: the red quarter grows
	{"at": Vector2(138, 152), "r": Vector2(24, 22)},  # south-east: farmland
]
## Palm islets: centre and radius in cells.
const PALM_ISLETS := [
	{"at": Vector2(52, 178), "r": 4.5}, {"at": Vector2(126, 178), "r": 5.0},
	{"at": Vector2(150, 118), "r": 3.5},
]
## The prison island: centre, radii (long and short side) and turn in radians.
const PRISON := {"at": Vector2(20, 34), "r": Vector2(15.0, 10.0), "turn": 0.45}
## East of this column the sea is kept clear for the fog island.
const FOG_GUARD := 158

## The finished core city and its elevation, embedded at `offset` cells.
var core: CityData
var core_height := PackedFloat32Array()
var offset := 32


func shape() -> void:
	_build_extended_elevation()
	_classify_terrain()
	_find_mainland()
	_build_forest()


func is_prison_island(x: int, y: int) -> bool:
	return _ellipse_t(Vector2(x, y), PRISON["at"], PRISON["r"], PRISON["turn"]) < 1.12


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
	for lobe in LOBES:
		var at: Vector2 = lobe["at"]
		var r: Vector2 = lobe["r"]
		for y in range(maxi(int(at.y - r.y * 1.3), 0), mini(int(at.y + r.y * 1.3), size)):
			for x in range(maxi(int(at.x - r.x * 1.3), 0), mini(int(at.x + r.x * 1.3), size)):
				var t := _ellipse_t(Vector2(x, y), at, r, 0.0)
				var e := 1.0 - t * t + coast.get_noise_2d(x, y) * _cfg.coast_noise * 0.9
				_raise(x, y, e)
	for it in PALM_ISLETS:
		_islet(coast, it["at"], Vector2(it["r"], it["r"]), 0.0, 0.3, 0.05, 3.0)
	_islet(coast, PRISON["at"], PRISON["r"], PRISON["turn"], 0.4, 0.15, 2.7)
	for y in size:
		for x in size:
			var edge := minf(minf(x, y), minf(size - 1 - x, size - 1 - y))
			var i := y * size + x
			if edge < 6:
				height[i] = minf(height[i], -0.3 + edge * 0.03)
			if x >= FOG_GUARD:
				height[i] = minf(height[i], -0.3)


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
