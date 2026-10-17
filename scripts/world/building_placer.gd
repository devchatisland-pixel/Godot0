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
	Kind.CASINO: Color("8e3a9a"), Kind.NIGHTCLUB: Color("e8a98a"),
	Kind.FERRIS_WHEEL: Color("f4f2f8"), Kind.DRIVE_IN: Color("4c4f5e"),
	Kind.LIGHTHOUSE: Color("d23b2f"), Kind.TELECOM_TOWER: Color("d23b2f"),
	Kind.SAT_DISH: Color("f4f2f8"), Kind.MESA: Color("c98a4b"), Kind.POND: Color("5fb7e0"),
	Kind.LANDMARK: Color("c9c2b0"), Kind.SHOPPING_CENTER: Color("5aa9d6"),
	Kind.CINEMA: Color("e98b8b"), Kind.OUTPOST: Color("a9876a"), Kind.QUARTER_BLDG: Color("efe6e3"),
	Kind.UN_HQ: Color("4f8fb8"), Kind.PRISON: Color("d7d2c4"),
	Kind.HOTEL: Color("e9dcc8"), Kind.MUSEUM: Color("e6dcc6"), Kind.POST_OFFICE: Color("b5654a"),
	Kind.CEMETERY: Color("74b85a"), Kind.BUNKER: Color("d9b06a"), Kind.AIRBASE: Color("6b6e78"),
	Kind.PHARMACY: Color("f1eff6"), Kind.GAS_STATION: Color("f1eff6"), Kind.CRANE: Color("c0392b"),
	Kind.POLICE_HQ: Color("3f6fd0"), Kind.MAIN_HOSPITAL: Color("f4f2f8"), Kind.MAIN_SCHOOL: Color("e07a5f"),
	Kind.MOUNTAIN: Color("8f8a82"), Kind.FIELD: Color("b9b04a"), Kind.POOR_BLDG: Color("a7a49e"),
	Kind.RUSSIAN: Color("9a8f86"), Kind.PRISON_WING: Color("b59a78"), Kind.OIL_PUMP: Color("3a3a40"),
	Kind.STALL: Color("f2a65a"), Kind.FACTORY_BLDG: Color("9a9a9e"),
	Kind.MCDONALDS: Color("e2b43a"), Kind.BURGER_KING: Color("d6402f"), Kind.URBAN_BLDG: Color("b9bcc6"),
	Kind.URBAN_CLUSTER: Color("4a4f60"), Kind.NUCLEAR_PLANT: Color("b9bcb8"), Kind.CINEMA_MAIN: Color("e98b8b"),
	Kind.AIRPORT: Color("9aa0aa"), Kind.BURGER_JOINT: Color("d6402f"),
	Kind.COOLING_TOWER: Color("c9c6bd"), Kind.COOLING_HALL: Color("b9b6ad"), Kind.BT_TOWER: Color("c7c3bb"),
	Kind.WATCHTOWER: Color("8a6a45"), Kind.BEACH_HUT: Color("c9954a"), Kind.PIER: Color("8a6a45"), Kind.BOAT: Color("7a6a5a"),
	Kind.FIRE_TRUCK: Color("c0392b"), Kind.BALLOON: Color("e2573b"), Kind.BILLBOARD: Color("d8d3c4"), Kind.UFO: Color("b9bcc6"), Kind.TANK: Color("5f6a4a"),
	Kind.BUS_STOP: Color("3f8f5a"), Kind.SKYLINE_BLDG: Color("4a5068"),
	Kind.BASKET_COURT: Color("7d7078"), Kind.RESTAURANT: Color("d98a5a"), Kind.PIZZA_SHOP: Color("e8cfc8"),
	Kind.BURGER_SHOP: Color("e0553a"), Kind.CAFE: Color("e8b0a0"), Kind.VEGAS_SIGN: Color("c0392b"),
}

