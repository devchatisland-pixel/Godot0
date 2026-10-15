class_name FogCityLayout
extends RefCounted
## The town of the fog island: ONE big city (local cells of the island) on real streets, like
## Chat City: straight avenues and streets that cross at right angles, in blocks of different
## sizes (the gaps between two streets are drawn at random, so no two blocks look alike), no
## rounded road.
##   - the centre: skyscrapers (the night tower, the office towers, the modular towers, block
##     storeys), two or three to a block;
##   - round it: offices, modular towers and blocks of flats;
##   - then flats, town houses and the shops (only the candy shop model);
##   - the outer blocks: the houses (the house, the modular houses, one of the seven modular
##     homes now and then).
## Every block has its own way of being filled (rows facing the street to the north and south,
## columns facing east and west, corner buildings round a yard, or a small park).
## Left clear: the army base, the nuclear plant, the industrial port, the farmland, the
## checkpoint and the avenue (FogBaseSites.KEEP_OUT).
## Pure data: `build(elevation)` returns {"roads": [[from, to, width]], "items": [plan entries]}.

const Cat := ModelCatalog.Cat
const SIZE := FogIslandShaper.SIZE
## Elevation byte above which a cell is firm land (the beach is left out).
const FIRM := 141

## Centre of the city: the avenue (row 96.5) crosses it.
const CENTER := Vector2(88.0, 98.0)
## Distances from the centre (cells; the north-south distance counts 1.1 times) where the
## skyscrapers end, the mid-rise ends and the flats and shops end.
const CORE_R := 25.0
const MID_R := 38.0
const MIXED_R := 50.0
## Gaps between two streets (cells, centre line to centre line).
const GAP_MIN := 8.5
const GAP_MAX := 15.5
## Width of the streets, and the clear space kept between a street and a building.
const STREET_W := 2.0
const AVENUE_Y := 96.5
const NORTH_STREET_X := 144.0
const CURB := 0.4

## The only shop model, and how many.
const SHOP_ID := "shop-general-orange-b-unlit"
const SHOP_COUNT := 50
## More shops put in the free spaces left once every block is filled (parks, gaps).
const EXTRA_SHOPS := 15
## Shops that take the place of houses (one or two of them), spread over the whole city; they
## look south and east in turn.
const CONVERTED_SHOPS := 50

## Skyscrapers of the centre: [category, footprint, storeys, which model].
const CORE := [
	[Cat.FOG_NIGHT_TOWER, 3.4, 1, 0], [Cat.FOG_MOD_TOWER, 3.6, 1, 1], [Cat.FOG_OFFICE_TOWER, 3.4, 1, 0],
	[Cat.FOG_MOD_TOWER, 3.8, 1, 2], [Cat.FOG_FLOOR, 3.2, 6, 0], [Cat.FOG_MOD_TOWER, 3.4, 1, 0],
	[Cat.FOG_NIGHT_TOWER, 3.4, 1, 0], [Cat.FOG_OFFICE_TOWER, 3.4, 1, 0],
]
## Offices and mid-rise.
const MID := [
	[Cat.FOG_OFFICE, 3.8, 1, 0], [Cat.FOG_MOD_TOWER, 3.2, 1, 0], [Cat.FOG_FLOOR, 3.0, 3, 0],
	[Cat.FOG_MOD_HOUSE, 3.2, 1, 2], [Cat.FOG_OFFICE_TOWER, 3.2, 1, 0], [Cat.FOG_MOD_HOUSE, 2.8, 1, 1],
	[Cat.FOG_FLOOR, 3.0, 2, 0], [Cat.FOG_MOD_TOWER, 3.4, 1, 1],
]
## Flats and town houses.
const MIXED := [
	[Cat.FOG_FLOOR, 2.6, 3, 0], [Cat.FOG_MOD_HOUSE, 2.6, 1, 0], [Cat.FOG_FLOOR, 2.6, 2, 0],
	[Cat.FOG_HOUSE, 2.3, 1, 0], [Cat.FOG_MOD_HOUSE, 2.6, 1, 2], [Cat.FOG_FLOOR, 2.6, 4, 0],
]
## Houses of the outer blocks.
const HOMES := [
	[Cat.FOG_HOUSE, 2.2, 1, 0], [Cat.FOG_MOD_HOUSE, 2.3, 1, 0], [Cat.FOG_HOUSE, 2.0, 1, 0],
	[Cat.FOG_MOD_HOUSE, 2.3, 1, 1], [Cat.FOG_FLOOR, 2.3, 1, 0], [Cat.FOG_MOD_HOUSE, 2.4, 1, 2],
	[Cat.FOG_HOUSE, 2.3, 1, 0],
]
## One house in this many is one of the seven modular homes (all fronts to the south).
const MOD_HOME_EVERY := 11
const MOD_HOME_FIT := 2.4
const MOD_HOUSE_CATS := [Cat.FOG_MOD_HOUSE, Cat.FOG_MOD_HOME]

