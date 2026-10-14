class_name FogBaseSites
extends RefCounted
## The fog island as an inhabited island, laid out like the main one (local cells of the
## island, FogIslandShaper; x east, y south). The avenue from the Golden Gate runs west to east
## through it:
##   - the blockade where the road leaves the bridge (barriers and cones across the three lanes like
##     the one of the east end of the bridge, the T-55, the BRDM and the Humvee that guarded the old
##     checkpoint behind it, noses to the bridge; the checkpoint model itself is the jail of the prison island);
##   - the capital (west): a business centre of towers on both sides of the avenue, suburbs of
##     houses north and south of it;
##   - Eastbay (east, north of the avenue): a small centre of offices and shops, houses behind;
##   - the industrial zone between the capital and the nuclear plant, the plant itself in a
##     fence;
##   - farmland north and south (crop fields, farm buildings, a tractor and a harvester);
##   - a very small army base in a fence north of the capital: its landing zone is the model of
##     the secret base of the main island, drawn at the same size, with a helipad, a few tents,
##     a barracks and a few armoured vehicles.
## The five models of the fog_city pack (offices, night tower, house, block storeys) are used
## for every building of the towns, the industry and the farms, and for no other place of the map.
## Pure data: FogIslandShaper paints PADS on the ground, FogBase draws ROADS, FENCES and plan().

const Cat := ModelCatalog.Cat

const CONCRETE := Color("a8a69d")
const TARMAC := Color("77787c")
const DIRT := Color("9a8c68")
const PAVED := Color("9c9ea3")
const SUBURB := Color("8fb565")
const INDUSTRY := Color("9a978f")
const FARM := Color("a59a62")

## Ground painted under the island's places: [rect in cells, colour] (the first match wins).
const PADS := [
	[Rect2(16.0, 93.2, 12.0, 6.6), CONCRETE],  # blockade (BLOCKADE_AT)
	[Rect2(49.5, 52.5, 20, 16.5), CONCRETE],   # army base (inside its fence)
	[Rect2(100, 102, 30, 26), CONCRETE],       # nuclear plant
	[Rect2(39, 85, 33, 22), PAVED],            # capital: business centre
	[Rect2(103, 83, 32, 13), PAVED],           # Eastbay: centre
	[Rect2(72, 98, 27, 29), INDUSTRY],         # industrial zone
	[Rect2(39, 74, 33, 11), SUBURB],           # capital: suburbs
	[Rect2(39, 107, 33, 20), SUBURB],
	[Rect2(103, 65, 32, 18), SUBURB],          # Eastbay: houses
	[Rect2(29, 74, 11, 53), SUBURB],           # capital: west side
	[Rect2(135, 83, 10, 13), PAVED],           # Eastbay: east end
	[Rect2(135, 65, 10, 18), SUBURB],
	[Rect2(99, 129, 32, 13), SUBURB],          # houses south of the plant
	[Rect2(75, 47, 35, 24), FARM],             # farmland north
	[Rect2(109, 50, 26, 15), FARM],
	[Rect2(57, 128, 43, 15), FARM],            # farmland south
]

