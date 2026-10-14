class_name ManualEdits
extends RefCounted
## Hand-made corrections to single buildings, applied once the whole map is generated
## (CityGenerator). An entry does not name a cell or a building number, which change with
## every rebuild of the map: it names a `kind` and a place `near` (a cell of the first map,
## 272 cells; MapLayout scales it), and applies to the nearest building of that kind that no
## other entry took. How many buildings of each kind there are is not decided here:
## BuildingBudget clears the surplus afterwards (and never one that an entry changed).
##   facing   0 north, 1 east, 2 south, 3 west (the side of the front)
##   scale    size factor of the model, 1 = as placed
##   scale_abs  absolute scale of the model, 1 = its own size (ignores the lot)
##   replace  name of the Kind the building becomes (it keeps its lot and its facing)
##   delete   true = nothing is drawn any more
##   park     true = the cells of the lot become park ground (trees grow there; use with delete)
##   size     [w, h] the new size of the lot, from the same top-left cell (when the ground is free)
##   shift    cells the lot moves by, on the first map (when the ground is free)
##   old_ground  zone name given back to the cells the building leaves when its lot changes
##            (the cells it enters take the ground of the building)
##   model    name of the model to draw, as the library names it (e.g. "building-type-n.glb")
##   clear_quay  radius: sand instead of quay ground (rocky = 2) within that many cells of the building
##   sign     name of a ModelCatalog.Cat (a neon sign); BuildingExtras.SIGNS says where it goes
##   lay      true = a flat model (crop field) is laid along `facing` instead of the long side

## Edit index -> building number it was applied to (filled by `apply`; read by the tests
## and by BuildingBudget).
static var resolved := {}
## Building numbers deleted by DELETED_AT (filled by `delete_by_hand`):
## they win over an entry of EDITS that changed the same building (read by the tests).
static var hand_deleted := {}

const EDITS := [
	{"kind": "CRANE", "near": Vector2i(132, 165), "facing": 1},
	# Drawn at 0.45 of its 8x8 lot; finish() shrinks the lot to its middle 4x4 (same model size).
	{"kind": "CINEMA_MAIN", "near": Vector2i(139, 143), "scale": 0.9},
	{"kind": "BANK", "near": Vector2i(139, 157), "scale": 0.6},
	# A hotel becomes a park with trees, another one the city hall.
	{"kind": "HOTEL", "near": Vector2i(164, 129), "delete": true, "park": true},
	{"kind": "HOTEL", "near": Vector2i(120, 129), "replace": "CITY_HALL", "size": [3, 5]},
	{"kind": "HOTEL", "near": Vector2i(100, 166), "facing": 3},
	{"kind": "HOTEL", "near": Vector2i(170, 164), "scale_abs": 1.0},
	{"kind": "HOTEL", "near": Vector2i(123, 210), "facing": 2},
	{"kind": "HOTEL", "near": Vector2i(154, 214), "facing": 2},
	{"kind": "AIRBASE", "near": Vector2i(69, 113), "shift": Vector2i(6, -5), "size": [5, 16], "facing": 1,
		"old_ground": "DESERT"},
	{"kind": "PHARMACY", "near": Vector2i(150, 166), "facing": 2},
	{"kind": "SHOP", "near": Vector2i(110, 71), "replace": "BURGER_KING"},
	{"kind": "HOSPITAL", "near": Vector2i(160, 139), "replace": "MAIN_HOSPITAL", "scale_abs": 1.0},
	{"kind": "SHOP", "near": Vector2i(137, 102), "facing": 1, "replace": "HOUSE",
		"model": "building-type-n.glb", "sign": "NEON_CONTROLLER"},
	{"kind": "POLICE", "near": Vector2i(171, 154), "sign": "NEON_PACMAN"},
	{"kind": "POLICE_HQ", "near": Vector2i(118, 148), "scale": 0.75},
	{"kind": "QUARTER_BLDG", "near": Vector2i(165, 208), "replace": "HOSPITAL"},
	{"kind": "LIGHTHOUSE", "near": Vector2i(93, 202), "clear_quay": 6},
	{"kind": "OUTPOST", "near": Vector2i(80, 134), "shift": Vector2i(0, -33)},
	{"kind": "FIRE_STATION", "near": Vector2i(150, 140), "scale": 1.12},
	{"kind": "POST_OFFICE", "near": Vector2i(133, 152), "scale": 1.12},
	# Shopping center: a casino stands in a park where it was.
	{"kind": "SHOPPING_CENTER", "near": Vector2i(100, 138), "replace": "CASINO", "size": [3, 3],
		"old_ground": "PARK"},
	# Business pack eateries in the central city: shops become 3 restaurants, 2 pizzerias, 1 burger bar, 4 cafes.
	{"kind": "SHOP", "near": Vector2i(138, 149), "replace": "RESTAURANT"},
	{"kind": "SHOP", "near": Vector2i(135, 146), "replace": "RESTAURANT"},
	{"kind": "SHOP", "near": Vector2i(142, 152), "replace": "RESTAURANT"},
	{"kind": "SHOP", "near": Vector2i(140, 150), "replace": "PIZZA_SHOP"},
	{"kind": "SHOP", "near": Vector2i(136, 152), "replace": "PIZZA_SHOP"},
	{"kind": "SHOP", "near": Vector2i(138, 143), "replace": "BURGER_SHOP"},
	{"kind": "SHOP", "near": Vector2i(134, 152), "replace": "CAFE"},
	{"kind": "SHOP", "near": Vector2i(146, 151), "replace": "CAFE"},
	{"kind": "SHOP", "near": Vector2i(144, 142), "replace": "CAFE"},
	{"kind": "SHOP", "near": Vector2i(147, 148), "replace": "CAFE"},
	# The corn field of the farm next to the tractor faces west.
	{"kind": "FIELD", "near": Vector2i(196, 174), "facing": 3, "lay": true},
]

## Kinds taken away everywhere: the airport, the urban ghetto block and the wings of the prison.
const DELETED_KINDS := ["AIRPORT", "RUSSIAN", "PRISON_WING"]

## Other buildings taken away by hand: kind and top-left cell of the lot on the final map.
const DELETED_AT := [
	["BALLOON", Vector2i(250, 141)],
	["HOTEL", Vector2i(206, 302)],
	["HOTEL", Vector2i(182, 301)],
	["PIER", Vector2i(138, 291)],
	["SHOP", Vector2i(172, 185)],
	["SHOP", Vector2i(170, 190)],
	["SHOP", Vector2i(170, 191)],
	["BILLBOARD", Vector2i(168, 187)],
	["OIL_PUMP", Vector2i(93, 168)],
	["BILLBOARD", Vector2i(260, 85)],
	["BILLBOARD", Vector2i(276, 256)],
	["TANK", Vector2i(100, 143)],
	["INDUSTRIAL", Vector2i(28, 94)],
	["INDUSTRIAL", Vector2i(38, 94)],
	["INDUSTRIAL", Vector2i(29, 83)],
	["INDUSTRIAL_YARD", Vector2i(32, 86)],
	["INDUSTRIAL_YARD", Vector2i(28, 88)],
	["INDUSTRIAL_YARD", Vector2i(37, 86)],
	["BOAT", Vector2i(167, 338)],
	["BOAT", Vector2i(21, 300)],
	["OIL_PUMP", Vector2i(121, 140)],
	["OUTPOST", Vector2i(122, 145)],
	["BURGER_KING", Vector2i(164, 102)],
	["NIGHTCLUB", Vector2i(128, 171)],
	["NIGHTCLUB", Vector2i(121, 178)],
	["PHARMACY", Vector2i(167, 203)],
]
## Buildings turned by hand: kind, top-left cell of the lot on the final map, facing (0 N, 1 E, 2 S, 3 W).
const TURNED_AT := [
	["MAIN_HOSPITAL", Vector2i(243, 201), 2],
	["MAIN_HOSPITAL", Vector2i(167, 195), 2],
]
## Buildings taken away by hand once the buildings are final (in `finish`, after the burger
## joints became McDonald's): kind and top-left cell of the lot on the final map.
const DELETED_LATE := [
	["MCDONALDS", Vector2i(237, 202)],
	["APARTMENT", Vector2i(175, 216)],
	# The apartment block in front of the fire station of (155, 210): the main one moves there.
	["APARTMENT", Vector2i(155, 213)],
	["CAFE", Vector2i(206, 213)],
	["RESTAURANT", Vector2i(200, 215)],
]
## Buildings drawn with another model by hand (in `finish`): kind, top-left cell of the lot on
## the final map, model (as the library names it).
const MODEL_AT := [
	["APARTMENT", Vector2i(138, 228), "building-k.glb"],
	["APARTMENT", Vector2i(148, 237), "building-k.glb"],
	["QUARTER_BLDG", Vector2i(193, 225), "building-k.glb"],
	["QUARTER_BLDG", Vector2i(188, 277), "building-k.glb"],
	# The church of the civic ground is drawn like the one of the suburb.
	["CHURCH", Vector2i(243, 214), "church_low.glb: church_low"],
]
## Buildings moved by hand (in `finish`, after the deletions): kind, top-left cell of the lot on
## the final map, new lot, new facing (0 N, 1 E, 2 S, 3 W). The ground follows the lot.
const MOVED_AT := [
	# The fire station of the east moves in front of the small one, across the street.
	["FIRE_STATION", Vector2i(198, 193), Rect2i(155, 213, 3, 3), 0],
]
## The main hospital whose front yard is paved like its lot (no grass), and how deep (cells).
const PAVED_HOSPITAL := Vector2i(243, 201)
const PAVED_DEPTH := 4
## Road cells of the east highway's north-west end that go back to grass (the stub of avenue
## and street north of the first lane): inclusive corners [from, to].
const HIGHWAY_STUB := Rect2i(252, 188, 3, 2)
## Cleared lots that get a farm building back: top-left cell, model (as the library names it).
const FARM_BUILDINGS_AT := [
	[Vector2i(265, 283), "outpost.glb: water_tank"],
]
## The oil pump whose lot starts at OIL_FIELD and two more stand apart in the middle of the
## desert: top-left cells of their lots, the last one is the reference that does not move.
const OIL_FIELD := Vector2i(99, 209)
const OIL_PUMP_SPOTS := [Vector2i(92, 200), Vector2i(112, 217), Vector2i(103, 209)]
const EXTRA_OIL_PUMPS := 2
## Small shops round the main cinema (it stood alone in its block): how many, lot size.
const CINEMA_SHOPS := 4
const CINEMA_SHOP_SIZE := Vector2i(2, 2)
## The fire station whose front yard is cleared for its fire truck (VehicleSites).
const MAIN_FIRE_STATION := Vector2i(229, 177)
## How far in front of it no tree grows (cells).
const FIRE_YARD_DEPTH := 5

