class_name MapStretch
extends RefCounted
## The main island grows to the south: empty rows are slipped in between the rows of lots of the
## south of the city and of the red district, and everything of the main island below them moves
## down (the coast with it). Run last, once every building and road is final: the hand edits keep
## naming the cells of the map before the stretch (`cell` turns such a cell into the new one).
##
## Only the columns of the main island move, and in each of them only down to its south coast
## (plus a margin of sea): the open sea right below is dropped to make room, so the other islands
## and the islets further south stay where they are.
## A slipped-in row copies the ground of the row above it; a road goes on through it only where it
## runs north-south (road above and below), and no tree grows on it in the city.

const Terrain := CityTypes.Terrain
const Zone := CityTypes.Zone

## Rows before which one empty row is slipped in: rows where no street runs east-west, so no lot
## loses its street (south of the city, then the red district).
const INSERTS: Array[int] = [204, 208, 226, 227, 244, 250, 285, 286, 289, 290, 291, 296]
## A cell of the main island (the flood that finds its columns starts there).
const MAIN_CELL := Vector2i(190, 200)
## Sea rows kept under the south coast of each column before the dropped rows.
const MARGIN := 3
## Zones whose slipped-in rows keep the trees of the row above (forests and fields).
const WILD: Array[int] = [Zone.NATURE, Zone.FARM, Zone.SAND]

## Column range of the main island and, for each of its columns, the last row that moves.
static var _x0 := -1
static var _x1 := -1
static var _end := PackedInt32Array()


## Cell of the map before the stretch -> cell after it.
static func cell(c: Vector2i) -> Vector2i:
	if _x0 < 0 or c.x < _x0 or c.x > _x1 or c.y > _end[c.x - _x0]:
		return c
	return Vector2i(c.x, c.y + _below(c.y))


## How many rows are slipped in at or above row `y`.
static func _below(y: int) -> int:
	var n := 0
	for r in INSERTS:
		if r <= y:
			n += 1
	return n


static func apply(data: CityData) -> Dictionary:
	var k := INSERTS.size()
	var main := _main_island(data)
	_x0 = data.size
	_x1 = -1
	var coast := {}
	for i in main.size():
		if main[i] == 1:
			var x := i % data.size
			_x0 = mini(_x0, x)
			_x1 = maxi(_x1, x)
			coast[x] = maxi(int(coast.get(x, 0)), i / data.size)
	if _x1 < 0:
		push_warning("[Stretch] no main island at %s" % MAIN_CELL)
		return {}
	# Each column moves down to its coast, past its last building (piers), plus the margin; the
	# k rows under that must be open sea with nothing on them, else the end goes further down.
	_end = PackedInt32Array()
	_end.resize(_x1 - _x0 + 1)
	var bottom := PackedInt32Array()
	bottom.resize(data.size)
	for b in data.building_count():
		if data.b_kind[b] == CityTypes.Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for x in range(r.position.x, r.end.x):
			if x >= _x0 and x <= _x1 and r.position.y <= int(coast.get(x, -1)) + MARGIN:
				bottom[x] = maxi(bottom[x], r.end.y - 1)
	var pushed := 0
	for x in range(_x0, _x1 + 1):
		var e := maxi(int(coast.get(x, INSERTS[0])), bottom[x]) + MARGIN
		while e + k < data.size and not _open_sea(data, x, e + 1, k):
			e += 1
			pushed += 1
		if e + k >= data.size:
			push_warning("[Stretch] no open sea under column %d" % x)
			e = data.size - k - 1
		_end[x - _x0] = e
	# The ground, column by column.
	var arrays := [data.terrain, data.zone, data.road, data.elevation, data.forest, data.rocky,
			data.deco, data.edge]
	for x in range(_x0, _x1 + 1):
		var e: int = _end[x - _x0]
		for a in arrays.size():
			arrays[a] = _stretch_column(data, arrays[a], a, x, e)
	data.terrain = arrays[0]
	data.zone = arrays[1]
	data.road = arrays[2]
	data.elevation = arrays[3]
	data.forest = arrays[4]
	data.rocky = arrays[5]
	data.deco = arrays[6]
	data.edge = arrays[7]
	# The buildings: moved down, and taller by the rows slipped in across them.
	var moved := 0
	for b in data.building_count():
		var r := data.building_rect(b)
		if r.position.x < _x0 or r.position.x > _x1 or r.position.y > _end[r.position.x - _x0]:
			continue
		var top := r.position.y + _below(r.position.y)
		var bot := (r.end.y - 1) + _below(r.end.y - 1)
		if top != r.position.y or bot - top + 1 != r.size.y:
			data.set_building_rect(b, Rect2i(r.position.x, top, r.size.x, bot - top + 1))
			moved += 1
	if data.bridge.x >= 0:
		data.bridge = cell(data.bridge)
	for i in data.centers.size():
		var c: Vector2 = data.centers[i]
		data.centers[i] = Vector2(cell(Vector2i(c))) + (c - Vector2(Vector2i(c)))
	return {"rows": k, "columns": _x1 - _x0 + 1, "buildings_moved": moved, "ends_pushed": pushed}


