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
}

const SERVICE_KINDS: Array[int] = [
	Kind.HOSPITAL, Kind.SCHOOL, Kind.FIRE_STATION, Kind.POLICE,
	Kind.CITY_HALL, Kind.STADIUM, Kind.FOUNTAIN, Kind.BANK, Kind.CHURCH,
	Kind.CASINO, Kind.FERRIS_WHEEL, Kind.DRIVE_IN, Kind.LIGHTHOUSE,
	Kind.TELECOM_TOWER, Kind.SAT_DISH, Kind.MESA, Kind.POND,
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