## Roads drawn with the highway texture: [from, to (centre line, along x or y), width].
const ROADS := [
	# The avenue is centred on the deck of the bridge: row 96 of the island is the bridge row of
	# the city, whose middle is half a cell further south.
	[Vector2(15, 96.5), Vector2(150, 96.5), 3.0],   # from the bridge across the island
	# Capital: streets north-south (the one at x 60 goes on to the gate of the base) and east-west.
	[Vector2(40, 76), Vector2(40, 126), 2.0], [Vector2(50, 76), Vector2(50, 126), 2.0],
	[Vector2(60, 70), Vector2(60, 126), 2.0], [Vector2(70, 76), Vector2(70, 126), 2.0],
	[Vector2(30, 76), Vector2(70, 76), 2.0], [Vector2(30, 86), Vector2(70, 86), 2.0],
	[Vector2(30, 106), Vector2(70, 106), 2.0], [Vector2(30, 116), Vector2(70, 116), 2.0],
	[Vector2(30, 126), Vector2(98, 126), 2.0],      # ... and on along the south farmland
	[Vector2(30, 76), Vector2(30, 86), 2.0], [Vector2(30, 106), Vector2(30, 126), 2.0],
	[Vector2(78, 126), Vector2(78, 142), 2.0],
	# Industrial zone and the gate of the plant.
	[Vector2(88, 96), Vector2(88, 130), 2.0], [Vector2(70, 115), Vector2(100, 115), 2.0],
	# Eastbay.
	[Vector2(104, 66), Vector2(104, 96), 2.0], [Vector2(114, 66), Vector2(114, 96), 2.0],
	[Vector2(124, 66), Vector2(124, 96), 2.0], [Vector2(134, 66), Vector2(134, 96), 2.0],
	[Vector2(144, 66), Vector2(144, 96), 2.0],
	[Vector2(104, 66), Vector2(144, 66), 2.0], [Vector2(104, 76), Vector2(144, 76), 2.0],
	[Vector2(104, 86), Vector2(144, 86), 2.0],
	# Houses south of the plant.
	[Vector2(88, 130), Vector2(130, 130), 2.0], [Vector2(110, 130), Vector2(110, 141), 2.0],
	[Vector2(120, 130), Vector2(120, 141), 2.0],
	# Farmland north: from the road of the base to Eastbay, a lane between the fields.
	[Vector2(60, 72), Vector2(104, 72), 2.0], [Vector2(92, 48), Vector2(92, 72), 2.0],
]

## Wire fences: [rect in cells, side of the gate (0 N, 1 E, 2 S, 3 W), height].
const FENCES := [
	[Rect2(49.5, 52.5, 20, 16.5), 2, 0.45],  # army base, gate on the road of the capital
	[Rect2(100.5, 102.5, 29, 25), 3, 0.5],   # nuclear plant, gate on the road of the industry
]

## The army base: the landing zone (the model of the secret base, at its size on the main island).
const LANDING_ZONE := Vector2(55.5, 58)
const HELIPAD := Vector2(64.5, 56.5)
const HELIPAD_SIZE := 3.5
const HELICOPTER := "p54_46_helicopter_military"

const JEEP := "jeep_willys"
const HUMVEE := "humvee_grey"
## The blockade at the west end of the avenue: the column of its barriers, the three lanes (rows
## of their middles) and how far behind it (cells towards the island) the vehicles stand.
const BLOCKADE_AT := Vector2(19, 96.5)
const BLOCKADE_LANES := [95.5, 96.5, 97.5]
const BARRIER_LEN := 1.05
const CONE_LEN := 0.15
## Vehicles behind the barriers: [category, cells behind the barriers, lane row offset]; their noses
## look to the bridge (west). The grey Humvee parks beside the road, before the barriers.
const BLOCKADE_PARK := [
	[Cat.TANK_T55, 2.4, -1.0], [Cat.TANK_T55, 2.4, 1.0],
	[Cat.APC_BRDM, 4.4, -1.0], [Cat.APC_BRDM, 4.4, 1.0],
]
const BLOCKADE_HUMVEE := Vector2(-1.6, 2.7)

## Towns: the business blocks (top-left cell, size) and the order of their buildings, the
## house blocks. A building entry: [category, footprint in cells, storeys (a stack of FOG_FLOOR)].
const CAPITAL_CENTRE := [Rect2(41, 87.5, 8, 6.5), Rect2(51, 87.5, 8, 6.5), Rect2(61, 87.5, 8, 6.5),
		Rect2(41, 98, 8, 6.5), Rect2(51, 98, 8, 6.5), Rect2(61, 98, 8, 6.5)]
