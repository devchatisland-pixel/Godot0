class_name ModelPools
extends RefCounted
## Decides which family of models a building is drawn from, so the districts
## mix the kits without looking random:
##   downtown   Kenney towers outside, photo towers in the dense middle
##   commercial Kenney mid-rise, New York street buildings, cartoon shops
##   Las Vegas  neon clubs, cartoon diners and cafes
##   apartments Kenney blocks, New York brick buildings, a panel block
##   quarter    the white and red low-poly town, with French houses and villas mixed in
##   suburbs    Kenney houses, colourful cartoon houses, French red and blue houses
##   poor       grey panel blocks and slabs, garages; one big Russian block
##   industrial Kenney factories, the big brick works and the concrete factory
## Every choice comes from the building seed: deterministic and thread safe.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Cat := ModelCatalog.Cat

## Kenney commercial models taller than this are offices, lower ones shops.
const OFFICE_MIN_HEIGHT := 1.6

## Share of the cartoon shops that are pizzerias.
const PIZZA_SHARE := 0.01

## Share of lots drawn from the extra house and town packs (HOUSE2, TOWN2), per zone.
const HOUSE2_SHARE := {Zone.SUBURBAN: 0.5, Zone.APARTMENT: 0.4, Zone.QUARTER: 0.45}
const SHOP2_SHARE := {Zone.SUBURBAN: 0.45, Zone.APARTMENT: 0.35, Zone.COMMERCIAL: 0.2, Zone.POOR: 0.6}

## Share of shops drawn from the cartoon business pack, per zone.
const BIZ_SHOP_SHARE := {
	Zone.ENTERTAINMENT: 0.45, Zone.COMMERCIAL: 0.25, Zone.SUBURBAN: 0.35, Zone.APARTMENT: 0.2,
}


