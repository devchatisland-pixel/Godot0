class_name LandmarkMeshes
extends RefCounted
## Unique landmarks (city hall, stadium), park fountain and the generic meshes
## used for the far level of detail and as fallback when a kit is missing.

const STONE := Color("e6dcc6")
const WHITE := Color("f4f2f8")
const DOME := Color("6f9c9a")
const ROOF := Color("8d8aa3")
const WINDOW := Color("3d4566")
const CONCRETE := Color("bcbacb")
const SEAT_A := Color("4d6fc4")
const SEAT_B := Color("e3e1ec")
const GRASS := Color("6db552")
const LINE := Color("f4f4f4")
const WATER := Color("5fb7e0")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("city_hall", city_hall())
	lib.add_named("stadium", stadium())
	lib.add_named("fountain", fountain())
	lib.add_named("pond", pond())
	lib.add_named("box", unit_box())
	lib.add_named("lamp_bulb", lamp_bulb())
	lib.add_named("tree", fallback_tree())


# --- City hall: stairs, colonnade, pediment and a dome ------------------------------------
static func city_hall() -> ArrayMesh:
	var k := MeshKit.new()
	# Plaza and stairs.
	k.box(Vector3(-1.45, 0, -1.45), Vector3(2.9, 0.03, 2.9), Color("d8d3c4"))
	for i in 3:
		k.box(Vector3(-0.8 + i * 0.05, 0.03 + i * 0.05, 0.7 - i * 0.08), Vector3(1.6 - i * 0.1, 0.05, 0.35), STONE)
	var body := Vector3(-1.2, 0.03, -1.1)
	var body_size := Vector3(2.4, 0.9, 1.65)
	k.box(body, body_size, STONE, ROOF)
	k.windows(body, body_size, 2, 7, WINDOW)
	# Colonnade and pediment.
	for i in 6:
		k.block(Vector3(-0.62 + i * 0.25, 0.18, 0.72), Vector3(0.08, 0.7, 0.08), WHITE)
	k.box(Vector3(-0.75, 0.88, 0.55), Vector3(1.5, 0.08, 0.3), WHITE)
	k.gable(Vector3(-0.75, 0.96, 0.55), Vector3(1.5, 0.25, 0.3), WHITE, STONE)
	# Drum and stepped dome.
	var top := Vector3(0, 0.93, -0.3)
	k.cylinder(top, 0.5, 0.5, 0.35, 16, WHITE)
	for i in 4:
		var r := 0.48 * cos(i * 0.38)
		var r2 := 0.48 * cos((i + 1) * 0.38)
		k.cylinder(top + Vector3(0, 0.35 + i * 0.12, 0), r, r2, 0.12, 16, DOME)
	k.block(top + Vector3(0, 0.83, 0), Vector3(0.03, 0.3, 0.03), WHITE)
	k.box(top + Vector3(0.015, 1.0, 0), Vector3(0.2, 0.12, 0.01), Color("d9474f"))
	return k.commit()


