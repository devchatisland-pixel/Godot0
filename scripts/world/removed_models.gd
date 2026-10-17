class_name RemovedModels
extends RefCounted
## Models taken off the map by hand: a building, vehicle or prop drawn with one of these is not drawn
## (its lot stays empty). The development island keeps its shops (one of each, see ShopSites).
## Names as the library knows them ("pack.glb: node", "file.glb", "veh:<vehicle catalog id>").

const NAMES := {
	"carto.glb: house1": true, "carto.glb: town1": true, "carto.glb: town3": true, "carto.glb: town5": true,
	"carto.glb: town6": true, "carto.glb: town11": true, "carto.glb: bakery": true,
	"euro.glb: blue_house": true, "euro.glb: townhouse_b": true,
	"free_mini.glb: m2": true, "free_mini.glb: m3": true, "free_mini.glb: m5": true, "free_mini.glb: m9": true,
	"free_mini.glb: m10": true, "gas_station_night.glb: m11": true,
	"ny_buildings.glb: flatiron": true, "ny_buildings.glb: metlife": true, "ny_buildings.glb: ny_times": true,
	"ny_buildings.glb: one_wtc": true, "ny_buildings.glb: woolworth": true,
	"ny_buildings.glb: ny_glass_2": true, "ny_buildings.glb: ny_glass_3": true, "ny_buildings.glb: ny_glass_4": true,
	"ny_street.glb: ny_street_01_b": true,
	"outpost.glb: truck": true, "outpost.glb: trailer_a": true, "outpost.glb: ranch_a": true,
	"building-m.glb": true, "business.glb: burger": true, "business.glb: pizza": true,
	"tank.glb: tank": true,
	"towers_a.glb: towers_a_11_b": true, "towers_a.glb: towers_a_46_b": true,
	"towers_a_17_b.glb: towers_a_17_b": true, "towers_a_33_b.glb: towers_a_33_b": true,
	"towers_a_51_b.glb: towers_a_51_b": true,
	"supermarket.glb: supermarket": true,
	"army_apc.glb: apc_bmp1": true, "army_apc.glb: apc_ee11_aa": true, "camp_radar.glb: camp_radar": true,
	"base_hall.glb: base_hall": true, "camp_tent_medical.glb: camp_tent_medical": true,
	"port_sheds.glb: shed_generic_4": true, "nuclear2.glb: nuclear2": true,
	"street.glb: shop_coffee": true, "accommodations.glb: flat10": true,
	"quarter.glb: quarter_13_b": true, "quarter.glb: quarter_19_b": true, "quarter.glb: quarter_21_b": true,
	"quarter.glb: quarter_24_b": true, "quarter.glb: quarter_52_b": true,
	"oil_rig.glb: oil_rig": true,
	"veh:police_us_cruiser": true, "veh:school_bus": true, "veh:p54_24_sedan_hardtop_teal": true,
	"veh:p54_12_wreck_chassis": true, "veh:p54_26_pickup_40s_red": true, "veh:p54_15_dump_truck_yellow": true,
	"veh:p54_07_box_truck_delivery_yellow": true, "veh:p54_35_crane_truck_mobile": true,
	"veh:humvee_sand": true, "veh:police_jp_black": true,
	# The second list (audit of the models used once or twice).
	"fog_city.glb: fog_office_tower": true, "fog_city.glb: fog_house": true,
	"vegas_casino.glb: casino_building": true, "fog_market.glb: fog_market": true,
	"port_tanks.glb: factory_brick": true, "port_tanks.glb: tank_long": true, "port_towers.glb: tower_tank_4": true,
	"outpost.glb: barrack_a": true, "accommodations.glb: flat8": true,
	"free_mini.glb: m1": true, "free_mini.glb: m7": true, "free_mini.glb: m8": true,
	"carto.glb: town7": true, "carto.glb: town8": true, "carto.glb: town10": true, "carto.glb: house2": true,
	"carto.glb: cone": true, "euro.glb: townhouse_c": true,
	"hotel_stars_night.glb: hotel_stars": true, # drawn as hotel_small (REPLACED)
	"veh:humvee_grey": true, "veh:jeep_willys": true, "veh:p54_11_ambulance": true, "veh:p54_18_tanker_fuel": true,
	"veh:p54_04_sedan_modern_silver": true, "veh:p54_02_van_conversion_white": true,
	"veh:p54_01_suv_offroad_navy": true, "veh:m8_wagon_blue": true, "veh:m8_wagon_teal": true,
	"veh:m8_long_sedan_black": true, "veh:m8_long_sedan_charcoal": true, "veh:m8_long_sedan_silver": true,
	"veh:m8_sedan_dark_red": true, "veh:m8_sedan_mustard": true, "veh:m8_pickup_blue": true,
}

## Models drawn as another model instead (their own mesh is never drawn): name -> name.
const REPLACED := {
	"hotel_stars_night.glb: hotel_stars": "hotel_small_night.glb: hotel_small",
}

## The unlit copies of the catalog shops (res://shops) drawn as the business pack shop instead, wherever they
## stand: in the city (MapRequests), on the fog island (FogBase); the development island does not show them.
const SHOPS_AS_BUSINESS := ["shop-flower-a-unlit", "shop-general-orange-a-unlit", "shop-general-orange-b-unlit", "shop-general-mini-unlit"]
const BUSINESS_SHOP := "business.glb: shop"


static func has(name: String) -> bool:
	return NAMES.has(name)


## The name `name` is drawn as (itself when it is not replaced).
static func replacement(name: String) -> String:
	return String(REPLACED.get(name, name))


## `ids` with every replaced model swapped for the model that stands in for it.
static func swap_ids(lib: ModelLibrary, ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		var target := String(REPLACED.get(lib.model_name(id), ""))
		var tid := lib.names.find(target) if target != "" else -1
		out.append(tid if tid >= 0 else id)
	return out