## Buildings drawn at another size by hand: kind, top-left cell of the lot, size factor.
const RESIZED_AT := [
	["BOAT", Vector2i(211, 40), 0.5],
]

## Last hand changes of the finished map (`final_tweaks`), cells of the final map.
const FINAL_DELETED := [["GRAVE", Vector2i(353, 130)],
	# The island of the old BT tower: the ruin and two industrial buildings are taken away.
	["INDUSTRIAL", Vector2i(44, 88)], ["INDUSTRIAL", Vector2i(27, 96)], ["INDUSTRIAL", Vector2i(24, 91)]]
## Kind, top-left cell of the lot, size factor of the model.
const FINAL_RESIZED := [["MUSEUM", Vector2i(213, 207), 0.7],
	# A little bigger: the glass tower (ny_glass_2) and the One World Trade Center of downtown.
	["SKYSCRAPER", Vector2i(149, 150), 1.15], ["LANDMARK", Vector2i(155, 155), 1.15]]
## More shops like the corner ones in the square of the main cinema (model, size factor): top-left
## cell of the 2x2 lot, facing. None in front of the cinema (its south side).
const FINAL_SHOP_MODEL := "building-e.glb"
const FINAL_SHOP_SCALE := 0.8
const FINAL_SHOPS := [
	[Vector2i(200, 203), 0], [Vector2i(202, 203), 0],
	[Vector2i(198, 205), 3], [Vector2i(198, 207), 3],
	[Vector2i(204, 205), 1], [Vector2i(204, 207), 1],
]
## The towers of the Las Vegas casino (the skyscraper model `building-skyscraper-d.glb`, drawn
## stretched in height, see BuildingPlacer) stand side by side along the column of the square of
## Las Vegas (CASINO2_LOTS, facing east), one neon word over them on the east wall.
const CASINO_MODEL := "building-skyscraper-d.glb"
## The square of Las Vegas: a night club (143,186) and two offices (143,188) and (143,192) make
## room for the four towers (CASINO2_LOTS; the first three take the old buildings, the fourth is new),
## the word on the northern one. A casino of the vegas_casino model stands beside them
## (CASINO2_SIDE, facing south). Entries of CASINO2_OLD: [kind, top-left cell] of the buildings taken away.
const CASINO2_OLD := [["NIGHTCLUB", Vector2i(143, 186)], ["OFFICE", Vector2i(143, 188)], ["OFFICE", Vector2i(143, 192)]]
const CASINO2_LOTS := [Rect2i(143, 186, 3, 2), Rect2i(143, 188, 3, 1), Rect2i(143, 189, 3, 2), Rect2i(143, 191, 3, 1)]
const CASINO2_SIDE := Rect2i(146, 189, 2, 3)
## The big casino model of Las Vegas (vegas_casino.glb) draws the side casino and fills the free lots.
const VEGAS_CASINO_MODEL := "vegas_casino.glb: casino_building"
## The Eiffel tower of Las Vegas (eiffel_tower.glb, 11 x 27 x 11): it takes the casino of the block
## at EIFFEL_BLOCK (that casino's lot grows to the whole 8 x 6 block), drawn at an absolute scale.
const EIFFEL_MODEL := "eiffel_tower.glb: eiffel_tower"
const EIFFEL_BLOCK := Rect2i(134, 184, 8, 6)
const EIFFEL_SCALE := 0.38
## The Eiffel tower moves to free Las Vegas ground at least this far from its old block (cells).
## The dishes (top-left cell of their lot on the final map) drawn with the realistic dish.
const REAL_DISH_MODEL := "dish_real.glb: dish_real"
const REAL_DISHES := [Vector2i(104, 188), Vector2i(108, 187), Vector2i(108, 183)]
## The three dishes of the island of the old BT tower, drawn with the second realistic dish.
const REAL_DISH_MODEL_2 := "dish_real2.glb: dish_real2"
const REAL_DISHES_2 := [Vector2i(32, 93), Vector2i(36, 91), Vector2i(36, 88)]
## Skyscrapers of downtown that get taller: kind, top-left cell of the lot, height factor (width and depth stay).
const FINAL_TALLER := [
	["SKYSCRAPER", Vector2i(146, 174), 1.35], ["SKYSCRAPER", Vector2i(146, 166), 1.35],
	["SKYSCRAPER", Vector2i(143, 169), 1.35], ["SKYSCRAPER", Vector2i(163, 165), 1.35],
	["SKYSCRAPER", Vector2i(159, 162), 1.35],
]
## Casinos (top-left cell of the lot) that become the glass tower, clubs that become casinos of the
## Vegas model, and buildings taken away (kind, top-left cell).
const GLASS_MODEL := "ny_buildings.glb: ny_glass_1"
const FINAL_TO_GLASS := [Vector2i(128, 199), Vector2i(132, 171)]
const FINAL_TO_CASINO := [Vector2i(122, 182), Vector2i(144, 202)]
const FINAL_DELETED_LATE := [["CASINO", Vector2i(146, 189)], ["NIGHTCLUB", Vector2i(153, 187)], ["NIGHTCLUB", Vector2i(141, 213)]]
## Last hand changes of Las Vegas (kind, top-left cell of the lot on the final map): buildings taken
## away after the swaps above, casinos that become the police station (model of the main one, facing
## north), casinos that get one of the new neon signs (cell, ModelCatalog.Cat name), and the casino
## that gets the word CASINO of the casino towers (cell; the sign is made to fit its wall, FINAL_SIGN_FIT).
const FINAL2_DELETED := [["SKYSCRAPER", Vector2i(137, 167)], ["SKYSCRAPER", Vector2i(143, 169)],
	["SKYSCRAPER", Vector2i(128, 199)], ["SKYSCRAPER", Vector2i(132, 171)],
	["NIGHTCLUB", Vector2i(131, 213)], ["SKYSCRAPER", Vector2i(143, 174)], ["SKYSCRAPER", Vector2i(146, 174)]]
const FINAL2_TO_POLICE := [Vector2i(118, 198), Vector2i(122, 203), Vector2i(147, 181), Vector2i(137, 178),
	Vector2i(131, 158), Vector2i(148, 202)]
