class_name BuildingExtras
extends RefCounted
## Small things added next to a building model: the golden arches, the U.N.
## emblem, the stadium floodlights, trees of houses, and the fillers of empty
## lots (gardens, plazas, industrial yards). Pure functions, thread safe.

const Kind := CityTypes.Kind
const Cat := ModelCatalog.Cat

## Helipad of the main hospital model: offset (x, z) from the roof centre and
## size, as fractions of the model width / depth.
const HOSPITAL_PAD := Vector3(0.0, 0.0, 0.3)
## The emblem of the U.N. tower is a bit smaller than the tower is wide.
const UN_EMBLEM := 0.38

static func place_extras(data: CityData, lib: ModelLibrary, i: int, kind: int,
		pick: Dictionary, batch: InstanceBatch) -> void:
	var r := data.building_rect(i)
	var seed: int = data.b_seed[i]
	var back := (int(data.b_facing[i]) + 2) % 4
	var o := CityTypes.FACING_OFFSETS[back]
	var lot_center := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var to_back := Vector3(o.x * r.size.x, 0, o.y * r.size.y) * 0.5
	var side := Vector3(-o.y, 0, o.x) * (0.6 if seed & 1 else -0.6)
	var xform: Transform3D = pick["xform"]
	var pid: int = pick["id"]
	var box: AABB = lib.bounds[pid]
	if data.b_sign[i] != 0:
		_place_sign(data, lib, i, pid, xform, batch)
	match kind:
		Kind.STADIUM:
			# Floodlight masts at the corners of the plot (seen at night).
			var lights := lib.named_id("stadium_lights")
			var h := box.size.y * xform.basis.get_scale().y * 1.6
			batch.add(lights, Transform3D(Basis.from_scale(Vector3(r.size.x, h, r.size.y)), lot_center))
		Kind.MCDONALDS:
			# Golden arches over the front, lit at night.
			var w := box.size.x * 0.5
			var at := Vector3(box.get_center().x, box.end.y + 0.02, box.get_center().z + box.size.z * 0.3)
			batch.add(lib.named_id("golden_arches"), xform * Transform3D(Basis.from_scale(Vector3(w, w, w)), at))
		Kind.UN_HQ:
			if ModelPools.is_pack_model(lib, pid, Cat.UN_TOWER):
				# Emblem and name high on the front of the tower.
				var front := Vector3(box.get_center().x, box.size.y * 0.66, box.end.z + 0.01)
				var w := box.size.x * UN_EMBLEM
				batch.add(lib.named_id("un_signs"), xform * Transform3D(Basis.from_scale(Vector3(w, w, w)), front))
		Kind.MAIN_HOSPITAL:
			if ModelPools.is_pack_model(lib, pid, Cat.HOSPITAL_MAIN):
				# Lit red H over the helipad of the roof.
				var pad := Vector3(box.get_center().x + box.size.x * HOSPITAL_PAD.x, box.end.y + 0.01,
						box.get_center().z + box.size.z * HOSPITAL_PAD.y)
				var w := box.size.x * HOSPITAL_PAD.z
				batch.add(lib.named_id("helipad_h"), xform * Transform3D(Basis.from_scale(Vector3(w, 1, w)), pad))
		Kind.HOUSE:
			if lib.has_cat(Cat.TREE):
				var trees := lib.ids(Cat.TREE)
				var p := lot_center + to_back * 0.75 + side * float(mini(r.size.x, r.size.y)) * 0.6
				batch.add(trees[seed % trees.size()], tree_xform(p, seed))
		Kind.INDUSTRIAL:
			if lib.has_cat(Cat.INDUSTRIAL_PROP) and seed % 3 == 0:
				var props := lib.ids(Cat.INDUSTRIAL_PROP)
				var p := lot_center + to_back * 0.7 + side
				var prop := props[(seed >> 3) % props.size()]
				if lib.bounds[prop].size.x < 1.0 and lib.bounds[prop].size.z < 1.0:
					batch.add(prop, Transform3D(Basis(Vector3.UP, (seed & 3) * PI * 0.5), p))


## Trees on gardens, a tree on plazas and props on industrial yards.
static func place_filler(data: CityData, lib: ModelLibrary, i: int, kind: int, batch: InstanceBatch) -> void:
	var r := data.building_rect(i)
	var seed: int = data.b_seed[i]
	if kind == Kind.INDUSTRIAL_YARD:
		_place_yard(lib, r, seed, batch)
		return
	var trees := lib.ids(Cat.TREE)
	if trees.is_empty():
		trees = PackedInt32Array([lib.named_id("tree")])
	var count := 1 if kind == Kind.PLAZA else mini(4, r.get_area())
	for t in count:
		var h := CityTypes.hash2(i, t, seed)
		var p := Vector3(r.position.x + 0.3 + float(h & 255) / 255.0 * (r.size.x - 0.6), 0,
				r.position.y + 0.3 + float((h >> 8) & 255) / 255.0 * (r.size.y - 0.6))
		batch.add(trees[h % trees.size()], tree_xform(p, h))


