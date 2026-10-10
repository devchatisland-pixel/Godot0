class_name CameraInput
extends RefCounted
## Translates raw input into camera navigation:
##   mouse  - drag with any button to pan, wheel to zoom at the cursor
##   touch  - one finger pans, two fingers pinch-zoom (and pan)
##   trackpad - two-finger scroll pans, pinch zooms

const WHEEL_STEP := 1.15
## A press that moves less than this many pixels, and ends within TAP_TIME, is a tap (a click).
const TAP_SLOP := 10.0
const TAP_TIME := 0.45

## Emitted when the user taps / clicks without dragging (screen position).
signal tapped(position: Vector2)
## Same for the right button (developer inspector: which cell / parcel is under the cursor).
signal right_tapped(position: Vector2)

var _cam: IsoCamera
var _touches := {}          # index -> position
var _pinch_distance := 0.0
var _mouse_drag := false
var _last_time := 0
var dragging := false
var _press_moved := 0.0
var _press_time := 0
var _touch_multi := false


func _init(cam: IsoCamera) -> void:
	_cam = cam


func handle(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return _on_touch(event)
	if event is InputEventScreenDrag:
		return _on_touch_drag(event)
	if event is InputEventMouseButton:
		return _on_mouse_button(event)
	if event is InputEventMouseMotion:
		return _on_mouse_motion(event)
	if event is InputEventMagnifyGesture:
		var g := event as InputEventMagnifyGesture
		_cam.zoom_at(g.position, 1.0 / maxf(g.factor, 0.01), false)
		return true
	if event is InputEventPanGesture:
		var p := event as InputEventPanGesture
		_cam.drag(p.position, p.position - p.delta * 12.0, 0.0)
		return true
	return false


# --- Mouse -----------------------------------------------------------------------------------
func _on_mouse_button(e: InputEventMouseButton) -> bool:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				_cam.zoom_at(e.position, 1.0 / _wheel_factor(e))
			return true
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				_cam.zoom_at(e.position, _wheel_factor(e))
			return true
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_mouse_drag = e.pressed
			dragging = e.pressed
			if e.pressed:
				_cam.stop_inertia()
				_last_time = Time.get_ticks_usec()
				_press_moved = 0.0
				_press_time = Time.get_ticks_msec()
			elif _is_tap():
				if e.button_index == MOUSE_BUTTON_LEFT:
					tapped.emit(e.position)
				elif e.button_index == MOUSE_BUTTON_RIGHT:
					right_tapped.emit(e.position)
			return true
	return false


func _wheel_factor(e: InputEventMouseButton) -> float:
	# Precise (smooth) wheels report a factor; classic wheels report 0 / 1.
	var f := e.factor if e.factor > 0.0 else 1.0
	return pow(WHEEL_STEP, f)


func _on_mouse_motion(e: InputEventMouseMotion) -> bool:
	if not _mouse_drag:
		return false
	_press_moved += e.relative.length()
	_cam.drag(e.position - e.relative, e.position, _elapsed())
	return true


# --- Touch -------------------------------------------------------------------------------------
func _on_touch(e: InputEventScreenTouch) -> bool:
	if e.pressed:
		if _touches.is_empty():
			_press_moved = 0.0
			_press_time = Time.get_ticks_msec()
			_touch_multi = false
		else:
			_touch_multi = true
		_touches[e.index] = e.position
		_cam.stop_inertia()
		_last_time = Time.get_ticks_usec()
	else:
		_touches.erase(e.index)
		if _touches.is_empty() and not _touch_multi and _is_tap():
			tapped.emit(e.position)
	dragging = not _touches.is_empty()
	_pinch_distance = _current_pinch()
	return true


func _on_touch_drag(e: InputEventScreenDrag) -> bool:
	if not _touches.has(e.index):
		_touches[e.index] = e.position
	_press_moved += e.relative.length()
	if _touches.size() == 1:
		_cam.drag(_touches[e.index], e.position, _elapsed())
		_touches[e.index] = e.position
		return true
	# Two fingers: zoom by the change of distance, pan by the midpoint motion.
	var old_mid := _midpoint()
	_touches[e.index] = e.position
	var new_mid := _midpoint()
	var dist := _current_pinch()
	if _pinch_distance > 1.0 and dist > 1.0:
		_cam.zoom_at(new_mid, _pinch_distance / dist, false)
	_pinch_distance = dist
	_cam.drag(old_mid, new_mid, 0.0)
	return true


func _midpoint() -> Vector2:
	var keys := _touches.keys()
	return (_touches[keys[0]] + _touches[keys[1]]) * 0.5


func _current_pinch() -> float:
	if _touches.size() < 2:
		return 0.0
	var keys := _touches.keys()
	return (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])


func _is_tap() -> bool:
	return _press_moved < TAP_SLOP and float(Time.get_ticks_msec() - _press_time) / 1000.0 < TAP_TIME


func _elapsed() -> float:
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_time) / 1000000.0
	_last_time = now
	return clampf(dt, 0.001, 0.1)
