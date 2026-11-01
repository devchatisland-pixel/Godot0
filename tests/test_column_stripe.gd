extends SceneTree
## The 1-wide lots of column 153, rows 171 to 240 (B-00111 to B-00131), are all empty.
##   godot --headless --path . --script res://tests/test_column_stripe.gd

func _init() -> void:
	var cfg := CityConfig.create()
	cfg.use_threads = false
	var data := CityGenerator.new(cfg).generate()
	var left := 0
	var seen := 0
	for b in data.building_count():
		var r := data.building_rect(b)
		if r.position.x == 153 and r.size.x == 1 and r.position.y >= 171 and r.position.y < 241:
			seen += 1
			if data.b_kind[b] != CityTypes.Kind.EMPTY:
				left += 1
				print("FAIL B-%05d still %s at %d,%d" % [b, CityTypes.Kind.keys()[data.b_kind[b]], r.position.x, r.position.y])
	print("ok   %d lots in the stripe, %d not empty" % [seen, left])
	print("TEST %s" % ("PASSED" if left == 0 and seen > 0 else "FAILED"))
	quit(0 if left == 0 and seen > 0 else 1)
