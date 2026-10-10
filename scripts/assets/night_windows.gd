class_name NightWindows
extends RefCounted
## Makes the city visible at night.
## Kenney kits: they colour everything from one small palette texture; its
## window swatches (light and mid blue glass) become an emission mask, so only
## the windows glow. One mask per palette (128x128), materials shared as before.
## Curated packs (photo textures): the facade is softly lit, like floodlit
## buildings; the night skyline keeps the lights painted in its own texture.

const ModelCat := ModelCatalog.Cat
## Kit categories whose windows light up.
const CATEGORIES := [ModelCat.SKYSCRAPER, ModelCat.COMMERCIAL, ModelCat.HOUSE, ModelCat.INDUSTRIAL]
## Palette colours used for window glass in the Kenney city kits.
const WINDOW_COLORS := [Color("d0e8ff"), Color("6794d9"), Color("b5ccec")]
const MASK_SIZE := 128
## Pack categories lit at night -> brightness of the facade.
const PACK_GLOW := {
	ModelCat.TOWER_PHOTO: 0.45, ModelCat.LANDMARK: 0.55, ModelCat.NY_STREET: 0.45,
	ModelCat.NY_MIDRISE: 0.45, ModelCat.PANEL: 0.4, ModelCat.QUARTER_LOW: 0.35,
	ModelCat.QUARTER_MID: 0.35, ModelCat.QUARTER_TALL: 0.35, ModelCat.BIZ_SHOP: 0.45,
	ModelCat.BIZ_PIZZA: 0.45, ModelCat.CINEMA: 0.6, ModelCat.MALL: 0.5, ModelCat.POLICE: 0.5,
	ModelCat.STADIUM: 0.75, ModelCat.OUTPOST: 0.25,
	ModelCat.POLICE_MAIN: 0.55, ModelCat.CITY_HALL_MAIN: 0.6, ModelCat.HOSPITAL_MAIN: 0.6,
	ModelCat.SCHOOL_MAIN: 0.45, ModelCat.PHARMACY: 0.55, ModelCat.GAS_STATION: 0.7,
	ModelCat.UN_TOWER: 0.55, ModelCat.CRANE: 0.35, ModelCat.BRIDGE: 0.6,
	ModelCat.BANK_PACK: 0.6, ModelCat.HOUSE2: 0.35, ModelCat.TOWN2: 0.4,
	ModelCat.SHOP2: 0.5, ModelCat.HOTEL_SMALL: 0.55, ModelCat.HOTEL_PACK: 0.6, ModelCat.MUSEUM_PACK: 0.6,
	ModelCat.CHURCH_PACK: 0.4, ModelCat.GAS_PACK: 0.8, ModelCat.WAREHOUSE: 0.3, ModelCat.FACTORY: 0.45,
	ModelCat.RUIN: 0.3, ModelCat.URBAN: 0.6, ModelCat.MCDONALDS: 0.7, ModelCat.BURGER_KING: 0.6,
	ModelCat.METAL_BRIDGE: 0.4, ModelCat.PIRATE_SHIP: 0.3, ModelCat.MANSION: 0.4, ModelCat.PRISON_BLOCK: 0.4, ModelCat.POOR_SLAB: 0.3,
	ModelCat.POOR_BLOCK: 0.3, ModelCat.RUSSIAN: 0.3, ModelCat.STALL: 0.7, ModelCat.POLICE_CAR: 0.3,
	ModelCat.COOLING: 0.3, ModelCat.COOLING_HALL: 0.3, ModelCat.WATCHTOWER: 0.2,
}
## Neon roof signs: dim by day, very bright at night (they glow in their own colours).
const NEON_PACKS := [ModelCat.NEON_CONTROLLER, ModelCat.NEON_PACMAN]
const NEON_DAY := 0.35
const NEON_NIGHT := 3.0
## Night packs keep the lights painted in their emission map (a lit facade where they have none).
const NIGHT_PACKS := [ModelCat.URBAN2, ModelCat.NIGHT_TOWER]


static func apply(lib: ModelLibrary) -> void:
	_apply_kits(lib)
	var done := {}
	for cat in PACK_GLOW:
		for id in lib.ids(cat):
			_light_facade(lib.meshes[id], PACK_GLOW[cat], done)
	for cat in [ModelCat.SKYLINE, ModelCat.SKYLINE2, ModelCat.FUTURE]:
		for id in lib.ids(cat):
			_light_skyline(lib.meshes[id], done)
	for cat in NEON_PACKS:
		for id in lib.ids(cat):
			_light_facade(lib.meshes[id], NEON_NIGHT, done, NEON_DAY, true)
	for cat in NIGHT_PACKS:
		for id in lib.ids(cat):
			var mesh := lib.meshes[id]
			var has_lights := false
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				has_lights = has_lights or (mat != null and mat.emission_enabled)
			if has_lights:
				_light_skyline(mesh, done)
			else:
				_light_facade(mesh, 0.45, done)


## Copy of every material of `mesh` whose texture also lights it at night.
## `keep_emission` keeps the emission colour the material already has (neon signs).
static func _light_facade(mesh: Mesh, energy: float, done: Dictionary, day: float = 0.0,
		keep_emission: bool = false) -> void:
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null:
			continue
		if not done.has(mat):
			var m := mat.duplicate() as BaseMaterial3D
			m.emission_enabled = true
			if mat.albedo_texture != null:
				m.emission = Color.BLACK
				m.emission_texture = mat.albedo_texture
				m.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
			elif not (keep_emission and mat.emission_enabled):
				m.emission = mat.albedo_color
			SignAtlas.register_night(m, day, energy)
			done[mat] = m
			done[m] = m
		mesh.surface_set_material(s, done[mat])


## The skyline has its city lights in an emission map: dim by day, bright at night.
static func _light_skyline(mesh: Mesh, done: Dictionary) -> void:
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null or done.has(mat) or not mat.emission_enabled:
			continue
		done[mat] = mat
		SignAtlas.register_night(mat, 0.15, 1.6)


static func _apply_kits(lib: ModelLibrary) -> void:
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
