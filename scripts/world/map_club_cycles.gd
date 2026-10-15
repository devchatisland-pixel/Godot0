class_name MapClubCycles
extends Node3D
## The club cycles model (res://props/vegas/club_cycles.glb) set five times on free ground of
## Las Vegas (Zone.ENTERTAINMENT): land, no road, no building. It is drawn as big as the free
## room allows (SCALES, biggest first); its long side (z of the model) lies along a street.
## Static props like the shops: one MeshInstance3D each, clickable.

const PATH := "res://props/vegas/club_cycles.glb"
const COUNT := 5
## Cells per metre to try, biggest first (the model is 33 x 60 m).
const SCALES := [0.1, 0.08, 0.065, 0.05, 0.04]
## Cells kept free round a model, and least distance between two models.
const MARGIN := 1
const APART := 10.0


func build(data: CityData, lib: ModelLibrary) -> void:
	var id := lib.load_named("props:club_cycles", PATH)
	if id < 0:
		return
	var box: AABB = lib.bounds[id]
	var blocked := PackedByteArray()
	blocked.resize(data.size * data.size)
	for b in data.building_count():
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.in_bounds(x, y):
					blocked[data.idx(x, y)] = 1
	var spots: Array[Dictionary] = []
	for k in SCALES:
		var s: float = k
		for turned in [false, true]:
			var w := int(ceil((box.size.z if turned else box.size.x) * s)) + MARGIN * 2
			var d := int(ceil((box.size.x if turned else box.size.z) * s)) + MARGIN * 2
			# A turned model (a quarter turn) swaps the two sides of its footprint.
			for y in range(0, data.size - d):
				for x in range(0, data.size - w):
					if spots.size() >= COUNT:
						break
					var r := Rect2i(x, y, w, d)
					var at := Vector2(r.get_center())
					if _far(spots, at) and _free(data, blocked, r):
						spots.append({"at": at, "scale": s, "turned": turned})
						for yy in range(r.position.y, r.end.y):
							for xx in range(r.position.x, r.end.x):
								blocked[data.idx(xx, yy)] = 1
		if spots.size() >= COUNT:
			break
	if spots.size() < COUNT:
		push_warning("[ClubCycles] only %d free spots in Las Vegas" % spots.size())
	var n := 0
	for sp in spots:
		var s: float = sp["scale"]
		var at: Vector2 = sp["at"]
		var yaw := PI * 0.5 if sp["turned"] else 0.0
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s)
		var centre := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[id]
		mi.transform = Transform3D(basis, Vector3(at.x, 0.0, at.y) - basis * centre)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "ClubCycles_%d" % n
		mi.set_meta("pick", {"uid": "C-%02d" % n, "number": n, "title": "Club cycles", "kind": "PROP",
				"model": "club_cycles", "category": "Prop", "note": "Las Vegas"})
		add_child(mi)
		n += 1
	print("[ClubCycles] %d placed in Las Vegas" % n)


static func _far(spots: Array[Dictionary], at: Vector2) -> bool:
	for sp in spots:
		if (sp["at"] as Vector2).distance_to(at) < APART:
			return false
	return true


static func _free(data: CityData, blocked: PackedByteArray, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := data.idx(x, y)
			var inner := x >= r.position.x + MARGIN and x < r.end.x - MARGIN \
					and y >= r.position.y + MARGIN and y < r.end.y - MARGIN
			if blocked[i] == 1 or data.terrain[i] != CityTypes.Terrain.LAND:
				return false
			if inner and (data.road[i] != 0 or data.zone[i] != CityTypes.Zone.ENTERTAINMENT):
				return false
	return true
