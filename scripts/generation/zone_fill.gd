class_name ZoneFill
extends RefCounted
## Builds on the empty plots of three zones, with the models the user chose for each:
##   SUBURBAN   the Kenney suburban houses (building-type-*)
##   QUARTER    quarter buildings (the red district)
##   APARTMENT  modular fog homes and offices, flats; only the south area, near Las Vegas and
##              the shopping streets (the north one, uptown, is left as it is)
## An empty plot is land of the zone with no road, no ground detail and no building on it:
## bare ground, or a lot the building budget cleared (BuildingBudget.cleared). A lot cleared by
## hand (ManualEdits, MapChanges...) stays empty. The free cells are cut into square lots that
## touch a street; each lot faces its street and takes the next model of the list that fits
## it (drawn at least FIT_MIN of its own size), so the models take turns.
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
}
## The apartment area filled is the one south of this row (the north one is uptown).
const APARTMENT_FROM_Y := 190
## A model fits a lot when it is drawn at least this share of its own size (the placer shrinks
## it to the lot, 0.94 of its sides).
const FIT_MIN := 0.8


## Returns {zone name: buildings added}.
static func apply(data: CityData) -> Dictionary:
	var built := PackedByteArray()
	built.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY and BuildingBudget.cleared.has(b):
			continue
		var r := data.building_rect(b)
		for y in range(maxi(r.position.y, 0), mini(r.end.y, data.size)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, data.size)):
				built[data.idx(x, y)] = 1
	var out := {}
	for z: int in PLANS:
		var plan: Array = PLANS[z]
		var free := PackedByteArray()
		free.resize(data.size * data.size)
		for y in data.size:
			if z == Zone.APARTMENT and y < APARTMENT_FROM_Y:
				continue
			for x in data.size:
				var i := data.idx(x, y)
				if data.zone[i] == z and built[i] == 0 and data.road[i] == 0 and data.deco[i] == 0 \
						and data.terrain[i] == Terrain.LAND:
					free[i] = 1
		out[Zone.keys()[z]] = _fill_zone(data, free, plan[0], plan[1], plan[2])
	return out


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


## The side of `lot` with the most street along it (south first on a tie), or -1 without any.
static func _front(data: CityData, lot: Rect2i) -> int:
	var best := -1
	var most := 0
	for f in [2, 1, 3, 0]:
		var k := 0
		for t in lot.size.x: # square lots: every side is as long
			var c: Vector2i
			match f:
				0: c = Vector2i(lot.position.x + t, lot.position.y - 1)
				1: c = Vector2i(lot.end.x, lot.position.y + t)
				2: c = Vector2i(lot.position.x + t, lot.end.y)
				_: c = Vector2i(lot.position.x - 1, lot.position.y + t)
			if data.is_road(c.x, c.y) and (data.road[data.idx(c.x, c.y)] & 3) != 0:
				k += 1
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
