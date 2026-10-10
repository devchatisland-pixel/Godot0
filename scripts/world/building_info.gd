class_name BuildingInfo
extends RefCounted
## What is known about one building, for the selection popup and for any future
## database or game logic. `describe` returns a plain Dictionary:
##   id        building number in the city data (stable for a given seed)
##   uid       readable id, "B-00123"
##   name      what it is, for people ("Police headquarters")
##   kind      the code name of its type (CityTypes.Kind), e.g. "POLICE_HQ"
##   category  the model category it is drawn from (ModelCatalog.Cat), "" for procedural models
##   model     the model: "pack.glb: node" or the name of the procedural mesh
##   model_id  index of the mesh in the ModelLibrary
##   cell      top-left cell (Vector2i) and `size` in cells (Vector2i)
##   world     centre of the footprint in world units (Vector3)
##   facing    "N", "E", "S" or "W" (the side of its front)
##   zone      ground zone of its first cell, e.g. "DOWNTOWN"
##   seed      seed that picks its model variant

## Readable names that the code name alone does not give.
const NAMES := {
	"UN_HQ": "United Nations headquarters", "POLICE_HQ": "Police headquarters",
	"POLICE": "Police station", "MAIN_HOSPITAL": "Main hospital", "HOSPITAL": "Clinic",
	"MAIN_SCHOOL": "Main school", "MCDONALDS": "McDonald's", "BURGER_KING": "Burger King",
	"BURGER_JOINT": "Burger restaurant", "CINEMA_MAIN": "Cinema", "FUTURE_BLDG": "Futuristic tower",
	"URBAN_BLDG": "Tower", "QUARTER_BLDG": "Red district building", "NUCLEAR_PLANT": "Nuclear plant",
	"POOR_BLDG": "Poor district block", "RUSSIAN": "Urban ghetto block", "FACTORY_BLDG": "Factory",
	"PRISON": "Penitentiary", "PRISON_WING": "Prison block", "SHOPPING_CENTER": "Shopping center",
	"FERRIS_WHEEL": "Ferris wheel", "DRIVE_IN": "Drive-in cinema", "TELECOM_TOWER": "Radio tower",
	"SAT_DISH": "Satellite dish", "OIL_PUMP": "Oil pump", "AIRBASE": "Secret base",
	"NIGHTCLUB": "Las Vegas club", "CASINO": "Casino", "LANDMARK": "Landmark tower",
	"SKYSCRAPER": "Skyscraper", "GAS_STATION": "Gas station", "POST_OFFICE": "Post office",
	"PIRATE_SHIP": "Pirate ship", "GRAVE": "Pirate grave", "FIELD": "Crop field",
	"OUTPOST": "Farm or ranch building", "INDUSTRIAL_YARD": "Industrial yard", "SHOP": "Shop",
	"AIRPORT": "Airport", "COOLING_TOWER": "Cooling tower", "COOLING_HALL": "Cooling hall",
	"BT_TOWER": "BT tower", "WATCHTOWER": "Watchtower", "EMPTY": "Cleared lot",
}
const FACINGS := ["N", "E", "S", "W"]


static func describe(data: CityData, lib: ModelLibrary, i: int) -> Dictionary:
	var kind: int = data.b_kind[i]
	var kind_name: String = CityTypes.Kind.keys()[kind]
	var rect := data.building_rect(i)
	var pick := BuildingPlacer.pick_for(data, lib, i)
	var model_id: int = pick["id"] if pick.has("id") else -1
	var cat := ""
	if model_id >= 0 and lib.cats[model_id] >= 0:
		cat = ModelCatalog.Cat.keys()[lib.cats[model_id]]
	var zone: int = data.zone_at(rect.position.x, rect.position.y)
	return {
		"id": i,
		"uid": "B-%05d" % i,
		"name": NAMES.get(kind_name, kind_name.capitalize()),
		"kind": kind_name,
		"category": cat,
		"model": lib.model_name(model_id) if model_id >= 0 else "(no model: ground detail)",
		"model_id": model_id,
		"cell": rect.position,
		"size": rect.size,
		"world": Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5),
		"facing": FACINGS[int(data.b_facing[i]) % 4],
		"zone": CityTypes.Zone.keys()[zone],
		"seed": data.b_seed[i],
	}


## The info as plain text (copied by the "Copy" button).
static func to_text(info: Dictionary) -> String:
	var cell: Vector2i = info["cell"]
	var size: Vector2i = info["size"]
	return "%s | %s | kind %s | model %s | cell %d,%d size %dx%d | facing %s | zone %s | seed %d" % [
			info["uid"], info["name"], info["kind"], info["model"], cell.x, cell.y, size.x, size.y,
			info["facing"], info["zone"], info["seed"]]