const CAPITAL_TOWERS := [
	[Cat.FOG_NIGHT_TOWER, 3.4, 1], [Cat.FOG_MOD_TOWER, 3.6, 1, 1], [Cat.FOG_OFFICE_TOWER, 3.4, 1],
	[Cat.FOG_MOD_TOWER, 3.8, 1, 2], [Cat.FOG_FLOOR, 3.2, 6], [Cat.FOG_MOD_TOWER, 3.4, 1, 0],
	[Cat.FOG_NIGHT_TOWER, 3.4, 1], [Cat.FOG_MOD_TOWER, 3.6, 1, 1], [Cat.FOG_OFFICE, 4.0, 1],
	[Cat.FOG_MOD_TOWER, 3.8, 1, 2], [Cat.FOG_OFFICE_TOWER, 3.4, 1], [Cat.FOG_MOD_TOWER, 3.4, 1, 0],
]
const CAPITAL_HOMES := [Rect2(41, 77, 8, 8), Rect2(51, 77, 8, 8), Rect2(61, 77, 8, 8),
		Rect2(41, 107, 8, 8), Rect2(51, 107, 8, 8), Rect2(61, 107, 8, 8),
		Rect2(41, 117, 8, 8), Rect2(51, 117, 8, 8), Rect2(61, 117, 8, 8),
		Rect2(31, 77, 8, 8), Rect2(31, 107, 8, 8), Rect2(31, 117, 8, 8),
		Rect2(101, 131.5, 8, 8), Rect2(111, 131.5, 8, 8), Rect2(121, 131.5, 8, 8)]
const EASTBAY_CENTRE := [Rect2(105, 87, 8, 7.5), Rect2(115, 87, 8, 7.5), Rect2(125, 87, 8, 7.5),
		Rect2(135, 87, 8, 7.5)]
const EASTBAY_SHOPS := [
	[Cat.FOG_OFFICE, 3.8, 1], [Cat.FOG_MOD_TOWER, 3.2, 1, 0], [Cat.FOG_FLOOR, 3.0, 3], [Cat.FOG_MOD_HOUSE, 3.2, 1, 2],
	[Cat.FOG_OFFICE_TOWER, 3.2, 1], [Cat.FOG_MOD_HOUSE, 2.8, 1, 1], [Cat.FOG_FLOOR, 3.0, 2], [Cat.FOG_MOD_TOWER, 3.4, 1, 1],
]
const EASTBAY_HOMES := [Rect2(105, 77, 8, 8), Rect2(115, 77, 8, 8), Rect2(125, 77, 8, 8),
		Rect2(105, 67, 8, 8), Rect2(115, 67, 8, 8), Rect2(125, 67, 8, 8),
		Rect2(135, 77, 8, 8), Rect2(135, 67, 8, 8)]
## Houses, in turn: the house of the fog_city pack and low blocks (no model of the main island:
## the fog island has its own buildings).
const HOMES := [[Cat.FOG_HOUSE, 2.2, 0], [Cat.FOG_MOD_HOUSE, 2.3, 0], [Cat.FOG_HOUSE, 2.0, 0],
		[Cat.FOG_MOD_HOUSE, 2.3, 1], [Cat.FOG_FLOOR, 2.3, 0], [Cat.FOG_MOD_HOUSE, 2.4, 2], [Cat.FOG_HOUSE, 2.3, 0]]

## The modular town houses (FOG_MOD_HOUSE, FOG_MOD_HOME) all show their fronts to the south,
## whatever side of the block they stand on.
const MOD_HOUSE_CATS := [Cat.FOG_MOD_HOUSE, Cat.FOG_MOD_HOME]
## Houses of HOMES (their number, counted over all the house blocks) that were a house of
## another kind and are the seven modular homes of the fog_homes pack now, one of each.
const MOD_HOMES_AT := [0, 20, 41, 63, 84, 105, 126]
const MOD_HOME_FIT := 2.4

