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
	lib.add_named("club_a", club(PINK, "neon_xxx", 0.8))
	lib.add_named("club_b", club(GREEN, "neon_bar", 1.2))
	lib.add_named("club_c", club(CYAN, "neon_club", 1.0))
	lib.add_named("club_tower", club_tower(MAGENTA, CYAN, "neon_club"))
	lib.add_named("club_tower_b", club_tower(Color("ff9a2f"), PINK, "neon_xxx"))
	lib.add_named("club_bar", small_bar())
	lib.add_named("chapel", chapel())
	lib.add_named("resort", resort())
	lib.add_named("ferris_wheel", ferris_wheel())
	lib.add_named("drive_in", drive_in())


# --- Casino palace (3x3): purple tiers, golden dome, neon sign ---------------------
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
	k.neon(false)
	# "CASINO" over the entrance.
	k.front_sign(0.0, 0.62, 0.62, 1.3, "neon_casino")
	return k.commit()


## Neon tubes along the top edges of a box.
static func _outline(k: MeshKit, min_c: Vector3, size: Vector3, color: Color) -> void:
	var t := 0.04
	var y := min_c.y + size.y - t
	k.box(Vector3(min_c.x, y, min_c.z + size.z), Vector3(size.x, t, t), color)
	k.box(Vector3(min_c.x, y, min_c.z - t), Vector3(size.x, t, t), color)
	k.box(Vector3(min_c.x - t, y, min_c.z), Vector3(t, t, size.z), color)
	k.box(Vector3(min_c.x + size.x, y, min_c.z), Vector3(t, t, size.z), color)


# --- Neon club (2x2): neon sign over the door ------------------------------------------------
static func club(tube: Color, sign_region: String, height: float) -> ArrayMesh:
	var k := MeshKit.new()
	var body := Vector3(-0.8, 0, -0.8)
	var body_size := Vector3(1.6, height, 1.4)
	k.box(body, body_size, NIGHT, Color("231b30"))
	k.windows(body, body_size, int(height / 0.4), 4, Color("6b4f8f"), 1)
	k.box(Vector3(-0.3, 0, 0.6), Vector3(0.6, 0.3, 0.05), Color("15101e"))
	k.neon(true)
	_outline(k, body, body_size, tube)
	k.box(Vector3(-0.8, 0.0, 0.6), Vector3(1.6, 0.04, 0.03), tube)
	k.neon(false)
	k.front_sign(0.0, 0.34, 0.62, 1.2, sign_region)
	return k.commit()


# --- Neon tower (2x2): slim tall club with glowing strips and a sign on the roof ---------------
static func club_tower(tube: Color, strip: Color, sign_region: String) -> ArrayMesh:
	var k := MeshKit.new()
	var body := Vector3(-0.5, 0, -0.5)
	var size := Vector3(1.0, 2.6, 1.0)
	k.box(body, size, NIGHT, Color("15101e"))
	k.windows(body, size, 9, 3, Color("6b4f8f"), 1)
	k.neon(true)
	for x in [-0.5, 0.5]:
		k.box(Vector3(x - 0.02, 0.0, 0.5), Vector3(0.04, size.y, 0.03), strip)
		k.box(Vector3(x - 0.02, 0.0, -0.53), Vector3(0.04, size.y, 0.03), strip)
	_outline(k, body, size, tube)
	k.box(Vector3(-0.5, 0.0, 0.5), Vector3(1.0, 0.04, 0.03), tube)
	k.neon(false)
	k.front_sign(0.0, 0.2, 0.52, 0.9, sign_region)
	# Rooftop sign on two posts, facing the street.
	k.block(Vector3(-0.3, size.y, 0.0), Vector3(0.05, 0.3, 0.05), Color("2b2b33"))
	k.block(Vector3(0.3, size.y, 0.0), Vector3(0.05, 0.3, 0.05), Color("2b2b33"))
	k.front_sign(0.0, size.y + 0.18, 0.04, 0.9, sign_region)
	return k.commit()


# --- Small bar (1x1): low box with a striped awning and a neon BAR sign -------------------------
static func small_bar() -> ArrayMesh:
	var k := MeshKit.new()
	var body := Vector3(-0.4, 0, -0.38)
	var size := Vector3(0.8, 0.5, 0.7)
	k.box(body, size, Color("3a2d52"), Color("231b30"))
	k.windows(body, size, 1, 3, Color("ffb25c"))
	k.box(Vector3(-0.45, 0.28, 0.32), Vector3(0.9, 0.04, 0.26), PINK)
	k.neon(true)
	_outline(k, body, size, GREEN)
	k.neon(false)
	k.front_sign(0.0, 0.32, 0.325, 0.6, "neon_bar")
	return k.commit()


