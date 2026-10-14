extends SceneTree
## Prints, for the zones that get candy shops, the building kinds and lot sizes:
## godot --headless --path . --script res://tests/dump_zone_kinds.gd

func _init() -> void:
	var data := CityGenerator.new(CityConfig.create()).generate()
	var Z := CityTypes.Zone
	var K := CityTypes.Kind
	for zone in [Z.QUARTER, Z.COMMERCIAL, Z.SUBURBAN, Z.APARTMENT]:
		var kinds := {}
		var small := {}
		for b in data.building_count():
			var r := data.building_rect(b)
			if data.zone_at(r.position.x, r.position.y) != zone:
				continue
			var name: String = K.keys()[data.b_kind[b]]
			kinds[name] = kinds.get(name, 0) + 1
			var lo := mini(r.size.x, r.size.y)
			var hi := maxi(r.size.x, r.size.y)
			if lo >= 2 and hi >= 3 and lo <= 4:
				small[name] = small.get(name, 0) + 1
		print("[Zone] ", Z.keys()[zone], " all: ", kinds)
		print("[Zone] ", Z.keys()[zone], " fit: ", small)
	quit(0)
