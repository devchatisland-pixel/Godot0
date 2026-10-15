extends SceneTree
## Measures how long the model library takes to load (threaded file reads).
## Run: godot --headless --script res://tests/bench_models.gd

func _init() -> void:
	var cfg := CityConfig.create()
	var t0 := Time.get_ticks_msec()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(3) < 1.0:
		OS.delay_msec(1)
	print("[bench_models] %d meshes in %d ms" % [lib.meshes.size(), Time.get_ticks_msec() - t0])
	quit()
