extends SceneTree
## Measures how long near / far chunk jobs take and how many draw calls and
## instances they produce. Run: godot --headless --script res://tests/bench_chunks.gd

func _init() -> void:
	var cfg := CityConfig.create()
	var data := CityGenerator.new(cfg).generate()
	var lib := ModelLibrary.new()
	lib.begin(cfg)
	while lib.load_next(10) < 1.0:
		pass
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	var side := data.chunks_per_side()
	var c := data.centers[0] / cfg.chunk_size
	var reach := mini(2, side / 2 - 1)
	for far in [false, true]:
		var t0 := Time.get_ticks_usec()
		var draws := 0
		var inst := 0
		var n := 0
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var key := Vector2i(int(c.x) + dx, int(c.y) + dy)
				var batch := InstanceBatch.new()
				for id in data.chunk_buildings[key.y * side + key.x]:
					BuildingPlacer.place(data, lib, id, batch, far)
				if not far:
					GroundPlacer.place_cells(data, lib, data.chunk_rect(key.x, key.y), batch)
				draws += batch.transforms.size() + int(not batch.boxes.is_empty())
				for k in batch.transforms:
					inst += batch.transforms[k].size() / 12
				inst += batch.boxes.size() / 16
				n += 1
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("%s: %.1f ms/chunk, %.0f draw calls/chunk, %.0f instances/chunk" % [
				"far " if far else "near", ms / n, float(draws) / n, float(inst) / n])
	print("static memory MB: ", OS.get_static_memory_usage() / 1048576.0)
	quit()
