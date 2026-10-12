class_name CityBake
extends RefCounted
## The generated city saved to a file and read back, so the game does not generate it at
## every start (the seed is fixed: it is the same city every time). tools/bake.gd writes
## the file when the web build is made (docker/Dockerfile); main.gd reads it when it is
## there and generates the city otherwise. The file is not in the repository (.gitignore):
## a new build always bakes it again from the current code.

const PATH := "res://baked/city.bin"
## Bumped when the fields below change: an older file is then ignored.
const FORMAT := 2

## Per-cell layers and building arrays, copied as they are.
const FIELDS := [
	"terrain", "zone", "road", "elevation", "forest", "rocky", "deco", "edge", "fence_edge",
	"b_rect", "b_kind", "b_facing", "b_seed", "b_height", "b_scale", "b_sign_facing", "b_lay",
	"b_model", "b_sign", "centers", "center_weights", "city_name", "tree_share", "bridge",
	"west_bridge", "central_park", "vehicle_plan", "prop_plan",
]
const FOG_FIELDS := ["origin", "elevation", "colors", "buildings", "trees", "bridge_land_x"]


## Writes `data` (just generated) for `cfg`, with the plans of its vehicles and props (they
## take seconds to work out). Returns an Error.
static func save(data: CityData, cfg: CityConfig, path: String = PATH) -> Error:
	data.vehicle_plan = VehicleSites.plan(data, MapVehicles.lengths_m())
	data.prop_plan = ScenicProps.plan(data)
	var d := {"format": FORMAT, "key": _key(cfg), "size": data.size, "chunk_size": data.chunk_size}
	for f in FIELDS:
		d[f] = data.get(f)
	if data.fog != null:
		var fog := {}
		for f in FOG_FIELDS:
			fog[f] = data.fog.get(f)
		d["fog"] = fog
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(d)
	file.close()
	return OK


## The baked city for `cfg`, or null when there is no file or it was baked for another
## format, seed or map size.
static func load_city(cfg: CityConfig, path: String = PATH) -> CityData:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var d = file.get_var()
	file.close()
	if not d is Dictionary or d.get("format", 0) != FORMAT or d.get("key", "") != _key(cfg):
		push_warning("[Bake] %s was baked for another map: the city is generated" % path)
		return null
	# What the generator sets for the planners that still run (MapLayout).
	MapLayout.set_scale(cfg.map_scale)
	var data := CityData.new(int(d["size"]), int(d["chunk_size"]))
	for f in FIELDS:
		if f == "centers":
			data.centers.assign(d[f])   # a typed array: filled, not replaced
		else:
			data.set(f, d[f])
	if d.has("fog"):
		data.fog = FogIslandShaper.new(cfg, data)
		for f in FOG_FIELDS:
			data.fog.set(f, d["fog"][f])
	data.build_chunk_index()
	return data


## What the city depends on besides the code: a file baked for another map is not used.
static func _key(cfg: CityConfig) -> String:
	return "%d/%d/%.6f/%d/%.4f" % [cfg.seed, cfg.map_size, cfg.map_scale, cfg.core_size, cfg.tree_share]