static func candidates(data: CityData, lib: ModelLibrary, i: int, kind: int) -> PackedInt32Array:
	var seed: int = data.b_seed[i]
	var roll := float((seed >> 12) & 1023) / 1024.0
	var r := data.building_rect(i)
	var zone: int = data.zone[data.idx(r.position.x, r.position.y)]
	match kind:
		Kind.SKYSCRAPER:
			# Photo-real towers gather in the middle of downtown.
			var photo := 0.25 + 0.5 * float(data.b_height[i])
			return _pick(lib, Cat.TOWER_PHOTO, roll < photo, lib.ids(Cat.SKYSCRAPER))
		Kind.OFFICE:
			if roll > 0.88 and zone == Zone.COMMERCIAL and lib.has_cat(Cat.HOTEL_SMALL):
				return lib.ids(Cat.HOTEL_SMALL) # little hotels among the offices
			var ny := _union(lib, [Cat.NY_STREET, Cat.NY_MIDRISE])
			return ny if roll < 0.3 and not ny.is_empty() else _kenney_commercial(lib, kind)
		Kind.SHOP:
			if roll > 0.5 and lib.has_cat(Cat.SHOP2) and float((seed >> 22) & 255) / 256.0 < SHOP2_SHARE.get(zone, 0.0):
				return lib.ids(Cat.SHOP2)
			var share: float = BIZ_SHOP_SHARE.get(zone, 0.0)
			if roll < share and lib.has_cat(Cat.BIZ_SHOP):
				# Half of the cartoon restaurants and shops are replaced by normal (Kenney) shops.
				if (seed >> 9) & 1 == 0:
					return _kenney_commercial(lib, kind)
				# Pizzerias stay rare: about one cartoon shop in a hundred.
				if roll < share * PIZZA_SHARE and lib.has_cat(Cat.BIZ_PIZZA):
					return lib.ids(Cat.BIZ_PIZZA)
				return lib.ids(Cat.BIZ_SHOP)
			if zone == Zone.COMMERCIAL and roll < share + 0.15 and lib.has_cat(Cat.NY_STREET):
				return lib.ids(Cat.NY_STREET)
			return _kenney_commercial(lib, kind)
		Kind.APARTMENT:
			if roll < 0.12 and lib.has_cat(Cat.PANEL):
				return lib.ids(Cat.PANEL)
			if roll > 0.7 and lib.has_cat(Cat.TOWN2):
				return lib.ids(Cat.TOWN2)
			return _pick(lib, Cat.NY_MIDRISE, roll < 0.35, _kenney_commercial(lib, kind))
		Kind.HOUSE:
			if lib.has_cat(Cat.HOUSE2) and roll < HOUSE2_SHARE.get(zone, 0.3):
				return lib.ids(Cat.HOUSE2)
			return lib.ids(Cat.HOUSE)
		Kind.INDUSTRIAL:
			return _industrial(lib, roll, r)
		Kind.POOR_BLDG:
			return _poor(lib, roll, r)
		Kind.RUSSIAN:
			return lib.ids(Cat.RUSSIAN)
		Kind.URBAN_BLDG:
			return lib.ids(Cat.URBAN)
		Kind.FUTURE_BLDG:
			return lib.ids(Cat.FUTURE)
		Kind.PIRATE_SHIP:
			return lib.ids(Cat.PIRATE_SHIP)
		Kind.NUCLEAR_PLANT:
			return lib.ids(Cat.NUCLEAR)
		Kind.CINEMA_MAIN:
			return lib.ids(Cat.CINEMA2)
		Kind.AIRPORT:
			return lib.ids(Cat.AIRPORT)
		Kind.BURGER_JOINT:
			return lib.ids(Cat.BURGER_JOINT)
		Kind.URBAN_CLUSTER:
			return _variant_of(_union(lib, [Cat.SKYLINE, Cat.SKYLINE2]), seed)
		Kind.MCDONALDS:
			return lib.ids(Cat.MCDONALDS)
		Kind.BURGER_KING:
			return lib.ids(Cat.BURGER_KING)
		Kind.HOTEL:
			return _variant_of(_union(lib, [Cat.HOTEL_PACK, Cat.HOTEL_SMALL]), seed)
		Kind.FACTORY_BLDG:
			return _variant_of(_eight_factories(lib), seed)
		Kind.PRISON_WING:
			return _variant(lib, _prison_cat(lib, seed), seed)
		Kind.STALL:
			return _variant(lib, Cat.STALL, seed)
		Kind.BANK:
			return lib.ids(Cat.BANK_PACK)
		Kind.CHURCH:
			return lib.ids(Cat.CHURCH_PACK)
		Kind.MUSEUM:
			return _variant(lib, Cat.MUSEUM_PACK, seed)
		Kind.GAS_STATION:
			return lib.ids(Cat.GAS_STATION) if roll < 0.5 or not lib.has_cat(Cat.GAS_PACK) else lib.ids(Cat.GAS_PACK)
		Kind.QUARTER_BLDG:
			return _quarter(lib, r, roll)
		Kind.LANDMARK:
			return _variant(lib, Cat.LANDMARK, seed)
		Kind.OUTPOST:
			return _variant(lib, Cat.OUTPOST, seed)
		Kind.SHOPPING_CENTER:
			return lib.ids(Cat.MALL)
		Kind.CINEMA:
			return lib.ids(Cat.CINEMA)
		# Models from the packs replace the procedural ones when present.
		Kind.POLICE_HQ:
			return lib.ids(Cat.POLICE_MAIN)
		Kind.CITY_HALL:
			return lib.ids(Cat.CITY_HALL_MAIN)
		Kind.MAIN_HOSPITAL:
			return lib.ids(Cat.HOSPITAL_MAIN)
		Kind.MAIN_SCHOOL:
			return lib.ids(Cat.SCHOOL_MAIN)
		Kind.PHARMACY:
			return lib.ids(Cat.PHARMACY)
		Kind.GAS_STATION:
			return lib.ids(Cat.GAS_STATION)
		Kind.UN_HQ:
			return lib.ids(Cat.UN_TOWER)
		Kind.CRANE:
			return lib.ids(Cat.CRANE)
		Kind.STADIUM:
			return lib.ids(Cat.STADIUM)
	return PackedInt32Array()


## Low houses on small lots, mid-rise on big ones, a few towers here and there.
static func _quarter(lib: ModelLibrary, r: Rect2i, roll: float) -> PackedInt32Array:
	# French villas, red and blue, and colourful town houses break the white and red.
	if roll > 0.62 and lib.has_cat(Cat.HOUSE2) and r.get_area() <= 6:
		return lib.ids(Cat.HOUSE2)
	if roll > 0.78 and lib.has_cat(Cat.TOWN2):
		return lib.ids(Cat.TOWN2)
	if roll > 0.94 and lib.has_cat(Cat.HOTEL_SMALL):
		return lib.ids(Cat.HOTEL_SMALL)
	var cat := Cat.QUARTER_LOW
	if roll < 0.1:
		cat = Cat.QUARTER_TALL
	elif r.get_area() >= 6 or roll < 0.4:
		cat = Cat.QUARTER_MID
	for c in [cat, Cat.QUARTER_MID, Cat.QUARTER_LOW]:
		if lib.has_cat(c):
			return lib.ids(c)
	return lib.ids(Cat.HOUSE)


