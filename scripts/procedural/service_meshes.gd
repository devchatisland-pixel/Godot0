class_name ServiceMeshes
extends RefCounted
## Public buildings missing from the kits, modelled in the same low-poly style.
## Every mesh is centred on its lot, sits on y = 0 and faces +Z (its street).
## Sizes are in cells: hospital 3x3, school 3x3, fire station 2x2, police 2x2.

const WHITE := Color("f1eff6")
const LAVENDER := Color("c9c6d6")
const WINDOW := Color("3d4566")
const ROOF := Color("8d8aa3")
const ASPHALT := Color("5a5d6e")
const LINE := Color("f4f4f4")
const RED := Color("d9474f")
const BRICK := Color("c97b55")
const GRASS := Color("7dbb5f")
const TRACK := Color("d4835a")
const BLUE := Color("4569b8")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("hospital", hospital())
	lib.add_named("school", school())
	lib.add_named("fire_station", fire_station())
	lib.add_named("police", police())


# --- Hospital: white blocks, red cross, helipad on the tower -------------------------
static func hospital() -> ArrayMesh:
	var k := MeshKit.new()
	# Parking in front with painted bays.
	k.box(Vector3(-1.35, 0, 0.55), Vector3(2.7, 0.02, 0.85), ASPHALT)
	for i in 7:
		k.box(Vector3(-1.2 + i * 0.38, 0.02, 0.62), Vector3(0.03, 0.005, 0.32), LINE)
	# Low wing (emergency department) and main tower.
	var wing := Vector3(-1.3, 0, -1.3)
	var wing_size := Vector3(2.6, 0.55, 1.75)
	k.box(wing, wing_size, WHITE, ROOF)
	k.windows(wing, wing_size, 2, 7, WINDOW)
	var tower := Vector3(-0.75, 0.55, -1.15)
	var tower_size := Vector3(1.5, 1.45, 1.2)
	k.box(tower, tower_size, WHITE, LAVENDER)
	k.windows(tower, tower_size, 5, 5, WINDOW)
	# Red stripe + entrance canopy.
	k.box(Vector3(-1.31, 0.5, 0.44), Vector3(2.62, 0.06, 0.02), RED)
	k.box(Vector3(-0.35, 0.28, 0.45), Vector3(0.7, 0.05, 0.3), RED)
	# Red cross on the tower front.
	k.box(Vector3(-0.07, 1.45, 0.05), Vector3(0.14, 0.42, 0.02), RED)
	k.box(Vector3(-0.21, 1.59, 0.05), Vector3(0.42, 0.14, 0.02), RED)
	# Helipad: dark pad, white ring and the H.
	var pad := Vector3(0, 2.0, -0.55)
	k.cylinder(pad, 0.5, 0.5, 0.03, 16, ASPHALT)
	k.disc(pad + Vector3(0, 0.032, 0), Vector2(0.42, 0.42), 16, LINE)
	k.disc(pad + Vector3(0, 0.034, 0), Vector2(0.37, 0.37), 16, ASPHALT)
	k.box(pad + Vector3(-0.17, 0.035, -0.17), Vector3(0.07, 0.005, 0.34), LINE)
	k.box(pad + Vector3(0.10, 0.035, -0.17), Vector3(0.07, 0.005, 0.34), LINE)
	k.box(pad + Vector3(-0.10, 0.035, -0.035), Vector3(0.2, 0.005, 0.07), LINE)
	# Rooftop machines on the wing.
	k.block(Vector3(0.95, 0.55, -0.9), Vector3(0.35, 0.18, 0.3), LAVENDER)
	k.block(Vector3(-1.0, 0.55, 0.2), Vector3(0.3, 0.15, 0.3), LAVENDER)
	return k.commit()


