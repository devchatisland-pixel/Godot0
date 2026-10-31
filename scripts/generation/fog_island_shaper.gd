class_name FogIslandShaper
extends RefCounted
## The second island, east of Chat City, hidden in the fog until "season 2".
## Only what shows through the fog is generated: the ground colours, with the concrete and
## tarmac of the military base (FogBaseSites.PADS; no tree grows). It is not part of
## the cell grid of the city (no roads or lots), so it costs almost nothing.
## Runs on the generation thread; the FogIsland node draws it.

## Size of the island square in cells: 1.5 times the first version (128), so about
## twice the area. Only the fog grows: the buildings stay where they were, in the middle.
const SIZE := 192
## Moves the original 128-cell layout to the middle of the bigger square.
const SHIFT := Vector2(28.0, 32.0)
## Hills (top), in the original 128-cell layout.
const HILLS := Vector2(36, 34)

const GRASS := Color("7fae5c")
const FOREST := Color("4f8a45")
const HILL := Color("9b8a63")

## World position of local cell (0, 0): right next to the city map.
var origin := Vector2.ZERO
var elevation := PackedByteArray()
## RGBA per cell: land colour, alpha 0 = rocky shore.
var colors := PackedByteArray()
## World x where the bridge reaches the fog island (west shore of its row).
var bridge_land_x := -1.0

var _cfg: CityConfig
var _height := PackedFloat32Array()
var _noise := FastNoiseLite.new()


func _init(cfg: CityConfig, data: CityData) -> void:
	_cfg = cfg
	# East of the bridge: the island starts about 22 cells beyond the end of the highway.
	origin = Vector2(data.bridge.x + 12, data.bridge.y - SIZE / 2) if data.bridge.x >= 0 \
			else Vector2(data.size - 32, 32)
	_noise.seed = cfg.seed + 9001
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 4.0 / float(SIZE)


func shape(bridge_row: int) -> void:
	_build_elevation()
	_paint()
	if bridge_row >= 0 and bridge_row < SIZE:
		for x in SIZE:
			if _height[bridge_row * SIZE + x] > 0.0:
				bridge_land_x = origin.x + x
				break
	_height = PackedFloat32Array()


## Same ellipse as Chat City, a little more to the west of its square.
func _build_elevation() -> void:
	_height.resize(SIZE * SIZE)
	elevation.resize(SIZE * SIZE)
	var center := Vector2(SIZE * 0.44, SIZE * 0.5)
	var radius := Vector2(SIZE, SIZE) * 0.5 * _cfg.island_radius
	for y in SIZE:
		for x in SIZE:
			var n := (Vector2(x, y) + Vector2(0.5, 0.5) - center) / radius
			var e := 1.0 - n.length_squared() + _noise.get_noise_2d(x, y) * _cfg.coast_noise
			var edge := minf(minf(x, y), minf(SIZE - 1 - x, SIZE - 1 - y))
			if edge < 6:
				e = minf(e, -0.3 + edge * 0.03)
			# The west border touches the city map: keep it sea.
			if x < 8:
				e = minf(e, -0.3)
			_height[y * SIZE + x] = e
			elevation[y * SIZE + x] = clampi(128 + int(e * 255.0), 0, 255)


func _paint() -> void:
	colors.resize(SIZE * SIZE * 4)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			# Nothing stands on the island and it is all grass: no pads, hills, forest or rocky shore.
			colors[i * 4] = GRASS.r8
			colors[i * 4 + 1] = GRASS.g8
			colors[i * 4 + 2] = GRASS.b8
			colors[i * 4 + 3] = 255


## Centre of the island in world coordinates (x, z).
func center() -> Vector2:
	return origin + Vector2(SIZE * 0.44, SIZE * 0.5)