## 1 on the cells of the main island (land and roads joined to MAIN_CELL).
static func _main_island(data: CityData) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(data.size * data.size)
	var stack: Array[Vector2i] = [MAIN_CELL]
	seen[data.idx(MAIN_CELL.x, MAIN_CELL.y)] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for o in CityTypes.FACING_OFFSETS:
			var n: Vector2i = c + o
			if not data.in_bounds(n.x, n.y) or seen[data.idx(n.x, n.y)] == 1:
				continue
			if data.is_land(n.x, n.y) or data.is_road(n.x, n.y):
				seen[data.idx(n.x, n.y)] = 1
				stack.append(n)
	return seen


## True when the `count` cells of column `x` from row `y` down are deep sea with no building.
static func _open_sea(data: CityData, x: int, y: int, count: int) -> bool:
	for yy in range(y, y + count):
		if not data.in_bounds(x, yy) or data.terrain[data.idx(x, yy)] != Terrain.DEEP:
			return false
		if data.road[data.idx(x, yy)] != 0:
			return false
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.EMPTY and data.building_rect(b).intersects(Rect2i(x, y, 1, count)):
			return false
	return true


## Column `x` of array `a` (index `which` in the list of apply) with the rows slipped in, down to
## row `e`; the rows under `e` are kept, less the ones the stretch pushed out.
static func _stretch_column(data: CityData, a: PackedByteArray, which: int, x: int, e: int) -> PackedByteArray:
	var n := data.size
	var col := PackedByteArray()
	var zone_col := PackedByteArray()
	for y in n:
		col.append(a[y * n + x])
		zone_col.append(data.zone[y * n + x])
	var out := PackedByteArray()
	var extra := 0
	for r in INSERTS:
		if r > e:
			extra += 1
	for y in e + 1:
		if INSERTS.has(y) and y > 0:
			out.append(_slipped(data, col, zone_col, which, x, y))
		out.append(col[y])
	# The rows slipped in under the coast of this column go at its end (open sea).
	for i in extra:
		out.append(col[e])
	# Rows past the end that were not pushed out stay where they were.
	var y2 := out.size()
	while y2 < n:
		out.append(col[y2])
		y2 += 1
	for y in n:
		a[y * n + x] = out[y]
	return a


## The value of a slipped-in cell, before row `y` of the column.
static func _slipped(data: CityData, col: PackedByteArray, zone_col: PackedByteArray, which: int, x: int, y: int) -> int:
	match which:
		2: # road: only where it runs north-south through the gap
			return col[y - 1] if col[y - 1] != 0 and col[y] != 0 else 0
		4: # forest: only in the wild
			return col[y - 1] if WILD.has(int(zone_col[y - 1])) else 0
		6: # deco
			return 0
		_:
			return col[y - 1]
