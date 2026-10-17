extends SceneTree
## What MapRequests left standing after FaceRoads (headless):
##   & .\tools\run_test.ps1 res://tests/dump_requests.gd


func _init() -> void:
	var cfg := CityConfig.new()
	var data := CityGenerator.new(cfg).generate()
	var first := data.building_count()
	var counts := {}
	for b in data.building_count():
		var m := String(data.b_model.get(b, ""))
		var key := ""
		if b >= MapRequests.added_from:
			key = "new " + CityTypes.Kind.keys()[data.b_kind[b]] if data.b_kind[b] != CityTypes.Kind.EMPTY else "new"
		elif MapRequests.ORANGE_B_TO.has(m) and data.b_kind[b] != CityTypes.Kind.HOUSE:
			key = "orange shop"
		elif m == "business.glb: shop" and b == 591:
			key = "B-00591"
		else:
			continue
		var k := key + (" gone" if data.b_kind[b] == CityTypes.Kind.EMPTY else " kept")
		counts[k] = counts.get(k, 0) + 1
	print("REQ ", counts, " buildings ", first)
	quit()
