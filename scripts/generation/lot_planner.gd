class_name LotPlanner
extends RefCounted
## Cuts every block into lots and decides what kind of building stands on each.
## Lots that do not touch a road become courtyards, gardens or yards.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind

## Lot size range (min, max) in cells per zone.
const LOT_SIZES := {
	Zone.DOWNTOWN: Vector2i(2, 3),
	Zone.COMMERCIAL: Vector2i(1, 2),
	Zone.APARTMENT: Vector2i(2, 2),
	Zone.SUBURBAN: Vector2i(2, 2),
	Zone.INDUSTRIAL: Vector2i(2, 3),
	Zone.ENTERTAINMENT: Vector2i(1, 4),
	Zone.QUARTER: Vector2i(2, 3),
	Zone.POOR: Vector2i(2, 3),
	Zone.URBAN: Vector2i(2, 3),
}

## Share of the lots in the middle of the urban island that get a futuristic tower.
const FUTURE_SHARE := 0.2

var _cfg: CityConfig
var _data: CityData
var _districts: DistrictPlanner
var _rng: RandomNumberGenerator

## Building id per cell (-1 = free). Used by the service planner.
var owner := PackedInt32Array()


func _init(cfg: CityConfig, data: CityData, districts: DistrictPlanner,
		rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_data = data
	_districts = districts
	_rng = rng
	owner.resize(data.size * data.size)
	owner.fill(-1)


## `rng` replaces the shared random numbers for this call (the urban island has its own).
func build(blocks: Array[Rect2i], zones: PackedByteArray, rng: RandomNumberGenerator = null) -> void:
	var shared := _rng
	if rng != null:
		_rng = rng
	for b in blocks.size():
		var z: int = zones[b]
		if LOT_SIZES.has(z):
			var lots: Array[Rect2i] = []
			var range_: Vector2i = LOT_SIZES[z]
			if z == Zone.URBAN and _urban_core(blocks[b].get_center()):
				range_ = Vector2i(3, 3) # big lots for the futuristic towers in the middle
			_split_lots(blocks[b], range_, lots)
			for lot in lots:
				_add_lot(lot, z)
	_rng = shared


## True in the middle of the urban island (where the futuristic towers stand).
func _urban_core(c: Vector2i) -> bool:
	var u: Dictionary = ExtensionIsland.URBAN
	var at: Vector2 = u["at"]
	var r: Vector2 = u["r"]
	return Vector2((c.x - at.x) / r.x, (c.y - at.y) / r.y).length() < 0.92


# --- Subdivision --------------------------------------------------------------------
func _split_lots(r: Rect2i, range_: Vector2i, out: Array[Rect2i]) -> void:
	var mn := range_.x
	var mx := range_.y
	if r.size.x <= mx and r.size.y <= mx:
		out.append(r)
		return
	var along_x := r.size.x >= r.size.y
	var length := r.size.x if along_x else r.size.y
	if length < mn * 2:
		out.append(r)
		return
	var cut := _rng.randi_range(mn, mini(mx, length - mn))
	if along_x:
		_split_lots(Rect2i(r.position.x, r.position.y, cut, r.size.y), range_, out)
		_split_lots(Rect2i(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y), range_, out)
	else:
		_split_lots(Rect2i(r.position.x, r.position.y, r.size.x, cut), range_, out)
		_split_lots(Rect2i(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut), range_, out)


# --- Lots -----------------------------------------------------------------------------
func _add_lot(lot: Rect2i, zone: int) -> void:
	if not _all_land(lot):
		return
	var c := Vector2(lot.get_center())
	var d := _districts.intensity(c.x, c.y)
	var facing := road_facing(_data, lot, _rng.randi())
	var seed := _rng.randi()
	var kind := _pick_kind(zone, lot, d, facing, seed)
	if zone == Zone.URBAN:
		facing = _urban_facing(lot, seed)
	elif kind == Kind.SHOP:
		# Shops show their front to the camera (an east or south street side when there is one).
		var visible := road_facing(_data, lot, seed >> 4, true)
		if visible >= 0:
			facing = visible
	var id := _data.add_building(lot, kind, maxi(facing, 0), seed, d)
	mark(lot, id)


## Towers of the urban island show their front to the camera: east or south, towards the
## street when one runs there (never north or west, whatever the street says).
func _urban_facing(lot: Rect2i, seed: int) -> int:
	var f := road_facing(_data, lot, seed >> 4, true)
	if f == 1 or f == 2:
		return f
	return 1 if (seed >> 7) & 1 == 1 else 2


func _pick_kind(zone: int, lot: Rect2i, d: float, facing: int, seed: int) -> int:
	var h := float(seed & 0xffff) / 65536.0
	var area := lot.get_area()
	if zone == Zone.URBAN:
		# Towers of three packs (ModelPools), with a few futuristic ones in the middle (3x3 lots).
		if mini(lot.size.x, lot.size.y) >= 3 and _urban_core(lot.get_center()) and h < FUTURE_SHARE:
			return Kind.FUTURE_BLDG
		return Kind.URBAN_BLDG
	if facing < 0: # no road access: courtyard
		match zone:
			Zone.INDUSTRIAL: return Kind.INDUSTRIAL_YARD
			Zone.SUBURBAN, Zone.APARTMENT, Zone.QUARTER, Zone.POOR: return Kind.GARDEN
			_: return Kind.PLAZA if h < 0.6 else Kind.GARDEN
	match zone:
		Zone.DOWNTOWN:
			# The only skyscraper district of the island.
			if h < 0.06:
				return Kind.PLAZA # small squares between the towers
			if mini(lot.size.x, lot.size.y) >= 2:
				return Kind.SKYSCRAPER
			return Kind.OFFICE
		Zone.COMMERCIAL:
			return Kind.OFFICE if area >= 4 and h < 0.3 else Kind.SHOP
		Zone.ENTERTAINMENT:
			# Neon clubs of every size (bars to resorts), offices and shops in between.
			if h < (0.7 if mini(lot.size.x, lot.size.y) <= 1 else 0.55):
				return Kind.NIGHTCLUB
			return Kind.OFFICE if area >= 4 and h < 0.85 else Kind.SHOP
		Zone.APARTMENT:
			if area < 4:
				return Kind.SHOP
			# Older row houses remain between the apartment blocks, with more shops around.
			if h > 0.84:
				return Kind.SHOP
			return Kind.HOUSE if h < 0.3 else Kind.APARTMENT
		Zone.SUBURBAN:
			# Corner shops along the avenues of residential areas.
			if _faces_avenue(lot, facing) and h < 0.7:
				return Kind.SHOP
			if h > 0.93:
				return Kind.SHOP
			return Kind.HOUSE
		Zone.INDUSTRIAL:
			return Kind.INDUSTRIAL if area >= 4 else Kind.INDUSTRIAL_YARD
		Zone.QUARTER:
			return Kind.QUARTER_BLDG
		Zone.POOR:
			return Kind.POOR_BLDG if area >= 3 and h < 0.8 else Kind.SHOP
	return Kind.GARDEN


func _faces_avenue(lot: Rect2i, facing: int) -> bool:
	var p := _side_cell(lot, facing)
	return _data.in_bounds(p.x, p.y) and (_data.road[_data.idx(p.x, p.y)] & 3) == CityTypes.ROAD_AVENUE


# --- Helpers (also used by the service planner) -----------------------------------------
func mark(r: Rect2i, id: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			owner[y * _data.size + x] = id


func _all_land(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.terrain[i] != CityTypes.Terrain.LAND or _data.road[i] != 0 or owner[i] != -1:
				return false
	return true


## Facing (0..3) of the side of `r` that touches a road, -1 when none.
## Avenues are preferred; ties are broken with `pick`. With `visible`, a road
## on the east or south side wins: the camera sees those faces, so signs and
## entrances of landmarks are always in view.
static func road_facing(data: CityData, r: Rect2i, pick: int, visible: bool = false) -> int:
	var best := -1
	var best_score := 0
	for f in 4:
		var score := 0
		for p in _side_cells(r, f):
			if data.in_bounds(p.x, p.y):
				var v := data.road[data.idx(p.x, p.y)] & 3
				score += v * 4
		if score == 0:
			continue
		score += (pick >> (f * 3)) & 3
		if visible and (f == 1 or f == 2):
			score += 1000
		if score > best_score:
			best_score = score
			best = f
	return best


func _side_cell(r: Rect2i, facing: int) -> Vector2i:
	var cells := _side_cells(r, facing)
	return cells[cells.size() / 2]


static func _side_cells(r: Rect2i, facing: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match facing:
		0:
			for x in range(r.position.x, r.end.x): out.append(Vector2i(x, r.position.y - 1))
		1:
			for y in range(r.position.y, r.end.y): out.append(Vector2i(r.end.x, y))
		2:
			for x in range(r.position.x, r.end.x): out.append(Vector2i(x, r.end.y))
		_:
			for y in range(r.position.y, r.end.y): out.append(Vector2i(r.position.x - 1, y))
	return out
