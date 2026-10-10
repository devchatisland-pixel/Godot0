extends SceneTree
## Checks the shop placement: every shop of res://shops/catalog.json gets a spot, on free land,
## in one of its zones, not on a road or a building, with its front towards a street.
## Run: godot --headless --script res://tests/test_shops.gd

const Kind := CityTypes.Kind

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

	var by_id := {}
	for p in plan:
		by_id[p["id"]] = by_id.get(p["id"], 0) + 1
	for e in catalog:
		var n: int = by_id.get(e["id"], 0)
		print("[Test]   %-30s %d / %d" % [e["id"], n, e["copies"]])
		if n == 0:
			_fail("no spot found for " + String(e["id"]))

	var taken := {}
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				taken[Vector2i(x, y)] = true
	var zones := {}
	for e in catalog:
		zones[e["id"]] = e["zones"]
	for p in plan:
		var at: Vector2 = p["at"]
		var c := Vector2i(int(floor(at.x)), int(floor(at.y)))
		var id: String = p["id"]
		if not data.is_land(c.x, c.y):
			_fail("%s at %s is not on land" % [id, c])
		if data.is_road(c.x, c.y):
			_fail("%s at %s is on a road" % [id, c])
		if taken.has(c):
			_fail("%s at %s is inside a building" % [id, c])
		if not zones[id].has(data.zone_at(c.x, c.y)) and not ShopSites.FALLBACK_ZONES.has(data.zone_at(c.x, c.y)):
			_fail("%s at %s is in zone %d, neither one of its zones nor a built-up zone" % [id, c, data.zone_at(c.x, c.y)])
		var head := Vector2(-sin(p["yaw"]), -cos(p["yaw"]))
		var front := Vector2i(roundi(float(c.x) + head.x), roundi(float(c.y) + head.y))
		if not data.is_road(front.x, front.y):
			# The front edge may lie further out for a deep shop: look two cells ahead too.
			var front2 := Vector2i(roundi(float(c.x) + head.x * 2.0), roundi(float(c.y) + head.y * 2.0))
			if not data.is_road(front2.x, front2.y):
				_fail("%s at %s does not face a street" % [id, c])
	print("[Test] %s" % ("FAILED: %d" % _fails if _fails > 0 else "all shop checks passed"))
	quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	_fails += 1
	push_error("[Test] " + msg)
	print("[Test] FAIL: ", msg)
