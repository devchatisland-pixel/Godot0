extends SceneTree
## Generates the city once and stores it in res://baked/city.bin (CitySnapshot), so exported
## builds start without generating. Reloads the file and checks it gives the same city.
## Run: godot --headless --path . --script res://tools/bake_city.gd

func _init() -> void:
	var cfg := CityConfig.create()
	var t0 := Time.get_ticks_msec()
	var data := CityGenerator.new(cfg).generate()
	var t1 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://baked"))
	var err := CitySnapshot.save(data, cfg)
	if err != OK:
		printerr("[Bake] FAILED: could not write %s (%s)" % [CitySnapshot.PATH, error_string(err)])
		quit(1)
		return
	var t2 := Time.get_ticks_msec()
	var back := CitySnapshot.load_city(cfg)
	var t3 := Time.get_ticks_msec()
	if back == null or var_to_bytes(CitySnapshot._dump(back, back)) != var_to_bytes(CitySnapshot._dump(data, data)):
		printerr("[Bake] FAILED: the stored city does not read back the same")
		quit(1)
		return
	var size := FileAccess.get_file_as_bytes(CitySnapshot.PATH).size()
	print("[Bake] OK: generated in %d ms, saved in %d ms, %.1f MB, loads in %d ms"
			% [t1 - t0, t2 - t1, size / 1e6, t3 - t2])
	quit(0)
