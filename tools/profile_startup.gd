extends SceneTree
## Where the start-up time goes, and what every model costs.
## Run (a renderer is needed to read mesh triangles):
##   godot --path . --rendering-driver opengl3 --script res://tools/profile_startup.gd
## Prints:
##   - the time of every generation step and of the whole generation;
##   - the time to load the model library, and the slowest model files;
##   - per model: triangles, how many times the map draws it, triangles drawn in total;
##     the heavy ones and the ones drawn only once or twice;
##   - the chunks that cost the most triangles and the time to build them;
##   - the chunks seen at the start zoom.

const START_ZOOM := 62.0


func _init() -> void:
	var cfg := CityConfig.create()
	var t0 := Time.get_ticks_msec()
	var last := [t0, "start"]
	var report := func(_v: float, text: String) -> void:
		var now := Time.get_ticks_msec()
		print("[Gen] %6d ms  %s" % [now - int(last[0]), last[1]])
		last[0] = now
		last[1] = text
	var data := CityGenerator.new(cfg, report).generate()
	print("[Gen] %6d ms  %s (and the rest of the pipeline)" % [Time.get_ticks_msec() - int(last[0]), last[1]])
	print("[Gen] TOTAL generation %d ms" % (Time.get_ticks_msec() - t0))

	# --- Model library -----------------------------------------------------------------
	var lib := ModelLibrary.new()
	var tl := Time.get_ticks_msec()
	lib.begin(cfg)
	var pending: Array = lib.get("_pending").duplicate()
	var file_ms := {}
	var i := 0
	while true:
		var ts := Time.get_ticks_usec()
		var p := lib.load_next(1)
		if i < pending.size():
			var path: String = pending[i]["path"]
			file_ms[path] = file_ms.get(path, 0.0) + (Time.get_ticks_usec() - ts) / 1000.0
		i += 1
		if p >= 1.0:
			break
	var tp := Time.get_ticks_msec()
	ServiceMeshes.build_all(lib)
	LandmarkMeshes.build_all(lib)
	EntertainmentMeshes.build_all(lib)
	NatureMeshes.build_all(lib)
	CivicMeshes.build_all(lib)
	PublicMeshes.build_all(lib)
	MilitaryMeshes.build_all(lib)
	FarmMeshes.build_all(lib)
	ParkMeshes.build_all(lib)
	print("[Models] %d entries from %d files loaded in %d ms (procedural meshes %d ms), %d meshes" % [
			pending.size(), file_ms.size(), tp - tl, Time.get_ticks_msec() - tp, lib.meshes.size()])
	var files := file_ms.keys()
	files.sort_custom(func(a, b) -> bool: return file_ms[a] > file_ms[b])
	for f in files.slice(0, 15):
		print("[Models]   %7.1f ms  %s" % [file_ms[f], f])

	# --- Usage of every mesh over the whole map (near LOD) ---------------------------------
	var tris := PackedInt32Array()
	tris.resize(lib.meshes.size())
	for m in lib.meshes.size():
		tris[m] = _triangles(lib.meshes[m])
	var uses := {}
	var chunk_tris := {}
	var chunk_ms := {}
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			var key := Vector2i(cx, cy)
			var ts := Time.get_ticks_usec()
			var batch := InstanceBatch.new()
			for id in data.chunk_buildings[cy * side + cx]:
				BuildingPlacer.place(data, lib, id, batch, false)
			GroundPlacer.place_cells(data, lib, data.chunk_rect(cx, cy), batch)
			chunk_ms[key] = (Time.get_ticks_usec() - ts) / 1000.0
			var total := 0
			for mid in batch.transforms:
				var n: int = batch.transforms[mid].size() / 12
				uses[mid] = uses.get(mid, 0) + n
				total += n * tris[mid]
			chunk_tris[key] = total
	var rows := []
	var grand := 0
	for mid in uses:
		rows.append([mid, uses[mid], tris[mid], uses[mid] * tris[mid]])
		grand += uses[mid] * tris[mid]
	print("[Draw] whole map, near LOD: %d triangles, %d meshes used of %d loaded" % [grand, uses.size(), lib.meshes.size()])
	rows.sort_custom(func(a, b) -> bool: return a[3] > b[3])
	print("[Draw] most triangles drawn (model: tris x uses = total):")
	for r in rows.slice(0, 25):
		print("[Draw]   %-55s %6d x %4d = %8d" % [lib.model_name(r[0]).left(55), r[2], r[1], r[3]])
	rows.sort_custom(func(a, b) -> bool: return a[2] > b[2])
	print("[Draw] heaviest models used 1 or 2 times:")
	var shown := 0
	for r in rows:
		if r[1] <= 2 and shown < 25:
			print("[Draw]   %-55s %6d tris, %d use(s)" % [lib.model_name(r[0]).left(55), r[2], r[1]])
			shown += 1
	var unused := 0
	var unused_tris := 0
	for m in lib.meshes.size():
		if not uses.has(m):
			unused += 1
			unused_tris += tris[m]
	print("[Draw] meshes loaded but never drawn in the chunks: %d (%d triangles; some are drawn by other nodes)" % [unused, unused_tris])

	# --- Chunks -----------------------------------------------------------------------------
	var keys := chunk_tris.keys()
	keys.sort_custom(func(a, b) -> bool: return chunk_tris[a] > chunk_tris[b])
	print("[Chunks] heaviest chunks (32x32 cells): triangles, build ms")
	for k in keys.slice(0, 12):
		print("[Chunks]   %s  %8d tris  %6.1f ms" % [k, chunk_tris[k], chunk_ms[k]])
	var all_ms := 0.0
	for k in chunk_ms:
		all_ms += chunk_ms[k]
	print("[Chunks] building every chunk (near) once: %d ms" % int(all_ms))
	# Chunks seen at the start: the view of an orthographic camera of size START_ZOOM, 16:9,
	# pitch 30 deg, yaw 45 deg, centred on the map.
	for zoom in [START_ZOOM, 40.0, 30.0]:
		var seen := _start_view(data, cfg, zoom)
		var st := 0
		var sm := 0.0
		for k in seen:
			st += chunk_tris.get(k, 0)
			sm += chunk_ms.get(k, 0.0)
		print("[Start] zoom %.0f: %d chunks in view, %d triangles, %d ms to build them" % [zoom, seen.size(), st, int(sm)])
	quit()


