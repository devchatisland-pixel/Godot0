class_name DistrictPlanner
extends RefCounted
## The layout of Chat City. Districts are placed by hand in "island units"
## (x: -1 west .. +1 east, y: -1 north .. +1 south, 1 = island radius) so the
## city always reads like a designed map:
##   a single skyscraper downtown, a little Las Vegas on the west coast,
##   a big central park, a desert in the north-east, a civic center,
##   residential neighbourhoods in the south and east, a colourful town
##   quarter by the south coast and a sports corner.
## On screen north-west is up, so downtown sits at the top, the desert on the
## right and the suburbs at the bottom.

const Zone := CityTypes.Zone

## Voronoi anchors: every block takes the zone of its closest anchor
## (distance divided by weight, so heavier anchors cover more ground).
const ANCHORS := [
	{"name": "downtown", "zone": Zone.DOWNTOWN, "at": Vector2(-0.44, -0.4), "weight": 0.72},
	{"name": "uptown", "zone": Zone.APARTMENT, "at": Vector2(-0.12, -0.72), "weight": 0.65},
	{"name": "vegas", "zone": Zone.ENTERTAINMENT, "at": Vector2(-0.8, 0.0), "weight": 0.85},
	{"name": "shops", "zone": Zone.COMMERCIAL, "at": Vector2(-0.32, 0.14), "weight": 0.7},
	{"name": "civic", "zone": Zone.COMMERCIAL, "at": Vector2(0.14, 0.22), "weight": 0.9},
	{"name": "sports", "zone": Zone.APARTMENT, "at": Vector2(-0.45, 0.55), "weight": 0.9},
	{"name": "suburb_ne", "zone": Zone.SUBURBAN, "at": Vector2(0.55, -0.22), "weight": 1.0},
	{"name": "suburb_e", "zone": Zone.SUBURBAN, "at": Vector2(0.7, 0.3), "weight": 1.1},
	{"name": "suburb_s", "zone": Zone.SUBURBAN, "at": Vector2(0.4, 0.68), "weight": 1.0},
	{"name": "quarter", "zone": Zone.QUARTER, "at": Vector2(-0.02, 0.72), "weight": 0.8},
]
## Areas without streets inside, surrounded by roads (island units).
const PARK_AREA := Rect2(-0.24, -0.38, 0.42, 0.38)
const DESERT_AREA := Rect2(0.26, -1.6, 1.6, 1.2)

## Big public buildings get a whole plot with a ring road, like the park:
## centre in island units, size in cells (interior, roads not included).
const PLOTS := [
	{"kind": CityTypes.Kind.STADIUM, "at": Vector2(-0.45, 0.58), "size": Vector2i(11, 9)},
	{"kind": CityTypes.Kind.MEGA_MALL, "at": Vector2(-0.6, 0.12), "size": Vector2i(15, 7)},
	{"kind": CityTypes.Kind.POLICE_HQ, "at": Vector2(-0.1, 0.32), "size": Vector2i(6, 6)},
	{"kind": CityTypes.Kind.CITY_HALL, "at": Vector2(0.14, 0.24), "size": Vector2i(8, 8)},
	{"kind": CityTypes.Kind.MUSEUM, "at": Vector2(0.34, -0.2), "size": Vector2i(8, 6)},
	{"kind": CityTypes.Kind.MAIN_SCHOOL, "at": Vector2(0.62, 0.08), "size": Vector2i(9, 7)},
	{"kind": CityTypes.Kind.CEMETERY, "at": Vector2(0.48, 0.52), "size": Vector2i(8, 6)},
	{"kind": CityTypes.Kind.FERRIS_WHEEL, "at": Vector2(-0.05, 0.84), "size": Vector2i(6, 6)},
]

## Places some services should be close to, besides the district anchors.
const HINTS := {
	"church": Vector2(0.5, -0.02),       # east suburbs, away from the desert
	"beach_quarter": Vector2(-0.05, 1.0), # colourful quarter by the south beach
	"hotels": Vector2(-0.3, 0.05),       # shopping streets, not Las Vegas
	"hotels_b": Vector2(0.3, 0.4),       # avenue south of the civic center
	"post": Vector2(0.0, 0.3),           # next to the civic center
}

## Block interior limits (short side, long side) per zone.
const BLOCK_LIMITS := {
	Zone.DOWNTOWN: Vector2i(4, 8),
	Zone.COMMERCIAL: Vector2i(4, 9),
	Zone.ENTERTAINMENT: Vector2i(4, 8),
	Zone.APARTMENT: Vector2i(4, 10),
	Zone.SUBURBAN: Vector2i(4, 12),
	Zone.QUARTER: Vector2i(4, 9),
}