## Crop fields: [top-left cell, size]; their kind is taken in turn.
const FIELDS := [
	[Vector2(76.5, 49), Vector2(6.5, 5)], [Vector2(83.5, 49), Vector2(6.5, 5)],
	[Vector2(94, 49), Vector2(6.5, 5)], [Vector2(101, 49), Vector2(6.5, 5)],
	[Vector2(76.5, 55), Vector2(6.5, 5)], [Vector2(83.5, 55), Vector2(6.5, 5)],
	[Vector2(94, 55), Vector2(6.5, 5)], [Vector2(101, 55), Vector2(6.5, 5)],
	[Vector2(59, 129), Vector2(6.5, 5.5)], [Vector2(66, 129), Vector2(6.5, 5.5)],
	[Vector2(80, 129), Vector2(6.5, 5.5)], [Vector2(87, 129), Vector2(6.5, 5.5)],
	[Vector2(59, 135.5), Vector2(6.5, 5.5)], [Vector2(66, 135.5), Vector2(6.5, 5.5)],
	[Vector2(80, 135.5), Vector2(6.5, 5.5)], [Vector2(87, 135.5), Vector2(6.5, 5.5)],
	[Vector2(110, 51.5), Vector2(6.5, 5.5)], [Vector2(117, 51.5), Vector2(6.5, 5.5)],
	[Vector2(110, 57.5), Vector2(6.5, 5.5)], [Vector2(117, 57.5), Vector2(6.5, 5.5)],
]
const FIELD_MESHES := ["field_wheat", "field_corn", "field_plowed", "field_green"]
## Farm buildings: [place, footprint].
## The houses at (80, 65), (86, 65) and (104, 64) were taken away; the ones at (97, 65) and
## (127, 57) are country market stores (FARMS_AS_MARKET, indexes of FARMS).
const FARMS := [[Vector2(97, 65), 4.4], [Vector2(74, 133), 3.0], [Vector2(96.5, 132), 2.5],
		[Vector2(127, 57), 4.4]]
const FARMS_AS_MARKET := [0, 3]

## The industrial zone, drawn with the buildings of the port of the main island (halls, sheds,
## tanks, a crane, shipping containers): [model, place, the way the front looks, footprint in
## cells, which model of the category, storeys]. A String model is a named mesh (a container).
const INDUSTRY_PLAN := [
	# North border of the square: the factory hall, turned along the border.
	[Cat.IND_HALL, Vector2(80, 101.5), Vector2(1, 0), 8.0, 2],
	# Two lines of food warehouses (the old warehouse model), fronts to the south.
	[Cat.FOG_WAREHOUSE, Vector2(77, 107), Vector2(0, 1), 6.0, 0],
	[Cat.FOG_WAREHOUSE, Vector2(83.8, 107), Vector2(0, 1), 6.0, 0],
	[Cat.FOG_WAREHOUSE, Vector2(77, 112), Vector2(0, 1), 6.0, 0],
	[Cat.FOG_WAREHOUSE, Vector2(83.8, 112), Vector2(0, 1), 6.0, 0],
	# North-east block: a warehouse and the oil and gas tanks.
	[Cat.IND_HALL, Vector2(94.5, 101.5), Vector2(0, 1), 6.0, 8],
	[Cat.PORT_TANK, Vector2(92.5, 108), Vector2(0, 1), 4.0, 0],
	[Cat.PORT_TANK, Vector2(96.5, 106), Vector2(0, 1), 4.0, 1],
	[Cat.PORT_TANK, Vector2(96.5, 110), Vector2(0, 1), 3.0, 3],
	# South-west block: the hangar and the crane of the quay.
	[Cat.IND_HALL, Vector2(79.5, 122), Vector2(0, -1), 8.0, 4],
	[Cat.IND_TOWER, Vector2(85.5, 122.5), Vector2(0, 1), 4.0, 0],
	# South-east block: the container yard (containers as small as on the main island's yards,
	# 1.3 cells long, stacked up to two high) and a shed.
	["yardbox:01", Vector2(91.6, 118.6), Vector2(1, 0), 1.3, 0, 2],
	["yardbox:04", Vector2(93.2, 118.6), Vector2(1, 0), 1.3, 0, 1],
	["yardbox:09", Vector2(94.8, 118.6), Vector2(1, 0), 1.3, 0, 2],
	["yardbox:02", Vector2(96.4, 118.6), Vector2(1, 0), 1.3, 0, 1],
	["yardbox:10", Vector2(91.6, 119.6), Vector2(1, 0), 1.3, 0, 1],
	["yardbox:01", Vector2(93.2, 119.6), Vector2(1, 0), 1.3, 0, 2],
	["yardbox:04", Vector2(94.8, 119.6), Vector2(1, 0), 1.3, 0, 1],
	["yardbox:09", Vector2(96.4, 119.6), Vector2(1, 0), 1.3, 0, 2],
	["yardbox:02", Vector2(91.6, 120.6), Vector2(1, 0), 1.3, 0, 2],
	["yardbox:10", Vector2(93.2, 120.6), Vector2(1, 0), 1.3, 0, 1],
	["yardbox:01", Vector2(94.8, 120.6), Vector2(1, 0), 1.3, 0, 2],
	["yardbox:04", Vector2(96.4, 120.6), Vector2(1, 0), 1.3, 0, 1],
	[Cat.IND_SHED, Vector2(95, 125), Vector2(0, -1), 4.0, 0],
]

