extends SceneTree
## Checks the urban island (two plants and a mass of towers), the BT tower islet, the Vegas
## buildings and the watchtowers.
## Run: godot --headless --script res://tests/test_urban_island.gd
## Prints a text map of the urban island (N plant, F futuristic tower, B BT tower, # road, . land) and exits with an error when a rule is broken.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

var _fails := 0


func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var by_kind := {}
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(b)
	_print_map(data)
	_check_places(data, by_kind)
	_check_towers(data, by_kind)
	_check_watchtowers(data, by_kind)
	_check_edits(data)
	_check_boats(data, by_kind)
	_check_models(cfg, data, by_kind)
	print("[Test] %s" % ("FAILED: %d" % _fails if _fails > 0 else "all urban island checks passed"))
	quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: ", msg)


func _rect(data: CityData, kind: int, by_kind: Dictionary, n: int = 0) -> Rect2i:
	if not by_kind.has(kind) or by_kind[kind].size() <= n:
		return Rect2i()
	return data.building_rect(by_kind[kind][n])


## True when `p` is on a line of sight from `r` to the camera (south-east of it).
func _in_front(r: Rect2i, p: Vector2i) -> bool:
	if p.x < r.position.x or p.y < r.position.y or r.has_point(p):
		return false
	var d := p.x - p.y
	return d >= r.position.x - (r.end.y - 1) and d <= r.end.x - 1 - r.position.y


func _check_places(data: CityData, by_kind: Dictionary) -> void:
	# The island: two plants of one size, one turned half a turn, and nothing but towers else
	# (UrbanIslandRebuild): no street, no fence, no yard, no vehicle.
	var plants: Array = by_kind.get(Kind.NUCLEAR_PLANT, [])
	if plants.size() != 2:
		_fail("expected 2 nuclear plants, found %d" % plants.size())
	else:
		var a := data.building_rect(plants[0])
		var b := data.building_rect(plants[1])
		if a.size != b.size:
			_fail("the two plants differ in size: %s and %s" % [a.size, b.size])
		if (int(data.b_facing[plants[0]]) - int(data.b_facing[plants[1]]) + 4) % 4 != 2:
			_fail("the plants are not turned half a turn from each other (facing %d and %d)" % [
					data.b_facing[plants[0]], data.b_facing[plants[1]]])
		if data.b_seed[plants[0]] != data.b_seed[plants[1]]:
			_fail("the two plants do not draw the same model")
		if a.intersects(b):
			_fail("the plants overlap: %s %s" % [a, b])
	var on_island := 0
	for b in data.building_count():
		var r := data.building_rect(b)
		var k: int = data.b_kind[b]
		if k == Kind.EMPTY or not MapLayout.on_urban_island(r.get_center()) 				or data.terrain[data.idx(r.get_center().x, r.get_center().y)] != CityTypes.Terrain.LAND:
			continue
		on_island += 1
		if k != Kind.FUTURE_BLDG and k != Kind.NUCLEAR_PLANT:
			_fail("%s B-%05d at %s on the urban island: only towers and the plants belong there" % [
					CityTypes.Kind.keys()[k], b, r])
		if k == Kind.FUTURE_BLDG:
			for p in plants:
				if data.building_rect(p).grow(1).intersects(r):
					_fail("tower B-%05d at %s touches a plant (%s)" % [b, r, data.building_rect(p)])
	var roads := 0
	var fences := 0
	for y in data.size:
		for x in MapLayout.cells("urban_columns"):
			if not MapLayout.on_urban_island(Vector2i(x, y)):
				continue
			var i := data.idx(x, y)
			if data.terrain[i] == CityTypes.Terrain.LAND and data.road[i] != 0:
				roads += 1
			if data.deco[i] == AmenitiesPlanner.FENCE_X or data.deco[i] == AmenitiesPlanner.FENCE_Z:
				fences += 1
	if roads > 0:
		_fail("%d road cells on the urban island" % roads)
	if fences > 0:
		_fail("%d fence pieces on the urban island" % fences)
	# No vehicle of the catalog stands on the island.
	var cars := 0
	for v in VehicleSites.plan(data):
		if MapLayout.on_urban_island(Vector2i(v["at"] as Vector2)):
			cars += 1
			_fail("vehicle %s (%s) stands on the urban island" % [v["id"], v["why"]])
	# The south end: the lots are filled, not left empty (the airport is gone).
	var urban_tip := int(Vector2(MapLayout.blob("urban")["at"]).y)
	var south := 0
	for b in by_kind.get(Kind.FUTURE_BLDG, []):
		if data.building_rect(b).position.y > urban_tip + 30:
			south += 1
	if south < 20:
		_fail("only %d towers on the south end of the island" % south)
	var bt := _rect(data, Kind.BT_TOWER, by_kind)
	var islet := MapLayout.blob("tower_islet")["at"] as Vector2
	var dishes := 0
	for b in by_kind.get(Kind.SAT_DISH, []):
		if islet.distance_to(Vector2(data.building_rect(b).get_center())) < 12.0:
			dishes += 1
	if bt.size.x == 0:
		_fail("BT tower missing")
	elif islet.distance_to(Vector2(bt.get_center())) > 2.5:
		_fail("BT tower is not in the middle of its islet: %s" % bt)
	if dishes != 3:
		_fail("expected 3 satellite dishes round the BT tower, found %d" % dishes)
	if bt.size.x > 0 and data.zone_at(bt.position.x, bt.position.y) != Zone.INDUSTRIAL:
		_fail("the BT islet is not an industrial zone")
	print("[Test] urban island: %d buildings, %d towers in the south end, plants %s, %d vehicles; BT %s dishes %d" % [
			on_island, south, plants.map(func(p): return data.building_rect(p)), cars, bt, dishes])