## Factories: the Kenney kit, the big concrete factory, the brick works, garages.
static func _industrial(lib: ModelLibrary, roll: float, r: Rect2i) -> PackedInt32Array:
	if r.get_area() >= 12 and roll < 0.5 and lib.has_cat(Cat.FACTORY):
		return lib.ids(Cat.FACTORY)
	if roll > 0.93 and lib.has_cat(Cat.WAREHOUSE):
		return lib.ids(Cat.WAREHOUSE)
	if roll > 0.8 and r.get_area() >= 6 and lib.has_cat(Cat.RUIN):
		return lib.ids(Cat.RUIN)
	return lib.ids(Cat.INDUSTRIAL)


## The 8 different buildings of the industrial zone: the concrete factory, the
## brick works, the ruin, a garage and four Kenney factories.
static func _eight_factories(lib: ModelLibrary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.append_array(lib.ids(Cat.FACTORY))
	out.append_array(lib.ids(Cat.RUIN))
	out.append_array(lib.ids(Cat.WAREHOUSE))
	var kit := lib.ids(Cat.INDUSTRIAL)
	for i in range(0, kit.size(), maxi(1, kit.size() / 4)):
		if out.size() >= 8:
			break
		out.append(kit[i])
	return out


static func _variant_of(ids: PackedInt32Array, seed: int) -> PackedInt32Array:
	if ids.is_empty():
		return ids
	return PackedInt32Array([ids[absi(seed) % ids.size()]])


## Panel towers and slabs, garages and corner shops of the poor district.
static func _poor(lib: ModelLibrary, roll: float, r: Rect2i) -> PackedInt32Array:
	if r.get_area() >= 8 and roll < 0.25 and lib.has_cat(Cat.POOR_SLAB):
		return lib.ids(Cat.POOR_SLAB)
	if roll > 0.92 and lib.has_cat(Cat.WAREHOUSE):
		return lib.ids(Cat.WAREHOUSE)
	if lib.has_cat(Cat.POOR_BLOCK):
		return lib.ids(Cat.POOR_BLOCK)
	return lib.ids(Cat.PANEL)


## Stone blocks, villas or the workshop of the prison island, by seed.
static func _prison_cat(lib: ModelLibrary, seed: int) -> int:
	var cats := [Cat.PRISON_BLOCK, Cat.MANSION, Cat.PRISON_BLOCK, Cat.RUIN]
	for k in cats.size():
		var c: int = cats[(absi(seed) + k) % cats.size()]
		if lib.has_cat(c):
			return c
	return Cat.PRISON_BLOCK


static func _kenney_commercial(lib: ModelLibrary, kind: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in lib.ids(Cat.COMMERCIAL):
		var h := lib.bounds[id].size.y
		var tall := h >= OFFICE_MIN_HEIGHT
		if (kind == Kind.SHOP and not tall) or (kind == Kind.OFFICE and tall) \
				or (kind == Kind.APARTMENT and h > 1.2 and h < 2.4):
			out.append(id)
	return out if not out.is_empty() else lib.ids(Cat.COMMERCIAL)


## `cat` when `use` is true and the category exists, else `fallback`.
static func _pick(lib: ModelLibrary, cat: int, use: bool, fallback: PackedInt32Array) -> PackedInt32Array:
	return lib.ids(cat) if use and lib.has_cat(cat) else fallback


static func _union(lib: ModelLibrary, cats: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in cats:
		out.append_array(lib.ids(c))
	return out


## One fixed model: unique buildings keep their variant index in the seed.
static func _variant(lib: ModelLibrary, cat: int, seed: int) -> PackedInt32Array:
	var ids := lib.ids(cat)
	if ids.is_empty():
		return ids
	return PackedInt32Array([ids[absi(seed) % ids.size()]])


static func is_photo_tower(lib: ModelLibrary, id: int) -> bool:
	return lib.ids(Cat.TOWER_PHOTO).has(id)


static func is_pack_model(lib: ModelLibrary, id: int, cat: int) -> bool:
	return lib.ids(cat).has(id)


## New York pack buildings are drawn taller than the Kenney kit around them.
static func is_new_york(lib: ModelLibrary, id: int) -> bool:
	return lib.ids(Cat.NY_STREET).has(id) or lib.ids(Cat.NY_MIDRISE).has(id)