# --- Stadium: oval stands, pitch and floodlights (5x4 cells) --------------------------------
static func stadium() -> ArrayMesh:
	var k := MeshKit.new()
	var c := Vector3(0, 0, 0)
	k.box(Vector3(-2.45, 0, -1.95), Vector3(4.9, 0.02, 3.9), CONCRETE)
	var seats: Array[Color] = [SEAT_A, SEAT_A, SEAT_B]
	k.elliptic_ring(c + Vector3(0, 0.02, 0), Vector2(1.45, 1.0), Vector2(2.3, 1.8), 0.08, 0.75, 40, seats, CONCRETE)
	# Roof rim.
	k.elliptic_ring(c + Vector3(0, 0.02, 0), Vector2(2.1, 1.62), Vector2(2.35, 1.85), 0.82, 0.86, 40, [WHITE] as Array[Color], WHITE)
	k.disc(c + Vector3(0, 0.03, 0), Vector2(1.46, 1.01), 40, Color("4e9a3f"))
	k.box(Vector3(-1.05, 0.032, -0.65), Vector3(2.1, 0.004, 1.3), GRASS)
	k.box(Vector3(-0.005, 0.037, -0.65), Vector3(0.01, 0.002, 1.3), LINE)
	k.disc(c + Vector3(0, 0.037, 0), Vector2(0.18, 0.18), 16, LINE)
	k.disc(c + Vector3(0, 0.038, 0), Vector2(0.16, 0.16), 16, GRASS)
	for x in [-1.05, 1.05]:
		k.box(Vector3(x - 0.005, 0.037, -0.65), Vector3(0.01, 0.002, 1.3), LINE)
	for z in [-0.655, 0.645]:
		k.box(Vector3(-1.05, 0.037, z), Vector3(2.1, 0.002, 0.01), LINE)
	# Four floodlight masts.
	for p in [Vector3(-2.0, 0, -1.5), Vector3(2.0, 0, -1.5), Vector3(-2.0, 0, 1.5), Vector3(2.0, 0, 1.5)]:
		k.block(p, Vector3(0.05, 1.4, 0.05), CONCRETE)
		k.block(p + Vector3(0, 1.4, 0), Vector3(0.22, 0.12, 0.08), WHITE)
	return k.commit()


# --- Park fountain (2x2) --------------------------------------------------------------------
static func fountain() -> ArrayMesh:
	var k := MeshKit.new()
	k.disc(Vector3(0, 0.01, 0), Vector2(0.95, 0.95), 24, Color("d8d3c4"))
	k.cylinder(Vector3(0, 0, 0), 0.6, 0.6, 0.1, 20, STONE)
	k.disc(Vector3(0, 0.09, 0), Vector2(0.54, 0.54), 20, WATER)
	k.cylinder(Vector3(0, 0, 0), 0.12, 0.08, 0.35, 10, STONE)
	k.cylinder(Vector3(0, 0.35, 0), 0.22, 0.22, 0.04, 12, STONE, WATER)
	k.cylinder(Vector3(0, 0.39, 0), 0.04, 0.0, 0.18, 8, WATER)
	return k.commit()


# --- Central park lake (6x4) with a fountain ---------------------------------------------
static func pond() -> ArrayMesh:
	var k := MeshKit.new()
	var rim: Array[Color] = [Color("d8d3c4")]
	k.elliptic_ring(Vector3(0, 0, 0), Vector2(2.6, 1.6), Vector2(2.85, 1.85), 0.06, 0.06, 32, rim, Color("bdb6a5"))
	k.disc(Vector3(0, 0.03, 0), Vector2(2.62, 1.62), 32, Color("4aa6d6"))
	k.disc(Vector3(0, 0.032, 0), Vector2(2.0, 1.1), 32, Color("5fb7e0"))
	k.cylinder(Vector3(0, 0, 0), 0.45, 0.45, 0.12, 16, STONE, WATER)
	k.cylinder(Vector3(0, 0.12, 0), 0.08, 0.06, 0.3, 8, STONE)
	k.cylinder(Vector3(0, 0.42, 0), 0.2, 0.2, 0.04, 12, STONE, WATER)
	k.neon(true)
	k.cylinder(Vector3(0, 0.46, 0), 0.05, 0.0, 0.35, 8, Color("cfeeff"))
	k.neon(false)
	return k.commit()


# --- Generic meshes -----------------------------------------------------------------------
## 1x1x1 box with its base at y = 0, used for far LOD buildings.
static func unit_box() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.5, 0, -0.5), Vector3.ONE, Color.WHITE, Color(0.82, 0.82, 0.86))
	return k.commit()


## Bulb under the head of a street light; it glows at night.
static func lamp_bulb() -> ArrayMesh:
	var k := MeshKit.new()
	k.glow(true)
	k.block(Vector3(0, -0.035, 0), Vector3(0.07, 0.035, 0.07), Color.WHITE)
	k.glow(false)
	return k.commit()


static func fallback_tree() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, 0.04, 0.04, 0.2, 6, Color("8a5a3c"))
	k.cylinder(Vector3(0, 0.15, 0), 0.2, 0.0, 0.5, 8, Color("4f9a45"))
	return k.commit()