func _check_towers(data: CityData, by_kind: Dictionary) -> void:
	var towers := 0
	var variants := {}
	for k in [Kind.URBAN_BLDG, Kind.FUTURE_BLDG]:
		for b in by_kind.get(k, []):
			towers += 1
			var f: int = data.b_facing[b]
			if f != 1 and f != 2:
				_fail("urban tower B-%05d faces %d (must be east or south)" % [b, f])
			variants[data.b_seed[b] % 97] = true
	print("[Test] urban towers: %d, seed variety %d" % [towers, variants.size()])
	if towers < 400:
		_fail("too few towers on the urban island: %d" % towers)


func _check_watchtowers(data: CityData, by_kind: Dictionary) -> void:
	var list: Array = by_kind.get(Kind.WATCHTOWER, [])
	if list.size() != 2:
		_fail("expected 2 watchtowers, found %d" % list.size())
	for b in list:
		var c := data.building_rect(b).get_center()
		if data.zone_at(c.x, c.y) != Zone.NATURE or data.forest[data.idx(c.x, c.y)] < 100:
			_fail("watchtower B-%05d at %s is not in a forest" % [b, c])
	print("[Test] watchtowers: ", list.map(func(b): return data.building_rect(b)))


## One boat of each kind; the cargo ship by the port, the submarine away from the bridge.
func _check_boats(data: CityData, by_kind: Dictionary) -> void:
	var seeds := {}
	for b in by_kind.get(Kind.BOAT, []):
		var s: int = data.b_seed[b]
		# Two cargo ships: keep the one that lies nearer to the industrial port.
		var port := Vector2(MapLayout.blob("industrial")["at"])
		if not seeds.has(s) or Vector2(data.building_rect(b).get_center()).distance_to(port) \
				< Vector2((seeds[s] as Rect2i).get_center()).distance_to(port):
			seeds[s] = data.building_rect(b)
		print("[Test] boat %d at %s" % [s, data.building_rect(b)])
	if seeds.size() != 5:
		_fail("expected 5 different boats, found %d" % seeds.size())
		return
	var port := Vector2(MapLayout.blob("industrial")["at"])
	if Vector2((seeds[BoatSites.CARGO] as Rect2i).get_center()).distance_to(port) > 35.0:
		_fail("the cargo ship is not near the industrial port")
	# One of the submarines lies off the end of the east highway, away from the bridge.
	var d := INF
	for b in by_kind.get(Kind.BOAT, []):
		if data.b_seed[b] == BoatSites.SUB:
			d = minf(d, Vector2(data.building_rect(b).get_center()).distance_to(Vector2(data.bridge)))
	print("[Test] the nearest submarine is %.0f cells from the end of the highway" % d)
	if d < 12.0 or d > 40.0:
		_fail("the nearest submarine is %.0f cells from the bridge to the fog island" % d)


