class_name PortRework
extends RefCounted
## Eighteenth wave, the last change to the finished map (after MapRetouch):
##   - every hotel gets its own model of HOTEL_MODELS (one model per building); hotels are
##     added in the city when there are fewer hotels than models;
##   - the industrial zone and port of the main island lose their old factories and Kenney
##     sheds and most container yards (the KEEP_YARDS nearest the crane stay); each model of
##     PORT_MODELS then gets its own lot there, the big ones first, beside a street when it can;
##   - the offshore oil rig stands at sea off the port.
## Nothing is random: the order of the lists and the distances decide.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

const HOTEL_MODELS := ["hotel_low.glb: hotel_orange", "hotel_small_night.glb: hotel_small",
		"hotel_stars_night.glb: hotel_stars", "hotels.glb: hotel_tower"]
const HOTEL_SIZE := Vector2i(3, 3)
const HOTEL_ZONES: Array[int] = [Zone.COMMERCIAL, Zone.DOWNTOWN, Zone.APARTMENT, Zone.ENTERTAINMENT]
const HOTEL_APART := 30.0

## Model and lot (cells, x by z with the building facing south), biggest first. The lots are
## the footprints of the models (tools/build_wave16_models.py) rounded up.
const PORT_MODELS := [
	["port_halls.glb: hall_building_10", Vector2i(4, 7)],
	["port_halls.glb: hall_factory_1", Vector2i(4, 7)],
	["port_halls.glb: hall_powerplant", Vector2i(4, 7)],
	["port_halls.glb: hall_hangar", Vector2i(5, 5)],
	["port_halls.glb: hall_factory_2", Vector2i(2, 7)],
	["port_halls.glb: hall_building_1", Vector2i(3, 5)],
	["port_halls.glb: hall_warehouse_5", Vector2i(3, 5)],
	["port_tanks.glb: factory_brick", Vector2i(4, 3)],
	["port_halls.glb: hall_terminal", Vector2i(5, 2)],
	["port_halls.glb: hall_warehouse_4", Vector2i(4, 2)],
	["port_halls.glb: hall_warehouse_1", Vector2i(4, 2)],
	["port_sheds.glb: shed_warehouse_3", Vector2i(3, 3)],
	["port_towers.glb: tower_tank_2", Vector2i(3, 3)],
	["port_tanks.glb: tank_big", Vector2i(3, 3)],
	["port_sheds.glb: shed_generic_4", Vector2i(4, 2)],
	["port_sheds.glb: shed_works_1", Vector2i(3, 2)],
	["port_sheds.glb: shed_works_2", Vector2i(3, 2)],
	["port_tanks.glb: tank_spheres", Vector2i(3, 2)],
	["port_sheds.glb: shed_loadbay", Vector2i(2, 3)],
	["port_towers.glb: tower_crane", Vector2i(2, 3)],
	["port_tanks.glb: tank_old", Vector2i(1, 3)],
	["port_towers.glb: tower_tank_1", Vector2i(2, 2)],
	["port_towers.glb: tower_water", Vector2i(2, 2)],
	["port_sheds.glb: shed_generic_3", Vector2i(2, 2)],
	["port_sheds.glb: shed_duplex", Vector2i(3, 1)],
	["port_tanks.glb: tank_rusty", Vector2i(3, 1)],
	["port_sheds.glb: shed_small_4", Vector2i(1, 2)],
	["port_sheds.glb: shed_trailer", Vector2i(2, 1)],
	["port_sheds.glb: shed_station", Vector2i(2, 1)],
	["port_tanks.glb: tank_long", Vector2i(2, 1)],
	["port_tanks.glb: tank_oil", Vector2i(2, 1)],
	["port_towers.glb: tower_tank_3", Vector2i(1, 1)],
	["port_towers.glb: tower_tank_4", Vector2i(1, 1)],
	["port_towers.glb: tower_tank_5", Vector2i(1, 1)],
	["port_towers.glb: tower_silo", Vector2i(1, 1)],
	["port_towers.glb: tower_radio", Vector2i(1, 1)],
	["port_towers.glb: tower_hut", Vector2i(1, 1)],
]
## The industrial blob grown by this much is the port area.
const AREA_GROW := 1.15
## Container yards that stay, the nearest to the crane of the quay.
const KEEP_YARDS := 32
## Free cells kept round every new lot (streets count as free).
const GAP := 1
const OIL_RIG := "oil_rig.glb: oil_rig"
const OIL_RIG_LOT := Vector2i(5, 6)
## Open sea all round the rig, in cells.
const OIL_RIG_SEA := 3

var _d: CityData
var _grid := PackedByteArray()
var _center := Vector2.ZERO
var _radius := Vector2.ONE


