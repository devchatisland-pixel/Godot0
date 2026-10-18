class_name PrisonCompound
extends Node3D
## The jail of the prison island: the walled prison of the map "Prison Breakout - Sniper Escape"
## (FREEMODELS/curated/prison_map.glb, made by tools/extract_prison_map.py: yards, cellhouses, four
## guard towers, a water tower; about 149 x 146 units, centred near the origin), drawn so that it
## is SIDE cells wide round the middle of the cellhouse lot. Static prop like the fences: one
## MeshInstance3D, clickable.

const Kind := CityTypes.Kind

const MODEL_PATH := "res://FREEMODELS/curated/prison_map.glb"
const MODEL_NAME := "prison_map"
## Size of the model's walled square in its own units, and the sides of the jail in cells (the
## island is about 40 x 27 cells).
const MODEL_SIDE := 149.0
const MIN_SIDE := 18.0
const MAX_SIDE := 23.0
## The walls shrink (down to this many cells) until they stand on dry land: the island is small.
const DRY_SIDE := 12.0
## Free ground between the lot of the cellhouse and the walls (cells, each side).
const LOT_MARGIN := 3.0
## The yard lies this many cells south of the middle of the lot (the garage side of the island).
const YARD_SOUTH := 2.0
## Small lift so the slab does not flicker with the sand.
const LIFT := 0.03

var _count := 0


func build(data: CityData, lib: ModelLibrary) -> void:
	var id := lib.load_named(MODEL_NAME, MODEL_PATH)
	if id < 0:
		push_warning("[Jail] no prison model " + MODEL_PATH)
		return
	for b in data.building_count():
		if data.b_kind[b] == Kind.PRISON:
			_jail(data, lib, id, b)
	print("[Jail] %d pieces placed" % _count)


## The square of ground (cells) the walls of the jail of cellhouse lot `lot` stand on.
static func square(data: CityData, lot: Rect2i) -> Rect2:
	var c := Vector2(lot.get_center()) + Vector2(0.0, YARD_SOUTH)
	var side := clampf(float(maxi(lot.size.x, lot.size.y)) + LOT_MARGIN * 2.0, MIN_SIDE, MAX_SIDE)
	while side > DRY_SIDE and not _dry(data, Rect2(c - Vector2.ONE * side * 0.5, Vector2.ONE * side)):
		side -= 1.0
	return Rect2(c - Vector2.ONE * side * 0.5, Vector2.ONE * side)


## True when the edge of the square (and its middle) is land.
static func _dry(data: CityData, r: Rect2) -> bool:
	var steps := int(r.size.x)
	for i in steps + 1:
		var t := float(i) / float(steps)
		for p in [Vector2(r.position.x + r.size.x * t, r.position.y), Vector2(r.position.x + r.size.x * t, r.end.y),
				Vector2(r.position.x, r.position.y + r.size.y * t), Vector2(r.end.x, r.position.y + r.size.y * t)]:
			if not data.is_land(int(p.x), int(p.y)):
				return false
	return true


func _jail(data: CityData, lib: ModelLibrary, id: int, b: int) -> void:
	var sq := square(data, data.building_rect(b))
	var s := sq.size.x / MODEL_SIDE
	var c := sq.get_center()
	var box := lib.bounds[id]
	var centre := box.get_center()
	# The middle of the walls on the middle of the yard, the ground of the model on the ground.
	var basis := Basis.from_scale(Vector3.ONE * s)
	var at := Vector3(c.x, LIFT, c.y)
	var xform := Transform3D(basis, at - basis * Vector3(centre.x, 0.0, centre.z))
	_add(lib.meshes[id], xform, "Jail", "PRISON", MODEL_NAME)


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
