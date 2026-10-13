class_name PortRework
extends RefCounted
## Eighteenth wave, the last change to the finished map (after MapRetouch):
##   - every hotel gets its own model of HOTEL_MODELS (one model per building); hotels are
##     added in the city when there are fewer hotels than models;
##   - the industrial zone and port of the main island lose their old factories and Kenney
##     sheds and most container yards (the KEEP_YARDS nearest the crane stay); each model of
##     PORT_MODELS then gets its own lot there, the big ones first, beside a street when it can;
##   - hand changes to some lots of the port (PORT_DELETED, PORT_MOVED, PORT_ADDED), the city's
##     radio tower drawn with the port's radio tower model, billboards turned round;
##   - the offshore oil rig stands at sea off the port, sheds float on the high seas.
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
## The rig stands this many cells off the coast at least, as near the port as it can (seen
## from the quays).
const OIL_RIG_OFFSHORE := 8

## Hand changes to the lots of the port, once every model has its lot (`_hand_edits`). A
## model stands once in the port, so its name says which building is meant.
const PORT_DELETED := ["port_towers.glb: tower_tank_3", "port_tanks.glb: factory_brick",
		"port_halls.glb: hall_hangar", "port_towers.glb: tower_tank_1", "port_halls.glb: hall_warehouse_4",
		"port_sheds.glb: shed_works_2", "port_towers.glb: tower_tank_2", "port_towers.glb: tower_tank_4",
		"port_sheds.glb: shed_station"]
## [model, lot, facing]: the lot a model moves to (the building on it before goes).
const PORT_MOVED := [
	# The power plant takes the place of warehouse 1, hall 10 the place of the power plant.
	["port_halls.glb: hall_powerplant", Rect2i(114, 234, 4, 7), 2],
	["port_halls.glb: hall_building_10", Rect2i(125, 257, 4, 7), 2],
	# Three water tanks in a line going north, turned east, beside the water tower.
	["port_towers.glb: tower_tank_5", Rect2i(110, 239, 1, 1), 1],
	# The rusty tank joins the old ones as the third of their row, now in the walled empty square
	# north of the old row (x 114-117, y 254-255): two rows of old tanks lying east-west, the
	# rusty tank at their east end.
	["port_tanks.glb: tank_rusty", Rect2i(117, 254, 1, 2), 1],
	["port_tanks.glb: tank_old", Rect2i(114, 255, 3, 1), 1],
	# The tower crane takes the place of the small shed 4.
	["port_towers.glb: tower_crane", Rect2i(116, 262, 2, 2), 1],
	# The big tank takes the place of shed 4; four more stand beside it (TANK_FARM).
	["port_tanks.glb: tank_big", Rect2i(107, 244, 3, 3), 2],
]
## The buildings the moved ones replace.
const PORT_REPLACED := ["port_halls.glb: hall_warehouse_1", "port_sheds.glb: shed_generic_4",
		"port_sheds.glb: shed_small_4"]