## Cars parked along the streets of the towns: [place, the way the nose looks].
const CARS := ["m8_long_sedan_black", "p54_04_sedan_modern_silver", "m8_wagon_blue", "m8_sedan_dark_red",
		"p54_03_sedan_classic_maroon", "m8_pickup_blue", "m8_wagon_teal", "p54_05_sedan_90s_teal",
		"m8_sedan_mustard", "p54_01_suv_offroad_navy"]
const CAR_SPOTS := [
	[Vector2(50.6, 80), Vector2(0, 1)], [Vector2(49.4, 91), Vector2(0, -1)], [Vector2(50.6, 101), Vector2(0, 1)],
	[Vector2(60.6, 90), Vector2(0, 1)], [Vector2(59.4, 110), Vector2(0, -1)], [Vector2(40.6, 112), Vector2(0, 1)],
	[Vector2(70.6, 92), Vector2(0, -1)], [Vector2(46, 105.4), Vector2(1, 0)], [Vector2(64, 86.6), Vector2(-1, 0)],
	[Vector2(55, 116.6), Vector2(1, 0)], [Vector2(45, 76.6), Vector2(-1, 0)], [Vector2(66, 125.4), Vector2(1, 0)],
	[Vector2(114.6, 90), Vector2(0, 1)], [Vector2(123.4, 80), Vector2(0, -1)], [Vector2(109, 86.6), Vector2(1, 0)],
	[Vector2(128, 85.4), Vector2(-1, 0)], [Vector2(104.6, 71), Vector2(0, 1)], [Vector2(130, 76.6), Vector2(1, 0)],
	[Vector2(30.6, 112), Vector2(0, 1)], [Vector2(35, 116.6), Vector2(1, 0)], [Vector2(144.6, 80), Vector2(0, 1)],
	[Vector2(139, 86.6), Vector2(-1, 0)], [Vector2(115, 130.6), Vector2(1, 0)], [Vector2(120.6, 136), Vector2(0, 1)],
]
## Other vehicles: [catalog id, place, nose].
const VEHICLES := [
	["school_bus", Vector2(55, 106.6), Vector2(1, 0)],
	["p54_33_fire_truck", Vector2(45, 86.6), Vector2(1, 0)],
	["p54_11_ambulance", Vector2(118, 86.6), Vector2(-1, 0)],
	["p54_14_semi_longnose_red", Vector2(88.6, 104), Vector2(0, -1)],
	# The yellow delivery box truck of the road to the yard became a red tractor (p54_14); a cream
	# tractor and the DYRER box truck park in the same stretch of road.
	["p54_14_semi_longnose_red", Vector2(87.4, 121), Vector2(0, 1)],
	["p54_20_semi_cabover_yellow", Vector2(88.6, 118.4), Vector2(0, -1)],
	["p54_07_box_truck_delivery_yellow", Vector2(87.4, 125.2), Vector2(0, 1)],
	["p54_15_dump_truck_yellow", Vector2(80, 115.6), Vector2(1, 0)],
	["p54_43_tractor_vintage_trailer", Vector2(87, 57.5), Vector2(1, 0)],
	["p54_21_harvester_olive", Vector2(97.3, 51.5), Vector2(-1, 0)],
	["p54_42_forwarder_green", Vector2(69.3, 132), Vector2(0, 1)],
	[HUMVEE, Vector2(97, 115.6), Vector2(1, 0)],   # at the gate of the plant
	[HUMVEE, Vector2(36, 96.7), Vector2(1, 0)],    # on the avenue, past the blockade
]


