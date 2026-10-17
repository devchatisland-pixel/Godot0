class_name MapFences
extends Node3D
## The wire fences of the map, each one a closed rectangle with a gate:
##   - round the prison, on dry ground only (a side that would run over the beach or the sea
##     moves in until it does not), with floodlights at its corners and bleachers in the yard
##     in front of the gate;
##   - round the secret base, at a little distance from its runway.
## Static props like the vehicles: one MeshInstance3D each, all of them clickable.

const Kind := CityTypes.Kind
const Cat := ModelCatalog.Cat

const STEEL := Color("8d939c")
const WIRE := Color("a9afb8")
## Distance between two posts and between two wires (cells), thickness of a post and of a wire.
const POST_STEP := 0.5
const WIRE_STEP := 0.125
const POST := 0.05
const THIN := 0.012

## Prison: cells between its lot and the fence (more to the north: a billboard stands there),
## height of the fence, width of its gate.
const PRISON_MARGIN := 2
const PRISON_MARGIN_NORTH := 3
const PRISON_HEIGHT := 0.55
const PRISON_GATE := 1.4
## Floodlights stand this far inside the corners; they are drawn this much bigger than at the
## concert camp.
const LIGHT_INSET := 0.55
const LIGHT_SCALE := 1.5
## Bleachers of the yard: how many on each side of the gate, distance from the fence.
const BLEACHERS := 3
const BLEACHER_INSET := 0.6
## Secret base: distance from its model to the fence, height, gate.
const BASE_MARGIN := 0.9
const BASE_HEIGHT := 0.45
const BASE_GATE := 1.6

var _count := 0


func build(data: CityData, lib: ModelLibrary) -> void:
	for b in data.building_count():
		if data.b_kind[b] == Kind.PRISON:
			_prison(data, lib, b)
		elif data.b_kind[b] == Kind.AIRBASE:
			_base(data, lib, b)
	print("[Fences] %d fence pieces, lights and stands placed" % _count)


func _prison(data: CityData, lib: ModelLibrary, b: int) -> void:
	var lot := data.building_rect(b)
	var want := Rect2i(lot.position - Vector2i(PRISON_MARGIN, PRISON_MARGIN_NORTH),
			lot.size + Vector2i(PRISON_MARGIN * 2, PRISON_MARGIN + PRISON_MARGIN_NORTH))
	var ring := Rect2(dry_ring(data, want, lot)).grow(-0.25)
	var note := "round the prison"
	_add(fence_mesh(ring, PRISON_HEIGHT, 2, PRISON_GATE), Transform3D.IDENTITY, "Prison fence", "FENCE", "wire fence", note)
	var mid := ring.get_center()
	var lights := lib.ids(Cat.FLOODLIGHT)
	if not lights.is_empty():
		var k := LIGHT_INSET
		for p: Vector2 in [ring.position + Vector2(k, k), Vector2(ring.end.x - k, ring.position.y + k),
				ring.end - Vector2(k, k), Vector2(ring.position.x + k, ring.end.y - k),
				Vector2(mid.x, ring.position.y + k), Vector2(ring.position.x + k, mid.y), Vector2(ring.end.x - k, mid.y)]:
			var to := Vector3(mid.x - p.x, 0, mid.y - p.y).normalized()
			_add(lib.meshes[lights[0]], BuildingExtras._standing(lib, lights[0], Vector3(p.x, 0, p.y),
					BuildingExtras._side_to(to), LIGHT_SCALE), "Floodlight", "PROP", lib.model_name(lights[0]), note)
	var stands := lib.ids(Cat.BLEACHER)
	var yard := ring.end.y - float(lot.end.y)
	if not stands.is_empty() and yard >= 1.2:
		# A row on each side of the gate, their backs to the fence, looking at the prison.
		var step := lib.bounds[stands[0]].size.z + 0.12
		var yaw := BuildingExtras._side_to(Vector3(0, 0, -1)) + BuildingExtras.CONCERT_SEAT_TURN
		for side in [-1.0, 1.0]:
			for i in BLEACHERS:
				var x: float = mid.x + side * (PRISON_GATE * 0.5 + 0.5 + step * (float(i) + 0.5))
				_add(lib.meshes[stands[0]], BuildingExtras._standing(lib, stands[0],
						Vector3(x, 0, ring.end.y - BLEACHER_INSET), yaw), "Bleacher", "PROP", lib.model_name(stands[0]),
						"in the yard of the prison")