## What is counted: buildings by group, shops, cars, blocks.
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
var _stats := {"core": 0, "mid": 0, "mixed": 0, "homes": 0, "mod_homes": 0, "shops": 0, "cars": 0,
		"blocks": 0, "parks": 0}
var _extra: Array = []      # roads that are not on the street grid (gates): buildings keep off them
var _xs: Array[float] = []
var _ys: Array[float] = []
var _shop_size := Vector2(3.0, 3.0)
var _shops_left := SHOP_COUNT
var _homes_n := 0
var _car_n := 0
var _block_shops := 0
var _rects: Array[Rect2] = []     # footprint of everything put in a block
var _block_list: Array[Rect2] = []


func _run() -> void:
	_load_shop()
	_grid_lines()
	_streets()
	_blocks()
	_extra_shops()
	_convert_to_shops()
	_cars()


# --- Land and keep-out -----------------------------------------------------------------------------
func _land(p: Vector2) -> bool:
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return false
	return _elev[y * SIZE + x] > FIRM


func _land_box(p: Vector2, half: Vector2) -> bool:
	return _land(p) and _land(p + Vector2(half.x, half.y)) and _land(p + Vector2(-half.x, half.y)) \
			and _land(p + Vector2(half.x, -half.y)) and _land(p + Vector2(-half.x, -half.y))


## Zones the city leaves alone.
static func keep_out(p: Vector2, margin: float) -> bool:
	for r: Rect2 in FogBaseSites.KEEP_OUT:
		if r.grow(margin).has_point(p):
			return true
	return false


func _near_extra(p: Vector2, margin: float) -> bool:
	for s in _extra:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < margin + float(s[2]) * 0.5:
			return true
	return false


## Distance from the centre of the city (the north-south distance counts a little more).
func _dist(p: Vector2) -> float:
	var d := p - CENTER
	return Vector2(d.x, d.y * 1.1).length()


# --- Street grid --------------------------------------------------------------------------------------
## Positions of the streets: from a fixed street outwards, with gaps drawn at random.
func _lines(start: float, lo: float, hi: float, rng: RandomNumberGenerator) -> Array[float]:
	var out: Array[float] = [start]
	var p := start
	while true:
		p -= lerpf(GAP_MIN, GAP_MAX, rng.randf())
		if p < lo:
			break
		out.append(p)
	p = start
	while true:
		p += lerpf(GAP_MIN, GAP_MAX, rng.randf())
		if p > hi:
			break
		out.append(p)
	out.sort()
	return out


func _grid_lines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	_xs = _lines(NORTH_STREET_X, 6.0, 170.0, rng)
	_ys = _lines(AVENUE_Y, 22.0, 168.0, rng)


func _road(a: Vector2, b: Vector2, w: float) -> void:
	_roads.append([a, b, w])


