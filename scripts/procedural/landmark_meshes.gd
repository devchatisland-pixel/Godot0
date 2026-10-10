class_name LandmarkMeshes
extends RefCounted
## Stadium (fallback) and its floodlights, park fountain and lake, the lit
## helipad of the main hospital and the generic meshes
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
	lib.add_named("stadium", stadium())
	lib.add_named("fountain", fountain())
	lib.add_named("pond", pond())
	lib.add_named("box", unit_box())
	lib.add_named("lamp_bulb", lamp_bulb())
	lib.add_named("tree", fallback_tree())
	lib.add_named("stadium_lights", stadium_lights())
	lib.add_named("helipad_h", helipad_h())
	lib.add_named("bt_tower", bt_tower())


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


## Four floodlight masts at the corners of a 1x1 square (scaled to the plot).
static func stadium_lights() -> ArrayMesh:
	var k := MeshKit.new()
	for x in [-0.47, 0.47]:
		for z in [-0.47, 0.47]:
			k.block(Vector3(x, 0, z), Vector3(0.012, 1.0, 0.012), CONCRETE)
			k.block(Vector3(x, 1.0, z), Vector3(0.05, 0.05, 0.03), Color("5a5d6e"))
	k.glow(true)
	for x in [-0.47, 0.47]:
		for z in [-0.47, 0.47]:
			k.block(Vector3(x - signf(x) * 0.012, 1.005, z - signf(z) * 0.012), Vector3(0.045, 0.04, 0.035), Color.WHITE)
	k.glow(false)
	return k.commit()


## Red neon H in a ring of lights, laid on the roof of the main hospital.
static func helipad_h() -> ArrayMesh:
	var k := MeshKit.new()
	var red := Color("ff2a3a")
	k.disc(Vector3(0, 0.0, 0), Vector2(0.5, 0.5), 20, Color("f4f2f8"))
	k.neon(true)
	k.box(Vector3(-0.22, 0.005, -0.25), Vector3(0.1, 0.01, 0.5), red)
	k.box(Vector3(0.12, 0.005, -0.25), Vector3(0.1, 0.01, 0.5), red)
	k.box(Vector3(-0.12, 0.005, -0.05), Vector3(0.24, 0.01, 0.1), red)
	k.neon(false)
	k.glow(true)
	for i in 10:
		var a := TAU * i / 10.0
		k.block(Vector3(cos(a) * 0.47, 0.0, sin(a) * 0.47), Vector3(0.05, 0.03, 0.05), Color.WHITE)
	k.glow(false)
	return k.commit()


## The BT tower: a tall concrete shaft on a plinth, two tiers of white aerial horns, a glass
## cabin whose windows light up at night, and a mast with a red light (about 12 cells high).
static func bt_tower() -> ArrayMesh:
	var k := MeshKit.new()
	var concrete := Color("d6d2c8")
	k.box(Vector3(-0.75, 0, -0.75), Vector3(1.5, 0.25, 1.5), Color("9d9a92"), Color("b9b6ad"))
	k.cylinder(Vector3(0, 0.25, 0), 0.5, 0.36, 7.4, 16, concrete, concrete)
	# Lower platform with a ring of white aerial horns.
	k.cylinder(Vector3(0, 7.6, 0), 0.62, 0.62, 0.18, 16, Color("a8a59d"), Color("c9c6bd"))
	for i in 10:
		var a := TAU * i / 10.0
		k.block(Vector3(cos(a) * 0.68, 7.95, sin(a) * 0.68), Vector3(0.2, 0.2, 0.3), WHITE)
	# Upper tier: a second, smaller ring.
	k.cylinder(Vector3(0, 8.3, 0), 0.5, 0.5, 0.14, 16, Color("a8a59d"), Color("c9c6bd"))
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		k.block(Vector3(cos(a) * 0.56, 8.62, sin(a) * 0.56), Vector3(0.16, 0.16, 0.24), WHITE)
	# Glass cabin with a ring of lit windows.
	k.cylinder(Vector3(0, 8.8, 0), 0.58, 0.58, 0.7, 18, Color("5d7391"), Color("8f929e"))
	k.glow(true)
	for i in 18:
		var a := TAU * i / 18.0
		k.block(Vector3(cos(a) * 0.59, 9.15, sin(a) * 0.59), Vector3(0.1, 0.18, 0.1), Color.WHITE)
	k.glow(false)
	# Roof, mast and the red light on top.
	k.cylinder(Vector3(0, 9.5, 0), 0.62, 0.45, 0.12, 18, Color("a8a59d"), Color("c9c6bd"))
	k.cylinder(Vector3(0, 9.62, 0), 0.07, 0.025, 2.6, 8, Color("8f929e"))
	k.neon(true)
	k.block(Vector3(0, 12.25, 0), Vector3(0.1, 0.1, 0.1), Color("ff2a3a"))
	k.neon(false)
	return k.commit()


static func fallback_tree() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, 0.04, 0.04, 0.2, 6, Color("8a5a3c"))
	k.cylinder(Vector3(0, 0.15, 0), 0.2, 0.0, 0.5, 8, Color("4f9a45"))
	return k.commit()
