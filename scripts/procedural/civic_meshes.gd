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
	k.front_sign(0.0, 2.55, -0.505, 1.5, "sign_un")
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


# --- Prison island (4x3): cellhouse, water tower, guard towers, walls ------------------
static func prison() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-1.95, 0, -1.45), Vector3(3.9, 0.03, 2.9), Color("a9a59b"))
	# Cellhouse: long three-storey concrete block with rows of barred windows.
	var cell := Vector3(-1.5, 0.03, -0.9)
	var cell_size := Vector3(3.0, 0.75, 1.2)
	k.box(cell, cell_size, Color("d7d2c4"), Color("8f8b80"))
	k.windows(cell, cell_size, 3, 12, Color("3a3a40"))
	k.box(Vector3(-1.55, 0.78, -0.95), Vector3(3.1, 0.06, 1.3), Color("c4bfb1"))
	k.front_sign(0.0, 0.55, 0.32, 1.4, "sign_prison")
	# Administration wing and the recreation yard walls.
	k.box(Vector3(0.9, 0.03, 0.4), Vector3(0.8, 0.45, 0.6), Color("cfc9bb"), Color("8f8b80"))
	k.box(Vector3(-1.9, 0.03, 0.4), Vector3(1.6, 0.25, 0.06), CONCRETE)
	k.box(Vector3(-1.9, 0.03, 1.3), Vector3(1.6, 0.25, 0.06), CONCRETE)
	k.box(Vector3(-1.9, 0.03, 0.4), Vector3(0.06, 0.25, 0.96), CONCRETE)
	# Water tower on stilts.
	for p in [Vector3(1.3, 0, -1.3), Vector3(1.7, 0, -1.3), Vector3(1.3, 0, -0.9), Vector3(1.7, 0, -0.9)]:
		k.block(p, Vector3(0.04, 0.9, 0.04), Color("6b5a4a"))
	k.cylinder(Vector3(1.5, 0.9, -1.1), 0.3, 0.3, 0.35, 12, Color("e6e0d0"), Color("8f8b80"))
	k.cylinder(Vector3(1.5, 1.25, -1.1), 0.3, 0.0, 0.12, 12, Color("8f8b80"))
	# Guard towers at two corners, with search lights.
	for p in [Vector3(-1.75, 0, 1.2), Vector3(1.75, 0, 1.2)]:
		k.block(p, Vector3(0.22, 0.75, 0.22), CONCRETE)
		k.block(p + Vector3(0, 0.75, 0), Vector3(0.32, 0.16, 0.32), DARK)
		k.block(p + Vector3(0, 0.91, 0), Vector3(0.38, 0.04, 0.38), Color("5a5d6e"))
		k.glow(true)
		k.block(p + Vector3(0, 0.8, 0.17), Vector3(0.08, 0.06, 0.03), Color.WHITE)
		k.glow(false)
	return k.commit()
