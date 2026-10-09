class_name BuildingPlacer
extends RefCounted
## Turns a lot of the city data into model instances: picks a model that fits
## the lot, turns it towards its street and scales it with the local density.
## Pure functions of (data, library, building id) -> safe on worker threads and
## the near and far LOD always agree on the same model.

const Kind := CityTypes.Kind
const Cat := ModelCatalog.Cat

## Kenney commercial models taller than this are offices, lower ones shops.
const OFFICE_MIN_HEIGHT := 1.6

const FAR_COLORS := {
	Kind.SKYSCRAPER: Color("aebfdc"), Kind.OFFICE: Color("cfd2e2"),
	Kind.SHOP: Color("e2dde6"), Kind.APARTMENT: Color("d9d7e4"),
	Kind.HOUSE: Color("efeae4"), Kind.INDUSTRIAL: Color("b4b1aa"),
	Kind.INDUSTRIAL_YARD: Color("9b9384"), Kind.HOSPITAL: Color("f4f2f8"),
	Kind.SCHOOL: Color("c97b55"), Kind.FIRE_STATION: Color("b8473f"),
	Kind.POLICE: Color("c8d2ea"), Kind.CITY_HALL: Color("e6dcc6"),
	Kind.STADIUM: Color("bcbacb"), Kind.FOUNTAIN: Color("d8d3c4"),
	Kind.BANK: Color("5b7fc4"), Kind.CHURCH: Color("9d8f86"),
	Kind.CASINO: Color("8e3a9a"), Kind.NIGHTCLUB: Color("4a3a66"),
	Kind.FERRIS_WHEEL: Color("f4f2f8"), Kind.DRIVE_IN: Color("4c4f5e"),
	Kind.LIGHTHOUSE: Color("d23b2f"), Kind.TELECOM_TOWER: Color("d23b2f"),
	Kind.SAT_DISH: Color("f4f2f8"), Kind.MESA: Color("c98a4b"), Kind.POND: Color("5fb7e0"),
}

## Procedural meshes per kind (several names = variants picked by seed).
const NAMED := {
	Kind.HOSPITAL: ["hospital"], Kind.SCHOOL: ["school"], Kind.FIRE_STATION: ["fire_station"],
	Kind.POLICE: ["police"], Kind.CITY_HALL: ["city_hall"], Kind.STADIUM: ["stadium"],
	Kind.FOUNTAIN: ["fountain"], Kind.BANK: ["bank"], Kind.CHURCH: ["church"],
	Kind.CASINO: ["casino"], Kind.NIGHTCLUB: ["club_a", "club_b"],
	Kind.FERRIS_WHEEL: ["ferris_wheel"], Kind.DRIVE_IN: ["drive_in"],
	Kind.LIGHTHOUSE: ["lighthouse"], Kind.TELECOM_TOWER: ["telecom_tower"],
	Kind.SAT_DISH: ["sat_dish"], Kind.MESA: ["mesa"], Kind.POND: ["pond"],
}


## Adds the models of building `i` to `batch` (near LOD) or a box (far LOD).
static func place(data: CityData, lib: ModelLibrary, i: int, batch: InstanceBatch, far: bool) -> void:
	var kind: int = data.b_kind[i]
	if kind == Kind.PLAZA or kind == Kind.GARDEN or kind == Kind.INDUSTRIAL_YARD:
		if not far:
			_place_filler(data, lib, i, kind, batch)
		return
	var pick := _pick_model(data, lib, i)
	if pick.is_empty():
		return
	var xform: Transform3D = pick["xform"]
	if far:
		var box := xform * lib.bounds[pick["id"]]
		var t := Transform3D(Basis.from_scale(box.size), box.get_center() - Vector3(0, box.size.y * 0.5, 0))
		var c: Color = FAR_COLORS.get(kind, Color.WHITE)
		var j := CityTypes.hashf(i, 3, data.b_seed[i]) * 0.1 - 0.05
		batch.add_box(t, Color(c.r + j, c.g + j, c.b + j))
		return
	batch.add(pick["id"], xform)
	_place_extras(data, lib, i, kind, pick, batch)


