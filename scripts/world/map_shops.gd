class_name MapShops
extends Node3D
## The shops of res://shops (see shops/CATALOG.md) put on the island at the spots chosen
## by ShopSites. Static props, like the vehicles: one MeshInstance3D each.

const CATALOG_PATH := "res://shops/catalog.json"

## Catalog id -> {"file", "width", "depth", "zones", "copies"}; read once.
static var _entries := {}


static func _ensure_catalog() -> void:
	if not _entries.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Dictionary:
		push_warning("[Shops] cannot read " + CATALOG_PATH)
		return
	for s in data.get("shops", []):
		var zones: Array[int] = []
		for name in s.get("zones", []):
			var z: int = CityTypes.Zone.get(name, -1)
			if z >= 0:
				zones.append(z)
		_entries[s["id"]] = {
			"id": s["id"], "file": s["file"],
			"width": float(s["size_m"]["width"]), "depth": float(s["size_m"]["depth"]),
			"zones": zones, "copies": int(s.get("copies", 1)),
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
		mi.name = "%s_%d" % [p["id"], placed]
		add_child(mi)
		placed += 1
	print("[Shops] %d shops placed" % placed)