## Procedural meshes per kind (several names = variants picked by seed).
## Main buildings fall back on the small ones when their pack is missing.
const NAMED := {
	Kind.HOSPITAL: ["hospital"], Kind.SCHOOL: ["school"], Kind.FIRE_STATION: ["fire_station"],
	Kind.POLICE: ["police"], Kind.CITY_HALL: ["museum_history"], Kind.STADIUM: ["stadium"],
	Kind.POLICE_HQ: ["police"], Kind.MAIN_HOSPITAL: ["hospital"], Kind.MAIN_SCHOOL: ["school"],
	Kind.MUSEUM: ["museum_art", "museum_history"],
	Kind.POST_OFFICE: ["post_office"], Kind.CEMETERY: ["cemetery"], Kind.BUNKER: ["bunker"],
	Kind.AIRBASE: ["airbase"],
	Kind.FIELD: ["field_wheat", "field_corn", "field_plowed", "field_green"],
	Kind.MOUNTAIN: ["mountain_a", "mountain_b", "mountain_c"], Kind.OIL_PUMP: ["oil_pump"],
	Kind.PRISON_WING: ["box"],
	Kind.POOR_BLDG: ["box"], Kind.RUSSIAN: ["box"], Kind.STALL: ["box"], Kind.FACTORY_BLDG: ["box"], Kind.MCDONALDS: ["box"],
	Kind.BURGER_KING: ["box"], Kind.URBAN_BLDG: ["box"], Kind.URBAN_CLUSTER: ["box"],
	Kind.FUTURE_BLDG: ["box"], Kind.PIRATE_SHIP: ["box"], Kind.GRAVE: ["grave"],
	Kind.NUCLEAR_PLANT: ["box"], Kind.CINEMA_MAIN: ["box"], Kind.AIRPORT: ["box"], Kind.BURGER_JOINT: ["box"],
	Kind.COOLING_TOWER: ["box"], Kind.COOLING_HALL: ["box"], Kind.BT_TOWER: ["bt_tower"], Kind.WATCHTOWER: ["box"], Kind.BEACH_HUT: ["box"], Kind.PIER: ["box"], Kind.BOAT: ["box"],
	Kind.FIRE_TRUCK: ["box"], Kind.BALLOON: ["box"], Kind.BILLBOARD: ["box"],
	Kind.UFO: ["box"], Kind.TANK: ["box"], Kind.BUS_STOP: ["box"], Kind.SKYLINE_BLDG: ["box"], Kind.BASKET_COURT: ["box"],
	Kind.RESTAURANT: ["box"], Kind.PIZZA_SHOP: ["box"], Kind.BURGER_SHOP: ["box"], Kind.CAFE: ["box"], Kind.VEGAS_SIGN: ["box"],
	Kind.FOUNTAIN: ["fountain"], Kind.BANK: ["bank"], Kind.CHURCH: ["church"],
	Kind.CASINO: ["casino"], Kind.NIGHTCLUB: ["club_a", "club_b", "club_c"],
	Kind.FERRIS_WHEEL: ["ferris_wheel"], Kind.DRIVE_IN: ["drive_in"],
	Kind.LIGHTHOUSE: ["lighthouse"], Kind.TELECOM_TOWER: ["telecom_tower"],
	Kind.SAT_DISH: ["sat_dish"], Kind.MESA: ["mesa"], Kind.POND: ["pond"],
	Kind.UN_HQ: ["un_hq"], Kind.PRISON: ["prison"],
}
## Kinds whose variant is the seed itself (museums: one of each).
const SEED_VARIANTS: Array[int] = [Kind.MUSEUM]
## Small props that keep their modelled size instead of filling the lot.
const FIXED_SIZE: Array[int] = [
	Kind.LIGHTHOUSE, Kind.TELECOM_TOWER, Kind.SAT_DISH, Kind.MESA, Kind.POND,
	Kind.FOUNTAIN, Kind.CRANE, Kind.MOUNTAIN, Kind.OIL_PUMP, Kind.STALL, Kind.GRAVE, Kind.BT_TOWER,
]
## Extra size of some fixed props (the radio tower is twice as big, mountains tower over the forest).
const KIND_SCALE := {Kind.TELECOM_TOWER: 2.0, Kind.MOUNTAIN: 1.5, Kind.GRAVE: 1.6, Kind.LIGHTHOUSE: 1.65,
		Kind.SCHOOL: 1.17}  # regular schools 17 % bigger
