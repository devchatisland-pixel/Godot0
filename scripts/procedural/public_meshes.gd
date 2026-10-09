class_name PublicMeshes
extends RefCounted
## Public buildings modelled in the Kenney style: the two museums, the post
## office, the cemetery and the two grand hotels. Centred on their lot, base
## at y = 0, front towards +Z, long buildings modelled along X. The building
## placer scales them to fill their lot. Windows and lamps glow at night.

const STONE := Color("e6dcc6")
const WHITE := Color("f4f2f8")
const ROOF := Color("8d8aa3")
const WINDOW := Color("3d4566")
const DOME := Color("6f9c9a")
const PAVING := Color("d8d3c4")
const GRASS := Color("74b85a")
const DARK := Color("4a4d63")
const GOLD := Color("e8b33a")
const BRICK := Color("b5654a")
const BLUE := Color("2f5fb3")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("museum_art", museum_art())
	lib.add_named("museum_history", museum_history())
	lib.add_named("post_office", post_office())
	lib.add_named("cemetery", cemetery())
	lib.add_named("hotel_a", hotel(Color("e9dcc8"), Color("7a2338"), false))
	lib.add_named("hotel_b", hotel(Color("5b7fc4"), Color("2b3550"), true))


# --- Art museum (7x5): wide temple front, two wings, glass pyramid --------------------
static func museum_art() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-3.3, 0, -2.3), Vector3(6.6, 0.03, 4.6), PAVING)
	# Two wings and the central hall.
	for x in [-3.0, 1.2]:
		var wing := Vector3(x, 0.03, -1.9)
		k.box(wing, Vector3(1.8, 1.0, 2.6), STONE, ROOF)
		k.windows(wing, Vector3(1.8, 1.0, 2.6), 2, 4, WINDOW)
	var hall := Vector3(-1.3, 0.03, -2.0)
	k.box(hall, Vector3(2.6, 1.35, 2.9), STONE, ROOF)
	k.windows(hall, Vector3(2.6, 1.35, 2.9), 2, 5, WINDOW)
	# Wide stairs, ten columns and the pediment with its sign.
	for i in 4:
		k.box(Vector3(-1.6 + i * 0.05, 0.03 + i * 0.06, 0.9 + 0.65 - i * 0.12),
				Vector3(3.2 - i * 0.1, 0.06, 0.6), STONE)
	for i in 10:
		k.block(Vector3(-1.45 + i * 0.322, 0.27, 1.25), Vector3(0.12, 1.0, 0.12), WHITE)
	k.box(Vector3(-1.6, 1.27, 0.88), Vector3(3.2, 0.14, 0.5), WHITE)
	k.gable(Vector3(-1.6, 1.41, 0.88), Vector3(3.2, 0.42, 0.5), WHITE, STONE)
	k.front_sign(0.0, 1.29, 1.385, 1.5, "sign_museum")
	# Glass pyramid in the courtyard behind (lit at night).
	k.box(Vector3(-0.55, 1.38, -1.5), Vector3(1.1, 0.03, 1.1), PAVING)
	k.glow(true)
	k.cylinder(Vector3(0, 1.41, -0.95), 0.62, 0.0, 0.7, 4, Color("bcd8ef"))
	k.glow(false)
	# Banners and lanterns along the front.
	for x in [-2.6, -2.0, 1.6, 2.2]:
		k.box(Vector3(x, 0.4, 0.71), Vector3(0.22, 0.45, 0.01), Color("c0392b"))
	k.glow(true)
	for x in [-1.8, 1.8]:
		k.block(Vector3(x, 0.03, 1.9), Vector3(0.06, 0.45, 0.06), WHITE)
	k.glow(false)
	return k.commit()


# --- History museum (4x4): stairs, colonnade, pediment and a dome ----------------------------
static func museum_history() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.45, 0, -1.45), Vector3(2.9, 0.03, 2.9), PAVING)
	for i in 3:
		k.box(Vector3(-0.8 + i * 0.05, 0.03 + i * 0.05, 0.7 - i * 0.08), Vector3(1.6 - i * 0.1, 0.05, 0.35), STONE)
	var body := Vector3(-1.2, 0.03, -1.1)
	var body_size := Vector3(2.4, 0.9, 1.65)
	k.box(body, body_size, STONE, ROOF)
	k.windows(body, body_size, 2, 7, WINDOW)
	for i in 6:
		k.block(Vector3(-0.62 + i * 0.25, 0.18, 0.72), Vector3(0.08, 0.7, 0.08), WHITE)
	k.box(Vector3(-0.75, 0.88, 0.55), Vector3(1.5, 0.08, 0.3), WHITE)
	k.gable(Vector3(-0.75, 0.96, 0.55), Vector3(1.5, 0.25, 0.3), WHITE, STONE)
	k.front_sign(0.0, 0.89, 0.855, 0.62, "sign_museum")
	var top := Vector3(0, 0.93, -0.3)
	k.cylinder(top, 0.5, 0.5, 0.35, 16, WHITE)
	for i in 4:
		var r := 0.48 * cos(i * 0.38)
		var r2 := 0.48 * cos((i + 1) * 0.38)
		k.cylinder(top + Vector3(0, 0.35 + i * 0.12, 0), r, r2, 0.12, 16, DOME)
	k.block(top + Vector3(0, 0.83, 0), Vector3(0.03, 0.3, 0.03), WHITE)
	k.glow(true)
	k.block(top + Vector3(0, 1.13, 0), Vector3(0.06, 0.06, 0.06), WHITE)
	k.glow(false)
	return k.commit()


