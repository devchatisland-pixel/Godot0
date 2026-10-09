class_name MilitaryMeshes
extends RefCounted
## The military corner of the desert: a half-buried bunker and a landing
## strip with its hangar, control tower and jets. Centred on their lot, base
## at y = 0, front towards +Z; the airbase is modelled along X (16x5 cells).
## Runway edge lights and the tower cab glow at night.

const SAND := Color("d9b06a")
const CONCRETE := Color("b9b4aa")
const DARK := Color("4a4d55")
const ASPHALT := Color("3f424c")
const LINE := Color("f4f4f4")
const KHAKI := Color("7d7a4f")
const JET := Color("8f97a3")
const GLASS := Color("6fa8dc")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("bunker", bunker())
	lib.add_named("airbase", airbase())


# --- Bunker (3x3): sand berm, concrete front with a steel door, sandbags ------------------
static func bunker() -> ArrayMesh:
	var k := MeshKit.new()
	# Berm: stepped sand mound covering the bunker.
	for i in 4:
		var s := 2.5 - i * 0.45
		k.box(Vector3(-s * 0.5, i * 0.14, -1.25 + i * 0.12), Vector3(s, 0.14, s * 0.85), SAND.darkened(i * 0.04))
	# Concrete entrance block and the door.
	k.box(Vector3(-0.6, 0, 0.55), Vector3(1.2, 0.5, 0.35), CONCRETE, Color("a19c92"))
	k.box(Vector3(-0.22, 0, 0.9), Vector3(0.44, 0.34, 0.01), DARK)
	k.box(Vector3(-0.55, 0.35, 0.9), Vector3(1.1, 0.04, 0.02), Color("d8c04a"))
	# Sandbag walls on both sides of the entrance.
	for side in [-1.0, 1.0]:
		for i in 3:
			k.block(Vector3(side * (0.8 + i * 0.18), 0, 1.0 - i * 0.05), Vector3(0.18, 0.12, 0.12), KHAKI)
			k.block(Vector3(side * (0.8 + i * 0.18), 0.12, 1.0 - i * 0.05), Vector3(0.16, 0.1, 0.11), KHAKI.darkened(0.1))
	# Air vents and a radio mast on top.
	k.block(Vector3(-0.3, 0.56, -0.5), Vector3(0.14, 0.18, 0.14), CONCRETE)
	k.block(Vector3(0.3, 0.56, -0.6), Vector3(0.14, 0.14, 0.14), CONCRETE)
	k.block(Vector3(0.0, 0.56, -0.2), Vector3(0.03, 1.1, 0.03), DARK)
	k.glow(true)
	k.block(Vector3(0, 0.38, 0.92), Vector3(0.1, 0.06, 0.04), Color("ff6644"))
	k.block(Vector3(0, 1.66, -0.2), Vector3(0.06, 0.06, 0.06), Color("ff6644"))
	k.glow(false)
	return k.commit()


# --- Airbase (16x5): runway, taxiway, apron, hangar, control tower, jets ----------------------
static func airbase() -> ArrayMesh:
	var k := MeshKit.new()
	var half := 7.8
	# Runway with threshold stripes, numbers block and a dashed centre line.
	k.box(Vector3(-half, 0, -2.3), Vector3(half * 2, 0.025, 1.5), ASPHALT)
	var x := -half + 1.2
	while x < half - 1.2:
		k.box(Vector3(x, 0.026, -1.57), Vector3(0.45, 0.003, 0.05), LINE)
		x += 0.8
	for end in [-1.0, 1.0]:
		for i in 6:
			k.box(Vector3(end * (half - 0.55) - 0.2, 0.026, -2.15 + i * 0.22), Vector3(0.4, 0.003, 0.1), LINE)
	# Taxiway and apron.
	k.box(Vector3(-0.3, 0, -0.8), Vector3(0.6, 0.02, 1.2), ASPHALT.lightened(0.08))
	k.box(Vector3(-4.5, 0, 0.4), Vector3(9.0, 0.02, 1.95), CONCRETE)
	# Hangar: rounded roof made of a few slanted panels.
	var hangar := Vector3(-4.2, 0.02, 0.5)
	k.box(hangar, Vector3(2.4, 0.5, 1.6), Color("9aa0a8"))
	k.xform = Transform3D(Basis(Vector3.UP, PI * 0.5), hangar + Vector3(1.2, 0.5, 0.8))
	k.gable(Vector3(-0.8, 0, -1.2), Vector3(1.6, 0.45, 2.4), Color("7f868f"), Color("9aa0a8"))
	k.xform = Transform3D.IDENTITY
	k.box(Vector3(-3.7, 0.02, 2.11), Vector3(1.4, 0.42, 0.01), DARK)
	# Control tower with a glass cab.
	var tower := Vector3(3.6, 0.02, 0.9)
	k.box(tower, Vector3(0.45, 1.3, 0.45), CONCRETE)
	k.box(tower + Vector3(-0.1, 1.3, -0.1), Vector3(0.65, 0.05, 0.65), DARK)
	k.glow(true)
	k.box(tower + Vector3(-0.07, 1.35, -0.07), Vector3(0.59, 0.28, 0.59), GLASS)
	k.glow(false)
	k.box(tower + Vector3(-0.1, 1.63, -0.1), Vector3(0.65, 0.05, 0.65), DARK)
	k.block(tower + Vector3(0.22, 1.68, 0.22), Vector3(0.02, 0.4, 0.02), DARK)
	# Three fighter jets on the apron and one ready on the runway.
	for p in [Vector3(-1.2, 0.02, 1.3), Vector3(0.0, 0.02, 1.3), Vector3(1.2, 0.02, 1.3)]:
		_jet(k, p, PI * 0.5)
	_jet(k, Vector3(-5.5, 0.025, -1.55), 0.0)
	# Fuel trucks and a wind sock.
	k.block(Vector3(2.5, 0.02, 1.9), Vector3(0.45, 0.2, 0.2), KHAKI)
	k.block(Vector3(5.5, 0.02, -0.4), Vector3(0.03, 0.5, 0.03), LINE)
	k.box(Vector3(5.5, 0.42, -0.42), Vector3(0.25, 0.07, 0.07), Color("ff7a2a"))
	# Edge lights along the runway.
	k.glow(true)
	x = -half + 0.3
	while x < half:
		for z in [-2.28, -0.84]:
			k.block(Vector3(x, 0.025, z), Vector3(0.06, 0.04, 0.06), Color.WHITE)
		x += 0.6
	k.glow(false)
	return k.commit()


## Delta-wing jet: nose towards local +X turned by `yaw`.
static func _jet(k: MeshKit, at: Vector3, yaw: float) -> void:
	var saved := k.xform
	k.xform = Transform3D(Basis(Vector3.UP, yaw), at)
	k.box(Vector3(-0.45, 0.06, -0.07), Vector3(0.9, 0.12, 0.14), JET)
	k.box(Vector3(0.45, 0.07, -0.05), Vector3(0.18, 0.08, 0.1), JET.darkened(0.15))
	k.box(Vector3(0.15, 0.17, -0.04), Vector3(0.2, 0.05, 0.08), Color("2f3a4a"))
	k.box(Vector3(-0.25, 0.08, -0.45), Vector3(0.45, 0.025, 0.9), JET)
	k.box(Vector3(-0.45, 0.08, -0.2), Vector3(0.15, 0.02, 0.4), JET)
	k.box(Vector3(-0.45, 0.12, -0.01), Vector3(0.18, 0.25, 0.02), JET.darkened(0.1))
	k.xform = saved
