class_name ZoneFill
extends RefCounted
## Builds on the empty plots of three zones, with the models the user chose for each:
##   SUBURBAN   the Kenney suburban houses (building-type-*)
##   QUARTER    quarter buildings (the red district)
##   APARTMENT  modular fog homes and offices, flats; the south area, near Las Vegas and the
##              shopping streets (the north one, uptown, is houses: it becomes SUBURBAN first)
##   COMMERCIAL Kenney commercial buildings (building-a... of the commercial kit) and two
##              suburban houses
## First the lots too big for the house on them are cut: a lot of SPLIT_KINDS running SPLIT_FROM
## cells or more along its street is cut in two along it; one as deep, with a street behind it
## too, is cut back to back (the new half faces the street behind). The building keeps the
## front / first part, a building of the list takes the other (again while a part is that big).
## Then the empty plots are built on: land of the zone with no road, no ground detail and no
## building, or with a cleared lot, except the lots cleared by hand (`keep_empty`, filled where
## ManualEdits, MapChanges, ModelEdits and ConcertSite clear one, and ManualEdits.hand_deleted).
## The free cells are cut into square lots that touch a street; each lot faces its street and
## takes the next model of the list that fits it (drawn at least FIT_MIN of its own size), so
## the models take turns.
## Last, what is still empty becomes green: every cleared lot left on dry land (not in the
## desert or on the urban island) becomes a garden, and the gardens, plazas and free cells of
## the city get their trees (CityData.forest, grown by GroundPlacer); a garden takes the ground of
## the parks (Zone.PARK: green, wooded); a garden of two cells or
## more gets a bench, of three or more a flowerbed (CityData.deco).
## Runs last, once the ground details are laid (AmenitiesPlanner).

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## Models (as ModelLibrary names them) with their footprint (x, z), measured on the files.
const SUBURBAN_MODELS := [
	["building-type-t.glb", 1.31, 1.41], ["building-type-d.glb", 1.76, 1.03], ["building-type-b.glb", 1.83, 1.14],
	["building-type-e.glb", 1.3, 1.03], ["building-type-n.glb", 1.78, 1.38], ["building-type-u.glb", 1.43, 1.09],
	["building-type-o.glb", 1.27, 1.03], ["building-type-s.glb", 1.41, 1.09], ["building-type-c.glb", 1.29, 1.03],
	["building-type-j.glb", 1.37, 0.92], ["building-type-a.glb", 1.3, 1.03], ["building-type-m.glb", 1.43, 1.43],
	["building-type-g.glb", 1.45, 1.18], ["building-type-k.glb", 0.92, 1.02], ["building-type-r.glb", 1.03, 1.02],
	["building-type-i.glb", 1.29, 1.03], ["building-type-h.glb", 1.3, 0.92],
]
const QUARTER_MODELS := [
	["quarter.glb: quarter_26_b", 1.99, 2.34], ["quarter_40_b.glb: quarter_40_b", 1.84, 1.84],
	["quarter.glb: quarter_79_b", 0.68, 0.67], ["quarter.glb: quarter_85_b", 1.59, 0.7],
	["quarter.glb: quarter_53_b", 1.5, 1.2], ["quarter.glb: quarter_74_b", 2.15, 2.15],
	["quarter.glb: quarter_32_b", 1.07, 1.38], ["quarter.glb: quarter_28_b", 1.85, 1.86],
	["quarter_95_b.glb: quarter_95_b", 0.89, 0.99], ["quarter_48_b.glb: quarter_48_b", 1.45, 1.33],
	["quarter.glb: quarter_50_b", 0.57, 0.57], ["quarter.glb: quarter_82_b", 0.88, 1.79],
	["quarter.glb: quarter_09_b", 1.68, 1.52], ["quarter.glb: quarter_02_b", 1.29, 1.14],
	["quarter.glb: quarter_72_b", 1.23, 0.97], ["quarter.glb: quarter_68_b", 1.09, 1.14],
	["quarter.glb: quarter_03_b", 1.18, 1.18], ["quarter.glb: quarter_38_b", 1.13, 1.11],
	["quarter.glb: quarter_17_b", 2.51, 2.15], ["quarter.glb: quarter_05_b", 0.58, 1.19],
	["quarter.glb: quarter_14_b", 1.01, 1.01],
]
## Kenney commercial kit (the industrial kit has files of the same names; the library lists the
## commercial ones first, so these names draw them).
const COMMERCIAL_MODELS := [
	["building-a.glb", 0.88, 0.94], ["building-b.glb", 0.97, 0.94], ["building-type-p.glb", 1.24, 0.99],
	["building-e.glb", 1.64, 1.01], ["building-type-q.glb", 1.24, 0.89], ["building-j.glb", 2.08, 1.34],
	["building-h.glb", 0.88, 1.01],
]
const APARTMENT_MODELS := [
	["free_mini.glb: m1", 1.59, 1.59], ["fog_city.glb: fog_office", 2.48, 2.99],
	["fog_city.glb: mod_house_big", 3.4, 0.89], ["fog_city.glb: mod_house_small", 2.4, 1.26],
	["fog_city.glb: mod_house_medium", 2.6, 1.36], ["fog_homes.glb: home-block", 3.0, 1.57],
	["home-bungalow.glb: home-bungalow", 3.0, 0.79], ["fog_city.glb: mod_tower_small", 3.4, 0.89],
	["fog_homes.glb: home-terrace", 3.0, 0.52], ["accommodations.glb: flat8", 2.29, 2.19],
	["carto.glb: house2", 1.17, 0.8],
]
## Zone -> [models, kind given to the new buildings, lot sizes tried (largest first)].
const PLANS := {
	Zone.SUBURBAN: [SUBURBAN_MODELS, Kind.HOUSE, [2]],
	Zone.QUARTER: [QUARTER_MODELS, Kind.QUARTER_BLDG, [2]],
	Zone.APARTMENT: [APARTMENT_MODELS, Kind.APARTMENT, [3, 2]],
	Zone.COMMERCIAL: [COMMERCIAL_MODELS, Kind.SHOP, [2]],
}
## Kinds whose lots are cut when they are too long, per zone.
const SPLIT_KINDS := {
	Zone.SUBURBAN: [Kind.HOUSE, Kind.SHOP, Kind.APARTMENT],
	Zone.QUARTER: [Kind.QUARTER_BLDG],
	Zone.APARTMENT: [Kind.APARTMENT, Kind.HOUSE, Kind.SHOP],
	Zone.COMMERCIAL: [Kind.SHOP, Kind.HOUSE, Kind.APARTMENT],
}
## A lot this long along its street (cells) or longer is cut in two.
const SPLIT_FROM := 4
## The apartment zone north of this row (uptown) is houses like the suburbs: it becomes SUBURBAN.
const APARTMENT_FROM_Y := 190
## A model fits a lot when it is drawn at least this share of its own size (the placer shrinks
## it to the lot, 0.94 of its sides).
const FIT_MIN := 0.8

