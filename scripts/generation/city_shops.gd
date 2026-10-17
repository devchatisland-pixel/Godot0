class_name CityShops
extends RefCounted
## The orange shop (shop-general-orange-b-unlit of res://shops, at its normal size),
## standing in the streets of Chat City: 40 in the commercial, suburban and apartment zones, 80
## in the quarter zone (a few in the poor one), none in the others. A shop takes a vacant lot
## or replaces a house, shop or block of the zone; they are spread evenly, never in clusters.
## Each shop is a real building of the city (Kind.SHOP with the model "shop:<id>").

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

const SHOP_ID := "shop-general-orange-b-unlit"
## 60% of the shops (by the hash of their place) are one of these three instead, a third each.
const OTHER_IDS := ["shop-general-mini-unlit", "shop-flower-a-unlit", "shop-general-orange-a-unlit"]
const OTHER_SHARE := 60
## Every shop id of the city, the main one first.
const ALL_IDS := ["shop-general-orange-b-unlit", "shop-general-mini-unlit", "shop-flower-a-unlit", "shop-general-orange-a-unlit"]
## Absolute scale of the shop (cells per metre of its model): its normal size.
## Zone -> number of shops.
const QUOTA := {
	Zone.COMMERCIAL: 40, Zone.SUBURBAN: 40, Zone.APARTMENT: 40, Zone.QUARTER: 80, Zone.POOR: 5,
	Zone.CIVIC: 20,
}
## Kinds of lot that become a shop (a vacant lot costs nothing, the others lose their model).
const REPLACED := [Kind.EMPTY, Kind.SHOP, Kind.HOUSE, Kind.QUARTER_BLDG, Kind.APARTMENT, Kind.OFFICE]


## Puts the shops, spread evenly over each zone: every new shop is the free lot farthest from
## the ones already put there (vacant lots are taken before the others at equal distance).
## Returns {zone name: shops put}.
## Catalog id of the shop standing at (x, y): the main one, or (60%) one of the three others.
static func shop_id_at(x: int, y: int) -> String:
	var h := CityTypes.hash2(x, y, 6161)
	if h % 100 < OTHER_SHARE:
		return OTHER_IDS[(h / 100) % OTHER_IDS.size()]
	return SHOP_ID


static func apply(data: CityData) -> Dictionary:
	var by_zone := {}
	for zone in QUOTA:
		by_zone[zone] = []
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if not REPLACED.has(k):
			continue
		if data.b_model.has(b) or data.b_sign[b] != 0 or data.b_more_signs.has(b):
			continue
		var r := data.building_rect(b)
		var zone: int = data.zone_at(r.position.x, r.position.y)
		if not QUOTA.has(zone):
			continue
		var lo := mini(r.size.x, r.size.y)
		var hi := maxi(r.size.x, r.size.y)
		if lo < 2 or hi < 3 or lo > 5:
			continue
		(by_zone[zone] as Array).append(b)
	var placed := {}
	for zone in QUOTA:
		var list: Array = by_zone[zone]
		var n := list.size()
		var quota := mini(int(QUOTA[zone]), n)
		var centre := PackedVector2Array()
		var mind := PackedFloat32Array()
		for b: int in list:
			var r := data.building_rect(b)
			centre.append(Vector2(r.position) + Vector2(r.size) * 0.5)
			mind.append(INF)
		var used := PackedByteArray()
		used.resize(n)
		var count := 0
		var pick := -1
		# The first shop: the lot with the smallest hash, the next ones by distance.
		var best_hash := 0x7fffffff
		for i in n:
			var h := CityTypes.hash2(int(centre[i].x), int(centre[i].y), 5151)
			if h < best_hash:
				best_hash = h
				pick = i
		while count < quota and pick >= 0:
			used[pick] = 1
			var b: int = list[pick]
			var face := _street_facing(data, data.building_rect(b))
			if face < 0:
				face = data.b_facing[b]
			# Every candy shop looks south or east, like the one of the development island: the ones
			# that would face north face south, the ones that would face west face east.
			face = 2 if face == 0 else (1 if face == 3 else face)
			# The model's front is -Z: turn it the other way round so that it looks at the street.
			data.b_kind[b] = Kind.SHOP
			data.b_facing[b] = (face + 2) % 4
			var at := data.building_rect(b).position
			data.b_model[b] = "shop:" + shop_id_at(at.x, at.y)
			data.b_scale[b] = -ShopSites.scale_of(String(data.b_model[b]).trim_prefix("shop:"))
			data.b_stretch[b] = ShopSites.stretch_of(String(data.b_model[b]).trim_prefix("shop:"))
			count += 1
			# Next: the free lot farthest from the shops of this zone (vacant lots get a bonus).
			var c := centre[pick]
			var best := -1.0
			pick = -1
			for i in n:
				if used[i] != 0:
					continue
				mind[i] = minf(mind[i], c.distance_to(centre[i]))
				var score := mind[i] + (3.0 if data.b_kind[list[i]] == Kind.EMPTY else 0.0)
				if score > best:
					best = score
					pick = i
		# Not enough lots to convert: shops on free ground of the zone, beside a street.
		if count < int(QUOTA[zone]):
			count += _on_free_ground(data, zone, int(QUOTA[zone]) - count)
		placed[Zone.keys()[zone]] = count
	return placed


