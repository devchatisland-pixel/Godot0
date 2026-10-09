class_name ModelPools
extends RefCounted
## Decides which family of models a building is drawn from, so the districts
## mix the kits without looking random:
##   downtown   Kenney towers outside, photo towers in the dense middle
##   commercial Kenney mid-rise, New York street buildings, cartoon shops
##   Las Vegas  neon clubs, cartoon diners and cafes
##   apartments Kenney blocks, New York brick buildings, a panel block
##   quarter    the white and red low-poly town
## Every choice comes from the building seed: deterministic and thread safe.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Cat := ModelCatalog.Cat

## Kenney commercial models taller than this are offices, lower ones shops.
const OFFICE_MIN_HEIGHT := 1.6

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
			var ny := _union(lib, [Cat.NY_STREET, Cat.NY_MIDRISE])
			return ny if roll < 0.3 and not ny.is_empty() else _kenney_commercial(lib, kind)
		Kind.SHOP:
			var share: float = BIZ_SHOP_SHARE.get(zone, 0.0)
			if roll < share and lib.has_cat(Cat.BIZ_SHOP):
				return lib.ids(Cat.BIZ_SHOP)
			if zone == Zone.COMMERCIAL and roll < share + 0.15 and lib.has_cat(Cat.NY_STREET):
				return lib.ids(Cat.NY_STREET)
			return _kenney_commercial(lib, kind)
		Kind.APARTMENT:
			if roll < 0.12 and lib.has_cat(Cat.PANEL):
				return lib.ids(Cat.PANEL)
			return _pick(lib, Cat.NY_MIDRISE, roll < 0.35, _kenney_commercial(lib, kind))
		Kind.HOUSE:
			return lib.ids(Cat.HOUSE)
		Kind.INDUSTRIAL:
			return lib.ids(Cat.INDUSTRIAL)
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
		Kind.POLICE:
			return lib.ids(Cat.POLICE)
		Kind.STADIUM:
			return lib.ids(Cat.STADIUM)
		Kind.COLISEUM:
			return lib.ids(Cat.COLISEUM)
	return PackedInt32Array()


## Low houses on small lots, mid-rise on big ones, a few towers here and there.
static func _quarter(lib: ModelLibrary, r: Rect2i, roll: float) -> PackedInt32Array:
	var cat := Cat.QUARTER_LOW
	if roll < 0.1:
		cat = Cat.QUARTER_TALL
	elif r.get_area() >= 6 or roll < 0.4:
		cat = Cat.QUARTER_MID
	for c in [cat, Cat.QUARTER_MID, Cat.QUARTER_LOW]:
		if lib.has_cat(c):
			return lib.ids(c)
	return lib.ids(Cat.HOUSE)


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
