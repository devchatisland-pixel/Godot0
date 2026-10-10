extends Camera3D

# Camera for res://scenes/shop_island.tscn
# Mouse wheel = zoom (each notch changes the distance by a fixed ratio)
# camera_left / camera_right / camera_forward / camera_back = pan along the row
# camera_center = back to the start view

@export var start_target := Vector3(36, 2, -3) # What the camera looks at when the scene starts
@export var start_distance := 40.0 # Starting distance to the target (smaller = more zoomed in)
@export var min_distance := 5.0
@export var max_distance := 400.0
@export var zoom_step := 1.25 # Distance multiplier per wheel notch
@export var pitch_degrees := 14.0 # Look-down angle
@export var pan_speed := 0.8 # Pan speed per second, multiplied by the current distance

var target:Vector3
var distance:float

func _ready():
	target = start_target
	distance = start_distance
	_apply(1.0)

func _process(delta):
	var input := Vector3.ZERO
	input.x = Input.get_axis("camera_left", "camera_right")
	input.z = Input.get_axis("camera_forward", "camera_back")
	target += input * pan_speed * distance * delta

	if Input.is_action_pressed("camera_center"):
		target = start_target
		distance = start_distance

	_apply(delta * 8)

func _unhandled_input(event):
	if event.is_action_pressed("zoom_in"):
		distance = max(min_distance, distance / zoom_step)
	elif event.is_action_pressed("zoom_out"):
		distance = min(max_distance, distance * zoom_step)

func _apply(weight:float):
	var pitch := deg_to_rad(pitch_degrees)
	var wanted := target + Vector3(0, sin(pitch), cos(pitch)) * distance
	position = position.lerp(wanted, clamp(weight, 0.0, 1.0))
	rotation = Vector3(-pitch, 0, 0)
