class_name ParkMeshes
extends RefCounted
## Small details of the ground: park benches, flowerbeds and a playground, the planks and
## lamps of the boardwalk of the red district, and the rocks and dry tufts that blend the
## desert into the meadows. Each one is centred on its cell (the playground on a 2x2 square).

const WOOD := Color("9a6a42")
const DARK_WOOD := Color("6e4a2e")
const METAL := Color("5f6270")
const SOIL := Color("6b4a32")
const LEAF := Color("4f9a45")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("bench", bench())
	lib.add_named("flowerbed", flowerbed())
	lib.add_named("playground", playground())
	lib.add_named("plank", plank())
	lib.add_named("boardwalk_lamp", boardwalk_lamp())
	lib.add_named("rock", rock())
	lib.add_named("dry_tuft", dry_tuft())
	lib.add_named("fence", fence())


## Park bench, seat along X, back towards -Z (the path is on its +Z side).
static func bench() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.3, 0.16, -0.1), Vector3(0.6, 0.04, 0.2), WOOD)
	k.box(Vector3(-0.3, 0.26, -0.12), Vector3(0.6, 0.16, 0.03), WOOD)
	for x in [-0.25, 0.22]:
		k.box(Vector3(x, 0.0, -0.1), Vector3(0.04, 0.16, 0.2), METAL)
	return k.commit()


## A square bed with a low hedge and rows of flowers.
static func flowerbed() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.45, 0, -0.45), Vector3(0.9, 0.08, 0.9), LEAF)
	k.box(Vector3(-0.38, 0.08, -0.38), Vector3(0.76, 0.01, 0.76), SOIL)
	var colors := [Color("ff4f6e"), Color("ffd84a"), Color("ffffff"), Color("c06bff"), Color("ff8a3d")]
	for ix in 4:
		for iz in 4:
			var c: Color = colors[(ix * 3 + iz) % colors.size()]
			k.block(Vector3(-0.28 + ix * 0.19, 0.14, -0.28 + iz * 0.19), Vector3(0.1, 0.1, 0.1), c)
	return k.commit()


## Playground on a 2x2 square: sandbox, a slide on a tower, a swing set.
static func playground() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.95, 0, -0.95), Vector3(1.9, 0.03, 1.9), Color("e8dcb4"))
	# Sandbox.
	k.box(Vector3(-0.8, 0.03, 0.15), Vector3(0.7, 0.1, 0.7), Color("c09a5a"))
	k.box(Vector3(-0.74, 0.1, 0.21), Vector3(0.58, 0.04, 0.58), Color("f0dfa0"))
	# Slide: a tower and a ramp.
	k.box(Vector3(0.25, 0.0, -0.8), Vector3(0.3, 0.5, 0.3), Color("3a7bd5"))
	k.box(Vector3(0.22, 0.5, -0.83), Vector3(0.36, 0.05, 0.36), Color("e8403a"))
	k.xform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-38.0)), Vector3(0.4, 0.5, -0.5))
	k.box(Vector3(-0.1, -0.02, 0.0), Vector3(0.2, 0.03, 0.65), Color("ffd84a"))
	k.xform = Transform3D.IDENTITY
	# Swing set.
	for x in [-0.85, -0.15]:
		k.box(Vector3(x, 0, -0.75), Vector3(0.04, 0.55, 0.04), METAL)
	k.box(Vector3(-0.87, 0.52, -0.77), Vector3(0.76, 0.04, 0.08), METAL)
	for x in [-0.65, -0.35]:
		k.box(Vector3(x, 0.18, -0.74), Vector3(0.16, 0.03, 0.1), Color("e8403a"))
		k.box(Vector3(x + 0.07, 0.2, -0.74), Vector3(0.01, 0.32, 0.01), METAL)
	return k.commit()


## One wooden plank tile (a whole cell), laid just above the sand.
static func plank() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.5, 0, -0.5), Vector3(1.0, 0.05, 1.0), Color("b58a5a"))
	for i in 4:
		k.box(Vector3(-0.5, 0.051, -0.5 + 0.25 * i), Vector3(1.0, 0.004, 0.02), DARK_WOOD)
	return k.commit()


## A post with a glowing bulb (lit at night).
static func boardwalk_lamp() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.02, 0, -0.02), Vector3(0.04, 0.55, 0.04), Color("3d3f4a"))
	k.glow(true)
	k.block(Vector3(0, 0.6, 0), Vector3(0.12, 0.1, 0.12), Color.WHITE)
	k.glow(false)
	return k.commit()


static func rock() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3(0, 0, 0), 0.14, 0.07, 0.11, 5, Color("9b8f7a"), Color("b3a78f"))
	k.cylinder(Vector3(0.12, 0, 0.05), 0.08, 0.04, 0.07, 5, Color("8a7f6c"), Color("a39880"))
	return k.commit()


static func dry_tuft() -> ArrayMesh:
	var k := MeshKit.new()
	var colors := [Color("bfae5a"), Color("d4c47a"), Color("a89a4a")]
	for i in 6:
		var a := TAU * i / 6.0
		var h := 0.16 + 0.05 * float(i % 3)
		k.cylinder(Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), 0.03, 0.0, h, 4, colors[i % 3])
	return k.commit()


## One cell of chain-link fence along X: two posts, a top rail and a few wires.
static func fence() -> ArrayMesh:
	var k := MeshKit.new()
	for x in [-0.5, 0.46]:
		k.box(Vector3(x, 0, -0.02), Vector3(0.04, 0.42, 0.04), METAL)
	k.box(Vector3(-0.5, 0.4, -0.015), Vector3(1.0, 0.025, 0.03), METAL)
	k.box(Vector3(-0.5, 0.02, -0.01), Vector3(1.0, 0.02, 0.02), METAL)
	for i in 9:
		k.box(Vector3(-0.44 + i * 0.11, 0.04, -0.005), Vector3(0.012, 0.36, 0.01), Color("9aa0aa"))
	return k.commit()