## A straight street from a to b, in pieces, cut where it leaves the land or enters a zone.
func _street(a: Vector2, b: Vector2, w: float) -> void:
	var length := a.distance_to(b)
	var n := maxi(1, int(length / 2.0))
	var dir := (b - a) / float(n)
	var run_start := -1
	for i in n + 1:
		var p := a + dir * float(i)
		var ok := _land(p) and not keep_out(p, 0.6)
		if ok and run_start < 0:
			run_start = i
		if (not ok or i == n) and run_start >= 0:
			var end_i := i if ok else i - 1
			if end_i - run_start >= 1:
				_road(a + dir * float(run_start), a + dir * float(end_i), w)
			run_start = -1


func _streets() -> void:
	# The avenue and the way from the bridge (FogBaseSites.ROADS).
	for r in FogBaseSites.ROADS:
		_road(r[0], r[1], float(r[2]))
	for x in _xs:
		_street(Vector2(x, _ys[0]), Vector2(x, _ys[_ys.size() - 1]), STREET_W)
	for y in _ys:
		if is_equal_approx(y, AVENUE_Y):
			continue
		_street(Vector2(_xs[0], y), Vector2(_xs[_xs.size() - 1], y), STREET_W)
	# Gates of the zones: a straight road to the nearest street.
	var base := FogBaseSites.BASE_RECT
	_gate(Vector2(base.get_center().x, base.end.y), Vector2(0, 1))
	var plant := FogBaseSites.PLANT_RECT
	_gate(Vector2(plant.position.x, plant.get_center().y), Vector2(-1, 0))
	var ind := FogBaseSites.INDUSTRY_RECT
	_gate(Vector2(ind.get_center().x, ind.position.y), Vector2(0, -1))
	var farm := FogBaseSites.FARM_RECT
	_gate(Vector2(farm.get_center().x, farm.end.y), Vector2(0, 1))


## A road from `p` going `dir` until it meets a street of the grid (or the avenue).
func _gate(p: Vector2, dir: Vector2) -> void:
	var q := p
	for i in 60:
		q += dir
		var on_street := false
		if absf(dir.y) > 0.5:
			for y in _ys:
				if absf(q.y - y) < 0.6:
					on_street = true
		else:
			for x in _xs:
				if absf(q.x - x) < 0.6:
					on_street = true
		if on_street or not _land(q):
			break
	_road(p, q, STREET_W)
	_extra.append([p, q, STREET_W])


# --- Blocks --------------------------------------------------------------------------------------------------
func _entry(spec: Array, at: Vector2, face: Vector2) -> Dictionary:
	var cat: int = spec[0]
	var e := {"cat": cat, "at": at, "dir": Vector2(0, 1) if MOD_HOUSE_CATS.has(cat) else face,
			"fit": float(spec[1]), "v": int(spec[3]), "city": true}
	if int(spec[2]) > 1:
		e["stack"] = int(spec[2])
	return e


func _hash(i: int, j: int) -> int:
	return CityTypes.hash2(i, j, 4711)


func _blocks() -> void:
	for i in _xs.size() - 1:
		for j in _ys.size() - 1:
			var half := STREET_W * 0.5
			var top := _ys[j] + (1.5 if is_equal_approx(_ys[j], AVENUE_Y) else half) + CURB
			var bottom := _ys[j + 1] - (1.5 if is_equal_approx(_ys[j + 1], AVENUE_Y) else half) - CURB
			var left := _xs[i] + half + CURB
			var right := _xs[i + 1] - half - CURB
			var r := Rect2(left, top, right - left, bottom - top)
			if r.size.x < 3.0 or r.size.y < 3.0:
				continue
			_block_list.append(r)
			_block(r, _hash(i, j))


func _pool(d: float) -> Array:
	if d < CORE_R:
		return CORE
	if d < MID_R:
		return MID
	if d < MIXED_R:
		return MIXED
	return HOMES


