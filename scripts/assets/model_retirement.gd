class_name ModelRetirement
extends RefCounted
## Models taken off the map to save memory and loading time (audit of the models used only once or
## twice, docs/audit orphelin models.docx). Labels are the ones of ModelLibrary ("pack.glb: node", or
## the file name of a single model); vehicles and boats of the catalog go by id.
##   - REPLACED: the slots of the old model show the other one (the old one is never loaded);
##   - DELETED: never loaded, never chosen. A fallback model of the same category stands in when
##     the category has others; when it has none the building stays a plain box.

const REPLACED := {
	"quarter.glb: quarter_46_b": "quarter.glb: quarter_48_b",
	"quarter.glb: quarter_35_b": "quarter.glb: quarter_40_b",
	"port_halls.glb: hall_factory_2": "port_halls.glb: hall_factory_1",
	"hotel_low.glb: hotel_orange": "hotel_small_night.glb: hotel_small",
	"building-type-l.glb": "bank_min.glb: bank_minimalist",
	"building-type-f.glb": "bank_min.glb: bank_minimalist",
	"carto.glb: hotel1": "hotel_small_night.glb: hotel_small",
	"hotels.glb: hotel_tower": "hotel_stars_night.glb: hotel_stars",
	"hungry.glb: burger_king": "hotel_stars_night.glb: hotel_stars",
	"port_halls.glb: hall_powerplant": "port_sheds.glb: shed_warehouse_3",
	"port_halls.glb: hall_terminal": "port_sheds.glb: shed_warehouse_3",
	"port_halls.glb: hall_warehouse_5": "port_sheds.glb: shed_warehouse_3",
	"port_sheds.glb: shed_generic_3": "port_sheds.glb: shed_trailer",
	"port_sheds.glb: shed_loadbay": "port_sheds.glb: shed_trailer",
	"port_sheds.glb: shed_works_1": "port_sheds.glb: shed_trailer",
	"quarter.glb: quarter_22_b": "quarter.glb: quarter_25_b",
	"quarter.glb: quarter_56_b": "quarter.glb: quarter_25_b",
	"quarter.glb: quarter_78_b": "quarter.glb: quarter_25_b",
	"outpost.glb: barrack_b": "outpost.glb: ranch_c",
	"quarter.glb: quarter_59_b": "quarter.glb: quarter_98_b",
	"quarter.glb: quarter_61_b": "quarter.glb: quarter_95_b",
	"urban.glb: tower5": "urban.glb: tower0",
	"urban.glb: tower6": "urban.glb: tower0",
	"port_halls.glb: hall_hangar": "port_halls.glb: hall_factory_1",
	"port_halls.glb: hall_warehouse_4": "port_halls.glb: hall_factory_1",
	"port_tanks.glb: tank_rusty": "port_tanks.glb: tank_oil",
	"port_towers.glb: tower_silo": "port_tanks.glb: tank_big",
}

const DELETED: Array[String] = [
	"business.glb: pizza",
	"building-m.glb",
	"business.glb: burger",
	"free_mini.glb: m3",
	"free_mini.glb: m7",
	"accommodations.glb: flat10",
	"quarter.glb: quarter_24_b",
	"quarter.glb: quarter_32_b",
	"carto.glb: town1",
	"carto.glb: town11",
	"euro.glb: townhouse_b",
	"euro.glb: townhouse_c",
	"free_mini.glb: m2",
	"building-type-p.glb",
	"building-type-g.glb",
	"building-type-m.glb",
	"building-type-u.glb",
	"carto.glb: bakery",
	"free_mini.glb: m9",
	"street.glb: shop_amber",
	"street.glb: shop_zinc",
	"carto.glb: restaurant",
	"carto.glb: town0",
	"carto.glb: town3",
	"carto.glb: town4",
	"gas_station_night.glb: m11",
	"ny_buildings.glb: chrysler",
	"ny_buildings.glb: empire_state",
	"ny_buildings.glb: flatiron",
	"ny_buildings.glb: metlife",
	"ny_buildings.glb: ny_times",
	"ny_buildings.glb: one_wtc",
	"ny_buildings.glb: woolworth",
	"outpost.glb: barrack_a",
	"port_halls.glb: hall_building_1",
	"port_halls.glb: hall_building_10",
	"port_towers.glb: tower_hut",
	"ny_buildings.glb: ny_glass_4",
	"ny_buildings.glb: ny_glass_1",
	"ny_buildings.glb: ny_glass_2",
	"towers_a.glb: towers_a_75_b",
	"towers_a.glb: towers_a_83_b",
	"supermarket.glb: supermarket",
	"camp_radar.glb: camp_radar",
	"nuclear2.glb: nuclear2",
	"army_apc.glb: apc_bmp1",
	"army_apc.glb: apc_ee11_aa",
	"oil_rig.glb: oil_rig",
	"tank.glb: tank",
]

## Catalog vehicles: id -> id of the vehicle drawn instead.
const VEHICLE_REPLACED := {
	"p54_42_forwarder_green": "p54_41_loader_claw_yellow",
	"p54_38_loader_grapple_yellow": "p54_41_loader_claw_yellow",
	"p54_14_semi_longnose_red": "p54_20_semi_cabover_yellow",
	"p54_10_tanker_water": "p54_20_semi_cabover_yellow",
}

## Catalog vehicles that are no longer placed.
const VEHICLE_DELETED: Array[String] = [
	"jeep_willys",
	"p54_07_box_truck_delivery_yellow",
	"p54_15_dump_truck_yellow",
	"humvee_sand",
	"p54_24_sedan_hardtop_teal",
	"p54_12_wreck_chassis",
	"p54_26_pickup_40s_red",
	"p54_35_crane_truck_mobile",
	"p54_18_tanker_fuel",
]


## Kinds of building whose models are all retired (or that lose some of their category): when
## none is left, nothing is drawn on the lot (no plain box).
const NO_MODEL_KINDS: Array[int] = [
	CityTypes.Kind.LANDMARK, CityTypes.Kind.PIZZA_SHOP, CityTypes.Kind.BURGER_SHOP,
	CityTypes.Kind.TANK, CityTypes.Kind.BOAT,
]


static func replacement(label: String) -> String:
	return String(REPLACED.get(label, ""))


static func is_deleted(label: String) -> bool:
	return DELETED.has(label)


## The vehicle id to draw for `id`: itself, another one, or "" when it is gone.
static func vehicle(id: String) -> String:
	if VEHICLE_DELETED.has(id):
		return ""
	return String(VEHICLE_REPLACED.get(id, id))