## Neon signs on the roof of a building (top-left cell, ModelCatalog.Cat name, wall it looks at: 1 east,
## 2 south); the police station of (118, 198) gets the girl of the casino at (131, 202), looking south.
const FINAL2_NEW_SIGNS := [[Vector2i(131, 194), "NEON_CLUB", 2], [Vector2i(131, 202), "NEON_GIRL", 1],
	[Vector2i(144, 202), "NEON_LOVE", 2], [Vector2i(128, 202), "NEON_LOVE", 1], [Vector2i(118, 198), "NEON_GIRL", 2]]
## Casinos turned by hand (top-left cell, facing 0 N, 1 E, 2 S, 3 W).
const FINAL2_TURNED := [[Vector2i(128, 202), 1]]
## More signs on a wall (cell, Cat name, mount) and the two casinos that exchange places (everything that
## belongs to the building but its lot: facing, seed, size factor, signs).
const FINAL2_WALL_SIGNS := [[Vector2i(131, 202), "NEON_CLUB", "face"]]
const FINAL2_EXCHANGED := [Vector2i(144, 202), Vector2i(127, 185)]
const FINAL2_CASINO_WORD := Vector2i(122, 186)
const FINAL2_SIGN_FIT := {"fill": 1.0, "shift": 0.0}
## Light stripes of the Taiwan signs (tw_led_band wraps the south-east corner, tw_led_board stands on the
## roof) added to casinos of Las Vegas: top-left cell of the lot, ModelCatalog.Cat name, mount.
const FINAL2_LEDS := [
	[Vector2i(122, 186), "TW_LED_BAND", "corner"], [Vector2i(131, 194), "TW_LED_BAND", "corner"],
	[Vector2i(144, 202), "TW_LED_BAND", "corner"], [Vector2i(122, 182), "TW_LED_BOARD", "roof"],
	[Vector2i(131, 194), "TW_LED_BOARD", "roof"],
]
## Skyscrapers added in the middle of downtown, on the lots of the two towers taken away (split in two
## rows) and on free ground: lot, facing (0 N, 2 S). Each is drawn with one of the Kenney skyscrapers
## (FINAL2_TOWER_MODELS), turn by turn, when its lot is free.
const FINAL2_NEW_TOWERS := [
	[Rect2i(137, 167, 5, 2), 0], [Rect2i(137, 169, 5, 2), 2], [Rect2i(143, 169, 4, 2), 0], [Rect2i(143, 171, 4, 2), 2],
	[Rect2i(155, 162, 4, 3), 2], [Rect2i(163, 172, 3, 2), 2], [Rect2i(130, 155, 4, 3), 2], [Rect2i(126, 158, 5, 3), 2],
]
const FINAL2_TOWER_MODELS := ["building-skyscraper-a.glb", "building-skyscraper-d.glb", "building-skyscraper-b.glb",
	"building-skyscraper-e.glb", "building-skyscraper-c.glb"]
## Burger King (cell): size factor.
const FINAL2_RESIZED := [["BURGER_KING", Vector2i(198, 295), 1.12]]
## The oil tank (top-left cell of its lot on the final map, model) that gets a line of more tanks to the east.
const TANK_LINE_FROM := Vector2i(131, 241)
const TANK_LINE_MODEL := "port_tanks.glb: tank_oil"
const TANK_LINE_COUNT := 4
const EIFFEL_MOVE_APART := 8.0
## Its new lot (the model is 6 x 6 cells at its scale) and the small buildings that may make room for it.
const EIFFEL_LOT := Vector2i(6, 6)
const EIFFEL_CLEARABLE := ["OFFICE", "SHOP", "NIGHTCLUB", "RESTAURANT", "CAFE", "PIZZA_SHOP", "BURGER_SHOP",
		"APARTMENT", "HOUSE", "GARDEN", "PLAZA"]
## The pizzeria on the commercial ground that goes to another lot (top-left cell on the final map),
## and how far at least (cells).
const PIZZERIA_AT := Vector2i(198, 212)
const PIZZERIA_MOVE_APART := 12.0
## Two police stations and a casino of Las Vegas are not what they were: they become neon halls (the
## back of the police station with its band as a neon, procedural meshes "neon_hall*" in different light
## colours, ServiceMeshes.NEON_HALLS), turned north, the ribbon being part of the mesh. Top-left cell
## of the lot, model. The first keeps the size the police station had (3.84 / 1.81 of its lot), the
## others are drawn as big as their lot lets (NEON_HALL_FILL of the lot).
const NEON_HALL_AT := Vector2i(148, 202)
const NEON_HALL_SCALE := 2.1215
const NEON_HALL_PLACES := [[Vector2i(148, 202), "neon_hall"], [Vector2i(122, 203), "neon_hall_pink"],
	[Vector2i(144, 202), "neon_hall_tall_gold"],
	[Vector2i(130, 185), "neon_hall_purple"], [Vector2i(147, 181), "neon_hall_red"],
	[Vector2i(117, 203), "neon_hall_gold"], [Vector2i(118, 207), "neon_hall_pink"],
	[Vector2i(122, 182), "neon_hall_tall_pink"], [Vector2i(123, 191), "neon_hall"],
	[Vector2i(130, 191), "neon_hall_tall_gold"]]
## Neon signs on two of the halls (about 15 % of the 11 places each): the two signs of the casino at
## NEON_HALL_SIGN_SOURCE (the girl on the roof and the club on the wall) go to the first place, the XXX
## sign on the south wall to the second.
const NEON_HALL_SIGN_SOURCE := Vector2i(131, 202)
const NEON_HALL_SIGNS_AT := Vector2i(147, 181)
const NEON_HALL_XXX_AT := Vector2i(130, 185)
const NEON_HALL_FILL := 0.96
## Free ground of Las Vegas (ENTERTAINMENT zone, no road, no building) gets more neon halls (5 x 3, drawn
## like the others, models in turn), shops of the catalog (the 2nd low poly shop with the orange awning,
## 3 x 2 at the scale of the development island) and little parks (trees on 3 x 3 or 2 x 2 spots).
const VEGAS_FILL_HALLS := 11
const VEGAS_FILL_SHOPS := 15
const VEGAS_FILL_PARKS := 6
const VEGAS_HALL_MODELS := ["neon_hall", "neon_hall_pink", "neon_hall_purple", "neon_hall_red", "neon_hall_gold",
	"neon_hall_tall_gold", "neon_hall_tall_pink"]
const VEGAS_SHOP_MODEL := "business.glb: shop"
## The "Welcome to Las Vegas" sign stands in the desert beside the highway that enters Las Vegas
## (north side of its three lanes), turned west to face the traffic coming from the desert.
const VEGAS_SIGN_LOT := Rect2i(116, 161, 1, 3)
const VEGAS_SIGN_FACING := 3

## A balloon floats over the mountain nearest to this cell of the first map (and over the
## stadium and the north-east corner of the central park).
const BALLOON_MOUNTAIN := Vector2i(177, 101)


## Applies every entry; returns how many were applied.
static func apply(data: CityData) -> int:
	var applied := 0
	resolved.clear()
	var used := {}
	for n in EDITS.size():
		var e: Dictionary = EDITS[n]
		var id := _nearest(data, e["kind"], MapLayout.scaled(e["near"]), used)
		if id < 0:
			push_warning("[Edits] no %s for the edit near %s: skipped" % [e["kind"], e["near"]])
			continue
		used[id] = true
		resolved[n] = id
		var r := data.building_rect(id)
		var lot := r
		if e.has("shift"):
			lot.position += MapLayout.scaled(e["shift"])
		if e.has("size"):
			lot.size = Vector2i(e["size"][0], e["size"][1])
		if lot != r and not _lot_is_free(data, id, lot):
			# Not enough room for the wanted lot: what fits inside the old one, where it was.
			lot = Rect2i(r.position, Vector2i(mini(lot.size.x, r.size.x), mini(lot.size.y, r.size.y)))
		if lot != r:
			_move_ground(data, r, lot, e.get("old_ground", ""))
			data.set_building_rect(id, lot)
		if e.has("facing"):
			data.b_facing[id] = e["facing"]
		if e.has("scale"):
			data.b_scale[id] = e["scale"]
		if e.has("scale_abs"):
			data.b_scale[id] = -float(e["scale_abs"])
		if e.has("clear_quay"):
			_clear_quay(data, lot, int(e["clear_quay"]))
		if e.has("model"):
			data.b_model[id] = e["model"]
		if e.get("lay", false):
			data.b_lay[id] = 1
		if e.has("sign"):
			data.b_sign[id] = ModelCatalog.Cat[e["sign"]]
		if e.has("replace"):
			data.b_kind[id] = CityTypes.Kind[e["replace"]]
		if e.get("delete", false):
			data.b_kind[id] = CityTypes.Kind.EMPTY
		if e.get("park", false):
			for y in range(lot.position.y, lot.end.y):
				for x in range(lot.position.x, lot.end.x):
					data.zone[data.idx(x, y)] = CityTypes.Zone.PARK
		applied += 1
	return applied