## Tree density (CityData.forest, 0..255) of the gardens, the other free cells of the city and
## the plazas.
const GARDEN_TREES := 190
const FREE_TREES := 140
const PLAZA_TREES := 60
## Town zones whose free cells take the ground of the parks.
## (CIVIC is left bare: the paved yards and parkings of the public buildings, where vehicles stand.)
const PARK_ZONES: Array[int] = [Zone.DOWNTOWN, Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN,
		Zone.ENTERTAINMENT, Zone.QUARTER, Zone.POOR]
## Zones where a cleared lot does not turn into a garden.
const NO_GARDEN_ZONES: Array[int] = [Zone.NONE, Zone.URBAN, Zone.DESERT]

## Lots cleared by hand: never built on again (CityGenerator empties it before a map is made).
static var keep_empty := {}


## Returns {"split": {zone: lots cut}, "filled": {zone: buildings added}}.
static func apply(data: CityData) -> Dictionary:
	var rezoned := 0
	for y in mini(APARTMENT_FROM_Y, data.size):
		for x in data.size:
			var i := data.idx(x, y)
			if data.zone[i] == Zone.APARTMENT:
				data.zone[i] = Zone.SUBURBAN
				rezoned += 1
	var keep := keep_empty.duplicate()
	keep.merge(ManualEdits.hand_deleted)
	var edited := {}
	for b in ManualEdits.resolved.values():
		edited[b] = true
	var turns := {}
	var split := {}
	for z: int in PLANS:
		turns[z] = 0
		split[Zone.keys()[z]] = 0
	# Lots too long: cut along their street.
	var queue: Array[int] = []
	for b in data.building_count():
		queue.append(b)
	while not queue.is_empty():
		var b: int = queue.pop_back()
		var r := data.building_rect(b)
		var z := data.zone_at(r.position.x, r.position.y)
		if not SPLIT_KINDS.has(z):
			continue
		if not (SPLIT_KINDS[z] as Array).has(int(data.b_kind[b])) or data.b_model.has(b) 				or data.b_sign[b] != 0 or data.b_more_signs.has(b) or edited.has(b):
			continue
		var facing: int = data.b_facing[b]
		var along_x := facing % 2 == 0
		var length := r.size.x if along_x else r.size.y
		var depth := r.size.y if along_x else r.size.x
		var back := (facing + 2) % 4
		var keep_lot: Rect2i
		var new_lot: Rect2i
		var new_facing := facing
		if length >= SPLIT_FROM:
			# Two lots side by side along the street.
			var a := length / 2
			keep_lot = Rect2i(r.position, Vector2i(a, r.size.y) if along_x else Vector2i(r.size.x, a))
			new_lot = Rect2i(r.position + (Vector2i(a, 0) if along_x else Vector2i(0, a)),
					Vector2i(length - a, r.size.y) if along_x else Vector2i(r.size.x, length - a))
		elif depth >= SPLIT_FROM and _road_cells(data, r, back) * 2 >= length:
			# A lot from one street to the next: two lots back to back, each facing its street.
			var d := depth / 2
			var front_first := facing == 0 or facing == 3 # the front half is the one at the top / left
			var first := Rect2i(r.position, Vector2i(r.size.x, d) if along_x else Vector2i(d, r.size.y))
			var second := Rect2i(r.position + (Vector2i(0, d) if along_x else Vector2i(d, 0)),
					Vector2i(r.size.x, depth - d) if along_x else Vector2i(depth - d, r.size.y))
			keep_lot = first if front_first else second
			new_lot = second if front_first else first
			new_facing = back
		else:
			continue
		var plan: Array = PLANS[z]
		var pick := _next_model(plan[0], new_lot, new_facing, turns[z])
		if pick < 0:
			continue
		turns[z] = pick + 1
		data.set_building_rect(b, keep_lot)
		var nb := data.add_building(new_lot, plan[1], new_facing,
				CityTypes.hash2(new_lot.position.x, new_lot.position.y, 4243), data.b_height[b])
		data.b_model[nb] = plan[0][pick][0]
		split[Zone.keys()[z]] += 1
		# A part still too long is cut again (the new one keeps its model: only the old one is).
		queue.append(b)
	# Empty plots.
	var built := PackedByteArray()
	built.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY and not keep.has(b):
			continue
		var r := data.building_rect(b)
		for y in range(maxi(r.position.y, 0), mini(r.end.y, data.size)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, data.size)):
				built[data.idx(x, y)] = 1
	var filled := {}
	for z: int in PLANS:
		var plan: Array = PLANS[z]
		var free := PackedByteArray()
		free.resize(data.size * data.size)
		for y in data.size:
			for x in data.size:
				var i := data.idx(x, y)
				if data.zone[i] == z and built[i] == 0 and data.road[i] == 0 and data.deco[i] == 0 						and data.terrain[i] == Terrain.LAND:
					free[i] = 1
		filled[Zone.keys()[z]] = _fill_zone(data, free, plan[0], plan[1], plan[2])
	return {"rezoned_to_suburban": rezoned, "split": split, "filled": filled, "green": _green(data)}


