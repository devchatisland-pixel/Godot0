class_name NatureMeshes
extends RefCounted
## Desert and coast pieces: telecom tower, satellite dish, mesa, cactus,
## lighthouse and palm tree. Centred on their lot, base at y = 0.

const RED := Color("d23b2f")
const WHITE := Color("f4f2f8")
const CONCRETE := Color("c9c4b8")
const STEEL := Color("b9b6c6")
const ROCK_A := Color("c98a4b")
const ROCK_B := Color("b5703a")
const ROCK_TOP := Color("dfae6a")
const CACTUS := Color("4f9a45")
const TRUNK := Color("9a6b3f")
const PALM := Color("3f9c3a")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("telecom_tower", telecom_tower())
	lib.add_named("sat_dish", sat_dish())
	lib.add_named("mesa", mesa())
	lib.add_named("cactus", cactus())
	lib.add_named("lighthouse", lighthouse())
	lib.add_named("palm", palm())
	lib.add_named("mountain_a", mountain(0))
	lib.add_named("mountain_b", mountain(1))
	lib.add_named("mountain_c", mountain(2))
	lib.add_named("oil_pump", oil_pump())


# --- Telecom tower (2x2): red and white lattice with a beacon ---------------------------
static func telecom_tower() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.95, 0, -0.95), Vector3(1.9, 0.03, 1.9), CONCRETE)
	k.box(Vector3(0.35, 0.03, 0.35), Vector3(0.5, 0.3, 0.4), WHITE, STEEL)
	var levels := 9
	var level_h := 0.5
	for i in levels:
		var w0 := 0.8 * (1.0 - float(i) / (levels + 1))
		var w1 := 0.8 * (1.0 - float(i + 1) / (levels + 1))
		var y := i * level_h
		var c := RED if i % 2 == 0 else WHITE
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p := Vector3(corner.x * (w0 + w1) * 0.25, y, corner.y * (w0 + w1) * 0.25)
			k.block(p, Vector3(0.05, level_h, 0.05), c)
		# Horizontal frame at the top of the level.
		var h := w1 * 0.5
		k.box(Vector3(-h, y + level_h - 0.03, -h), Vector3(w1, 0.03, 0.03), c)
		k.box(Vector3(-h, y + level_h - 0.03, h - 0.03), Vector3(w1, 0.03, 0.03), c)
		k.box(Vector3(-h, y + level_h - 0.03, -h), Vector3(0.03, 0.03, w1), c)
		k.box(Vector3(h - 0.03, y + level_h - 0.03, -h), Vector3(0.03, 0.03, w1), c)
	var top := levels * level_h
	k.block(Vector3(0, top, 0), Vector3(0.04, 0.6, 0.04), WHITE)
	k.block(Vector3(0.12, top - 0.6, 0.0), Vector3(0.1, 0.25, 0.1), STEEL)
	k.neon(true)
	k.block(Vector3(0, top + 0.6, 0), Vector3(0.09, 0.09, 0.09), Color("ff3030"))
	k.neon(false)
	return k.commit()


# --- Satellite dish (2x2) ----------------------------------------------------------------
static func sat_dish() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.7, 0, -0.7), Vector3(1.4, 0.04, 1.4), CONCRETE)
	k.cylinder(Vector3(0, 0.04, 0), 0.18, 0.12, 0.45, 8, STEEL)
	# Dish tilted towards the sky, made of a wide cone and a feed arm.
	k.xform = Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(0, 0.55, 0))
	k.cylinder(Vector3(0, -0.05, 0), 0.12, 0.75, 0.28, 16, WHITE, Color("e2e0ea"))
	k.block(Vector3(0, 0.2, 0), Vector3(0.03, 0.55, 0.03), STEEL)
	k.block(Vector3(0, 0.75, 0), Vector3(0.1, 0.1, 0.1), STEEL)
	k.xform = Transform3D.IDENTITY
	return k.commit()


