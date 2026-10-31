extends SceneTree
## Where the feet of the port gantry cranes stand (cells), and the road cells round them:
##   godot --headless --script res://tests/dump_crane_feet.gd


func _init() -> void:
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(40) < 1.0:
		pass
	# Optional candidate lots "x,y,w,h" for the cranes in order of their rows (after `--`).
	var cands := OS.get_cmdline_user_args()
	var ci := 0
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY or data.b_model.get(b, "") != "port_towers.glb: tower_crane":
			continue
		if ci < cands.size():
			var v := cands[ci].split(",")
			data.set_building_rect(b, Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3])))
		ci += 1
		var pick := BuildingPlacer.pick_for(data, lib, b)
		var id: int = pick["id"]
		var xf: Transform3D = pick["xform"]
		var aabb := lib.bounds[id]
		print("[Crane] B-%05d lot %s facing %d aabb size %s pos %s scale %s" % [b, data.building_rect(b), data.b_facing[b], aabb.size, aabb.position, xf.basis.get_scale()])
		var mesh: Mesh = lib.meshes[id]
		var pts := []
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				if v.y < aabb.position.y + aabb.size.y * 0.1:
					pts.append(xf * v)
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for p: Vector3 in pts:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		print("[Crane]   feet (y<10%%) x %.2f..%.2f  z %.2f..%.2f  (%d vertices)" % [lo.x, hi.x, lo.y, hi.y, pts.size()])
		# Feet clusters: split by the middle of their box along the longer side.
		var mid := (lo + hi) * 0.5
		var groups := [[], [], [], []]
		for p: Vector3 in pts:
			groups[(1 if p.x > mid.x else 0) + (2 if p.z > mid.y else 0)].append(p)
		for g in groups:
			if g.is_empty():
				continue
			var glo := Vector2(1e9, 1e9)
			var ghi := Vector2(-1e9, -1e9)
			for p: Vector3 in g:
				glo = Vector2(minf(glo.x, p.x), minf(glo.y, p.z))
				ghi = Vector2(maxf(ghi.x, p.x), maxf(ghi.y, p.z))
			print("[Crane]   foot x %.2f..%.2f  z %.2f..%.2f" % [glo.x, ghi.x, glo.y, ghi.y])
		var r := data.building_rect(b)
		for y in range(r.position.y - 3, r.end.y + 3):
			var line := ""
			for x in range(r.position.x - 4, r.end.x + 4):
				line += "#" if data.is_road(x, y) else "."
			print("[Crane]   %3d %s" % [y, line])
	quit(0)
