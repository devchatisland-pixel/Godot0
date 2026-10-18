extends SceneTree
## The towers of the urban island stand in strips; every second strip is empty and the strip
## of the tower at 67,195 stays full.
##   godot --headless --path . --script res://tests/test_urban_rows.gd

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _init() -> void:
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var starts := {}
	var kept := false
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.SKYLINE_BLDG:
			continue
		var r := data.building_rect(b)
		starts[r.position.x] = starts.get(r.position.x, 0) + 1
		if r.position == Vector2i(67, 195) and r.size.x == 4:
			kept = true
	var xs := starts.keys()
	xs.sort()
	print("strips with towers (west column: towers): ", starts)
	_check(kept, "the tower at 67,195 (4 wide) is still there")
	_check(xs.has(67), "the strip of column 67 is full")
	var gaps_ok := true
	for i in range(1, xs.size()):
		var gap: int = xs[i] - xs[i - 1]
		# Next full strip is two strips further (8 cells), plus 1 where a road lies between.
		if gap < 8:
			gaps_ok = false
	_check(gaps_ok, "no two full strips side by side")
	_check(xs.size() == 5, "five full strips of ten (%d)" % xs.size())
	print("TEST %s" % ("FAILED" if _fails > 0 else "PASSED"))
	quit(1 if _fails > 0 else 0)
