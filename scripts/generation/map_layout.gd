class_name MapLayout
extends RefCounted
## Where everything is on the big map: the islands, the round districts and the single
## places, in one file. The planners ask for them by name and hold no coordinates.
## All values are in cells of the map at scale 1 (the 272-cell map); `scale` grows the whole
## layout from the top-left corner, so the structure between the zones stays the same.
## The core city is not here: DistrictPlanner already lays it out in island units.
##
##   blob(name)    a round area: {"at": centre, "r": radii, "turn": radians (prison only)}
##   point(name)   a single cell (where a search starts, where a prop stands)
##   points(name)  a list of cells
##   cells(name)   a length or a column / row number, in cells

## Set once by CityGenerator before anything is planned.
static var scale := 1.0

## Round areas. "fixed": the size does not grow with the scale, only the place moves.
const BLOBS := {
	# Islands.
	"main": {"at": Vector2(141, 133), "r": Vector2(80, 94)},
	# The urban island (third island) west of the main one, joined by the metal bridge.
	"urban": {"at": Vector2(30, 138), "r": Vector2(23, 52)},
	# A lobe of land at its north end, wide enough for the nuclear plant and its cooling towers.
	"urban_north": {"at": Vector2(34, 96), "r": Vector2(21, 13)},
	# The tiny islet of the BT tower, in the sea north of the urban island.
	"tower_islet": {"at": Vector2(24, 64), "r": Vector2(10, 6.5)},
	# The development island, alone in the empty south-west corner of the sea, far from the
	# fog island: one of each shop in a row (see shops/CATALOG.md). Flat, no trees.
	"dev_island": {"at": Vector2(42, 228), "r": Vector2(36, 12), "fixed": true},
	# The prison island: centre, radii (long and short side) and turn in radians.
	# Far out in the north-west, well away from the coast of the main island.
	"prison": {"at": Vector2(34, 38), "r": Vector2(15.0, 10.0), "turn": 0.45},
	# Round districts of the main island.
	"desert": {"at": Vector2(78, 128), "r": Vector2(22, 36)},
	"industrial": {"at": Vector2(84, 182), "r": Vector2(22, 19)},
	"farm": {"at": Vector2(202, 190), "r": Vector2(24, 32)},
	"forest": {"at": Vector2(178, 62), "r": Vector2(34, 17)},
	"poor": {"at": Vector2(122, 76), "r": Vector2(18, 10)},
	"quarter": {"at": Vector2(138, 211), "r": Vector2(36, 17)},
}

## Palm islets: centre and radius in cells.
const PALM_ISLETS := [
	{"at": Vector2(70, 252), "r": 4.5}, {"at": Vector2(150, 259), "r": 5.0},
	{"at": Vector2(236, 246), "r": 4.0}, {"at": Vector2(250, 92), "r": 3.5},
]

const POINTS := {
	# The smallest palm islet: the pirate grave stands on it.
	"pirate_islet": Vector2i(250, 92),
	# Where the search for the sea of the pirate ship starts.
	"pirate_sea": Vector2i(255, 208),
	# Where the ferris wheel stands (6x6 plot, at the south beach).
	"ferris": Vector2i(146, 221),
	# Where the search for the plot of the nuclear plant starts.
	"plant": Vector2i(30, 96),
	# Where the search for the forest fire truck starts.
	"fire_truck": Vector2i(172, 70),
	# The flying saucer: far from the city and from the secret base, in the south of the desert.
	"ufo": Vector2i(64, 152),
	# The balloon (cell of its centre; it floats).
	"balloon": Vector2i(206, 44),
	# Where the cargo ship looks for sea: west of the industrial port (the quay and cranes).
	"cargo_ship": Vector2i(66, 183),
	# A second oil tanker north-west of the nuclear plant.
	"tanker": Vector2i(40, 76),
	# Sea north of the main island, where the wooden boat lies.
	"north_sea": Vector2i(150, 30),
	# The sea beside the graveyard islet.
	"graveyard_sea": Vector2i(139, 252),
}

const POINT_LISTS := {
	# Submarines all round the seas, far from each other.
	"submarines_a": [Vector2i(100, 16), Vector2i(16, 215), Vector2i(190, 262), Vector2i(250, 16)],
	"submarines_b": [Vector2i(216, 28), Vector2i(120, 242)],
	# Pirate ships, always far from any beach.
	"pirate_ships_a": [Vector2i(60, 252), Vector2i(130, 266), Vector2i(262, 70), Vector2i(170, 12)],
	"pirate_ships_b": [Vector2i(80, 20), Vector2i(200, 250), Vector2i(24, 250)],
}

const CELLS := {
	# Columns of the map the urban island may use (west of the metal bridge).
	"urban_columns": 60,
	# Rows above this (north end of the urban island) get no streets and no lots.
	"nuclear_end": 111,
	# Column where the search for the airport plot starts.
	"airport_column": 30,
	# Rows tried for the west highway (from, to).
	"west_highway_from": 112,
	"west_highway_to": 156,
	# The yards round the nuclear plant that get the fence: rows (from, to) and columns below.
	"plant_yard_from": 84,
	"plant_yard_to": 108,
	# South end of the urban island checked by the tests.
	"urban_south_end": 215,
}

static var _blobs := {}


static func set_scale(value: float) -> void:
	scale = value
	_blobs.clear()


## The round area `name`, scaled. The returned dictionary is shared: do not change it.
static func blob(name: String) -> Dictionary:
	if _blobs.has(name):
		return _blobs[name]
	var b: Dictionary = BLOBS[name].duplicate()
	b["at"] = (b["at"] as Vector2) * scale
	if not b.get("fixed", false):
		b["r"] = (b["r"] as Vector2) * scale
	_blobs[name] = b
	return b


static func palm_islets() -> Array:
	if _blobs.has("#palm"):
		return _blobs["#palm"]
	var out := []
	for it: Dictionary in PALM_ISLETS:
		out.append({"at": (it["at"] as Vector2) * scale, "r": float(it["r"]) * scale})
	_blobs["#palm"] = out
	return out


static func point(name: String) -> Vector2i:
	return _scaled(POINTS[name])


static func points(name: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Vector2i in POINT_LISTS[name]:
		out.append(_scaled(p))
	return out


static func cells(name: String) -> int:
	return roundi(float(CELLS[name]) * scale)


static func _scaled(p: Vector2i) -> Vector2i:
	return Vector2i(roundi(p.x * scale), roundi(p.y * scale))