var _cfg: CityConfig
var _data: CityData
var _island: IslandShaper
var _noise := FastNoiseLite.new()
var _center := Vector2.ZERO
var _radius := Vector2.ONE

## Anchor name -> position in cells.
var anchors := {}
## Interiors (cells) of the park and of the desert.
var park := Rect2i()
var desert := Rect2i()
## [kind, Rect2i] of every big-building plot.
var plots: Array = []


func _init(cfg: CityConfig, data: CityData, island: IslandShaper) -> void:
	_cfg = cfg
	_data = data
	_island = island
	_noise.seed = cfg.seed + 501
	_noise.frequency = 8.0 / float(data.size)
	_center = Vector2(data.size, data.size) * 0.5
	_radius = Vector2(cfg.core_size, cfg.core_size) * 0.5 * cfg.island_radius


func plan() -> void:
	for a in ANCHORS:
		anchors[a["name"]] = to_cells(a["at"])
	for h in HINTS:
		anchors[h] = to_cells(HINTS[h])
	for p in PLOTS:
		var size: Vector2i = p["size"]
		var c := Vector2i(to_cells(p["at"]).round())
		plots.append([p["kind"], Rect2i(c - size / 2, size)])
	park = _rect_cells(PARK_AREA)
	desert = _rect_cells(DESERT_AREA).intersection(Rect2i(0, 0, _data.size, _data.size))
	_data.centers = [_center]
	_data.center_weights = PackedFloat32Array([1.0])


func to_cells(p: Vector2) -> Vector2:
	return _center + p * _radius


func _rect_cells(r: Rect2) -> Rect2i:
	var a := to_cells(r.position)
	var b := to_cells(r.end)
	return Rect2i(Vector2i(a.round()), Vector2i((b - a).round()))


## Areas the road planner keeps free of streets.
func exclusions() -> Array[Rect2i]:
	var out: Array[Rect2i] = [park, desert]
	for p in plots:
		out.append(p[1])
	return out


# --- Districts -------------------------------------------------------------------------
func district_at(x: float, y: float) -> Dictionary:
	# Jitter the sample point so borders between districts are not straight.
	var p := Vector2(x, y) + Vector2(_noise.get_noise_2d(x, y), _noise.get_noise_2d(y + 99.0, x)) * 5.0
	var best: Dictionary = ANCHORS[0]
	var best_d := INF
	for a in ANCHORS:
		var d: float = p.distance_to(anchors[a["name"]]) / float(a["weight"])
		if d < best_d:
			best_d = d
			best = a
	return best


func zone_at(x: float, y: float) -> int:
	return district_at(x, y)["zone"]


func block_limits(x: float, y: float) -> Vector2i:
	return BLOCK_LIMITS.get(zone_at(x, y), Vector2i(5, 10))


## 0..1, how central a point is in downtown (towers grow towards the middle).
func intensity(x: float, y: float) -> float:
	var d := Vector2(x, y).distance_to(anchors["downtown"])
	return clampf(1.0 - d / (_radius.x * 0.35), 0.0, 1.0)


# --- Zoning --------------------------------------------------------------------------------
func assign_zones(blocks: Array[Rect2i]) -> PackedByteArray:
	var zones := PackedByteArray()
	zones.resize(blocks.size())
	for i in blocks.size():
		var c := Vector2(blocks[i].get_center())
		zones[i] = zone_at(c.x, c.y)
	return zones


## Paints zones on the cell grid: blocks, park, desert, islets; the rest of the
## land becomes nature (beaches, coastal meadows).
func paint_zones(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	var size := _data.size
	for y in size:
		for x in size:
			var i := y * size + x
			var land := _data.terrain[i] >= CityTypes.Terrain.BEACH
			var z := Zone.NONE
			if land and _data.road[i] == 0:
				z = Zone.NATURE if _island.is_mainland(x, y) else Zone.ISLET
				if z == Zone.ISLET and _island.is_prison_island(x, y):
					z = Zone.PRISON
				if _island.is_mainland(x, y):
					if park.has_point(Vector2i(x, y)):
						z = Zone.PARK
					elif desert.has_point(Vector2i(x, y)):
						z = Zone.DESERT
					elif _in_plot(x, y):
						z = Zone.CIVIC
			_data.zone[i] = z
	for b in blocks.size():
		var r := blocks[b]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := y * size + x
				if _data.terrain[i] == CityTypes.Terrain.LAND and _data.road[i] == 0:
					_data.zone[i] = zones[b]


func _in_plot(x: int, y: int) -> bool:
	for p in plots:
		if (p[1] as Rect2i).has_point(Vector2i(x, y)):
			return true
	return false
