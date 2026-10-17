class_name MapRequests
extends RefCounted
## Hand requests on the finished Chat City, run just before FaceRoads:
##   - DELETED: buildings taken away (by number, checked against their kind);
##   - B-00591's orange shop drawn with the business pack shop;
##   - every boat and submarine at sea taken away (the oil rig stays);
##   - the free ground of the suburban zone filled with houses, that of the red district (Zone.QUARTER)
##     with quarter buildings (FaceRoads then turns them and moves them up to a road, or drops them);
##   - after FaceRoads (`after_roads`): the shops of TO_BUSINESS_SHOP drawn with the business pack shop,
##     COPIES (a building made a copy of another one, both facing east), the orange shops (shop-general-orange-b-unlit) drawn as Kenney
##     houses (ORANGE_B_TO), and every house of the suburban zone without a model of its own is drawn
##     with one of the Kenney building-type houses, all of them in turn.
## New buildings go at the end of the list, so no number of an older building changes.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

## [building number, Kind name] taken away (the cafe and the restaurant of the business pack).
const DELETED := [[474, "CAFE"], [440, "RESTAURANT"]]
## [building number, model it had, model it gets].
const MODEL_SWAPS := [[591, "shop:shop-general-orange-a-unlit", "business.glb: shop"]]
## Shops of the catalog drawn with the business pack shop instead (after FaceRoads).
const TO_BUSINESS_SHOP := ["shop:shop-general-mini-unlit", "shop:shop-flower-a-unlit", "shop:shop-general-orange-a-unlit",
	"shop:shop-general-orange-b-unlit"]
const BUSINESS_SHOP := "business.glb: shop"
## [building number, its Kind name, building number of the copy]: the building becomes a copy of the other
## one (kind, model, size factors), facing COPY_FACING, and so does the original.
const COPIES := [[1054, "BURGER_KING", 1061]]
const COPY_FACING := 1
const ORANGE_B := "shop:shop-general-orange-b-unlit"
const ORANGE_B_TO := ["building-type-b.glb", "building-type-k.glb", "building-type-a.glb"]
## The Kenney houses of the suburban fill (building-type-f and -l are drawn as -n and -s, ModelCatalog).
const HOUSE_MODELS := ["building-type-a.glb", "building-type-b.glb", "building-type-c.glb",
	"building-type-d.glb", "building-type-e.glb", "building-type-g.glb", "building-type-h.glb",
	"building-type-i.glb", "building-type-j.glb", "building-type-k.glb", "building-type-m.glb",
	"building-type-n.glb", "building-type-o.glb", "building-type-p.glb", "building-type-q.glb",
	"building-type-r.glb", "building-type-s.glb", "building-type-t.glb", "building-type-u.glb"]
const HOUSE_LOT := Vector2i(2, 2)
const QUARTER_LOTS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 2)]
## Boats that stay (not a boat: the oil rig stands on the sea as a BOAT).
const BOAT_KEPT := [PortRework.OIL_RIG]

## Number of the first building the fill added (read by the tests).
static var added_from := -1


static func apply(data: CityData) -> Dictionary:
	var out := {"deleted": 0, "swapped": 0, "boats": 0}
	for d in DELETED:
		var b: int = d[0]
		if b < data.building_count() and data.b_kind[b] == Kind[d[1]]:
			data.b_kind[b] = Kind.EMPTY
			out["deleted"] += 1
		else:
			push_warning("[Requests] B-%05d is not a %s" % [b, d[1]])
	for s in MODEL_SWAPS:
		var b: int = s[0]
		if b < data.building_count() and data.b_model.get(b, "") == s[1]:
			_set_model(data, b, s[2])
			_unflip(data, b)
			out["swapped"] += 1
		else:
			push_warning("[Requests] B-%05d is not drawn with %s" % [b, s[1]])
	for b in data.building_count():
		if data.b_kind[b] == Kind.BOAT and not BOAT_KEPT.has(data.b_model.get(b, "")):
			data.b_kind[b] = Kind.EMPTY
			out["boats"] += 1
	added_from = data.building_count()
	out["houses"] = _fill(data, Zone.SUBURBAN, [HOUSE_LOT], Kind.HOUSE)
	out["quarter"] = _fill(data, Zone.QUARTER, QUARTER_LOTS, Kind.QUARTER_BLDG)
	return out


