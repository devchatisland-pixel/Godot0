extends SceneTree
## Checks the urban island, the BT tower islet, the Vegas buildings and the watchtowers.
## Run: godot --headless --script res://tests/test_urban_island.gd
## Prints a text map of the urban island (A airport, N plant, c cooling, T tower, I industry,
## H helipad, B BT tower, # road, . land) and exits with an error when a rule is broken.

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
	var airport := _rect(data, Kind.AIRPORT, by_kind)
	var plant := _rect(data, Kind.NUCLEAR_PLANT, by_kind)
	if airport.size.x == 0:
		_fail("no airport")
	if plant.size.x == 0:
		_fail("no nuclear plant")
	var urban_tip := int(Vector2(ExtensionIsland.URBAN["at"]).y)
	if airport.size.x > 0 and airport.end.y < urban_tip + 38:
		_fail("airport is not at the south end: rows %d-%d" % [airport.position.y, airport.end.y])
	if plant.size.x > 0 and plant.get_center().y > UrbanIslandPlanner.NUCLEAR_END:
		_fail("plant is not at the north end: centre row %d" % plant.get_center().y)
	# Nothing in front of the airport; only low industry in front of the plant.
	for b in data.building_count():
		var r := data.building_rect(b)
		var k: int = data.b_kind[b]
		if r.position.x >= ExtensionIsland.URBAN_COLUMNS or r.position.y > 215:
			continue
		if airport.size.x > 0 and k != Kind.AIRPORT and _in_front(airport, r.position) \
				and _in_front(airport, r.end - Vector2i.ONE):
			_fail("%s (B-%05d) at %s stands in front of the airport" % [CityTypes.Kind.keys()[k], b, r])
		if plant.size.x > 0 and _in_front(plant, r.get_center()) and [Kind.URBAN_BLDG, Kind.FUTURE_BLDG,
				Kind.URBAN_CLUSTER, Kind.SKYSCRAPER].has(k):
			_fail("tower B-%05d at %s stands in front of the plant" % [b, r])
		if plant.size.x > 0 and r.position.y < UrbanIslandPlanner.NUCLEAR_END \
				and r.position.x < ExtensionIsland.URBAN_COLUMNS \
				and [Kind.URBAN_BLDG, Kind.FUTURE_BLDG].has(k):
			_fail("%s B-%05d at %s is in the nuclear rows" % [CityTypes.Kind.keys()[k], b, r])
	if not by_kind.has(Kind.COOLING_TOWER) or by_kind[Kind.COOLING_TOWER].size() < 2:
		_fail("fewer than 2 cooling towers")
	if not by_kind.has(Kind.COOLING_HALL):
		_fail("no cooling hall")
	var bt := _rect(data, Kind.BT_TOWER, by_kind)
	var pad := _rect(data, Kind.HELIPAD, by_kind)
	if bt.size.x == 0 or pad.size.x == 0:
		_fail("BT tower or helipad missing")
	elif not (ExtensionIsland.TOWER_ISLET["at"] as Vector2).distance_to(Vector2(bt.get_center())) < 12.0:
		_fail("BT tower is not on its islet: %s" % bt)
	print("[Test] airport %s  plant %s  BT %s  pad %s" % [airport, plant, bt, pad])


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
	if towers < 10:
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
	CivicMeshes.build_all(lib)
	for cat in [ModelCatalog.Cat.URBAN2, ModelCatalog.Cat.NIGHT_TOWER, ModelCatalog.Cat.COOLING,
			ModelCatalog.Cat.COOLING_HALL, ModelCatalog.Cat.BT_TOWER, ModelCatalog.Cat.WATCHTOWER]:
		if not lib.has_cat(cat):
			_fail("model category %s is empty" % ModelCatalog.Cat.keys()[cat])
	var seen := {}
	var tallest_club := 0.0
	for k in [Kind.AIRPORT, Kind.NUCLEAR_PLANT, Kind.COOLING_TOWER, Kind.COOLING_HALL, Kind.BT_TOWER,
			Kind.HELIPAD, Kind.WATCHTOWER, Kind.URBAN_BLDG, Kind.FUTURE_BLDG, Kind.NIGHTCLUB]:
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
			elif k != Kind.HELIPAD and lib.cats[pick["id"]] < 0 and name == "box":
				_fail("%s B-%05d is drawn as a grey box" % [CityTypes.Kind.keys()[k], b])
			if not seen.has(name):
				seen[name] = true
				print("[Test] %-14s %-34s height %.1f" % [CityTypes.Kind.keys()[k], name, h])
	print("[Test] tallest Vegas club: %.1f" % tallest_club)
	if tallest_club > 4.0:
		_fail("a Vegas club is %.1f tall (limit 4.0)" % tallest_club)


func _print_map(data: CityData) -> void:
	var rows := PackedStringArray()
	var glyph := {Kind.AIRPORT: "A", Kind.NUCLEAR_PLANT: "N", Kind.COOLING_TOWER: "c",
			Kind.COOLING_HALL: "c", Kind.URBAN_BLDG: "T", Kind.FUTURE_BLDG: "F", Kind.INDUSTRIAL: "I",
			Kind.INDUSTRIAL_YARD: "y", Kind.HELIPAD: "H", Kind.BT_TOWER: "B"}
	var layer := {}
	for b in data.building_count():
		var r := data.building_rect(b)
		var g: String = glyph.get(int(data.b_kind[b]), "")
		if g == "" or r.position.x >= 60:
			continue
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				layer[Vector2i(x, y)] = g
	for y in range(78, 214):
		var line := ""
		for x in range(0, 56):
			var i := data.idx(x, y)
			var c := " "
			if data.terrain[i] >= CityTypes.Terrain.BEACH:
				c = "#" if data.road[i] != 0 else "."
			if layer.has(Vector2i(x, y)):
				c = layer[Vector2i(x, y)]
			line += c
		rows.append("%3d %s" % [y, line])
	print("\n".join(rows))
