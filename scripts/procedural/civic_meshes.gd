class_name CivicMeshes
extends RefCounted
## Signed buildings that use the sign atlas: the bank, the United Nations
## headquarters and the Alcatraz-like prison. Centred on their lot, base at
## y = 0, front (and readable signs) towards +Z.

const WHITE := Color("f1eff6")
const STONE := Color("e6dcc6")
const ROOF := Color("8d8aa3")
const WINDOW := Color("3d4566")
const GLASS := Color("4f8fb8")
const CONCRETE := Color("b9b4aa")
const DARK := Color("4a4d63")
const GOLD := Color("e8b33a")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("bank", bank())
	lib.add_named("un_hq", un_headquarters())
	lib.add_named("prison", prison())
	lib.add_named("un_signs", un_signs())


# --- Bank (3x3): stone base with columns, glass tower, big "$" facing the street ---
static func bank() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.45, 0, -1.45), Vector3(2.9, 0.03, 2.9), Color("d8d3c4"))
	# Classical base with steps and six columns.
	var base := Vector3(-1.2, 0.03, -1.1)
	var base_size := Vector3(2.4, 0.7, 1.9)
	k.box(base, base_size, STONE, ROOF)
	for i in 3:
		k.box(Vector3(-0.9 + i * 0.05, 0.03 + i * 0.05, 0.8 - i * 0.07), Vector3(1.8 - i * 0.1, 0.05, 0.3), STONE)
	for i in 6:
		k.block(Vector3(-0.85 + i * 0.34, 0.18, 0.86), Vector3(0.09, 0.5, 0.09), WHITE)
	k.box(Vector3(-1.0, 0.68, 0.78), Vector3(2.0, 0.08, 0.18), WHITE)
	# Glass tower on top.
	var tower := Vector3(-0.85, 0.73, -0.9)
	var tower_size := Vector3(1.7, 2.6, 1.4)
	k.box(tower, tower_size, Color("5b7fc4"), DARK)
	k.windows(tower, tower_size, 10, 5, Color("a9c4f0"))
	k.box(Vector3(-0.9, 3.33, -0.95), Vector3(1.8, 0.08, 1.5), WHITE)
	# Signs: "BANK" over the columns, a big "$" coin on the tower front and on a roof frame.
	k.front_sign(0.0, 0.47, 0.965, 1.2, "sign_bank")
	k.front_sign(0.0, 1.9, 0.52, 0.95, "dollar")
	k.block(Vector3(-0.45, 3.41, 0.1), Vector3(0.05, 0.5, 0.05), DARK)
	k.block(Vector3(0.45, 3.41, 0.1), Vector3(0.05, 0.5, 0.05), DARK)
	k.front_sign(0.0, 3.5, 0.13, 1.0, "dollar")
	return k.commit()


# --- United Nations headquarters (3x3): slender glass slab, assembly hall, flags ---
static func un_headquarters() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.45, 0, -1.45), Vector3(2.9, 0.03, 2.9), Color("d8d3c4"))
	# Secretariat: a thin slab, glass on its wide faces, white stone on the narrow ones.
	var slab := Vector3(-0.95, 0.03, -1.15)
	var slab_size := Vector3(1.9, 4.6, 0.62)
	k.box(slab, slab_size, GLASS, Color("d9dde6"))
	k.box(Vector3(-1.0, 0.03, -1.16), Vector3(0.06, 4.6, 0.64), WHITE)
	k.box(Vector3(0.94, 0.03, -1.16), Vector3(0.06, 4.6, 0.64), WHITE)
	k.windows(slab, slab_size, 16, 8, Color("a8d0e6"))
	# The emblem and the name on the front of the slab.
	k.front_sign(0.0, 3.0, -0.505, 1.1, "un_emblem")
	# General Assembly: low building with a curved roof in front.
	var hall := Vector3(-1.2, 0.03, -0.25)
	k.box(hall, Vector3(1.5, 0.5, 0.8), WHITE, Color("c9c6d6"))
	k.cylinder(Vector3(-0.45, 0.53, 0.15), 0.32, 0.22, 0.16, 12, Color("6f9c9a"))
	# Row of flags along the street.
	var flag_colors := [Color("d9474f"), Color("4569b8"), Color("f1eff6"), Color("5c9d4c"),
			Color("e8b33a"), Color("4b92db"), Color("d9474f"), Color("2f2f3a")]
	for i in flag_colors.size():
		var x := -1.3 + i * 0.34
		k.block(Vector3(x, 0.03, 1.2), Vector3(0.025, 0.7, 0.025), WHITE)
		k.box(Vector3(x + 0.013, 0.55, 1.19), Vector3(0.22, 0.13, 0.01), flag_colors[i])
	k.glow(true)
	k.block(Vector3(0, 4.63, -0.84), Vector3(0.12, 0.05, 0.12), Color.WHITE)
	k.glow(false)
	return k.commit()


