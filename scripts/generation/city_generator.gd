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
	var rng := RandomNumberGenerator.new()
	rng.seed = _cfg.seed
	var data := CityData.new(_cfg.map_size, _cfg.chunk_size)
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

	_report(0.85, "Placing public services")
	var services := ServicePlanner.new(_cfg, data, districts, lots)
	services.build(roads.blocks, zones)
	LandmarkPlanner.new(data, districts, island, services, lots).build()
	services.finish()

	_report(0.95, "Hiding an island in the fog")
	data.fog = FogIslandShaper.new(_cfg, data)
	data.fog.shape(data.bridge.y)

	data.build_chunk_index()
	_report(1.0, "City ready")
	_print_stats(data, roads.blocks.size(), services.counts, Time.get_ticks_msec() - t0)
	return data


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
