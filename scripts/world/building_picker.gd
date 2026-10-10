class_name BuildingPicker
extends Node
## Makes every building clickable. A click (or tap) that is not a drag casts the camera
## ray against the buildings; the nearest one hit is selected:
##   - it glows (a pulsing skin over the building, a frame and a wave on the ground,
##     a bobbing arrow above it, always visible),
##   - an information bubble opens over it (BuildingPopup),
##   - `building_selected` is emitted with the info Dictionary (see BuildingInfo), so
##     that a database or game logic can react to a precise building later.
## Clicking elsewhere, Esc or the X of the bubble clears the selection.

signal building_selected(info: Dictionary)
signal selection_cleared

const OVERLAY := preload("res://shaders/selection_overlay.gdshader")
const RING := preload("res://shaders/selection_ring.gdshader")
## Highest building the quick test allows for (cells); the exact test uses the real model.
const COARSE_HEIGHT := 45.0
## Height of fillers without a model (plazas, gardens, yards).
const FLAT_HEIGHT := 0.6
## Props are small and thin: their hit box is a little fatter than the model (cells), and
## they win over the building under them by this much (cells of distance).
const PROP_MARGIN := 0.12
const PROP_BIAS := 2.0

## Building id of the selection (-1 when none, or when a prop is selected).
var selected := -1
## Selectable things that are not city buildings (vehicles, barriers...), added with `add_prop`.
var props: Array[Dictionary] = []
var _has_selection := false

var _cam: IsoCamera
var _data: CityData
var _lib: ModelLibrary
var _popup: BuildingPopup
var _fx := Node3D.new()
var _overlay: MeshInstance3D
var _ring: MeshInstance3D
var _arrow: MeshInstance3D
var _entry := {}
var _box := AABB()
var _footprint := Vector2.ONE


func setup(cam: IsoCamera, data: CityData, lib: ModelLibrary) -> void:
	_cam = cam
	_data = data
	_lib = lib
	_cam.tapped.connect(_on_tap)
	_popup = BuildingPopup.new()
	add_child(_popup)
	_popup.closed.connect(clear)
	_fx.name = "SelectionFx"
	add_child(_fx)
	_build_fx()
	_fx.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _has_selection:
		clear()


func _on_tap(screen_pos: Vector2) -> void:
	var hit := pick(screen_pos)
	if hit.is_empty():
		clear()
	else:
		select(hit)


# --- Picking ---------------------------------------------------------------------------------
## Makes a loose model selectable (vehicle, barrier...). `info` follows BuildingInfo, plus
## `box` (world AABB), `mesh` and `xform` (to make it glow).
func add_prop(info: Dictionary) -> void:
	info["id"] = 100000 + props.size()
	info["uid"] = "P-%05d" % (props.size() + 1)
	props.append(info)


## The thing under a screen position: an entry {info, box, mesh, xform, footprint}, or {}.
func pick(screen_pos: Vector2) -> Dictionary:
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var best := {}
	var best_t := INF
	for i in _data.building_count():
		var r := _data.building_rect(i)
		var coarse := AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, COARSE_HEIGHT, r.size.y))
		if coarse.intersects_ray(from, dir) == null:
			continue
		var e := _building_entry(i)
		var hit = (e["box"] as AABB).intersects_ray(from, dir)
		if hit != null:
			var t := from.distance_to(hit)
			if t < best_t:
				best_t = t
				best = e
	for p in props:
		# Props are small: they win over the building they stand on when they are hit.
		var hit = (p["box"] as AABB).grow(PROP_MARGIN).intersects_ray(from, dir)
		if hit != null:
			var t := from.distance_to(hit) - PROP_BIAS
			if t < best_t:
				best_t = t
				best = {"info": p, "box": p["box"], "mesh": p.get("mesh"), "xform": p.get("xform", Transform3D()),
						"footprint": Vector2(p["size"])}
	return best


