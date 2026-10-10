extends SceneTree
## Turns the raw packs of FREEMODELS/_incoming into small curated packs:
## only the useful buildings, each one a top-level node standing on y = 0,
## centred, at Kenney scale (1 unit = 1 road tile), front towards +Z, with
## textures downscaled and only an albedo map. Writes for every pack:
##   FREEMODELS/curated/<out>.glb          the buildings
##   FREEMODELS/curated/<out>.models.json  node name -> category
## Run (needs a renderer to read textures):
##   godot --rendering-driver opengl3 --script res://tools/curate_models.gd [-- <out> ...]
## With pack names ("out") after "--", only those packs are rebuilt.

## Every tools/curate_spec*.json is read; their "packs" lists are joined.
const SPEC_DIR := "res://tools"
const OUT_DIR := "res://FREEMODELS/curated"

var _tex_max := 512
var _default_tex_max := 512
## Optional colour forced on every material of a pack (untextured white models).
var _albedo := Color(0, 0, 0, 0)
## Keep the emission map (night lights painted in the texture).
var _keep_emission := false
var _tex_cache := {}
## Items given as a world rectangle: id -> Node3D holding the cut meshes.
var _regions := {}
var _mat_cache := {}


func _init() -> void:
	await process_frame
	var packs := _read_specs()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var only := OS.get_cmdline_user_args()
	for pack in packs:
		if only.is_empty() or only.has(pack["out"]):
			await _curate(pack)
	quit()


## The packs of all spec files (the first file gives the default texture size).
func _read_specs() -> Array:
	var packs := []
	var files := []
	for f in DirAccess.get_files_at(SPEC_DIR):
		if f.begins_with("curate_spec") and f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f in files:
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC_DIR.path_join(f)))
		if f == "curate_spec.json":
			_default_tex_max = int(spec.get("texture_max", 512))
		packs.append_array(spec["packs"])
	return packs


func _curate(pack: Dictionary) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(pack["src"], state) != OK:
		push_error("cannot read " + pack["src"])
		return
	var src: Node = doc.generate_scene(state)
	get_root().add_child(src)
	await process_frame
	_tex_cache.clear()
	_mat_cache.clear()
	_tex_max = int(pack.get("texture_max", _default_tex_max))
	pack["_scale"] = _pack_scale(src, pack)
	_albedo = Color(pack["albedo"]) if pack.has("albedo") else Color(0, 0, 0, 0)
	_keep_emission = pack.get("keep_emission", false)
	var items: Array = pack["items"] if pack.has("items") else _auto_items(src, pack)
	var out := Node3D.new()
	out.name = pack["out"]
	get_root().add_child(out)
	_regions = _split_regions(src, items)
	var manifest := []
	for item in items:
		var node := _build_item(src, out, item, pack)
		if node != null:
			manifest.append({"node": String(node.name), "cat": item["cat"]})
	src.queue_free()
	var path: String = OUT_DIR.path_join(pack["out"] + ".glb")
	var exporter := GLTFDocument.new()
	var out_state := GLTFState.new()
	exporter.append_from_scene(out, out_state)
	exporter.write_to_filesystem(out_state, ProjectSettings.globalize_path(path))
	var json := FileAccess.open(OUT_DIR.path_join(pack["out"] + ".models.json"), FileAccess.WRITE)
	json.store_string(JSON.stringify({"file": pack["out"] + ".glb", "models": manifest}, "\t"))
	out.queue_free()
	print("[Curate] %s: %d buildings" % [path, manifest.size()])
	await process_frame