## Every model of the island: {"cat" or "veh" or "named" or "landing_zone", "at": Vector2 (local
## cells), "dir": Vector2 the front looks to, "scale"}, and optional "fit" (footprint in cells,
## instead of "scale"), "v" (which model of the category), "stack" (storeys piled up), "size"
## (a flat model stretched over that many cells, x by y).
static func plan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var north := Vector2(0, -1)
	var south := Vector2(0, 1)
	var east := Vector2(1, 0)
	var west := Vector2(-1, 0)
	# --- Blockade at the end of the bridge, the vehicles of the old checkpoint behind it ---
	for row: float in BLOCKADE_LANES:
		out.append({"cat": Cat.ROADBLOCK_A, "at": Vector2(BLOCKADE_AT.x + 0.5, row), "dir": east, "fit": BARRIER_LEN})
	for k in 4:
		out.append({"cat": Cat.CONE, "at": Vector2(BLOCKADE_AT.x - 1.4, BLOCKADE_AT.y + (float(k) - 1.5)), "dir": south,
				"fit": CONE_LEN})
	# The T-55 and the BRDM of the pack look along -Z (the gun of the tank points that way), so they are
	# stood with `east` to look west, at the bridge.
	for v in BLOCKADE_PARK:
		_add(out, v[0], Vector2(BLOCKADE_AT.x + 0.5 + float(v[1]), BLOCKADE_AT.y + float(v[2])), east)
	_veh(out, HUMVEE, BLOCKADE_AT + BLOCKADE_HUMVEE, west)
	# --- The army base: landing zone, helipad, tents, barracks, a few vehicles ---
	out.append({"landing_zone": true, "at": LANDING_ZONE, "dir": south, "scale": 1.0})
	_veh(out, HELICOPTER, HELIPAD, east)
	var tents := [Cat.TENT_JUNGLE, Cat.TENT_JUNGLE, Cat.TENT_MEDICAL]
	for k in tents.size():
		out.append({"cat": tents[k], "at": Vector2(52.2 + k * 2.9, 66.0), "dir": south, "fit": 2.5})
	out.append({"cat": Cat.BASE_HALL, "at": Vector2(65, 62), "dir": west, "fit": 3.5})
	out.append({"cat": Cat.RADAR, "at": Vector2(68, 54.5), "dir": south, "fit": 1.6})
	# Armoured vehicles in a row by the barracks, their noses (-Z of the pack) to the south.
	var row := [Cat.TANK_T55, Cat.TANK_T55, Cat.APC_BMP1, Cat.APC_EE11, Cat.APC_BRDM]
	for k in row.size():
		_add(out, row[k], Vector2(61.6 + k * 1.5, 66.8), north)
	_veh(out, JEEP, Vector2(59.8, 64.0), north)
	_veh(out, HUMVEE, Vector2(61.0, 64.0), south)
	# --- Nuclear plant, in its fence ---
	_add(out, Cat.NUCLEAR2, Vector2(116, 114), east)
	out.append({"cat": Cat.BASE_HALL, "at": Vector2(106, 123.5), "dir": north, "fit": 4.0})
	for i in 2:
		_add(out, Cat.APC_BRDM, Vector2(102.5 + i * 1.1, 106), south)
	# --- Towns ---
	var n := 0
	for k in CAPITAL_CENTRE.size():
		var r: Rect2 = CAPITAL_CENTRE[k]
		var face := south if r.position.y < 96.0 else north
		for side in 2:
			_building(out, CAPITAL_TOWERS[n % CAPITAL_TOWERS.size()],
					Vector2(r.position.x + (2.1 if side == 0 else 5.9), r.get_center().y), face, n)
			n += 1
	for k in EASTBAY_CENTRE.size():
		var r: Rect2 = EASTBAY_CENTRE[k]
		for side in 2:
			_building(out, EASTBAY_SHOPS[(k * 2 + side) % EASTBAY_SHOPS.size()],
					Vector2(r.position.x + (2.1 if side == 0 else 5.9), r.get_center().y), south, k * 2 + side)
	var h := 0
	for r: Rect2 in CAPITAL_HOMES + EASTBAY_HOMES:
		h = _homes(out, r, h)
	# --- Industrial zone: the buildings, tanks, crane and containers of the port of the main island ---
	for e in INDUSTRY_PLAN:
		var item := {"at": e[1], "dir": e[2], "fit": e[3]}
		if e[0] is String:
			item["named"] = e[0]
		else:
			item["cat"] = e[0]
			item["v"] = e[4]
		if e.size() > 5:
			item["stack"] = e[5]
		out.append(item)
	# --- Farmland ---
	for k in FIELDS.size():
		var f: Array = FIELDS[k]
		var size: Vector2 = f[1]
		out.append({"named": FIELD_MESHES[k % FIELD_MESHES.size()], "at": (f[0] as Vector2) + size * 0.5,
				"dir": south, "size": size})
	for k in FARMS.size():
		# The farm buildings of FARMS_AS_MARKET are the country market store, not houses.
		var farm_cat: int = Cat.FOG_MARKET if FARMS_AS_MARKET.has(k) else Cat.FOG_HOUSE
		out.append({"cat": farm_cat, "at": FARMS[k][0], "dir": south, "fit": FARMS[k][1]})
	# --- Vehicles ---
	for k in CAR_SPOTS.size():
		_veh(out, CARS[k % CARS.size()], CAR_SPOTS[k][0], CAR_SPOTS[k][1])
	for v in VEHICLES:
		_veh(out, v[0], v[1], v[2])
	return out


