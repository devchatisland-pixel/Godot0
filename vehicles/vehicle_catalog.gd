class_name VehicleCatalog
extends RefCounted
## Lookup helper for res://vehicles/catalog.json (see CATALOG.md for the visual list).
## Not wired into the map; call it from wherever vehicles get spawned later.
##   var car := VehicleCatalog.instantiate("p54_04_sedan_modern_silver")

const CATALOG_PATH := "res://vehicles/catalog.json"

static var _entries: Array = []
static var _by_id: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _entries.is_empty():
		return
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("VehicleCatalog: cannot parse %s" % CATALOG_PATH)
		return
	_entries = data.get("vehicles", [])
	for e in _entries:
		_by_id[e["id"]] = e


static func all() -> Array:
	_ensure_loaded()
	return _entries


static func get_entry(id: String) -> Dictionary:
	_ensure_loaded()
	return _by_id.get(id, {})


static func in_category(category: String) -> Array:
	_ensure_loaded()
	return _entries.filter(func(e): return e["category"] == category)


static func categories() -> PackedStringArray:
	_ensure_loaded()
	var out := PackedStringArray()
	for e in _entries:
		if not out.has(e["category"]):
			out.append(e["category"])
	return out


## Returns the vehicle scene root (front is -Z, origin on the ground), or null.
static func instantiate(id: String) -> Node3D:
	var e := get_entry(id)
	if e.is_empty():
		push_warning("VehicleCatalog: unknown vehicle '%s'" % id)
		return null
	var scene := load(e["file"]) as PackedScene
	return scene.instantiate() as Node3D if scene else null
