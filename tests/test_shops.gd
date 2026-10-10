extends SceneTree
## Checks the shops of res://shops/catalog.json: every model loads, and the development
## island holds exactly one of each, in a row, on free land of Zone.DEV.
## Run: godot --headless --script res://tests/test_shops.gd

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

var _fails := 0


func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var catalog := MapShops.catalog()
	var plan := ShopSites.plan(data, catalog)
	print("[Test] %d shops planned for %d catalog entries" % [plan.size(), catalog.size()])

	for e in catalog:
		if not ResourceLoader.exists(e["file"]):
			_fail("model missing or not imported: " + String(e["file"]))
		elif not ResourceLoader.load(e["file"]) is PackedScene:
			_fail("not a scene: " + String(e["file"]))

	if plan.size() != catalog.size():
		_fail("expected one shop per catalog entry, got %d for %d" % [plan.size(), catalog.size()])
	var seen := {}
	for p in plan:
		if seen.has(p["id"]):
			_fail("%s placed twice" % p["id"])
		seen[p["id"]] = true
	for e in catalog:
		if not seen.has(e["id"]):
			_fail("not placed: " + String(e["id"]))

	var taken := {}
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[Vector2i(x, y)] = true
	var rects := []
	var by_id := {}
	for e in catalog:
		by_id[e["id"]] = e
	for p in plan:
		var at: Vector2 = p["at"]
		var e: Dictionary = by_id[p["id"]]
		var w: float = e["width"] * ShopSites.CELLS_PER_METRE
		var d: float = e["depth"] * ShopSites.CELLS_PER_METRE
		var rect := Rect2(at - Vector2(w, d) * 0.5, Vector2(w, d))
		for corner in [rect.position, rect.end]:
			var c := Vector2i(int(floor(corner.x)), int(floor(corner.y)))
			var i := data.idx(c.x, c.y)
			if data.zone[i] != Zone.DEV or data.terrain[i] != CityTypes.Terrain.LAND:
				_fail("%s sticks out of the development island at %s" % [p["id"], c])
			if taken.has(c) or data.road[i] != 0:
				_fail("%s overlaps a building or a road at %s" % [p["id"], c])
		for o in rects:
			if rect.grow(-0.01).intersects(o):
				_fail("%s overlaps another shop" % p["id"])
		rects.append(rect)

	# Nothing of the shops anywhere else on the map: the DEV zone is the only place.
	var dev := 0
	for i in data.zone.size():
		if data.zone[i] == Zone.DEV:
			dev += 1
	print("[Test] development island: %d cells" % dev)
	if dev < 100:
		_fail("development island too small")
	print("[Test] %s" % ("FAILED: %d" % _fails if _fails > 0 else "all shop checks passed"))
	quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: ", msg)