func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			n += idx.size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Chunks under the start view (ground polygon of the camera, as IsoCamera.view_polygon).
func _start_view(data: CityData, cfg: CityConfig, zoom: float) -> Array:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.rotation_degrees = Vector3(cfg.camera_pitch_deg, cfg.camera_yaw_deg, 0.0)
	var c := Vector3(data.size * 0.5, 0, data.size * 0.5)
	var back := Basis.from_euler(cam.rotation).z
	# Ground footprint of a 16:9 view: half height `zoom / 2` on screen, stretched on the ground.
	var pitch := deg_to_rad(-cfg.camera_pitch_deg)
	var half_h := zoom * 0.5 / sin(pitch)
	var half_w := zoom * 0.5 * 16.0 / 9.0
	var yaw := deg_to_rad(cfg.camera_yaw_deg)
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var poly := PackedVector2Array()
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		poly.append(Vector2(c.x, c.z) + right * s.x * half_w + fwd * s.y * half_h)
	cam.free()
	var out := []
	var cs := float(cfg.chunk_size)
	var side := data.chunks_per_side()
	for cy in side:
		for cx in side:
			var r := PackedVector2Array([Vector2(cx, cy) * cs, Vector2(cx + 1, cy) * cs,
					Vector2(cx + 1, cy + 1) * cs, Vector2(cx, cy + 1) * cs])
			if not Geometry2D.intersect_polygons(poly, r).is_empty() and not data.chunk_is_empty(cx, cy):
				out.append(Vector2i(cx, cy))
	return out
