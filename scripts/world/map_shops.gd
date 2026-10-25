class_name MapShops
extends Node3D
## The shops of res://shops (see shops/CATALOG.md): one of each in a row on the development
## island (ShopSites), each with a name label, and in front of each its night copy (its SHOP
## sign lit, tools/make_night_variants.py shops). Static props like the vehicles: one
## MeshInstance3D each.

const CATALOG_PATH := "res://shops/catalog.json"
## File and name suffix of the night copy of a shop.
const NIGHT_SUFFIX := "_night"

## Catalog id -> {"id", "file", "width", "depth", "height"}; read once.
static var _entries := {}


static func _ensure_catalog() -> void:
	if not _entries.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Dictionary:
		push_warning("[Shops] cannot read " + CATALOG_PATH)
		return
	for s in data.get("shops", []):
		var size: Dictionary = s["size_m"]
		_entries[s["id"]] = {
			"id": s["id"], "file": s["file"], "name": s.get("name", s["id"]), "category": s.get("category", ""),
			"width": float(size["width"]), "depth": float(size["depth"]), "height": float(size["height"]),
		}


## Library id of the mesh of catalog shop `id` (loaded on first use), or -1.
static func mesh_id(lib: ModelLibrary, id: String) -> int:
	_ensure_catalog()
	if not _entries.has(id):
		push_warning("[Shops] unknown shop " + id)
		return -1
	return lib.load_named("shop:" + id, _entries[id]["file"])


## The catalog as the list ShopSites.plan() takes.
static func catalog() -> Array:
	_ensure_catalog()
	return _entries.values()


## Library id of the night copy of catalog shop `id` (shops/models/<id>_night.glb, its SHOP
## sign lit at night by its own night map), or -1 when it has none.
static func night_mesh_id(lib: ModelLibrary, id: String) -> int:
	_ensure_catalog()
	if not _entries.has(id):
		return -1
	var path := String(_entries[id]["file"]).trim_suffix(".glb") + NIGHT_SUFFIX + ".glb"
	if not ResourceLoader.exists(path):
		return -1
	var mid := lib.load_named("shop:" + id + NIGHT_SUFFIX, path)
	if mid >= 0:
		NightWindows.light_own(lib.meshes[mid])
	return mid


func build(data: CityData, lib: ModelLibrary) -> void:
	var placed := 0
	var lit := 0
	for p in ShopSites.plan(data, catalog()):
		var mid := mesh_id(lib, p["id"])
		if mid < 0:
			continue
		var e: Dictionary = _entries.get(p["id"], {})
		_place(lib.meshes[mid], p, p["at"], String(p["id"]), {
			"uid": "S-%02d" % placed, "number": placed, "title": e.get("name", p["id"]), "kind": "SHOP",
			"model": String(p["id"]), "category": e.get("category", ""), "note": "development island",
		})
		placed += 1
		# The night copy stands in front of the original, to compare the two.
		var nid := night_mesh_id(lib, p["id"])
		if nid < 0:
			continue
		_place(lib.meshes[nid], p, p["night_at"], String(p["id"]) + NIGHT_SUFFIX, {
			"uid": "S-%02dN" % (placed - 1), "number": placed - 1, "title": "%s (night)" % e.get("name", p["id"]),
			"kind": "SHOP", "model": String(p["id"]) + NIGHT_SUFFIX, "category": e.get("category", ""),
			"note": "development island, SHOP sign lit at night",
		})
		lit += 1
	print("[Shops] %d shops placed, %d night copies" % [placed, lit])


## One shop (`mesh`) of the placement `p` at `at` (cells), with its name label.
func _place(mesh: Mesh, p: Dictionary, at: Vector2, title: String, pick: Dictionary) -> void:
	var s: float = p.get("scale", ShopSites.CELLS_PER_METRE)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, p["yaw"]) * Basis.from_scale(Vector3.ONE * s),
			Vector3(at.x, 0.0, at.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = title
	add_child(mi)
	mi.set_meta("pick", pick)
	var label := Label3D.new()
	label.text = title.trim_prefix("shop-")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.font_size = 40
	label.outline_size = 12
	label.position = Vector3(at.x, p["height"] * s + 0.6, at.y)
	label.name = "Label_" + title
	add_child(label)
