class_name MapRetouch
extends RefCounted
## Third wave of changes to the finished map, after MapAdditions and the concert camp (and so
## after BuildingBudget has counted the buildings):
##   - TOWER_SIGNS: a logo or a neon sign on the east wall of towers of the urban island (one
##     has a second sign on its roof), CLUB_SIGNS: neon signs on the roofs of three clubs;
##   - TURNED: buildings turned by hand, KIND_FACING: every McDonald's faces east; the secret base is drawn BASE_SCALE times bigger (its
##     jets with it);
##   - BILLBOARDS more billboards and COURTS basketball courts in the city, each on bare ground
##     beside a street, far from each other.
## Nothing is random: spots are taken in the order of the hash of their cell. The fences of the
## prison and the secret base are drawn by MapFences.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

## Top-left cell of the lot of the tower, sign (a ModelCatalog.Cat; BuildingExtras.SIGNS). Only
## towers with no tower in front of their east wall carry a wall sign; the Taiwan signboards
## (TW_*) hang out of the wall from their brackets, the LED band wraps a free south-east corner.
const TOWER_SIGNS := [
	[Vector2i(71, 143), "SIGN_WINDOWS"],
	[Vector2i(63, 133), "NEON_JOYSTICK"],
	[Vector2i(67, 170), "NEON_FUN"],
	[Vector2i(67, 175), "NEON_PALM"],
	[Vector2i(63, 160), "TW_LED_BAND"],
	[Vector2i(71, 151), "TW_BANASONIC"],
	[Vector2i(67, 187), "TW_MCDONALDS"],
]
## Signs on the roof of a tower (above its wall sign, or alone on a tower that has a lower one in
## front of its east wall, so the sign shows over it): top-left cell, sign. They look east like the
## wall signs.
const TOWER_ROOF_SIGNS := [
	[Vector2i(67, 170), "NEON_MARTINI"],
	[Vector2i(71, 204), "NEON_BULL"],
	[Vector2i(67, 147), "TW_COLA_BILLBOARD"],
	# The board of the tower at (63, 186) stood unseen: it sits above the LED band of this one.
	[Vector2i(63, 160), "TW_LED_BOARD"],
]
## Roof signs of three Las Vegas clubs (top-left cell of the lot, sign), looking south.
const CLUB_SIGNS := [
	[Vector2i(122, 182), "NEON_CLUB"],
	[Vector2i(144, 202), "NEON_LOVE"],
]
## Signs flat on the east wall of a club (top-left cell of the lot, signs side by side from
## north to south).
const CLUB_WALL_SIGNS := [
	[Vector2i(134, 178), ["NEON_CLUB", "NEON_XXX", "NEON_WOMAN", "NEON_PLAYBOY"]],
]
## The steps of the supermarket jut out this share of its depth in front of its wall.
const CLUB_SIGN_INSET := 0.09
## Clubs drawn with another model (top-left cell of the lot, model): B-00023 is the supermarket
## without its texts (tools/clean_supermarket.py), its signs on the wall.
const CLUB_MODELS := [
	[Vector2i(134, 178), "supermarket.glb: supermarket"],
]
## The neon woman of the tower of Las Vegas (MapAdditions) moves to the east wall of this tower of the
## urban island (top-left cell of its lot), as wide as the wall (it took the place of the bar sign).
const WOMAN_TOWER := Vector2i(67, 195)
## The wall the signs hang on: east, towards the road and the camera (the towers stand wall
## to wall from north to south).
const SIGN_WALL := 1
## Kind, top-left cell of the lot, new facing.
const TURNED := []
## Kinds whose buildings all face the same way.
const KIND_FACING := {"MCDONALDS": 1}
const BASE_SCALE := 1.5

const CITY_ZONES: Array[int] = [Zone.DOWNTOWN, Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN,
		Zone.ENTERTAINMENT, Zone.QUARTER, Zone.POOR]
const BILLBOARDS := 10
const BILLBOARD_SIZE := Vector2i(3, 2)
## Cells between two billboards (the new ones and those that stand already).
const BILLBOARD_APART := 22.0
const COURTS := 2
const COURT_SIZE := Vector2i(3, 6)
const COURT_ZONES: Array[int] = [Zone.SUBURBAN, Zone.APARTMENT, Zone.QUARTER, Zone.COMMERCIAL]
const COURT_APART := 60.0

