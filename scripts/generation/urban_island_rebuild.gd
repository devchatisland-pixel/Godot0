class_name UrbanIslandRebuild
extends RefCounted
## The urban island as it is finally built: the two nuclear plants on its north lobe and, all
## over the rest, rows of skyscrapers (the 13 towers of the night city skyline pack) along
## three parallel roads. It runs once the whole map is generated and the budget of the
## buildings is applied (CityGenerator), so no other district moves by a single cell:
##   - everything the planners put on the island is taken away (towers, yards and containers,
##     industry, the cooling hall, the fire truck, the billboard, the bus stops), and so are its
##     streets;
##   - the two plants keep their lots (PLANT_LOTS, else where as few cells as possible lie on
##     their line of sight to the camera), both facing south; AmenitiesPlanner fences them;
##   - streets: ROAD_COUNT roads down the length of the island, a cross street from the landing
##     of the metal bridge over all of them, a street joining their ends at the north and at
##     the south, a street along the front of each plant joined to the others, and a small
##     yard of containers and barrels beside the plant road;
##   - the towers (SKYLINE_TOWER) stand in rows on both sides of every road, with no gap
##     between two towers of a row: only the roads part them. On the line of sight of a plant
##     no tower is taller than what the camera (30 degrees down) still sees the plant over.
## The bridge itself stays (it is a model drawn from `CityData.west_bridge`).
## Only the cells of the island and the buildings standing on them are touched; `CityData`
## outside it is exactly what the other planners made.

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## Lot of each plant, in cells (the model is 15.5 x 4.4: it fills it at scale 1.09).
const PLANT_SIZE := Vector2i(18, 7)
## Cells either side of the line of sight of a plant where the towers are kept low.
const SIGHT_MARGIN := 1
## Height of the plant model, the slope of the camera ray (tan of the 30 degrees of pitch of
## CityConfig) and what of the plant may still be hidden, in cells.
const PLANT_TOP := 4.9
const VIEW_SLOPE := 0.5774
const HIDDEN_ALLOWED := 0.5
## The towers of the pack (night_skyline.glb): node, length of the lot along the road in cells
## (the models are 2.4 to 5.4 cells long) and height once the tower fills its lot, in cells.
const MODEL_PREFIX := "night_skyline.glb: "
const TOWERS := [
	["sky_01", 4, 16.5], ["sky_02", 4, 13.5], ["sky_03", 3, 9.5], ["sky_04", 5, 11.5],
	["sky_05", 4, 21.5], ["sky_06", 5, 12.5], ["sky_07", 3, 11.5], ["sky_08", 4, 5.7],
	["sky_09", 4, 17.9], ["sky_10", 3, 11.0], ["sky_11", 4, 6.3], ["sky_12", 5, 11.5],
	["sky_13", 3, 9.2],
]
## The parallel roads: how many, and the columns from one to the next (a road, then two rows
## of towers back to back).
const ROAD_COUNT := 3
const ROW_DEPTH := 4
const ROAD_STEP := 2 * ROW_DEPTH + 1
## Shortest lot of TOWERS along the road.
const MIN_LENGTH := 3
## Rows of towers behind each of the two outer roads, out to the coast.
const OUTER_ROWS := 3
## Cost of a cell of one plant that hides the other, in land cells of sight.
const HIDE_WEIGHT := 3.0
## No tower closer than this to a plant (cells).
const PLANT_AIR := 1
## Bare ground at the end of the metal bridge: columns before its head, rows either side.
const LANDING_COLUMNS := 5
const LANDING_ROWS := 2
## Salt of the hashes of this pass.
const SALT := 5101
## Where the two plants stand (cells of the final map): they keep their place when the land is
## there (ExtensionIsland keeps it).
const PLANT_LOTS: Array[Rect2i] = [Rect2i(53, 149, 18, 7), Rect2i(51, 139, 18, 7)]
## The yard by the plant road: lots (2x2) and their seeds (containers, then barrels: see
## BuildingExtras._place_yard).
const PLANT_YARD_SEEDS := [3 * 101, 3 * 211 + 1]


