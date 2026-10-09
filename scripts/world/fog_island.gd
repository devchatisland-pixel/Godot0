class_name FogIsland
extends Node3D
## Draws the island hidden in the fog east of Chat City and the Golden Gate
## bridge that leads to it:
##   - its buildings and palms (a few MultiMeshes, always loaded, small),
##   - the night skyline model in its two downtowns (city lights in the fog),
##   - a fog bank made of painted cloud textures: drifting sheets plus big
##     billows and smoke plumes on camera-facing quads (no 3D volumes),
##   - the "ZONE UNLOCKED ON SEASON 2, COMING SOON" title above it.
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
## Smoke plumes rising from the hidden city (local cells of the fog island).
const PLUMES := [Vector2(70, 40) + FogIslandShaper.SHIFT, Vector2(78, 88) + FogIslandShaper.SHIFT]
## Highest the bridge towers may stand (the model is squashed to keep them slim).
const BRIDGE_HEIGHT := 3.6
## Width of the title in world units and its height above the island.
const TITLE_WIDTH := 84.0
const TITLE_HEIGHT := 3.0

var _materials: Array[ShaderMaterial] = []


func build(cfg: CityConfig, data: CityData, lib: ModelLibrary) -> void:
	var fog := data.fog
	if fog == null:
		return
	var skyline := lib.ids(Cat.SKYLINE)
	_build_buildings(fog, lib, not skyline.is_empty())
	if not skyline.is_empty():
		_build_skylines(fog, lib, skyline[0])
	_build_bridge(data, lib)
	_build_layers(fog)
	_build_puffs(fog, 60 if cfg.is_mobile else 120)
	_build_title(fog)


func set_night(amount: float) -> void:
	for m in _materials:
		m.set_shader_parameter("night", amount)


# --- Buildings and trees -------------------------------------------------------------------
func _build_buildings(fog: FogIslandShaper, lib: ModelLibrary, has_skyline: bool) -> void:
	var pools := [_union(lib, [Cat.TOWER_PHOTO, Cat.SKYSCRAPER]),
			_union(lib, [Cat.COMMERCIAL, Cat.NY_MIDRISE]), lib.ids(Cat.HOUSE)]
	var groups := {}
	for b in fog.buildings:
		var p: Vector2 = b[0]
		var kind: int = b[1]
		var h: int = b[2]
		if has_skyline and kind < 2 and _near_downtown(fog, p, 13.0):
			continue # the skyline model stands there
		var pool: PackedInt32Array = pools[kind]
		if pool.is_empty():
			continue
		var id := pool[h % pool.size()]
		var s := 1.2 if kind == 0 else 1.0
		var t := Transform3D(Basis(Vector3.UP, float(h & 3) * PI * 0.5).scaled(Vector3(s, s, s)),
				Vector3(p.x, 0, p.y))
		_add(groups, id, t)
	var palm := lib.named_id("palm")
	var trees := lib.ids(Cat.TREE)
	for tr in fog.trees:
		var p: Vector2 = tr[0]
		var h: int = tr[2]
		var id := palm if tr[1] or trees.is_empty() else trees[h % trees.size()]
		var s := 1.0 + float(h & 7) * 0.08
		_add(groups, id, Transform3D(Basis(Vector3.UP, float(h & 63) * 0.1).scaled(Vector3(s, s, s)),
				Vector3(p.x, 0, p.y)))
	for id in groups:
		_multimesh(lib.meshes[id], groups[id])


func _near_downtown(fog: FogIslandShaper, p: Vector2, r: float) -> bool:
	for cl in FogIslandShaper.CLUSTERS:
		if cl["towers"] and p.distance_to(fog.origin + FogIslandShaper.cluster_at(cl)) < r:
			return true
	return false


## The night skyline model in both downtowns, turned differently.
func _build_skylines(fog: FogIslandShaper, lib: ModelLibrary, id: int) -> void:
	var box := lib.bounds[id]
	var k := 0
	for cl in FogIslandShaper.CLUSTERS:
		if not cl["towers"]:
			continue
		var at: Vector2 = fog.origin + FogIslandShaper.cluster_at(cl)
		var basis := Basis(Vector3.UP, PI * 0.5 * k)
		var center := Vector3(box.get_center().x, 0, box.get_center().z)
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[id]
		mi.transform = Transform3D(basis, Vector3(at.x, 0, at.y) - basis * center)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		k += 1


# --- Golden Gate bridge -----------------------------------------------------------------------
func _build_bridge(data: CityData, lib: ModelLibrary) -> void:
	var fog := data.fog
	if data.bridge.x < 0 or fog.bridge_land_x < 0.0:
		return
	var x0 := float(data.bridge.x) - 0.6
	var x1 := fog.bridge_land_x + 1.0
	var z := float(data.bridge.y) + 0.5
	var ids := lib.ids(Cat.BRIDGE)
	if ids.is_empty():
		return
	var box := lib.bounds[ids[0]]
	# The model runs along its longest side; turn it to run along X.
	var along_x := box.size.x >= box.size.z
	var length := box.size.x if along_x else box.size.z
	var s := (x1 - x0) / length
	var sy := minf(s, BRIDGE_HEIGHT / box.size.y)
	# The deck is as wide as the three-lane highway that leads to it.
	var width := 3.0 / (box.size.z if along_x else box.size.x)
	var basis := (Basis() if along_x else Basis(Vector3.UP, PI * 0.5)) * Basis.from_scale(Vector3(s, sy, width))
	var center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var mi := MeshInstance3D.new()
	mi.name = "GoldenGate"
	mi.mesh = lib.meshes[ids[0]]
	mi.transform = Transform3D(basis, Vector3((x0 + x1) * 0.5, 0.0, z) - basis * center)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_build_checkpoint(lib, x0 + 0.5, z)


## Orange-and-white triangle barriers and cones close the highway before the bridge.
func _build_checkpoint(lib: ModelLibrary, x: float, z: float) -> void:
	var groups := {}
	var barriers := lib.ids(Cat.BARRIER)
	var cones := lib.ids(Cat.CONE)
	if not barriers.is_empty():
		for i in 4:
			var t := Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(2.6, 2.6, 2.6)),
					Vector3(x - 0.5, 0.0, z - 1.1 + i * 0.75))
			_add(groups, barriers[i % barriers.size()], t)
	if not cones.is_empty():
		for i in 7:
			_add(groups, cones[0], Transform3D(Basis().scaled(Vector3(3.6, 3.6, 3.6)),
					Vector3(x - 1.4 - float(i % 2) * 0.4, 0.0, z - 1.3 + i * 0.45)))
	for id in groups:
		_multimesh(lib.meshes[id], groups[id])


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
		_materials.append(m)
		var plane := PlaneMesh.new()
		plane.size = radius * 2.6
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = m
		mi.position = Vector3(c.x, l[0], c.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


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


# --- Helpers ---------------------------------------------------------------------------------------
func _add(groups: Dictionary, id: int, t: Transform3D) -> void:
	if id < 0:
		return
	if not groups.has(id):
		groups[id] = []
	groups[id].append(t)


func _multimesh(mesh: Mesh, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _union(lib: ModelLibrary, cats: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in cats:
		out.append_array(lib.ids(c))
	return out