# --- Post office (3x2): brick, blue band, sign, mail vans -------------------------------------
static func post_office() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.45, 0, -0.95), Vector3(2.9, 0.02, 1.9), Color("5a5d6e"))
	var body := Vector3(-1.2, 0.02, -0.85)
	var size := Vector3(1.7, 0.8, 1.1)
	k.box(body, size, BRICK, ROOF)
	k.windows(body, size, 2, 5, WINDOW)
	k.box(Vector3(-1.21, 0.5, 0.25), Vector3(1.72, 0.06, 0.02), BLUE)
	k.box(Vector3(-0.6, 0.02, 0.25), Vector3(0.5, 0.35, 0.12), WHITE)
	k.front_sign(-0.35, 0.58, 0.27, 1.0, "sign_post")
	# Flag pole and mail box.
	k.block(Vector3(-1.35, 0.02, 0.75), Vector3(0.03, 1.0, 0.03), WHITE)
	k.box(Vector3(-1.335, 0.8, 0.75), Vector3(0.3, 0.18, 0.01), BLUE)
	k.block(Vector3(0.1, 0.02, 0.7), Vector3(0.12, 0.18, 0.1), BLUE)
	# Garage with three white and blue vans.
	for i in 3:
		var p := Vector3(0.85, 0.02, -0.6 + i * 0.5)
		k.block(p, Vector3(0.5, 0.2, 0.26), WHITE)
		k.block(p + Vector3(0.2, 0.05, 0), Vector3(0.1, 0.1, 0.27), BLUE)
	k.glow(true)
	k.block(Vector3(-0.35, 0.37, 0.4), Vector3(0.3, 0.03, 0.05), WHITE)
	k.glow(false)
	return k.commit()


# --- Cemetery (6x5): stone wall, gate, rows of graves, cypresses, chapel ------------------------
static func cemetery() -> ArrayMesh:
	var k := MeshKit.new()
	var w := 2.85
	var d := 2.35
	k.box(Vector3(-w, 0, -d), Vector3(w * 2, 0.02, d * 2), GRASS)
	# Walls with a gate in the front.
	var wall := Color("a49c8c")
	k.box(Vector3(-w, 0.02, -d), Vector3(w * 2, 0.18, 0.08), wall)
	k.box(Vector3(-w, 0.02, -d), Vector3(0.08, 0.18, d * 2), wall)
	k.box(Vector3(w - 0.08, 0.02, -d), Vector3(0.08, 0.18, d * 2), wall)
	k.box(Vector3(-w, 0.02, d - 0.08), Vector3(w - 0.35, 0.18, 0.08), wall)
	k.box(Vector3(0.35, 0.02, d - 0.08), Vector3(w - 0.35, 0.18, 0.08), wall)
	for x in [-0.4, 0.32]:
		k.box(Vector3(x, 0.02, d - 0.12), Vector3(0.08, 0.35, 0.12), wall)
	# Central path to the chapel.
	k.box(Vector3(-0.25, 0.022, -1.2), Vector3(0.5, 0.005, d + 1.15), Color("cfc4a8"))
	# Rows of graves: tall headstones, crosses and angels on pedestals, easy to see from far.
	var grey := [Color("bdbab2"), Color("9e9b94"), Color("d8d5ce")]
	for row in 6:
		for col in 12:
			var x := -w + 0.35 + col * 0.46
			if absf(x) < 0.45:
				continue
			var z := -1.0 + row * 0.55
			var h := CityTypes.hash2(row, col, 909)
			var c: Color = grey[h % 3]
			if h % 4 == 0:
				k.block(Vector3(x, 0.02, z), Vector3(0.07, 0.5, 0.07), c)
				k.block(Vector3(x, 0.3, z), Vector3(0.3, 0.07, 0.07), c)
			elif h % 7 == 0:
				k.block(Vector3(x, 0.02, z), Vector3(0.2, 0.18, 0.2), c)
				k.block(Vector3(x, 0.2, z), Vector3(0.1, 0.34, 0.08), Color("e6e3dc"))
			else:
				k.block(Vector3(x, 0.02, z), Vector3(0.24, 0.3 + float(h & 3) * 0.06, 0.08), c)
			k.box(Vector3(x - 0.12, 0.021, z + 0.06), Vector3(0.24, 0.004, 0.3), Color("5f9a4a"))
	# Tall cypress trees along the walls.
	for i in 8:
		var x := -w + 0.3 + i * (w * 2 - 0.6) / 7.0
		k.cylinder(Vector3(x, 0.02, -d + 0.3), 0.17, 0.0, 1.5, 6, Color("2f6b3a"))
		k.cylinder(Vector3(x, 0.02, d - 0.4), 0.15, 0.0, 1.3, 6, Color("37783f"))
	# Chapel (a big one) at the back with lit windows and a golden cross.
	k.box(Vector3(-0.65, 0.02, -2.15), Vector3(1.3, 0.9, 0.95), Color("cfc9bb"), ROOF)
	k.gable(Vector3(-0.72, 0.92, -2.15), Vector3(1.44, 0.5, 0.95), DARK, Color("cfc9bb"))
	k.block(Vector3(0, 1.38, -1.7), Vector3(0.06, 0.45, 0.06), GOLD)
	k.box(Vector3(-0.15, 1.65, -1.73), Vector3(0.3, 0.06, 0.06), GOLD)
	k.glow(true)
	k.box(Vector3(-0.14, 0.2, -1.195), Vector3(0.28, 0.5, 0.01), Color("ffd28a"))
	for z in [-0.6, 0.6, 1.6]:
		k.block(Vector3(0.35, 0.02, z), Vector3(0.05, 0.4, 0.05), WHITE)
	k.glow(false)
	return k.commit()