# --- Mesa (6x4): layered rock plateau -----------------------------------------------------
static func mesa() -> ArrayMesh:
	var k := MeshKit.new()
	var layers := [
		[1.0, 0.92, 0.45, ROCK_A], [0.86, 0.78, 0.4, ROCK_B], [0.72, 0.66, 0.35, ROCK_A],
	]
	var y := 0.0
	for l in layers:
		k.xform = Transform3D(Basis.from_scale(Vector3(2.8, 1.0, 1.8)), Vector3(0, y, 0))
		k.cylinder(Vector3.ZERO, l[0], l[1], l[2], 9, l[3], ROCK_TOP)
		y += l[2]
	k.xform = Transform3D(Basis.from_scale(Vector3(1.2, 1.0, 0.9)), Vector3(1.2, 0, 0.6))
	k.cylinder(Vector3.ZERO, 0.9, 0.6, 0.6, 7, ROCK_B, ROCK_TOP)
	k.xform = Transform3D.IDENTITY
	return k.commit()


static func cactus() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, 0.05, 0.045, 0.42, 6, CACTUS)
	k.cylinder(Vector3(0.09, 0.14, 0), 0.03, 0.03, 0.16, 6, CACTUS)
	k.box(Vector3(0.03, 0.13, -0.02), Vector3(0.08, 0.04, 0.04), CACTUS)
	k.cylinder(Vector3(-0.08, 0.2, 0), 0.03, 0.03, 0.12, 6, CACTUS)
	k.box(Vector3(-0.08, 0.19, -0.02), Vector3(0.06, 0.04, 0.04), CACTUS)
	return k.commit()


# --- Lighthouse (1x1): red and white tower on rocks ------------------------------------------
static func lighthouse() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, 0.45, 0.38, 0.12, 9, Color("8d8578"), Color("a39a8a"))
	var bands := 5
	var h := 0.32
	for i in bands:
		var r0 := 0.22 - i * 0.015
		var r1 := 0.22 - (i + 1) * 0.015
		k.cylinder(Vector3(0, 0.12 + i * h, 0), r0, r1, h, 12, RED if i % 2 == 0 else WHITE)
	var top := 0.12 + bands * h
	k.cylinder(Vector3(0, top, 0), 0.2, 0.2, 0.04, 12, Color("3d4566"))
	k.neon(true)
	k.cylinder(Vector3(0, top + 0.04, 0), 0.11, 0.11, 0.18, 10, Color("fff2a0"))
	k.neon(false)
	k.cylinder(Vector3(0, top + 0.22, 0), 0.15, 0.0, 0.16, 10, RED)
	return k.commit()


# --- Palm tree ---------------------------------------------------------------------------------
static func palm() -> ArrayMesh:
	var k := MeshKit.new()
	var p := Vector3.ZERO
	for i in 5:
		var next := p + Vector3(0.025 * i, 0.16, 0.0)
		k.cylinder(p, 0.04 - i * 0.004, 0.036 - i * 0.004, 0.17, 6, TRUNK)
		p = next
	for i in 7:
		var yaw := TAU * i / 7.0
		k.xform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -0.45), p)
		k.box(Vector3(0, -0.01, -0.05), Vector3(0.36, 0.02, 0.1), PALM.darkened(0.15 * (i % 2)))
	k.xform = Transform3D.IDENTITY
	k.cylinder(p - Vector3(0, 0.03, 0), 0.05, 0.03, 0.06, 6, Color("6b4a2a"))
	return k.commit()


# --- Mountains (6x6): faceted rocky peaks with pine forests on the slopes and snow caps ---------
const ROCK_GREY := Color("8f8a82")
const ROCK_DARK := Color("6e6a64")
const SNOW := Color("f4f6fa")
const PINE := Color("2f6b3a")
const PINE_LIGHT := Color("3f8a45")

## The peaks are drawn this much bigger than listed, so the range towers over the forest.
const PEAK_SCALE := 1.35
## Peaks: [x, z, base radius, height] per variant.
const PEAKS := [
	[[0.0, 0.0, 2.3, 5.2], [1.6, -1.0, 1.5, 3.4], [-1.7, 1.2, 1.4, 2.8]],
	[[-1.4, 0.0, 1.9, 3.6], [0.6, 0.0, 2.1, 4.6], [2.0, 0.8, 1.2, 2.2]],
	[[0.0, 0.2, 2.6, 6.2], [-1.8, -1.2, 1.3, 2.6], [1.3, 1.6, 1.2, 2.4]],
]


