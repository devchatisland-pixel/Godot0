class_name CityGenerator
extends RefCounted
## Runs every generation step in order. Designed to run on a worker thread:
## it only touches its own CityData and reports progress through a callable.

var _cfg: CityConfig
var _progress: Callable


func _init(cfg: CityConfig, progress: Callable = Callable()) -> void:
	_cfg = cfg
	_progress = progress


func generate() -> CityData:
	var t0 := Time.get_ticks_msec()
	# The city as it was (generated alone on its own grid), then the map around it.
	var core := _generate_core()
	var core_data: CityData = core["data"]
	var data := CityData.new(_cfg.map_size, _cfg.chunk_size)
	data.city_name = _cfg.city_name
	var offset := (_cfg.map_size - _cfg.core_size) / 2
	CoreEmbed.copy(core_data, data, offset)

	_report(0.9, "Growing the island")
	var island := ExtensionIsland.new(_cfg, data)
	island.core = core_data
	island.core_height = core["height"]
	island.offset = offset
	island.shape()
	var rng := RandomNumberGenerator.new()
	rng.seed = _cfg.seed + 777
	var extension := ExtensionPlanner.new(_cfg, data, island, rng)
	extension.build()

	_report(0.97, "Hiding an island in the fog")
	data.fog = FogIslandShaper.new(_cfg, data)
	data.fog.shape(FogIslandShaper.SIZE / 2)

	var edits := ManualEdits.apply(data)
	print("[City] %d hand edits applied" % edits)
	data.build_chunk_index()
	_report(1.0, "City ready")
	var services: Dictionary = core["services"].duplicate()
	for k in extension.counts:
		services[k] = services.get(k, 0) + extension.counts[k]
	_print_stats(data, core["blocks"] + extension.block_count, services, Time.get_ticks_msec() - t0)
	return data


## The original pipeline on a core_size grid; same seed, same city as before.
func _generate_core() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _cfg.seed
	var data := CityData.new(_cfg.core_size, _cfg.chunk_size)
	data.city_name = _cfg.city_name

	_report(0.05, "Raising the island")
	var island := IslandShaper.new(_cfg, data)
	island.shape()

	_report(0.3, "Choosing districts")
	var districts := DistrictPlanner.new(_cfg, data, island)
	districts.plan()

	_report(0.4, "Laying out roads")
	var roads := RoadPlanner.new(_cfg, data, island, districts, rng)
	roads.build()

	_report(0.6, "Zoning blocks")
	var zones := districts.assign_zones(roads.blocks)
	districts.paint_zones(roads.blocks, zones)

	_report(0.7, "Dividing lots")
	var lots := LotPlanner.new(_cfg, data, districts, rng)
	lots.build(roads.blocks, zones)

	_report(0.8, "Placing public services")
	var services := ServicePlanner.new(_cfg, data, districts, lots)
	services.build(roads.blocks, zones)
	LandmarkPlanner.new(data, districts, island, services, lots).build()
	services.finish()
	return {"data": data, "height": island.height, "services": services.counts,
			"blocks": roads.blocks.size()}


func _report(value: float, text: String) -> void:
	if _progress.is_valid():
		_progress.call_deferred(value, text)


func _print_stats(data: CityData, block_count: int, services: Dictionary, ms: int) -> void:
	var names := {}
	for k in CityTypes.Kind.keys():
		names[CityTypes.Kind[k]] = k
	var per_kind := {}
	for i in data.building_count():
		var k: String = names[int(data.b_kind[i])]
		per_kind[k] = per_kind.get(k, 0) + 1
	print("[City] %s generated in %d ms: %d blocks, %d lots" % [
			data.city_name, ms, block_count, data.building_count()])
	print("[City] lots per kind: ", per_kind)
	var svc := {}
	for k in services:
		svc[names[k]] = services[k]
	print("[City] services: ", svc)