# --- Grand hotel (3x3): podium with a canopy and sign, tower with a lit crown ----------------
static func hotel(wall: Color, accent: Color, pool: bool) -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.45, 0, -1.45), Vector3(2.9, 0.02, 2.9), PAVING)
	var podium := Vector3(-1.3, 0.02, -1.2)
	k.box(podium, Vector3(2.6, 0.6, 2.2), accent, ROOF)
	k.windows(podium, Vector3(2.6, 0.6, 2.2), 1, 7, Color("ffe1a8"))
	var tower := Vector3(-0.9, 0.62, -1.0)
	var tower_size := Vector3(1.8, 4.2, 1.5)
	k.box(tower, tower_size, wall, DARK)
	k.windows(tower, tower_size, 14, 6, WINDOW)
	# Gold canopy over the entrance, red carpet, flags.
	k.box(Vector3(-0.6, 0.32, 1.0), Vector3(1.2, 0.05, 0.4), GOLD)
	k.box(Vector3(-0.15, 0.021, 1.0), Vector3(0.3, 0.004, 0.42), Color("b3202f"))
	for x in [-1.2, -0.95, 0.95, 1.2]:
		k.block(Vector3(x, 0.02, 1.3), Vector3(0.025, 0.7, 0.025), WHITE)
		k.box(Vector3(x + 0.013, 0.56, 1.29), Vector3(0.18, 0.11, 0.01), accent.lightened(0.2))
	k.front_sign(0.0, 0.62, 0.52, 1.5, "sign_hotel")
	var top := 0.62 + tower_size.y
	if pool:
		k.box(Vector3(-0.8, top, -0.9), Vector3(1.6, 0.04, 1.3), PAVING)
		k.box(Vector3(-0.5, top + 0.04, -0.6), Vector3(1.0, 0.01, 0.6), Color("4fd2f0"))
	else:
		k.box(Vector3(-0.7, top, -0.8), Vector3(1.4, 0.3, 1.1), accent, DARK)
		k.cylinder(Vector3(0, top + 0.3, -0.25), 0.4, 0.0, 0.5, 4, GOLD)
	# Lit crown and the outline of the tower top.
	k.glow(true)
	k.box(Vector3(-0.92, top - 0.12, 0.5), Vector3(1.84, 0.05, 0.02), WHITE)
	k.box(Vector3(-0.92, top - 0.12, -1.02), Vector3(1.84, 0.05, 0.02), WHITE)
	k.box(Vector3(0.9, top - 0.12, -1.0), Vector3(0.02, 0.05, 1.5), WHITE)
	k.box(Vector3(-0.92, top - 0.12, -1.0), Vector3(0.02, 0.05, 1.5), WHITE)
	k.glow(false)
	return k.commit()
