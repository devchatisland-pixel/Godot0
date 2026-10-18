class_name UrbanSkyline
extends RefCounted
## The urban island as it stands now: nothing but the towers of the night city skyline pack
## (Cat.NIGHT_SKYLINE, 13 buildings), in rows along three parallel roads that run the whole
## length of the island. It runs after MapOverhaul has emptied the island:
##   - every street of the island is taken away;
##   - one road crosses the island from the landing of the metal bridge, and three roads run
##     north-south, ROAD_STEP columns apart, as far as the land goes: they all meet the first;
##   - the land between and beside the roads is cut in strips STRIP cells deep (ten of them), every
##     second strip is left empty, and each other strip is filled from north to south with towers standing wall to wall: the lot of a tower is
##     as deep as the strip and as long as the model asks, and BuildingPlacer stretches the
##     model over the whole lot, so the only gaps are the roads.
## Which tower stands where comes from the hash of the cell: the same island on every device.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

const PACK := "skyline_towers.glb: sky_%02d"
## Footprint (x, z) of the 13 towers of the pack, in cells (tools/curate_spec_wave15.json).
const TOWERS: Array[Vector2] = [
	Vector2(3.5, 3.5), Vector2(3.5, 3.74), Vector2(2.75, 3.09), Vector2(3.41, 3.14), Vector2(4.27, 5.38),
	Vector2(2.82, 3.72), Vector2(4.64, 4.64), Vector2(4.17, 4.19), Vector2(3.5, 3.47), Vector2(2.86, 2.87),
	Vector2(4.08, 3.94), Vector2(5.38, 4.27), Vector2(2.43, 2.43),
]
## Depth of a row of towers (cells, across the island) and the length a lot may have.
const STRIP := 4
const LOT_LENGTH := Vector2i(3, 6)
## Columns between two of the three roads: two rows of towers back to back, and the road.
const ROAD_STEP := 2 * STRIP + 1
## Rows of towers on the outer side of the first and the last road.
const OUTER_STRIPS := 3
const SALT := 7301
## West column of the strip that stays full (the tower of cell 67,195); the strips of the island
## alternate full and empty from it.
const KEEP_STRIP_X := 67

var _d: CityData
## 1 on the dry land of the island.
var _land := PackedByteArray()
## 1 where a tower stands.
var _used := PackedByteArray()


## Returns {"roads": cells, "towers": n}.
static func apply(data: CityData) -> Dictionary:
	var s := UrbanSkyline.new()
	s._d = data
	return s._run()


func _run() -> Dictionary:
	var lo := Vector2i(_d.size, _d.size)
	var hi := Vector2i(-1, -1)
	var sum := 0
	var n := 0
	_land.resize(_d.size * _d.size)
	_used.resize(_d.size * _d.size)
	for y in _d.size:
		for x in _d.size:
			var i := _d.idx(x, y)
			if _d.terrain[i] != Terrain.LAND or not MapLayout.on_urban_island(Vector2i(x, y)):
				continue
			_land[i] = 1
			_d.road[i] = 0
			_d.deco[i] = 0
			_d.zone[i] = Zone.URBAN
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			sum += x
			n += 1
	if n == 0:
		return {"roads": 0, "towers": 0}
	var mid := roundi(float(sum) / float(n))
	var columns: Array[int] = [mid - ROAD_STEP, mid, mid + ROAD_STEP]
	var row := _d.west_bridge.z if _d.west_bridge.x >= 0 else (lo.y + hi.y) / 2
	var roads := _roads(columns, row, hi)
	# Left column of each row of towers, from west to east.
	var strips: Array[int] = []
	for k in range(OUTER_STRIPS, 0, -1):
		strips.append(columns[0] - k * STRIP)
	for c in columns:
		strips.append(c + 1)
		if c != columns[2]:
			strips.append(c + 1 + STRIP)
	for k in range(1, OUTER_STRIPS):
		strips.append(columns[2] + 1 + k * STRIP)
	# One strip full, the next one empty, and so on: the strip that starts at KEEP_STRIP_X
	# (its tower at 67,195) stays, so every second strip from it is full.
	var keep := strips.find(KEEP_STRIP_X)
	if keep < 0:
		push_warning("[UrbanSkyline] no strip starts at column %d: %s" % [KEEP_STRIP_X, strips])
		keep = 0
	var towers := 0
	for k in strips.size():
		if posmod(k - keep, 2) == 0:
			towers += _fill_strip(strips[k], lo.y, hi.y)
	return {"roads": roads, "towers": towers}


## The road from the bridge across the island on `row`, and the three roads of `columns`
## from one end of the land to the other. Returns the number of road cells.
func _roads(columns: Array[int], row: int, hi: Vector2i) -> int:
	var n := 0
	var east := _d.west_bridge.y if _d.west_bridge.x >= 0 else hi.x
	for x in range(columns[0], east + 1):
		if _is_land(x, row):
			n += _road(x, row)
	for c in columns:
		for dir in [-1, 1]:
			var y: int = row
			while _is_land(c, y):
				n += _road(c, y)
				y += dir
	return n


func _road(x: int, y: int) -> int:
	var i := _d.idx(x, y)
	if _d.road[i] != 0:
		return 0
	_d.road[i] = CityTypes.ROAD_STREET
	return 1


func _is_land(x: int, y: int) -> bool:
	return _d.in_bounds(x, y) and _land[_d.idx(x, y)] == 1


## Towers one after the other down the strip whose west column is `x`. Returns how many.
func _fill_strip(x: int, y0: int, y1: int) -> int:
	var n := 0
	var y := y0
	var last := -1
	while y <= y1:
		var t := CityTypes.hash2(x, y, SALT) % TOWERS.size()
		if t == last:
			t = (t + 1) % TOWERS.size()
		# The lot is as deep as the strip; its length keeps the shape of the model.
		var fp := TOWERS[t]
		var length := clampi(roundi(float(STRIP) * fp.y / fp.x), LOT_LENGTH.x, LOT_LENGTH.y)
		var placed := false
		for l in [length, LOT_LENGTH.x]:
			var r := Rect2i(x, y, STRIP, l)
			if _free(r):
				_add(r, t)
				y += l
				last = t
				n += 1
				placed = true
				break
		if not placed:
			y += 1
	return n


func _free(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _is_land(x, y):
				return false
			var i := _d.idx(x, y)
			if _d.road[i] != 0 or _used[i] == 1:
				return false
	return true


func _add(r: Rect2i, tower: int) -> void:
	var b := _d.add_building(r, Kind.SKYLINE_BLDG, 1, tower, 1.0)
	_d.b_model[b] = PACK % (tower + 1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_used[_d.idx(x, y)] = 1
