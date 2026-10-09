class_name FogIslandShaper
extends RefCounted
## The second island, east of Chat City, hidden in the fog until "season 2".
## Only what shows through the fog is generated: the ground colours, two
## clusters of towers, a few houses and many palm trees. It is not part of
## the cell grid of the city (no roads or lots), so it costs almost nothing.
## Runs on the generation thread; the FogIsland node draws it.

const SIZE := 128
## Hills (top), two hidden downtowns and the palm coast, in local cells.
const CLUSTERS := [
	{"at": Vector2(72, 38), "radius": 15.0, "towers": true},
	{"at": Vector2(74, 92), "radius": 17.0, "towers": true},
	{"at": Vector2(40, 70), "radius": 12.0, "towers": false},
]
const HILLS := Vector2(36, 34)

const GRASS := Color("7fae5c")
const FOREST := Color("4f8a45")
const HILL := Color("9b8a63")
const CITY := Color("8d8a96")
const STREET := Color("5c6070")

## World position of local cell (0, 0): right next to the city map.
var origin := Vector2.ZERO
var elevation := PackedByteArray()
## RGBA per cell: land colour, alpha 0 = rocky shore.
var colors := PackedByteArray()
## Buildings: [Vector2 world position, kind (0 tower, 1 mid-rise, 2 house), seed].
var buildings: Array = []
## Palm trees and trees: [Vector2 world position, palm?, seed].
var trees: Array = []
## World x where the bridge reaches the fog island (west shore of its row).
var bridge_land_x := -1.0

var _cfg: CityConfig
var _height := PackedFloat32Array()
var _noise := FastNoiseLite.new()


func _init(cfg: CityConfig, data: CityData) -> void:
	_cfg = cfg
	origin = Vector2(data.size, 0)
	_noise.seed = cfg.seed + 9001
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 4.0 / float(SIZE)


func shape(bridge_row: int) -> void:
	_build_elevation()
	_paint()
	_place_buildings()
	_place_trees()
	if bridge_row >= 0:
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
			var p := Vector2(x, y)
			var f := clampf(_noise.get_noise_2d(x * 3.0, y * 3.0) * 0.8 + 0.5, 0.0, 1.0)
			var c := GRASS.lerp(FOREST, f)
			var hill := 1.0 - p.distance_to(HILLS) / 26.0
			if hill > 0.0:
				c = c.lerp(HILL, clampf(hill * 1.6, 0.0, 0.85))
			for cl in CLUSTERS:
				var d: float = p.distance_to(cl["at"]) / float(cl["radius"])
				if d < 1.0:
					c = STREET if (x % 5 == 0 or y % 5 == 0) else CITY
			colors[i * 4] = c.r8
			colors[i * 4 + 1] = c.g8
			colors[i * 4 + 2] = c.b8
			var rocky := _noise.get_noise_2d(x * 2.0 + 300.0, y * 2.0) > 0.2
			colors[i * 4 + 3] = 0 if rocky else 255


## Lots of the hidden downtowns: towers in the middle, mid-rise around.
func _place_buildings() -> void:
	for c in CLUSTERS.size():
		var cl: Dictionary = CLUSTERS[c]
		var at: Vector2 = cl["at"]
		var r: float = cl["radius"]
		for y in range(int(at.y - r), int(at.y + r) + 1, 5):
			for x in range(int(at.x - r), int(at.x + r) + 1, 5):
				for sub: Vector2 in [Vector2(1.5, 1.5), Vector2(3.5, 1.5), Vector2(1.5, 3.5), Vector2(3.5, 3.5)]:
					var p := Vector2(x, y) + sub
					var d := p.distance_to(at) / r
					var h := CityTypes.hash2(int(p.x * 2.0), int(p.y * 2.0), c)
					if d > 0.95 or not _is_land(p) or float(h & 255) / 255.0 < d * 0.5:
						continue
					var kind := 2
					if cl["towers"]:
						kind = 0 if d < 0.55 else 1
					elif d < 0.4:
						kind = 1
					buildings.append([origin + p, kind, h])


func _place_trees() -> void:
	for y in range(2, SIZE - 2, 2):
		for x in range(2, SIZE - 2, 2):
			var h := CityTypes.hash2(x, y, 4242)
			var p := Vector2(x, y) + Vector2(float(h & 15), float((h >> 4) & 15)) / 15.0 * 1.6
			if not _is_land(p) or _in_cluster(p) or (h >> 8) & 3 == 0:
				continue
			var near_coast := _height[int(p.y) * SIZE + int(p.x)] < 0.18
			trees.append([origin + p, near_coast or (h >> 10) & 1 == 0, h])


func _is_land(p: Vector2) -> bool:
	var x := int(p.x)
	var y := int(p.y)
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE and _height[y * SIZE + x] > _cfg.beach_width


func _in_cluster(p: Vector2) -> bool:
	for cl in CLUSTERS:
		if p.distance_to(cl["at"]) < float(cl["radius"]):
			return true
	return false


## Centre of the island in world coordinates (x, z).
func center() -> Vector2:
	return origin + Vector2(SIZE * 0.44, SIZE * 0.5)
