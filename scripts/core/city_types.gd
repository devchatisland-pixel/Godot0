class_name CityTypes
extends RefCounted
## Shared enums and small helpers used by generation and rendering.
## Grid convention: cell (x, y) covers world X in [x, x+1] and world Z in [y, y+1].

# --- Terrain -----------------------------------------------------------------
enum Terrain { DEEP, SHALLOW, BEACH, LAND }

# --- Zoning (one value per cell) --------------------------------------------
enum Zone {
	NONE,        # water / not buildable
	NATURE,      # fields and forests outside the city
	PARK,
	DOWNTOWN,    # skyscrapers and offices
	COMMERCIAL,  # shops and mid-rise
	APARTMENT,   # residential mid-rise
	SUBURBAN,    # detached houses
	INDUSTRIAL,
	CIVIC,       # land reserved by a public service
	DESERT,
	ENTERTAINMENT, # the little Las Vegas
	ISLET,       # small palm islands off the coast
	QUARTER,     # colourful low-rise town quarter
	PRISON,      # the Alcatraz-like prison island
	POOR,        # run-down district of panel blocks, behind downtown
	FARM,        # fields and farms of the countryside
	URBAN,       # the third island: massive urbanism, no trees
	SAND,        # wide beach strip around the mountain forest
}

# --- Road grid values ---------------------------------------------------------
const ROAD_NONE := 0
const ROAD_STREET := 1
const ROAD_AVENUE := 2
const ROAD_BRIDGE_FLAG := 4

# --- Building kinds -------------------------------------------------------------
enum Kind {
	SKYSCRAPER,
	OFFICE,
	SHOP,
	APARTMENT,
	HOUSE,
	INDUSTRIAL,
	INDUSTRIAL_YARD,  # tanks, containers and chimneys on a small lot
	HOSPITAL,
	SCHOOL,
	FIRE_STATION,
	POLICE,
	CITY_HALL,
	STADIUM,
	FOUNTAIN,
	PLAZA,            # empty paved inner lot (ground only, a tree maybe)
	GARDEN,           # empty green inner lot
	BANK,
	CHURCH,
	CASINO,
	NIGHTCLUB,
	FERRIS_WHEEL,
	DRIVE_IN,
	LIGHTHOUSE,
	TELECOM_TOWER,
	SAT_DISH,
	MESA,
	POND,             # central park lake with its fountain
	LANDMARK,         # famous towers downtown (variant = seed)
	SHOPPING_CENTER,
	CINEMA,
	OUTPOST,          # desert shacks, barns and trailers (variant = seed)
	QUARTER_BLDG,     # building of the colourful quarter
	UN_HQ,            # United Nations headquarters
	PRISON,           # cellhouse of the prison island
	HOTEL,            # grand hotels of the city centre (variant = seed)
	MUSEUM,
	POST_OFFICE,
	CEMETERY,
	BUNKER,           # military bunker in the desert
	AIRBASE,          # military landing strip with hangar and jets
	PHARMACY,
	GAS_STATION,
	CRANE,            # construction crane in the colourful quarter
	POLICE_HQ,        # main police station (small ones are POLICE)
	MAIN_HOSPITAL,    # main hospital (small clinics are HOSPITAL)
	MAIN_SCHOOL,      # main school with its sports ground (small ones are SCHOOL)
	MOUNTAIN,         # rocky peak of the northern mountains
	FIELD,            # crop field (variant = seed)
	POOR_BLDG,        # panel block or slab of the poor district
	RUSSIAN,          # the one big urban ghetto block
	PRISON_WING,      # stone block, warden's house or workshop of the prison island
	OIL_PUMP,         # pumpjack of the west desert
	STALL,            # ice cream and food stall on the beach
	FACTORY_BLDG,     # one of the 8 buildings of the industrial zone (variant = seed)
	MCDONALDS,
	BURGER_KING,
	URBAN_BLDG,       # tower of the urban island
	URBAN_CLUSTER,    # night skyline block of the urban island
	FUTURE_BLDG,      # futuristic tower of the urban island (night skyline pack)
	PIRATE_SHIP,
	GRAVE,            # pirate grave on the little islet
	NUCLEAR_PLANT,    # on the urban island
	CINEMA_MAIN,      # the big cinema (replaces the old city hall plot)
	AIRPORT,          # small airport of the urban island
	BURGER_JOINT,     # one cartoon burger restaurant per district
	COOLING_TOWER,    # cooling tower of the nuclear plant
	COOLING_HALL,     # long low hall beside the cooling towers
	BT_TOWER,         # the lone tower on its own islet
	WATCHTOWER,       # wooden lookout in the forests
	EMPTY,            # a building taken away by hand (ManualEdits): nothing is drawn, the id stays
	BEACH_HUT,        # hut or pavilion on a beach (BeachSites)
	PIER,             # wooden pier into the sea (BeachSites)
	BOAT,             # a boat at sea (BoatSites); the seed is the kind of boat
	FIRE_TRUCK,       # the forest fire truck (PropSites)
	BALLOON,          # hot air balloon floating in the air (PropSites)
	BILLBOARD,        # one per zone (PropSites)
	UFO,              # the flying saucer on the ground near the secret base
	TANK,             # tank at the gates of the secret base
	BUS_STOP,         # bus shelter beside a road (BusStops)
}