var _d: CityData
## 1 on every cell of a standing building and of a lot deleted by hand.
var _grid := PackedByteArray()


## Returns {"signs": n, "turned": n, "base": n, "billboards": n, "courts": n}.
static func apply(data: CityData) -> Dictionary:
	var m := MapRetouch.new()
	m._d = data
	m._mark()
	var out := {"signs": m._signs(), "turned": m._turned(), "base": m._base()}
	out["courts"] = m._courts()
	out["billboards"] = m._billboards()
	return out


func _mark() -> void:
	_grid.resize(_d.size * _d.size)
	for b in _d.building_count():
		var k: int = _d.b_kind[b]
		if (k != Kind.EMPTY and k != Kind.BALLOON) or ManualEdits.hand_deleted.has(b):
			_stamp(_d.building_rect(b))


func _stamp(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _d.in_bounds(x, y):
				_grid[_d.idx(x, y)] = 1


## The building of `kind` whose lot starts at `cell`, or -1.
func _at(kind: int, cell: Vector2i) -> int:
	for b in _d.building_count():
		if _d.b_kind[b] == kind and _d.building_rect(b).position == cell:
			return b
	return -1


func _signs() -> int:
	var n := 0
	for s in TOWER_SIGNS:
		var b := _at(Kind.SKYLINE_BLDG, s[0])
		if b < 0:
			push_warning("[Retouch] no tower at %s for its sign" % s[0])
			continue
		_d.b_sign[b] = ModelCatalog.Cat[s[1]]
		_d.b_sign_facing[b] = SIGN_WALL
		n += 1
	for s in TOWER_ROOF_SIGNS:
		var b := _at(Kind.SKYLINE_BLDG, s[0])
		if b < 0:
			push_warning("[Retouch] no tower at %s for its roof sign" % s[0])
			continue
		_d.b_sign_facing[b] = SIGN_WALL
		_d.b_more_signs[b] = [[ModelCatalog.Cat[s[1]], "roof"]]
		n += 1
	for s in CLUB_SIGNS:
		var b := _at(Kind.NIGHTCLUB, s[0])
		if b < 0:
			push_warning("[Retouch] no club at %s for its sign" % s[0])
			continue
		_d.b_sign[b] = ModelCatalog.Cat[s[1]]
		_d.b_sign_facing[b] = 2
		n += 1
	for s in CLUB_WALL_SIGNS:
		var b := _at(Kind.NIGHTCLUB, s[0])
		if b < 0:
			push_warning("[Retouch] no club at %s for its wall sign" % s[0])
			continue
		_d.b_sign_facing[b] = SIGN_WALL
		var signs: Array = s[1]
		var more := []
		for k in signs.size():
			more.append([ModelCatalog.Cat[signs[k]], "face", k, signs.size(), CLUB_SIGN_INSET])
		_d.b_more_signs[b] = more
		n += 1
	for c in CLUB_MODELS:
		var b := _at(Kind.NIGHTCLUB, c[0])
		if b < 0:
			push_warning("[Retouch] no club at %s for its model" % c[0])
			continue
		_d.b_model[b] = c[1]
	return n + _move_woman()


## The neon woman leaves the tower of Las Vegas for the east wall of WOMAN_TOWER.
func _move_woman() -> int:
	var to := _at(Kind.SKYLINE_BLDG, WOMAN_TOWER)
	if to < 0:
		push_warning("[Retouch] no tower at %s for the neon woman" % WOMAN_TOWER)
		return 0
	var old := -1
	for b in _d.building_count():
		if _d.b_sign[b] == ModelCatalog.Cat.NEON_WOMAN:
			old = b
	if old < 0:
		push_warning("[Retouch] no neon woman to move")
		return 0
	_d.b_sign[old] = 0
	_d.b_sign[to] = ModelCatalog.Cat.NEON_WOMAN
	_d.b_sign_facing[to] = SIGN_WALL
	return 1


func _turned() -> int:
	var n := 0
	for t in TURNED:
		var b := _at(Kind[t[0]], t[1])
		if b < 0:
			push_warning("[Retouch] no %s at %s to turn" % [t[0], t[1]])
			continue
		_d.b_facing[b] = t[2]
		n += 1
	for b in _d.building_count():
		var kind: String = Kind.keys()[_d.b_kind[b]]
		if KIND_FACING.has(kind) and _d.b_facing[b] != KIND_FACING[kind]:
			_d.b_facing[b] = KIND_FACING[kind]
			n += 1
	return n


func _base() -> int:
	var n := 0
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.AIRBASE:
			_d.b_scale[b] = BASE_SCALE
			n += 1
	return n


# --- Billboards, courts -----------------------------------------------------------------------
func _billboards() -> int:
	var taken: Array[Vector2] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.BILLBOARD:
			taken.append(Vector2(_d.building_rect(b).get_center()))
	var spots := _spots(BILLBOARD_SIZE, CITY_ZONES, BILLBOARDS, BILLBOARD_APART, 811, taken)
	for r in spots:
		_d.add_building(r, Kind.BILLBOARD, 2, _d.zone[_d.idx(r.position.x, r.position.y)], 0.5)
		_stamp(r)
	if spots.size() < BILLBOARDS:
		push_warning("[Retouch] only %d of the %d new billboards found a place" % [spots.size(), BILLBOARDS])
	return spots.size()


## A court is long: along the street when the ground is wide, else across it.
func _courts() -> int:
	var spots := _spots(COURT_SIZE, COURT_ZONES, COURTS, COURT_APART, 823, [])
	if spots.size() < COURTS:
		var wide := _spots(Vector2i(COURT_SIZE.y, COURT_SIZE.x), COURT_ZONES, COURTS - spots.size(), COURT_APART, 829,
				_centers(spots))
		spots.append_array(wide)
	for r in spots:
		_d.add_building(r, Kind.BASKET_COURT, 2 if r.size.y > r.size.x else 1, 0, 0.5)
		_stamp(r)
	if spots.size() < COURTS:
		push_warning("[Retouch] only %d of the %d basketball courts found a place" % [spots.size(), COURTS])
	return spots.size()


func _centers(rects: Array[Rect2i]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in rects:
		out.append(Vector2(r.position) + Vector2(r.size) * 0.5)
	return out


## Up to `count` bare rectangles of `size` on ground of `zones`, beside a street, at least
## `apart` cells from each other and from the points of `avoid`.
func _spots(size: Vector2i, zones: Array[int], count: int, apart: float, salt: int,
		avoid: Array[Vector2]) -> Array[Rect2i]:
	var cands: Array[Rect2i] = []
	for y in range(1, _d.size - size.y - 1):
		for x in range(1, _d.size - size.x - 1):
			if zones.has(int(_d.zone[_d.idx(x, y)])):
				var r := Rect2i(x, y, size.x, size.y)
				if _bare(r, zones) and _by_street(r):
					cands.append(r)
	cands.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return CityTypes.hash2(a.position.x, a.position.y, salt) < CityTypes.hash2(b.position.x, b.position.y, salt))
	var out: Array[Rect2i] = []
	var points := avoid.duplicate()
	for r in cands:
		if out.size() >= count:
			break
		var c := Vector2(r.position) + Vector2(r.size) * 0.5
		var far := true
		for p in points:
			if p.distance_to(c) < apart:
				far = false
				break
		if far:
			out.append(r)
			points.append(c)
	return out


## True when every cell of `r` is dry land of `zones` with no road, building or park detail.
func _bare(r: Rect2i, zones: Array[int]) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := _d.idx(x, y)
			if _d.terrain[i] != CityTypes.Terrain.LAND or _d.road[i] != 0 or _grid[i] != 0 or _d.deco[i] != 0 \
					or not zones.has(int(_d.zone[i])):
				return false
	return true


## True when a street runs along the south or the east side of `r` (the sides the camera sees).
func _by_street(r: Rect2i) -> bool:
	for x in range(r.position.x, r.end.x):
		if _d.is_road(x, r.end.y):
			return true
	for y in range(r.position.y, r.end.y):
		if _d.is_road(r.end.x, y):
			return true
	return false
