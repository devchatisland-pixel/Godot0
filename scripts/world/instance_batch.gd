class_name InstanceBatch
extends RefCounted
## Collects instance transforms grouped by mesh id, already packed in the
## MultiMesh buffer layout (12 floats per transform, +4 for a colour).
## Built on worker threads, turned into MultiMeshes on the main thread.

## mesh id -> PackedFloat32Array
var transforms := {}
## Far LOD boxes (transform + colour per instance).
var boxes := PackedFloat32Array()


func add(mesh_id: int, t: Transform3D) -> void:
	if mesh_id < 0:
		return
	if not transforms.has(mesh_id):
		transforms[mesh_id] = PackedFloat32Array()
	var buf: PackedFloat32Array = transforms[mesh_id]
	_append(buf, t)
	transforms[mesh_id] = buf


func add_box(t: Transform3D, color: Color) -> void:
	_append(boxes, t)
	boxes.append(color.r)
	boxes.append(color.g)
	boxes.append(color.b)
	boxes.append(color.a)


func is_empty() -> bool:
	return transforms.is_empty() and boxes.is_empty()


static func _append(buf: PackedFloat32Array, t: Transform3D) -> void:
	var b := t.basis
	buf.append(b.x.x)
	buf.append(b.y.x)
	buf.append(b.z.x)
	buf.append(t.origin.x)
	buf.append(b.x.y)
	buf.append(b.y.y)
	buf.append(b.z.y)
	buf.append(t.origin.y)
	buf.append(b.x.z)
	buf.append(b.y.z)
	buf.append(b.z.z)
	buf.append(t.origin.z)


## Creates the MultiMesh nodes under `parent`. Returns the number of nodes.
func build_nodes(parent: Node3D, lib: ModelLibrary, box_material: Material) -> int:
	var count := 0
	for id in transforms:
		var buf: PackedFloat32Array = transforms[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lib.meshes[id]
		mm.instance_count = buf.size() / 12
		mm.buffer = buf
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		count += 1
	if not boxes.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = lib.meshes[lib.named_id("box")]
		mm.instance_count = boxes.size() / 16
		mm.buffer = boxes
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = box_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		count += 1
	return count