## Industrial yard: stacked containers, oil barrels or a truck (cartoon pack), else the Kenney props.
static func _place_yard(lib: ModelLibrary, r: Rect2i, seed: int, batch: InstanceBatch) -> void:
	var c := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var turn := Basis(Vector3.UP, (seed & 1) * PI * 0.5)
	match seed % 3:
		0:
			var boxes := lib.ids(Cat.CONTAINER)
			if not boxes.is_empty():
				for i in 3:
					var p := c + turn * Vector3(0.0, 0.0, (i - 1) * 0.55)
					var s := Basis.from_scale(Vector3(1.5, 1.5, 1.5))
					batch.add(boxes[(seed >> 3) % boxes.size()], Transform3D(turn * s, p))
					if i == 1:
						batch.add(boxes[(seed >> 5) % boxes.size()], Transform3D(turn * s, p + Vector3(0, 0.62, 0)))
				return
		1:
			var barrels := lib.ids(Cat.BARREL)
			if not barrels.is_empty():
				for i in 5:
					var p := c + Vector3(float(i % 3) - 1.0, 0.0, float(i / 3) - 0.5) * 0.4
					batch.add(barrels[(seed >> (3 + i)) % barrels.size()], Transform3D(Basis.from_scale(Vector3(1.8, 1.8, 1.8)), p))
				return
		_:
			var trucks := lib.ids(Cat.TRUCK)
			if not trucks.is_empty():
				batch.add(trucks[0], Transform3D(turn * Basis.from_scale(Vector3(1.3, 1.3, 1.3)), c))
				return
	var props := lib.ids(Cat.INDUSTRIAL_PROP)
	if not props.is_empty():
		batch.add(props[seed % props.size()], Transform3D(Basis(Vector3.UP, (seed & 1) * PI * 0.5), c))


static func tree_xform(p: Vector3, seed: int) -> Transform3D:
	var s := 1.1 + float((seed >> 5) & 15) / 15.0 * 0.6
	return Transform3D(Basis(Vector3.UP, float(seed & 63) * 0.1).scaled(Vector3(s, s, s)), p)


## Neon signs by model category: "roof" stands on the roof of the building at its south
## edge (on the highest point under the sign), "wall" hangs on its south wall at `height` (share of the building
## height). `scale` shrinks the model; `halo` is the size of the glow copy drawn behind it.
const ROOF_EDGE_INSET := 0.1
const SIGNS := {
	ModelCatalog.Cat.NEON_CONTROLLER: {"mount": "wall", "scale": 0.2, "height": 0.45, "halo": 1.25},
	ModelCatalog.Cat.NEON_PACMAN: {"mount": "roof", "scale": 0.58, "halo": 1.15, "yaw": PI * 0.5},
}


static func _place_sign(data: CityData, lib: ModelLibrary, i: int, pid: int, xform: Transform3D,
		batch: InstanceBatch) -> void:
	var cat: int = data.b_sign[i]
	var ids := lib.ids(cat)
	if ids.is_empty() or not SIGNS.has(cat):
		return
	var spec: Dictionary = SIGNS[cat]
	var s: float = spec["scale"]
	var body: AABB = xform * lib.bounds[pid]
	var model := lib.bounds[ids[0]]
	var local_center := Vector3(model.get_center().x, model.position.y, model.get_center().z)
	var at := Vector3(body.get_center().x, 0.0, body.get_center().z)
	if spec["mount"] == "wall":
		local_center = model.get_center()
		at.y = body.position.y + body.size.y * float(spec["height"])
		at.z = body.end.z + 0.02
	else:
		at.z = body.end.z - ROOF_EDGE_INSET # at the south edge of the roof, like a parapet sign
		at.y = _roof_height(lib, pid, xform, Vector2(at.x, at.z), model.size.x * s * 0.5)
	var turn := Basis(Vector3.UP, float(spec.get("yaw", 0.0)))
	batch.add(ids[0], Transform3D(turn * Basis.from_scale(Vector3(s, s, s)), at - turn * (local_center * s)))
	var halo := lib.named_id("neon_halo_%d" % cat)
	if halo >= 0:
		var h: float = s * float(spec["halo"])
		var back := Vector3(0, 0, -0.03)
		batch.add(halo, Transform3D(turn * Basis.from_scale(Vector3(h, h, s)),
				at + back - turn * (local_center * Vector3(h, h, s))))


## Height of the highest point of the model under a square window of half-width `half`
## around `center` (the roof under a sign); the top of its box when nothing is there.
static func _roof_height(lib: ModelLibrary, id: int, xform: Transform3D, center: Vector2, half: float) -> float:
	var top := -INF
	var mesh := lib.meshes[id]
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var p := xform * v
			if absf(p.x - center.x) <= half and absf(p.z - center.y) <= half:
				top = maxf(top, p.y)
	if top == -INF:
		top = (xform * lib.bounds[id]).end.y
	return top
