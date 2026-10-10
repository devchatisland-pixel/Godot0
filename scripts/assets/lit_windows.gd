class_name LitWindows
extends RefCounted
## Lit windows at night for the main public buildings, the cinema, the shopping centre and
## the hotels. Their textures are small palettes of flat colours, so the windows are found
## by colour and written into an emission texture of the same size: dark glass lights up
## warm, blue and cyan glass cool, and the teal cross of the pharmacy glows green.
## Everything else stays unlit (the facade is no longer lit as a whole, as before).

const Cat := ModelCatalog.Cat
const CATS := [Cat.CITY_HALL_MAIN, Cat.POLICE_MAIN, Cat.HOSPITAL_MAIN, Cat.SCHOOL_MAIN,
		Cat.PHARMACY, Cat.CINEMA2, Cat.MALL, Cat.HOTEL_PACK, Cat.HOTEL_SMALL]
const WARM := Color(1.0, 0.82, 0.45)
const COOL := Color(0.65, 0.88, 1.0)
const GREEN := Color(0.15, 1.0, 0.45)
## Brightness of the windows at night (0 by day).
const NIGHT := 2.4


static func apply(lib: ModelLibrary) -> void:
	var done := {}
	for cat in CATS:
		for id in lib.ids(cat):
			var mesh := lib.meshes[id]
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				if mat == null:
					continue
				if not done.has(mat):
					done[mat] = _lit_copy(mat)
				if done[mat] != null:
					mesh.surface_set_material(s, done[mat])


## A copy of `mat` that also emits from its windows, or null when it has none.
static func _lit_copy(mat: BaseMaterial3D) -> BaseMaterial3D:
	var m := mat.duplicate() as BaseMaterial3D
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	if mat.albedo_texture != null:
		var mask := _mask(mat.albedo_texture)
		if mask == null:
			return null
		m.emission = Color.WHITE
		m.emission_texture = mask
	else:
		# Untextured models: the light blue surfaces are the glass.
		var c := mat.albedo_color
		if not (c.b > c.r + 0.04 and c.b > 0.9 and c.g > 0.75):
			return null
		m.emission = WARM
	SignAtlas.register_night(m, 0.0, NIGHT)
	return m


## Emission colour of a texel: the window colour, or black.
static func window_color(c: Color) -> Color:
	var hi := maxf(c.r, maxf(c.g, c.b))
	var lo := minf(c.r, minf(c.g, c.b))
	# Teal of the pharmacy cross.
	if c.r < 0.1 and c.g > 0.4 and c.g < 0.6 and c.b > 0.3 and c.b < 0.45:
		return GREEN
	# Dark, grey glass.
	if hi < 0.3 and lo > 0.06 and hi - lo < 0.12:
		return WARM
	# Blue and cyan glass.
	if c.r < 0.45 and c.b > 0.45 and c.g > 0.45 and absf(c.g - c.b) < 0.18:
		return COOL
	if c.r < 0.15 and c.b > 0.7 and c.g < 0.45:
		return COOL
	return Color.BLACK


static func _mask(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return null # headless runs without a renderer have no texture data
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var lit := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := window_color(img.get_pixel(x, y))
			lit += int(c != Color.BLACK)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img) if lit > 0 else null
