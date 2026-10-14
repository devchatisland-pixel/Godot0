class_name FogCityLayout
extends RefCounted
## The town of the fog island: ONE big city round a centre (local cells of the island), laid
## out as rings and radial streets instead of a chessboard:
##   - the centre: skyscrapers (the night tower, the office towers, the modular towers, block
##     storeys) in two rows round the first ring, and four more in the middle of it;
##   - the second ring: offices, modular towers and blocks of flats;
##   - the third ring: blocks of flats, town houses and the shops of the catalog;
##   - the outer rings: the houses (the house, the modular houses, one of the seven modular
##     homes now and then), three rows between two streets, back to back.
## Left clear: the army base, the nuclear plant, the industrial port, the farmland, the
## checkpoint and the avenue (FogBaseSites). The ring roads and the radial streets are cut where
## they would run through those or into the sea.
## Pure data: `build(elevation)` returns {"roads": [[from, to, width]], "items": [plan entries]}
## and `stats` counts what was put where.

const Cat := ModelCatalog.Cat
const SIZE := FogIslandShaper.SIZE
## Elevation byte above which a cell is firm land (the beach is left out).
const FIRM := 141

## Centre of the city: a little south of the avenue (row 96.5), which crosses it.
const CENTER := Vector2(90.0, 98.0)
## Radius of the ring roads (cells).
const RINGS := [15.0, 27.0, 39.0, 51.0, 63.0]
## Radial streets, and the width of every street of the city.
const RADIALS := 9
const STREET_W := 2.0
## First radius of the radial streets (outside the two rows of skyscrapers of the first ring).
const RADIAL_FROM := 21.0
## Cells of a ring road kept free on each side before the first row of houses.
const CURB := 1.0

## Shops (catalog ids) in the order they are put, and how many of them.
const SHOP_COUNT := 50
const SHOP_ORDER := ["shop-candy-b", "shop-general-orange-a", "shop-coffee-b", "shop-flower-a",
		"shop-townhouse-gabled", "shop-general-mini", "shop-candy-a", "shop-business",
		"shop-townhouse-blue", "shop-general-orange-b", "shop-coffee-a", "shop-building-multi"]

## Skyscrapers of the centre: [category, footprint, storeys, which model].
const CORE := [
	[Cat.FOG_NIGHT_TOWER, 3.4, 1, 0], [Cat.FOG_MOD_TOWER, 3.6, 1, 1], [Cat.FOG_OFFICE_TOWER, 3.4, 1, 0],
	[Cat.FOG_MOD_TOWER, 3.8, 1, 2], [Cat.FOG_FLOOR, 3.2, 6, 0], [Cat.FOG_MOD_TOWER, 3.4, 1, 0],
	[Cat.FOG_NIGHT_TOWER, 3.4, 1, 0], [Cat.FOG_OFFICE_TOWER, 3.4, 1, 0],
]
## Offices and mid-rise of the second ring.
const MID := [
	[Cat.FOG_OFFICE, 3.8, 1, 0], [Cat.FOG_MOD_TOWER, 3.2, 1, 0], [Cat.FOG_FLOOR, 3.0, 3, 0],
	[Cat.FOG_MOD_HOUSE, 3.2, 1, 2], [Cat.FOG_OFFICE_TOWER, 3.2, 1, 0], [Cat.FOG_MOD_HOUSE, 2.8, 1, 1],
	[Cat.FOG_FLOOR, 3.0, 2, 0], [Cat.FOG_MOD_TOWER, 3.4, 1, 1],
]
## Flats and town houses of the third ring.
const MIXED := [
	[Cat.FOG_FLOOR, 2.6, 3, 0], [Cat.FOG_MOD_HOUSE, 2.6, 1, 0], [Cat.FOG_FLOOR, 2.6, 2, 0],
	[Cat.FOG_HOUSE, 2.3, 1, 0], [Cat.FOG_MOD_HOUSE, 2.6, 1, 2], [Cat.FOG_FLOOR, 2.6, 4, 0],
]
## Houses of the outer rings.
const HOMES := [
	[Cat.FOG_HOUSE, 2.2, 1, 0], [Cat.FOG_MOD_HOUSE, 2.3, 1, 0], [Cat.FOG_HOUSE, 2.0, 1, 0],
	[Cat.FOG_MOD_HOUSE, 2.3, 1, 1], [Cat.FOG_FLOOR, 2.3, 1, 0], [Cat.FOG_MOD_HOUSE, 2.4, 1, 2],
	[Cat.FOG_HOUSE, 2.3, 1, 0],
]
## One house in this many is one of the seven modular homes (all fronts to the south).
const MOD_HOME_EVERY := 11
const MOD_HOME_FIT := 2.4
const MOD_HOUSE_CATS := [Cat.FOG_MOD_HOUSE, Cat.FOG_MOD_HOME]

