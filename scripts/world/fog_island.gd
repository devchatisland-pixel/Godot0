class_name FogIsland
extends Node3D
## Draws the island hidden in the fog east of Chat City and the metal
## bridge that leads to it:
##   - a fog bank made of painted cloud textures: drifting sheets plus big
##     billows and smoke plumes on camera-facing quads (no 3D volumes),
##   - the "ZONE UNLOCKED ON SEASON 2, COMING SOON" title above it (switched off: SHOW_TITLE).
## DayNight darkens the fog through `set_night`.

const LAYER_SHADER := preload("res://shaders/fog_layer.gdshader")
const PUFF_SHADER := preload("res://shaders/fog_puff.gdshader")
const NOISE_TEX := preload("res://textures/fog_noise.png")
const PUFF_TEX := preload("res://textures/fog_puffs.png")
const TITLE_TEX := preload("res://textures/season2.png")
const Cat := ModelCatalog.Cat

## Fog sheets: height, density, texture scale, seed.
const LAYERS := [
	[0.5, 1.0, 0.03, 0.0], [2.2, 0.95, 0.022, 0.31], [4.5, 0.9, 0.017, 0.57], [8.0, 0.7, 0.012, 0.83],
]
## Smoke plume rising from the nuclear plant of the base (local cells of the fog island).
const PLUMES := [Vector2(118, 116)]
## The "SEASON 2" title over the island: no longer shown.
const SHOW_TITLE := false
## The fog bank, its billows and the smoke plume: no longer drawn, the sky over the island
## is clear so that the military base shows.
const SHOW_FOG := false
## Width of the title in world units and its height above the island.
const TITLE_WIDTH := 84.0
const TITLE_HEIGHT := 3.0

var _materials: Array[ShaderMaterial] = []
## x range and row of the bridge, kept free of fog.
var _clear := Vector3(-1000.0, -1000.0, 0.0)
## Clear radius around the bridge (cells) and how wide the fog fades back in.
const CLEAR_RADIUS := 6.0
## How wide the fog fades back in around that clear strip.
const CLEAR_FADE := 9.0


func build(cfg: CityConfig, data: CityData, lib: ModelLibrary) -> void:
	var fog := data.fog
	if fog == null:
		return
	_build_bridge(data, lib)
	if SHOW_FOG:
		_build_layers(fog)
		_build_puffs(fog, 60 if cfg.is_mobile else 120)
	if SHOW_TITLE:
		_build_title(fog)


func set_night(amount: float) -> void:
	for m in _materials:
		m.set_shader_parameter("night", amount)