## Building numbers the entries changed and that must stay (BuildingBudget does not clear them).
static func kept() -> Dictionary:
	var out := {}
	for n in resolved:
		if not EDITS[n].get("delete", false):
			out[resolved[n]] = true
	return out


## The building of `kind_name` nearest to `at` that is not in `used`, or -1.
static func _nearest(data: CityData, kind_name: String, at: Vector2i, used: Dictionary = {}) -> int:
	var kind: int = CityTypes.Kind[kind_name]
	var best := -1
	var best_d := INF
	for b in data.building_count():
		if data.b_kind[b] != kind or used.has(b):
			continue
		var d := Vector2(data.building_rect(b).position).distance_to(Vector2(at))
		if d < best_d:
			best_d = d
			best = b
	return best


## True when `lot` is dry land and no other (not cleared) building stands on it.
static func _lot_is_free(data: CityData, id: int, lot: Rect2i) -> bool:
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if not data.in_bounds(x, y) or data.terrain[data.idx(x, y)] != CityTypes.Terrain.LAND \
					or data.road[data.idx(x, y)] != 0:
				return false
	for b in data.building_count():
		if b != id and data.b_kind[b] != CityTypes.Kind.EMPTY and data.building_rect(b).intersects(lot):
			return false
	return true


## The ground follows the lot: the new cells get the zone of the building, the cells it
## leaves go back to `old_ground` (when given).
static func _move_ground(data: CityData, old: Rect2i, lot: Rect2i, old_ground: String) -> void:
	var zone := data.zone[data.idx(old.position.x, old.position.y)]
	if old_ground != "":
		for y in range(old.position.y, old.end.y):
			for x in range(old.position.x, old.end.x):
				if not lot.has_point(Vector2i(x, y)):
					data.zone[data.idx(x, y)] = CityTypes.Zone[old_ground]
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			data.zone[data.idx(x, y)] = zone


## Quay ground (the land colour reaching the sea) within `radius` cells of `lot` becomes sand.
static func _clear_quay(data: CityData, lot: Rect2i, radius: int) -> void:
	for y in range(lot.position.y - radius, lot.end.y + radius):
		for x in range(lot.position.x - radius, lot.end.x + radius):
			if data.in_bounds(x, y) and data.rocky[data.idx(x, y)] == 2:
				data.rocky[data.idx(x, y)] = 0


# --- After the props ----------------------------------------------------------------------------
## What only exists once the props are placed: the kinds taken away and the balloons
## (added at the end of the building list).
static func apply_late(data: CityData) -> void:
	for kind_name in DELETED_KINDS:
		var kind: int = CityTypes.Kind[kind_name]
		for b in data.building_count():
			if data.b_kind[b] == kind:
				data.b_kind[b] = CityTypes.Kind.EMPTY
	for c in _balloon_cells(data):
		data.add_building(Rect2i(c - Vector2i(1, 1), Vector2i(3, 3)), CityTypes.Kind.BALLOON, 2, 1, 0.5)


