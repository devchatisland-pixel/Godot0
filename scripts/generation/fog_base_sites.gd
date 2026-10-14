class_name FogBaseSites
extends RefCounted
## The fog island as an inhabited island (local cells of the island, FogIslandShaper; x east,
## y south). The avenue from the Golden Gate runs west to east through it:
##   - the blockade where the road leaves the bridge (barriers and cones across the three lanes,
##     the T-55, the BRDM and the Humvee behind it, noses to the bridge);
##   - ONE big city round a centre (FogCityLayout): skyscrapers in the middle, offices and flats
##     round them, houses and the shops further out, on ring roads and radial streets;
##   - the industrial port south of the city (the buildings of the port of the main island);
##   - one farmland, north-east: crop fields, a few farm buildings, a tractor and a harvester;
##   - the nuclear plant, smaller, in a fence on the east shore;
##   - a very small army base in a fence north-west: its landing zone is the model of the secret
##     base of the main island, drawn at the same size, with a helipad, a few tents, a barracks
##     and a few armoured vehicles.
## The models of the fog_city pack (offices, night tower, house, block storeys) are used for
## every building of the city, the industry and the farm; the shops are the shops of the catalog.
## Pure data: FogIslandShaper paints PADS on the ground, FogBase draws the roads, FENCES and plan().

const Cat := ModelCatalog.Cat

const CONCRETE := Color("a8a69d")
const TARMAC := Color("77787c")
const DIRT := Color("9a8c68")
const PAVED := Color("9c9ea3")
const SUBURB := Color("8fb565")
const INDUSTRY := Color("9a978f")
const FARM := Color("a59a62")

## The zones (local cells): the city is laid out round them (FogCityLayout.keep_out).
const CHECKPOINT_RECT := Rect2(18.8, 89.7, 14.4, 11.1)
const BASE_RECT := Rect2(49.5, 52.5, 20, 16.5)
const PLANT_RECT := Rect2(134.0, 103.0, 18.0, 16.0)
const INDUSTRY_RECT := Rect2(60.0, 124.0, 58.0, 30.0)
const FARM_RECT := Rect2(75.0, 43.0, 53.0, 23.0)
const KEEP_OUT := [
	Rect2(0, 89.0, 36.0, 15.0), BASE_RECT, PLANT_RECT, INDUSTRY_RECT, FARM_RECT,
]

## Ground painted under the island's places: [rect in cells, colour] (the first match wins); the
## city itself is painted by distance to its centre (pad_color).
const PADS := [
	[CHECKPOINT_RECT, CONCRETE],
	[BASE_RECT, CONCRETE],                      # army base (inside its fence)
	[PLANT_RECT, CONCRETE],                     # nuclear plant
	[INDUSTRY_RECT, INDUSTRY],
	[FARM_RECT, FARM],
]

## Roads drawn with the highway texture: [from, to (centre line), width]. The streets of the
## city are made by FogCityLayout; these are the avenue and the way from the bridge.
const ROADS := [
	# The avenue is centred on the deck of the bridge: row 96 of the island is the bridge row of
	# the city, whose middle is half a cell further south.
	[Vector2(15, 96.5), Vector2(18.8, 96.5), 3.0],  # from the bridge to the blockade,
	[Vector2(18.8, 96.5), Vector2(33.2, 96.5), 1.5], # between the walls of its two gates,
	[Vector2(33.2, 96.5), Vector2(150, 96.5), 3.0], # then the avenue across the island
]
## Inside the industrial port (moved with INDUSTRY_SHIFT).
const INDUSTRY_ROADS := [[Vector2(70, 139), Vector2(100, 139), 2.0]]
const INDUSTRY_SHIFT := Vector2(0, 24)