# --- Bridge to the fog island ------------------------------------------------------------------
## The same metal truss as the west bridge (WestBridge), several spans end to end.
func _build_bridge(data: CityData, lib: ModelLibrary) -> void:
	var fog := data.fog
	if data.bridge.x < 0 or fog.bridge_land_x < 0.0:
		return
	# From the start of the last highway cell: the deck covers the end of the road there.
	var x0 := float(data.bridge.x) - 1.0
	var x1 := fog.bridge_land_x + 1.0
	var z := float(data.bridge.y) + 0.5
	var ids := lib.ids(Cat.METAL_BRIDGE)
	if ids.is_empty():
		return
	var box := lib.bounds[ids[0]]
	var count := maxi(1, ceili((x1 - x0) / WestBridge.SPAN))
	var span := (x1 - x0) / float(count)
	var along_x := box.size.x >= box.size.z
	var model_len := box.size.x if along_x else box.size.z
	var model_w := box.size.z if along_x else box.size.x
	var sx := span / model_len
	var sz := WestBridge.WIDTH / model_w
	var sy := minf(sx, WestBridge.MAX_HEIGHT / box.size.y)
	var basis := (Basis() if along_x else Basis(Vector3.UP, PI * 0.5)) * Basis.from_scale(Vector3(sx, sy, sz))
	var center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var deck := (box.position.y + WestBridge.DECK_FRACTION * box.size.y) * sy - WestBridge.DECK_LEVEL
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lib.meshes[ids[0]]
	mm.instance_count = count
	for k in count:
		var at := Vector3(x0 + span * (float(k) + 0.5), 0.0, z)
		mm.set_instance_transform(k, Transform3D(basis, at - basis * center - Vector3(0, deck, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FogBridge"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Only the span over the water stays clear: the fog covers the island itself from its coast.
	_clear = Vector3(x0 - 4.0, x1 - 10.0, z)


# --- Fog ------------------------------------------------------------------------------------------
func _build_layers(fog: FogIslandShaper) -> void:
	var c := fog.center()
	var radius := Vector2(FogIslandShaper.SIZE, FogIslandShaper.SIZE) * 0.5 * Vector2(0.8, 0.7)
	for l in LAYERS:
		var m := ShaderMaterial.new()
		m.shader = LAYER_SHADER
		m.set_shader_parameter("noise_tex", NOISE_TEX)
		m.set_shader_parameter("center", c)
		m.set_shader_parameter("radius", radius)
		m.set_shader_parameter("density", l[1])
		m.set_shader_parameter("scale", l[2])
		m.set_shader_parameter("seed", l[3])
		m.set_shader_parameter("clear_seg", _clear)
		m.set_shader_parameter("clear_radius", CLEAR_RADIUS)
		m.set_shader_parameter("clear_fade", CLEAR_FADE)
		_materials.append(m)
		var plane := PlaneMesh.new()
		plane.size = radius * 2.6
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = m
		mi.position = Vector3(c.x, l[0], c.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _near_bridge(p: Vector2, margin: float) -> bool:
	var dx := maxf(maxf(_clear.x - p.x, p.x - _clear.y), 0.0)
	return Vector2(dx, p.y - _clear.z).length() < CLEAR_RADIUS + margin * 0.35


## Big billows over the island (thicker towards the bridge) and smoke plumes.
func _build_puffs(fog: FogIslandShaper, count: int) -> void:
	var c := fog.center()
	var radius := Vector2(52, 46) * float(FogIslandShaper.SIZE) / 128.0
	var puffs := [] # [position, size, picture, opacity, darkness]
	for i in count:
		var h := CityTypes.hash2(i, 31, 7)
		var a := float(h & 1023) / 1024.0 * TAU
		var d := sqrt(float((h >> 10) & 1023) / 1024.0)
		var p := c + Vector2(cos(a), sin(a)) * radius * d * 1.05
		if i % 4 == 0:
			p.x = c.x - radius.x * (0.75 + 0.3 * float((h >> 20) & 15) / 15.0)
		var y := 1.0 + float((h >> 3) & 7) * 1.1
		var size := 18.0 + float((h >> 6) & 15) * 1.2
		if _near_bridge(p, size + y * 1.5):
			continue
		puffs.append([Vector3(p.x, y, p.y), size, h % 4, 0.6 + float((h >> 12) & 3) * 0.08,
				0.45 if i % 5 == 0 else 0.0])
	for k in PLUMES.size():
		var base: Vector2 = fog.origin + PLUMES[k]
		for j in 7:
			var drift := Vector2(j * 1.4, -j * 0.6)
			puffs.append([Vector3(base.x + drift.x, 2.0 + j * 2.6, base.y + drift.y),
					8.0 + j * 2.5, (j + k) % 4, 0.85 - j * 0.07, 0.75 - j * 0.06])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = puffs.size()
	for i in puffs.size():
		var pf: Array = puffs[i]
		var s: float = pf[1]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), pf[0]))
		mm.set_instance_custom_data(i, Color(float(pf[2]) / 4.0, float(i % 17) / 17.0, pf[3], pf[4]))
	var m := ShaderMaterial.new()
	m.shader = PUFF_SHADER
	m.set_shader_parameter("puff_tex", PUFF_TEX)
	m.render_priority = 1
	_materials.append(m)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Quads are turned to the camera in the shader: give a box that holds them all.
	var half := 135.0
	mmi.custom_aabb = AABB(Vector3(c.x - half, -10, c.y - half), Vector3(half * 2.0, 60, half * 2.0))
	add_child(mmi)


func _build_title(fog: FogIslandShaper) -> void:
	var c := fog.center()
	var title := Sprite3D.new()
	title.name = "Season2"
	title.texture = TITLE_TEX
	title.pixel_size = TITLE_WIDTH / float(TITLE_TEX.get_width())
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.shaded = false
	title.render_priority = 10
	title.position = Vector3(c.x, TITLE_HEIGHT, c.y)
	add_child(title)
