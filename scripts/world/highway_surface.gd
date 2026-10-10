class_name HighwaySurface
extends Node3D
## The asphalt of the two three-lane highways, with lanes and a double yellow line, drawn as
## flat panels laid just over the road tiles (one texture of 75 KB, a few dozen instances).
## Only the highways get it: runs of three avenue cells one above the other, on land.

const TEXTURE := preload("res://textures/highway.jpg")
## Longest panel along the road (cells), and its height above the ground.
const SEGMENT := 12
const LIFT := 0.04


func build(data: CityData) -> void:
	var segments: Array[Vector3] = [] # x start, row, length
	for y in range(1, data.size - 1):
		var x := 0
		while x < data.size:
			if not _lane(data, x, y):
				x += 1
				continue
			var start := x
			while x < data.size and _lane(data, x, y) and x - start < SEGMENT:
				x += 1
			segments.append(Vector3(start, y, x - start))
	if segments.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEXTURE
	mat.roughness = 0.95
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = segments.size()
	for i in segments.size():
		var s := segments[i]
		var basis := Basis.from_scale(Vector3(s.z, 1.0, 3.0))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(s.x + s.z * 0.5, LIFT, s.y + 0.5)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "HighwayAsphalt"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## True when (x, y) is the middle of three avenue cells (a lane row of a highway), not a bridge.
func _lane(data: CityData, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		var v := data.road[data.idx(x, y + dy)]
		if (v & 3) != CityTypes.ROAD_AVENUE or (v & CityTypes.ROAD_BRIDGE_FLAG) != 0:
			return false
	return true
