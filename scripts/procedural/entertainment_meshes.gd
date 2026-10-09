class_name EntertainmentMeshes
extends RefCounted
## The little Las Vegas: casino palace, neon clubs, ferris wheel and the drive-in
## cinema. Neon parts use the unshaded surface of MeshKit so they glow without
## any post effect. All meshes face +Z and are centred on their lot.

const GOLD := Color("e8b33a")
const PURPLE := Color("5a3482")
const MAGENTA := Color("8e3a9a")
const NIGHT := Color("2f2540")
const PINK := Color("ff4fd8")
const CYAN := Color("4ff0ff")
const YELLOW := Color("ffe14f")
const RED := Color("ff3355")
const GREEN := Color("5bff7a")
const WHITE := Color("f4f2f8")
const WINDOW := Color("3d4566")
const ASPHALT := Color("4c4f5e")
const STEEL := Color("c9c6d6")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("casino", casino())
	lib.add_named("club_a", club(PINK, YELLOW, 0.8))
	lib.add_named("club_b", club(GREEN, CYAN, 1.2))
	lib.add_named("ferris_wheel", ferris_wheel())
	lib.add_named("drive_in", drive_in())


# --- Casino palace (3x3): purple tiers, golden dome, giant playing cards -------------
static func casino() -> ArrayMesh:
	var k := MeshKit.new()
	var base := Vector3(-1.35, 0, -1.2)
	var base_size := Vector3(2.7, 0.6, 2.2)
	k.box(base, base_size, PURPLE, NIGHT)
	k.windows(base, base_size, 2, 7, Color("c78bff"))
	var top := Vector3(-0.9, 0.6, -0.9)
	var top_size := Vector3(1.8, 0.7, 1.5)
	k.box(top, top_size, MAGENTA, NIGHT)
	k.windows(top, top_size, 2, 5, YELLOW)
	# Golden stepped dome with a spire.
	var dome := Vector3(0, 1.3, -0.15)
	for i in 4:
		var r := 0.55 * cos(i * 0.4)
		var r2 := 0.55 * cos((i + 1) * 0.4)
		k.cylinder(dome + Vector3(0, i * 0.13, 0), r, r2, 0.13, 14, GOLD)
	k.cylinder(dome + Vector3(0, 0.52, 0), 0.05, 0.0, 0.3, 6, GOLD)
	# Gold canopy over the entrance.
	k.box(Vector3(-0.6, 0.35, 1.0), Vector3(1.2, 0.06, 0.35), GOLD)
	k.neon(true)
	# Neon outlines of both tiers.
	_outline(k, base, base_size, PINK)
	_outline(k, top, top_size, CYAN)
	# Two giant playing cards leaning on the front.
	for side in [-1.0, 1.0]:
		k.xform = Transform3D(Basis(Vector3.UP, side * 0.25), Vector3(side * 0.85, 0.7, 1.02))
		k.box(Vector3(-0.28, 0, 0), Vector3(0.56, 0.75, 0.03), WHITE)
		k.box(Vector3(-0.22, 0.08, 0.031), Vector3(0.44, 0.59, 0.01), RED)
	k.xform = Transform3D.IDENTITY
	k.neon(false)
	return k.commit()


## Neon tubes along the top edges of a box.
static func _outline(k: MeshKit, min_c: Vector3, size: Vector3, color: Color) -> void:
	var t := 0.04
	var y := min_c.y + size.y - t
	k.box(Vector3(min_c.x, y, min_c.z + size.z), Vector3(size.x, t, t), color)
	k.box(Vector3(min_c.x, y, min_c.z - t), Vector3(size.x, t, t), color)
	k.box(Vector3(min_c.x - t, y, min_c.z), Vector3(t, t, size.z), color)
	k.box(Vector3(min_c.x + size.x, y, min_c.z), Vector3(t, t, size.z), color)


# --- Neon club (2x2) -------------------------------------------------------------------------
static func club(tube: Color, sign_color: Color, height: float) -> ArrayMesh:
	var k := MeshKit.new()
	var body := Vector3(-0.8, 0, -0.8)
	var body_size := Vector3(1.6, height, 1.4)
	k.box(body, body_size, NIGHT, Color("231b30"))
	k.windows(body, body_size, int(height / 0.4), 4, Color("6b4f8f"), 1)
	k.box(Vector3(-0.3, 0, 0.6), Vector3(0.6, 0.3, 0.05), Color("15101e"))
	k.neon(true)
	_outline(k, body, body_size, tube)
	# Sign board above the door with stripes, and a vertical blade sign.
	k.box(Vector3(-0.6, height * 0.55, 0.61), Vector3(1.2, 0.3, 0.03), sign_color)
	for i in 3:
		k.box(Vector3(-0.5 + i * 0.38, height * 0.55 + 0.08, 0.645), Vector3(0.25, 0.14, 0.01), tube)
	k.box(Vector3(0.62, height * 0.3, 0.45), Vector3(0.06, height * 0.9, 0.2), sign_color)
	k.box(Vector3(-0.8, 0.0, 0.6), Vector3(1.6, 0.04, 0.03), tube)
	k.neon(false)
	return k.commit()