## Entry of building `i`: its info, world box and the mesh that glows.
func _building_entry(i: int) -> Dictionary:
	var r := _data.building_rect(i)
	var e := {"footprint": Vector2(r.size), "mesh": null, "xform": Transform3D()}
	var box := AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, FLAT_HEIGHT, r.size.y))
	if _data.b_kind[i] == CityTypes.Kind.INDUSTRIAL_YARD:
		var yard := BuildingPlacer.yard_content(_lib, r, _data.b_seed[i])
		if not yard.is_empty():
			box.size.y = maxf(FLAT_HEIGHT, float(yard["height"]))
			if yard.has("xform"):
				e["mesh"] = _lib.meshes[yard["id"]]
				e["xform"] = yard["xform"]
	else:
		var pk := BuildingPlacer.pick_for(_data, _lib, i)
		if not pk.is_empty():
			var xform: Transform3D = pk["xform"]
			box = xform * _lib.bounds[pk["id"]]
			e["mesh"] = _lib.meshes[pk["id"]]
			e["xform"] = xform
	e["box"] = box
	e["building"] = i
	return e


# --- Selection ---------------------------------------------------------------------------------
func select(e: Dictionary) -> void:
	_has_selection = true
	_entry = e
	selected = e.get("building", -1)
	_box = e["box"]
	_footprint = e["footprint"]
	var info: Dictionary
	if selected >= 0:
		info = BuildingInfo.describe(_data, _lib, selected)
	else:
		info = e["info"]
	_show_fx(e)
	_popup.show_info(info)
	building_selected.emit(info)


func clear() -> void:
	if not _has_selection:
		return
	_has_selection = false
	selected = -1
	_fx.visible = false
	_popup.hide_popup()
	selection_cleared.emit()


func _process(_delta: float) -> void:
	if not _has_selection:
		return
	var zs := _zoom_scale()
	var c := _box.get_center()
	var top := _box.end.y
	_popup.set_anchor(_cam.unproject_position(Vector3(c.x, top + 0.8 * zs, c.z)))
	# Bobbing arrow, a little bigger when zoomed out so that it stays easy to see.
	var bob := sin(Time.get_ticks_msec() * 0.005) * 0.35 * zs
	_arrow.position = Vector3(c.x, top + 1.6 * zs + bob, c.z)
	_arrow.scale = Vector3.ONE * zs
	_arrow.rotation.y += _delta * 1.8
	var size := maxf(_footprint.x, _footprint.y) + 8.0 * zs
	var quad := _ring.mesh as QuadMesh
	quad.size = Vector2(size, size)
	var mat := _ring.material_override as ShaderMaterial
	mat.set_shader_parameter("half_size", _footprint * 0.5 / size)
	mat.set_shader_parameter("thickness", 0.16 * zs / size)


## 1 when zoomed in, more when zoomed out.
func _zoom_scale() -> float:
	return clampf(_cam.zoom / 55.0, 1.0, 6.0)


func _show_fx(e: Dictionary) -> void:
	_fx.visible = true
	if e["mesh"] == null:
		_overlay.visible = false
	else:
		_overlay.visible = true
		_overlay.mesh = e["mesh"]
		_overlay.transform = e["xform"]
	var c := _box.get_center()
	_ring.position = Vector3(c.x, 0.07, c.z)


func _build_fx() -> void:
	_overlay = MeshInstance3D.new()
	var glow := ShaderMaterial.new()
	glow.shader = OVERLAY
	_overlay.material_override = glow
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(_overlay)

	_ring = MeshInstance3D.new()
	_ring.mesh = QuadMesh.new()
	_ring.rotation_degrees = Vector3(-90, 0, 0)
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = RING
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(_ring)

	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 0.0
	cone.height = 1.3
	cone.radial_segments = 4
	_arrow.mesh = cone
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.albedo_color = Color(1.0, 0.72, 0.18)
	arrow_mat.no_depth_test = true
	arrow_mat.render_priority = 5
	_arrow.material_override = arrow_mat
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.add_child(_arrow)
