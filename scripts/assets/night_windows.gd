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
	ModelCat.QUARTER_MID: 0.35, ModelCat.QUARTER_TALL: 0.35, ModelCat.POLICE: 0.5,
	ModelCat.STADIUM: 0.75, ModelCat.OUTPOST: 0.25,
	ModelCat.POLICE_MAIN: 0.55, ModelCat.CITY_HALL_MAIN: 0.6, ModelCat.HOSPITAL_MAIN: 0.6,
	ModelCat.SCHOOL_MAIN: 0.45, ModelCat.PHARMACY: 0.55, ModelCat.GAS_STATION: 0.7,
	ModelCat.UN_TOWER: 0.55, ModelCat.CRANE: 0.35, ModelCat.BRIDGE: 0.6,
	ModelCat.BANK_PACK: 0.6, ModelCat.BANK_MIN: 0.6, ModelCat.HOUSE2: 0.35, ModelCat.TOWN2: 0.4,
	ModelCat.SHOP2: 0.5, ModelCat.HOTEL_SMALL: 0.55, ModelCat.HOTEL_PACK: 0.6, ModelCat.HOTEL_LOW: 0.55, ModelCat.MUSEUM_PACK: 0.6,
	ModelCat.CHURCH_PACK: 0.4, ModelCat.GAS_PACK: 0.8, ModelCat.WAREHOUSE: 0.3, ModelCat.FACTORY: 0.45,
	ModelCat.RUIN: 0.3, ModelCat.URBAN: 0.6, ModelCat.MCDONALDS: 0.7, ModelCat.BURGER_KING: 0.6,
	ModelCat.BIZ_RESTAURANT: 0.6, ModelCat.BIZ_SHOP: 0.5, ModelCat.BIZ_PIZZA: 0.6, ModelCat.BIZ_BURGER: 0.6, ModelCat.BIZ_CAFE: 0.6,
	ModelCat.METAL_BRIDGE: 0.4, ModelCat.MANSION: 0.4, ModelCat.PRISON_BLOCK: 0.4, ModelCat.POOR_SLAB: 0.3,
	ModelCat.POOR_BLOCK: 0.3, ModelCat.RUSSIAN: 0.3, ModelCat.STALL: 0.7, ModelCat.POLICE_CAR: 0.3,
	ModelCat.COOLING: 0.3, ModelCat.COOLING_HALL: 0.3, ModelCat.WATCHTOWER: 0.2,
	ModelCat.LIGHTHOUSE_CLUB: 0.45, ModelCat.CHECKPOINT: 0.25,
	# The floodlights (concert camp, prison) shine by themselves at night: no light is added.
	ModelCat.FLOODLIGHT: 1.3,
}
## Neon roof signs: dim by day, very bright at night (they glow in their own colours).
const NEON_PACKS := [ModelCat.NEON_CONTROLLER, ModelCat.NEON_PACMAN, ModelCat.NEON_WOMAN,
		ModelCat.NEON_JOYSTICK, ModelCat.NEON_MARTINI, ModelCat.NEON_BAR,
		ModelCat.NEON_BULL, ModelCat.NEON_FUN, ModelCat.NEON_PALM,
		ModelCat.NEON_CLUB, ModelCat.NEON_GIRL, ModelCat.NEON_LOVE, ModelCat.NEON_LIGHTHOUSE]
## A lit logo keeps its own colours at night (as bright as a neon, they would all turn white).
## The Taiwan signboards are light boxes: only their "board" surface lights up, not the steel.
const LOGO_PACKS := [ModelCat.SIGN_WINDOWS, ModelCat.TW_BANASONIC, ModelCat.TW_MCDONALDS,
		ModelCat.TW_COLA_JP, ModelCat.TW_COLA_BILLBOARD, ModelCat.TW_LED_BOARD, ModelCat.TW_LED_BAND]
## Surfaces of a lit logo whose material starts with this stay unlit (frames, brackets).
const LOGO_DARK := "metal"
const LOGO_DAY := 0.15
const LOGO_NIGHT := 0.9
const NEON_DAY := 0.35
const NEON_NIGHT := 5.0
## Brightness of the halo (a bigger copy added behind the sign) at night.
const HALO_NIGHT := 3.0
## Night packs keep the lights painted in their emission map (a lit facade where they have none).
const NIGHT_PACKS := [ModelCat.URBAN2, ModelCat.NIGHT_TOWER]
## Billboard panels at night: soft warm white, at this brightness.
const BILLBOARD_LIGHT := Color(1.0, 0.96, 0.88)
const BILLBOARD_GLOW := 1.0
## Night duplicates (tools/make_night_variants.py: the pharmacy cross, the police lights, the
## lit words CINEMA, HOTEL, POLICE and CITY HALL, the police roof sign, the hotel stars, the
## blue cross of the hospital, the stadium lit inside only) bring
## their own night map, which holds a third of the final light: off by day, x3 at night.
## A higher value makes the light the lamps throw around them stronger; the lamps themselves
## keep their colour.
const OWN_NIGHT := 3.0