# --- Ferris wheel (2x2), wheel in the XY plane facing the street -------------------------------
static func ferris_wheel() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.9, 0, -0.5), Vector3(1.8, 0.03, 1.0), Color("8f86a6"))
	var hub := Vector3(0, 1.45, 0)
	var radius := 1.1
	var segs := 16
	# A-frame legs on both sides of the wheel, joined at the hub.
	for z in [-0.18, 0.18]:
		for side in [-1.0, 1.0]:
			k.xform = Transform3D(Basis(Vector3.BACK, side * 0.38), hub + Vector3(0, 0, z))
			k.box(Vector3(-0.04, -1.58, -0.03), Vector3(0.08, 1.58, 0.06), STEEL)
	k.xform = Transform3D.IDENTITY
	k.cylinder(hub - Vector3(0, 0.05, 0.2), 0.08, 0.08, 0.1, 8, STEEL)
	for i in segs:
		var a := TAU * i / segs
		var p := hub + Vector3(cos(a), sin(a), 0) * radius
		# Spoke and rim segment.
		k.xform = Transform3D(Basis(Vector3.BACK, a), hub)
		k.box(Vector3(0, -0.015, -0.015), Vector3(radius, 0.03, 0.03), STEEL)
		var chord := 2.0 * radius * sin(PI / segs)
		k.xform = Transform3D(Basis(Vector3.BACK, a + PI * 0.5 + PI / segs), p)
		k.box(Vector3(0, -0.025, -0.025), Vector3(chord, 0.05, 0.05), WHITE)
		k.xform = Transform3D.IDENTITY
		# Gondola hanging under the rim point.
		var colors := [RED, CYAN, YELLOW, GREEN]
		k.block(p - Vector3(0, 0.2, 0), Vector3(0.14, 0.14, 0.14), Color(colors[i % 4]).darkened(0.2))
	k.neon(true)
	for i in segs:
		var a := TAU * (i + 0.5) / segs
		k.block(hub + Vector3(cos(a), sin(a), 0) * radius * 1.02 + Vector3(0, -0.02, 0.03),
				Vector3(0.05, 0.05, 0.02), PINK)
	k.neon(false)
	return k.commit()


# --- Drive-in cinema (4x3): big screen, parking rows of cars facing it ---------------------------
static func drive_in() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.95, 0, -1.45), Vector3(3.9, 0.02, 2.9), ASPHALT)
	# Screen on two legs at the back.
	for x in [-1.0, 1.0]:
		k.box(Vector3(x - 0.05, 0, -1.35), Vector3(0.1, 0.5, 0.1), STEEL)
	k.box(Vector3(-1.45, 0.45, -1.4), Vector3(2.9, 1.2, 0.08), WHITE)
	k.neon(true)
	k.box(Vector3(-1.35, 0.55, -1.315), Vector3(2.7, 1.0, 0.01), Color("2c3e66"))
	k.box(Vector3(-1.0, 0.75, -1.3), Vector3(2.0, 0.55, 0.01), Color("6fa8dc"))
	k.box(Vector3(1.5, 0.02, 1.2), Vector3(0.4, 0.35, 0.06), YELLOW)
	k.neon(false)
	# Rows of cars, all turned towards the screen.
	var car_colors := [Color("d9474f"), Color("4569b8"), Color("f1eff6"), Color("e8b33a"), Color("5c9d4c")]
	for row in 3:
		for i in 7:
			var h := CityTypes.hash2(row, i, 77)
			if h % 5 == 0:
				continue # empty spot
			var c: Color = car_colors[h % car_colors.size()]
			var p := Vector3(-1.5 + i * 0.5, 0.02, -0.4 + row * 0.6)
			k.block(p, Vector3(0.2, 0.08, 0.34), c)
			k.block(p + Vector3(0, 0.08, 0.03), Vector3(0.16, 0.06, 0.16), c.darkened(0.25))
	return k.commit()
