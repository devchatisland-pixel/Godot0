class_name BuildingPlacer
extends RefCounted
## Turns a lot of the city data into model instances: picks a model that fits
## the lot, turns it towards its street and scales it with the local density.
## Pure functions of (data, library, building id) -> safe on worker threads and
## the near and far LOD always agree on the same model.

const Kind := CityTypes.Kind
const Cat := ModelCatalog.Cat

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
	Kind.LANDMARK: Color("c9c2b0"), Kind.SHOPPING_CENTER: Color("5aa9d6"),
	Kind.CINEMA: Color("e98b8b"), Kind.OUTPOST: Color("a9876a"), Kind.QUARTER_BLDG: Color("efe6e3"),
	Kind.UN_HQ: Color("4f8fb8"), Kind.MEGA_MALL: Color("2f4f9a"), Kind.PRISON: Color("d7d2c4"),
	Kind.HOTEL: Color("e9dcc8"), Kind.MUSEUM: Color("e6dcc6"), Kind.POST_OFFICE: Color("b5654a"),
	Kind.CEMETERY: Color("74b85a"), Kind.BUNKER: Color("d9b06a"), Kind.AIRBASE: Color("6b6e78"),
	Kind.PHARMACY: Color("f1eff6"), Kind.GAS_STATION: Color("f1eff6"), Kind.CRANE: Color("c0392b"),
	Kind.POLICE_HQ: Color("3f6fd0"), Kind.MAIN_HOSPITAL: Color("f4f2f8"), Kind.MAIN_SCHOOL: Color("e07a5f"),
	Kind.MOUNTAIN: Color("8f8a82"), Kind.FIELD: Color("b9b04a"), Kind.POOR_BLDG: Color("a7a49e"),
	Kind.RUSSIAN: Color("9a8f86"), Kind.PRISON_WING: Color("b59a78"), Kind.OIL_PUMP: Color("3a3a40"),
	Kind.STALL: Color("f2a65a"), Kind.FACTORY_BLDG: Color("9a9a9e"),
	Kind.MCDONALDS: Color("e2b43a"), Kind.BURGER_KING: Color("d6402f"), Kind.URBAN_BLDG: Color("b9bcc6"),
	Kind.URBAN_CLUSTER: Color("4a4f60"),
}