## The U.N. emblem (no text) for the front of the U.N. tower model: a unit
## panel centred on x, bottom at y = 0, facing +Z (placed and scaled by the
## building placer).
static func un_signs() -> ArrayMesh:
	var k := MeshKit.new()
	k.front_sign(0.0, 0.0, 0.0, 1.0, "un_emblem")
	return k.commit()


# --- Prison island (4x3): cellhouse, water tower, guard towers, walls ------------------
static func prison() -> ArrayMesh:
	var k := MeshKit.new()
	var wall := Color("8f8b80")
	var wire := Color("5a5d6e")
	k.box(Vector3(-1.95, 0, -1.45), Vector3(3.9, 0.03, 2.9), Color("a9a59b"))
	# The cellhouse is the school building model (BuildingExtras puts it in the middle).
	# Perimeter wall, with a gate in the middle of the front and razor wire on top.
	var walls := [
		[Vector3(-1.93, 0.03, -1.43), Vector3(3.86, 0.3, 0.07)], [Vector3(-1.93, 0.03, -1.43), Vector3(0.07, 0.3, 2.86)],
		[Vector3(1.86, 0.03, -1.43), Vector3(0.07, 0.3, 2.86)], [Vector3(-1.93, 0.03, 1.36), Vector3(1.63, 0.3, 0.07)],
		[Vector3(0.3, 0.03, 1.36), Vector3(1.63, 0.3, 0.07)],
	]
	for w in walls:
		k.box(w[0], w[1], wall, CONCRETE)
		var size: Vector3 = w[1]
		k.box((w[0] as Vector3) + Vector3(0.02, 0.3, 0.02), Vector3(maxf(size.x - 0.04, 0.03), 0.05, maxf(size.z - 0.04, 0.03)), wire)
	# Inner chain fence round the yard: posts and two rails.
	for z in [-1.22, 1.15]:
		for h in [0.12, 0.22]:
			k.box(Vector3(-1.7, h, z), Vector3(3.4, 0.015, 0.015), wire)
		for i in 18:
			k.box(Vector3(-1.7 + i * 0.2, 0.03, z), Vector3(0.02, 0.22, 0.02), wire)
	for x in [-1.7, 1.68]:
		for h in [0.12, 0.22]:
			k.box(Vector3(x, h, -1.22), Vector3(0.015, 0.015, 2.37), wire)
		for i in 12:
			k.box(Vector3(x, 0.03, -1.22 + i * 0.2), Vector3(0.02, 0.22, 0.02), wire)
	# Exercise yard in front of the cellhouse.
	k.box(Vector3(-1.5, 0.03, 0.85), Vector3(1.2, 0.006, 0.26), Color("7f8a6a"))
	# Guard towers at the four corners and beside the gate, with search lights.
	for p in [Vector3(-1.8, 0, -1.3), Vector3(1.8, 0, -1.3), Vector3(-1.8, 0, 1.3), Vector3(1.8, 0, 1.3),
			Vector3(-0.42, 0, 1.38), Vector3(0.42, 0, 1.38)]:
		k.block(p, Vector3(0.2, 0.62, 0.2), CONCRETE)
		k.block(p + Vector3(0, 0.62, 0), Vector3(0.3, 0.15, 0.3), DARK)
		k.block(p + Vector3(0, 0.77, 0), Vector3(0.36, 0.04, 0.36), wire)
		k.glow(true)
		k.block(p + Vector3(0, 0.66, 0.16), Vector3(0.08, 0.06, 0.03), Color.WHITE)
		k.glow(false)
	return k.commit()