## Up to `want` shops on free 5 x 3 ground of `zone` (no road, building or path), long side
## along a street, spread by the hash of their corner. Returns how many were put.
static func _on_free_ground(data: CityData, zone: int, want: int) -> int:
	var n := data.size
	var used := PackedByteArray()
	used.resize(n * n)
	for b in data.building_count():
		if data.b_kind[b] == Kind.PLAZA or data.b_kind[b] == Kind.GARDEN:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				used[y * n + x] = 1
	var found: Array = []
	for y in range(1, n - 6):
		for x in range(1, n - 6):
			if data.zone[y * n + x] != zone:
				continue
			for horizontal in [true, false]:
				var w := 5 if horizontal else 3
				var h := 3 if horizontal else 5
				if not _free(data, used, x, y, w, h, zone):
					continue
				var face := _street_side(data, x, y, w, h, horizontal)
				if face >= 0:
					found.append([x, y, w, h, face])
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return CityTypes.hash2(a[0], a[1], 5353) < CityTypes.hash2(b[0], b[1], 5353))
	var count := 0
	var taken: Array[Vector2i] = []
	for c in found:
		if count >= want:
			break
		var rect := Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
		var at := rect.position + rect.size / 2
		var far := true
		for t in taken:
			if absi(t.x - at.x) < 5 and absi(t.y - at.y) < 5:
				far = false
				break
		var clear := true
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if used[y * n + x] != 0:
					clear = false
		if not far or not clear:
			continue
		var face := int(c[4])
		face = 2 if face == 0 else (1 if face == 3 else face)
		var b := data.add_building(rect, Kind.SHOP, (face + 2) % 4,
				CityTypes.hash2(rect.position.x, rect.position.y, 5252), 0.3)
		data.b_model[b] = "shop:" + shop_id_at(rect.position.x, rect.position.y)
		data.b_scale[b] = -ShopSites.scale_of(String(data.b_model[b]).trim_prefix("shop:"))
		data.b_stretch[b] = ShopSites.stretch_of(String(data.b_model[b]).trim_prefix("shop:"))
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				used[y * n + x] = 1
		taken.append(at)
		count += 1
	return count


static func _free(data: CityData, used: PackedByteArray, x: int, y: int, w: int, h: int, zone: int) -> bool:
	var n := data.size
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var i := yy * n + xx
			if used[i] != 0 or data.road[i] != 0 or data.zone[i] != zone or not data.is_land(xx, yy):
				return false
			if data.deco[i] != 0 or data.terrain[i] != CityTypes.Terrain.LAND:
				return false
	return true


## Facing (0 N, 1 E, 2 S, 3 W) of the street that runs along a long side of the lot, or -1.
static func _street_side(data: CityData, x: int, y: int, w: int, h: int, horizontal: bool) -> int:
	if horizontal:
		var north := 0
		var south := 0
		for xx in range(x, x + w):
			if data.is_road(xx, y - 1):
				north += 1
			if data.is_road(xx, y + h):
				south += 1
		if north >= w - 1 and north >= south:
			return 0
		if south >= w - 1:
			return 2
		return -1
	var west := 0
	var east := 0
	for yy in range(y, y + h):
		if data.is_road(x - 1, yy):
			west += 1
		if data.is_road(x + w, yy):
			east += 1
	if west >= h - 1 and west >= east:
		return 3
	if east >= h - 1:
		return 1
	return -1


## Facing (0 N, 1 E, 2 S, 3 W) of the side of lot `r` that has the most street cells along it, or -1.
static func _street_facing(data: CityData, r: Rect2i) -> int:
	var count := [0, 0, 0, 0]
	for x in range(r.position.x, r.end.x):
		if data.is_road(x, r.position.y - 1):
			count[0] += 1
		if data.is_road(x, r.end.y):
			count[2] += 1
	for y in range(r.position.y, r.end.y):
		if data.is_road(r.end.x, y):
			count[1] += 1
		if data.is_road(r.position.x - 1, y):
			count[3] += 1
	var best := -1
	var best_n := 0
	for f in 4:
		if count[f] > best_n:
			best_n = count[f]
			best = f
	return best