## Procedural meshes per kind (several names = variants picked by seed).
## Main buildings fall back on the small ones when their pack is missing.
const NAMED := {
	Kind.HOSPITAL: ["hospital"], Kind.SCHOOL: ["school"], Kind.FIRE_STATION: ["fire_station"],
	Kind.POLICE: ["police"], Kind.CITY_HALL: ["museum_history"], Kind.STADIUM: ["stadium"],
	Kind.POLICE_HQ: ["police"], Kind.MAIN_HOSPITAL: ["hospital"], Kind.MAIN_SCHOOL: ["school"],
	Kind.MUSEUM: ["museum_art", "museum_history"], Kind.HOTEL: ["hotel_a", "hotel_b"],
	Kind.POST_OFFICE: ["post_office"], Kind.CEMETERY: ["cemetery"], Kind.BUNKER: ["bunker"],
	Kind.AIRBASE: ["airbase"],
	Kind.FIELD: ["field_wheat", "field_corn", "field_plowed", "field_green"],
	Kind.MOUNTAIN: ["mountain_a", "mountain_b", "mountain_c"], Kind.OIL_PUMP: ["oil_pump"],
	Kind.PRISON_WING: ["box"], Kind.MEGA_MALL: ["box"],
	Kind.POOR_BLDG: ["box"], Kind.RUSSIAN: ["box"], Kind.STALL: ["box"], Kind.FACTORY_BLDG: ["box"], Kind.MCDONALDS: ["box"],
	Kind.BURGER_KING: ["box"], Kind.URBAN_BLDG: ["box"], Kind.URBAN_CLUSTER: ["box"],
	Kind.FOUNTAIN: ["fountain"], Kind.BANK: ["bank"], Kind.CHURCH: ["church"],
	Kind.CASINO: ["casino"], Kind.NIGHTCLUB: ["club_a", "club_b", "club_c"],
	Kind.FERRIS_WHEEL: ["ferris_wheel"], Kind.DRIVE_IN: ["drive_in"],
	Kind.LIGHTHOUSE: ["lighthouse"], Kind.TELECOM_TOWER: ["telecom_tower"],
	Kind.SAT_DISH: ["sat_dish"], Kind.MESA: ["mesa"], Kind.POND: ["pond"],
	Kind.UN_HQ: ["un_hq"], Kind.PRISON: ["prison"],
}
## Kinds whose variant is the seed itself (museums, hotels: one of each).
const SEED_VARIANTS: Array[int] = [Kind.MUSEUM, Kind.HOTEL]
## Small props that keep their modelled size instead of filling the lot.
const FIXED_SIZE: Array[int] = [
	Kind.LIGHTHOUSE, Kind.TELECOM_TOWER, Kind.SAT_DISH, Kind.MESA, Kind.POND,
	Kind.FOUNTAIN, Kind.CRANE, Kind.MOUNTAIN, Kind.OIL_PUMP, Kind.STALL,
]
## Las Vegas buildings by the short side of their lot: small bars and chapels,
## clubs, then neon towers and resorts that fill bigger lots.
const VEGAS_BY_SIZE := {
	1: ["club_bar", "chapel", "club_bar"],
	2: ["club_a", "club_b", "club_c", "club_bar", "club_tower"],
	3: ["club_tower", "club_tower_b", "resort", "club_tower"],
}
## Cartoon shops (burger, pizza, diner) are drawn up to this much bigger so they stay visible.
const SHOP_BOOST := 1.7
## Big buildings from the packs grow to fill their (big) lot, up to this scale.
const MAX_FILL := 3.0
## The mall may grow a little more than other public buildings.
const MALL_FILL := 2.0
## Famous New York towers: wider lots and this height at least (stretched a bit).
const LANDMARK_SCALE := 2.1
const LANDMARK_HEIGHT := 11.0


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
	var candidates := ModelPools.candidates(data, lib, i, kind)
	if kind == Kind.FIELD and candidates.is_empty():
		var fid := lib.named_id(NAMED[kind][absi(seed >> 2) % 4])
		return {"id": fid, "xform": _fit_field(lib, fid, r)}
	if candidates.is_empty() and NAMED.has(kind):
		var names: Array = NAMED[kind]
		if kind == Kind.NIGHTCLUB:
			names = VEGAS_BY_SIZE[clampi(mini(r.size.x, r.size.y), 1, 3)]
		var v := absi(seed) if SEED_VARIANTS.has(kind) else (seed >> 3)
		var nid := lib.named_id(names[v % names.size()])
		var fill := 1.0
		if not FIXED_SIZE.has(kind):
			fill = clampf(_named_room(lib, nid, r, facing), 0.5, MAX_FILL)
		return {"id": nid, "xform": _fit(lib, nid, r, facing, fill, 1.0, 0.0, true)}
	if candidates.is_empty():
		var bid := lib.named_id("box")
		var h := 0.6 + density * 3.0
		var t := Transform3D(Basis.from_scale(Vector3(r.size.x * 0.8, h, r.size.y * 0.8)),
				Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5))
		return {"id": bid, "xform": t}
	if kind == Kind.FIELD:
		return {"id": candidates[0], "xform": _fit_field(lib, candidates[0], r)}
	var id := _choose_fitting(lib, candidates, r, facing, seed)
	var scale := 1.0
	var stretch := 1.0
	var room := _room(lib, id, r, facing)
	match kind:
		Kind.SKYSCRAPER:
			# Taller towards the heart of downtown, leaving room between towers.
			# Photo towers (New York glass towers) only get a little taller.
			scale = clampf(room * 0.85, 0.8, 1.25)
			if ModelPools.is_photo_tower(lib, id):
				stretch = 1.15 + density * 0.2
			else:
				stretch = 0.85 + density * 0.55 + float(seed & 7) * 0.03
		Kind.OFFICE:
			scale = clampf(room, 0.8, 1.15)
		Kind.LANDMARK:
			# Empire State, Chrysler...: much higher than the Kenney towers.
			scale = minf(room, LANDMARK_SCALE)
			var h := lib.bounds[id].size.y * scale
			stretch = clampf(LANDMARK_HEIGHT / h, 1.0, 1.5)
		Kind.CRANE:
			scale = 1.0
		Kind.STALL:
			scale = 2.4
		Kind.MEGA_MALL:
			scale = minf(room, MALL_FILL)
		Kind.SHOP:
			var biz := lib.ids(Cat.BIZ_SHOP).has(id) or lib.ids(Cat.BIZ_PIZZA).has(id)
			scale = minf(room, SHOP_BOOST if biz else 1.0)
		_:
			scale = minf(room, MAX_FILL if CityTypes.is_service(kind) else 1.0)
	if ModelPools.is_new_york(lib, id):
		# The New York street buildings stand taller than the Kenney kit.
		stretch = 1.5
	var push := 0.25 if kind == Kind.HOUSE else 0.85
	if CityTypes.is_service(kind):
		push = 0.0
	return {"id": id, "xform": _fit(lib, id, r, facing, scale, stretch, push, false)}


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