## The orange shops drawn as Kenney houses (they keep the place FaceRoads gave them), and the houses of
## the suburban zone drawn with the building-type models. Returns {"orange_shops": n, "houses": n}.
static func after_roads(data: CityData) -> Dictionary:
	var shops := 0
	var business := 0
	for b in data.building_count():
		if data.b_kind[b] != Kind.EMPTY and TO_BUSINESS_SHOP.has(data.b_model.get(b, "")):
			_set_model(data, b, BUSINESS_SHOP)
			_unflip(data, b)
			business += 1
		elif data.b_kind[b] != Kind.EMPTY and data.b_model.get(b, "") == ORANGE_B:
			_set_model(data, b, ORANGE_B_TO[shops % ORANGE_B_TO.size()])
			_unflip(data, b)
			shops += 1
	var n := 0
	for b in data.building_count():
		if data.b_kind[b] != Kind.HOUSE or data.b_model.has(b) or data.b_sign[b] != 0:
			continue
		var p := data.building_rect(b).position
		if data.zone[data.idx(p.x, p.y)] == Zone.SUBURBAN:
			data.b_model[b] = HOUSE_MODELS[n % HOUSE_MODELS.size()]
			n += 1
	var copies := 0
	for c in COPIES:
		var b: int = c[0]
		var src: int = c[2]
		if b >= data.building_count() or data.b_kind[b] != Kind[c[1]]:
			push_warning("[Requests] B-%05d is not a %s" % [b, c[1]])
			continue
		data.b_kind[b] = data.b_kind[src]
		data.b_model[b] = data.b_model.get(src, "")
		# Same size as the original although the lot is bigger (models fill their lot).
		var rb := data.building_rect(b).size
		var rs := data.building_rect(src).size
		var f := 1.0 if data.b_scale[src] < 0.0 else float(mini(rs.x, rs.y)) / float(mini(rb.x, rb.y))
		data.b_scale[b] = data.b_scale[src] * f
		data.b_stretch[b] = data.b_stretch[src]
		data.b_height[b] = data.b_height[src]
		data.b_facing[b] = COPY_FACING
		data.b_facing[src] = COPY_FACING
		copies += 1
	return {"orange_shops": shops, "business_shops": business, "houses": n, "copies": copies}


## A shop of the catalog is modelled the other way round (b_facing is the opposite of its front):
## drawn with another model, its front turns back to the road.
static func _unflip(data: CityData, b: int) -> void:
	data.b_facing[b] = (int(data.b_facing[b]) + 2) % 4


static func _set_model(data: CityData, b: int, model: String) -> void:
	data.b_model[b] = model
	data.b_scale[b] = 1.0
	data.b_stretch[b] = 1.0


## New buildings of `kind` on the free lots of `zone` with a road at most FaceRoads.REACH cells away
## (facing the road beside them, else south). Returns how many were added.
static func _fill(data: CityData, zone: int, sizes: Array[Vector2i], kind: int) -> int:
	var free := {}
	for y in range(data.size):
		for x in range(data.size):
			var i := data.idx(x, y)
			if data.zone[i] == zone and data.terrain[i] == CityTypes.Terrain.LAND and data.road[i] == 0 \
					and data.deco[i] == 0:
				free[i] = true
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.in_bounds(x, y):
					free.erase(data.idx(x, y))
	var n := 0
	for size in sizes:
		for h in ManualEdits._free_rects(data, free, size):
			var lot: Rect2i = h[0]
			if not _road_near(data, lot):
				continue
			var side := _road_side(data, lot)
			var facing := side if side >= 0 else 2
			var seed := CityTypes.hash2(lot.position.x, lot.position.y, 4421 + zone)
			var b := data.add_building(lot, kind, facing, seed, 0.4)
			for y in range(lot.position.y, lot.end.y):
				for x in range(lot.position.x, lot.end.x):
					var i := data.idx(x, y)
					free.erase(i)
					data.forest[i] = 0
			n += 1
	return n


## Side of `lot` with a road right beside it all along (south, east, west, then north), or -1.
static func _road_side(data: CityData, lot: Rect2i) -> int:
	for side in [2, 1, 3, 0]:
		var ok := true
		var cells := []
		match side:
			0: for x in range(lot.position.x, lot.end.x): cells.append(Vector2i(x, lot.position.y - 1))
			2: for x in range(lot.position.x, lot.end.x): cells.append(Vector2i(x, lot.end.y))
			1: for y in range(lot.position.y, lot.end.y): cells.append(Vector2i(lot.end.x, y))
			3: for y in range(lot.position.y, lot.end.y): cells.append(Vector2i(lot.position.x - 1, y))
		for c: Vector2i in cells:
			if not data.in_bounds(c.x, c.y) or data.road[data.idx(c.x, c.y)] == 0:
				ok = false
		if ok:
			return side
	return -1


## True when a road is at most FaceRoads.REACH cells from `lot` on some side.
static func _road_near(data: CityData, lot: Rect2i) -> bool:
	var g := lot.grow(FaceRoads.REACH)
	for y in range(g.position.y, g.end.y):
		for x in range(g.position.x, g.end.x):
			if data.in_bounds(x, y) and data.road[data.idx(x, y)] != 0:
				return true
	return false
