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
	QUARTER_LOW, QUARTER_MID, QUARTER_TALL, OUTPOST,
	POLICE, STADIUM,
	# Main public buildings (one of each), U.N. tower, crane, bridge
	POLICE_MAIN, CITY_HALL_MAIN, HOSPITAL_MAIN, SCHOOL_MAIN, PHARMACY, GAS_STATION,
	UN_TOWER, CRANE, BRIDGE,
	# Second and third wave of packs
	BANK_PACK, POLICE_CAR, BARRIER, CONE, TRUCK, CONTAINER, BARREL,
	HOUSE2, TOWN2, SHOP2, HOTEL_SMALL, HOTEL_PACK, MUSEUM_PACK, CHURCH_PACK, GAS_PACK,
	WAREHOUSE, FACTORY, RUIN, MANSION, PRISON_BLOCK, POOR_SLAB, POOR_BLOCK, RUSSIAN, FIELD, STALL,
	# Fourth wave: the urban island, burger restaurants, the west bridge
	URBAN, MCDONALDS, BURGER_KING, SKYLINE2, METAL_BRIDGE,
	# Fifth wave: futuristic towers
	FUTURE,
	# Sixth wave: nuclear plant, new cinema, airport, burger joints, villas, roadblocks
	NUCLEAR, CINEMA2, AIRPORT, BURGER_JOINT, VILLA, ROADBLOCK_A, ROADBLOCK_B,
	# Seventh wave: more urban towers, cooling towers, the BT tower, the watchtower
	URBAN2, NIGHT_TOWER, COOLING, COOLING_HALL, WATCHTOWER,
	# Eighth wave: neon roof signs
	NEON_CONTROLLER, NEON_PACMAN,
	# Ninth wave: piers
	PIER,
	# Tenth wave: boats
	BOAT_SIMPLE, BOAT_WOODEN, BOAT_FISHING, BOAT_CARGO, BOAT_SUB,
	# Eleventh wave: forest fire truck, tank, billboard, hot air balloon, F-111 jets
	TRUCK_CCF, TANK, BILLBOARD, BALLOON, JET_F111,
	# Twelfth wave: UFO
	UFO,
	# Thirteenth wave: the concert camp (festival stage, floodlight, bleacher, crowd barrier)
	CONCERT_STAGE, FLOODLIGHT, BLEACHER, CROWD_BARRIER,
	# Fourteenth wave: the military base of the fog island, the low poly church, one more neon sign
	CHURCH_LOW, JET_F14, TENT_JUNGLE, TENT_MEDICAL, SAM_NASAMS, RADAR,
	APC_EE11, APC_BMP1, APC_BRDM, TANK_T55, NUCLEAR2, BASE_HALL, NEON_WOMAN,
	# Fifteenth wave: the night skyline towers of the urban island, the Golden Gate bridge, the
	# radar dish (satellite dishes), the aircraft carrier, the oil silo
	NIGHT_SKYLINE, GOLDEN_GATE, SAT_DISH, CARRIER, SILO,
	# Sixteenth wave (tools/build_wave16_models.py): signs for the walls of the urban island, the
	# hotel, the basketball court
	SIGN_WINDOWS, NEON_JOYSTICK, NEON_MARTINI, NEON_BAR, HOTEL_LOW, COURT,
	# Seventeenth wave: more neon signs (walls of the urban island, roofs of Las Vegas), the bank
	NEON_BULL, NEON_FUN, NEON_PALM, NEON_CLUB, NEON_GIRL, NEON_LOVE, BANK_MIN,
	# Eighteenth wave (tools/build_wave16_models.py, PortRework): the industrial buildings set (halls,
	# sheds, towers and tanks), the oil and storage tanks with the brick factory, the offshore oil rig
	IND_HALL, IND_SHED, IND_TOWER, PORT_TANK, OIL_RIG,
	# Nineteenth wave (tools/build_wave16_models.py): Taiwan style signboards of the urban island
	# (blade signs on the east walls, boards on the roofs, an LED band round a corner)
	TW_BANASONIC, TW_MCDONALDS, TW_COLA_JP, TW_COLA_BILLBOARD, TW_LED_BOARD, TW_LED_BAND,
	# Nineteenth wave: the checkpoint of the Golden Gate (fog island), the "Danger" plate of the
	# secret base, the lighthouse club of the little island and the glowing part of its sign
	CHECKPOINT, DANGER_SIGN, LIGHTHOUSE_CLUB, NEON_LIGHTHOUSE,
	# Twentieth wave: the low poly business buildings (central city shops and eateries)
	BIZ_RESTAURANT, BIZ_SHOP, BIZ_PIZZA, BIZ_BURGER, BIZ_CAFE,
	# Twenty-first wave: the Utrecht city hall (the museum)
	MUSEUM_HALL,
	# Twenty-second wave: the towns of the fog island (FogBaseSites)
	FOG_OFFICE, FOG_HOUSE, FOG_NIGHT_TOWER, FOG_OFFICE_TOWER, FOG_FLOOR, FOG_MOD_HOUSE, FOG_MOD_TOWER,
	# Twenty-third wave: the supermarket of Las Vegas, its XXX and Playboy neon signs, the seven
	# modular houses of the fog island
	SUPERMARKET, NEON_XXX, NEON_PLAYBOY, FOG_MOD_HOME,
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
