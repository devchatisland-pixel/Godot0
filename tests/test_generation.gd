extends SceneTree
## Headless check of the city generation.
## Run: godot --headless --script res://tests/test_generation.gd

func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	assert(data.building_count() > 0)
	quit()
