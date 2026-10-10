class_name ModelLibrary
extends RefCounted
## Owns every mesh used by the city. Each mesh gets an integer id; chunks only
## store ids + transforms, so a model is in memory once however often it is used.
## Models are loaded step by step on the main thread (keeps the loading screen alive);
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

var _pending: Array[Dictionary] = []
var _total := 0
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
	print("[Models] %d model files selected in %s" % [_pending.size(), cfg.models_root])


## Loads up to `count` models. Returns progress 0..1 (1 = done).
func load_next(count: int) -> float:
	for i in count:
		if _pending.is_empty():
			break
		var e: Dictionary = _pending.pop_front()
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


func _load_mesh(path: String) -> Mesh:
	var res: Resource = null
	if ResourceLoader.exists(path):
		res = ResourceLoader.load(path)
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
		var res: Resource = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
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
