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
## (02, 09 and 10 are retired: ModelRetirement.)
const YARD_CONTAINERS := ["container-01", "container-04"]

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
## Slots of by_cat that show another model (ModelRetirement.REPLACED), filled in when the
## packs are done: {"cat", "at" (index in by_cat[cat]), "target" (label)}.
var _aliases: Array[Dictionary] = []
## Label of a retired model -> the label it is drawn as (for models asked for by name).
var _alias_of := {}


func begin(cfg: CityConfig) -> void:
	var catalog := ModelCatalog.new()
	catalog.scan(cfg.models_root)
	_pending = _retire(_limit_variants(catalog.entries, cfg.max_variants), catalog.entries)
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
		if e.has("alias"):
			# A retired model: its slot will show the model `alias`; nothing is read for it.
			var acat: int = e["cat"]
			if not by_cat.has(acat):
				by_cat[acat] = PackedInt32Array()
			_aliases.append({"cat": acat, "at": by_cat[acat].size(), "target": e["alias"]})
			_alias_of[_label(e)] = e["alias"]
			by_cat[acat].append(-1)
			continue
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
		_resolve_aliases()
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


## Takes the deleted models off the list and marks the replaced ones (ModelRetirement); makes
## sure every model they are replaced by is in the list (the variant limit may have cut it).
func _retire(list: Array[Dictionary], all: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var have := {}
	for e in list:
		have[_label(e)] = true
	for e in list:
		var label := _label(e)
		if ModelRetirement.is_deleted(label):
			continue
		var target := ModelRetirement.replacement(label)
		if target != "":
			var a := e.duplicate()
			a["alias"] = target
			out.append(a)
			if not have.has(target):
				for c in all:
					if _label(c) == target:
						out.append(c)
						have[target] = true
						break
		else:
			out.append(e)
	return out


## Puts the real model ids into the slots of the replaced ones. A slot whose target is missing is dropped.
func _resolve_aliases() -> void:
	var gone := {}
	for a in _aliases:
		var id := names.find(a["target"])
		var arr: PackedInt32Array = by_cat[a["cat"]]
		if id >= 0:
			arr[a["at"]] = id
		else:
			gone[a["cat"]] = true
		by_cat[a["cat"]] = arr
	for c in gone:
		var kept := PackedInt32Array()
		for id in by_cat[c]:
			if id >= 0:
				kept.append(id)
		by_cat[c] = kept
	_aliases.clear()


## Id of the model labelled `label`, following ModelRetirement (-1 when it is not loaded).
func name_id(label: String) -> int:
	var id := names.find(label)
	if id < 0 and _alias_of.has(label):
		id = names.find(_alias_of[label])
	return id


## Keeps `lookahead` distinct upcoming files requested.
func _request_ahead() -> void:
	if lookahead == 0:
		return
	var seen := {}
	for e in _pending:
		if e.has("alias"):
			continue
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
