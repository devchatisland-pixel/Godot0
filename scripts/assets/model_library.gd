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

var _pending: Array[Dictionary] = []
var _total := 0


func begin(cfg: CityConfig) -> void:
	var catalog := ModelCatalog.new()
	catalog.scan(cfg.models_root)
	_pending = _limit_variants(catalog.entries, cfg.max_variants)
	_total = maxi(1, _pending.size())
	print("[Models] %d model files selected in %s" % [_pending.size(), cfg.models_root])


## Loads up to `count` models. Returns progress 0..1 (1 = done).
func load_next(count: int) -> float:
	for i in count:
		if _pending.is_empty():
			break
		var e: Dictionary = _pending.pop_front()
		var mesh := _load_mesh(e["path"])
		if mesh == null:
			push_warning("[Models] could not load " + e["path"])
			continue
		var id := add_mesh(mesh, e["mask"])
		var cat: int = e["cat"]
		if not by_cat.has(cat):
			by_cat[cat] = PackedInt32Array()
		by_cat[cat].append(id)
	return 1.0 - float(_pending.size()) / float(_total)


func add_mesh(mesh: Mesh, mask: int = 0) -> int:
	meshes.append(mesh)
	bounds.append(mesh.get_aabb())
	road_masks.append(mask)
	return meshes.size() - 1


func add_named(name: String, mesh: Mesh) -> int:
	var id := add_mesh(mesh)
	named[name] = id
	return id


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
	var root: Node = null
	if res is PackedScene:
		root = (res as PackedScene).instantiate()
	elif res is Mesh:
		return res
	else:
		root = _load_gltf_raw(path)
	if root == null:
		return null
	var mesh := _merge_meshes(root)
	root.free()
	return mesh


## Fallback for model files that were not imported by the editor.
func _load_gltf_raw(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


## Collapses all MeshInstance3D nodes of a model into one mesh (one surface per
## original surface, vertices baked into model space).
func _merge_meshes(root: Node) -> Mesh:
	var instances: Array[MeshInstance3D] = []
	_find_meshes(root, instances)
	if instances.is_empty():
		return null
	if instances.size() == 1 and _model_transform(instances[0], root) == Transform3D.IDENTITY:
		return instances[0].mesh
	var out := ArrayMesh.new()
	for mi in instances:
		var xform := _model_transform(mi, root)
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
