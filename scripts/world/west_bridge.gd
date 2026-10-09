class_name WestBridge
extends Node3D
## The metal bridge from the west coast of the main island to the urban island.
## The model is one span (a truss with a deck); several spans are put end to end
## so that together they cross the gap, and the deck is as wide as the three-lane
## highway that leads to it.

const Cat := ModelCatalog.Cat
## Longest span, in cells.
const SPAN := 9.0
const WIDTH := 3.0
## Truss height limit (cells): the model is squashed so it stays low.
const MAX_HEIGHT := 1.6


func build(data: CityData, lib: ModelLibrary) -> void:
	var wb := data.west_bridge
	var ids := lib.ids(Cat.METAL_BRIDGE)
	if wb.x < 0 or ids.is_empty():
		return
	var box := lib.bounds[ids[0]]
	var x_far := float(wb.y) + 0.5   # urban island side
	var x_near := float(wb.x) + 0.5  # main island side
	var length := x_near - x_far
	var count := maxi(1, ceili(length / SPAN))
	var span := length / float(count)
	var along_x := box.size.x >= box.size.z
	var model_len := box.size.x if along_x else box.size.z
	var model_w := box.size.z if along_x else box.size.x
	var sx := span / model_len
	var sz := WIDTH / model_w
	var sy := minf(sx, MAX_HEIGHT / box.size.y)
	var turn := Basis() if along_x else Basis(Vector3.UP, PI * 0.5)
	var basis := turn * Basis.from_scale(Vector3(sx, sy, sz))
	var center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lib.meshes[ids[0]]
	mm.instance_count = count
	for i in count:
		var at := Vector3(x_far + span * (float(i) + 0.5), 0.0, float(wb.z) + 0.5)
		mm.set_instance_transform(i, Transform3D(basis, at - basis * center))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MetalBridge"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
