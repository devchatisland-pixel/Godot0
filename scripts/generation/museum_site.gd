class_name MuseumSite
extends RefCounted
## The museum: the city hall of Utrecht (curated pack museum_hall, category MUSEUM_HALL), one of it
## on the biggest free square of grass near the shop at SHOP_AT, its front towards the east.
## Added at the very end of the building list, so that no number of an older building changes.
## Nothing is random: the order of the sizes and the distance decide.

const Kind := CityTypes.Kind
const Terrain := CityTypes.Terrain

const MODEL := "museum_hall.glb: museum_hall"
## Top-left cell of the lot of the shop (B-00645 of the map this was set up on) the museum stands near.
## The museum is drawn this much smaller than the lot allows.
const MODEL_SIZE := 0.7
const SHOP_AT := Vector2i(215, 203)
## Lots tried, biggest first (cells, x by y: the museum looks east, so its front is as deep as x).
const SIZES: Array[Vector2i] = [Vector2i(6, 7), Vector2i(6, 6), Vector2i(5, 6), Vector2i(5, 5), Vector2i(4, 5)]
## How far from the shop the square may be (cells).
const REACH := 14
const EAST := 1


## Returns the lot of the museum (empty when there is no room).
static func apply(data: CityData) -> Rect2i:
	var shop := -1
	for b in data.building_count():
		if data.b_kind[b] == Kind.SHOP and data.building_rect(b).position == SHOP_AT:
			shop = b
	if shop < 0:
		push_warning("[Museum] no shop at %s to stand near" % SHOP_AT)
		return Rect2i()
	var anchor := Vector2(data.building_rect(shop).get_center())
	for size in SIZES:
		var best := Rect2i()
		var best_d := INF
		for y in range(int(anchor.y) - REACH, int(anchor.y) + REACH + 1):
			for x in range(int(anchor.x) - REACH, int(anchor.x) + REACH + 1):
				var lot := Rect2i(x, y, size.x, size.y)
				var d := Vector2(lot.get_center()).distance_to(anchor)
				if d < best_d and _free(data, lot):
					best_d = d
					best = lot
		if best.size.x > 0:
			_build(data, best)
			print("[Museum] lot %s facing east" % best)
			return best
	push_warning("[Museum] no free square near %s" % SHOP_AT)
	return Rect2i()


static func _build(data: CityData, lot: Rect2i) -> void:
	var b := data.add_building(lot, Kind.MUSEUM, EAST, 0, 0.5)
	data.b_model[b] = MODEL
	data.b_scale[b] = MODEL_SIZE
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			data.forest[data.idx(x, y)] = 0


## True when every cell of `lot` is dry land with no road, no path or bench, and no standing building.
static func _free(data: CityData, lot: Rect2i) -> bool:
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if data.terrain[i] != Terrain.LAND or data.road[i] != 0 or data.deco[i] != 0:
				return false
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if k != Kind.EMPTY and k != Kind.BALLOON and data.building_rect(b).intersects(lot):
			return false
	return true