## Returns {"hotels": n models given, "hotels_added": n, "removed": n, "yards_removed": n,
## "placed": n, "missing": n, "oil_rig": 0 or 1}.
static func apply(data: CityData) -> Dictionary:
	var p := PortRework.new()
	p._d = data
	var blob := MapLayout.blob("industrial")
	p._center = blob["at"]
	p._radius = (blob["r"] as Vector2) * AREA_GROW
	var out := p._hotels()
	out.merge(p._clear())
	p._mark()
	out["placed"] = p._place()
	out["missing"] = PORT_MODELS.size() - out["placed"]
	out["oil_rig"] = p._oil_rig()
	return out


# --- Hotels ------------------------------------------------------------------------------------
func _hotels() -> Dictionary:
	var hotels: Array[int] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.HOTEL:
			hotels.append(b)
	var added := 0
	if hotels.size() < HOTEL_MODELS.size():
		_mark()
		for r in _hotel_spots(HOTEL_MODELS.size() - hotels.size(), hotels):
			hotels.append(_d.add_building(r, Kind.HOTEL, 2, 0, 0.5))
			_stamp(r)
			added += 1
	for k in mini(hotels.size(), HOTEL_MODELS.size()):
		_d.b_model[hotels[k]] = HOTEL_MODELS[k]
	if hotels.size() < HOTEL_MODELS.size():
		push_warning("[Port] only %d hotels for %d hotel models" % [hotels.size(), HOTEL_MODELS.size()])
	return {"hotels": mini(hotels.size(), HOTEL_MODELS.size()), "hotels_added": added}


## Bare 3x3 plots in the city beside a street, far from each other and from the hotels.
func _hotel_spots(count: int, hotels: Array[int]) -> Array[Rect2i]:
	var points: Array[Vector2] = []
	for b in hotels:
		points.append(Vector2(_d.building_rect(b).get_center()))
	var cands: Array[Rect2i] = []
	for y in range(1, _d.size - HOTEL_SIZE.y - 1):
		for x in range(1, _d.size - HOTEL_SIZE.x - 1):
			var r := Rect2i(Vector2i(x, y), HOTEL_SIZE)
			if HOTEL_ZONES.has(int(_d.zone[_d.idx(x, y)])) and _bare(r, HOTEL_ZONES) and _by_street(r):
				cands.append(r)
	cands.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return CityTypes.hash2(a.position.x, a.position.y, 907) < CityTypes.hash2(b.position.x, b.position.y, 907))
	var out: Array[Rect2i] = []
	for r in cands:
		if out.size() >= count:
			break
		var c := Vector2(r.get_center())
		if points.all(func(q: Vector2) -> bool: return q.distance_to(c) >= HOTEL_APART):
			out.append(r)
			points.append(c)
			_stamp(r)
	return out


# --- Industrial zone ---------------------------------------------------------------------------
## True when the cell is in the port area of the main island.
func _in_area(c: Vector2i) -> bool:
	var v := (Vector2(c) + Vector2(0.5, 0.5) - _center) / _radius
	return v.length_squared() <= 1.0 and _d.zone_at(c.x, c.y) == Zone.INDUSTRIAL \
			and not MapLayout.on_urban_island(c)


## Takes away the old factories and sheds and the yards far from the crane.
func _clear() -> Dictionary:
	var crane := _center
	var best := INF
	for b in _d.building_count():
		var c := _d.building_rect(b).get_center()
		if _d.b_kind[b] == Kind.CRANE and _in_area(c) and Vector2(c).distance_to(_center) < best:
			best = Vector2(c).distance_to(_center)
			crane = Vector2(c)
	var removed := 0
	var yards: Array[int] = []
	for b in _d.building_count():
		var k: int = _d.b_kind[b]
		var r := _d.building_rect(b)
		if not _in_area(r.position):
			continue
		if k == Kind.FACTORY_BLDG or (k == Kind.INDUSTRIAL and _d.b_model.get(b, "") != MapAdditions.SILO_MODEL):
			_d.b_kind[b] = Kind.EMPTY
			_d.b_model.erase(b)
			removed += 1
		elif k == Kind.INDUSTRIAL_YARD:
			yards.append(b)
	yards.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(_d.building_rect(a).get_center()).distance_to(crane) \
				< Vector2(_d.building_rect(b).get_center()).distance_to(crane))
	for k in range(KEEP_YARDS, yards.size()):
		_d.b_kind[yards[k]] = Kind.EMPTY
	return {"removed": removed, "yards_removed": maxi(0, yards.size() - KEEP_YARDS)}


