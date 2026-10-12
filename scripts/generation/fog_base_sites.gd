class_name FogBaseSites
extends RefCounted
## The military base of the fog island: where everything stands, in local cells of the island
## (FogIslandShaper; x east, y south). Three parts, joined by roads from the bridge:
##   - the air base in the north: a long runway, an apron with a row of F-14, the staff
##     building, a radar, air defence at both ends, a fire truck and a tow truck, and the
##     helipad with its helicopter;
##   - the camp in the middle: rows of army and medical tents (mixed), jeeps beside them,
##     barracks, and the vehicle park (each kind of vehicle in its own block, side by side);
##   - the nuclear plant in the south-east, which the army is there to protect: a barracks
##     and armoured cars round it;
##   - jeeps round the base and Humvees out on its roads.
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
const HELIPAD_SIZE := 6.0
const HELICOPTER := "p54_46_helicopter_military"

## Drawn size of the models (they are curated at the size of a building of the city).
const JET_SCALE := 1.35
const HALL_SCALE := 1.3

## Vehicle blocks of the park: [category, first vehicle, columns, rows, gap across, gap along].
## Half of the army vehicles of the island were taken away: each block lost half its columns.
const PARK := [
	[Cat.TANK_T55, Vector2(35, 101.5), 3, 2, 1.25, 2.4],
	[Cat.APC_BMP1, Vector2(45, 101.5), 3, 2, 1.15, 2.1],
	[Cat.APC_BRDM, Vector2(54.5, 101.5), 2, 2, 1.05, 1.9],
	[Cat.APC_EE11, Vector2(62.5, 101.5), 3, 1, 1.05, 1.9],
	[Cat.TANK_T55, Vector2(35, 107.5), 2, 1, 1.25, 2.4],
	[Cat.APC_BMP1, Vector2(45, 107.5), 2, 1, 1.15, 2.1],
]

## The camp: TENT_ROWS rows of TENT_COLUMNS tents; the slots [row, column] of MEDICAL_SLOTS
## hold a medical tent, the others an army tent, so the two kinds are mixed.
const TENT_ROWS := 3
const TENT_COLUMNS := 8
const TENT_FIRST := Vector2(35.5, 83.5)
const TENT_STEP := Vector2(3.3, 3.0)
const MEDICAL_SLOTS := [[0, 2], [0, 6], [1, 0], [1, 4], [2, 3], [2, 7]]