func _group(d: float) -> String:
	if d < CORE_R:
		return "core"
	if d < MID_R:
		return "mid"
	if d < MIXED_R:
		return "mixed"
	return "homes"


## Fills one block `r`. `h` picks how: 0 and 1 rows facing north and south, 2 columns facing
## east and west, 3 buildings in the four corners, 4 (outer blocks only) a park.
func _block(r: Rect2, h: int) -> void:
	var c := r.get_center()
	var d := _dist(c)
	if d > 95.0:
		return
	_stats["blocks"] += 1
	var group := _group(d)
	var pool := _pool(d)
	var style := absi(h) % 5
	if group == "homes" and style == 4 and (absi(h) / 5) % 3 == 0:
		_stats["parks"] += 1
		return
	if style == 4:
		style = absi(h) % 3
	# The shops: blocks of the flats and town houses ring, until there are 50.
	_block_shops = 0
	var shops_here := _shops_left > 0 and d >= CORE_R - 8.0 and d < MIXED_R + 14.0
	var k := absi(h)
	if style == 3:
		var fit := float(pool[k % pool.size()][1]) + 0.6
		if r.size.x >= fit * 2.0 and r.size.y >= fit * 2.0:
			var corners := [Vector2(r.position.x + fit * 0.5, r.position.y + fit * 0.5),
					Vector2(r.end.x - fit * 0.5, r.position.y + fit * 0.5),
					Vector2(r.position.x + fit * 0.5, r.end.y - fit * 0.5),
					Vector2(r.end.x - fit * 0.5, r.end.y - fit * 0.5)]
			for q in 4:
				var p: Vector2 = corners[q]
				var face := Vector2(0, 1) if p.y < c.y else Vector2(0, -1)
				_put(pool[(k + q) % pool.size()], p, face, group)
			return
		style = 0
	if style == 2:
		_columns(r, pool, group, k)
	else:
		_rows(r, pool, group, k, shops_here)


## Rows along the north and south edges (and a middle one when the block is deep enough), the
## fronts to the nearest street.
func _rows(r: Rect2, pool: Array, group: String, k: int, shops: bool) -> void:
	var spec0: Array = pool[k % pool.size()]
	var depth := float(spec0[1])
	var row_n := maxi(1, int((r.size.y + 0.5) / (depth + 0.5)))
	row_n = mini(row_n, 3)
	var step_y := r.size.y / float(row_n)
	for row in row_n:
		var y := r.position.y + step_y * (float(row) + 0.5)
		var face := Vector2(0, 1) if row >= row_n / 2 + (row_n % 2) else Vector2(0, -1)
		if row_n == 1:
			face = Vector2(0, 1) if (k % 2 == 0) else Vector2(0, -1)
		var x := r.position.x
		var m := k + row * 3
		while true:
			var spec: Array = pool[m % pool.size()]
			var w := float(spec[1])
			var shop := shops and _shops_left > 0 and _block_shops < 3 and (m % 2 == 0)
			if shop:
				w = _shop_size.x
			if x + w > r.end.x + 0.2:
				break
			var p := Vector2(x + w * 0.5, y)
			x += w + 0.45
			m += 1
			if shop:
				_put_shop(p, face)
			else:
				_put(spec, p, face, group)


## Columns along the west and east edges, the fronts to the nearest street.
func _columns(r: Rect2, pool: Array, group: String, k: int) -> void:
	var spec0: Array = pool[k % pool.size()]
	var depth := float(spec0[1])
	var col_n := maxi(1, int((r.size.x + 0.5) / (depth + 0.5)))
	col_n = mini(col_n, 3)
	var step_x := r.size.x / float(col_n)
	for col in col_n:
		var x := r.position.x + step_x * (float(col) + 0.5)
		var face := Vector2(1, 0) if col >= col_n / 2 + (col_n % 2) else Vector2(-1, 0)
		if col_n == 1:
			face = Vector2(1, 0) if (k % 2 == 0) else Vector2(-1, 0)
		var y := r.position.y
		var m := k + col * 5
		while true:
			var spec: Array = pool[m % pool.size()]
			var w := float(spec[1])
			if y + w > r.end.y + 0.2:
				break
			var p := Vector2(x, y + w * 0.5)
			y += w + 0.45
			m += 1
			_put(spec, p, face, group)


