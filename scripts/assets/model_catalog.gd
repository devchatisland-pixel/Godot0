class_name ModelCatalog
extends RefCounted
## Finds model files under the models folder and sorts them into categories
## by file name. Only files of the needed categories are kept, so unused kit
## pieces (signs, fences, cones...) are never loaded into memory.

enum Cat {
	SKYSCRAPER, COMMERCIAL, HOUSE, INDUSTRIAL, INDUSTRIAL_PROP, TREE,
	ROAD_STRAIGHT, ROAD_CROSS, ROAD_T, ROAD_BEND, ROAD_END,
	BRIDGE_PILLAR, STREET_LIGHT,
}

## Native connection mask of each Kenney road tile (measured from the meshes:
## straight runs along X, the T-junction is closed on its north side, etc.).
const ROAD_TILES := {
	"road-straight": [Cat.ROAD_STRAIGHT, CityTypes.DIR_E | CityTypes.DIR_W],
	"road-crossroad": [Cat.ROAD_CROSS, 15],
	"road-intersection": [Cat.ROAD_T, CityTypes.DIR_E | CityTypes.DIR_S | CityTypes.DIR_W],
	"road-bend": [Cat.ROAD_BEND, CityTypes.DIR_S | CityTypes.DIR_W],
	"road-end": [Cat.ROAD_END, CityTypes.DIR_E],
}

const MODEL_EXTENSIONS := ["glb", "gltf"]

## Each entry: {path, cat, mask}
var entries: Array[Dictionary] = []


func scan(root: String) -> void:
	entries.clear()
	var files: Array[String] = []
	_collect(root, files)
	files.sort()
	for path in files:
		var info := classify(path)
		if not info.is_empty():
			entries.append(info)


## Returns {path, cat, mask} or {} when the file is not useful.
static func classify(path: String) -> Dictionary:
	var lower := path.to_lower()
	var name := lower.get_file().get_basename()
	var res := {"path": path, "mask": 0}
	if ROAD_TILES.has(name):
		res["cat"] = ROAD_TILES[name][0]
		res["mask"] = ROAD_TILES[name][1]
		return res
	if name.begins_with("low-detail") or name.begins_with("detail-"):
		return {}
	if name.contains("skyscraper"):
		res["cat"] = Cat.SKYSCRAPER
	elif name.begins_with("building") and lower.contains("commercial"):
		res["cat"] = Cat.COMMERCIAL
	elif name.begins_with("building") and lower.contains("suburban"):
		res["cat"] = Cat.HOUSE
	elif name.begins_with("building") and lower.contains("industrial"):
		res["cat"] = Cat.INDUSTRIAL
	elif name.begins_with("chimney") or name.begins_with("detail-tank") \
			or name.begins_with("shipping-container") or name == "water-tower" \
			or name.begins_with("tank"):
		res["cat"] = Cat.INDUSTRIAL_PROP
	elif name.begins_with("tree"):
		res["cat"] = Cat.TREE
	elif name == "bridge-pillar-wide":
		res["cat"] = Cat.BRIDGE_PILLAR
	elif name == "light-square-double" or name == "light-curved-double":
		res["cat"] = Cat.STREET_LIGHT
	else:
		return {}
	return res


## Recursive listing that also works in exported builds, where the source
## files are replaced by "*.import" / "*.remap" entries.
func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		var full := dir_path.path_join(file)
		if dir.current_is_dir():
			if not file.begins_with("."):
				_collect(full, out)
		else:
			var clean := full.trim_suffix(".import").trim_suffix(".remap")
			if clean.get_extension().to_lower() in MODEL_EXTENSIONS and not out.has(clean):
				out.append(clean)
		file = dir.get_next()
	dir.list_dir_end()
