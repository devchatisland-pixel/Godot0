class_name MapAdditions
extends RefCounted
## Buildings added to the finished map, after MapOverhaul (and so after BuildingBudget has
## counted the others):
##   - CHURCHES low poly churches in the main city, each on the lot nearest to a chosen place;
##   - one tall tower in the little Las Vegas with the neon woman sign on its roof;
##   - the poor district gets its ghetto look: its panel blocks are redrawn with the three
##     blackthorn towers and the ten buildings of the "Buildings" pack, each one a few times;
##   - downtown gets denser: its cleared and low lots become Kenney skyscrapers.
## Nothing is random: lots are picked by distance or by the hash of their cell.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

const CHURCH_MODEL := "church_low.glb: church_low"
## Where the three churches stand (the lot nearest to each cell).
const CHURCHES: Array[Vector2i] = [Vector2i(206, 142), Vector2i(262, 172), Vector2i(196, 216)]
## Kinds a church or the neon tower may replace.
const ORDINARY: Array[int] = [Kind.HOUSE, Kind.SHOP, Kind.APARTMENT, Kind.OFFICE, Kind.QUARTER_BLDG,
		Kind.GARDEN, Kind.PLAZA, Kind.EMPTY]
## How far from its place a church may stand (cells).
const CHURCH_REACH := 16.0

## The neon tower: the Las Vegas lot nearest to this cell.
const NEON_TOWER_NEAR := Vector2i(134, 176)

## Models of the ghetto: library name, footprint (x, z) in cells, smallest and largest scale.
const GHETTO := [
	["urban.glb: tower0", Vector2(1.75, 1.8), 0.7, 1.15],
	["urban.glb: tower5", Vector2(3.6, 1.45), 0.7, 1.15],
	["urban.glb: tower6", Vector2(1.68, 3.4), 0.7, 1.15],
	["ny_street.glb: ny_street_01_b", Vector2(1.6, 1.18), 1.0, 1.7],
	["ny_street.glb: ny_street_02_b", Vector2(1.6, 0.92), 1.0, 1.7],
	["ny_street.glb: ny_street_03_b", Vector2(1.6, 1.1), 1.0, 1.7],
	["ny_street.glb: ny_street_04_b", Vector2(1.6, 0.9), 1.0, 1.7],
	["ny_street.glb: ny_street_05_b", Vector2(1.6, 1.14), 1.0, 1.7],
	["ny_street.glb: ny_street_06_b", Vector2(1.6, 1.31), 1.0, 1.7],
	["ny_street.glb: ny_street_07_b", Vector2(1.6, 1.03), 1.0, 1.7],
	["ny_street.glb: ny_street_08_b", Vector2(1.6, 1.04), 1.0, 1.7],
	["ny_street.glb: ny_street_09_b", Vector2(1.6, 1.44), 1.0, 1.7],
	["ny_street.glb: ny_street_10_b", Vector2(1.6, 0.89), 1.0, 1.7],
]
## How many times each model replaces a panel block, and how many more go on cleared lots.
const GHETTO_USES := 2
const GHETTO_EXTRA := 1

## The oil silos of the port: model, how many stand side by side, lot of each, scale.
const SILO_MODEL := "silo.glb: silo"
const SILOS := 3
const SILO_LOT := 2
const SILO_SCALE := 0.85

## Kinds of downtown that become skyscrapers (with the cleared lots).
const LOW_DOWNTOWN: Array[int] = [Kind.OFFICE, Kind.SHOP, Kind.APARTMENT, Kind.PLAZA, Kind.GARDEN]
## Bits of the seed ModelPools reads as "roll": all set, the tower is a Kenney skyscraper.
const KENNEY_ROLL := 1023 << 12

var _d: CityData
## Building id + 1 on every cell of a standing building.
var _grid := PackedInt32Array()


## Returns {"churches": n, "neon_tower": n, "ghetto": n, "skyscrapers": n}.
static func apply(data: CityData) -> Dictionary:
	var a := MapAdditions.new()
	a._d = data
	a._mark()
	var out := {}
	out["churches"] = a._churches()
	out["neon_tower"] = a._neon_tower()
	out["ghetto"] = a._ghetto()
	out["skyscrapers"] = a._skyscrapers()
	out["silos"] = a._silos()
	return out


