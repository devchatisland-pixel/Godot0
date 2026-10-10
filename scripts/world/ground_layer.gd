class_name GroundLayer
extends Node3D
## The island ground and the sea. Two small textures (one texel per cell) and
## a single plane replace millions of tiles: cheap on memory and draw calls.

const GROUND_SHADER := preload("res://shaders/ground.gdshader")

const ROAD := Color("5c6070")
const AVENUE := Color("50546a")
const GRASS := Color("8cc56b")
const FOREST := Color("5c9d4c")
const ZONE_COLORS := {
	CityTypes.Zone.NONE: Color("8cc56b"),
	CityTypes.Zone.NATURE: Color("8cc56b"),
	CityTypes.Zone.PARK: Color("7cc35d"),
	CityTypes.Zone.DOWNTOWN: Color("cfcbdc"),
	CityTypes.Zone.COMMERCIAL: Color("d3cfdd"),
	CityTypes.Zone.APARTMENT: Color("a9cf8c"),
	CityTypes.Zone.SUBURBAN: Color("9fd27c"),
	CityTypes.Zone.INDUSTRIAL: Color("b5afa2"),
	CityTypes.Zone.CIVIC: Color("d8d3c4"),
	CityTypes.Zone.DESERT: Color("e3b56a"),
	CityTypes.Zone.ENTERTAINMENT: Color("8f88a6"),
	CityTypes.Zone.ISLET: Color("86c867"),
	CityTypes.Zone.QUARTER: Color("e2dacb"),
	CityTypes.Zone.PRISON: Color("a9a59b"),
	CityTypes.Zone.POOR: Color("bdb7ab"),
	CityTypes.Zone.FARM: Color("a6b45c"),
	CityTypes.Zone.URBAN: Color("8f929c"),
	CityTypes.Zone.SAND: Color("ead9a4"),
}

## Paths of the park, the boardwalk, and the dry grass where the desert blends into the meadows.
const PATH := Color("e6d9b0")
const BOARDWALK := Color("a8794a")
const DRY_GRASS := Color("c7bb78")

## Sea colour, also used as background so the ocean looks endless.
const DEEP_SEA := Color(0.16, 0.45, 0.66)

var _material: ShaderMaterial


func build(cfg: CityConfig, data: CityData) -> void:
	var size := float(data.size)
	_material = ShaderMaterial.new()
	_material.shader = GROUND_SHADER
	_material.set_shader_parameter("elevation_tex", _elevation_texture(data))
	_material.set_shader_parameter("zone_tex", _zone_texture(data))
	_material.set_shader_parameter("beach_level", cfg.beach_width)
	_material.set_shader_parameter("shallow_level", cfg.shallow_width)
	_material.set_shader_parameter("deep_color", DEEP_SEA)

	_material.set_shader_parameter("map_size", size)
	if data.fog != null:
		var fog := data.fog
		var n := FogIslandShaper.SIZE
		_material.set_shader_parameter("fog_elevation_tex", ImageTexture.create_from_image(
				Image.create_from_data(n, n, false, Image.FORMAT_L8, fog.elevation)))
		_material.set_shader_parameter("fog_zone_tex", ImageTexture.create_from_image(
				Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, fog.colors)))
		_material.set_shader_parameter("fog_origin", fog.origin)
		_material.set_shader_parameter("fog_size", float(n))

	# One plane for island and sea; it reaches far beyond the map so the ocean
	# looks endless at any zoom.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 14.0, size * 14.0)
	ground.mesh = plane
	ground.material_override = _material
	ground.position = Vector3(size * 0.5, 0.0, size * 0.5)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.name = "IslandAndSea"
	add_child(ground)


func _elevation_texture(data: CityData) -> ImageTexture:
	var img := Image.create_from_data(data.size, data.size, false, Image.FORMAT_L8, data.elevation)
	return ImageTexture.create_from_image(img)


func _zone_texture(data: CityData) -> ImageTexture:
	var n := data.size * data.size
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	var lut := []
	for z in ZONE_COLORS:
		while lut.size() <= z:
			lut.append(GRASS)
		lut[z] = ZONE_COLORS[z]
	for i in n:
		var c: Color
		var road: int = data.road[i]
		if road != 0:
			c = AVENUE if (road & 3) == CityTypes.ROAD_AVENUE else ROAD
		else:
			var z: int = data.zone[i]
			c = lut[z]
			if z == CityTypes.Zone.NATURE:
				c = GRASS.lerp(FOREST, float(data.forest[i]) / 255.0)
			var deco: int = data.deco[i]
			if deco == AmenitiesPlanner.PATH:
				c = PATH
			elif deco == AmenitiesPlanner.BOARD or deco == AmenitiesPlanner.BOARD_LAMP:
				c = BOARDWALK
			elif data.edge[i] != 0:
				# Patchy: the dry colour reaches further in some places than in others.
				var patch := 0.35 + 0.65 * CityTypes.hashf(i % data.size, i / data.size, 77)
				var t := float(data.edge[i] & 15) / 4.0 * patch
				c = c.lerp(DRY_GRASS, t * (0.8 if (data.edge[i] & 0x80) != 0 else 1.0))
		bytes[i * 4] = c.r8
		bytes[i * 4 + 1] = c.g8
		bytes[i * 4 + 2] = c.b8
		# Alpha 0 = rocky shore instead of sand.
		bytes[i * 4 + 3] = 0 if data.rocky[i] == 1 else (128 if data.rocky[i] == 2 else 255)
	var img := Image.create_from_data(data.size, data.size, false, Image.FORMAT_RGBA8, bytes)
	return ImageTexture.create_from_image(img)
