class_name ModelLibrary
extends RefCounted
## Owns every mesh used by the city. Each mesh gets an integer id; chunks only
## store ids + transforms, so a model is in memory once however often it is used.
## Model files are read and parsed by ResourceLoader's worker threads (all CPU cores),
## then turned into merged meshes step by step on the main thread (keeps the loading screen alive);
## after loading the library is read-only and safe to query from worker threads.

const Cat := ModelCatalog.Cat

var meshes: Array[Mesh] = []
## Bounding box of each mesh (position = min corner, size).
var bounds: Array[AABB] = []
## Native road connection mask (road tiles only).
var road_masks := PackedInt32Array()
## Category -> PackedInt32Array of mesh ids.
var by_cat := {}
## Procedural meshes by name ("hospital", "box"...).
var named := {}
## Parallel to `meshes`: a readable name per model (pack file + node, or procedural name),
## and its category (-1 for procedural models).
var names := PackedStringArray()
var cats := PackedInt32Array()

## The shipping containers of the yards (shops/models, from the "Low-poly Container" pack),
## loaded as named meshes "yardbox:NN" when the packs are done.
const YARD_CONTAINERS := ["container-01", "container-02", "container-04", "container-09", "container-10"]

var _pending: Array[Dictionary] = []
var _yard_loaded := false
var _total := 0
## How many model files are read ahead in the background (0 = none, read on the
## main thread; -1 = all at once). A small window leaves CPU to the city generator.
const DEFAULT_LOOKAHEAD := 4
var lookahead := DEFAULT_LOOKAHEAD
# Paths handed to ResourceLoader.load_threaded_request (path -> true).
var _requested := {}
var _fetched := {}
# Curated pack currently open (packs hold many buildings, opened once each).
var _pack_path := ""
var _pack_root: Node


func begin(cfg: CityConfig) -> void:
	var catalog := ModelCatalog.new()
	catalog.scan(cfg.models_root)
	_pending = _limit_variants(catalog.entries, cfg.max_variants)
	# Group buildings of the same pack so every pack file is opened only once.
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["path"] < b["path"])
	_total = maxi(1, _pending.size())
	# Start reading every model file in the background right away; load_next only
	# picks up files that are ready, so disk and parsing never stall a frame.
	_request_ahead()
	print("[Models] %d model files selected in %s" % [_pending.size(), cfg.models_root])


## Loads up to `count` models. Returns progress 0..1 (1 = done).
func load_next(count: int) -> float:
	for i in count:
		if _pending.is_empty():
			break
		if not _ready(_pending[0]["path"]):
			break
		var e: Dictionary = _pending.pop_front()
		_request_ahead()
		var mesh := _load_pack_mesh(e["path"], e["node"]) if e.has("node") else _load_mesh(e["path"])
		if mesh == null:
			push_warning("[Models] could not load %s %s" % [e["path"], e.get("node", "")])
			continue
		var id := add_mesh(mesh, e["mask"], _label(e))
		var cat: int = e["cat"]
		cats[id] = cat
		if not by_cat.has(cat):
			by_cat[cat] = PackedInt32Array()
		by_cat[cat].append(id)
	if _pending.is_empty():
		_close_pack()
		if not _yard_loaded:
			_yard_loaded = true
			for c: String in YARD_CONTAINERS:
				load_named("yardbox:" + c.trim_prefix("container-"), "res://shops/models/%s.glb" % c)
	return 1.0 - float(_pending.size()) / float(_total)


func add_mesh(mesh: Mesh, mask: int = 0, label: String = "") -> int:
	meshes.append(mesh)
	bounds.append(mesh.get_aabb())
	road_masks.append(mask)
	names.append(label)
	cats.append(-1)
	return meshes.size() - 1


func add_named(name: String, mesh: Mesh) -> int:
	var id := add_mesh(mesh, 0, name)
	named[name] = id
	return id


## "pack.glb: node" or the file name of a single model.
func _label(e: Dictionary) -> String:
	var file := String(e["path"]).get_file()
	return "%s: %s" % [file, e["node"]] if e.has("node") else file


func model_name(id: int) -> String:
	return names[id] if id >= 0 and id < names.size() else ""