func _mark() -> void:
	_grid.resize(_d.size * _d.size)
	for b in _d.building_count():
		var k: int = _d.b_kind[b]
		if k != Kind.EMPTY and k != Kind.BALLOON:
			_stamp(b)


func _stamp(b: int) -> void:
	var r := _d.building_rect(b)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _d.in_bounds(x, y):
				_grid[_d.idx(x, y)] = b + 1


## True when lot `b` can take a new building: a standing one, or a cleared lot (not one
## deleted by hand) whose ground is still land without road or building.
func _usable(b: int) -> bool:
	if ManualEdits.hand_deleted.has(b) or ManualEdits.resolved.values().has(b) or _d.b_sign[b] != 0:
		return false
	if _d.b_kind[b] != Kind.EMPTY:
		return true
	var r := _d.building_rect(b)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _d.is_land(x, y) or _d.road[_d.idx(x, y)] != 0 or _grid[_d.idx(x, y)] != 0:
				return false
	return true


func _zone(b: int) -> int:
	var r := _d.building_rect(b)
	return _d.zone[_d.idx(r.position.x, r.position.y)]


## The usable lot of `kinds` nearest to `cell` (within `reach`) whose sides are within
## `sides` (x = shortest allowed, y = longest allowed), in one of `zones` (empty = any).
func _nearest_lot(cell: Vector2i, reach: float, kinds: Array[int], sides: Vector2i, zones: Array[int]) -> int:
	var best := -1
	var best_d := reach
	for b in _d.building_count():
		if not kinds.has(int(_d.b_kind[b])):
			continue
		var r := _d.building_rect(b)
		if mini(r.size.x, r.size.y) < sides.x or maxi(r.size.x, r.size.y) > sides.y:
			continue
		if not zones.is_empty() and not zones.has(_zone(b)):
			continue
		var d := Vector2(r.get_center()).distance_to(Vector2(cell))
		if d < best_d and _usable(b):
			best_d = d
			best = b
	return best


# --- Churches --------------------------------------------------------------------------------
func _churches() -> int:
	var n := 0
	for cell in CHURCHES:
		var b := _nearest_lot(cell, CHURCH_REACH, ORDINARY, Vector2i(2, 5), [])
		if b < 0:
			push_warning("[Additions] no lot for a church near %s" % cell)
			continue
		var r := _d.building_rect(b)
		_d.b_kind[b] = Kind.CHURCH
		_d.b_model[b] = CHURCH_MODEL
		_d.b_scale[b] = 1.0
		# The church is long: along the long side of its lot, its front to the south or the east.
		_d.b_facing[b] = 2 if r.size.x >= r.size.y else 1
		_stamp(b)
		n += 1
	return n


# --- Neon tower of Las Vegas ---------------------------------------------------------------------
func _neon_tower() -> int:
	var kinds: Array[int] = [Kind.OFFICE, Kind.SHOP, Kind.NIGHTCLUB, Kind.EMPTY]
	var b := _nearest_lot(NEON_TOWER_NEAR, 40.0, kinds, Vector2i(3, 4), [Zone.ENTERTAINMENT])
	if b < 0:
		push_warning("[Additions] no lot for the neon tower")
		return 0
	_d.b_kind[b] = Kind.SKYSCRAPER
	_d.b_seed[b] = _d.b_seed[b] | KENNEY_ROLL
	_d.b_height[b] = 1.0
	_d.b_scale[b] = 1.0
	_d.b_facing[b] = 2
	_d.b_model.erase(b)
	_d.b_sign[b] = ModelCatalog.Cat.NEON_WOMAN
	_d.b_sign_facing[b] = 2
	_stamp(b)
	return 1


# --- Ghetto ------------------------------------------------------------------------------------------
func _ghetto() -> int:
	var blocks: Array[int] = []
	var cleared: Array[int] = []
	for b in _d.building_count():
		if _zone(b) != Zone.POOR or not _usable(b):
			continue
		if _d.b_kind[b] == Kind.POOR_BLDG:
			blocks.append(b)
		elif _d.b_kind[b] == Kind.EMPTY and mini(_d.building_rect(b).size.x, _d.building_rect(b).size.y) >= 2:
			cleared.append(b)
	return _dress(blocks, GHETTO_USES) + _dress(cleared, GHETTO_EXTRA)