## One building of a town: `spec` = [category, footprint, storeys].
static func _building(out: Array[Dictionary], spec: Array, at: Vector2, face: Vector2, v: int) -> void:
	var e := {"cat": spec[0], "at": at, "dir": Vector2(0, 1) if MOD_HOUSE_CATS.has(spec[0]) else face, "fit": spec[1], "v": int(spec[3]) if spec.size() > 3 else v}
	if int(spec[2]) > 1:
		e["stack"] = int(spec[2])
	out.append(e)


## Six houses on a block (two rows of three), each facing the street of its side. Returns the
## next number in HOMES.
static func _homes(out: Array[Dictionary], r: Rect2, first: int) -> int:
	var k := first
	for row in 2:
		var y := r.position.y + (2.0 if row == 0 else r.size.y - 2.0)
		var face := Vector2(0, -1) if row == 0 else Vector2(0, 1)
		for col in 3:
			var spec: Array = HOMES[k % HOMES.size()]
			var home := MOD_HOMES_AT.find(k)
			if home >= 0:
				spec = [Cat.FOG_MOD_HOME, MOD_HOME_FIT, home]
			out.append({"cat": spec[0], "at": Vector2(r.position.x + 1.4 + col * 2.6, y),
					"dir": Vector2(0, 1) if MOD_HOUSE_CATS.has(spec[0]) else face,
					"fit": spec[1], "v": int(spec[2])})
			k += 1
	return k


static func _add(out: Array[Dictionary], cat: int, at: Vector2, dir: Vector2, scale: float = 1.0) -> void:
	out.append({"cat": cat, "at": at, "dir": dir, "scale": scale})


## A vehicle of the catalog (res://vehicles).
static func _veh(out: Array[Dictionary], id: String, at: Vector2, dir: Vector2) -> void:
	out.append({"veh": id, "at": at, "dir": dir, "scale": VehicleSites.size_factor(id)})


## Colour of the ground at local cell `p`, or null where nothing is painted.
static func pad_color(p: Vector2) -> Variant:
	for pad in PADS:
		if (pad[0] as Rect2).has_point(p):
			return pad[1]
	return null