## What is counted: buildings by group, shops, roads.
static var stats := {}
static var _cache := {}


## {"roads": Array of [Vector2, Vector2, float], "items": Array[Dictionary]} for this island.
static func build(elevation: PackedByteArray) -> Dictionary:
	if _cache.has("roads") and _cache["size"] == elevation.size():
		return _cache
	var gen := FogCityLayout.new()
	gen._elev = elevation
	gen._run()
	_cache = {"roads": gen._roads, "items": gen._items, "size": elevation.size()}
	stats = gen._stats
	return _cache


var _elev := PackedByteArray()
var _roads: Array = []
var _items: Array[Dictionary] = []
var _stats := {"core": 0, "mid": 0, "mixed": 0, "homes": 0, "mod_homes": 0, "shops": 0, "cars": 0}
var _straight: Array = []   # [from, to, width] of the roads that are not rings (houses keep off them)
var _shop_sizes := {}
var _homes_n := 0
var _shops_left := SHOP_COUNT
var _car_n := 0


func _run() -> void:
	_load_shops()
	_streets()
	_core()
	_ring_rows()
	_cars()


## Nominal radius `r` at angle `a` as it is on the ground: the rings wobble, they are not circles.
static func ground_r(r: float, a: float) -> float:
	return r * (1.0 + 0.05 * sin(2.0 * a + r * 0.11) + 0.035 * sin(3.0 * a + 1.7 + r * 0.05))


static func ground_pt(r: float, a: float) -> Vector2:
	return CENTER + Vector2(cos(a), sin(a)) * ground_r(r, a)


# --- Land and keep-out -----------------------------------------------------------------------------
func _land(p: Vector2) -> bool:
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return false
	return _elev[y * SIZE + x] > FIRM


func _land_box(p: Vector2, half: float) -> bool:
	return _land(p) and _land(p + Vector2(half, half)) and _land(p + Vector2(-half, half)) \
			and _land(p + Vector2(half, -half)) and _land(p + Vector2(-half, -half))


## Zones the city leaves alone.
static func keep_out(p: Vector2, margin: float) -> bool:
	for r: Rect2 in FogBaseSites.KEEP_OUT:
		if r.grow(margin).has_point(p):
			return true
	return false


func _near_straight(p: Vector2, margin: float) -> bool:
	for s in _straight:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < margin + float(s[2]) * 0.5:
			return true
	return false


func _blocked(p: Vector2, fit: float) -> bool:
	var half := fit * 0.5
	return not _land_box(p, half) or keep_out(p, half + 0.4) or _near_straight(p, half + 0.5)


# --- Streets ---------------------------------------------------------------------------------------------
func _ok_point(p: Vector2) -> bool:
	return _land(p) and not keep_out(p, 0.5)


## Adds the road a-b if both ends are usable.
func _road(a: Vector2, b: Vector2, w: float, straight := true) -> void:
	_roads.append([a, b, w])
	if straight:
		_straight.append([a, b, w])