const SERVICE_KINDS: Array[int] = [
	Kind.HOSPITAL, Kind.SCHOOL, Kind.FIRE_STATION, Kind.POLICE,
	Kind.CITY_HALL, Kind.STADIUM, Kind.FOUNTAIN, Kind.BANK, Kind.CHURCH,
	Kind.CASINO, Kind.FERRIS_WHEEL, Kind.DRIVE_IN, Kind.LIGHTHOUSE,
	Kind.TELECOM_TOWER, Kind.SAT_DISH, Kind.MESA, Kind.POND,
	Kind.LANDMARK, Kind.SHOPPING_CENTER, Kind.CINEMA, Kind.OUTPOST,
	Kind.UN_HQ, Kind.PRISON, Kind.HOTEL, Kind.MUSEUM,
	Kind.POST_OFFICE, Kind.CEMETERY, Kind.BUNKER, Kind.AIRBASE, Kind.PHARMACY,
	Kind.GAS_STATION, Kind.CRANE, Kind.POLICE_HQ, Kind.MAIN_HOSPITAL, Kind.MAIN_SCHOOL,
	Kind.MOUNTAIN, Kind.FIELD, Kind.RUSSIAN, Kind.PRISON_WING, Kind.OIL_PUMP, Kind.STALL,
	Kind.FACTORY_BLDG, Kind.MCDONALDS, Kind.BURGER_KING, Kind.URBAN_CLUSTER,
	Kind.PIRATE_SHIP, Kind.GRAVE,
	Kind.NUCLEAR_PLANT, Kind.CINEMA_MAIN, Kind.AIRPORT, Kind.BURGER_JOINT,
	Kind.COOLING_TOWER, Kind.COOLING_HALL, Kind.BT_TOWER, Kind.WATCHTOWER, Kind.BEACH_HUT, Kind.PIER, Kind.BOAT, Kind.FIRE_TRUCK, Kind.BALLOON, Kind.BILLBOARD, Kind.UFO, Kind.TANK, Kind.BUS_STOP,
]

# --- Directions (facing / road connections) -------------------------------------
# Bit masks for road connections. N is -Z (grid y-1).
const DIR_N := 1
const DIR_E := 2
const DIR_S := 4
const DIR_W := 8

## Facing index 0..3 = N, E, S, W.
const FACING_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


## Yaw that turns a model whose front is +Z so that it faces `facing`.
static func facing_yaw(facing: int) -> float:
	var o := FACING_OFFSETS[facing]
	return atan2(float(o.x), float(o.y))


## Rotates a N/E/S/W bit mask by `yaw` radians around +Y.
static func rotate_mask(mask: int, yaw: float) -> int:
	var out := 0
	for i in 4:
		if mask & (1 << i) == 0:
			continue
		var o := FACING_OFFSETS[i]
		var v := Vector3(o.x, 0.0, o.y).rotated(Vector3.UP, yaw)
		out |= 1 << direction_index(Vector2i(roundi(v.x), roundi(v.z)))
	return out


static func direction_index(offset: Vector2i) -> int:
	for i in 4:
		if FACING_OFFSETS[i] == offset:
			return i
	return 0


static func is_service(kind: int) -> bool:
	return SERVICE_KINDS.has(kind)


## Cheap deterministic integer hash (thread-safe, no RNG state).
static func hash2(x: int, y: int, salt: int = 0) -> int:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


## Deterministic float in [0, 1).
static func hashf(x: int, y: int, salt: int = 0) -> float:
	return float(hash2(x, y, salt) & 0xffff) / 65536.0