## [model, lot, facing]: more of a model of the port.
const PORT_ADDED := [
	# The old tanks (three silos each) doubled into a rectangle (the walled square, see PORT_MOVED).
	["port_tanks.glb: tank_old", Rect2i(114, 254, 3, 1), 1],
	# Three long tanks side by side, three duplex sheds one behind the other.
	["port_tanks.glb: tank_long", Rect2i(137, 264, 1, 2), 1],
	["port_tanks.glb: tank_long", Rect2i(138, 264, 1, 2), 1],
	["port_sheds.glb: shed_duplex", Rect2i(120, 270, 3, 1), 2],
	["port_sheds.glb: shed_duplex", Rect2i(120, 272, 3, 1), 2],
	["port_towers.glb: tower_tank_5", Rect2i(110, 238, 1, 1), 1],
	["port_towers.glb: tower_tank_5", Rect2i(110, 237, 1, 1), 1],
	# A second water tower where the big tower tank stood in the south-east.
	["port_towers.glb: tower_water", Rect2i(141, 257, 2, 2), 2],
	# TANK_FARM: a column of three big tanks and one of two beside it.
	["port_tanks.glb: tank_big", Rect2i(107, 241, 3, 3), 2],
	["port_tanks.glb: tank_big", Rect2i(107, 238, 3, 3), 2],
	["port_tanks.glb: tank_big", Rect2i(104, 241, 3, 3), 2],
	["port_tanks.glb: tank_big", Rect2i(104, 238, 3, 3), 2],
]
## The radio tower of the port becomes the radio tower of the city (the TELECOM_TOWER at
## RADIO_TOWER_AT), drawn RADIO_TOWER_SCALE times its own size.
const RADIO_TOWER := "port_towers.glb: tower_radio"
const RADIO_TOWER_AT := Vector2i(104, 184)
const RADIO_TOWER_SCALE := 2.0
## The construction crane of the quay (top-left cell of its lot) moves beside the loading bay shed.
const CRANE_MOVED := [Vector2i(123, 277), Rect2i(126, 244, 2, 2)]
## Billboards turned round: top-left cell of the lot, new facing (0 N, 1 E, 2 S, 3 W).
const BILLBOARDS_TURNED := [[Vector2i(167, 200), 0]]
## Sheds of the port (pontoons) out on the high seas: model, how many, lot, how far apart.
## The pontoons at sea are boats (they were drawn as sheds and looked like buildings).
const SEA_SHED := "boat_wooden.glb: boat_wooden"
const SEA_SHEDS := 6
const SEA_SHED_LOT := Vector2i(4, 2)
const SEA_SHED_APART := 70.0
const SEA_SHED_OFFSHORE := 16
## Sea sheds taken away by hand (top-left cell of the lot). The shed at (130, 340) goes to the
## lighthouse island (LighthouseIsland).
const SEA_SHED_DELETED := [Vector2i(80, 92)]
## The oil rig is moved, once the sheds are placed (so that they stay where they were), to the
## open sea nearest to this cell: the other side of the island, off its east coast.
const OIL_RIG_NEAR := Vector2(300, 265)

var _d: CityData
var _grid := PackedByteArray()
var _center := Vector2.ZERO
var _radius := Vector2.ONE


## Returns {"hotels": n models given, "hotels_added": n, "removed": n, "yards_removed": n,
## "placed": n, "missing": n, "hand": n changes, "oil_rig": 0 or 1, "sea_sheds": n}.
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
	out["hand"] = p._hand_edits()
	p._mark()
	out["oil_rig"] = p._oil_rig()
	out["sea_sheds"] = p._sea_sheds()
	out["sea_hand"] = p._hand_sea()
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


# --- Hand edits ---------------------------------------------------------------------------------
## Applies PORT_DELETED, PORT_REPLACED, PORT_MOVED and PORT_ADDED, gives the city's radio tower
## the model of the port's one and turns BILLBOARDS_TURNED. Returns how many changes were made.
func _hand_edits() -> int:
	var done := 0
	for m in PORT_DELETED + PORT_REPLACED + [RADIO_TOWER]:
		var b := _port_building(m)
		if b >= 0:
			_d.b_kind[b] = Kind.EMPTY
			_d.b_model.erase(b)
			done += 1
	for e in PORT_MOVED:
		var b := _port_building(e[0])
		if b >= 0:
			_d.set_building_rect(b, e[1])
			_d.b_facing[b] = e[2]
			done += 1
	for e in PORT_ADDED:
		var b := _d.add_building(e[1], Kind.INDUSTRIAL, e[2], 1, 0.5)
		_d.b_model[b] = e[0]
		done += 1
	for b in _d.building_count():
		var at := _d.building_rect(b).position
		if _d.b_kind[b] == Kind.TELECOM_TOWER and at == RADIO_TOWER_AT:
			_d.b_model[b] = RADIO_TOWER
			_d.b_scale[b] = RADIO_TOWER_SCALE
			done += 1
		elif _d.b_kind[b] == Kind.CRANE and at == CRANE_MOVED[0]:
			_d.set_building_rect(b, CRANE_MOVED[1])
			done += 1
		elif _d.b_kind[b] == Kind.BILLBOARD:
			for t in BILLBOARDS_TURNED:
				if at == t[0]:
					_d.b_facing[b] = t[1]
					done += 1
	return done


## The standing building drawn with `model` (each model has one lot in the port), -1 if none.
func _port_building(model: String) -> int:
	for b in _d.building_count():
		if _d.b_kind[b] != Kind.EMPTY and _d.b_model.get(b, "") == model:
			return b
	return -1


