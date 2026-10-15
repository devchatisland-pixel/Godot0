extends SceneTree
## Prints the candy shops put in the city, per zone: godot --headless --script res://tests/dump_shops.gd

func _init() -> void:
	var data := CityGenerator.new(CityConfig.create()).generate()
	var per := {}
	for b in data.building_count():
		if data.b_model.get(b, "") == "shop:shop-general-orange-b-unlit":
			var r := data.building_rect(b)
			var z: String = CityTypes.Zone.keys()[data.zone_at(r.position.x, r.position.y)]
			per[z] = per.get(z, 0) + 1
	print("[Shops] ", per)
	quit(0)