# --- Wedding chapel (1x2): little white chapel with a pink neon steeple --------------------------
static func chapel() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.42, 0, -0.8), Vector3(0.84, 0.4, 1.3), WHITE, Color("cfc9d8"))
	k.gable(Vector3(-0.46, 0.4, -0.84), Vector3(0.92, 0.3, 1.4), Color("c0508a"), WHITE)
	k.box(Vector3(-0.12, 0, 0.5), Vector3(0.24, 0.9, 0.24), WHITE)
	k.cylinder(Vector3(0, 0.9, 0.62), 0.2, 0.0, 0.4, 4, Color("c0508a"))
	k.neon(true)
	k.block(Vector3(0, 1.28, 0.62), Vector3(0.03, 0.2, 0.03), PINK)
	k.box(Vector3(-0.07, 1.4, 0.605), Vector3(0.14, 0.03, 0.03), PINK)
	_outline(k, Vector3(-0.42, 0, -0.8), Vector3(0.84, 0.4, 1.3), PINK)
	k.neon(false)
	for z in [-0.5, -0.1]:
		k.box(Vector3(0.425, 0.12, z), Vector3(0.01, 0.2, 0.14), Color("ffb25c"))
		k.box(Vector3(-0.435, 0.12, z), Vector3(0.01, 0.2, 0.14), Color("ffb25c"))
	return k.commit()


# --- Resort casino (4x4): marquee podium with two stepped towers and a giant sign --------------
static func resort() -> ArrayMesh:
	var k := MeshKit.new()
	var podium := Vector3(-1.7, 0, -1.4)
	var podium_size := Vector3(3.4, 0.5, 2.9)
	k.box(podium, podium_size, PURPLE, NIGHT)
	k.windows(podium, podium_size, 1, 10, Color("ffd36b"))
	for x in [-1.25, 0.35]:
		var t := Vector3(x, 0.5, -1.15)
		k.box(t, Vector3(0.9, 1.9, 1.1), MAGENTA, NIGHT)
		k.windows(t, Vector3(0.9, 1.9, 1.1), 7, 3, Color("ffe14f"))
		k.box(t + Vector3(0.1, 1.9, 0.1), Vector3(0.7, 0.5, 0.9), PURPLE, NIGHT)
		k.cylinder(t + Vector3(0.45, 2.4, 0.55), 0.25, 0.0, 0.5, 8, GOLD)
	k.cylinder(Vector3(0, 0.5, 0.3), 0.7, 0.55, 0.3, 14, GOLD)
	k.cylinder(Vector3(0, 0.8, 0.3), 0.5, 0.0, 0.5, 14, GOLD)
	k.box(Vector3(-0.9, 0.3, 1.4), Vector3(1.8, 0.05, 0.4), GOLD)
	k.neon(true)
	_outline(k, podium, podium_size, PINK)
	_outline(k, Vector3(-1.25, 0.5, -1.15), Vector3(0.9, 1.9, 1.1), CYAN)
	_outline(k, Vector3(0.35, 0.5, -1.15), Vector3(0.9, 1.9, 1.1), CYAN)
	k.neon(false)
	k.front_sign(0.0, 0.52, 1.52, 1.6, "neon_xxx")
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


# --- Drive-in cinema (4x3): big screen showing a film, cars facing it, lamp posts ----------------
static func drive_in() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.95, 0, -1.45), Vector3(3.9, 0.02, 2.9), ASPHALT)
	# Screen on two legs at the back; the film glows at night like a sign.
	for x in [-1.0, 1.0]:
		k.box(Vector3(x - 0.05, 0, -1.35), Vector3(0.1, 0.5, 0.1), STEEL)
	k.box(Vector3(-1.45, 0.45, -1.4), Vector3(2.9, 1.2, 0.08), WHITE)
	k.panel(Vector3(-1.35, 0.52, -1.315), Vector3(2.7, 0, 0), Vector3(0, 1.06, 0), "movie")
	k.neon(true)
	k.box(Vector3(1.5, 0.02, 1.2), Vector3(0.4, 0.35, 0.06), YELLOW)
	k.neon(false)
	# Projection booth and its beam light.
	k.box(Vector3(-0.25, 0.02, 1.0), Vector3(0.5, 0.3, 0.35), Color("e8e4d8"), Color("8f86a6"))
	# Rows of cars, all turned towards the screen, with their parking lights.
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
	# Lamp posts around the lot, a string of bulbs over the entrance.
	for p in [Vector3(-1.85, 0, -1.3), Vector3(1.85, 0, -1.3), Vector3(-1.85, 0, 1.3), Vector3(1.85, 0, 1.3)]:
		k.block(p, Vector3(0.04, 0.6, 0.04), STEEL)
	k.glow(true)
	for p in [Vector3(-1.85, 0, -1.3), Vector3(1.85, 0, -1.3), Vector3(-1.85, 0, 1.3), Vector3(1.85, 0, 1.3)]:
		k.block(p + Vector3(0, 0.6, 0), Vector3(0.1, 0.06, 0.1), Color.WHITE)
	for i in 9:
		k.block(Vector3(-1.9 + i * 0.475, 0.45, 1.42), Vector3(0.06, 0.06, 0.06), Color.WHITE)
	k.block(Vector3(0, 0.25, 0.98), Vector3(0.12, 0.08, 0.04), Color.WHITE)
	k.glow(false)
	return k.commit()