## A crop field stretched over its whole lot, long side along the long side of the lot.
static func _fit_field(lib: ModelLibrary, id: int, r: Rect2i) -> Transform3D:
	var b := lib.bounds[id]
	var turn := (r.size.x > r.size.y) != (b.size.x > b.size.z)
	var fx := b.size.z if turn else b.size.x
	var fz := b.size.x if turn else b.size.z
	var basis := Basis(Vector3.UP, PI * 0.5 if turn else 0.0) * Basis.from_scale(
			Vector3(float(r.size.x) * 0.96 / maxf(fx, 0.01), 1.0, float(r.size.y) * 0.96 / maxf(fz, 0.01)))
	var center := Vector3(b.get_center().x, 0, b.get_center().z)
	var lot := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	return Transform3D(basis, lot - basis * center)


## Room of a procedural mesh, turned the way `_fit` turns it (square_fit).
static func _named_room(lib: ModelLibrary, id: int, r: Rect2i, facing: int) -> float:
	var s := lib.bounds[id].size
	var fp := Vector2(s.z, s.x) if facing % 2 == 1 else Vector2(s.x, s.z)
	if r.size.x != r.size.y and (facing % 2 == 1) == (r.size.x > r.size.y):
		fp = Vector2(fp.y, fp.x)
	return minf(r.size.x * 0.96 / fp.x, r.size.y * 0.96 / fp.y)


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
## Helipad of the main hospital model: offset (x, z) from the roof centre and
## size, as fractions of the model width / depth.
const HELIPAD := Vector3(0.0, 0.0, 0.3)

static func _place_extras(data: CityData, lib: ModelLibrary, i: int, kind: int,
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
				var w := box.size.x * 0.55
				batch.add(lib.named_id("un_signs"), xform * Transform3D(Basis.from_scale(Vector3(w, w, w)), front))
		Kind.MAIN_HOSPITAL:
			if ModelPools.is_pack_model(lib, pid, Cat.HOSPITAL_MAIN):
				# Lit red H over the helipad of the roof.
				var pad := Vector3(box.get_center().x + box.size.x * HELIPAD.x, box.end.y + 0.01,
						box.get_center().z + box.size.z * HELIPAD.y)
				var w := box.size.x * HELIPAD.z
				batch.add(lib.named_id("helipad_h"), xform * Transform3D(Basis.from_scale(Vector3(w, 1, w)), pad))
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
		batch.add(trees[h % trees.size()], _tree_xform(p, h))


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


static func _tree_xform(p: Vector3, seed: int) -> Transform3D:
	var s := 1.1 + float((seed >> 5) & 15) / 15.0 * 0.6
	return Transform3D(Basis(Vector3.UP, float(seed & 63) * 0.1).scaled(Vector3(s, s, s)), p)