func _base(data: CityData, lib: ModelLibrary, b: int) -> void:
	var pick := BuildingPlacer.pick_for(data, lib, b)
	if pick.is_empty():
		return
	var box: AABB = (pick["xform"] as Transform3D) * lib.bounds[pick["id"]]
	var ring := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(BASE_MARGIN)
	# The gate is on the side the base faces.
	var side := int(data.b_facing[b]) % 4
	_add(fence_mesh(ring, BASE_HEIGHT, side, BASE_GATE), Transform3D.IDENTITY, "Secret base fence", "FENCE",
			"wire fence", "round the secret base")


func _add(mesh: Mesh, xform: Transform3D, title: String, kind: String, model: String, note: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Fence_%d" % _count
	mi.set_meta("pick", {"uid": "F-%03d" % _count, "number": _count, "title": title, "kind": kind,
			"model": model, "category": "Prop", "note": note})
	add_child(mi)
	_count += 1


## `want` with every side moved in, cell by cell, until it runs over dry land only (no beach,
## no sea); it never comes closer than one cell to `keep`.
static func dry_ring(data: CityData, want: Rect2i, keep: Rect2i) -> Rect2i:
	var r := want
	var limit := keep.grow(1)
	for step in 16:
		var moved := false
		if r.position.y < limit.position.y and not _dry(data, Rect2i(r.position.x, r.position.y, r.size.x, 1)):
			r = Rect2i(r.position.x, r.position.y + 1, r.size.x, r.size.y - 1)
			moved = true
		if r.end.y > limit.end.y and not _dry(data, Rect2i(r.position.x, r.end.y - 1, r.size.x, 1)):
			r = Rect2i(r.position.x, r.position.y, r.size.x, r.size.y - 1)
			moved = true
		if r.position.x < limit.position.x and not _dry(data, Rect2i(r.position.x, r.position.y, 1, r.size.y)):
			r = Rect2i(r.position.x + 1, r.position.y, r.size.x - 1, r.size.y)
			moved = true
		if r.end.x > limit.end.x and not _dry(data, Rect2i(r.end.x - 1, r.position.y, 1, r.size.y)):
			r = Rect2i(r.position.x, r.position.y, r.size.x - 1, r.size.y)
			moved = true
		if not moved:
			break
	return r


static func _dry(data: CityData, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not data.in_bounds(x, y) or data.terrain[data.idx(x, y)] != CityTypes.Terrain.LAND:
				return false
	return true


## A wire fence along the sides of `r` (x, z in cells), `height` high: posts, a top rail and a
## mesh of wires. The side `gate_side` (0 north, 1 east, 2 south, 3 west) has an opening
## `gate` wide in its middle, between two taller posts.
static func fence_mesh(r: Rect2, height: float, gate_side: int, gate: float) -> ArrayMesh:
	var k := MeshKit.new()
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	# Sides in the order north, east, south, west.
	var sides := [[corners[0], corners[1]], [corners[1], corners[2]], [corners[3], corners[2]], [corners[0], corners[3]]]
	for s in 4:
		var a: Vector2 = sides[s][0]
		var b: Vector2 = sides[s][1]
		if s != gate_side:
			_run(k, a, b, height)
			continue
		var dir := (b - a).normalized()
		var mid := (a + b) * 0.5
		var left := mid - dir * gate * 0.5
		var right := mid + dir * gate * 0.5
		_run(k, a, left, height)
		_run(k, right, b, height)
		for p: Vector2 in [left, right]:
			k.block(Vector3(p.x, 0, p.y), Vector3(POST * 1.6, height * 1.25, POST * 1.6), STEEL.darkened(0.15))
	return k.commit()


## One straight stretch of fence from `a` to `b` (along x or along z).
static func _run(k: MeshKit, a: Vector2, b: Vector2, height: float) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var dir := (b - a) / length
	var posts := maxi(1, roundi(length / POST_STEP))
	for i in posts + 1:
		var p := a + dir * (length * float(i) / float(posts))
		k.block(Vector3(p.x, 0, p.y), Vector3(POST, height, POST), STEEL)
	var wires := maxi(1, roundi(length / WIRE_STEP))
	for i in wires:
		var p := a + dir * (length * (float(i) + 0.5) / float(wires))
		k.block(Vector3(p.x, 0, p.y), Vector3(THIN, height, THIN), WIRE)
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var span := (b - a).abs()
	for h: float in [0.2, 0.4, 0.6, 0.8]:
		k.box(Vector3(lo.x - THIN * 0.5, height * h, lo.y - THIN * 0.5), Vector3(span.x + THIN, THIN, span.y + THIN), WIRE)
	k.box(Vector3(lo.x - POST * 0.4, height - POST * 0.8, lo.y - POST * 0.4),
			Vector3(span.x + POST * 0.8, POST * 0.8, span.y + POST * 0.8), STEEL)
