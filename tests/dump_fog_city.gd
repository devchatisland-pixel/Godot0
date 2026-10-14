extends SceneTree
## Draws the fog island (land, streets, buildings by kind) top-down and prints counts:
## godot --headless --path . --script res://tests/dump_fog_city.gd -- <out.png>

func _init() -> void:
	var out := "user://fog_city.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var cfg := CityConfig.create()
	var data := CityData.new(cfg.map_size, cfg.chunk_size)
	data.bridge = Vector2i(316, 191)
	var fog := FogIslandShaper.new(cfg, data)
	fog.shape(FogIslandShaper.SIZE / 2)
	var t0 := Time.get_ticks_msec()
	var plan := FogBaseSites.plan(fog)
	var roads := FogBaseSites.roads(fog)
	print("[Fog] plan in %d ms: %d items, %d roads" % [Time.get_ticks_msec() - t0, plan.size(), roads.size()])
	print("[Fog] city stats: ", FogCityLayout.stats)
	var k := 5
	var n := FogIslandShaper.SIZE
	var img := Image.create(n * k, n * k, false, Image.FORMAT_RGB8)
	img.fill(Color(0.16, 0.45, 0.66))
	for y in n:
		for x in n:
			if fog.elevation[y * n + x] > 128:
				var i := (y * n + x) * 4
				var c := Color8(fog.colors[i], fog.colors[i + 1], fog.colors[i + 2])
				for oy in k:
					for ox in k:
						img.set_pixel(x * k + ox, y * k + oy, c)
	for r in roads:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var steps := int(a.distance_to(b) * k) + 1
		for s in steps + 1:
			var q := a.lerp(b, float(s) / steps) * k
			var w := int(float(r[2]) * k * 0.5)
			for oy in range(-w, w + 1):
				for ox in range(-w, w + 1):
					var px := int(q.x) + ox
					var py := int(q.y) + oy
					if px >= 0 and py >= 0 and px < n * k and py < n * k:
						img.set_pixel(px, py, Color(0.3, 0.3, 0.35))
	var counts := {}
	for p in plan:
		var col := Color(0.8, 0.55, 0.3)
		var size := 1.6
		var kind := "other"
		if p.has("shop"):
			col = Color(1, 0, 1)
			kind = "shop"
			size = 3.0
		elif p.has("veh"):
			col = Color(0, 1, 1)
			kind = "vehicle"
			size = 1.0
		elif p.has("named"):
			col = Color(0.75, 0.7, 0.2)
			kind = "field/yard"
			size = 3.0
			if p.has("size"):
				var sz: Vector2 = p["size"]
				size = sz.x
		elif p.has("cat"):
			size = float(p.get("fit", 2.0))
			var c: int = p["cat"]
			kind = ModelCatalog.Cat.keys()[c]
			if kind.begins_with("FOG_"):
				col = Color(1, 0.9, 0.3) if p.get("stack", 1) > 1 or c == ModelCatalog.Cat.FOG_NIGHT_TOWER or c == ModelCatalog.Cat.FOG_OFFICE_TOWER or c == ModelCatalog.Cat.FOG_MOD_TOWER else Color(0.85, 0.5, 0.3)
			else:
				col = Color(1, 0.2, 0.2)
		counts[kind] = counts.get(kind, 0) + 1
		var at: Vector2 = p["at"]
		var half := int(size * k * 0.5)
		for oy in range(-half, half + 1):
			for ox in range(-half, half + 1):
				var px := int(at.x * k) + ox
				var py := int(at.y * k) + oy
				if px >= 0 and py >= 0 and px < n * k and py < n * k:
					img.set_pixel(px, py, col)
	print("[Fog] by kind: ", counts)
	img.save_png(out)
	print("[Fog] saved ", out)
	quit(0)
