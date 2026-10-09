class_name SignAtlas
extends RefCounted
## The sheet of signs (textures/signs.png, made by tools/make_sign_atlas.py)
## and the materials that glow at night. The DayNight node drives the
## emission of every material listed by `night_materials()`.

const TEXTURE := preload("res://textures/signs.png")
const SIZE := 1024.0

## name -> pixel rectangle; must match tools/make_sign_atlas.py
const REGIONS := {
	"un_emblem": Rect2(0, 0, 256, 256),
	"dollar": Rect2(256, 0, 256, 256),
	"sign_post": Rect2(512, 0, 512, 128),
	"sign_museum": Rect2(512, 128, 512, 128),
	"neon_xxx": Rect2(0, 256, 512, 256),
	"neon_casino": Rect2(512, 256, 512, 256),
	"sign_hotel": Rect2(0, 512, 512, 128),
	"neon_bar": Rect2(0, 640, 512, 128),
	"sign_bank": Rect2(512, 512, 512, 128),
	"sign_prison": Rect2(512, 640, 512, 128),
	"movie": Rect2(0, 768, 512, 256),
	"neon_club": Rect2(512, 768, 512, 128),
	"sign_un": Rect2(512, 896, 512, 128),
}

## Warm light of lit windows and lamps.
const WINDOW_LIGHT := Color(1.0, 0.82, 0.5)

static var _sign_material: StandardMaterial3D
static var _window_material: StandardMaterial3D
static var _bulb_material: StandardMaterial3D
## [material, day energy, night energy]
static var _night: Array = []


## UV rectangle (0..1) of a region.
static func uv(name: String) -> Rect2:
	var r: Rect2 = REGIONS[name]
	return Rect2(r.position / SIZE, r.size / SIZE)


## Width / height of a region, to size panels without stretching.
static func aspect(name: String) -> float:
	var r: Rect2 = REGIONS[name]
	return r.size.x / r.size.y


## Signs: textured, slightly glowing by day, bright at night.
static func sign_material() -> StandardMaterial3D:
	if _sign_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = TEXTURE
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.emission_enabled = true
		m.emission_texture = TEXTURE
		# Additive emission: black colour + texture, so each sign glows in its own colours.
		m.emission = Color.BLACK
		m.roughness = 0.8
		_sign_material = m
		register_night(m, 0.25, 1.4)
	return _sign_material


## Windows of the procedural buildings: dark by day, warm light at night.
static func window_material() -> StandardMaterial3D:
	if _window_material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.emission_enabled = true
		m.emission = WINDOW_LIGHT
		m.roughness = 0.4
		_window_material = m
		register_night(m, 0.0, 1.6)
	return _window_material


## Lamp bulbs and floodlights: pale by day, bright at night.
static func bulb_material() -> StandardMaterial3D:
	if _bulb_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.95, 0.8)
		m.emission_enabled = true
		m.emission = WINDOW_LIGHT
		_bulb_material = m
		register_night(m, 0.0, 3.0)
	return _bulb_material


static func register_night(m: BaseMaterial3D, day: float, night: float) -> void:
	_night.append([m, day, night])
	m.emission_energy_multiplier = day


static func night_materials() -> Array:
	return _night
