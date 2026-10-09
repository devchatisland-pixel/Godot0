class_name ChunkStreamer
extends Node3D
## Streams the city around the camera.
## Every chunk has two optional representations:
##   far  - one coloured box per building (1 draw call per chunk, few KB)
##   near - real models, roads, trees and lights (MultiMesh per model)
## Both are built on worker threads (pure data), turned into nodes on the main
## thread a few per frame, and evicted least-recently-used when over budget.

class ChunkState:
	var key: Vector2i
	var far_node: Node3D
	var near_node: Node3D
	var far_pending := false
	var near_pending := false
	var last_seen := 0

var _cfg: CityConfig
var _data: CityData
var _lib: ModelLibrary
var _box_material: StandardMaterial3D

var _chunks := {}          # Vector2i -> ChunkState
var _jobs := {}            # task id -> [key, far]
var _results: Array = []   # [key, far, InstanceBatch] filled by workers
var _mutex := Mutex.new()
var _frame := 0
var _empty := {}           # Vector2i -> true for chunks of open sea
var _visible_keys: Array[Vector2i] = []
var near_mode := false


func setup(cfg: CityConfig, data: CityData, lib: ModelLibrary) -> void:
	_cfg = cfg
	_data = data
	_lib = lib
	_box_material = StandardMaterial3D.new()
	_box_material.vertex_color_use_as_albedo = true
	_box_material.roughness = 0.9
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			if data.chunk_is_empty(cx, cy):
				_empty[Vector2i(cx, cy)] = true


## Called every frame with the ground polygon seen by the camera (cells).
func update_view(view_poly: PackedVector2Array, zoom: float) -> void:
	_frame += 1
	var was_near := near_mode
	# Hysteresis avoids flickering when zooming around the threshold.
	near_mode = zoom < _cfg.near_lod_size * (1.1 if was_near else 1.0)
	_visible_keys = _keys_in_view(view_poly)
	var center := _poly_center(view_poly) / float(_cfg.chunk_size)
	_visible_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))

	var visible := {}
	for key in _visible_keys:
		visible[key] = true
		var st := _state(key)
		st.last_seen = _frame
		if near_mode and st.near_node == null:
			_request(st, false)
		if st.far_node == null and not (near_mode and st.near_node != null):
			_request(st, true)
	_collect_finished()
	_apply_results()
	_update_visibility(visible)
	_evict()


# --- View -----------------------------------------------------------------------------
func _keys_in_view(poly: PackedVector2Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if poly.size() < 3:
		return out
	var cs := float(_cfg.chunk_size)
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	var side := _data.chunks_per_side()
	var x0 := clampi(floori(mn.x / cs), 0, side - 1)
	var x1 := clampi(floori(mx.x / cs), 0, side - 1)
	var y0 := clampi(floori(mn.y / cs), 0, side - 1)
	var y1 := clampi(floori(mx.y / cs), 0, side - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var key := Vector2i(cx, cy)
			if _empty.has(key):
				continue
			var r := PackedVector2Array([Vector2(cx, cy) * cs, Vector2(cx + 1, cy) * cs,
					Vector2(cx + 1, cy + 1) * cs, Vector2(cx, cy + 1) * cs])
			if not Geometry2D.intersect_polygons(poly, r).is_empty():
				out.append(key)
	return out


func _poly_center(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(1.0, poly.size())


func _state(key: Vector2i) -> ChunkState:
	if not _chunks.has(key):
		var st := ChunkState.new()
		st.key = key
		_chunks[key] = st
	return _chunks[key]


# --- Jobs -------------------------------------------------------------------------------------
func _request(st: ChunkState, far: bool) -> void:
	if (far and st.far_pending) or (not far and st.near_pending):
		return
	if _jobs.size() >= _cfg.max_jobs:
		return
	if far:
		st.far_pending = true
	else:
		st.near_pending = true
	var task := WorkerThreadPool.add_task(_run_job.bind(st.key, far), false, "city chunk")
	_jobs[task] = [st.key, far]


## Worker thread: builds the instance lists of one chunk (no nodes, no RIDs).
func _run_job(key: Vector2i, far: bool) -> void:
	var batch := InstanceBatch.new()
	var side := _data.chunks_per_side()
	var ids := _data.chunk_buildings[key.y * side + key.x]
	for id in ids:
		BuildingPlacer.place(_data, _lib, id, batch, far)
	if not far:
		GroundPlacer.place_cells(_data, _lib, _data.chunk_rect(key.x, key.y), batch)
	_mutex.lock()
	_results.append([key, far, batch])
	_mutex.unlock()


func _collect_finished() -> void:
	for task in _jobs.keys():
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_jobs.erase(task)


func _apply_results() -> void:
	_mutex.lock()
	var count := mini(_cfg.applies_per_frame, _results.size())
	var ready := _results.slice(0, count)
	_results = _results.slice(count)
	_mutex.unlock()
	for r in ready:
		var key: Vector2i = r[0]
		var far: bool = r[1]
		var batch: InstanceBatch = r[2]
		var st := _state(key)
		var node := Node3D.new()
		node.name = "%s_%d_%d" % ["far" if far else "near", key.x, key.y]
		batch.build_nodes(node, _lib, _box_material)
		add_child(node)
		if far:
			st.far_pending = false
			st.far_node = node
		else:
			st.near_pending = false
			st.near_node = node


# --- Visibility and memory ---------------------------------------------------------------------
func _update_visibility(visible: Dictionary) -> void:
	for key in _chunks:
		var st: ChunkState = _chunks[key]
		var seen := visible.has(key)
		var show_near := seen and near_mode and st.near_node != null
		if st.near_node != null:
			st.near_node.visible = show_near
		if st.far_node != null:
			st.far_node.visible = seen and not show_near


func _evict() -> void:
	var near_list: Array[ChunkState] = []
	var far_list: Array[ChunkState] = []
	for key in _chunks:
		var st: ChunkState = _chunks[key]
		if st.near_node != null:
			near_list.append(st)
		if st.far_node != null:
			far_list.append(st)
	_evict_list(near_list, _cfg.max_near_chunks, false)
	_evict_list(far_list, _cfg.max_far_chunks, true)


func _evict_list(list: Array[ChunkState], limit: int, far: bool) -> void:
	if list.size() <= limit:
		return
	list.sort_custom(func(a: ChunkState, b: ChunkState) -> bool: return a.last_seen < b.last_seen)
	for i in list.size() - limit:
		var st := list[i]
		if st.last_seen == _frame:
			break # never drop what is on screen
		if far:
			st.far_node.queue_free()
			st.far_node = null
		else:
			st.near_node.queue_free()
			st.near_node = null


func pending_jobs() -> int:
	return _jobs.size() + _results.size()


func loaded_counts() -> Vector2i:
	var n := 0
	var f := 0
	for key in _chunks:
		var st: ChunkState = _chunks[key]
		n += int(st.near_node != null)
		f += int(st.far_node != null)
	return Vector2i(n, f)


func _exit_tree() -> void:
	for task in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(task)
	_jobs.clear()