# --- At sea -------------------------------------------------------------------------------------
## SEA_SHEDS pontoon sheds on the high seas: the spots of open water farthest from any coast,
## SEA_SHED_APART from each other and from the oil rig. Returns how many were placed.
func _sea_sheds() -> int:
	var dist := _sea_distance()
	var n := _d.size
	var taken: Array[Vector2] = []
	for b in _d.building_count():
		if _d.b_model.get(b, "") == OIL_RIG:
			taken.append(Vector2(_d.building_rect(b).get_center()))
	var cells: Array[Vector2i] = []
	for y in range(0, n - SEA_SHED_LOT.y):
		for x in range(0, n - SEA_SHED_LOT.x):
			if dist[_d.idx(x, y)] >= SEA_SHED_OFFSHORE:
				cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := dist[_d.idx(a.x, a.y)]
		var db := dist[_d.idx(b.x, b.y)]
		return da > db or (da == db and CityTypes.hash2(a.x, a.y, 613) < CityTypes.hash2(b.x, b.y, 613)))
	var placed := 0
	for c in cells:
		if placed >= SEA_SHEDS:
			break
		var r := Rect2i(c, SEA_SHED_LOT)
		var at := Vector2(r.get_center())
		if not taken.all(func(q: Vector2) -> bool: return q.distance_to(at) >= SEA_SHED_APART):
			continue
		if not _open_sea(r.grow(OIL_RIG_SEA)):
			continue
		var b := _d.add_building(r, Kind.BOAT, 2, 0, 0.5)
		_d.b_model[b] = SEA_SHED
		_stamp(r)
		taken.append(at)
		placed += 1
	if placed < SEA_SHEDS:
		push_warning("[Port] only %d of the %d sheds at sea" % [placed, SEA_SHEDS])
	return placed


## Deletes the sheds of SEA_SHED_DELETED and moves the oil rig to the spot nearest to OIL_RIG_NEAR.
func _hand_sea() -> int:
	var done := 0
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.BOAT and _d.b_model.get(b, "") == SEA_SHED \
				and SEA_SHED_DELETED.has(_d.building_rect(b).position):
			_d.b_kind[b] = Kind.EMPTY
			_d.b_model.erase(b)
			done += 1
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.BOAT and _d.b_model.get(b, "") == OIL_RIG:
			_d.b_kind[b] = Kind.EMPTY
			_mark()
			var spot := _rig_spot(OIL_RIG_NEAR)
			_d.b_kind[b] = Kind.BOAT
			if spot.size.x == 0:
				push_warning("[Port] no open sea for the oil rig on the other side")
			else:
				_d.set_building_rect(b, spot)
				done += 1
			_mark()
			break
	return done


## The oil rig: at sea, OIL_RIG_OFFSHORE cells off the coast at least, as near the port as it
## can stand, so that it is seen from the quays.
func _oil_rig() -> int:
	var best := _rig_spot(_center)
	if best.size.x == 0:
		push_warning("[Port] no open sea for the oil rig")
		return 0
	var b := _d.add_building(best, Kind.BOAT, 2, 0, 0.5)
	_d.b_model[b] = OIL_RIG
	_stamp(best)
	return 1


## The lot of the oil rig nearest to `near`: open sea all round, OIL_RIG_OFFSHORE cells off the
## coast at least; the empty rectangle when there is none.
func _rig_spot(near: Vector2) -> Rect2i:
	var n := _d.size
	var dist := _sea_distance()
	var best := Rect2i()
	var best_d := INF
	for y in range(0, n - OIL_RIG_LOT.y):
		for x in range(0, n - OIL_RIG_LOT.x):
			var c := Vector2i(x + OIL_RIG_LOT.x / 2, y + OIL_RIG_LOT.y / 2)
			if dist[_d.idx(c.x, c.y)] < OIL_RIG_OFFSHORE:
				continue
			var d := Vector2(c).distance_to(near)
			if d < best_d:
				var r := Rect2i(Vector2i(x, y), OIL_RIG_LOT)
				if _open_sea(r.grow(OIL_RIG_SEA)):
					best_d = d
					best = r
	return best


## Cells of open water to the nearest coast (island, quay, building at sea or edge of the
## map), 0 on them.
func _sea_distance() -> PackedInt32Array:
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
	return dist


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