## Wire fences: [rect in cells, side of the gate (0 N, 1 E, 2 S, 3 W), height].
const FENCES := [
	[Rect2(49.5, 52.5, 20, 16.5), 2, 0.45],  # army base, gate on the road of the city
	[Rect2(134.5, 103.5, 17, 15), 3, 0.5],   # nuclear plant, gate on the road of the city
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

## Crop fields of the one farmland: columns and rows (top-left cell of the first, pitch, size).
const FIELD_ORIGIN := Vector2(78.0, 45.0)
const FIELD_COLS := 6
const FIELD_ROWS := 3
const FIELD_PITCH := Vector2(8.4, 6.7)
const FIELD_SIZE := Vector2(6.5, 5.0)
const FIELD_MESHES := ["field_wheat", "field_corn", "field_plowed", "field_green"]
## Farm buildings: [place, footprint]; the first and the last are country market stores.
const FARMS := [[Vector2(72.5, 49), 4.4], [Vector2(72.5, 63), 3.0], [Vector2(131.5, 49), 4.4]]
const FARMS_AS_MARKET := [0, 2]
## The nuclear plant, smaller than it was: scale of the model.
const PLANT_SCALE := 0.62

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

## Cars parked along the streets (FogCityLayout puts them along the rings).
const CARS := ["m8_long_sedan_black", "p54_04_sedan_modern_silver", "m8_wagon_blue", "m8_sedan_dark_red",
		"p54_03_sedan_classic_maroon", "m8_pickup_blue", "m8_wagon_teal", "p54_05_sedan_90s_teal",
		"m8_sedan_mustard", "p54_01_suv_offroad_navy"]
## Other vehicles: [catalog id, place, nose]. `ring` ones are on a ring of the city: [R, degrees].
const VEHICLES := [
	["school_bus", Vector2(0, 0), Vector2(1, 0), 27.0, 200.0],
	["p54_33_fire_truck", Vector2(0, 0), Vector2(1, 0), 15.0, 60.0],
	["p54_11_ambulance", Vector2(0, 0), Vector2(-1, 0), 15.0, 235.0],
	["p54_14_semi_longnose_red", Vector2(88.6, 128), Vector2(0, -1)],
	["p54_14_semi_longnose_red", Vector2(87.4, 145), Vector2(0, 1)],
	["p54_20_semi_cabover_yellow", Vector2(88.6, 142.4), Vector2(0, -1)],
	["p54_07_box_truck_delivery_yellow", Vector2(87.4, 149.2), Vector2(0, 1)],
	["p54_15_dump_truck_yellow", Vector2(80, 139.6), Vector2(1, 0)],
	["p54_43_tractor_vintage_trailer", Vector2(92, 51.6), Vector2(1, 0)],
	["p54_21_harvester_olive", Vector2(108, 58.0), Vector2(-1, 0)],
	["p54_42_forwarder_green", Vector2(122, 51.4), Vector2(0, 1)],
	[HUMVEE, Vector2(131.6, 112.2), Vector2(1, 0)],  # at the gate of the plant
	[HUMVEE, Vector2(36, 96.7), Vector2(1, 0)],    # on the avenue, past the blockade
]


## The roads of the island: the avenue and the way from the bridge, the streets of the city and
## the lanes of the port. [from, to, width].
static func roads(fog: FogIslandShaper) -> Array:
	var out: Array = []
	out.append_array(FogCityLayout.build(fog.elevation)["roads"])
	return out


## Every model of the island: {"cat" or "veh" or "named" or "shop" or "landing_zone", "at":
## Vector2 (local cells), "dir": Vector2 the front looks to, "scale"}, and optional "fit"
## (footprint in cells, instead of "scale"), "v" (which model of the category), "stack" (storeys
## piled up), "size" (a flat model stretched over that many cells, x by y).
static func plan(fog: FogIslandShaper) -> Array[Dictionary]:
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
	# --- Nuclear plant, in its (smaller) fence, on the east shore ---
	var pc := PLANT_RECT.get_center()
	_add(out, Cat.NUCLEAR2, pc + Vector2(1.5, -0.5), east, PLANT_SCALE)
	out.append({"cat": Cat.BASE_HALL, "at": Vector2(PLANT_RECT.position.x + 4.0, PLANT_RECT.end.y - 2.4), "dir": north, "fit": 3.6})
	for i in 2:
		_add(out, Cat.APC_BRDM, Vector2(PLANT_RECT.position.x + 2.2, pc.y - 1.0 + i * 1.6), west)
	# --- The city ---
	var layout := FogCityLayout.build(fog.elevation)
	for e: Dictionary in layout["items"]:
		var item := e.duplicate()
		if item.has("veh"):
			item["scale"] = VehicleSites.size_factor(item["veh"])
		out.append(item)
	# --- Industrial zone: the buildings, tanks, crane and containers of the port of the main island ---
	for e in INDUSTRY_PLAN:
		var item := {"at": (e[1] as Vector2) + INDUSTRY_SHIFT, "dir": e[2], "fit": e[3]}
		if e[0] is String:
			item["named"] = e[0]
		else:
			item["cat"] = e[0]
			item["v"] = e[4]
		if e.size() > 5:
			item["stack"] = e[5]
		out.append(item)
	# --- Farmland: one zone ---
	var k := 0
	for r in FIELD_ROWS:
		for c in FIELD_COLS:
			var top := FIELD_ORIGIN + Vector2(c * FIELD_PITCH.x, r * FIELD_PITCH.y)
			out.append({"named": FIELD_MESHES[k % FIELD_MESHES.size()], "at": top + FIELD_SIZE * 0.5,
					"dir": south, "size": FIELD_SIZE})
			k += 1
	for i in FARMS.size():
		var farm_cat: int = Cat.FOG_MARKET if FARMS_AS_MARKET.has(i) else Cat.FOG_HOUSE
		out.append({"cat": farm_cat, "at": FARMS[i][0], "dir": south, "fit": FARMS[i][1]})
	# --- Other vehicles ---
	for v in VEHICLES:
		if v.size() > 3:
			var a: float = deg_to_rad(float(v[4]))
			var rr: float = float(v[3]) + 0.55
			_veh(out, v[0], FogCityLayout.CENTER + Vector2(cos(a), sin(a)) * rr, Vector2(-sin(a), cos(a)))
		else:
			_veh(out, v[0], v[1], v[2])
	return out


static func _add(out: Array[Dictionary], cat: int, at: Vector2, dir: Vector2, scale: float = 1.0) -> void:
	out.append({"cat": cat, "at": at, "dir": dir, "scale": scale})


## A vehicle of the catalog (res://vehicles).
static func _veh(out: Array[Dictionary], id: String, at: Vector2, dir: Vector2) -> void:
	out.append({"veh": id, "at": at, "dir": dir, "scale": VehicleSites.size_factor(id)})


## Colour of the ground at local cell `p`, or null where nothing is painted: the places of PADS,
## then the paved centre of the city and the green of its suburbs.
static func pad_color(p: Vector2) -> Variant:
	for pad in PADS:
		if (pad[0] as Rect2).has_point(p):
			return pad[1]
	var d := p.distance_to(FogCityLayout.CENTER)
	if d < 34.0:
		return PAVED
	if d < 68.0:
		return PAVED.lerp(SUBURB, clampf((d - 34.0) / 12.0, 0.0, 1.0))
	return null