const JEEP := "jeep_willys"
const HUMVEE := "humvee_grey"
## Jeeps: [place, the way the nose looks]. Beside the tents, then round the base.
const JEEPS := [
	[Vector2(62.3, 83.2), Vector2(0, 1)], [Vector2(63.2, 83.2), Vector2(0, 1)],
	[Vector2(62.6, 89.8), Vector2(-1, 0)], [Vector2(33.6, 86.4), Vector2(0, -1)],
	[Vector2(33.6, 90.2), Vector2(1, 0)], [Vector2(47.0, 92.6), Vector2(1, 0)],
	[Vector2(89.5, 67.5), Vector2(0, -1)], [Vector2(53.5, 66.0), Vector2(-1, 0)],
	[Vector2(113.5, 121.5), Vector2(1, 0)], [Vector2(70.5, 104.5), Vector2(0, -1)],
]
## Grey Humvees: one where the bridge lands (the sand one stands at the other end of the
## bridge, VehicleSites), the others out on the roads of the base, not parked.
const HUMVEES := [
	[Vector2(19.5, 93.6), Vector2(-1, 0)],
	[Vector2(41.0, 96.7), Vector2(1, 0)], [Vector2(66.0, 95.3), Vector2(-1, 0)],
	[Vector2(88.0, 96.7), Vector2(1, 0)], [Vector2(95.3, 81.0), Vector2(0, 1)],
	[Vector2(96.7, 104.0), Vector2(0, -1)], [Vector2(75.0, 61.0), Vector2(1, 0)],
]
## On the apron of the air base, beside the taxiway.
const FIRE_TRUCK := "p54_33_fire_truck"
const TOW_TRUCK := "p54_08_tow_truck_yellow"


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
		_add(out, Cat.JET_F14, Vector2(66.0 + i * 4.4, 63.5), south, JET_SCALE)
	_add(out, Cat.JET_F14, Vector2(47, 54.5), west, JET_SCALE) # lined up on the runway
	_add(out, Cat.JET_F14, Vector2(52, 54.5), west, JET_SCALE)
	_add(out, Cat.BASE_HALL, Vector2(84, 70.5), north, HALL_SCALE)
	_add(out, Cat.RADAR, Vector2(114, 71), north, 1.3)
	_add(out, Cat.SAM_NASAMS, Vector2(38, 60), west)
	_add(out, Cat.SAM_NASAMS, Vector2(134, 60), east)
	_add(out, Cat.APC_EE11, Vector2(104.0, 71.5), north)
	_veh(out, FIRE_TRUCK, Vector2(108.0, 67.5), north)
	_veh(out, TOW_TRUCK, Vector2(112.0, 67.5), north)
	_veh(out, HELICOPTER, HELIPAD, east)
	# --- Camp: army and medical tents mixed north of the road, barracks ---
	for row in TENT_ROWS:
		for col in TENT_COLUMNS:
			var cat := Cat.TENT_MEDICAL if MEDICAL_SLOTS.has([row, col]) else Cat.TENT_JUNGLE
			_add(out, cat, TENT_FIRST + Vector2(col * TENT_STEP.x, row * TENT_STEP.y), south)
	_add(out, Cat.BASE_HALL, Vector2(72, 86.5), south, HALL_SCALE)
	_add(out, Cat.BASE_HALL, Vector2(82, 86.5), south, HALL_SCALE)
	_add(out, Cat.RADAR, Vector2(90, 84), south)
	_add(out, Cat.SAM_NASAMS, Vector2(90, 89), north)
	# Guards at the gate, where the road leaves the bridge: they look into the island.
	for s in [-1.0, 1.0]:
		_add(out, Cat.TANK_T55, Vector2(24, 96.0 + s * 2.6), east)
		_add(out, Cat.APC_BRDM, Vector2(27, 96.0 + s * 2.6), east)
	# --- Vehicle park: one block per kind, all the noses to the road ---
	for g in PARK:
		for r in int(g[3]):
			for c in int(g[2]):
				_add(out, g[0], (g[1] as Vector2) + Vector2(c * float(g[4]), r * float(g[5])), north)
	# --- Nuclear plant (no air defence round it any more) ---
	_add(out, Cat.NUCLEAR2, Vector2(116, 114), east)
	_add(out, Cat.BASE_HALL, Vector2(108, 123.5), north, HALL_SCALE)
	for i in 2:
		_add(out, Cat.APC_EE11, Vector2(104.0 + i * 1.1, 105), north)
		_add(out, Cat.APC_BRDM, Vector2(118.0 + i * 1.1, 123.5), south)
	_add(out, Cat.TANK_T55, Vector2(120.0, 105), north)
	# --- Jeeps and Humvees ---
	for j in JEEPS:
		_veh(out, JEEP, j[0], j[1])
	for h in HUMVEES:
		_veh(out, HUMVEE, h[0], h[1])
	return out


static func _add(out: Array[Dictionary], cat: int, at: Vector2, dir: Vector2, scale: float = 1.0) -> void:
	out.append({"cat": cat, "at": at, "dir": dir, "scale": scale})


## A vehicle of the catalog (res://vehicles).
static func _veh(out: Array[Dictionary], id: String, at: Vector2, dir: Vector2) -> void:
	out.append({"veh": id, "at": at, "dir": dir, "scale": VehicleSites.size_factor(id)})


## Colour of the base ground at local cell `p`, or null outside the pads.
static func pad_color(p: Vector2) -> Variant:
	for pad in PADS:
		if (pad[0] as Rect2).has_point(p):
			return pad[1]
	return null
