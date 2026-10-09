class_name ModelCatalog
extends RefCounted
## Finds model files under the models folder and sorts them into categories:
##   - kit models (one model per file) by file name,
##   - curated packs (many buildings in one file) by their "*.models.json" list,
##     written by tools/curate_models.gd.
## Only the needed categories are kept, so unused pieces never reach memory.
## Folders starting with "_" or "." (raw incoming packs) are skipped.

enum Cat {
	SKYSCRAPER, COMMERCIAL, HOUSE, INDUSTRIAL, INDUSTRIAL_PROP, TREE,
	ROAD_STRAIGHT, ROAD_CROSS, ROAD_T, ROAD_BEND, ROAD_END,
	BRIDGE_PILLAR, STREET_LIGHT,
	# Curated packs
	TOWER_PHOTO, LANDMARK, NY_STREET, NY_MIDRISE, PANEL,
	QUARTER_LOW, QUARTER_MID, QUARTER_TALL, BIZ_SHOP, BIZ_PIZZA, CINEMA, MALL, OUTPOST,
	POLICE, STADIUM,
	# Main public buildings (one of each), U.N. tower, crane, bridge, night skyline
	POLICE_MAIN, CITY_HALL_MAIN, HOSPITAL_MAIN, SCHOOL_MAIN, PHARMACY, GAS_STATION,
	UN_TOWER, CRANE, BRIDGE, SKYLINE,
	# Second and third wave of packs
	BANK_PACK, POLICE_CAR, BARRIER, CONE, TRUCK, CONTAINER, BARREL,
	HOUSE2, TOWN2, SHOP2, HOTEL_SMALL, HOTEL_PACK, MUSEUM_PACK, CHURCH_PACK, GAS_PACK,
	WAREHOUSE, FACTORY, RUIN, MANSION, PRISON_BLOCK, POOR_SLAB, POOR_BLOCK, RUSSIAN, FIELD, STALL,
	# Fourth wave: the urban island, burger restaurants, the west bridge
	URBAN, MCDONALDS, BURGER_KING, SKYLINE2, METAL_BRIDGE,
	# Fifth wave: futuristic towers, pirate ship
	FUTURE, PIRATE_SHIP,
}

const MANIFEST_SUFFIX := ".models.json"

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

## Each entry: {path, cat, mask} and, for a building inside a pack, {node}.
var entries: Array[Dictionary] = []


func scan(root: String) -> void:
	entries.clear()
	var files: Array[String] = []
	var manifests: Array[String] = []
	_collect(root, files, manifests)
	files.sort()
	manifests.sort()
	var packed := {}
	for m in manifests:
		for e in _read_manifest(m):
			entries.append(e)
			packed[e["path"]] = true
	for path in files:
		if packed.has(path):
			continue
		var info := classify(path)
		if not info.is_empty():
			entries.append(info)


## Entries of a curated pack list: {"file": "x.glb", "models": [{"node", "cat"}]}.
func _read_manifest(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("[Models] bad list " + path)
		return out
	var glb: String = path.get_base_dir().path_join(data.get("file", ""))
	for m in data.get("models", []):
		if Cat.has(m.get("cat", "")):
			out.append({"path": glb, "node": m["node"], "cat": Cat[m["cat"]], "mask": 0})
	return out


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
func _collect(dir_path: String, out: Array[String], manifests: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		var full := dir_path.path_join(file)
		if dir.current_is_dir():
			if not file.begins_with(".") and not file.begins_with("_"):
				_collect(full, out, manifests)
		elif file.ends_with(MANIFEST_SUFFIX):
			manifests.append(full)
		else:
			var clean := full.trim_suffix(".import").trim_suffix(".remap")
			if clean.get_extension().to_lower() in MODEL_EXTENSIONS and not out.has(clean):
				out.append(clean)
		file = dir.get_next()
	dir.list_dir_end()