## Cleared lots into gardens, trees on the gardens, plazas and free cells (see the header).
static func _green(data: CityData) -> Dictionary:
	var built := PackedByteArray()
	built.resize(data.size * data.size)
	var plaza := PackedByteArray()
	plaza.resize(data.size * data.size)
	for b in data.building_count():
		var k: int = data.b_kind[b]
		var r := data.building_rect(b)
		for y in range(maxi(r.position.y, 0), mini(r.end.y, data.size)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, data.size)):
				if k == Kind.PLAZA:
					plaza[data.idx(x, y)] = 1
				elif k != Kind.EMPTY and k != Kind.GARDEN:
					built[data.idx(x, y)] = 1
	# Every cleared lot on dry land becomes a garden (drawn as nothing: the cells a building of
	# ZoneFill took are that building's). A whole free garden gets a bench and a flowerbed.
	var made := 0
	var furnished := 0
	for b in data.building_count():
		var k: int = data.b_kind[b]
		if k != Kind.EMPTY and k != Kind.GARDEN:
			continue
		var r := data.building_rect(b)
		var c := r.get_center()
		if not data.in_bounds(c.x, c.y) or data.terrain[data.idx(c.x, c.y)] != Terrain.LAND 				or NO_GARDEN_ZONES.has(data.zone_at(c.x, c.y)):
			continue
		if k == Kind.EMPTY:
			data.b_kind[b] = Kind.GARDEN
			made += 1
		if not _dry_and_free(data, built, r):
			continue
		var cells: Array[int] = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.deco[data.idx(x, y)] == 0:
					cells.append(data.idx(x, y))
		var h := absi(CityTypes.hash2(r.position.x, r.position.y, 2718))
		if cells.size() >= 2:
			var bench: int = cells[h % cells.size()]
			data.deco[bench] = AmenitiesPlanner.BENCH_X if (h >> 3) & 1 == 0 else AmenitiesPlanner.BENCH_Z
			cells.erase(bench)
			furnished += 1
		if cells.size() >= 2:
			data.deco[cells[(h >> 5) % cells.size()]] = AmenitiesPlanner.FLOWER
	# Every cell of the city with nothing built on it: trees, and in the town zones the green
	# ground of the parks (gardens, what is left of cleared lots, the strips between lots).
	# The yard of the main fire station stays clear (its truck drives out there).
	var fs := ManualEdits._nearest(data, "FIRE_STATION", ManualEdits.MAIN_FIRE_STATION)
	if fs >= 0:
		for c in ManualEdits.front_yard(data, fs, ManualEdits.FIRE_YARD_DEPTH, 1):
			built[data.idx(c.x, c.y)] = 1
	var green := 0
	var wooded := 0
	for i in data.size * data.size:
		if built[i] == 1 or data.road[i] != 0 or data.terrain[i] != Terrain.LAND:
			continue
		var z: int = data.zone[i]
		if plaza[i] == 1:
			data.forest[i] = maxi(data.forest[i], PLAZA_TREES)
		elif PARK_ZONES.has(z):
			data.zone[i] = Zone.PARK
			data.forest[i] = maxi(data.forest[i], GARDEN_TREES)
			green += 1
		elif GroundPlacer.CITY_TREE_ZONES.has(z):
			data.forest[i] = maxi(data.forest[i], FREE_TREES)
			wooded += 1
	return {"lots_made_gardens": made, "gardens_furnished": furnished, "cells_made_park": green,
			"cells_with_trees": wooded}


