extends SceneTree
## Prints every building (id, kind, cell, size, facing, zone, seed, model):
## godot --headless --script res://tests/dump_all.gd


func _init() -> void:
	var data := CityGenerator.new(CityConfig.create()).generate()
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if k == CityTypes.Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		print("[All] B-%05d %s cell %d,%d size %dx%d facing %d zone %s seed %d model %s" % [b,
				CityTypes.Kind.keys()[k], r.position.x, r.position.y, r.size.x, r.size.y, data.b_facing[b],
				CityTypes.Zone.keys()[data.zone_at(r.position.x, r.position.y)], data.b_seed[b],
				data.b_model.get(b, "")])
	quit(0)