## Every hand edit (ManualEdits) was applied: the kind, facing and scale are the wanted ones.
func _check_edits(data: CityData) -> void:
	for n in ManualEdits.EDITS.size():
		var e: Dictionary = ManualEdits.EDITS[n]
		if not ManualEdits.resolved.has(n):
			_fail("edit %d (%s near %s) was not applied" % [n, e["kind"], e["near"]])
			continue
		var id: int = ManualEdits.resolved[n]
		var want: String = "EMPTY" if e.get("delete", false) else e.get("replace", e["kind"])
		if CityTypes.Kind.keys()[data.b_kind[id]] != want:
			_fail("edit B-%05d: expected %s, found %s" % [id, want, CityTypes.Kind.keys()[data.b_kind[id]]])
		if e.has("facing") and data.b_facing[id] != e["facing"]:
			_fail("edit B-%05d: facing %d, wanted %d" % [id, data.b_facing[id], e["facing"]])
		if e.has("scale") and not is_equal_approx(data.b_scale[id], e["scale"]):
			_fail("edit B-%05d: scale %.2f, wanted %.2f" % [id, data.b_scale[id], e["scale"]])
		if e.has("sign") and data.b_sign[id] != ModelCatalog.Cat[e["sign"]]:
			_fail("edit B-%05d: sign not set" % id)
		if e.has("scale_abs") and not is_equal_approx(data.b_scale[id], -float(e["scale_abs"])):
			_fail("edit B-%05d: absolute scale not set" % id)
	print("[Test] %d hand edits checked" % ManualEdits.EDITS.size())


## Every new kind gets its real model (not the grey box); Vegas buildings stay low.
func _check_models(cfg: CityConfig, data: CityData, by_kind: Dictionary) -> void:
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(10) < 1.0:
		pass
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	ParkMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	for cat in [ModelCatalog.Cat.NEON_CONTROLLER, ModelCatalog.Cat.NEON_PACMAN, ModelCatalog.Cat.URBAN2, ModelCatalog.Cat.NIGHT_TOWER, ModelCatalog.Cat.COOLING,
			ModelCatalog.Cat.COOLING_HALL, ModelCatalog.Cat.WATCHTOWER]:
		if not lib.has_cat(cat):
			_fail("model category %s is empty" % ModelCatalog.Cat.keys()[cat])
	NightWindows.apply(lib)
	_check_signs(data, lib)
	for cat in [ModelCatalog.Cat.NEON_CONTROLLER, ModelCatalog.Cat.NEON_PACMAN]:
		var b := lib.bounds[lib.ids(cat)[0]]
		print("[Test] neon sign %s: %.1f wide, %.1f high, %.2f thick" % [ModelCatalog.Cat.keys()[cat], b.size.x, b.size.y, b.size.z])
		if b.size.z > b.size.x or b.position.y < -0.01 or b.position.y > 0.01:
			_fail("neon sign %s is not a flat sign standing on y = 0" % ModelCatalog.Cat.keys()[cat])
	var seen := {}
	var tallest_club := 0.0
	for k in [Kind.NUCLEAR_PLANT, Kind.COOLING_TOWER, Kind.COOLING_HALL, Kind.BT_TOWER,
			Kind.WATCHTOWER, Kind.SAT_DISH, Kind.BOAT, Kind.URBAN_BLDG, Kind.FUTURE_BLDG, Kind.NIGHTCLUB]:
		for b in by_kind.get(k, []):
			var pick := BuildingPlacer.pick_for(data, lib, b)
			if not pick.has("id") or pick["id"] < 0:
				_fail("%s B-%05d has no model" % [CityTypes.Kind.keys()[k], b])
				continue
			var xf: Transform3D = pick["xform"]
			var h: float = lib.bounds[pick["id"]].size.y * xf.basis.get_scale().y
			var name := lib.model_name(pick["id"])
			if k == Kind.NIGHTCLUB:
				tallest_club = maxf(tallest_club, h)
			elif lib.cats[pick["id"]] < 0 and name == "box":
				_fail("%s B-%05d is drawn as a grey box" % [CityTypes.Kind.keys()[k], b])
			if k == Kind.FUTURE_BLDG:
				_check_sight(data, by_kind, lib, b, h)
			if not seen.has(name):
				seen[name] = true
				print("[Test] %-14s %-34s height %.1f" % [CityTypes.Kind.keys()[k], name, h])
	print("[Test] tallest Vegas club: %.1f" % tallest_club)
	if tallest_club > 4.0:
		_fail("a Vegas club is %.1f tall (limit 4.0)" % tallest_club)


