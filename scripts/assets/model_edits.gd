class_name ModelEdits
extends RefCounted
## Hand edits of the models of the map (from the audits, docs/audit *.docx).
##   REMOVED          models taken off the map: the lots that would use them stay empty and their
##                    mesh data is freed (ModelLibrary keeps only the box, so the ids do not move);
##   REPLACED         a model drawn as another one (the label of the first is kept, the mesh is
##                    the one of the second; they share it in memory);
##   REMOVED_VEHICLES catalog vehicles (vehicles/catalog.json) taken off the map.
## Models are named like the audits: "pack.glb: node", or the file name of a single model.

const REMOVED := [
	"hotels.glb: hotel_tower",
	"hungry.glb: burger_king",
	"ny_buildings.glb: flatiron",
	"ny_buildings.glb: metlife",
	"ny_buildings.glb: ny_glass_4",
	"towers_a.glb: towers_a_11_b",
	"port_towers.glb: tower_tank_4",
	"port_towers.glb: tower_tank_5",
]

## Drawn as building-type-f and building-type-g, one after the other.
const HOUSE_SWAP := ["building-type-f.glb", "building-type-g.glb"]
const HOUSE_SWAPPED := [
	"carto.glb: restaurant", "carto.glb: town0", "carto.glb: town3", "carto.glb: town4",
	"free_mini.glb: m2", "ny_buildings.glb: ny_brick_1", "ny_buildings.glb: ny_brick_5",
	"ny_buildings.glb: ny_brick_6", "free_mini.glb: m11",
]

const HOTEL_SMALL := "hotel_small_night.glb: hotel_small"
const BARRACK := "outpost.glb: barrack_b"

const REMOVED_VEHICLES := [
	"m8_pickup_mustard", "m8_wagon_blue", "p54_24_sedan_hardtop_teal",
	"m8_wagon_mustard", "m8_wagon_teal", "m8_wagon_sloped_black", "m8_wagon_sloped_burgundy",
	"m8_pickup_blue", "p54_12_wreck_chassis",
	"p54_42_forwarder_green", "p54_41_loader_claw_yellow", "p54_08_tow_truck_yellow",
	"p54_35_crane_truck_mobile", "p54_18_tanker_fuel", "p54_10_tanker_water", "school_bus",
	"p54_01_suv_offroad_navy", "humvee_sand",
]


static func replaced() -> Dictionary:
	var out := {
		"hotel_low.glb: hotel_orange": HOTEL_SMALL,
		"hotel_stars_night.glb: hotel_stars": HOTEL_SMALL,
		"carto.glb: hotel1": HOTEL_SMALL,
		"outpost.glb: ranch_b": BARRACK,
		"outpost.glb: ranch_a": BARRACK,
	}
	for i in HOUSE_SWAPPED.size():
		out[HOUSE_SWAPPED[i]] = HOUSE_SWAP[i % HOUSE_SWAP.size()]
	# The brick apartment is drawn as the cartoon house.
	out["ny_buildings.glb: ny_brick_4"] = "carto.glb: house2"
	return out


static func vehicle_removed(id: String) -> bool:
	return REMOVED_VEHICLES.has(id)


## Vehicles taken off the map where they stand: catalog id and the cell they were planned at
## (the wheel loader of the old BT tower island, the Rosomak beside the lighthouse of the prison island).
const REMOVED_VEHICLES_AT := [
	["p54_38_loader_grapple_yellow", Vector2(33.5, 88.5)],
	["rosomak_apc", Vector2(29.5, 48.5)],
]


static func vehicle_removed_at(id: String, at: Vector2) -> bool:
	for v in REMOVED_VEHICLES_AT:
		if v[0] == id and (v[1] as Vector2).distance_to(at) < 2.0:
			return true
	return false


## Every boat (all kinds) is taken off the map: its lot is cleared.
static func clear_boats(data: CityData) -> int:
	var n := 0
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.BOAT:
			data.b_kind[b] = CityTypes.Kind.EMPTY
			n += 1
	return n


## The stripe of 1-wide lots along column `x` from row `y0` to `y1` (downtown, commercial and
## apartment zones: B-00111 to B-00131) is emptied. Returns how many lots were cleared.
static func clear_column(data: CityData, x: int, y0: int, y1: int) -> int:
	var n := 0
	for b in data.building_count():
		var r := data.building_rect(b)
		if r.position.x == x and r.size.x == 1 and r.position.y >= y0 and r.position.y < y1:
			if data.b_kind[b] == CityTypes.Kind.EMPTY:
				continue
			data.b_kind[b] = CityTypes.Kind.EMPTY
			n += 1
	return n
