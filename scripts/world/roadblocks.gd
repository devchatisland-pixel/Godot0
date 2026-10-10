class_name Roadblocks
extends Node3D
## Checkpoints on the three-lane highways, on land and away from the bridges:
##   - east (Golden Gate side): white stand barriers across the lanes, with cones,
##   - west (main island side): a different barrier model plus a very small police
##     car parked beside the road (not on it).

const Cat := ModelCatalog.Cat
## Distance from the bridge head, in cells.
const EAST_BACK := 13
const WEST_BACK := 11
## Longest side of each model once placed, in cells.
const BARRIER_LEN := 1.05
const CAR_LEN := 0.85
const CONE_LEN := 0.3


func build(data: CityData, lib: ModelLibrary) -> void:
	if data.bridge.x >= 0:
		var x := data.bridge.x - EAST_BACK
		_block(lib, Cat.ROADBLOCK_A, x, data.bridge.y, true)
		_police_car(lib, x + 2, data.bridge.y)
	if data.west_bridge.x >= 0:
		var x := data.west_bridge.x + WEST_BACK
		_block(lib, Cat.ROADBLOCK_B, x, data.west_bridge.z, false)
		_police_car(lib, x, data.west_bridge.z)


## A line of barriers across the three lanes of the row `row` at column `x`.
func _block(lib: ModelLibrary, cat: int, x: int, row: int, with_cones: bool) -> void:
	var ids := lib.ids(cat)
	if ids.is_empty():
		return
	for k in 3:
		var id := ids[k % ids.size()]
		var z := float(row) + 0.5 + float(k - 1)
		_put(lib, id, Vector3(float(x) + 0.5, 0.0, z), PI * 0.5, BARRIER_LEN)
	if with_cones:
		var cones := lib.ids(Cat.CONE)
		if not cones.is_empty():
			for k in 4:
				var z := float(row) + 0.5 + (float(k) - 1.5) * 1.0
				_put(lib, cones[0], Vector3(float(x) - 1.4, 0.0, z), 0.0, CONE_LEN)


func _police_car(lib: ModelLibrary, x: int, row: int) -> void:
	var ids := lib.ids(Cat.POLICE_CAR)
	if ids.is_empty():
		return
	# Two cells beside the outer lane, on the verge, facing along the road.
	_put(lib, ids[0], Vector3(float(x) - 1.6, 0.0, float(row) + 0.5 + 2.7), 0.0, CAR_LEN)


## Puts model `id` on the ground at `at`, scaled so that its longest side is `length`.
func _put(lib: ModelLibrary, id: int, at: Vector3, yaw: float, length: float) -> void:
	var box := lib.bounds[id]
	var longest := maxf(box.size.x, box.size.z)
	if longest <= 0.0:
		return
	var s := length / longest
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s)
	var center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var mi := MeshInstance3D.new()
	mi.mesh = lib.meshes[id]
	mi.transform = Transform3D(basis, at - basis * center)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
