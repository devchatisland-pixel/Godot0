class_name CityShops
extends RefCounted
## The candy shop (shop-candy-b of res://shops), the same model as the fog island's shops,
## standing in the streets of Chat City: 40 in the commercial, suburban and apartment zones, 80
## in the quarter zone (a few in the poor one), none in the others. A shop takes a vacant lot
## or replaces a house, shop or block of the zone; they are spread evenly, never in clusters.
## Each shop is a real building of the city (Kind.SHOP with the model "shop:<id>").

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

const SHOP_ID := "shop-candy-b"
## Absolute scale of the shop (cells per metre of its model): the same as on the fog island.
const SHOP_SCALE := 0.68
## Zone -> number of shops.
const QUOTA := {
	Zone.COMMERCIAL: 40, Zone.SUBURBAN: 40, Zone.APARTMENT: 40, Zone.QUARTER: 80, Zone.POOR: 5,
}
## Kinds of lot that become a shop (a vacant lot costs nothing, the others lose their model).
const REPLACED := [Kind.EMPTY, Kind.SHOP, Kind.HOUSE, Kind.QUARTER_BLDG, Kind.APARTMENT, Kind.OFFICE]


## Puts the shops, spread evenly over each zone: every new shop is the free lot farthest from
## the ones already put there (vacant lots are taken before the others at equal distance).
## Returns {zone name: shops put}.
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
			# The model's front is -Z: turn it the other way round so that it looks at the street.
			data.b_kind[b] = Kind.SHOP
			data.b_facing[b] = (face + 2) % 4
			data.b_model[b] = "shop:" + SHOP_ID
			data.b_scale[b] = -SHOP_SCALE
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
		placed[Zone.keys()[zone]] = count
	return placed


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