## Things that float: height above the ground (in cells).
const KIND_LIFT := {Kind.BALLOON: 8.0}
## Models drawn bigger than modelled (by model name), as far as the lot allows.
const MODEL_BOOST := {"free_mini.glb: m7": 1.15}
## Models drawn this much smaller than they would fit their lot.
const MODEL_SHRINK := {"museum_hall.glb: museum_hall": 0.75}
## The business pack shop is drawn like an office (0.8 to 1.15 of its size) whatever the kind of
## the building, on the east side (a restaurant of that model was drawn much bigger).
const BIZ_SHOP_MODEL := "business.glb: shop"
## The row of skyscraper towers of the Las Vegas casino (ManualEdits) is stretched this much in height.
const CASINO_TOWER_STRETCH := 2.3
## Schools are drawn this much bigger (all round); tanks this much smaller.
const SCHOOL_SCALE := 1.1
const TANK_SHRINK := 0.9
## Las Vegas buildings are drawn at most this much bigger than modelled (they were skyscraper size).
const VEGAS_MAX_FILL := 1.2
## Cooling towers beside the nuclear plant, the BT tower and the watchtowers: largest scale.
const COOLING_SCALE := 2.2
const WATCHTOWER_SCALE := 1.35
## Positions of the vehicles in the STALL list (the others are kiosks).
const STALL_VEHICLES: Array[int] = [0, 6, 7]
## Seed of the mountain of the core forest: the biggest of the three.
const BIG_MOUNTAIN_SEED := 16
## The U.N. tower is half the size it was.
const UN_SCALE := 1.5
## Size of the radar dish that stands for a satellite dish (its own size, whatever the lot).
const DISH_SCALE := 1.25
## Share of its lot a tower of the urban island covers: they stand wall to wall.
const SKYLINE_FILL := 0.985
## Futuristic towers of the urban island: a bit wider than their lot allows for others, much taller.
const FUTURE_STRETCH := 1.5
## Futuristic towers that look bad: drawn as this model of the night city instead (stretched like it).
const BAD_FUTURE_TOWERS := ["tower_g", "tower_k"]
const FUTURE_REPLACEMENT := "city_night.glb: city_night_03_b"
## Las Vegas buildings by the short side of their lot: small bars and chapels,
## clubs, then neon towers and resorts that fill bigger lots.
const VEGAS_BY_SIZE := {
	1: ["club_bar", "chapel", "club_bar"],
	2: ["club_a", "club_b", "club_c", "club_bar", "club_tower"],
	3: ["club_tower", "club_tower_b", "resort", "club_tower"],
}
## Big buildings from the packs grow to fill their (big) lot, up to this scale.
const MAX_FILL := 3.0
## Famous New York towers: wider lots and this height at least (stretched a bit).
const LANDMARK_SCALE := 2.1
const LANDMARK_HEIGHT := 11.0


## Adds the models of building `i` to `batch` (near LOD) or a box (far LOD).
static func place(data: CityData, lib: ModelLibrary, i: int, batch: InstanceBatch, far: bool) -> void:
	var kind: int = data.b_kind[i]
	if kind == Kind.EMPTY:
		return
	if kind == Kind.CONCERT:
		BuildingExtras.place_concert(data, lib, i, batch, far)
		return
	if kind == Kind.PLAZA or kind == Kind.GARDEN or kind == Kind.INDUSTRIAL_YARD:
		if not far:
			BuildingExtras.place_filler(data, lib, i, kind, batch)
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
	BuildingExtras.place_extras(data, lib, i, kind, pick, batch)


## The model and transform used for building `i`, or {} for fillers without a model
## (plazas, gardens, yards). Same choice as `place`, so the picker highlights the right thing.
## `facing` >= 0 asks for the model as if the building faced that way (signs keep their place).
static func pick_for(data: CityData, lib: ModelLibrary, i: int, facing: int = -1) -> Dictionary:
	var kind: int = data.b_kind[i]
	if kind == Kind.PLAZA or kind == Kind.GARDEN or kind == Kind.INDUSTRIAL_YARD or kind == Kind.EMPTY:
		return {}
	if kind == Kind.CONCERT:
		return BuildingExtras.concert_stage(data, lib, i) # the stage stands for the whole camp
	return _pick_model(data, lib, i, facing)


# --- Model choice ------------------------------------------------------------------------
## The cartoon houses "house1" and "house2" never face north: they are turned to face south.
## Buildings drawn with a model whose name starts like this are left out of the city.
const REMOVED_MODEL_PREFIX := "ny_buildings.glb: ny_brick_"
const SOUTH_ONLY_MODELS := ["carto.glb: house1", "carto.glb: house2"]


static func _pick_model(data: CityData, lib: ModelLibrary, i: int, facing_override: int = -1) -> Dictionary:
	# The jail is the whole walled prison of PrisonCompound: the cellhouse lot has no model of its own.
	if data.b_kind[i] == Kind.PRISON:
		return {}
	var pick := _pick_model_raw(data, lib, i, facing_override)
	# The New York brick buildings are not built at all (taken away by hand).
	if not pick.is_empty() and lib.model_name(pick["id"]).begins_with(REMOVED_MODEL_PREFIX):
		return {}
	var facing: int = data.b_facing[i] if facing_override < 0 else facing_override
	if facing == 0 and not pick.is_empty() and SOUTH_ONLY_MODELS.has(lib.model_name(pick["id"])):
		return _pick_model_raw(data, lib, i, 2)
	# The shop that stands for Kenney's building-n faces south or east: north turns to south, west to east.
	if (facing == 0 or facing == 3) and not pick.is_empty() and lib.ids(Cat.BIZ_SHOP).has(pick["id"]):
		return _pick_model_raw(data, lib, i, 2 if facing == 0 else 1)
	return pick