static func mountain(variant: int) -> ArrayMesh:
	var k := MeshKit.new()
	for p in PEAKS[variant]:
		var base := Vector3(p[0], 0.0, p[1]) * PEAK_SCALE
		var r: float = float(p[2]) * PEAK_SCALE
		var h: float = float(p[3]) * PEAK_SCALE
		# Three stacked cones with few sides: grey rock, darker band, snow on the tip.
		k.cylinder(base, r, r * 0.62, h * 0.38, 7, ROCK_DARK, ROCK_GREY)
		k.cylinder(base + Vector3(0, h * 0.38, 0), r * 0.62, r * 0.3, h * 0.34, 7, ROCK_GREY, ROCK_DARK)
		var tip := h * 0.72
		k.cylinder(base + Vector3(0, tip, 0), r * 0.3, 0.0, h - tip, 7, SNOW if h > 3.0 else ROCK_GREY)
		# Pine ring around the foot.
		for i in 9:
			var a: float = TAU * (float(i) + 0.4) / 9.0 + float(p[0])
			var q := base + Vector3(cos(a), 0, sin(a)) * (r * 0.92)
			_pine(k, q, (0.55 + 0.25 * float(i % 3)) * 1.2)
	return k.commit()


static func _pine(k: MeshKit, at: Vector3, s: float) -> void:
	k.cylinder(at, 0.05 * s, 0.05 * s, 0.18 * s, 5, TRUNK)
	k.cylinder(at + Vector3(0, 0.12 * s, 0), 0.26 * s, 0.0, 0.6 * s, 6, PINE)
	k.cylinder(at + Vector3(0, 0.38 * s, 0), 0.2 * s, 0.0, 0.5 * s, 6, PINE_LIGHT)


# --- Pumpjack (2x2): base, walking beam with horse head, counterweight, tank -------------------
static func oil_pump() -> ArrayMesh:
	var k := MeshKit.new()
	var steel := Color("3a3a40")
	var rust := Color("b5532e")
	k.box(Vector3(-0.7, 0, -0.5), Vector3(1.4, 0.04, 1.0), CONCRETE)
	# Samson post (A frame) and the walking beam on top.
	for z in [-0.12, 0.12]:
		k.xform = Transform3D(Basis(Vector3.BACK, 0.4), Vector3(-0.15, 0.04, z))
		k.box(Vector3(-0.025, 0, -0.02), Vector3(0.05, 0.62, 0.04), steel)
		k.xform = Transform3D(Basis(Vector3.BACK, -0.4), Vector3(-0.15, 0.04, z))
		k.box(Vector3(-0.025, 0, -0.02), Vector3(0.05, 0.62, 0.04), steel)
	k.xform = Transform3D(Basis(Vector3.BACK, 0.08), Vector3(-0.15, 0.62, 0))
	k.box(Vector3(-0.55, -0.04, -0.06), Vector3(1.1, 0.08, 0.12), rust)
	k.cylinder(Vector3(0.52, -0.34, 0), 0.2, 0.2, 0.06, 10, steel)
	k.box(Vector3(0.5, -0.3, -0.04), Vector3(0.04, 0.34, 0.08), steel)
	k.block(Vector3(-0.55, -0.16, 0), Vector3(0.16, 0.2, 0.16), steel)
	k.xform = Transform3D.IDENTITY
	# Counterweight and well head, storage tank.
	k.cylinder(Vector3(-0.62, 0.04, 0), 0.14, 0.14, 0.2, 10, steel)
	k.block(Vector3(0.45, 0.04, 0), Vector3(0.1, 0.25, 0.1), steel)
	k.cylinder(Vector3(0.45, 0.04, 0.38), 0.18, 0.18, 0.3, 10, Color("d8d3c4"), Color("8f8b80"))
	return k.commit()
