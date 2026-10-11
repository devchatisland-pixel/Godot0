class_name MapVehicles
extends Node3D
## The vehicles of res://vehicles (see vehicles/CATALOG.md) put on the island at the spots
## chosen by VehicleSites. Static props, like the roadblocks: one MeshInstance3D each.

## Police cars are drawn 15 % bigger than the other vehicles.
const POLICE_SCALE := {"police_jp_black": 1.15, "police_jp_patrol": 1.15, "police_us_cruiser": 1.15}
const CATALOG_PATH := "res://vehicles/catalog.json"

## Catalog id -> {"file": path, "length": metres, "name", "category"}; read once.
static var _entries := {}


static func _ensure_catalog() -> void:
	if not _entries.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Dictionary:
		push_warning("[Vehicles] cannot read " + CATALOG_PATH)
		return
	for v in data.get("vehicles", []):
		_entries[v["id"]] = {
			"file": v["file"], "length": float(v["size_m"]["length"]),
			"name": v.get("name", v["id"]), "category": v.get("category", ""),
		}


## What the picker shows for catalog vehicle `id` (see BuildingInfo.for_prop).
static func entry(id: String) -> Dictionary:
	_ensure_catalog()
	return _entries.get(id, {})


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
		var s: float = VehicleSites.CELLS_PER_METRE * POLICE_SCALE.get(String(p["id"]), 1.0)
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[mid]
		mi.transform = Transform3D(Basis(Vector3.UP, p["yaw"]) * Basis.from_scale(Vector3.ONE * s),
				Vector3(at.x, float(p.get("lift", 0.0)), at.y))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = String(p["id"])
		add_child(mi)
		var e := entry(p["id"])
		mi.set_meta("pick", {
			"uid": "V-%03d" % placed, "number": placed, "title": e.get("name", p["id"]), "kind": "VEHICLE",
			"model": String(p["id"]), "category": e.get("category", ""), "note": String(p.get("why", "")),
		})
		placed += 1
	print("[Vehicles] %d vehicles placed" % placed)
	_build_props(data, lib)


## The single props of ScenicProps (beach umbrella and chairs, the park billboard): each one
## stands on the ground, scaled so that its longest side is the planned length.
func _build_props(data: CityData, lib: ModelLibrary) -> void:
	var n := 0
	for p in ScenicProps.plan(data):
		var id := lib.load_named("prop:" + String(p["file"]).get_file(), p["file"])
		if id < 0:
			continue
		var box := lib.bounds[id]
		var longest := maxf(box.size.x, box.size.z)
		if longest <= 0.0:
			continue
		var basis := Basis(Vector3.UP, p["yaw"]) * Basis.from_scale(Vector3.ONE * (float(p["length"]) / longest))
		var bottom := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[id]
		mi.transform = Transform3D(basis, p["at"] - basis * bottom)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Prop_%d" % n
		add_child(mi)
		mi.set_meta("pick", {
			"uid": "P-%03d" % n, "number": n, "title": p["title"], "kind": "PROP",
			"model": String(p["file"]).get_file(), "category": "Prop", "note": "",
		})
		n += 1
	print("[Props] %d props placed" % n)