# --- Model choice ------------------------------------------------------------------------
static func _pick_model(data: CityData, lib: ModelLibrary, i: int) -> Dictionary:
	var kind: int = data.b_kind[i]
	var r := data.building_rect(i)
	var facing: int = data.b_facing[i]
	var seed: int = data.b_seed[i]
	var density: float = data.b_height[i]
	if NAMED.has(kind):
		var names: Array = NAMED[kind]
		var nid := lib.named_id(names[(seed >> 3) % names.size()])
		return {"id": nid, "xform": _fit(lib, nid, r, facing, 1.0, 1.0, 0.0, true)}
	var candidates := _candidates(lib, kind)
	if candidates.is_empty():
		var bid := lib.named_id("box")
		var h := 0.6 + density * 3.0
		var t := Transform3D(Basis.from_scale(Vector3(r.size.x * 0.8, h, r.size.y * 0.8)),
				Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5))
		return {"id": bid, "xform": t}
	var id := _choose_fitting(lib, candidates, r, facing, seed)
	var scale := 1.0
	var stretch := 1.0
	var room := _room(lib, id, r, facing)
	match kind:
		Kind.SKYSCRAPER:
			# Taller towards the heart of downtown, leaving room between towers.
			scale = clampf(room * 0.85, 0.8, 1.1)
			stretch = 0.85 + density * 0.55 + float(seed & 7) * 0.03
		Kind.OFFICE:
			scale = clampf(room, 0.8, 1.15)
		_:
			scale = minf(room, 1.0)
	var push := 0.25 if kind == Kind.HOUSE else 0.85
	return {"id": id, "xform": _fit(lib, id, r, facing, scale, stretch, push, false)}


static func _candidates(lib: ModelLibrary, kind: int) -> PackedInt32Array:
	match kind:
		Kind.SKYSCRAPER:
			return lib.ids(Cat.SKYSCRAPER)
		Kind.OFFICE, Kind.SHOP, Kind.APARTMENT:
			var out := PackedInt32Array()
			for id in lib.ids(Cat.COMMERCIAL):
				var h := lib.bounds[id].size.y
				var tall := h >= OFFICE_MIN_HEIGHT
				if (kind == Kind.SHOP and not tall) or (kind == Kind.OFFICE and tall) \
						or (kind == Kind.APARTMENT and h > 1.2 and h < 2.4):
					out.append(id)
			return out if not out.is_empty() else lib.ids(Cat.COMMERCIAL)
		Kind.HOUSE:
			return lib.ids(Cat.HOUSE)
		Kind.INDUSTRIAL:
			return lib.ids(Cat.INDUSTRIAL)
	return PackedInt32Array()


## Prefers models that fill the lot well; falls back to the smallest one.
static func _choose_fitting(lib: ModelLibrary, ids: PackedInt32Array, r: Rect2i, facing: int, seed: int) -> int:
	var good := PackedInt32Array()
	var ok := PackedInt32Array()
	var smallest := ids[0]
	var smallest_area := INF
	var lot_area := float(r.get_area())
	for id in ids:
		var fp := _footprint(lib, id, facing)
		var area := fp.x * fp.y
		if area < smallest_area:
			smallest_area = area
			smallest = id
		if fp.x <= r.size.x * 0.98 and fp.y <= r.size.y * 0.98:
			ok.append(id)
			if area >= lot_area * 0.4:
				good.append(id)
	var pool := good if not good.is_empty() else ok
	if pool.is_empty():
		return smallest
	return pool[(seed >> 4) % pool.size()]


## Footprint (x, z) of a model once turned to `facing`.
static func _footprint(lib: ModelLibrary, id: int, facing: int) -> Vector2:
	var s := lib.bounds[id].size
	return Vector2(s.z, s.x) if facing % 2 == 1 else Vector2(s.x, s.z)


## How much the model could be scaled and still fit in the lot.
static func _room(lib: ModelLibrary, id: int, r: Rect2i, facing: int) -> float:
	var fp := _footprint(lib, id, facing)
	return minf(r.size.x * 0.94 / fp.x, r.size.y * 0.94 / fp.y)


