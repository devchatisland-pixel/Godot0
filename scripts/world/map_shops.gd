class_name MapShops
extends Node3D
## The shops of res://shops (see shops/CATALOG.md): one of each in a row on the development
## island (ShopSites), each with a name label. Static props like the vehicles: one
## MeshInstance3D each.

const CATALOG_PATH := "res://shops/catalog.json"

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
			"id": s["id"], "file": s["file"],
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


func build(data: CityData, lib: ModelLibrary) -> void:
	var placed := 0
	for p in ShopSites.plan(data, catalog()):
		var mid := mesh_id(lib, p["id"])
		if mid < 0:
			continue
		var at: Vector2 = p["at"]
		var s := ShopSites.CELLS_PER_METRE
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[mid]
		mi.transform = Transform3D(Basis(Vector3.UP, p["yaw"]) * Basis.from_scale(Vector3.ONE * s),
				Vector3(at.x, 0.0, at.y))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = String(p["id"])
		add_child(mi)
		var label := Label3D.new()
		label.text = String(p["id"]).trim_prefix("shop-")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.012
		label.font_size = 40
		label.outline_size = 12
		label.position = Vector3(at.x, p["height"] * s + 0.6, at.y)
		label.name = "Label_" + String(p["id"])
		add_child(label)
		placed += 1
	print("[Shops] %d shops placed" % placed)