# --- School: L-shaped brick building with a sports field and track ----------------------
static func school() -> ArrayMesh:
	var k := MeshKit.new()
	var main := Vector3(-1.35, 0, 0.25)
	var main_size := Vector3(2.7, 0.65, 0.9)
	k.box(main, main_size, BRICK, ROOF)
	k.windows(main, main_size, 2, 8, WINDOW)
	var side := Vector3(-1.35, 0, -1.3)
	var side_size := Vector3(0.9, 0.65, 1.55)
	k.box(side, side_size, BRICK, ROOF)
	k.windows(side, side_size, 2, 4, WINDOW)
	# Entrance with a white portico and a flag pole.
	k.box(Vector3(-0.3, 0, 1.15), Vector3(0.6, 0.4, 0.2), WHITE)
	k.block(Vector3(0.6, 0, 1.3), Vector3(0.03, 0.9, 0.03), LAVENDER)
	k.box(Vector3(0.615, 0.72, 1.3), Vector3(0.25, 0.15, 0.01), BLUE)
	# Sports field with running track.
	var field_c := Vector3(0.45, 0.012, -0.55)
	k.disc(field_c, Vector2(0.95, 0.68), 24, TRACK)
	k.disc(field_c + Vector3(0, 0.003, 0), Vector2(0.78, 0.52), 24, GRASS)
	k.box(field_c + Vector3(-0.005, 0.004, -0.5), Vector3(0.01, 0.002, 1.0), LINE)
	k.box(Vector3(-0.42, 0.016, -0.6), Vector3(0.05, 0.1, 0.12), LINE)
	k.box(Vector3(1.27, 0.016, -0.6), Vector3(0.05, 0.1, 0.12), LINE)
	return k.commit()


# --- Fire station: red brick, three garage doors, drill tower ------------------------------
static func fire_station() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.9, 0, 0.35), Vector3(1.8, 0.02, 0.6), ASPHALT)
	var body := Vector3(-0.85, 0, -0.75)
	var body_size := Vector3(1.4, 0.7, 1.1)
	k.box(body, body_size, Color("b8473f"), ROOF)
	k.windows(body, body_size, 2, 4, WINDOW, 1)
	for i in 3:
		k.box(Vector3(-0.78 + i * 0.44, 0, 0.35), Vector3(0.36, 0.32, 0.012), WHITE)
		for j in 3:
			k.box(Vector3(-0.76 + i * 0.44, 0.06 + j * 0.09, 0.362), Vector3(0.32, 0.02, 0.006), LAVENDER)
	k.box(Vector3(-0.85, 0.38, 0.35), Vector3(1.4, 0.08, 0.02), WHITE)
	# Drill tower.
	var tower := Vector3(0.6, 0, -0.75)
	k.box(tower, Vector3(0.35, 1.35, 0.35), Color("a03c36"), ROOF)
	k.windows(tower, Vector3(0.35, 1.35, 0.35), 5, 1, WINDOW, 1)
	return k.commit()


# --- Police station: light facade with a blue band, antennas, patrol parking ---------------
static func police() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.9, 0, 0.45), Vector3(1.8, 0.02, 0.5), ASPHALT)
	for i in 4:
		k.block(Vector3(-0.6 + i * 0.4, 0.02, 0.7), Vector3(0.18, 0.08, 0.3), WHITE if i % 2 == 0 else BLUE)
	var body := Vector3(-0.85, 0, -0.85)
	var body_size := Vector3(1.7, 0.85, 1.25)
	k.box(body, body_size, Color("dcdde6"), ROOF)
	k.windows(body, body_size, 3, 6, WINDOW)
	k.box(Vector3(-0.86, 0.26, 0.4), Vector3(1.72, 0.07, 0.02), BLUE)
	k.box(Vector3(-0.86, 0.26, -0.86), Vector3(1.72, 0.07, 0.02), BLUE)
	# Entrance with the blue lantern.
	k.box(Vector3(-0.25, 0, 0.4), Vector3(0.5, 0.3, 0.15), BLUE)
	k.block(Vector3(0, 0.3, 0.5), Vector3(0.1, 0.1, 0.06), Color("8fb3ff"))
	# Radio antennas.
	k.block(Vector3(0.5, 0.85, -0.5), Vector3(0.04, 0.6, 0.04), LAVENDER)
	k.block(Vector3(0.3, 0.85, -0.6), Vector3(0.2, 0.12, 0.2), LAVENDER)
	return k.commit()