## Returns {"removed": n, "towers": n, "plants": [Rect2i], "land": cells}.
static func apply(data: CityData) -> Dictionary:
	var land := _island_land(data)
	var cells: Array[Vector2i] = []
	for i in land.size():
		if land[i] == 1:
			cells.append(Vector2i(i % data.size, i / data.size))
	if cells.is_empty():
		return {"removed": 0, "towers": 0, "plants": [], "land": 0}
	var out := {"removed": 0, "towers": 0, "plants": [], "land": cells.size()}
	var plants := _take_away(data, land, out)
	_clear_cells(data, cells)
	var rects := _place_plants(data, land, cells, plants)
	out["plants"] = rects
	out["streets"] = _build_streets(data, land, rects)
	out["yard"] = _plant_yard(data, land, rects)
	out["towers"] = _build_towers(data, land, cells, rects)
	return out


# --- The island --------------------------------------------------------------------------------
## 1 on the dry land of the urban island (the land of its ellipses, joined to the plant).
static func _island_land(data: CityData) -> PackedByteArray:
	var land := PackedByteArray()
	land.resize(data.size * data.size)
	var start := Vector2i(-1, -1)
	for b in data.building_count():
		if data.b_kind[b] == Kind.NUCLEAR_PLANT and MapLayout.on_urban_island(data.building_rect(b).get_center()):
			start = data.building_rect(b).get_center()
			break
	if start.x < 0:
		for y in data.size:
			for x in data.size:
				if start.x < 0 and _is_island_land(data, x, y):
					start = Vector2i(x, y)
	if start.x < 0 or not _is_island_land(data, start.x, start.y):
		return land
	var stack: Array[Vector2i] = [start]
	land[data.idx(start.x, start.y)] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = c + o
			if _is_island_land(data, q.x, q.y) and land[data.idx(q.x, q.y)] == 0:
				land[data.idx(q.x, q.y)] = 1
				stack.append(q)
	return land


static func _is_island_land(data: CityData, x: int, y: int) -> bool:
	return data.in_bounds(x, y) and data.terrain[data.idx(x, y)] == Terrain.LAND \
			and MapLayout.on_urban_island(Vector2i(x, y))


# --- Taking away ---------------------------------------------------------------------------------
## Clears every building that stands on the island, its beaches and its loose bits of land
## included (the lot stays in the list, empty: the numbers do not move). Returns the ids of the
## nuclear plants.
static func _take_away(data: CityData, land: PackedByteArray, out: Dictionary) -> Array[int]:
	var plants: Array[int] = []
	for b in data.building_count():
		var kind: int = data.b_kind[b]
		if kind == Kind.EMPTY:
			continue
		var c := data.building_rect(b).get_center()
		if not data.in_bounds(c.x, c.y) or not MapLayout.on_urban_island(c) 				or data.terrain[data.idx(c.x, c.y)] < Terrain.BEACH:
			continue
		if kind == Kind.NUCLEAR_PLANT:
			plants.append(b)
		else:
			data.b_kind[b] = Kind.EMPTY
			out["removed"] += 1
	return plants


## No street, no fence, no hand-made ground detail on the island; one zone all over.
static func _clear_cells(data: CityData, cells: Array[Vector2i]) -> void:
	for c in cells:
		var i := data.idx(c.x, c.y)
		data.road[i] = 0
		data.deco[i] = 0
		data.zone[i] = Zone.URBAN


# --- The plants -----------------------------------------------------------------------------------
## True when `(x, y)` lies on a line of sight from `rect` to the camera (south-east of it).
static func _in_front(rect: Rect2i, x: int, y: int, margin: int) -> bool:
	if x < rect.position.x - margin or y < rect.position.y - margin:
		return false
	var d := x - y
	return d >= rect.position.x - (rect.end.y - 1) - margin and d <= rect.end.x - 1 - rect.position.y + margin


