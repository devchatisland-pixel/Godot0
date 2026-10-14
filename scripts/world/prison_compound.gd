class_name PrisonCompound
extends Node3D
## The jail of the prison island, made of the military post of the Golden Gate (checkpoint.glb:
## concrete walls, a gate at each end, guard posts, two watchtowers, the garage), drawn
## SCALE times its size round the cellhouse, with a water tower in the south yard. The post is
## built round the middle of its road (its origin), the road runs along x, the cellhouse stands
## in the north yard. Static props like the fences: one MeshInstance3D each, all clickable.

const Kind := CityTypes.Kind
const Cat := ModelCatalog.Cat

## The post, in cells at scale 1: north wall at -6.17, south wall at 4.74, 7.17 either side.
const NORTH := 6.17
const YARD_CENTRE := 3.3
const MIN_SCALE := 1.5
const MAX_SCALE := 1.9
## Free ground between the lot of the cellhouse and the north wall (cells).
const LOT_MARGIN := 2.0
## The water tower: its place in the south yard (post units, from the middle of the road) and its height (cells).
const TOWER_AT := Vector2(5.2, 2.0)
const TOWER_HEIGHT := 3.2
const TOWER_MODEL := "port_towers.glb: tower_water"
## Concrete under the post: how far it reaches beyond the walls (post units).
const PAD_EXTRA := 0.35

var _count := 0


func build(data: CityData, lib: ModelLibrary) -> void:
	var post := lib.ids(Cat.CHECKPOINT)
	if post.is_empty():
		push_warning("[Jail] no checkpoint model")
		return
	for b in data.building_count():
		if data.b_kind[b] == Kind.PRISON:
			_jail(data, lib, post[0], b)
	print("[Jail] %d pieces placed" % _count)


func _jail(data: CityData, lib: ModelLibrary, id: int, b: int) -> void:
	var lot := data.building_rect(b)
	var s := clampf((float(lot.size.y) + LOT_MARGIN * 2.0) / NORTH, MIN_SCALE, MAX_SCALE)
	var c := Vector2(lot.get_center())
	var origin := Vector3(c.x, 0.0, c.y + YARD_CENTRE * s)
	var box := lib.bounds[id]
	var xform := Transform3D(Basis.from_scale(Vector3.ONE * s), origin)
	_add(_pad(box, s), Transform3D(Basis(), origin), "Jail yard", "PROP", "concrete", false)
	_add(lib.meshes[id], xform, "Jail", "PRISON", lib.model_name(id))
	var towers := lib.names.find(TOWER_MODEL)
	if towers >= 0:
		var tb := lib.bounds[towers]
		var k := TOWER_HEIGHT / maxf(tb.size.y, 0.01)
		var at := origin + Vector3(TOWER_AT.x * s, 0.0, TOWER_AT.y * s)
		var basis := Basis.from_scale(Vector3.ONE * k)
		var t := Transform3D(basis, at - basis * Vector3(tb.get_center().x, tb.position.y, tb.get_center().z))
		_add(lib.meshes[towers], t, "Water tower", "PRISON", lib.model_name(towers))
	else:
		push_warning("[Jail] no water tower model " + TOWER_MODEL)


## Concrete slab under the post, a little bigger than its walls.
func _pad(box: AABB, s: float) -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(box.size.x + PAD_EXTRA * 2.0, box.size.z + PAD_EXTRA * 2.0) * s
	plane.center_offset = Vector3(box.get_center().x * s, 0.015, box.get_center().z * s)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a9a59b")
	mat.roughness = 0.95
	plane.material = mat
	return plane


func _add(mesh: Mesh, xform: Transform3D, title: String, kind: String, model: String, pick: bool = true) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Jail_%d" % _count
	if pick:
		mi.set_meta("pick", {"uid": "J-%02d" % _count, "number": _count, "title": title, "kind": kind,
				"model": model, "category": "Prison", "note": "jail of the prison island"})
	add_child(mi)
	_count += 1
