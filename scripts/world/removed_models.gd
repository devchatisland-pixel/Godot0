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
}


static func has(name: String) -> bool:
	return NAMES.has(name)
