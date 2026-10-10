class_name ExtensionRoads
extends RefCounted
## The roads of the extension: the two highways (east to the Golden Gate, west to
## the metal bridge), shortest-way links that join every new district to the old
## city, and the cross of streets of the industrial zone. `network` marks the
## cells that are connected to the old city.

const Terrain := CityTypes.Terrain
const Zone := CityTypes.Zone

var network := PackedByteArray()

var _data: CityData
var _island: ExtensionIsland
var _spots: ExtensionSpots


func _init(data: CityData, island: ExtensionIsland, spots: ExtensionSpots) -> void:
	_data = data
	_island = island
	_spots = spots


## Call once the new land is painted: the roads of the core are the network.
func begin() -> void:
	network = _data.road.duplicate()


# --- Highways -------------------------------------------------------------------------------
## East: three lanes wide, like the Golden Gate: from the end of the core's road
## to the coast. The bridge starts where the highway reaches the water.
func build_east_highway() -> void:
	var start := _data.bridge
	if start.x < 0:
		return
	var x := start.x
	var last := x
	# The lanes go on over the beach, so that the asphalt touches the bridge at the water.
	while x < _data.size - 2 and _data.terrain[_data.idx(x, start.y)] >= Terrain.BEACH:
		_lane(x, start.y, true)
		last = x
		x += 1
	_data.bridge = Vector2i(last + 1, start.y)
	# And into the city: the single road of the core is widened to three lanes as far as the
	# land beside it is free, up to the first street that crosses it.
	var w := start.x - 1
	while w > 0 and _data.road[_data.idx(w, start.y)] != 0:
		_lane(w, start.y, true)
		var m := _data.road_mask(w, start.y)
		if (m & CityTypes.DIR_N) != 0 or (m & CityTypes.DIR_S) != 0:
			break
		w -= 1


## West: from the west-most street of the core to the west coast, then over the
## metal bridge to the urban island. Rows are tried from the one with the
## west-most road; the way west of it must be free.
func build_west_highway() -> void:
	var rows := []
	for y in range(MapLayout.cells("west_highway_from"), MapLayout.cells("west_highway_to")):
		for x in range(_data.size):
			if _data.road[_data.idx(x, y)] != 0:
				rows.append([x, y])
				break
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for cand in rows:
		var y: int = cand[1]
		var x: int = cand[0]
		var coast := _clear_way_west(x, y)
		if coast < 0:
			continue
		for cx in range(coast, x):
			_lane(cx, y)
		# First land of the urban island on the same row (east coast of the island).
		var urban := -1
		for ux in range(coast - 2, 0, -1):
			if _data.terrain[_data.idx(ux, y)] == Terrain.LAND and _island.is_urban_island(ux, y):
				urban = ux
				break
		if urban < 0:
			return
		for ux in range(urban, maxi(urban - 12, 1), -1):
			if _data.terrain[_data.idx(ux, y)] == Terrain.LAND:
				_lane(ux, y)
		_data.west_bridge = Vector3i(coast, urban, y)
		return


## The last land column (west-most) of the way west from (x, y), or -1 when blocked.
func _clear_way_west(x: int, y: int) -> int:
	var last := -1
	for cx in range(x - 1, 0, -1):
		var i := _data.idx(cx, y)
		if _data.terrain[i] != Terrain.LAND:
			return last
		if not _spots.is_open(i) or _data.road[i] != 0:
			return -1
		last = cx
	return -1


## One column of the three-lane highway (the middle lane is the row itself).
func _lane(x: int, y: int, beach: bool = false) -> void:
	for dy in range(-1, 2):
		if not _data.in_bounds(x, y + dy):
			continue
		var i := _data.idx(x, y + dy)
		var dry: bool = _data.terrain[i] >= Terrain.BEACH if beach else _data.terrain[i] == Terrain.LAND
		if dry and _data.road[i] == 0 \
				and (_spots.is_open(i) or _data.zone[i] == Zone.URBAN):
			_data.road[i] = CityTypes.ROAD_AVENUE
			network[i] = 1


# --- Roads to the city ----------------------------------------------------------------------
func road_nearest_to_city(area: Rect2i) -> int:
	return _nearest(area, Vector2(_data.size, _data.size) * 0.5, true)


func land_nearest_to_city(area: Rect2i) -> int:
	return _nearest(area, Vector2(_data.size, _data.size) * 0.5, false)


## The road cell (or free farm cell) of `area` closest to `target`, -1 when none.
func _nearest(area: Rect2i, target: Vector2, want_road: bool) -> int:
	var best := -1
	var best_d := INF
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _data.in_bounds(x, y):
				continue
			var i := _data.idx(x, y)
			var ok := (_data.road[i] != 0 and network[i] == 0) if want_road \
					else (_data.terrain[i] == Terrain.LAND and _data.road[i] == 0 and _data.zone[i] == Zone.FARM)
			if ok:
				var d := target.distance_squared_to(Vector2(x, y))
				if d < best_d:
					best_d = d
					best = i
	return best


## Joins `start` to the road network with the shortest way over free land
## (breadth first search). Everything on the way becomes part of the network.
func link(start: int) -> void:
	if start < 0:
		return
	var n := _data.size * _data.size
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-2)
	prev[start] = -1
	var queue := PackedInt32Array([start])
	var head := 0
	var goal := -1
	while head < queue.size() and goal < 0:
		var cur := queue[head]
		head += 1
		var cx := cur % _data.size
		var cy := cur / _data.size
		for o in CityTypes.FACING_OFFSETS:
			var nx := cx + o.x
			var ny := cy + o.y
			if not _data.in_bounds(nx, ny):
				continue
			var ni := _data.idx(nx, ny)
			if prev[ni] != -2 or _data.terrain[ni] != Terrain.LAND:
				continue
			if network[ni] != 0:
				prev[ni] = cur
				goal = ni
				break
			if _data.road[ni] == 0 and not _link_zone(_data.zone[ni]):
				continue
			prev[ni] = cur
			queue.append(ni)
	if goal < 0:
		return
	var at := goal
	while at >= 0:
		if _data.road[at] == 0:
			_data.road[at] = CityTypes.ROAD_STREET
		network[at] = 1
		at = prev[at]


func _link_zone(z: int) -> bool:
	return z == Zone.NONE or z == Zone.NATURE or z == Zone.DESERT or z == Zone.FARM \
			or z == Zone.INDUSTRIAL or z == Zone.URBAN or z == Zone.SAND


## Every road cell of `mask` counts as connected (call after linking one of them).
func adopt(mask: PackedByteArray) -> void:
	for i in mask.size():
		if mask[i] == 1 and _data.road[i] != 0:
			network[i] = 1


## A cross of streets through the middle of a blob (the industrial zone).
func spines(b: Dictionary) -> void:
	var at: Vector2 = b["at"]
	var r: Vector2 = b["r"]
	for x in range(int(at.x - r.x), int(at.x + r.x) + 1):
		_street_cell(x, int(at.y), b)
	for y in range(int(at.y - r.y), int(at.y + r.y) + 1):
		_street_cell(int(at.x), y, b)


func _street_cell(x: int, y: int, b: Dictionary) -> void:
	var i := _data.idx(x, y)
	if _spots.in_blob(b, x, y) and _data.terrain[i] == Terrain.LAND and _data.road[i] == 0 \
			and _data.zone[i] == Zone.INDUSTRIAL:
		_data.road[i] = CityTypes.ROAD_STREET
		network[i] = 1