## Name of the procedural model a Las Vegas club is drawn with (the same choice as `_pick_model_raw`).
static func club_model_name(data: CityData, i: int) -> String:
	var r := data.building_rect(i)
	var names: Array = VEGAS_BY_SIZE[clampi(mini(r.size.x, r.size.y), 1, 3)]
	return names[(data.b_seed[i] >> 3) % names.size()]


static func _pick_model_raw(data: CityData, lib: ModelLibrary, i: int, facing_override: int = -1) -> Dictionary:
	var kind: int = data.b_kind[i]
	var r := data.building_rect(i)
	var facing: int = data.b_facing[i] if facing_override < 0 else facing_override
	var seed: int = data.b_seed[i]
	var density: float = data.b_height[i]
	var candidates := ModelPools.candidates(data, lib, i, kind)
	var wanted: String = data.b_model.get(i, "")
	if wanted.begins_with("shop:") and lib.named_id(wanted) < 0:
		# A shop of the catalog (res://shops) standing in the city: loaded the first time it is needed.
		var sid := MapShops.mesh_id(lib, wanted.substr(5))
		if sid >= 0:
			NightWindows.light_own(lib.meshes[sid])
	var forced: int = lib.names.find(wanted) if data.b_model.has(i) else -1
	if forced >= 0:
		candidates = PackedInt32Array([forced])
	if kind == Kind.FIELD and candidates.is_empty():
		var fid := lib.named_id(NAMED[kind][absi(seed >> 2) % 4])
		return {"id": fid, "xform": _fit_field(lib, fid, r, _laid_across(data, i, facing))}
	if candidates.is_empty() and NAMED.has(kind):
		var names: Array = NAMED[kind]
		if kind == Kind.NIGHTCLUB:
			names = VEGAS_BY_SIZE[clampi(mini(r.size.x, r.size.y), 1, 3)]
		var v := absi(seed) if SEED_VARIANTS.has(kind) else (seed >> 3)
		var nid := lib.named_id(names[v % names.size()])
		var fill := 1.0
		if not FIXED_SIZE.has(kind):
			fill = clampf(_named_room(lib, nid, r, facing), 0.5, MAX_FILL)
		if kind == Kind.NIGHTCLUB:
			fill = minf(fill, VEGAS_MAX_FILL)
		fill *= KIND_SCALE.get(kind, 1.0)
		if kind == Kind.MOUNTAIN and seed == BIG_MOUNTAIN_SEED:
			fill *= 1.4
		fill = _sized(fill, data.b_scale[i])
		return {"id": nid, "xform": _fit(lib, nid, r, facing, fill, 1.0, 0.0, true)}
	if candidates.is_empty():
		var bid := lib.named_id("box")
		var h := 0.6 + density * 3.0
		var t := Transform3D(Basis.from_scale(Vector3(r.size.x * 0.8, h, r.size.y * 0.8)),
				Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5))
		return {"id": bid, "xform": t}
	if kind == Kind.SKYLINE_BLDG:
		return {"id": candidates[0], "xform": _fill_lot(lib, candidates[0], r)}
	if kind == Kind.FIELD:
		return {"id": candidates[0], "xform": _fit_field(lib, candidates[0], r, _laid_across(data, i, facing))}
	var id := _choose_fitting(lib, candidates, r, facing, seed)
	id = ModelPools.shop_for_building_n(lib, id)
	var swapped := false
	if kind == Kind.FUTURE_BLDG:
		var model := lib.model_name(id)
		for bad in BAD_FUTURE_TOWERS:
			var good := lib.names.find(FUTURE_REPLACEMENT)
			if model.ends_with(bad) and good >= 0:
				id = good
				swapped = true
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
		Kind.SCHOOL, Kind.MAIN_SCHOOL:
			scale = minf(room, MAX_FILL) * SCHOOL_SCALE
		Kind.TANK:
			scale = minf(room, 1.0) * TANK_SHRINK
		Kind.STALL:
			# Kiosks are big enough to see; the three vehicles (ice cream truck, food truck, caravan)
			# are half that size.
			scale = 1.2 if STALL_VEHICLES.has(lib.ids(Cat.STALL).find(id)) else 2.4
		Kind.UN_HQ:
			scale = minf(room, UN_SCALE)
		Kind.SAT_DISH:
			scale = DISH_SCALE
		Kind.COOLING_TOWER, Kind.COOLING_HALL:
			scale = minf(room, COOLING_SCALE)
		Kind.WATCHTOWER:
			scale = minf(room, WATCHTOWER_SCALE)
		Kind.UFO:
			scale = minf(room, 0.3) # a little saucer
		Kind.BURGER_JOINT:
			scale = minf(room, 1.0) # regular size (they used to be drawn up to 3 times bigger)
		Kind.FUTURE_BLDG:
			scale = minf(room, 1.0 if swapped else 1.15)
			stretch = 1.0 if swapped else FUTURE_STRETCH
		Kind.URBAN_CLUSTER:
			scale = minf(room, 1.0)
			stretch = 1.6
		_:
			scale = minf(room, MAX_FILL if CityTypes.is_service(kind) else 1.0)
	if lib.model_name(id) == BIZ_SHOP_MODEL and facing == 1 and kind != Kind.OFFICE:
		scale = clampf(room, 0.8, 1.15)
	if kind == Kind.CASINO and data.b_model.get(i, "") == ManualEdits.CASINO_MODEL:
		stretch = CASINO_TOWER_STRETCH
	if ModelPools.is_new_york(lib, id):
		# The New York street buildings stand taller than the Kenney kit.
		stretch = 1.5
	stretch *= data.b_stretch[i]
	var boost: float = MODEL_BOOST.get(lib.model_name(id), 1.0)
	if boost != 1.0:
		scale = maxf(scale, 1.0) * boost # not limited by the lot: the house may overhang
	scale *= MODEL_SHRINK.get(lib.model_name(id), 1.0)
	scale = _sized(scale, data.b_scale[i])
	var push := 1.0 # up to the road: the front of every building touches it (FaceRoads)
	if CityTypes.is_service(kind):
		push = 0.0
	var placed := _fit(lib, id, r, facing, scale, stretch, push, false)
	if KIND_LIFT.has(kind):
		placed.origin.y += KIND_LIFT[kind]
	return {"id": id, "xform": placed}


