extends SceneTree
## Draws the continent layout (land, streets, highways, bridges, buildings) as a top-down PNG:
## godot --headless --path . --script res://tests/dump_continent.gd -- <out.png>
## The fog island is built from a dummy city (bridge cell as on the real map).

func _init() -> void:
	var out := "user://continent.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var cfg := CityConfig.create()
	var data := CityData.new(cfg.map_size, cfg.chunk_size)
	data.bridge = Vector2i(316, 191)
	data.fog = FogIslandShaper.new(cfg, data)
	data.fog.shape(FogIslandShaper.SIZE / 2)
	var t0 := Time.get_ticks_msec()
	var c := ContinentShaper.new(cfg, data)
	c.shape()
	print("[Continent] ", c.timings)
	print("[Continent] shaped in %d ms: %d buildings, %d highways, %d bridges" % [
			Time.get_ticks_msec() - t0, c.b_model.size(), c.highways.size(), c.bridges.size()])
	for b in c.bridges:
		print("[Continent] bridge ", b)
	# World window drawn: x 300..760, z -100..380, 3 px per cell.
	var x0 := 300.0
	var z0 := -100.0
	var k := 3
	var w := int(460 * k)
	var h := int(480 * k)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.16, 0.45, 0.66))
	var tw := ContinentShaper.SIZE.x * ContinentShaper.RES
	for py in h:
		for px in w:
			var wx := x0 + float(px) / k
			var wz := z0 + float(py) / k
			var lx := wx - ContinentShaper.ORIGIN.x
			var lz := wz - ContinentShaper.ORIGIN.y
			if lx >= 0 and lz >= 0 and lx < ContinentShaper.SIZE.x and lz < ContinentShaper.SIZE.y:
				var cx := int(lx)
				var cz := int(lz)
				if c.elevation[cz * ContinentShaper.SIZE.x + cx] > 128 + 12:
					var tx := int(lx * ContinentShaper.RES)
					var ty := int(lz * ContinentShaper.RES)
					var i := (ty * tw + tx) * 4
					img.set_pixel(px, py, Color8(c.colors[i], c.colors[i + 1], c.colors[i + 2]))
				elif c.elevation[cz * ContinentShaper.SIZE.x + cx] > 128:
					img.set_pixel(px, py, Color("e8d9a0"))
			# fog island
			var fx := int(wx - data.fog.origin.x)
			var fz := int(wz - data.fog.origin.y)
			if fx >= 0 and fz >= 0 and fx < FogIslandShaper.SIZE and fz < FogIslandShaper.SIZE:
				if data.fog.elevation[fz * FogIslandShaper.SIZE + fx] > 128:
					img.set_pixel(px, py, Color("7fae5c"))
	for i in c.b_model.size():
		var p := c.b_pos[i]
		var v: Vector3 = ContinentShaper.MODELS[c.b_model[i]]
		var s := c.b_scale[i]
		var hw := v.x * s * 0.5
		var hd := v.z * s * 0.5
		var col := Color(0.35, 0.3, 0.4).lerp(Color(0.95, 0.85, 0.5), clampf(v.y / 10.0, 0.0, 1.0))
		var yaw := c.b_yaw[i]
		var cs := cos(yaw)
		var sn := sin(yaw)
		for a in range(-int(hw * k * 2), int(hw * k * 2) + 1):
			for b in range(-int(hd * k * 2), int(hd * k * 2) + 1):
				var lx := a / (2.0 * k)
				var lz := b / (2.0 * k)
				var wx := p.x + lx * cs + lz * sn
				var wz := p.y - lx * sn + lz * cs
				var px := int((wx - x0) * k)
				var py := int((wz - z0) * k)
				if px >= 0 and py >= 0 and px < w and py < h:
					img.set_pixel(px, py, col)
	for b in c.bridges:
		var a: Vector2 = b["from"]
		var d: Vector2 = b["to"]
		for t in 100:
			var q := a.lerp(d, t / 99.0)
			var px := int((q.x - x0) * k)
			var py := int((q.y - z0) * k)
			for o in 2:
				img.set_pixel(clampi(px + o, 0, w - 1), clampi(py, 0, h - 1), Color.RED)
	img.save_png(out)
	print("[Continent] saved ", out)
	quit(0)