## A tower on the line of sight of a plant is no taller than what the camera (30 degrees down)
## still sees the plant over: the towers rise like seats in a stadium.
func _check_sight(data: CityData, by_kind: Dictionary, lib: ModelLibrary, b: int, h: float) -> void:
	var r := data.building_rect(b)
	for p in by_kind.get(Kind.NUCLEAR_PLANT, []):
		var pr := data.building_rect(p)
		var pick := BuildingPlacer.pick_for(data, lib, p)
		var top: float = lib.bounds[pick["id"]].size.y * (pick["xform"] as Transform3D).basis.get_scale().y
		for c: Vector2i in [r.position, r.end - Vector2i.ONE]:
			if _in_front(pr, c):
				var k := maxi(maxi(r.position.x - (pr.end.x - 1), r.position.y - (pr.end.y - 1)), 0)
				var limit := top + 1.0 + 0.5774 * float(k) * 1.4142
				if h > limit:
					_fail("tower B-%05d at %s is %.1f tall, hides the plant at %s (limit %.1f)" % [b, r, h, pr, limit])
				return


## The neon signs are drawn on their buildings: the wall sign on the south face, the roof sign
## on the roof, each with its glow copy.
func _check_signs(data: CityData, lib: ModelLibrary) -> void:
	for b in data.building_count():
		if data.b_sign[b] == 0:
			continue
		var batch := InstanceBatch.new()
		BuildingPlacer.place(data, lib, b, batch, false)
		var pick := BuildingPlacer.pick_for(data, lib, b)
		var body: AABB = (pick["xform"] as Transform3D) * lib.bounds[pick["id"]]
		var cat: int = data.b_sign[b]
		var sign_id: int = lib.ids(cat)[0]
		var halo_id := lib.named_id("neon_halo_%d" % cat)
		if not batch.transforms.has(sign_id) or not batch.transforms.has(halo_id):
			_fail("B-%05d has no sign or halo in its batch" % b)
			continue
		var t: PackedFloat32Array = batch.transforms[sign_id]
		# Transform3D is stored as 12 floats: basis rows then origin.
		var origin := Vector3(t[3], t[7], t[11])
		print("[Test] B-%05d sign %s at %s, building box %s" % [b, ModelCatalog.Cat.keys()[cat], origin, body])
		if origin.y < body.position.y or origin.y > body.end.y + 0.1:
			_fail("B-%05d sign height %.2f is outside the building (%.2f..%.2f)" % [b, origin.y, body.position.y, body.end.y])


func _print_map(data: CityData) -> void:
	var rows := PackedStringArray()
	var glyph := {Kind.AIRPORT: "A", Kind.NUCLEAR_PLANT: "N", Kind.COOLING_TOWER: "c",
			Kind.COOLING_HALL: "c", Kind.URBAN_BLDG: "T", Kind.FUTURE_BLDG: "F", Kind.INDUSTRIAL: "I",
			Kind.INDUSTRIAL_YARD: "y", Kind.SAT_DISH: "d", Kind.BT_TOWER: "B"}
	var layer := {}
	for b in data.building_count():
		var r := data.building_rect(b)
		var g: String = glyph.get(int(data.b_kind[b]), "")
		if g == "" or r.position.x >= MapLayout.cells("urban_columns"):
			continue
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				layer[Vector2i(x, y)] = g
	for y in range(108, 290, 2):
		var line := ""
		for x in range(0, MapLayout.cells("urban_columns")):
			var i := data.idx(x, y)
			var c := " "
			if data.terrain[i] >= CityTypes.Terrain.BEACH:
				c = "#" if data.road[i] != 0 else "."
			if layer.has(Vector2i(x, y)):
				c = layer[Vector2i(x, y)]
			line += c
		rows.append("%3d %s" % [y, line])
	print("\n".join(rows))
