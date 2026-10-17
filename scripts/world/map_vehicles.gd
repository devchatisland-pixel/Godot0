class_name MapVehicles
extends Node3D
## The vehicles of res://vehicles (see vehicles/CATALOG.md) put on the island at the spots
## chosen by VehicleSites. Static props, like the roadblocks: one MeshInstance3D each.

## Police cars are drawn 15 % bigger than the other vehicles.
const POLICE_SCALE := {"police_jp_black": 1.15, "police_jp_patrol": 1.15, "police_us_cruiser": 1.15}
const CATALOG_PATH := "res://vehicles/catalog.json"
## Height of a ground helipad above the ground (and of the helicopter standing on it).
const HELIPAD_LIFT := 0.03

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
## A "<file>_night.glb" next to the model is its night duplicate (same look by day, its
## lights glow at night: tools/make_night_variants.py); it is drawn in place of the model.
static func mesh_id(lib: ModelLibrary, id: String) -> int:
	_ensure_catalog()
	if not _entries.has(id):
		push_warning("[Vehicles] unknown vehicle " + id)
		return -1
	var file: String = _entries[id]["file"]
	var night := file.get_basename() + "_night.glb"
	if ResourceLoader.exists(night) or FileAccess.file_exists(night):
		var nid := lib.load_named("veh:" + id, night)
		if nid >= 0:
			NightWindows.light_own(lib.meshes[nid])
			return nid
	return lib.load_named("veh:" + id, file)


static func lengths_m() -> Dictionary:
	_ensure_catalog()
	var out := {}
	for id in _entries:
		out[id] = _entries[id]["length"]
	return out


## The helipad on the ground: the painted H of the hospital roof (LandmarkMeshes); -1 when
## it is missing.
static func helipad_id(lib: ModelLibrary) -> int:
	return lib.named_id("helipad_h")


## The helipad, `width` cells across, lying on the ground with its middle at `at`.
static func helipad_xform(at: Vector3, width: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(width, 1, width)), at + Vector3(0, HELIPAD_LIFT, 0))


func build(data: CityData, lib: ModelLibrary) -> void:
	var placed := 0
	for p in VehicleSites.plan(data, lengths_m()):
		if RemovedModels.has("veh:" + String(p["id"])):
			continue
		var mid := mesh_id(lib, p["id"])
		if mid < 0:
			continue
		var at: Vector2 = p["at"]
		var s: float = VehicleSites.CELLS_PER_METRE * POLICE_SCALE.get(String(p["id"]), 1.0) 				* VehicleSites.size_factor(String(p["id"]))
		var pad_id := helipad_id(lib) if p.has("pad") else -1
		var lift := float(p.get("lift", 0.0)) + (HELIPAD_LIFT if pad_id >= 0 else 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = lib.meshes[mid]
		mi.transform = Transform3D(Basis(Vector3.UP, p["yaw"]) * Basis.from_scale(Vector3.ONE * s),
				Vector3(at.x, lift, at.y))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = String(p["id"])
		add_child(mi)
		# Aircraft: red light on the left wingtip, green on the right (NavLights).
		for l in NavLights.for_vehicle(lib, String(p["id"]), mid, mi.transform):
			var light := MeshInstance3D.new()
			light.mesh = lib.meshes[l[0]]
			light.transform = l[1]
			light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(light)
		if pad_id >= 0:
			# The helipad the vehicle stands on.
			var pad := MeshInstance3D.new()
			pad.mesh = lib.meshes[pad_id]
			pad.transform = helipad_xform(Vector3(at.x, 0, at.y), float(p["pad"]))
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pad.set_meta("pick", {
				"uid": "V-%03d-pad" % placed, "number": placed, "title": "Helipad", "kind": "PROP",
				"model": "helipad_h", "category": "Prop", "note": String(p.get("why", "")),
			})
			add_child(pad)
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
		if p["file"] == ScenicProps.BILLBOARD and not NightWindows.light_billboard(lib.meshes[id]):
			push_warning("[Props] the park billboard has no flat panel to light at night")
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
			"front": p.get("front", Vector3(0, 0, -1)),
		})
		n += 1
	print("[Props] %d props placed" % n)
