class_name ChunkBake
extends RefCounted
## What every chunk draws (the InstanceBatch of BuildingPlacer and GroundPlacer), near and far,
## baked with the city by tools/bake.gd: the streamer then only turns these lists into
## MultiMeshes, instead of placing every building, road, tree and light again on a worker
## thread (seconds in the browser for the first view). The meshes are named by their id in the
## baked model library, with the night lights added (NightWindows makes the sign halos); the
## name of each id is kept to check that the library read at start is the same.

const PATH := "res://baked/chunks.bin"
const FORMAT := 1


## Places every chunk of `data` with `lib` (the library as the game has it once started) and
## writes the lists. Returns an Error.
static func save(data: CityData, lib: ModelLibrary, path: String = PATH) -> Error:
	var side := data.chunks_per_side()
	var near := []
	var far := []
	var names := {}
	for i in side * side:
		var r := data.chunk_rect(i % side, i / side)
		for is_far in [false, true]:
			var batch := InstanceBatch.new()
			for id in data.chunk_buildings[i]:
				BuildingPlacer.place(data, lib, id, batch, is_far)
			if not is_far:
				GroundPlacer.place_cells(data, lib, r, batch)
			for id in batch.transforms:
				names[id] = lib.names[id]
			(far if is_far else near).append({"t": batch.transforms, "b": batch.boxes})
	var d := {"format": FORMAT, "meshes": lib.meshes.size(), "names": names, "near": near, "far": far}
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(d)
	file.close()
	return OK


## The baked lists, or {} when there is no file.
static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var d = file.get_var()
	file.close()
	return d if d is Dictionary and d.get("format", 0) == FORMAT else {}


## True when `d` was baked with the same library as `lib` (same meshes under the same ids).
static func matches(d: Dictionary, lib: ModelLibrary) -> bool:
	if d.is_empty() or int(d["meshes"]) != lib.meshes.size():
		return false
	var names: Dictionary = d["names"]
	for id in names:
		if int(id) >= lib.names.size() or lib.names[int(id)] != names[id]:
			return false
	return true


## The baked batch of chunk `index` (y * side + x).
static func batch(d: Dictionary, index: int, far: bool) -> InstanceBatch:
	var e: Dictionary = d["far" if far else "near"][index]
	var b := InstanceBatch.new()
	b.transforms = e["t"]
	b.boxes = e["b"]
	return b
