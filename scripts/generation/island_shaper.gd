class_name IslandShaper
extends RefCounted
## Builds the island: elevation, terrain classes, forests and the main landmass.

var _cfg: CityConfig
var _data: CityData
## 1 for cells of the biggest landmass (the only one that gets a city).
var mainland := PackedByteArray()
## Raw elevation (> 0 is above sea level). Freed by the generator when done.
var height := PackedFloat32Array()


func _init(cfg: CityConfig, data: CityData) -> void:
	_cfg = cfg
	_data = data


func shape() -> void:
	_build_elevation()
	_classify_terrain()
	_find_mainland()
	_build_forest()


func elevation_at(x: int, y: int) -> float:
	return height[y * _data.size + x]


# --- Elevation -------------------------------------------------------------------
## Small islands: palm islets off the south coast and the rocky prison island
## off the north-west coast, facing downtown
## (position in island units: 1 = radius; radius as a fraction of the map).
const ISLETS := [
	{"at": Vector2(0.05, 1.2), "radius": 0.034},
	{"at": Vector2(0.82, 0.84), "radius": 0.028},
	{"at": Vector2(-0.55, 1.05), "radius": 0.023},
	{"at": Vector2(-0.92, -0.95), "radius": 0.054, "prison": true},
]

## Centre and radius (cells) of the prison island; radius 0 = none.
var prison_center := Vector2.ZERO
var prison_radius := 0.0


func _build_elevation() -> void:
	var size := _data.size
	var coast := FastNoiseLite.new()
	coast.seed = _cfg.seed
	coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	coast.fractal_octaves = 4
	coast.frequency = 4.0 / float(size)

	height.resize(size * size)
	var half := float(size) * 0.5
	var radius := Vector2(half, half) * _cfg.island_radius
	var islets := []
	for it in ISLETS:
		var at: Vector2 = it["at"]
		var c := Vector2(half + at.x * radius.x, half + at.y * radius.y)
		islets.append([c, float(it["radius"]) * size])
		if it.get("prison", false):
			prison_center = c
			prison_radius = float(it["radius"]) * size
	for y in size:
		var ny := (float(y) + 0.5 - half) / radius.y
		for x in size:
			var nx := (float(x) + 0.5 - half) / radius.x
			var e := 1.0 - (nx * nx + ny * ny)
			e += coast.get_noise_2d(x, y) * _cfg.coast_noise
			for isl in islets:
				var t: float = Vector2(x, y).distance_to(isl[0]) / isl[1]
				e = maxf(e, (1.0 - t * t) * 0.3 + coast.get_noise_2d(x * 3, y * 3) * 0.05)
			# Hard edge so the map border is always ocean.
			var edge := minf(minf(x, y), minf(size - 1 - x, size - 1 - y))
			if edge < 6:
				e = minf(e, -0.3 + edge * 0.03)
			height[y * size + x] = e


func _classify_terrain() -> void:
	var n := _data.size * _data.size
	var beach := _cfg.beach_width
	var shallow := _cfg.shallow_width
	for i in n:
		var e := height[i]
		var t := CityTypes.Terrain.LAND
		if e < -shallow:
			t = CityTypes.Terrain.DEEP
		elif e < 0.0:
			t = CityTypes.Terrain.SHALLOW
		elif e < beach:
			t = CityTypes.Terrain.BEACH
		_data.terrain[i] = t
		_data.elevation[i] = clampi(128 + int(e * 255.0), 0, 255)
	_mark_rocky_shores()


## Some stretches of coast are rocky cliffs instead of beaches.
func _mark_rocky_shores() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = _cfg.seed + 33
	noise.frequency = 6.0 / float(_data.size)
	for y in _data.size:
		for x in _data.size:
			var i := y * _data.size + x
			if _data.terrain[i] != CityTypes.Terrain.BEACH:
				continue
			# The prison island is all rocks, like the real one.
			if noise.get_noise_2d(x, y) > 0.15 or is_prison_island(x, y):
				_data.rocky[i] = 1


# --- Mainland (largest connected land area) ---------------------------------------
func _find_mainland() -> void:
	var size := _data.size
	var n := size * size
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	var best_label := -1
	var best_count := 0
	var current := 0
	var stack := PackedInt32Array()
	for start in n:
		if label[start] != -1 or _data.terrain[start] < CityTypes.Terrain.BEACH:
			continue
		var count := 0
		stack.append(start)
		label[start] = current
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := i % size
			var y := i / size
			for o in CityTypes.FACING_OFFSETS:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var j := ny * size + nx
				if label[j] == -1 and _data.terrain[j] >= CityTypes.Terrain.BEACH:
					label[j] = current
					stack.append(j)
		if count > best_count:
			best_count = count
			best_label = current
		current += 1
	mainland.resize(n)
	for i in n:
		mainland[i] = 1 if label[i] == best_label and best_label >= 0 else 0


func is_prison_island(x: int, y: int) -> bool:
	return prison_radius > 0.0 and Vector2(x, y).distance_to(prison_center) < prison_radius * 1.4


func is_mainland(x: int, y: int) -> bool:
	return _data.in_bounds(x, y) and mainland[y * _data.size + x] == 1


# --- Forest density (trees in nature zones) ------------------------------------------
func _build_forest() -> void:
	var size := _data.size
	var noise := FastNoiseLite.new()
	noise.seed = _cfg.seed + 77
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 3
	noise.frequency = 9.0 / float(size)
	for y in size:
		for x in size:
			var i := y * size + x
			if _data.terrain[i] != CityTypes.Terrain.LAND:
				_data.forest[i] = 0
				continue
			var f := noise.get_noise_2d(x, y) * 0.5 + 0.5
			# Forests prefer higher land, keep coasts as meadows.
			f = clampf((f - 0.35) * 1.8 + (height[i] - 0.15), 0.0, 1.0)
			_data.forest[i] = int(f * 255.0)