static func _all_land(data: CityData, land: PackedByteArray, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not data.in_bounds(x, y) or land[data.idx(x, y)] == 0:
				return false
	return true


## Cells of `front` that stand on the line of sight of `behind` (they hide a part of it).
static func _hidden_cells(behind: Rect2i, front: Rect2i) -> int:
	var n := 0
	for y in range(front.position.y, front.end.y):
		for x in range(front.position.x, front.end.x):
			if _in_front(behind, x, y, SIGHT_MARGIN):
				n += 1
	return n


## Land cells on the line of sight of `r`.
static func _sight_cells(r: Rect2i, cells: Array[Vector2i]) -> int:
	var n := 0
	for c in cells:
		if _in_front(r, c.x, c.y, SIGHT_MARGIN) and not r.has_point(c):
			n += 1
	return n


## Gives both plants the same lot and puts them where few land cells lie in their way to the
## camera. Returns the two lots; both plants face south.
static func _place_plants(data: CityData, land: PackedByteArray, cells: Array[Vector2i],
		plants: Array[int]) -> Array[Rect2i]:
	var pinned := true
	for lot in PLANT_LOTS:
		if not _all_land(data, land, lot):
			pinned = false
	if pinned:
		return _set_plants(data, plants, [PLANT_LOTS[0], PLANT_LOTS[1]])
	var lobe := MapLayout.blob("urban_north")
	var at: Vector2 = lobe["at"]
	var reach: Vector2 = lobe["r"]
	# The lobe first; the whole island when the lobe has no room for both.
	var first := Rect2i()
	var second := Rect2i()
	for rows: Vector2i in [Vector2i(int(at.y - reach.y), int(at.y + reach.y)), Vector2i(1, data.size - 1)]:
		first = _best_spot(data, land, cells, rows.x, rows.y, [], Vector2i(-1, -1))
		if first.size.x > 0:
			second = _best_spot(data, land, cells, rows.x, rows.y, [first], first.position)
		if second.size.x > 0:
			break
	if first.size.x <= 0:
		return []
	return _set_plants(data, plants, [first, second])


## Puts the plants on `spots` (both facing south). The plants of the planners are reused
## (their numbers stay); missing ones are added, extra ones taken away.
static func _set_plants(data: CityData, plants: Array[int], spots: Array[Rect2i]) -> Array[Rect2i]:
	var first := spots[0]
	while plants.size() < 2:
		plants.append(data.add_building(Rect2i(), Kind.NUCLEAR_PLANT, 2, 0, 0.5))
	var seed := int(data.b_seed[plants[0]]) if data.b_seed[plants[0]] > 0 else CityTypes.hash2(first.position.x, first.position.y, SALT)
	for n in 2:
		var b: int = plants[n]
		if spots[n].size.x <= 0:
			data.b_kind[b] = Kind.EMPTY
			continue
		data.set_building_rect(b, spots[n])
		data.b_facing[b] = 2
		data.b_seed[b] = seed
		data.b_scale[b] = 1.0
		data.b_height[b] = 0.5
	# Plants beyond the two (none expected) are taken away.
	for n in range(2, plants.size()):
		data.b_kind[plants[n]] = Kind.EMPTY
	return spots


## The lot of PLANT_SIZE on land, between rows `y0` and `y1`, with the fewest land cells on its
## line of sight; `avoid` are lots it must not touch (nor stand on the sight of), `near` the
## place it should be close to when nothing else tells (-1 = no wish).
static func _best_spot(data: CityData, land: PackedByteArray, cells: Array[Vector2i], y0: int, y1: int,
		avoid: Array, near: Vector2i) -> Rect2i:
	var best := Rect2i()
	var best_score := INF
	var columns := MapLayout.cells("urban_columns")
	for y in range(maxi(y0, 1), y1 - PLANT_SIZE.y, 2):
		for x in range(1, columns - PLANT_SIZE.x, 2):
			var r := Rect2i(x, y, PLANT_SIZE.x, PLANT_SIZE.y)
			if not _all_land(data, land, r):
				continue
			var blocked := false
			var score := 0.0
			for a: Rect2i in avoid:
				if r.intersects(a.grow(PLANT_AIR + 1)):
					blocked = true
				else:
					# Cells of one plant on the line of sight of the other hide a part of it.
					score += float(_hidden_cells(a, r) + _hidden_cells(r, a)) * HIDE_WEIGHT
			if blocked:
				continue
			score += float(_sight_cells(r, cells))
			if near.x >= 0:
				score += Vector2(r.position - near).length() * 0.15
			if score < best_score:
				best_score = score
				best = r
	return best


# --- The streets ---------------------------------------------------------------------------------
## Lays the streets on the island land (CityData.road, ROAD_STREET): a street along the front
## of each plant, ROAD_COUNT parallel roads down the length of the island, a cross street from
## the landing of the metal bridge over all of them, and a street joining their ends at the
## north and at the south. Returns their cells.
static func _build_streets(data: CityData, land: PackedByteArray, plants: Array[Rect2i]) -> int:
	var wb := data.west_bridge
	if wb.x < 0:
		return 0
	var row := wb.z
	# A street along the front (south side) of each plant.
	for p in plants:
		for x in range(p.position.x - 1, p.end.x + 1):
			if data.in_bounds(x, p.end.y) and land[data.idx(x, p.end.y)] == 1 and not _in_other(plants, p, x, p.end.y):
				_road(data, x, p.end.y)
	# The parallel roads, from the row of the bridge to the north and to the south as far as
	# the land goes (or to a street that is already there).
	var columns := road_columns()
	var north := -1
	var south := data.size
	# No road runs further north than the street of the northern plant.
	var limit := 0
	for p in plants:
		limit = p.end.y if limit == 0 else mini(limit, p.end.y)
	for x in columns:
		if _blocked(data, land, plants, x, row):
			continue
		_road(data, x, row)
		var ends := [row, row]
		for k in 2:
			var dir: int = -1 if k == 0 else 1
			var y := row + dir
			while y >= limit and (data.is_road(x, y) or not _blocked(data, land, plants, x, y)):
				var joined := data.is_road(x, y)
				_road(data, x, y)
				ends[k] = y
				if joined:
					break
				y += dir
		north = maxi(north, ends[0])
		south = mini(south, ends[1])
	# The cross street of the bridge, from its landing to the westernmost road.
	for x in range(columns[0], wb.y + 1):
		if not _blocked(data, land, plants, x, row):
			_road(data, x, row)
	# The streets that join the ends of the roads; the side roads stop there, the middle one
	# runs on to the tips of the island.
	for y: int in [north, south]:
		if y < 0 or y >= data.size or absi(y - row) < 3:
			continue
		var whole := true
		for x in range(columns[0], columns[columns.size() - 1] + 1):
			if not data.is_road(x, y) and _blocked(data, land, plants, x, y):
				whole = false
		if not whole:
			continue
		for x in range(columns[0], columns[columns.size() - 1] + 1):
			_road(data, x, y)
		var out: int = -1 if y == north else 1
		for x: int in [columns[0], columns[columns.size() - 1]]:
			var yy := y + out
			while data.in_bounds(x, yy) and land[data.idx(x, yy)] == 1 and data.is_road(x, yy) \
					and not _plant_street(plants, x, yy):
				data.road[data.idx(x, yy)] = 0
				yy += out
	for p in plants:
		_join(data, land, plants, p)
	_prune_stubs(data, land)
	var n := 0
	for i in land.size():
		if land[i] == 1 and data.road[i] != 0:
			n += 1
	return n


## Columns of the parallel roads: ROAD_COUNT of them, ROAD_STEP apart, the middle one on the
## spine of the island.
static func road_columns() -> Array[int]:
	var mid := int(Vector2(MapLayout.blob("urban")["at"]).x)
	var out: Array[int] = []
	for k in ROAD_COUNT:
		out.append(mid + (k - ROAD_COUNT / 2) * ROAD_STEP)
	return out


## True on the street that runs along the front of a plant.
static func _plant_street(plants: Array[Rect2i], x: int, y: int) -> bool:
	for p in plants:
		if y == p.end.y and x >= p.position.x - 1 and x <= p.end.x:
			return true
	return false


static func _blocked(data: CityData, land: PackedByteArray, plants: Array[Rect2i], x: int, y: int) -> bool:
	if not data.in_bounds(x, y) or land[data.idx(x, y)] == 0:
		return true
	for p in plants:
		if p.grow(1).has_point(Vector2i(x, y)):
			return true
	return false


static func _road(data: CityData, x: int, y: int) -> void:
	data.road[data.idx(x, y)] = CityTypes.ROAD_STREET


static func _in_other(plants: Array[Rect2i], p: Rect2i, x: int, y: int) -> bool:
	for q in plants:
		if q != p and q.grow(1).has_point(Vector2i(x, y)):
			return true
	return false


## Joins the street in front of plant `p` to the other streets, by the shortest way over free
## land that runs beside no other street (no double street).
static func _join(data: CityData, land: PackedByteArray, plants: Array[Rect2i], p: Rect2i) -> void:
	var own := {}
	for x in range(p.position.x - 1, p.end.x + 1):
		if data.in_bounds(x, p.end.y) and data.road[data.idx(x, p.end.y)] != 0:
			own[Vector2i(x, p.end.y)] = true
	if own.is_empty():
		return
	# Already joined: a street of the network touches it.
	for c: Vector2i in own:
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = c + o
			if not own.has(q) and data.is_road(q.x, q.y):
				return
	var prev := {}
	var queue: Array[Vector2i] = []
	for c: Vector2i in own:
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = c + o
			if not own.has(q) and _free_for_road(data, land, plants, q) and not prev.has(q):
				prev[q] = c
				queue.append(q)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var goal := false
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = c + o
			if not own.has(q) and q != prev[c] and data.is_road(q.x, q.y):
				goal = true
		if goal:
			var k := c
			while not own.has(k):
				_road(data, k.x, k.y)
				k = prev[k]
			return
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = c + o
			if prev.has(q) or not _free_for_road(data, land, plants, q):
				continue
			# Beside no cell of the plant street but the one it comes from.
			var side := 0
			for o2 in CityTypes.FACING_OFFSETS:
				var r: Vector2i = q + o2
				if r != c and own.has(r):
					side += 1
			if side > 0:
				continue
			prev[q] = c
			queue.append(q)


static func _free_for_road(data: CityData, land: PackedByteArray, plants: Array[Rect2i], c: Vector2i) -> bool:
	if not data.in_bounds(c.x, c.y) or land[data.idx(c.x, c.y)] == 0 or data.road[data.idx(c.x, c.y)] != 0:
		return false
	for p in plants:
		if p.grow(1).has_point(c):
			return false
	return true


## Takes away the dead ends shorter than 3 cells (stubs), the head of the bridge left out.
static func _prune_stubs(data: CityData, land: PackedByteArray) -> void:
	var changed := true
	while changed:
		changed = false
		for i in land.size():
			if land[i] == 0 or data.road[i] == 0:
				continue
			var c := Vector2i(i % data.size, i / data.size)
			if MapAudit.at_bridge_head(data, c.x, c.y):
				continue
			var m := data.road_mask(c.x, c.y)
			if m != 0 and m != CityTypes.DIR_N and m != CityTypes.DIR_E and m != CityTypes.DIR_S and m != CityTypes.DIR_W:
				continue
			if m != 0 and MapAudit.dead_end_length(data, c) >= 3:
				continue
			# The whole stub goes, from its tip back to the junction.
			var cur := c
			while true:
				data.road[data.idx(cur.x, cur.y)] = 0
				changed = true
				var next := Vector2i(-1, -1)
				var ways := 0
				for o in CityTypes.FACING_OFFSETS:
					var q: Vector2i = cur + o
					if data.is_road(q.x, q.y):
						ways += 1
						next = q
				if ways != 1:
					break
				var deg := 0
				for o in CityTypes.FACING_OFFSETS:
					if data.is_road(next.x + o.x, next.y + o.y):
						deg += 1
				if deg != 1:
					break
				cur = next


# --- The yard by the plant road --------------------------------------------------------------------
## A few containers and barrels (two INDUSTRIAL_YARD lots) on free land just south of the street
## in front of the southern plant. Returns how many lots.
static func _plant_yard(data: CityData, land: PackedByteArray, plants: Array[Rect2i]) -> int:
	if plants.is_empty():
		return 0
	var p := plants[0]
	for q in plants:
		if q.position.y > p.position.y:
			p = q
	var placed := 0
	var y := p.end.y + 1
	for x in range(p.position.x + 2, p.end.x - 2):
		if placed >= PLANT_YARD_SEEDS.size():
			break
		var r := Rect2i(x, y, 2, 2)
		if not _yard_free(data, land, r):
			continue
		data.add_building(r, Kind.INDUSTRIAL_YARD, 2, PLANT_YARD_SEEDS[placed], 0.3)
		placed += 1
	return placed


## Land with no road and no lot, and no street round it but on its north side (the road).
static func _yard_free(data: CityData, land: PackedByteArray, r: Rect2i) -> bool:
	for yy in range(r.position.y, r.end.y + 1):
		for xx in range(r.position.x - 1, r.end.x + 1):
			if not data.in_bounds(xx, yy) or land[data.idx(xx, yy)] == 0 or data.road[data.idx(xx, yy)] != 0:
				return false
	for b in data.building_count():
		if data.b_kind[b] != Kind.EMPTY and data.building_rect(b).intersects(r.grow(1)):
			return false
	return true


# --- The towers -------------------------------------------------------------------------------------
## Rows of skyscrapers down the island, on both sides of every road and behind them as far as
## the land goes: each row is ROW_DEPTH cells deep and its towers touch each other (a lot is
## as long as its tower, see TOWERS). The streets, the landing of the bridge and the ground
## round the plants stay free. Returns how many were built.
static func _build_towers(data: CityData, land: PackedByteArray, cells: Array[Vector2i],
		plants: Array[Rect2i]) -> int:
	var free := land.duplicate()
	for p in plants:
		for y in range(p.position.y - PLANT_AIR - 1, p.end.y + PLANT_AIR + 1):
			for x in range(p.position.x - PLANT_AIR - 1, p.end.x + PLANT_AIR + 1):
				if data.in_bounds(x, y):
					free[data.idx(x, y)] = 0
	_keep_landing_free(data, free)
	var top := data.size
	var bottom := 0
	for c in cells:
		var i := data.idx(c.x, c.y)
		if data.road[i] != 0:
			free[i] = 0
		top = mini(top, c.y)
		bottom = maxi(bottom, c.y)
	# The north lobe is left to the plants: the rows start south of their street.
	for p in plants:
		top = maxi(top, p.end.y + 1)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				if data.in_bounds(x, y):
					free[data.idx(x, y)] = 0
	var built := 0
	var band := 0
	for row: Array in _rows():
		built += _tower_row(data, free, plants, row[0], row[1], top, bottom, band)
		band += 1
	return built


## The rows of towers: [column of the side nearest to its road, facing]. Two rows between two
## roads (back to back), and rows behind the outer roads out to the coast.
static func _rows() -> Array:
	var columns := road_columns()
	var out := []
	for x in columns:
		out.append([x - 1, 1])
		out.append([x + 1, 3])
	var west: int = columns[0] - 1 - ROW_DEPTH
	var east: int = columns[columns.size() - 1] + 1 + ROW_DEPTH
	for k in OUTER_ROWS:
		out.append([west - k * ROW_DEPTH, 1])
		out.append([east + k * ROW_DEPTH, 3])
	return out


## One row of towers from the north of the island to the south. `near` is the column of the row
## nearest to its road; the row lies west of it when the towers face east (1), east of it when
## they face west (3). Where the coast leaves no room for the whole depth, a shallower lot.
static func _tower_row(data: CityData, free: PackedByteArray, plants: Array[Rect2i], near: int,
		facing: int, top: int, bottom: int, band: int) -> int:
	var built := 0
	var last := -1
	var y := top
	while y <= bottom:
		var placed := false
		var first := CityTypes.hash2(band, built, SALT) % TOWERS.size()
		for step in TOWERS.size():
			var t: int = (first + step * 5) % TOWERS.size()
			if t == last:
				continue
			var length: int = TOWERS[t][1]
			for depth: int in [ROW_DEPTH, ROW_DEPTH - 1]:
				var r := Rect2i(near - depth + 1 if facing == 1 else near, y, depth, length)
				if not _free_rect(data, free, r) or not _tower_allowed(r, plants, float(TOWERS[t][2])):
					continue
				# What is left of the row up to the next street must hold a tower (or nothing).
				var left := _run(data, free, Rect2i(r.position.x, r.end.y, depth, 1), MIN_LENGTH)
				if left > 0 and left < MIN_LENGTH:
					continue
				var id := data.add_building(r, Kind.SKYLINE_TOWER, facing,
						CityTypes.hash2(r.position.x, r.position.y, SALT) & 0x7fffffff, 0.5)
				data.b_model[id] = MODEL_PREFIX + String(TOWERS[t][0])
				for yy in range(r.position.y, r.end.y):
					for xx in range(r.position.x, r.end.x):
						free[data.idx(xx, yy)] = 0
				built += 1
				last = t
				y += length
				placed = true
				break
			if placed:
				break
		if not placed:
			y += 1
	return built


## True when a tower `height` cells high on lot `r` hides no plant: any tower off the lines of
## sight, the low ones near a plant, none right in front of it.
static func _tower_allowed(r: Rect2i, plants: Array[Rect2i], height: float) -> bool:
	for p in plants:
		var hit := false
		for c: Vector2i in [r.position, Vector2i(r.end.x - 1, r.position.y),
				Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE]:
			if _in_front(p, c.x, c.y, SIGHT_MARGIN):
				hit = true
		if not hit:
			continue
		# Ground distance along the camera ray, from the nearest cell of the lot to the plant.
		var k := maxi(maxi(r.position.x - (p.end.x - 1), r.position.y - (p.end.y - 1)), 0)
		if height > PLANT_TOP + HIDDEN_ALLOWED + VIEW_SLOPE * float(k) * 1.4142:
			return false
	return true


## How many rows in a row, from `r` southwards, are free over its whole width (at most `most`).
static func _run(data: CityData, free: PackedByteArray, r: Rect2i, most: int) -> int:
	var n := 0
	while n < most and _free_rect(data, free, Rect2i(r.position.x, r.position.y + n, r.size.x, 1)):
		n += 1
	return n


static func _free_rect(data: CityData, free: PackedByteArray, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not data.in_bounds(x, y) or free[data.idx(x, y)] == 0:
				return false
	return true


## The deck of the metal bridge ends on bare ground.
static func _keep_landing_free(data: CityData, free: PackedByteArray) -> void:
	var wb := data.west_bridge
	if wb.x < 0:
		return
	for y in range(wb.z - LANDING_ROWS, wb.z + LANDING_ROWS + 1):
		for x in range(wb.y - LANDING_COLUMNS + 1, wb.y + 2):
			if data.in_bounds(x, y):
				free[data.idx(x, y)] = 0
