class_name MapVehicles
extends Node3D
## The vehicles of res://vehicles (see vehicles/CATALOG.md) put on the island at the spots
## chosen by VehicleSites. Static props, like the roadblocks: one MeshInstance3D each.

const CATALOG_PATH := "res://vehicles/catalog.json"

## Catalog id -> {"file": path, "length": metres}; read once.
static var _entries := {}


static func _ensure_catalog() -> void:
	if not _entries.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Dictionary:
		push_warning("[Vehicles] cannot read " + CATALOG_PATH)
		return
	for v in data.get("vehicles", []):
		_entries[v["id"]] = {"file": v["file"], "length": float(v["size_m"]["length"])}


## Library id of the mesh of catalog vehicle `id` (loaded on first use), or -1.
static func mesh_id(lib: ModelLibrary, id: String) -> int:
	_ensure_catalog()
	if not _entries.has(id):
		push_warning("[Vehicles] unknown vehicle " + id)
		return -1
	return lib.load_named("veh:" + id, _entries[id]["file"])


static func lengths_m() -> Dictionary:
	_ensure_catalog()
	var out := {}
	for id in _entries:
		out[id] = _entries[id]["length"]
	return out


func build(data: CityData, lib: ModelLibrary) -> void:
	var placed := 0
	for p in VehicleSites.plan(data, lengths_m()):
		var mid := mesh_id(lib, p["id"])
		if mid < 0:
			continue
		var at: Vector2 = p["at"]
		var s := VehicleSites.CELLS_PER_METRE
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[mid]
		mi.transform = Transform3D(Basis(Vector3.UP, p["yaw"]) * Basis.from_scale(Vector3.ONE * s),
				Vector3(at.x, 0.0, at.y))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = String(p["id"])
		add_child(mi)
		placed += 1
	print("[Vehicles] %d vehicles placed" % placed)
