extends SceneTree
## Lists the buildings that touch a column of the map: the stripe to empty.
##   godot --headless --path . --script res://tests/dump_column.gd -- <x> <y0> <y1>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var x := int(args[0]) if args.size() > 0 else 153
	var y0 := int(args[1]) if args.size() > 1 else 170
	var y1 := int(args[2]) if args.size() > 2 else 250
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var rows := []
	for b in data.building_count():
		var r := data.building_rect(b)
		if r.position.x <= x and x < r.end.x and r.end.y > y0 and r.position.y < y1:
			rows.append([r.position.y, "B-%05d kind %s cell %d,%d size %dx%d zone %s" % [b, CityTypes.Kind.keys()[data.b_kind[b]],
					r.position.x, r.position.y, r.size.x, r.size.y, CityTypes.Zone.keys()[data.zone_at(r.position.x, r.position.y)]]])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	print("[Column] %d buildings touch x=%d, y %d..%d" % [rows.size(), x, y0, y1])
	for r in rows:
		print("[Column] ", r[1])
	quit(0)