## `base` times the building's size factor; a negative factor is an absolute scale (ManualEdits).
static func _sized(base: float, factor: float) -> float:
	return -factor if factor < 0.0 else base * factor


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
## True when field `i` is laid along its facing (ManualEdits "lay") and that turns it a
## quarter from the way it fits its lot (facing east or west).
static func _laid_across(data: CityData, i: int, facing: int) -> bool:
	return data.b_lay[i] == 1 and facing % 2 == 1


## Field model stretched over lot `r`; `across` turns it a quarter (its rows the other way).
static func _fit_field(lib: ModelLibrary, id: int, r: Rect2i, across: bool = false) -> Transform3D:
	var b := lib.bounds[id]
	var turn := ((r.size.x > r.size.y) != (b.size.x > b.size.z)) != across
	var fx := b.size.z if turn else b.size.x
	var fz := b.size.x if turn else b.size.z
	var basis := Basis(Vector3.UP, PI * 0.5 if turn else 0.0) * Basis.from_scale(
			Vector3(float(r.size.x) * 0.96 / maxf(fx, 0.01), 1.0, float(r.size.y) * 0.96 / maxf(fz, 0.01)))
	var center := Vector3(b.get_center().x, 0, b.get_center().z)
	var lot := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	return Transform3D(basis, lot - basis * center)


## Model `id` stretched over the whole lot `r` (turned a quarter when that keeps its shape
## better); its height grows with the mean of the two stretches.
static func _fill_lot(lib: ModelLibrary, id: int, r: Rect2i) -> Transform3D:
	var b := lib.bounds[id]
	var straight := absf(log(float(r.size.x) * b.size.z / (float(r.size.y) * b.size.x)))
	var turned := absf(log(float(r.size.x) * b.size.x / (float(r.size.y) * b.size.z)))
	var turn := turned < straight
	var sx := float(r.size.x) * SKYLINE_FILL / maxf(b.size.z if turn else b.size.x, 0.01)
	var sz := float(r.size.y) * SKYLINE_FILL / maxf(b.size.x if turn else b.size.z, 0.01)
	var s := Vector3(sz, sqrt(sx * sz), sx) if turn else Vector3(sx, sqrt(sx * sz), sz)
	var basis := Basis(Vector3.UP, PI * 0.5 if turn else 0.0) * Basis.from_scale(s)
	var lot := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	return Transform3D(basis, lot - basis * Vector3(b.get_center().x, b.position.y, b.get_center().z))


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
