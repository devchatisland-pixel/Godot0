class_name NightWindows
extends RefCounted
## Makes the windows of the Kenney buildings light up at night.
## The kits colour everything from one small palette texture; its window
## swatches (light and mid blue glass) become an emission mask, so only the
## windows glow. One mask per palette (128x128), materials shared as before.

const ModelCat := ModelCatalog.Cat
## Kit categories whose windows light up.
const CATEGORIES := [ModelCat.SKYSCRAPER, ModelCat.COMMERCIAL, ModelCat.HOUSE, ModelCat.INDUSTRIAL]
## Palette colours used for window glass in the Kenney city kits.
const WINDOW_COLORS := [Color("d0e8ff"), Color("6794d9"), Color("b5ccec")]
const MASK_SIZE := 128


static func apply(lib: ModelLibrary) -> void:
	var lit_materials := {}
	var masks := {}
	for cat in CATEGORIES:
		for id in lib.ids(cat):
			var mesh := lib.meshes[id]
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				if mat == null or mat.albedo_texture == null:
					continue
				if not lit_materials.has(mat):
					lit_materials[mat] = _lit_copy(mat, masks)
				if lit_materials[mat] != null:
					mesh.surface_set_material(s, lit_materials[mat])


static func _lit_copy(mat: BaseMaterial3D, masks: Dictionary) -> BaseMaterial3D:
	var tex := mat.albedo_texture
	if not masks.has(tex):
		masks[tex] = _mask(tex)
	if masks[tex] == null:
		return null
	var m := mat.duplicate() as BaseMaterial3D
	m.emission_enabled = true
	# Additive emission: black colour + mask, so only the windows glow.
	m.emission = Color.BLACK
	m.emission_texture = masks[tex]
	SignAtlas.register_night(m, 0.0, 1.3)
	return m


## Warm light where the palette has window glass, black elsewhere.
static func _mask(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return null # headless runs have no texture data
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_NEAREST)
	var found := false
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			var c := img.get_pixel(x, y)
			var lit := false
			for w in WINDOW_COLORS:
				if absf(c.r - w.r) + absf(c.g - w.g) + absf(c.b - w.b) < 0.08:
					lit = true
					break
			found = found or lit
			img.set_pixel(x, y, SignAtlas.WINDOW_LIGHT if lit else Color.BLACK)
	return ImageTexture.create_from_image(img) if found else null