func _streets() -> void:
	# The avenue, the checkpoint pieces and the road to the east bridge come from FogBaseSites.ROADS.
	for r in FogBaseSites.ROADS:
		_road(r[0], r[1], float(r[2]))
	# Rings, cut where they leave the land or enter a keep-out zone.
	for R: float in RINGS:
		var step := 5.0 / R
		var a := 0.0
		while a < TAU - 0.0001:
			var p0 := ground_pt(R, a)
			var p1 := ground_pt(R, a + step)
			if _ok_point(p0) and _ok_point(p1):
				_road(p0, p1, STREET_W, false)
			a += step
	# Radial streets from the first ring to the last, a little bent.
	for k in RADIALS:
		var base := float(k) / float(RADIALS) * TAU + 0.11
		var prev := Vector2.ZERO
		var have := false
		var r := RADIAL_FROM
		while r <= (RINGS[RINGS.size() - 1] as float) + 0.01:
			var a := base + 0.05 * sin(r * 0.13 + float(k))
			var p := ground_pt(r, a)
			if have and _ok_point(p) and _ok_point(prev):
				_road(prev, p, STREET_W)
			prev = p
			have = true
			r += 4.0
	# Streets that join the zones to the city.
	var ag := FogBaseSites.FARM_RECT
	_road(Vector2(144, 96.5), Vector2(144, ag.end.y), 2.0)                       # to the north bridge
	var base_gate := Vector2(FogBaseSites.BASE_RECT.get_center().x, FogBaseSites.BASE_RECT.end.y)
	_road(base_gate, Vector2(base_gate.x, 96.5), 2.0)                             # army base gate
	var plant := FogBaseSites.PLANT_RECT
	_road(Vector2(plant.position.x, plant.get_center().y), Vector2(CENTER.x + 40.0, plant.get_center().y), 2.0)
	var ind := FogBaseSites.INDUSTRY_RECT
	_road(Vector2(88, CENTER.y + 27.0), Vector2(88, ind.end.y - 2.0), 2.0)       # to the port
	for r in FogBaseSites.INDUSTRY_ROADS:
		_road(r[0], r[1], float(r[2]))
	# A lane across the farmland.
	_road(Vector2(ag.position.x - 4.0, ag.end.y + 1.0), Vector2(144, ag.end.y + 1.0), 2.0)


# --- Buildings -------------------------------------------------------------------------------------------
func _entry(spec: Array, at: Vector2, face: Vector2) -> Dictionary:
	var cat: int = spec[0]
	var e := {"cat": cat, "at": at, "dir": Vector2(0, 1) if MOD_HOUSE_CATS.has(cat) else face,
			"fit": float(spec[1]), "v": int(spec[3]), "city": true}
	if int(spec[2]) > 1:
		e["stack"] = int(spec[2])
	return e


## The four towers in the middle of the first ring.
func _core() -> void:
	var spots := [Vector2(-5.5, 5.0), Vector2(5.5, 5.0), Vector2(-5.5, -5.0), Vector2(5.5, -5.0)]
	for k in spots.size():
		var spec: Array = CORE[k]
		var p := CENTER + (spots[k] as Vector2)
		if not _blocked(p, float(spec[1])):
			_items.append(_entry(spec, p, Vector2(0, 1) if p.y < CENTER.y else Vector2(0, -1)))
			_stats["core"] += 1