func _put(spec: Array, p: Vector2, face: Vector2, group: String) -> void:
	var fit := float(spec[1])
	var half := Vector2(fit, fit) * 0.5
	if not _land_box(p, half) or keep_out(p, fit * 0.5 + 0.3) or _near_extra(p, fit * 0.5 + 0.5):
		return
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
	_rects.append(Rect2(p - half, half * 2.0))
	_stats[group] += 1


func _put_shop(p: Vector2, face: Vector2) -> void:
	face = _south_or_east(face)
	var half := _shop_size * 0.5
	if not _land_box(p, half) or keep_out(p, maxf(half.x, half.y) + 0.3) or _near_extra(p, half.x + 0.5):
		return
	_items.append({"shop": CityShops.shop_id_at(int(p.x * 4.0), int(p.y * 4.0)), "at": p, "dir": face, "scale": _shop_scale(), "city": true})
	_rects.append(Rect2(p - half, half * 2.0))
	_shops_left -= 1
	_block_shops += 1
	_stats["shops"] += 1


# --- More shops in the free spaces ------------------------------------------------------------------------------
## One more shop in a block that has room left (a park, a gap), the front to the nearest
## north or south street, until EXTRA_SHOPS are put.
func _extra_shops() -> void:
	var left := EXTRA_SHOPS
	var half := _shop_size * 0.5
	var order := range(_block_list.size())
	# Spread them over the city: every third block first, then the others.
	var picked: Array = []
	for pass_i in 3:
		for i in order:
			if i % 3 == pass_i:
				picked.append(i)
	for i in picked:
		if left <= 0:
			break
		var r: Rect2 = _block_list[i]
		if _dist(r.get_center()) > 80.0:
			continue
		var near: Array[Rect2] = []
		for q in _rects:
			if q.intersects(r.grow(1.0)):
				near.append(q)
		var y := r.position.y + half.y
		var done := false
		while y <= r.end.y - half.y and not done:
			var x := r.position.x + half.x
			while x <= r.end.x - half.x:
				var p := Vector2(x, y)
				var box := Rect2(p - half - Vector2(0.2, 0.2), _shop_size + Vector2(0.4, 0.4))
				var free := true
				for q in near:
					if q.intersects(box):
						free = false
						break
				if free and _land_box(p, half) and not keep_out(p, maxf(half.x, half.y) + 0.3) 						and not _near_extra(p, half.x + 0.5):
					var face := _south_or_east(Vector2(0, 1) if p.y < r.get_center().y else Vector2(0, -1))
					_items.append({"shop": CityShops.shop_id_at(int(p.x * 4.0), int(p.y * 4.0)), "at": p, "dir": face, "scale": _shop_scale(), "city": true})
					_rects.append(Rect2(p - half, _shop_size))
					_stats["shops"] += 1
					left -= 1
					done = true
					break
				x += 0.5
			y += 0.5