## Gives every ghetto model to `uses` lots of `lots` (in the order of the hash of their cell):
## the lot the model fits best in. Returns how many lots changed.
func _dress(lots: Array[int], uses: int) -> int:
	lots.sort_custom(func(a: int, b: int) -> bool:
		var pa := _d.building_rect(a).position
		var pb := _d.building_rect(b).position
		return CityTypes.hash2(pa.x, pa.y, 61) < CityTypes.hash2(pb.x, pb.y, 61))
	var n := 0
	for u in uses:
		for g in GHETTO:
			var best := -1
			var best_fit := 0.0
			for k in lots.size():
				var fit := _fit(lots[k], g[1])
				# The first lot the model fits in at full size, else the one it fits best in.
				if fit > best_fit:
					best_fit = fit
					best = k
				if fit >= float(g[3]):
					break
			if best < 0:
				return n
			var b: int = lots[best]
			lots.remove_at(best)
			_d.b_kind[b] = Kind.POOR_BLDG
			_d.b_model[b] = g[0]
			_d.b_scale[b] = -clampf(best_fit, float(g[2]), float(g[3])) # absolute scale
			_stamp(b)
			n += 1
	return n


## Largest scale at which a model of footprint `fp` (x, z) fits in lot `b`, turned as it faces.
func _fit(b: int, fp: Vector2) -> float:
	var r := _d.building_rect(b)
	var f := Vector2(fp.y, fp.x) if int(_d.b_facing[b]) % 2 == 1 else fp
	return minf(r.size.x * 0.94 / f.x, r.size.y * 0.94 / f.y)


# --- Downtown -----------------------------------------------------------------------------------------
func _skyscrapers() -> int:
	var n := 0
	for b in _d.building_count():
		var k: int = _d.b_kind[b]
		if _zone(b) != Zone.DOWNTOWN or not (k == Kind.EMPTY or LOW_DOWNTOWN.has(k)):
			continue
		var r := _d.building_rect(b)
		if mini(r.size.x, r.size.y) < 2 or not _usable(b):
			continue
		_d.b_kind[b] = Kind.SKYSCRAPER
		_d.b_seed[b] = _d.b_seed[b] | KENNEY_ROLL
		_d.b_height[b] = maxf(_d.b_height[b], 0.45 + 0.4 * CityTypes.hashf(r.position.x, r.position.y, 71))
		_d.b_scale[b] = 1.0
		_d.b_model.erase(b)
		_stamp(b)
		n += 1
	return n


# --- Oil silos ---------------------------------------------------------------------------------------------
## SILOS oil silos in a row on the free ground nearest to the container yards of the port.
func _silos() -> int:
	var sum := Vector2.ZERO
	var yards := 0
	for b in _d.building_count():
		var c := _d.building_rect(b).get_center()
		if _d.b_kind[b] == Kind.INDUSTRIAL_YARD and not MapLayout.on_urban_island(c):
			sum += Vector2(c)
			yards += 1
	if yards == 0:
		return 0
	var port := sum / float(yards)
	var size := Vector2i(SILOS * SILO_LOT, SILO_LOT)
	var best := Rect2i()
	var best_d := INF
	for y in range(int(port.y) - 40, int(port.y) + 40):
		for x in range(int(port.x) - 40, int(port.x) + 40):
			var r := Rect2i(x, y, size.x, size.y)
			var d := (Vector2(r.position) + Vector2(r.size) * 0.5).distance_to(port)
			if d < best_d and _bare(r):
				best_d = d
				best = r
	if best.size.x == 0:
		push_warning("[Additions] no room for the oil silos")
		return 0
	for k in SILOS:
		var b := _d.add_building(Rect2i(best.position + Vector2i(k * SILO_LOT, 0), Vector2i(SILO_LOT, SILO_LOT)),
				Kind.INDUSTRIAL, 2, 1, 0.5)
		_d.b_model[b] = SILO_MODEL
		_d.b_scale[b] = -SILO_SCALE
		_stamp(b)
	return SILOS


## True when every cell of `r` is dry land with no road and no building.
func _bare(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _d.in_bounds(x, y):
				return false
			var i := _d.idx(x, y)
			if _d.terrain[i] != CityTypes.Terrain.LAND or _d.road[i] != 0 or _grid[i] != 0:
				return false
	return true
