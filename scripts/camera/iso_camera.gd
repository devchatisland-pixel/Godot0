class_name IsoCamera
extends Camera3D
## Orthographic isometric camera. Only two things are possible: navigate (pan)
## and zoom. Input comes from CameraInput (mouse, touch, trackpad, keyboard).

## Emitted on a click or tap that was not a drag (screen position).
signal tapped(screen_pos: Vector2)
## Right click or tap that was not a drag (developer inspector).
signal right_tapped(screen_pos: Vector2)

const KEY_PAN_SPEED := 1.2      # screens per second
const ZOOM_SMOOTH := 14.0
const INERTIA_DAMP := 6.0

var target := Vector3.ZERO      # point of the ground at the screen centre
var zoom := 60.0                # ortho size (world units visible vertically)
var _zoom_goal := 60.0
var _zoom_anchor := Vector2(-1, -1)
var _velocity := Vector3.ZERO   # pan inertia (world units / s)
var _bounds := Rect2()
var _min_zoom := 8.0
var _max_zoom := 500.0
var _input: CameraInput


func setup(cfg: CityConfig, map_size: int, start: Vector3, start_zoom: float) -> void:
	projection = PROJECTION_ORTHOGONAL
	near = 1.0
	far = 6000.0
	_min_zoom = cfg.min_zoom
	_max_zoom = cfg.max_zoom
	_bounds = Rect2(0, 0, map_size, map_size)
	rotation_degrees = Vector3(cfg.camera_pitch_deg, cfg.camera_yaw_deg, 0.0)
	target = start
	zoom = clampf(start_zoom, _min_zoom, _max_zoom)
	_zoom_goal = zoom
	_input = CameraInput.new(self)
	_input.tapped.connect(func(p: Vector2) -> void: tapped.emit(p))
	_input.right_tapped.connect(func(p: Vector2) -> void: right_tapped.emit(p))
	_apply()


## Area (x, z) the view centre may move in.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if _input != null and _input.handle(event):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _input == null:
		return
	_keyboard(delta)
	# Smooth zoom that keeps the point under the cursor fixed.
	if absf(zoom - _zoom_goal) > 0.001:
		var anchor := _zoom_anchor if _zoom_anchor.x >= 0.0 else get_viewport().get_visible_rect().size * 0.5
		var before := ground_point(anchor)
		zoom = lerpf(zoom, _zoom_goal, 1.0 - exp(-ZOOM_SMOOTH * delta))
		if absf(zoom - _zoom_goal) < 0.01:
			zoom = _zoom_goal
		_apply()
		target += before - ground_point(anchor)
	# Inertia after a drag (mainly for touch screens).
	if not _input.dragging and _velocity.length_squared() > 0.01:
		target += _velocity * delta
		_velocity *= exp(-INERTIA_DAMP * delta)
	_apply()


# --- Navigation API (used by CameraInput) ----------------------------------------------
## Moves the map so that the ground under `from` ends under `to`.
func drag(from: Vector2, to: Vector2, delta: float) -> void:
	var move := ground_point(from) - ground_point(to)
	target += move
	if delta > 0.0:
		_velocity = _velocity.lerp(move / delta, 0.5)
	_apply()


func stop_inertia() -> void:
	_velocity = Vector3.ZERO


## factor < 1 zooms in, > 1 zooms out, around a screen position.
func zoom_at(screen_pos: Vector2, factor: float, smooth: bool = true) -> void:
	_zoom_goal = clampf(_zoom_goal * factor, _min_zoom, _max_zoom)
	_zoom_anchor = screen_pos
	if not smooth:
		var before := ground_point(screen_pos)
		zoom = _zoom_goal
		_apply()
		target += before - ground_point(screen_pos)
		_apply()


func _keyboard(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		var screen := get_viewport().get_visible_rect().size
		var c := screen * 0.5
		var step := dir.normalized() * screen.y * KEY_PAN_SPEED * delta
		target += ground_point(c + step) - ground_point(c)
	var z := 0.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT): z += 1
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD): z -= 1
	if z != 0.0:
		_zoom_anchor = Vector2(-1, -1)
		_zoom_goal = clampf(_zoom_goal * exp(z * 1.6 * delta), _min_zoom, _max_zoom)


# --- Geometry ------------------------------------------------------------------------------
func _apply() -> void:
	target.x = clampf(target.x, _bounds.position.x, _bounds.end.x)
	target.z = clampf(target.z, _bounds.position.y, _bounds.end.y)
	target.y = 0.0
	size = zoom
	var back := global_transform.basis.z
	global_position = target + back * 2500.0


## Intersection of the camera ray through `screen_pos` with the ground plane.
func ground_point(screen_pos: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return target
	var t := -origin.y / dir.y
	return origin + dir * t


## Ground area seen by the camera, as a polygon in cell coordinates (x, z).
func view_polygon(margin_px: float = 64.0) -> PackedVector2Array:
	var r := get_viewport().get_visible_rect()
	var m := Vector2(margin_px, margin_px)
	var corners := [r.position - m, Vector2(r.end.x + m.x, r.position.y - m.y),
			r.end + m, Vector2(r.position.x - m.x, r.end.y + m.y)]
	var out := PackedVector2Array()
	for c in corners:
		var p := ground_point(c)
		out.append(Vector2(p.x, p.z))
	return out
