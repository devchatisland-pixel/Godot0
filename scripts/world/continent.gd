class_name Continent
extends Node3D
## Draws the continent of ContinentShaper: its buildings (one MultiMesh per model and chunk,
## coloured boxes instead when the camera is far away, like the city's chunks), its highways
## (flat panels with the highway texture, like FogBase) and the two metal bridges to the fog
## island (the same truss as the west bridge, WestBridge).
## The ground, the coast and the streets are painted by the ground shader from the textures of
## ContinentShaper (GroundLayer).

const Cat := ModelCatalog.Cat
const TEXTURE := preload("res://textures/highway.jpg")
## Cells per chunk of the building batches: a chunk is drawn or skipped as a whole.
const CHUNK := 40.0
## Length of a highway panel (cells), a little longer than its step so bends leave no gap,
## and its height above the ground.
const SEGMENT := 5.0
const OVERLAP := 0.4
const LIFT := 0.04

var _cfg: CityConfig
var _camera: IsoCamera
var _near_root: Node3D
var _far_root: Node3D
var _near_mode := true


func build(cfg: CityConfig, data: CityData, lib: ModelLibrary, camera: IsoCamera) -> void:
	var c := data.continent
	if c == null:
		return
	_cfg = cfg
	_camera = camera
	var placed := _buildings(c, lib)
	_highways(c)
	_bridges(c, lib)
	print("[Continent] %d buildings, %d highways, %d bridges" % [placed, c.highways.size(), c.bridges.size()])


func _process(_delta: float) -> void:
	if _camera == null or _near_root == null:
		return
	var near := _camera.zoom < _cfg.near_lod_size * (1.1 if _near_mode else 1.0)
	if near != _near_mode:
		_near_mode = near
		_near_root.visible = near
		_far_root.visible = not near


# --- Buildings -----------------------------------------------------------------------------------
func _buildings(c: ContinentShaper, lib: ModelLibrary) -> int:
	# Mesh id of every model, by the node name of the pack ("continent_07").
	var ids := {}
	for cat in [Cat.CONTINENT, Cat.CONTINENT2]:
		for id in lib.ids(cat):
			ids[lib.model_name(id).get_slice(": ", 1)] = id
	_near_root = Node3D.new()
	_near_root.name = "Near"
	add_child(_near_root)
	_far_root = Node3D.new()
	_far_root.name = "Far"
	_far_root.visible = false
	add_child(_far_root)
	var near := {}   # chunk -> InstanceBatch
	var far := {}
	var n := 0
	for i in c.b_model.size():
		var name := c.b_model[i]
		if not ids.has(name):
			continue
		var id: int = ids[name]
		var p := c.b_pos[i]
		var s := c.b_scale[i]
		var yaw := c.b_yaw[i]
		var key := Vector2i(int((p.x - ContinentShaper.ORIGIN.x) / CHUNK), int((p.y - ContinentShaper.ORIGIN.y) / CHUNK))
		if not near.has(key):
			near[key] = InstanceBatch.new()
			far[key] = InstanceBatch.new()
		var box := lib.bounds[id]
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s)
		var origin := Vector3(p.x, 0.0, p.y) - basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
		(near[key] as InstanceBatch).add(id, Transform3D(basis, origin))
		var size := box.size * s
		var tone := clampf(0.78 - size.y * 0.035, 0.35, 0.78)
		(far[key] as InstanceBatch).add_box(
				Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), Vector3(p.x, 0.0, p.y)),
				Color(tone, tone * 1.02, tone * 1.08))
		n += 1
	var box_material := StandardMaterial3D.new()
	box_material.vertex_color_use_as_albedo = true
	box_material.roughness = 0.9
	for key: Vector2i in near:
		var a := Node3D.new()
		a.name = "near_%d_%d" % [key.x, key.y]
		_near_root.add_child(a)
		(near[key] as InstanceBatch).build_nodes(a, lib, box_material)
		var b := Node3D.new()
		b.name = "far_%d_%d" % [key.x, key.y]
		_far_root.add_child(b)
		(far[key] as InstanceBatch).build_nodes(b, lib, box_material)
	return n


# --- Highways ---------------------------------------------------------------------------------------
func _highways(c: ContinentShaper) -> void:
	var panels: Array[Transform3D] = []
	for h in c.highways:
		# Walk the curve in steps of SEGMENT cells.
		var i := 0
		while i < h.size() - 1:
			var a := h[i]
			var len := 0.0
			var j := i + 1
			while j < h.size() and len < SEGMENT:
				len += h[j].distance_to(h[j - 1])
				j += 1
			var b := h[j - 1]
			var d := b - a
			var l := d.length()
			if l > 0.05:
				var mid := (a + b) * 0.5
				var basis := Basis(Vector3.UP, atan2(-d.y, d.x)) * Basis.from_scale(
						Vector3(l + OVERLAP, 1.0, ContinentShaper.HIGHWAY_WIDTH))
				panels.append(Transform3D(basis, Vector3(mid.x, LIFT, mid.y)))
			i = j - 1
	if panels.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEXTURE
	mat.roughness = 0.95
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = panels.size()
	for k in panels.size():
		mm.set_instance_transform(k, panels[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Highways"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- Bridges ----------------------------------------------------------------------------------------
## The truss of the west bridge in several spans end to end, from the coast of the fog island
## (`to`) to the coast of the continent (`from`), its deck level with the highway.
func _bridges(c: ContinentShaper, lib: ModelLibrary) -> void:
	var ids := lib.ids(Cat.METAL_BRIDGE)
	if ids.is_empty() or c.bridges.is_empty():
		return
	var box := lib.bounds[ids[0]]
	var along_x := box.size.x >= box.size.z
	var model_len := box.size.x if along_x else box.size.z
	var model_w := box.size.z if along_x else box.size.x
	var centre := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lib.meshes[ids[0]]
	var xforms: Array[Transform3D] = []
	for b in c.bridges:
		var a: Vector2 = b["to"]
		var e: Vector2 = b["from"]
		var d := e - a
		var length := d.length()
		var count := maxi(1, ceili(length / WestBridge.SPAN))
		var span := length / float(count)
		var sx := span / model_len
		var sz := WestBridge.WIDTH / model_w
		var sy := minf(sx, WestBridge.MAX_HEIGHT / box.size.y)
		var turn := Basis(Vector3.UP, atan2(-d.y, d.x)) * (Basis() if along_x else Basis(Vector3.UP, PI * 0.5))
		var basis := turn * Basis.from_scale(Vector3(sx, sy, sz))
		var deck := (box.position.y + WestBridge.DECK_FRACTION * box.size.y) * sy - WestBridge.DECK_LEVEL
		var dir := d / length
		for i in count:
			var at2 := a + dir * (span * (float(i) + 0.5))
			var at := Vector3(at2.x, 0.0, at2.y)
			xforms.append(Transform3D(basis, at - basis * centre - Vector3(0, deck, 0)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ContinentBridges"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