## One row along ring `R`, on its inner (-1) or outer (+1) side, or at the radius `R` itself
## (side 0, between two streets: facing out and in in turn). `pool` is the order of buildings.
func _row(R: float, side: int, pool: Array, group: String, shops: bool) -> void:
	var k := 0
	var s := 0.0
	var guard := 0
	while guard < 4000:
		guard += 1
		var spec: Array = pool[k % pool.size()]
		var shop := ""
		var w := float(spec[1])
		var depth := float(spec[1])
		if shops and _shops_left > 0 and k % 2 == 0:
			shop = SHOP_ORDER[(SHOP_COUNT - _shops_left) % SHOP_ORDER.size()]
			var sz: Vector2 = _shop_sizes.get(shop, Vector2(3.0, 3.0))
			w = sz.x
			depth = sz.y
		var off := CURB + depth * 0.5 + 0.2
		var r := R + float(side) * off if side != 0 else R
		if s + w > TAU * r:
			break
		var a := (s + w * 0.5) / r
		var p := ground_pt(r, a)
		var out := Vector2(cos(a), sin(a))
		var face := out if side < 0 else -out
		if side == 0:
			face = out if k % 2 == 0 else -out
		s += w + 0.55
		k += 1
		if _blocked(p, maxf(w, depth)):
			continue
		if shop != "":
			_items.append({"shop": shop, "at": p, "dir": face, "scale": _shop_scale(shop), "city": true})
			_shops_left -= 1
			_stats["shops"] += 1
			continue
		var e: Dictionary
		if group == "homes":
			_homes_n += 1
			if _homes_n % MOD_HOME_EVERY == 0:
				e = _entry([Cat.FOG_MOD_HOME, MOD_HOME_FIT, 1, (_homes_n / MOD_HOME_EVERY) % 7], p, face)
				_stats["mod_homes"] += 1
			else:
				e = _entry(spec, p, face)
		else:
			e = _entry(spec, p, face)
		_items.append(e)
		_stats[group] += 1


func _ring_rows() -> void:
	# Centre: two rows of skyscrapers round the first ring.
	_row(RINGS[0], -1, CORE, "core", false)
	_row(RINGS[0], 1, CORE, "core", false)
	# Offices and mid-rise.
	_row(RINGS[1], -1, MID, "mid", false)
	_row(RINGS[1], 1, MID, "mid", false)
	# Flats, town houses and the shops.
	_row((RINGS[1] as float + RINGS[2] as float) * 0.5, 0, MIXED, "mixed", false)
	_row(RINGS[2], -1, MIXED, "mixed", true)
	_row(RINGS[2], 1, MIXED, "mixed", true)
	# Houses: a row on each side of the outer streets and one between two streets.
	_row((RINGS[2] as float + RINGS[3] as float) * 0.5, 0, HOMES, "homes", false)
	_row(RINGS[3], -1, HOMES, "homes", false)
	_row(RINGS[3], 1, HOMES, "homes", false)
	_row((RINGS[3] as float + RINGS[4] as float) * 0.5, 0, HOMES, "homes", false)
	_row(RINGS[4], -1, HOMES, "homes", false)
	_row(RINGS[4], 1, HOMES, "homes", false)
	# Still shops to put: along the outer side of the second ring.
	var extra := [[RINGS[1], 1], [RINGS[3], -1], [RINGS[3], 1], [RINGS[2], 0], [RINGS[4], -1]]
	for e in extra:
		if _shops_left <= 0:
			break
		_row(float(e[0]), int(e[1]), MIXED, "mixed", true)


# --- Shops ---------------------------------------------------------------------------------------------------
func _load_shops() -> void:
	for s in MapShops.catalog():
		var k := ShopSites.CELLS_PER_METRE * float(ShopSites.SCALE.get(s["id"], 1.0))
		_shop_sizes[s["id"]] = Vector2(float(s["width"]) * k, float(s["depth"]) * k)


func _shop_scale(id: String) -> float:
	return ShopSites.CELLS_PER_METRE * float(ShopSites.SCALE.get(id, 1.0))


# --- Cars ------------------------------------------------------------------------------------------------------
## Parked along the ring roads: every few cells, the nose along the street.
func _cars() -> void:
	for ri in range(1, RINGS.size()):
		var R: float = RINGS[ri]
		var a := 0.3 + 0.2 * float(ri)
		while a < TAU:
			var p := ground_pt(R + 0.55, a)
			if _ok_point(p) and not _near_straight(p, 1.2):
				var tangent := Vector2(-sin(a), cos(a))
				_items.append({"veh": FogBaseSites.CARS[_car_n % FogBaseSites.CARS.size()], "at": p,
						"dir": tangent if _car_n % 2 == 0 else -tangent, "city": true})
				_car_n += 1
				_stats["cars"] += 1
			a += 24.0 / R