## True when every cell of `r` is dry land and no building stands on it.
static func _dry_and_free(data: CityData, built: PackedByteArray, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not data.in_bounds(x, y):
				return false
			var i := data.idx(x, y)
			if built[i] == 1 or data.terrain[i] != Terrain.LAND or data.road[i] != 0:
				return false
	return true


## Cuts the free cells into square lots touching a street and builds on them.
static func _fill_zone(data: CityData, free: PackedByteArray, models: Array, kind: int, sizes: Array) -> int:
	var n := 0
	var turn := 0
	for s: int in sizes:
		for y in data.size - s + 1:
			for x in data.size - s + 1:
				if free[data.idx(x, y)] == 0:
					continue
				var lot := Rect2i(x, y, s, s)
				if not _all_free(data, free, lot):
					continue
				var facing := _front(data, lot)
				if facing < 0:
					continue
				var pick := _next_model(models, lot, facing, turn)
				if pick < 0:
					continue
				turn = pick + 1
				var seed := CityTypes.hash2(x, y, 4242)
				var b := data.add_building(lot, kind, facing, seed, 0.5)
				data.b_model[b] = models[pick][0]
				for ly in range(lot.position.y, lot.end.y):
					for lx in range(lot.position.x, lot.end.x):
						free[data.idx(lx, ly)] = 0
						data.forest[data.idx(lx, ly)] = 0
				n += 1
	return n


static func _all_free(data: CityData, free: PackedByteArray, lot: Rect2i) -> bool:
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			if free[data.idx(x, y)] == 0:
				return false
	return true


## How many cells of street run along side `side` of `lot`.
static func _road_cells(data: CityData, lot: Rect2i, side: int) -> int:
	var k := 0
	for c in _side_cells(lot, side):
		if data.is_road(c.x, c.y):
			k += 1
	return k


## The cells just outside side `side` (0 north, 1 east, 2 south, 3 west) of `lot`.
static func _side_cells(lot: Rect2i, side: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match side:
		0:
			for t in lot.size.x:
				cells.append(Vector2i(lot.position.x + t, lot.position.y - 1))
		1:
			for t in lot.size.y:
				cells.append(Vector2i(lot.end.x, lot.position.y + t))
		2:
			for t in lot.size.x:
				cells.append(Vector2i(lot.position.x + t, lot.end.y))
		_:
			for t in lot.size.y:
				cells.append(Vector2i(lot.position.x - 1, lot.position.y + t))
	return cells


## The side of `lot` with the most street along it (south first on a tie), or -1 without any.
static func _front(data: CityData, lot: Rect2i) -> int:
	var best := -1
	var most := 0
	for f in [2, 1, 3, 0]:
		var k := _road_cells(data, lot, f)
		if k > most:
			most = k
			best = f
	return best


## The first model of `models` from `start` on (in turn) that fits `lot` turned to `facing`.
static func _next_model(models: Array, lot: Rect2i, facing: int, start: int) -> int:
	for k in models.size():
		var m: int = (start + k) % models.size()
		var fx: float = models[m][1]
		var fz: float = models[m][2]
		var fp := Vector2(fz, fx) if facing % 2 == 1 else Vector2(fx, fz)
		var fit := minf(lot.size.x * 0.94 / fp.x, lot.size.y * 0.94 / fp.y)
		if fit >= FIT_MIN:
			return m
	return -1