## Over the stadium, over the north-east corner of the central park, over a mountain.
static func _balloon_cells(data: CityData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stadium := _nearest(data, "STADIUM", Vector2i(data.size / 2, data.size / 2))
	if stadium >= 0:
		out.append(data.building_rect(stadium).get_center())
	# The central park is the biggest group of park cells: its corner is taken on the rows
	# and columns that hold the most of them.
	var lo := Vector2i(data.size, data.size)
	var hi := Vector2i(-1, -1)
	var middle := Vector2i(data.size / 2, data.size / 2)
	var reach := data.size / 4
	for y in range(middle.y - reach, middle.y + reach):
		for x in range(middle.x - reach, middle.x + reach):
			if data.zone_at(x, y) == CityTypes.Zone.PARK and data.road[data.idx(x, y)] == 0:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x >= 0:
		out.append(Vector2i(hi.x - 1, lo.y + 1))
	var mountain := _nearest(data, "MOUNTAIN", MapLayout.scaled(BALLOON_MOUNTAIN))
	if mountain >= 0:
		out.append(data.building_rect(mountain).get_center())
	return out


# --- The secret base and the motorhome trade places ----------------------------------------------
## Free room kept round the base lot: its fence (3 cells) and the tanks outside the gates.
const BASE_MARGIN := 7


## The secret base moves to the clearest spot of the desert (where the motorhome used to
## stand; VehicleSites now puts the motorhome in the south of the desert). Run after `apply`,
## before the props (the tanks of the gates and the fence follow the base). False when no
## spot of the desert has room for the base.
static func swap_base(data: CityData) -> bool:
	var base := _nearest(data, "AIRBASE", Vector2i(data.size / 2, data.size / 2))
	if base < 0:
		return false
	var old := data.building_rect(base)
	for c in VehicleSites.desert_spots(data, base):
		var lot := Rect2i(c - old.size / 2, old.size)
		if not _lot_is_free(data, base, lot.grow(BASE_MARGIN)) or not _all_desert(data, lot.grow(BASE_MARGIN)):
			continue
		var zone := data.zone[data.idx(old.position.x, old.position.y)]
		for y in range(old.position.y, old.end.y):
			for x in range(old.position.x, old.end.x):
				data.zone[data.idx(x, y)] = CityTypes.Zone.DESERT
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				data.zone[data.idx(x, y)] = zone
		data.set_building_rect(base, lot)
		return true
	push_warning("[Edits] no room in the desert for the secret base: it stays where it is")
	return false


static func _all_desert(data: CityData, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if data.zone[data.idx(x, y)] != CityTypes.Zone.DESERT:
				return false
	return true


## Deletes the buildings of DELETED_AT, resizes those of RESIZED_AT (run after the urban island is rebuilt).
## Returns how many were found.
static func delete_by_hand(data: CityData) -> int:
	var found := 0
	hand_deleted.clear()
	for b in data.building_count():
		var at := data.building_rect(b).position
		for d in DELETED_AT:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and at == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
				found += 1
		for d in RESIZED_AT:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and at == d[1]:
				data.b_scale[b] = d[2]
				found += 1
	return found


## Last hand changes, once the buildings are final: houses that face west turn east, the
## cleared lots of FARM_BUILDINGS_AT get a farm building back, and no tree grows in the front
## yard of the main fire station. Returns how many houses turned.
static func finish(data: CityData) -> int:
	var turned := 0
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.HOUSE and data.b_facing[b] == 3:
			data.b_facing[b] = 1
			turned += 1
		for f in FARM_BUILDINGS_AT:
			if data.b_kind[b] == CityTypes.Kind.EMPTY and data.building_rect(b).position == f[0]:
				data.b_kind[b] = CityTypes.Kind.OUTPOST
				data.b_model[b] = f[1]
				data.b_facing[b] = 2
	for b in data.building_count():
		for t in TURNED_AT:
			if data.b_kind[b] == CityTypes.Kind[t[0]] and data.building_rect(b).position == t[1]:
				data.b_facing[b] = t[2]
	# Every burger joint becomes a McDonald's.
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.BURGER_JOINT:
			data.b_kind[b] = CityTypes.Kind.MCDONALDS
	for b in data.building_count():
		for d in DELETED_LATE:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and data.building_rect(b).position == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
	for b in data.building_count():
		for m in MODEL_AT:
			if data.b_kind[b] == CityTypes.Kind[m[0]] and data.building_rect(b).position == m[1]:
				data.b_model[b] = m[2]
	_move_by_hand(data)
	_pave_hospital_yard(data)
	_clear_highway_stub(data)
	_add_oil_pumps(data)
	_cinema_shops(data)
	# The main police station: its front yard is paved like its lot (its patrol car parks there).
	var hq := _nearest(data, "POLICE_HQ", Vector2i(data.size / 2, data.size / 2))
	if hq >= 0:
		for c in front_yard(data, hq, 1):
			data.zone[data.idx(c.x, c.y)] = CityTypes.Zone.CIVIC
			data.forest[data.idx(c.x, c.y)] = 0
	var fs := _nearest(data, "FIRE_STATION", MAIN_FIRE_STATION)
	if fs >= 0:
		# No forest grows on the ground in front of it (across the road too).
		for c in front_yard(data, fs, FIRE_YARD_DEPTH, 1):
			data.forest[data.idx(c.x, c.y)] = 0
	return turned


## The ground in front of the main hospital of PAVED_HOSPITAL is civic ground, without trees.
static func _pave_hospital_yard(data: CityData) -> void:
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.MAIN_HOSPITAL and data.building_rect(b).position == PAVED_HOSPITAL:
			for c in front_yard(data, b, PAVED_DEPTH, 1):
				data.zone[data.idx(c.x, c.y)] = CityTypes.Zone.CIVIC
				data.forest[data.idx(c.x, c.y)] = 0


## The road stub at the north-west end of the east highway becomes grass.
static func _clear_highway_stub(data: CityData) -> void:
	for y in range(HIGHWAY_STUB.position.y, HIGHWAY_STUB.end.y):
		for x in range(HIGHWAY_STUB.position.x, HIGHWAY_STUB.end.x):
			if data.in_bounds(x, y):
				data.road[data.idx(x, y)] = 0
				data.zone[data.idx(x, y)] = CityTypes.Zone.NATURE


## The pump of OIL_FIELD moves to the first of OIL_PUMP_SPOTS, the EXTRA_OIL_PUMPS others stand on
## the rest, each on free desert (a spot with no room is shifted a few cells).
static func _add_oil_pumps(data: CityData) -> void:
	var pump := _nearest(data, "OIL_PUMP", OIL_FIELD)
	if pump < 0:
		return
	var size := data.building_rect(pump).size
	var placed := 0
	for k in OIL_PUMP_SPOTS.size():
		var lot := _free_desert_lot(data, pump, OIL_PUMP_SPOTS[k], size)
		if lot.size.x == 0:
			push_warning("[Edits] no room for the oil pump near %s" % OIL_PUMP_SPOTS[k])
			continue
		if k == 0:
			_move_ground(data, data.building_rect(pump), lot, "DESERT")
			data.set_building_rect(pump, lot)
		else:
			for y in range(lot.position.y, lot.end.y):
				for x in range(lot.position.x, lot.end.x):
					data.zone[data.idx(x, y)] = CityTypes.Zone.DESERT
			data.add_building(lot, CityTypes.Kind.OIL_PUMP, 2, data.b_seed[pump] + k, 0.5)
		placed += 1
	if placed < OIL_PUMP_SPOTS.size():
		push_warning("[Edits] only %d of %d oil pumps placed" % [placed, OIL_PUMP_SPOTS.size()])


## The free lot of `size` nearest to `want` (within a few cells), all desert ground; the empty
## rectangle when there is none. `skip` is the building that is moved (it does not block).
static func _free_desert_lot(data: CityData, skip: int, want: Vector2i, size: Vector2i) -> Rect2i:
	for ring in 6:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var lot := Rect2i(want + Vector2i(dx, dy), size)
				if _lot_is_free(data, skip, lot) and _all_desert(data, lot):
					return lot
	return Rect2i()


## Moves the buildings of MOVED_AT.
static func _move_by_hand(data: CityData) -> void:
	for m in MOVED_AT:
		var b := -1
		for i in data.building_count():
			if data.b_kind[i] == CityTypes.Kind[m[0]] and data.building_rect(i).position == m[1]:
				b = i
		if b < 0:
			push_warning("[Edits] no %s at %s to move" % [m[0], m[1]])
			continue
		_move_ground(data, data.building_rect(b), m[2], "")
		data.set_building_rect(b, m[2])
		data.b_facing[b] = m[3]


## The main cinema stood alone in the middle of its big square lot: the lot shrinks to the
## middle half (the model keeps its size: the edit draws it at 0.9 of the smaller lot) and
## small shops stand in the corners of the square, facing outwards.
static func _cinema_shops(data: CityData) -> void:
	var cinema := _nearest(data, "CINEMA_MAIN", Vector2i(data.size / 2, data.size / 2))
	if cinema < 0:
		return
	var r := data.building_rect(cinema)
	if r.size.x < 6 or r.size.y < 6:
		return
	var inner := Rect2i(r.position + r.size / 4, r.size / 2)
	data.set_building_rect(cinema, inner)
	var s := CINEMA_SHOP_SIZE
	var corners := [[r.position, 0], [Vector2i(r.end.x - s.x, r.position.y), 0],
			[Vector2i(r.position.x, r.end.y - s.y), 2], [r.end - s, 2]]
	for k in mini(CINEMA_SHOPS, corners.size()):
		var lot := Rect2i(corners[k][0], s)
		if not _lot_is_free(data, -1, lot):
			continue
		var c := lot.get_center()
		var b := data.add_building(lot, CityTypes.Kind.SHOP, corners[k][1], CityTypes.hash2(c.x, c.y, 717), 0.3)
		data.b_scale[b] = 0.8


## Free cells (no road) up to `depth` cells in front of building `b`, `widen` cells wider than
## the lot on each side.
static func front_yard(data: CityData, b: int, depth: int, widen: int = 0) -> Array[Vector2i]:
	var r := data.building_rect(b)
	var o := CityTypes.FACING_OFFSETS[data.b_facing[b]]
	var out: Array[Vector2i] = []
	for y in range(r.position.y - depth, r.end.y + depth):
		for x in range(r.position.x - depth, r.end.x + depth):
			var c := Vector2i(x, y)
			if r.has_point(c) or not data.in_bounds(x, y) or data.road[data.idx(x, y)] != 0:
				continue
			# On the front side: beyond the lot that way, level with it the other way.
			var ahead := (o.x > 0 and x >= r.end.x) or (o.x < 0 and x < r.position.x) 					or (o.y > 0 and y >= r.end.y) or (o.y < 0 and y < r.position.y)
			var level := (o.x != 0 and y >= r.position.y - widen and y < r.end.y + widen) 					or (o.y != 0 and x >= r.position.x - widen and x < r.end.x + widen)
			if ahead and level:
				out.append(c)
	return out


# --- The bunker beside the secret base -------------------------------------------------------------
## The bunker moves just outside the fence of the secret base (east side first, then north),
## its front turned away from the base. Run after swap_base, before the props.
static func move_bunker(data: CityData) -> bool:
	var base := _nearest(data, "AIRBASE", Vector2i(data.size / 2, data.size / 2))
	var bunker := _nearest(data, "BUNKER", Vector2i(data.size / 2, data.size / 2))
	if base < 0 or bunker < 0:
		return false
	var ring: Rect2i = AmenitiesPlanner.base_fence(data.building_rect(base))["rect"]
	var old := data.building_rect(bunker)
	var c := ring.get_center()
	var tries := [
		[Rect2i(ring.end.x + 1, c.y - old.size.y / 2, old.size.x, old.size.y), 1],
		[Rect2i(c.x - old.size.x / 2, ring.position.y - old.size.y - 1, old.size.x, old.size.y), 0],
		[Rect2i(ring.end.x + 1, ring.position.y, old.size.x, old.size.y), 1],
	]
	for t in tries:
		var lot: Rect2i = t[0]
		if not _lot_is_free(data, bunker, lot.grow(1)):
			continue
		var outside := data.zone_at(old.position.x - 1, old.position.y)
		_move_ground(data, old, lot, CityTypes.Zone.keys()[outside])
		data.set_building_rect(bunker, lot)
		data.b_facing[bunker] = t[1]
		return true
	push_warning("[Edits] no room for the bunker beside the secret base")
	return false


## Last hand changes, run at the very end of the generation: deletes FINAL_DELETED, resizes
## FINAL_RESIZED, adds the shops of FINAL_SHOPS on free ground of the cinema square, builds the casino.
static func final_tweaks(data: CityData) -> void:
	for b in data.building_count():
		var at := data.building_rect(b).position
		for d in FINAL_DELETED:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and at == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
		for d in FINAL_RESIZED:
			if data.b_kind[b] == CityTypes.Kind[d[0]] and at == d[1]:
				data.b_scale[b] = d[2]
	for f in FINAL_SHOPS:
		var lot := Rect2i(f[0], Vector2i(2, 2))
		if not _lot_is_free(data, -1, lot):
			push_warning("[Edits] no room for the shop at %s" % lot)
			continue
		var c := lot.get_center()
		var b := data.add_building(lot, CityTypes.Kind.SHOP, f[1], CityTypes.hash2(c.x, c.y, 717), 0.3)
		data.b_model[b] = FINAL_SHOP_MODEL
		data.b_scale[b] = FINAL_SHOP_SCALE
	_delete_club_towers(data)
	_casino_square(data)
	_casino_fill(data)
	_eiffel_tower(data)
	_casinos_to_vegas_model(data)
	_move_vegas_sign(data)
	_move_pizzeria(data)
	_bt_tower_to_radio_tower(data)
	_real_dishes(data)
	_tank_line(data)
	_downtown_and_vegas_swaps(data)
	_vegas_second_pass(data)
	_neon_hall(data)
	_vegas_fill(data)


## The row of casino towers on the square of Las Vegas (CASINO2_LOTS).
static func _casino_square(data: CityData) -> void:
	var old: Array[int] = []
	for d in CASINO2_OLD:
		for b in data.building_count():
			if data.b_kind[b] == CityTypes.Kind[d[0]] and data.building_rect(b).position == d[1] and not old.has(b):
				old.append(b)
				break
	if old.size() < CASINO2_OLD.size():
		push_warning("[Edits] the square of Las Vegas has %d of its %d buildings: no casino towers there" % [old.size(), CASINO2_OLD.size()])
		return
	var towers: Array[int] = []
	for k in CASINO2_LOTS.size():
		if k < old.size():
			data.set_building_rect(old[k], CASINO2_LOTS[k])
			towers.append(old[k])
		else:
			towers.append(data.add_building(CASINO2_LOTS[k], CityTypes.Kind.CASINO, 1, data.b_seed[old[0]], data.b_height[old[0]]))
	for b: int in towers:
		data.b_kind[b] = CityTypes.Kind.CASINO
		data.b_facing[b] = 1
		data.b_scale[b] = 1.0
		data.b_model[b] = CASINO_MODEL
		data.b_sign[b] = 0
		data.b_more_signs.erase(b)
	data.b_sign[towers[0]] = ModelCatalog.Cat.NEON_CASINO
	data.b_sign_facing[towers[0]] = 1
	var side := data.add_building(CASINO2_SIDE, CityTypes.Kind.CASINO, 2, data.b_seed[old[0]], data.b_height[old[0]])
	data.b_scale[side] = 1.0
	data.b_model[side] = VEGAS_CASINO_MODEL


## The offices on big lots of the Las Vegas zone become casinos of the vegas_casino model.
static func _casino_fill(data: CityData) -> void:
	var n := 0
	for b in data.building_count():
		var r := data.building_rect(b)
		if data.b_kind[b] != CityTypes.Kind.OFFICE or r.size.x < 3 or r.size.y < 3 or data.b_model.has(b):
			continue
		var c := r.get_center()
		if data.in_bounds(c.x, c.y) and data.zone[data.idx(c.x, c.y)] == CityTypes.Zone.ENTERTAINMENT:
			data.b_kind[b] = CityTypes.Kind.CASINO
			data.b_model[b] = VEGAS_CASINO_MODEL
			n += 1
	print("[Edits] offices of Las Vegas turned into casinos: ", n)


## The Eiffel tower takes the casino that stands in EIFFEL_BLOCK, then moves to the free ground of
## the Las Vegas zone nearest to it (EIFFEL_MOVE_APART or more cells away); the old block becomes park.
static func _eiffel_tower(data: CityData) -> void:
	var casino := -1
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		if not r.intersects(EIFFEL_BLOCK):
			continue
		if data.b_kind[b] == CityTypes.Kind.CASINO and casino < 0 and EIFFEL_BLOCK.encloses(r):
			casino = b
		else:
			push_warning("[Edits] the block of the Eiffel tower holds another building at %s" % r)
			return
	if casino < 0:
		push_warning("[Edits] no casino in the block of the Eiffel tower at %s" % EIFFEL_BLOCK)
		return
	var lot := _free_vegas_lot(data, casino, EIFFEL_LOT, EIFFEL_BLOCK)
	if lot.size.x == 0:
		push_warning("[Edits] no free ground in Las Vegas for the Eiffel tower: it stays at %s" % EIFFEL_BLOCK)
		lot = EIFFEL_BLOCK
	else:
		for b in data.building_count():
			if b != casino and data.b_kind[b] != CityTypes.Kind.EMPTY and data.building_rect(b).intersects(lot):
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				data.forest[data.idx(x, y)] = 0
		for y in range(EIFFEL_BLOCK.position.y, EIFFEL_BLOCK.end.y):
			for x in range(EIFFEL_BLOCK.position.x, EIFFEL_BLOCK.end.x):
				data.zone[data.idx(x, y)] = CityTypes.Zone.PARK
	print("[Edits] Eiffel tower at ", lot)
	data.set_building_rect(casino, lot)
	data.b_facing[casino] = 2
	data.b_model[casino] = EIFFEL_MODEL
	data.b_scale[casino] = -EIFFEL_SCALE
	data.b_sign[casino] = 0
	data.b_more_signs.erase(casino)


## The rectangle of `size` of the Las Vegas ground nearest to the middle of `from` and at least
## EIFFEL_MOVE_APART cells from it, on dry ground with no road and none of the buildings that must
## stay (only the small ones of EIFFEL_CLEARABLE may be in the way: fewest first, then nearest);
## the empty rectangle when there is none. `skip` is the building that moves.
static func _free_vegas_lot(data: CityData, skip: int, size: Vector2i, from: Rect2i) -> Rect2i:
	var owner := PackedInt32Array()
	owner.resize(data.size * data.size)
	owner.fill(-1)
	for b in data.building_count():
		if b != skip and data.b_kind[b] != CityTypes.Kind.EMPTY:
			var r := data.building_rect(b)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if data.in_bounds(x, y):
						owner[data.idx(x, y)] = b
	var centre := Vector2(from.get_center())
	var best := Rect2i()
	var best_score := INF
	for y in range(from.position.y - 40, from.position.y + 40):
		for x in range(from.position.x - 40, from.position.x + 40):
			var lot := Rect2i(x, y, size.x, size.y)
			var d := Vector2(lot.get_center()).distance_to(centre)
			if d < EIFFEL_MOVE_APART:
				continue
			var in_the_way := _vegas_ground(data, lot, owner)
			if in_the_way < 0:
				continue
			var score := float(in_the_way) * 100.0 + d
			if score < best_score:
				best = lot
				best_score = score
	return best


## How many clearable buildings stand on `lot`, or -1 when it is not dry ground without road, with
## its middle on Las Vegas ground, or holds a building that must stay.
static func _vegas_ground(data: CityData, lot: Rect2i, owner: PackedInt32Array) -> int:
	var found := {}
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if not data.in_bounds(x, y):
				return -1
			var i := data.idx(x, y)
			if data.terrain[i] != CityTypes.Terrain.LAND or data.road[i] != 0:
				return -1
			if owner[i] >= 0:
				var b := owner[i]
				if not EIFFEL_CLEARABLE.has(CityTypes.Kind.keys()[data.b_kind[b]]) or data.b_model.has(b) 						or data.b_sign[b] != 0 or data.b_more_signs.has(b):
					return -1
				found[b] = true
	var c := lot.get_center()
	if data.zone[data.idx(c.x, c.y)] != CityTypes.Zone.ENTERTAINMENT:
		return -1
	return found.size()


## Every Las Vegas club drawn as the club tower is taken away (not those with a sign or a model of
## their own: the signed clubs are the ones MapRetouch dressed).
static func _delete_club_towers(data: CityData) -> void:
	var n := 0
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.NIGHTCLUB or data.b_model.has(b) or data.b_sign[b] != 0 				or data.b_more_signs.has(b):
			continue
		if BuildingPlacer.club_model_name(data, b) == "club_tower":
			data.b_kind[b] = CityTypes.Kind.EMPTY
			hand_deleted[b] = true
			n += 1
	print("[Edits] club towers taken away: ", n)


## Every casino drawn with the old procedural model takes the model of the Las Vegas casino.
static func _casinos_to_vegas_model(data: CityData) -> void:
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.CASINO and not data.b_model.has(b):
			data.b_model[b] = VEGAS_CASINO_MODEL


## The pizzeria of PIZZERIA_AT goes to the nearest cleared lot of the commercial ground that is at
## least PIZZERIA_MOVE_APART cells away and big enough (2 x 3, either way).
static func _move_pizzeria(data: CityData) -> void:
	var pizza := -1
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.PIZZA_SHOP and data.building_rect(b).position == PIZZERIA_AT:
			pizza = b
	if pizza < 0:
		push_warning("[Edits] no pizzeria at %s to move" % PIZZERIA_AT)
		return
	var from := Vector2(data.building_rect(pizza).get_center())
	var best := -1
	var best_d := INF
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.EMPTY or hand_deleted.has(b):
			continue
		var r := data.building_rect(b)
		if mini(r.size.x, r.size.y) < 2 or maxi(r.size.x, r.size.y) < 3 or data.zone_at(r.position.x, r.position.y) != CityTypes.Zone.COMMERCIAL:
			continue
		var d := Vector2(r.get_center()).distance_to(from)
		if d >= PIZZERIA_MOVE_APART and d < best_d and _lot_is_free(data, b, r):
			best = b
			best_d = d
	if best < 0:
		push_warning("[Edits] no free lot for the pizzeria: it stays at %s" % PIZZERIA_AT)
		return
	print("[Edits] pizzeria moved to ", data.building_rect(best))
	data.b_kind[best] = CityTypes.Kind.PIZZA_SHOP
	data.b_seed[best] = data.b_seed[pizza]
	data.b_height[best] = data.b_height[pizza]
	data.b_scale[best] = data.b_scale[pizza]
	data.b_kind[pizza] = CityTypes.Kind.EMPTY
	hand_deleted[pizza] = true


## The dishes of REAL_DISHES and REAL_DISHES_2 are drawn with the realistic dish models.
static func _real_dishes(data: CityData) -> void:
	var n := 0
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.SAT_DISH:
			continue
		var at := data.building_rect(b).position
		if REAL_DISHES.has(at):
			data.b_model[b] = REAL_DISH_MODEL
			n += 1
		elif REAL_DISHES_2.has(at):
			data.b_model[b] = REAL_DISH_MODEL_2
			n += 1
	if n < REAL_DISHES.size() + REAL_DISHES_2.size():
		push_warning("[Edits] only %d of the %d realistic dishes found" % [n, REAL_DISHES.size() + REAL_DISHES_2.size()])


## Last hand changes of Las Vegas and downtown (after the casino towers and their side casino exist):
## FINAL_TALLER skyscrapers get taller, FINAL_TO_GLASS casinos become the glass tower, FINAL_TO_CASINO
## clubs become casinos of the Vegas model, FINAL_DELETED_LATE buildings are taken away.
static func _downtown_and_vegas_swaps(data: CityData) -> void:
	for b in data.building_count():
		var at := data.building_rect(b).position
		var kind: String = CityTypes.Kind.keys()[data.b_kind[b]]
		for t in FINAL_TALLER:
			if kind == t[0] and at == t[1]:
				data.b_stretch[b] = t[2]
		for c in FINAL_TO_GLASS:
			if kind == "CASINO" and at == c:
				data.b_kind[b] = CityTypes.Kind.SKYSCRAPER
				data.b_model[b] = GLASS_MODEL
				data.b_scale[b] = 1.0
				data.b_sign[b] = 0
				data.b_more_signs.erase(b)
		for c in FINAL_TO_CASINO:
			if kind == "NIGHTCLUB" and at == c:
				data.b_kind[b] = CityTypes.Kind.CASINO
				data.b_model[b] = VEGAS_CASINO_MODEL
				data.b_scale[b] = 1.0
				data.b_sign[b] = 0
				data.b_more_signs.erase(b)
		for d in FINAL_DELETED_LATE:
			if kind == d[0] and at == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true


## FINAL2_*: buildings taken away, casinos become police stations facing north, two casinos get a
## new neon sign, the casino of FINAL2_CASINO_WORD gets the word CASINO of the casino towers.
static func _vegas_second_pass(data: CityData) -> void:
	var word := -1
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.CASINO and data.b_sign[b] == ModelCatalog.Cat.NEON_CASINO:
			word = b
	for b in data.building_count():
		var at := data.building_rect(b).position
		var kind: String = CityTypes.Kind.keys()[data.b_kind[b]]
		for d in FINAL2_DELETED:
			if kind == d[0] and at == d[1]:
				data.b_kind[b] = CityTypes.Kind.EMPTY
				hand_deleted[b] = true
		for d in FINAL2_RESIZED:
			if kind == d[0] and at == d[1]:
				data.b_scale[b] = d[2]
		if kind != "CASINO":
			continue
		if FINAL2_TO_POLICE.has(at):
			data.b_kind[b] = CityTypes.Kind.POLICE
			data.b_facing[b] = 0
			data.b_scale[b] = 1.0
			data.b_model.erase(b)
			data.b_sign[b] = 0
			data.b_more_signs.erase(b)
		for t in FINAL2_TURNED:
			if at == t[0]:
				data.b_facing[b] = t[1]
		for s in FINAL2_NEW_SIGNS:
			if at == s[0]:
				data.b_sign[b] = ModelCatalog.Cat[s[1]]
				data.b_sign_facing[b] = s[2]
				data.b_more_signs.erase(b)
				data.b_sign_fit.erase(b)
				if s[2] == 1:
					# A roof sign looks south unless it is turned: the east one stands on the east edge.
					data.b_sign_fit[b] = {"yaw": PI * 0.5}
		if at == FINAL2_CASINO_WORD:
			if word < 0:
				push_warning("[Edits] no casino tower carries the word CASINO")
				continue
			data.b_sign[b] = ModelCatalog.Cat.NEON_CASINO
			data.b_sign_facing[b] = data.b_facing[b]
			data.b_sign_fit[b] = FINAL2_SIGN_FIT
			data.b_more_signs.erase(b)
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.CASINO:
			continue
		for l in FINAL2_LEDS:
			if data.building_rect(b).position == l[0]:
				var more: Array = data.b_more_signs.get(b, [])
				more.append([ModelCatalog.Cat[l[1]], l[2]])
				data.b_more_signs[b] = more
				if data.b_sign[b] == 0:
					data.b_sign_facing[b] = 2
		for w in FINAL2_WALL_SIGNS:
			if data.building_rect(b).position == w[0]:
				var wall: Array = data.b_more_signs.get(b, [])
				wall.append([ModelCatalog.Cat[w[1]], w[2]])
				data.b_more_signs[b] = wall
	_exchange_casinos(data)
	_downtown_towers(data)


## Skyscrapers of FINAL2_NEW_TOWERS on their free lots.
static func _downtown_towers(data: CityData) -> void:
	var n := 0
	for t in FINAL2_NEW_TOWERS:
		var lot: Rect2i = t[0]
		if not _lot_is_free(data, -1, lot):
			continue
		var b := data.add_building(lot, CityTypes.Kind.SKYSCRAPER, t[1], 7919 * (n + 3) + lot.position.x * 31 + lot.position.y, 0.8)
		data.b_model[b] = FINAL2_TOWER_MODELS[n % FINAL2_TOWER_MODELS.size()]
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				data.zone[data.idx(x, y)] = CityTypes.Zone.DOWNTOWN
		n += 1
	print("[Edits] skyscrapers added to downtown: ", n)


## Free rectangles of `size` (either way round) on the free cells of `free` (a set of cell index -> true),
## taken greedily row by row and not overlapping: [[Rect2i, turned]].
static func _free_rects(data: CityData, free: Dictionary, size: Vector2i) -> Array:
	var used := {}
	var out := []
	for y in range(data.size):
		for x in range(data.size):
			if not free.has(data.idx(x, y)):
				continue
			for turned in [false, true]:
				var sz := Vector2i(size.y, size.x) if turned else size
				var r := Rect2i(x, y, sz.x, sz.y)
				var ok := true
				for yy in range(r.position.y, r.end.y):
					for xx in range(r.position.x, r.end.x):
						if not data.in_bounds(xx, yy):
							ok = false
						else:
							var i := data.idx(xx, yy)
							if not free.has(i) or used.has(i):
								ok = false
				if ok:
					for yy in range(r.position.y, r.end.y):
						for xx in range(r.position.x, r.end.x):
							used[data.idx(xx, yy)] = true
					out.append([r, turned])
					break
	return out


## `count` of `list`, spread evenly over it.
static func _spread(list: Array, count: int) -> Array:
	var out := []
	if list.is_empty():
		return out
	count = mini(count, list.size())
	for k in count:
		out.append(list[k * list.size() / count])
	return out


## FINAL VEGAS_FILL_*: neon halls, then shops, then little parks on the free ground of Las Vegas.
static func _vegas_fill(data: CityData) -> void:
	# Grass under the Eiffel tower.
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.EMPTY and data.b_model.get(b, "") == EIFFEL_MODEL:
			var lot := data.building_rect(b)
			for y in range(lot.position.y, lot.end.y):
				for x in range(lot.position.x, lot.end.x):
					data.zone[data.idx(x, y)] = CityTypes.Zone.PARK
	var free := {}
	for y in range(data.size):
		for x in range(data.size):
			var i := data.idx(x, y)
			if data.zone[i] == CityTypes.Zone.ENTERTAINMENT and data.terrain[i] == CityTypes.Terrain.LAND and data.road[i] == 0:
				free[i] = true
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.in_bounds(x, y):
					free.erase(data.idx(x, y))
	var halls := 0
	for h in _spread(_free_rects(data, free, Vector2i(5, 3)), VEGAS_FILL_HALLS):
		var lot: Rect2i = h[0]
		var facing := 1 if h[1] else 0
		var b := data.add_building(lot, CityTypes.Kind.POLICE, facing, CityTypes.hash2(lot.position.x, lot.position.y, 919), 0.3)
		data.b_model[b] = VEGAS_HALL_MODELS[halls % VEGAS_HALL_MODELS.size()]
		var along := Vector2(lot.size.y, lot.size.x) if h[1] else Vector2(lot.size.x, lot.size.y)
		data.b_scale[b] = -minf(along.x * NEON_HALL_FILL / 1.76, along.y * NEON_HALL_FILL / 1.31)
		data.b_sign_facing[b] = 2
		halls += 1
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				free.erase(data.idx(x, y))
	var shops := 0
	for h in _spread(_free_rects(data, free, Vector2i(3, 2)), VEGAS_FILL_SHOPS):
		var lot: Rect2i = h[0]
		var facing := 1 if h[1] else 0
		var b := data.add_building(lot, CityTypes.Kind.SHOP, facing, CityTypes.hash2(lot.position.x, lot.position.y, 929), 0.3)
		data.b_model[b] = VEGAS_SHOP_MODEL
		shops += 1
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				free.erase(data.idx(x, y))
	var parks := 0
	var spots := _free_rects(data, free, Vector2i(3, 3))
	spots.append_array(_free_rects(data, free, Vector2i(2, 2)))
	for h in _spread(spots, VEGAS_FILL_PARKS):
		var lot: Rect2i = h[0]
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				var i := data.idx(x, y)
				data.zone[i] = CityTypes.Zone.PARK
				data.forest[i] = 200
		parks += 1
	print("[Edits] Las Vegas: %d neon halls, %d shops, %d parks added" % [halls, shops, parks])


## The two casinos of FINAL2_EXCHANGED trade everything but their lots: facing, seed, height, size
## factors, model, signs (so each building stands where the other one was, turned the way it was).
static func _exchange_casinos(data: CityData) -> void:
	var a := -1
	var c := -1
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.CASINO:
			continue
		var at := data.building_rect(b).position
		if at == FINAL2_EXCHANGED[0]:
			a = b
		elif at == FINAL2_EXCHANGED[1]:
			c = b
	if a < 0 or c < 0:
		push_warning("[Edits] the casinos to exchange were not found (%d, %d)" % [a, c])
		return
	var t_facing := data.b_facing[a]; data.b_facing[a] = data.b_facing[c]; data.b_facing[c] = t_facing
	var t_seed := data.b_seed[a]; data.b_seed[a] = data.b_seed[c]; data.b_seed[c] = t_seed
	var t_height := data.b_height[a]; data.b_height[a] = data.b_height[c]; data.b_height[c] = t_height
	var t_scale := data.b_scale[a]; data.b_scale[a] = data.b_scale[c]; data.b_scale[c] = t_scale
	var t_stretch := data.b_stretch[a]; data.b_stretch[a] = data.b_stretch[c]; data.b_stretch[c] = t_stretch
	var t_sign := data.b_sign[a]; data.b_sign[a] = data.b_sign[c]; data.b_sign[c] = t_sign
	var t_sf := data.b_sign_facing[a]; data.b_sign_facing[a] = data.b_sign_facing[c]; data.b_sign_facing[c] = t_sf
	for d: Dictionary in [data.b_model, data.b_more_signs, data.b_sign_fit]:
		var has_a := d.has(a)
		var has_c := d.has(c)
		var va = d.get(a)
		var vc = d.get(c)
		d.erase(a)
		d.erase(c)
		if has_c:
			d[a] = vc
		if has_a:
			d[c] = va


## The oil tank of TANK_LINE_FROM is copied to make a line of TANK_LINE_COUNT more towards the east
## (each one on the free lot next to the last).
static func _tank_line(data: CityData) -> void:
	var src := -1
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.INDUSTRIAL and data.building_rect(b).position == TANK_LINE_FROM 				and data.b_model.get(b, "") == TANK_LINE_MODEL:
			src = b
	if src < 0:
		push_warning("[Edits] no tank at %s for the line of tanks" % TANK_LINE_FROM)
		return
	var r := data.building_rect(src)
	var placed := 0
	for k in range(1, TANK_LINE_COUNT + 1):
		var lot := Rect2i(r.position + Vector2i(r.size.x * k, 0), r.size)
		if not _lot_is_free(data, src, lot):
			push_warning("[Edits] no room for the tank of the line at %s" % lot)
			break
		var b := data.add_building(lot, CityTypes.Kind.INDUSTRIAL, data.b_facing[src], data.b_seed[src], data.b_height[src])
		data.b_model[b] = TANK_LINE_MODEL
		data.b_scale[b] = data.b_scale[src]
		for y in range(lot.position.y, lot.end.y):
			for x in range(lot.position.x, lot.end.x):
				data.zone[data.idx(x, y)] = data.zone[data.idx(r.position.x, r.position.y)]
		placed += 1
	print("[Edits] tanks added to the line: ", placed)


## The BT tower becomes the radio tower model (the one of PortRework), at the same size, with a green light.
static func _bt_tower_to_radio_tower(data: CityData) -> void:
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.BT_TOWER:
			data.b_model[b] = PortRework.RADIO_TOWER
			data.b_scale[b] = PortRework.RADIO_TOWER_SCALE


## The Las Vegas sign moves from the middle of the city to the desert road (VEGAS_SIGN_LOT).
static func _move_vegas_sign(data: CityData) -> void:
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.VEGAS_SIGN:
			continue
		if not _lot_is_free(data, b, VEGAS_SIGN_LOT):
			push_warning("[Edits] no room for the Las Vegas sign at %s" % VEGAS_SIGN_LOT)
			return
		data.set_building_rect(b, VEGAS_SIGN_LOT)
		data.b_facing[b] = VEGAS_SIGN_FACING
		return


## The buildings of NEON_HALL_PLACES (police stations and casinos) become neon halls.
static func _neon_hall(data: CityData) -> void:
	var half := Vector2(1.76, 1.31)
	var src := {}
	for b in data.building_count():
		if data.building_rect(b).position == NEON_HALL_SIGN_SOURCE and data.b_kind[b] != CityTypes.Kind.EMPTY:
			src = {"sign": data.b_sign[b], "facing": data.b_sign_facing[b],
					"more": data.b_more_signs.get(b, []).duplicate(true), "fit": data.b_sign_fit.get(b, {}).duplicate()}
	if src.is_empty() or (src["sign"] == 0 and src["more"].is_empty()):
		push_warning("[Edits] no neon signs on the casino at %s to copy" % NEON_HALL_SIGN_SOURCE)
	for place: Array in NEON_HALL_PLACES:
		var cell: Vector2i = place[0]
		var found := false
		for b in data.building_count():
			var r := data.building_rect(b)
			if r.position != cell or not [CityTypes.Kind.POLICE, CityTypes.Kind.CASINO].has(data.b_kind[b]):
				continue
			found = true
			data.b_facing[b] = 0
			data.b_model[b] = place[1]
			if cell == NEON_HALL_AT:
				data.b_scale[b] = -NEON_HALL_SCALE
			else:
				data.b_scale[b] = -minf(r.size.x * NEON_HALL_FILL / half.x, r.size.y * NEON_HALL_FILL / half.y)
			data.b_sign[b] = 0
			data.b_more_signs.erase(b)
			data.b_sign_fit.erase(b)
			if cell == NEON_HALL_SIGNS_AT and not src.is_empty():
				data.b_sign[b] = src["sign"]
				data.b_sign_facing[b] = src["facing"]
				if not src["more"].is_empty():
					data.b_more_signs[b] = src["more"]
				if not src["fit"].is_empty():
					data.b_sign_fit[b] = src["fit"]
			elif cell == NEON_HALL_XXX_AT:
				data.b_sign_facing[b] = 2
				data.b_more_signs[b] = [[ModelCatalog.Cat.NEON_XXX, "face"]]
			break
		if not found:
			push_warning("[Edits] no building at %s for the neon hall" % cell)
