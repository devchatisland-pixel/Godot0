class_name FogBaseSites
extends RefCounted
## The military base of the fog island: where everything stands, in local cells of the island
## (FogIslandShaper; x east, y south). Three parts, joined by roads from the bridge:
##   - the air base in the north: a long runway, an apron with a row of F-14, the staff
##     building, a radar, air defence at both ends and the helipad with its helicopter;
##   - the camp in the middle: rows of tents, the medical tents, barracks, and the vehicle
##     park (each kind of vehicle in its own block, side by side);
##   - the nuclear plant in the south-east, which the army is there to protect: air defence
##     and armoured cars all round it.
## Pure data: FogIslandShaper paints PADS on the ground, FogBase draws ROADS and plan().

const Cat := ModelCatalog.Cat

const CONCRETE := Color("a8a69d")
const TARMAC := Color("77787c")
const DIRT := Color("9a8c68")

## Ground painted under the base: [rect in cells, colour].
const PADS := [
	[Rect2(40, 50, 92, 9), CONCRETE],     # runway strip
	[Rect2(56, 59, 62, 16), TARMAC],      # apron, staff building
	[Rect2(44, 59, 9, 9), CONCRETE],      # helipad
	[Rect2(32, 81, 62, 12), DIRT],        # tents
	[Rect2(32, 99, 46, 11), TARMAC],      # vehicle park
	[Rect2(100, 102, 30, 26), CONCRETE],  # nuclear plant
]

## Roads drawn with the highway texture: [from, to (centre line, along x or y), width].
const ROADS := [
	[Vector2(42, 54.5), Vector2(130, 54.5), 4.0],   # runway
	[Vector2(62, 56.5), Vector2(62, 61), 2.0],      # taxiways
	[Vector2(110, 56.5), Vector2(110, 61), 2.0],
	[Vector2(15, 96), Vector2(97.5, 96), 3.0],      # from the bridge through the camp
	[Vector2(96, 75), Vector2(96, 110), 3.0],       # air base - plant
	[Vector2(96, 110), Vector2(100, 110), 3.0],
]

const HELIPAD := Vector2(48.5, 63.5)
const HELIPAD_SIZE := 5.0
const HELICOPTER := "p54_46_helicopter_military"

## Drawn size of the models (they are curated at the size of a building of the city).
const JET_SCALE := 1.35
const HALL_SCALE := 1.3

## Vehicle blocks of the park: [category, first vehicle, columns, rows, gap across, gap along].
const PARK := [
	[Cat.TANK_T55, Vector2(35, 101.5), 6, 2, 1.25, 2.4],
	[Cat.APC_BMP1, Vector2(45, 101.5), 6, 2, 1.15, 2.1],
	[Cat.APC_BRDM, Vector2(54.5, 101.5), 5, 2, 1.05, 1.9],
	[Cat.APC_EE11, Vector2(62.5, 101.5), 6, 1, 1.05, 1.9],
	[Cat.TANK_T55, Vector2(35, 107.5), 4, 1, 1.25, 2.4],
	[Cat.APC_BMP1, Vector2(45, 107.5), 4, 1, 1.15, 2.1],
]


## Every model of the base: {"cat" or "veh", "at": Vector2 (local cells), "dir": Vector2 the
## front looks to, "scale"}.
static func plan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var north := Vector2(0, -1)
	var south := Vector2(0, 1)
	var east := Vector2(1, 0)
	var west := Vector2(-1, 0)
	# --- Air base ---
	for i in 10:
		_add(out, Cat.JET_F14, Vector2(66.0 + i * 4.4, 63.5), north, JET_SCALE)
	_add(out, Cat.JET_F14, Vector2(47, 54.5), east, JET_SCALE) # lined up on the runway
	_add(out, Cat.JET_F14, Vector2(52, 54.5), east, JET_SCALE)
	_add(out, Cat.BASE_HALL, Vector2(84, 70.5), north, HALL_SCALE)
	_add(out, Cat.RADAR, Vector2(114, 71), north, 1.3)
	_add(out, Cat.SAM_NASAMS, Vector2(38, 60), west)
	_add(out, Cat.SAM_NASAMS, Vector2(134, 60), east)
	for i in 3:
		_add(out, Cat.APC_EE11, Vector2(104.0 + i * 1.1, 71.5), north)
	out.append({"veh": HELICOPTER, "at": HELIPAD, "dir": east, "scale": 1.0})
	# --- Camp: tents north of the road, barracks, medical tents ---
	for row in 3:
		for i in 6:
			_add(out, Cat.TENT_JUNGLE, Vector2(36.0 + i * 3.1, 83.5 + row * 3.0), south)
	for i in 4:
		_add(out, Cat.TENT_MEDICAL, Vector2(57.0 + i * 2.2, 84.5), south)
	_add(out, Cat.BASE_HALL, Vector2(72, 86.5), south, HALL_SCALE)
	_add(out, Cat.BASE_HALL, Vector2(82, 86.5), south, HALL_SCALE)
	_add(out, Cat.RADAR, Vector2(90, 84), south)
	_add(out, Cat.SAM_NASAMS, Vector2(90, 89), north)
	# Guards at the gate, where the road leaves the bridge.
	for s in [-1.0, 1.0]:
		_add(out, Cat.TANK_T55, Vector2(24, 96.0 + s * 2.6), west)
		_add(out, Cat.APC_BRDM, Vector2(27, 96.0 + s * 2.6), west)
	# --- Vehicle park: one block per kind, all the noses to the road ---
	for g in PARK:
		for r in int(g[3]):
			for c in int(g[2]):
				_add(out, g[0], (g[1] as Vector2) + Vector2(c * float(g[4]), r * float(g[5])), north)
	# --- Nuclear plant ---
	_add(out, Cat.NUCLEAR2, Vector2(116, 114), east)
	_add(out, Cat.BASE_HALL, Vector2(108, 123.5), north, 0.9)
	for c in [Vector2(101.5, 104), Vector2(128.5, 104), Vector2(101.5, 126), Vector2(128.5, 126)]:
		_add(out, Cat.SAM_NASAMS, c, Vector2(signf(c.x - 115.0), 0))
	_add(out, Cat.RADAR, Vector2(124, 124.5), south)
	for i in 4:
		_add(out, Cat.APC_EE11, Vector2(104.0 + i * 1.1, 105), north)
		_add(out, Cat.APC_BRDM, Vector2(118.0 + i * 1.1, 123.5), south)
	for i in 3:
		_add(out, Cat.TANK_T55, Vector2(120.0 + i * 1.3, 105), north)
	return out


static func _add(out: Array[Dictionary], cat: int, at: Vector2, dir: Vector2, scale: float = 1.0) -> void:
	out.append({"cat": cat, "at": at, "dir": dir, "scale": scale})


## Colour of the base ground at local cell `p`, or null outside the pads.
static func pad_color(p: Vector2) -> Variant:
	for pad in PADS:
		if (pad[0] as Rect2).has_point(p):
			return pad[1]
	return null