## Each model on its own lot: the free rectangle of the area nearest to its centre, beside a
## street when there is one, with GAP free cells round it.
func _place() -> int:
	var cells: Array[Vector2i] = []
	var lo := Vector2i(_center - _radius)
	var hi := Vector2i(_center + _radius) + Vector2i.ONE
	for y in range(maxi(1, lo.y), mini(_d.size - 1, hi.y)):
		for x in range(maxi(1, lo.x), mini(_d.size - 1, hi.x)):
			if _in_area(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	var placed := 0
	for m in PORT_MODELS:
		var size: Vector2i = m[1]
		var best := Rect2i()
		var best_score := INF
		for c in cells:
			for s in [size, Vector2i(size.y, size.x)]:
				var r := Rect2i(c, s)
				if not _free_lot(r):
					continue
				var score := Vector2(r.get_center()).distance_to(_center) + (0.0 if _by_street(r) else 8.0)
				if score < best_score:
					best_score = score
					best = r
				if s.x == s.y:
					break
		if best.size.x == 0:
			push_warning("[Port] no room for %s" % m[0])
			continue
		var turned: bool = best.size != size
		var b := _d.add_building(best, Kind.INDUSTRIAL, 1 if turned else 2, 1, 0.5)
		_d.b_model[b] = m[0]
		_stamp(best.grow(GAP))
		placed += 1
	return placed


## Every cell of `r` is dry land of the area, free and without road; the cells round it are
## free of buildings too.
func _free_lot(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _d.in_bounds(x, y) or not _in_area(Vector2i(x, y)):
				return false
			var i := _d.idx(x, y)
			if _grid[i] != 0 or _d.road[i] != 0 or _d.terrain[i] != Terrain.LAND:
				return false
	var g := r.grow(GAP)
	for y in range(g.position.y, g.end.y):
		for x in range(g.position.x, g.end.x):
			if _d.in_bounds(x, y) and _grid[_d.idx(x, y)] == 1:
				return false
	return true


# --- The oil rig --------------------------------------------------------------------------------
## At sea, on the spot of open water farthest from any coast (island, quay or edge of the map).
func _oil_rig() -> int:
	var n := _d.size
	var dist := PackedInt32Array()
	dist.resize(n * n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for y in n:
		for x in n:
			var i := _d.idx(x, y)
			if _d.terrain[i] != Terrain.DEEP or _grid[i] != 0 or x == 0 or y == 0 or x == n - 1 or y == n - 1:
				dist[i] = 0
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % n
		var y := i / n
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + o.x
			var ny: int = y + o.y
			if nx < 0 or ny < 0 or nx >= n or ny >= n:
				continue
			var j := _d.idx(nx, ny)
			if dist[j] < 0:
				dist[j] = dist[i] + 1
				queue.append(j)
	var best := Rect2i()
	var best_d := 0
	for y in range(0, n - OIL_RIG_LOT.y):
		for x in range(0, n - OIL_RIG_LOT.x):
			var c := Vector2i(x + OIL_RIG_LOT.x / 2, y + OIL_RIG_LOT.y / 2)
			var d := dist[_d.idx(c.x, c.y)]
			if d > best_d:
				var r := Rect2i(Vector2i(x, y), OIL_RIG_LOT)
				if _open_sea(r.grow(OIL_RIG_SEA)):
					best_d = d
					best = r
	if best.size.x == 0:
		push_warning("[Port] no open sea for the oil rig")
		return 0
	var b := _d.add_building(best, Kind.BOAT, 2, 0, 0.5)
	_d.b_model[b] = OIL_RIG
	return 1


func _open_sea(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _d.in_bounds(x, y):
				return false
			var i := _d.idx(x, y)
			if _d.terrain[i] != Terrain.DEEP or _grid[i] != 0:
				return false
	return true


# --- Grid ---------------------------------------------------------------------------------------
## 1 on every cell of a standing building (and of a lot deleted by hand).
func _mark() -> void:
	_grid = PackedByteArray()
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


## True when every cell of `r` is dry land of `zones` with no road, building or park detail.
func _bare(r: Rect2i, zones: Array[int]) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := _d.idx(x, y)
			if _d.terrain[i] != Terrain.LAND or _d.road[i] != 0 or _grid[i] != 0 or _d.deco[i] != 0 \
					or not zones.has(int(_d.zone[i])):
				return false
	return true


## True when a street runs along one side of `r`.
func _by_street(r: Rect2i) -> bool:
	for x in range(r.position.x, r.end.x):
		if _d.is_road(x, r.position.y - 1) or _d.is_road(x, r.end.y):
			return true
	for y in range(r.position.y, r.end.y):
		if _d.is_road(r.position.x - 1, y) or _d.is_road(r.end.x, y):
			return true
	return false