## Transform placing model `id` centred in the lot, facing its street and
## pushed towards it by `push` (0 = centred, 1 = touching the sidewalk).
static func _fit(lib: ModelLibrary, id: int, r: Rect2i, facing: int, scale: float,
		stretch: float, push: float, square_fit: bool) -> Transform3D:
	var yaw := CityTypes.facing_yaw(facing)
	if square_fit and r.size.x != r.size.y:
		# Non-square named meshes are modelled long along X: keep them that way.
		var long_x := r.size.x > r.size.y
		if (facing % 2 == 1) == long_x:
			yaw += PI * 0.5
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(scale, scale * stretch, scale))
	var aabb := lib.bounds[id]
	var center_local := Vector3(aabb.get_center().x, 0, aabb.get_center().z)
	var lot_center := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var origin := lot_center - basis * center_local
	if push > 0.0:
		var fp := _footprint(lib, id, facing) * scale
		var o := CityTypes.FACING_OFFSETS[facing]
		var depth_room := (r.size.y - fp.y) if o.y != 0 else (r.size.x - fp.x)
		origin += Vector3(o.x, 0, o.y) * maxf(depth_room, 0.0) * 0.5 * push
	return Transform3D(basis, origin)


# --- Extras --------------------------------------------------------------------------------
static func _place_extras(data: CityData, lib: ModelLibrary, i: int, kind: int,
		pick: Dictionary, batch: InstanceBatch) -> void:
	var r := data.building_rect(i)
	var seed: int = data.b_seed[i]
	var back := (int(data.b_facing[i]) + 2) % 4
	var o := CityTypes.FACING_OFFSETS[back]
	var lot_center := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var to_back := Vector3(o.x * r.size.x, 0, o.y * r.size.y) * 0.5
	var side := Vector3(-o.y, 0, o.x) * (0.6 if seed & 1 else -0.6)
	match kind:
		Kind.HOUSE:
			if lib.has_cat(Cat.TREE):
				var trees := lib.ids(Cat.TREE)
				var p := lot_center + to_back * 0.75 + side * float(mini(r.size.x, r.size.y)) * 0.6
				batch.add(trees[seed % trees.size()], _tree_xform(p, seed))
		Kind.INDUSTRIAL:
			if lib.has_cat(Cat.INDUSTRIAL_PROP) and seed % 3 == 0:
				var props := lib.ids(Cat.INDUSTRIAL_PROP)
				var p := lot_center + to_back * 0.7 + side
				var prop := props[(seed >> 3) % props.size()]
				if lib.bounds[prop].size.x < 1.0 and lib.bounds[prop].size.z < 1.0:
					batch.add(prop, Transform3D(Basis(Vector3.UP, (seed & 3) * PI * 0.5), p))


## Trees on gardens, a tree on plazas and props on industrial yards.
static func _place_filler(data: CityData, lib: ModelLibrary, i: int, kind: int, batch: InstanceBatch) -> void:
	var r := data.building_rect(i)
	var seed: int = data.b_seed[i]
	if kind == Kind.INDUSTRIAL_YARD:
		var props := lib.ids(Cat.INDUSTRIAL_PROP)
		if props.is_empty():
			return
		var p := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		batch.add(props[seed % props.size()], Transform3D(Basis(Vector3.UP, (seed & 1) * PI * 0.5), p))
		return
	var trees := lib.ids(Cat.TREE)
	if trees.is_empty():
		trees = PackedInt32Array([lib.named_id("tree")])
	var count := 1 if kind == Kind.PLAZA else mini(4, r.get_area())
	for t in count:
		var h := CityTypes.hash2(i, t, seed)
		var p := Vector3(r.position.x + 0.3 + float(h & 255) / 255.0 * (r.size.x - 0.6), 0,
				r.position.y + 0.3 + float((h >> 8) & 255) / 255.0 * (r.size.y - 0.6))
		batch.add(trees[h % trees.size()], _tree_xform(p, h))


static func _tree_xform(p: Vector3, seed: int) -> Transform3D:
	var s := 1.1 + float((seed >> 5) & 15) / 15.0 * 0.6
	return Transform3D(Basis(Vector3.UP, float(seed & 63) * 0.1).scaled(Vector3(s, s, s)), p)
