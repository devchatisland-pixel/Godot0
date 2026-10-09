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
func _build_elevation() -> void:
	var size := _data.size
	var coast := FastNoiseLite.new()
	coast.seed = _cfg.seed
	coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	coast.fractal_octaves = 5
	coast.frequency = 3.2 / float(size)
	coast.domain_warp_enabled = true
	coast.domain_warp_amplitude = float(size) * 0.05
	coast.domain_warp_frequency = 1.5 / float(size)

	height.resize(size * size)
	var half := float(size) * 0.5
	var radius := half * _cfg.island_radius
	for y in size:
		var ny := (float(y) + 0.5 - half) / radius
		for x in size:
			var nx := (float(x) + 0.5 - half) / radius
			# Slightly elliptical falloff gives a less "perfect circle" island.
			var d2 := nx * nx * 0.9 + ny * ny * 1.1
			var e := 1.0 - d2
			e += coast.get_noise_2d(x, y) * _cfg.coast_noise
			# Hard edge so the map border is always ocean.
			var edge := minf(minf(x, y), minf(size - 1 - x, size - 1 - y))
			if edge < 12:
				e = minf(e, -0.3 + edge * 0.02)
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