# --- Shops in the place of houses ---------------------------------------------------------------------------
## Takes the houses and flats (footprint up to 3.1) of the city, farthest apart first: each
## shop replaces the house it stands on and any neighbour its footprint touches.
func _convert_to_shops() -> void:
	var cand: Array[int] = []
	for i in _items.size():
		var e := _items[i]
		if e.has("cat") and e.has("city") and float(e.get("fit", 9.0)) <= 3.1 and _dist(e["at"]) > CORE_R:
			cand.append(i)
	var mind := PackedFloat32Array()
	mind.resize(cand.size())
	for k in cand.size():
		mind[k] = INF
	var gone := {}
	var made: Array[Dictionary] = []
	var pick := 0 if not cand.is_empty() else -1
	var count := 0
	while count < CONVERTED_SHOPS and pick >= 0:
		var e := _items[cand[pick]]
		var at: Vector2 = e["at"]
		mind[pick] = -1.0
		if gone.has(cand[pick]):
			pick = _farthest(cand, mind, gone, at)
			continue
		var east := count % 2 == 1
		var size := Vector2(_shop_size.y, _shop_size.x) if east else _shop_size
		var box := Rect2(at - size * 0.5 - Vector2(0.15, 0.15), size + Vector2(0.3, 0.3))
		var ok := _land_box(at, size * 0.5)
		var touched: Array[int] = []
		for k in cand.size():
			if gone.has(cand[k]) or k == pick:
				continue
			var o := _items[cand[k]]
			var f := float(o["fit"])
			if Rect2((o["at"] as Vector2) - Vector2(f, f) * 0.5, Vector2(f, f)).intersects(box):
				touched.append(cand[k])
		if ok:
			gone[cand[pick]] = true
			for t in touched:
				gone[t] = true
			made.append({"shop": CityShops.shop_id_at(int(at.x * 4.0), int(at.y * 4.0)), "at": at, "dir": Vector2(1, 0) if east else Vector2(0, 1),
					"scale": _shop_scale(), "city": true})
			_stats["shops"] += 1
			count += 1
		pick = _farthest(cand, mind, gone, at)
	var kept: Array[Dictionary] = []
	for i in _items.size():
		if not gone.has(i):
			kept.append(_items[i])
	_items = kept
	_items.append_array(made)


## Index (in `cand`) of the candidate farthest from `from` and from the earlier ones, not gone.
func _farthest(cand: Array[int], mind: PackedFloat32Array, gone: Dictionary, from: Vector2) -> int:
	var best := -1
	var best_d := -1.0
	for k in cand.size():
		if mind[k] < 0.0 or gone.has(cand[k]):
			continue
		var d := (_items[cand[k]]["at"] as Vector2).distance_to(from)
		mind[k] = minf(mind[k], d)
		if mind[k] > best_d:
			best_d = mind[k]
			best = k
	return best


# --- The shop ---------------------------------------------------------------------------------------------------
func _load_shop() -> void:
	for s in MapShops.catalog():
		if s["id"] == SHOP_ID:  # the main shop sets the footprint of the others too
			var k := _shop_scale()
			_shop_size = Vector2(float(s["width"]) * k, float(s["depth"]) * k)


## The shops look south or east, like the one of the development island: a front to the
## north turns south, a front to the west turns east.
func _south_or_east(face: Vector2) -> Vector2:
	if face.y < -0.5:
		return Vector2(0, 1)
	if face.x < -0.5:
		return Vector2(1, 0)
	return face


func _shop_scale() -> float:
	return ShopSites.CELLS_PER_METRE * float(ShopSites.SCALE.get(SHOP_ID, 1.0))


# --- Cars ----------------------------------------------------------------------------------------------------------
## Parked along the east-west streets: every few cells, on the side of the street, nose along it.
func _cars() -> void:
	for y in _ys:
		var x := _xs[0] + 6.0
		var side := 1.0
		while x < _xs[_xs.size() - 1] - 4.0:
			var p := Vector2(x, y + 0.55 * side)
			if _land(p) and not keep_out(p, 0.8) and not _near_extra(p, 1.2) and _dist(p) < 70.0:
				var on_x_street := false
				for sx in _xs:
					if absf(sx - p.x) < 1.8:
						on_x_street = true
				if not on_x_street:
					_items.append({"veh": FogBaseSites.CARS[_car_n % FogBaseSites.CARS.size()], "at": p,
							"dir": Vector2(1, 0) if side > 0.0 else Vector2(-1, 0), "city": true})
					_car_n += 1
					_stats["cars"] += 1
			x += 17.0 + float((_car_n * 7) % 5)
			side = -side