# --- Items --------------------------------------------------------------------------
## Moves the item's nodes under a new top-level node, normalised in size and place.
func _build_item(src: Node, out: Node3D, item: Dictionary, pack: Dictionary) -> Node3D:
	var parts: Array[Node3D] = []
	if item.has("region"):
		if _regions.has(item["id"]):
			parts.append(_regions[item["id"]])
	for n in item.get("nodes", []):
		var found := src.find_child(String(n).validate_node_name(), true, false) as Node3D
		if found == null:
			push_warning("missing node %s in %s" % [n, pack["src"]])
			continue
		parts.append(found)
	if parts.is_empty():
		return null
	var holder := Node3D.new()
	holder.name = item["id"]
	out.add_child(holder)
	for p in parts:
		var xf := p.global_transform if p.is_inside_tree() else p.transform
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		holder.add_child(p)
		p.transform = xf
	var box := _aabb(holder)
	var s := float(pack["_scale"]) * float(item.get("scale_mul", 1.0))
	if pack.has("footprint"):
		s = float(pack["footprint"]) / maxf(box.size.x, box.size.z)
	if item.has("footprint"):
		s = float(item["footprint"]) / maxf(box.size.x, box.size.z)
	if item.has("height"):
		s = float(item["height"]) / box.size.y
	if pack.has("max_height") and box.size.y * s > float(pack["max_height"]):
		s = float(pack["max_height"]) / box.size.y
	var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	# "yaw" turns the building so that its front looks towards +Z.
	var rot := Basis(Vector3.UP, deg_to_rad(float(item.get("yaw", 0.0))))
	holder.transform = Transform3D(rot * Basis.from_scale(Vector3(s, s, s)), rot * (-base * s))
	for mi in _meshes(holder):
		_slim_materials(mi)
	return holder


## Packs that store one object per material for the whole town: cuts the
## triangles into the items that carry a "region" ([x0, z0, x1, z1] in world
## space, optional "ymax"), by the centre of each triangle. One pass over
## the triangles whatever the number of buildings.
func _split_regions(src: Node, items: Array) -> Dictionary:
	var wanted: Array = items.filter(func(i): return i.has("region"))
	var out := {}
	if wanted.is_empty():
		return out
	# id -> {material -> surface arrays being filled}
	var buckets := {}
	for it in wanted:
		buckets[it["id"]] = {}
	for mi in _meshes(src):
		var xf := mi.global_transform
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var cols = arr[Mesh.ARRAY_COLOR]
			var idx = arr[Mesh.ARRAY_INDEX]
			var tri_count: int = (idx.size() if idx != null else verts.size()) / 3
			var mat := mi.get_active_material(s)
			var world := PackedVector3Array()
			world.resize(verts.size())
			for v in verts.size():
				world[v] = xf * verts[v]
			for t in tri_count:
				var a: int = idx[t * 3] if idx != null else t * 3
				var b: int = idx[t * 3 + 1] if idx != null else t * 3 + 1
				var c: int = idx[t * 3 + 2] if idx != null else t * 3 + 2
				var ctr := (world[a] + world[b] + world[c]) / 3.0
				for it in wanted:
					var r: Array = it["region"]
					if ctr.x < r[0] or ctr.x > r[2] or ctr.z < r[1] or ctr.z > r[3]:
						continue
					if it.has("ymax") and ctr.y > float(it["ymax"]):
						continue
					var per: Dictionary = buckets[it["id"]]
					if not per.has(mat):
						per[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(),
								"u": PackedVector2Array(), "c": PackedColorArray()}
					var d: Dictionary = per[mat]
					for k in [a, b, c]:
						d["v"].append(world[k])
						d["n"].append((nb * norms[k]).normalized() if norms != null else Vector3.UP)
						d["u"].append(uvs[k] if uvs != null else Vector2.ZERO)
						if cols != null:
							d["c"].append(cols[k])
					break
	for it in wanted:
		var holder := Node3D.new()
		holder.name = String(it["id"]) + "_cut"
		for mat in buckets[it["id"]]:
			var d: Dictionary = buckets[it["id"]][mat]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = d["v"]
			arrays[Mesh.ARRAY_NORMAL] = d["n"]
			arrays[Mesh.ARRAY_TEX_UV] = d["u"]
			if (d["c"] as PackedColorArray).size() == (d["v"] as PackedVector3Array).size():
				arrays[Mesh.ARRAY_COLOR] = d["c"]
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, mat)
			var node := MeshInstance3D.new()
			node.mesh = mesh
			holder.add_child(node)
		out[it["id"]] = holder
		get_root().add_child(holder)
	return out


