class_name CityShops
extends RefCounted
## The candy shop (shop-candy-b of res://shops) in the free corners of the city streets: the
## same model as the fog island's shops, standing on a free 5 x 3 lot beside a street, its
## front to the street. Zones that get shops (and how many): the commercial, suburban and
## quarter zones and, in smaller numbers, the apartment, poor, urban and entertainment ones;
## nothing in the nature, farm, industrial, desert and downtown zones.
## Each shop is a real building of the city (Kind.SHOP with the model "shop:<id>"), so trees,
## roads and the streaming of chunks treat it like any other.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

const SHOP_ID := "shop-candy-b"
## Absolute scale of the shop (cells per metre of its model): the same as on the fog island.
const SHOP_SCALE := 0.68
## Lot of a shop: long side along the street.
const LONG := 5
const SHORT := 3
## Cells kept free of other shops round one (centre to centre, in cells).
const SPACING := 8
## Zone -> number of shops.
const QUOTA := {
	Zone.COMMERCIAL: 35, Zone.SUBURBAN: 35, Zone.QUARTER: 25, Zone.APARTMENT: 12,
	Zone.POOR: 5, Zone.URBAN: 5, Zone.ENTERTAINMENT: 3,
}


## Puts the shops: houses and shops of the zones above, on lots at least 3 cells long and 2
## wide, become the candy shop (the lot, its street and its number stay; the model changes).
## Returns {zone name: shops put}.
static func apply(data: CityData) -> Dictionary:
	var by_zone := {}
	for zone in QUOTA:
		by_zone[zone] = []
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if k != Kind.HOUSE and k != Kind.SHOP:
			continue
		if data.b_model.has(b) or data.b_sign[b] != 0 or data.b_more_signs.has(b):
			continue
		var r := data.building_rect(b)
		var zone: int = data.zone_at(r.position.x, r.position.y)
		if not QUOTA.has(zone):
			continue
		var lo := mini(r.size.x, r.size.y)
		var hi := maxi(r.size.x, r.size.y)
		if lo < 2 or hi < 3 or lo > 4:
			continue
		(by_zone[zone] as Array).append(b)
	var placed := {}
	var taken: Array[Vector2i] = []
	for zone in QUOTA:
		var list: Array = by_zone[zone]
		list.sort_custom(func(a: int, b: int) -> bool:
			var ra := data.building_rect(a).position
			var rb := data.building_rect(b).position
			return CityTypes.hash2(ra.x, ra.y, 5151) < CityTypes.hash2(rb.x, rb.y, 5151))
		var count := 0
		for b: int in list:
			if count >= int(QUOTA[zone]):
				break
			var r := data.building_rect(b)
			var at := r.position + r.size / 2
			var far := true
			for t in taken:
				if absi(t.x - at.x) < SPACING and absi(t.y - at.y) < SPACING:
					far = false
					break
			if not far:
				continue
			# The model's front is -Z: turn it the other way round so that it looks at the street.
			data.b_kind[b] = Kind.SHOP
			data.b_facing[b] = (data.b_facing[b] + 2) % 4
			data.b_model[b] = "shop:" + SHOP_ID
			data.b_scale[b] = -SHOP_SCALE
			taken.append(at)
			count += 1
		placed[Zone.keys()[zone]] = count
	return placed