func ids(cat: int) -> PackedInt32Array:
	return by_cat.get(cat, PackedInt32Array())


func has_cat(cat: int) -> bool:
	return by_cat.has(cat) and not by_cat[cat].is_empty()


func named_id(name: String) -> int:
	return named.get(name, -1)


## Loads one model file (imported or raw) as a mesh named `name`; returns its id or -1.
## Used for the single vehicles that are not part of a category.
func load_named(name: String, path: String, node_name: String = "") -> int:
	if named.has(name):
		return named[name]
	var mesh := _load_pack_mesh(path, node_name) if node_name != "" else _load_mesh(path)
	if mesh == null:
		push_warning("[Models] could not load " + path)
		return -1
	return add_named(name, mesh)


# --- Loading -------------------------------------------------------------------------
## Keeps at most `limit` models per category (evenly spread over the list).
func _limit_variants(entries: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var per_cat := {}
	for e in entries:
		var c: int = e["cat"]
		if not per_cat.has(c):
			per_cat[c] = []
		per_cat[c].append(e)
	var out: Array[Dictionary] = []
	for c in per_cat:
		var list: Array = per_cat[c]
		var step := maxf(1.0, float(list.size()) / float(limit))
		var f := 0.0
		while int(f) < list.size():
			out.append(list[int(f)])
			f += step
	return out


## Keeps `lookahead` distinct upcoming files requested.
func _request_ahead() -> void:
	if lookahead == 0:
		return
	var seen := {}
	for e in _pending:
		var path: String = e["path"]
		if seen.has(path):
			continue
		seen[path] = true
		if lookahead > 0 and seen.size() > lookahead:
			break
		_request(path)


func _request(path: String) -> void:
	if _requested.has(path) or _fetched.has(path) or not ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_requested[path] = true


## True when `path` can be fetched without waiting (or was never requested).
func _ready(path: String) -> bool:
	if not _requested.has(path):
		return true
	return ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS


func _fetch(path: String) -> Resource:
	if _requested.has(path):
		_requested.erase(path)
		_fetched[path] = true
		var r := ResourceLoader.load_threaded_get(path)
		if r != null:
			return r
	return ResourceLoader.load(path) if ResourceLoader.exists(path) else null


func _load_mesh(path: String) -> Mesh:
	var res: Resource = _fetch(path)
	if res is Mesh:
		return res
	var root := _open_scene(path, res)
	if root == null:
		return null
	var mesh := _merge_meshes(root, root)
	root.free()
	return mesh


## One building of a curated pack: the top-level node `node_name`.
func _load_pack_mesh(path: String, node_name: String) -> Mesh:
	if path != _pack_path:
		_close_pack()
		_pack_path = path
		var res: Resource = _fetch(path)
		_pack_root = _open_scene(path, res)
	if _pack_root == null:
		return null
	# A pack holding a single building is imported with that building as root.
	if _pack_root.name == node_name:
		return _merge_meshes(_pack_root, _pack_root)
	var node := _pack_root.find_child(node_name, false, false)
	if node == null:
		return null
	return _merge_meshes(node, _pack_root)


func _close_pack() -> void:
	if _pack_root != null:
		_pack_root.free()
	_pack_root = null
	_pack_path = ""


func _open_scene(path: String, res: Resource) -> Node:
	if res is PackedScene:
		return (res as PackedScene).instantiate()
	return _load_gltf_raw(path)


## Fallback for model files that were not imported by the editor.
func _load_gltf_raw(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


## Collapses all MeshInstance3D nodes under `node` into one mesh (one surface
## per original surface, vertices baked into the space of `space`).
func _merge_meshes(node: Node, space: Node) -> Mesh:
	var instances: Array[MeshInstance3D] = []
	_find_meshes(node, instances)
	if instances.is_empty():
		return null
	if instances.size() == 1 and _model_transform(instances[0], space) == Transform3D.IDENTITY:
		return instances[0].mesh
	var out := ArrayMesh.new()
	for mi in instances:
		var xform := _model_transform(mi, space)
		for s in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, s, xform)
			var mat := mi.get_active_material(s)
			st.set_material(mat)
			st.commit(out)
	return out


func _find_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		_find_meshes(c, out)


func _model_transform(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