## Picks the complete buildings of a pack automatically (skips wall slabs,
## ground patches and props), or sorts a whole pack by height.
func _auto_items(src: Node, pack: Dictionary) -> Array:
	var auto: Dictionary = pack["auto"]
	var group := src
	while group.get_child_count() == 1:
		group = group.get_child(0)
	var scale := float(pack["_scale"])
	var items := []
	var k := 0
	for c in group.get_children():
		if not c is Node3D or items.size() >= int(auto.get("max", 20)):
			continue
		k += 1
		var box := _aabb(c)
		var w := maxf(box.size.x, box.size.z)
		var d := minf(box.size.x, box.size.z)
		if w <= 0.0:
			continue
		if auto.has("min_ratio") and box.size.y / w < float(auto["min_ratio"]):
			continue
		if auto.has("min_depth_ratio") and d / w < float(auto["min_depth_ratio"]):
			continue
		if auto.has("min_tris") and _tris(c) < int(auto["min_tris"]):
			continue
		var h := box.size.y * (float(pack["footprint"]) / w if pack.has("footprint") else scale)
		if pack.has("max_footprint") and w * scale > float(pack["max_footprint"]):
			continue
		if pack.has("max_height") and not pack.has("footprint") and h > float(pack["max_height"]):
			continue
		var cat: String = auto.get("cat", "")
		if auto.has("cat_by_height"):
			for pair in auto["cat_by_height"]:
				if h <= float(pair[0]):
					cat = pair[1]
					break
		c.name = "%s_%02d" % [pack["out"], k]
		if String(c.name) in pack.get("exclude", []):
			continue
		items.append({"id": String(c.name) + "_b", "nodes": [String(c.name)], "cat": cat})
	return items


## Common scale of a pack: fixed ("scale") or so that a reference building gets
## a given footprint ("scale_ref"); measured in world space, so a scale on the
## pack's root node is taken into account.
func _pack_scale(src: Node, pack: Dictionary) -> float:
	if pack.has("scale_ref"):
		var ref: Dictionary = pack["scale_ref"]
		var node := src.find_child(String(ref["node"]).validate_node_name(), true, false)
		if node != null:
			var box := _aabb(node)
			return float(ref["footprint"]) / maxf(box.size.x, box.size.z)
		push_warning("missing reference node " + ref["node"])
	return float(pack.get("scale", 1.0))


# --- Materials: albedo only, small textures -------------------------------------------
func _slim_materials(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var mat := mi.get_active_material(s)
		if mat is BaseMaterial3D:
			mesh.surface_set_material(s, _slim(mat))
			mi.set_surface_override_material(s, null)


func _slim(mat: BaseMaterial3D) -> StandardMaterial3D:
	if _mat_cache.has(mat):
		return _mat_cache[mat]
	var m := StandardMaterial3D.new()
	m.albedo_color = _albedo if _albedo.a > 0.0 else mat.albedo_color
	m.albedo_texture = _small(mat.albedo_texture)
	m.vertex_color_use_as_albedo = mat.vertex_color_use_as_albedo
	if _keep_emission and mat.emission_enabled:
		m.emission_enabled = true
		m.emission = mat.emission
		m.emission_texture = _small(mat.emission_texture)
	m.transparency = mat.transparency
	m.cull_mode = mat.cull_mode
	m.roughness = 0.9
	m.metallic = 0.0
	_mat_cache[mat] = m
	return m


func _small(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _tex_cache.has(tex):
		return _tex_cache[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	var m := maxi(img.get_width(), img.get_height())
	if m > _tex_max:
		var k := float(_tex_max) / m
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var small := ImageTexture.create_from_image(img)
	_tex_cache[tex] = small
	return small


# --- Helpers ---------------------------------------------------------------------------
func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(n):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _tris(n: Node) -> int:
	var t := 0
	for mi in _meshes(n):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			t += idx.size() / 3 if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