static func apply(lib: ModelLibrary) -> void:
	_apply_kits(lib)
	var done := {}
	for cat in PACK_GLOW:
		for id in lib.ids(cat):
			if not light_own(lib.meshes[id]):
				_light_facade(lib.meshes[id], PACK_GLOW[cat], done)
	# Not lit as a whole: only their night map (the blue beacons of the forest fire truck,
	# the red word CINEMA).
	for cat in [ModelCat.TRUCK_CCF, ModelCat.CINEMA2]:
		for id in lib.ids(cat):
			light_own(lib.meshes[id])
	for cat in [ModelCat.SKYLINE2, ModelCat.FUTURE, ModelCat.NIGHT_SKYLINE]:
		for id in lib.ids(cat):
			_light_skyline(lib.meshes[id], done)
	for cat in NEON_PACKS:
		for id in lib.ids(cat):
			_light_facade(lib.meshes[id], NEON_NIGHT, done, NEON_DAY, true)
			lib.add_named("neon_halo_%d" % cat, _halo(lib.meshes[id]))
	for cat in LOGO_PACKS:
		for id in lib.ids(cat):
			_light_facade(lib.meshes[id], LOGO_NIGHT, done, LOGO_DAY, false, LOGO_DARK)
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
	for id in lib.ids(ModelCat.BILLBOARD):
		light_billboard(lib.meshes[id])


## Billboards: only the flat poster panel lights up at night, lit by its own picture (a blank
## panel glows plain white); the frame stays dark. Returns false when no panel was found.
static func light_billboard(mesh: Mesh) -> bool:
	if mesh.has_meta("night_lit"):
		return mesh.get_meta("night_lit")
	var found := false
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null or not _is_panel(mesh, s):
			continue
		var m := mat.duplicate() as BaseMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED # the park panel is alpha-cut at 1.0
		m.emission_enabled = true
		m.emission = BILLBOARD_LIGHT
		m.emission_texture = mat.albedo_texture
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		SignAtlas.register_night(m, 0.0, BILLBOARD_GLOW)
		mesh.surface_set_material(s, m)
		found = true
	mesh.set_meta("night_lit", found)
	return found


## Models with their own night map (an emission texture): only the map lights up, at
## night. Returns false when the mesh has no such map.
static func light_own(mesh: Mesh) -> bool:
	if mesh.has_meta("own_night"):
		return mesh.get_meta("own_night")
	var lit := {}
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null or mat.emission_texture == null or lit.has(mat):
			continue
		mat.emission_enabled = true
		# The map alone is the light. The importer leaves the emission colour white (the
		# emissiveFactor of the file): added to the map, it would turn the whole model white.
		mat.emission = Color.BLACK
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		# The map has its own texture coordinates when the model brings a second set.
		mat.emission_on_uv2 = (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
		SignAtlas.register_night(mat, 0.0, OWN_NIGHT)
		lit[mat] = true
	mesh.set_meta("own_night", not lit.is_empty())
	return not lit.is_empty()


## A surface whose bounding box is almost flat (thinner than 2% of its width).
static func _is_panel(mesh: Mesh, s: int) -> bool:
	var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return false
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box.size[box.get_shortest_axis_index()] < box.get_longest_axis_size() * 0.02


## Copy of every material of `mesh` whose texture also lights it at night.
## `keep_emission` keeps the emission colour the material already has (neon signs).
static func _light_facade(mesh: Mesh, energy: float, done: Dictionary, day: float = 0.0,
		keep_emission: bool = false, dark: String = "") -> void:
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null or (dark != "" and mat.resource_name.begins_with(dark)):
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


## A copy of a neon sign that only adds light (additive, invisible by day): drawn a bit
## bigger behind the sign it thickens the glow.
static func _halo(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
		var src := mesh.surface_get_material(s) as BaseMaterial3D
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color.BLACK
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		if src != null and src.emission_texture != null:
			m.emission = Color.BLACK
			m.emission_texture = src.emission_texture
		elif src != null:
			m.emission = src.emission if src.emission_enabled else src.albedo_color
		SignAtlas.register_night(m, 0.0, HALO_NIGHT)
		out.surface_set_material(s, m)
	return out


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
