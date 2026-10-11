class_name UrbanIslandRebuild
extends RefCounted
## The urban island as it is finally built: the two nuclear plants, a few streets and
## TOWER_COUNT futuristic towers along them. It runs once the whole map is generated and the
## budget of the buildings is applied (CityGenerator), so no other district moves by a single cell:
##   - everything the planners put on the island is taken away (towers, yards and containers,
##     industry, the cooling hall, the fire truck, the billboard, the bus stops), and so are its
##     streets;
##   - the two plants keep their lots (PLANT_LOTS, else where as few cells as possible lie on
##     their line of sight to the camera), both facing south; AmenitiesPlanner fences them;
##   - streets: one from the landing of the metal bridge across the island, cross streets
##     every STREET_STEP columns, a street along the front of each plant joined to the others,
##     and a small yard of containers and barrels beside the plant road;
##   - the towers (FUTURE_BLDG) stand along the streets. On the line of sight of a plant the
##     towers rise like the seats of a stadium: no tower is taller than what the camera (30
##     degrees down) still sees the plant over, so the plants stay in view.
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
## The towers that may stand on a line of sight, by their height at the biggest scale a lot gives
## (model height x 1.15 x the stretch of the placer). Tower c of the pack is a flat sheet: never
## used. Tower g is drawn as the night city tower that replaces it (BuildingPlacer), a lower
## one. The names are the ones of the model library.
const RAMP := [
	["future.glb: tower_h", 6.2], ["future.glb: tower_g", 7.5], ["future.glb: tower_l", 10.2],
	["future.glb: tower_e", 10.7], ["future.glb: tower_f", 12.6], ["future.glb: tower_b", 14.3],
	["future.glb: tower_a", 17.9],
]
## Cost of a cell of one plant that hides the other, in land cells of sight.
const HIDE_WEIGHT := 3.0
## No tower closer than this to a plant (cells).
const PLANT_AIR := 1
## Towers tried in this order of shapes, biggest first; the first of the list that a cell
## picks by its hash comes first, the others follow by area. No lot is smaller than 3x3:
## the narrow towers of the pack look wrong on a smaller lot.
const SHAPES: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(3, 3), Vector2i(3, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4),
	Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 4),
]
## Bare ground at the end of the metal bridge: columns before its head, rows either side.
const LANDING_COLUMNS := 5
const LANDING_ROWS := 2
## Salt of the hashes of this pass.
const SALT := 5101
## Where the two plants stand (cells of the final map): they keep their place when the land is
## there (ExtensionIsland keeps it).
const PLANT_LOTS: Array[Rect2i] = [Rect2i(53, 149, 18, 7), Rect2i(51, 139, 18, 7)]
## How many towers stand on the island (the ones left once many were taken away by hand).
const TOWER_COUNT := 87
## Columns between two cross streets, and the first one west of the bridge landing.
const STREET_STEP := 9
const FIRST_CROSS := 6
## Passes of the towers: on a street, then up to this many cells back from one.
const STREET_REACH: Array[int] = [1, 3]
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
## Clears every building that stands on the island land (the lot stays in the list, empty: the
## numbers do not move). Returns the ids of the nuclear plants.
static func _take_away(data: CityData, land: PackedByteArray, out: Dictionary) -> Array[int]:
	var plants: Array[int] = []
	for b in data.building_count():
		var kind: int = data.b_kind[b]
		if kind == Kind.EMPTY:
			continue
		var c := data.building_rect(b).get_center()
		if not data.in_bounds(c.x, c.y) or land[data.idx(c.x, c.y)] == 0:
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
## Lays the streets on the island land (CityData.road, ROAD_STREET). Returns their cells.
static func _build_streets(data: CityData, land: PackedByteArray, plants: Array[Rect2i]) -> int:
	var wb := data.west_bridge
	if wb.x < 0:
		return 0
	var row := wb.z
	# From the landing of the bridge westwards, across the island.
	var west := wb.y
	while not _blocked(data, land, plants, west - 1, row):
		west -= 1
	for x in range(west, wb.y + 1):
		_road(data, x, row)
	# Cross streets, north and south as far as the land goes.
	for x in range(wb.y - FIRST_CROSS, west, -STREET_STEP):
		for dir in [-1, 1]:
			var y: int = row + dir
			while not _blocked(data, land, plants, x, y):
				_road(data, x, y)
				y += dir
	# A street along the front (south side) of each plant, joined to the others.
	for p in plants:
		for x in range(p.position.x - 1, p.end.x + 1):
			if data.in_bounds(x, p.end.y) and land[data.idx(x, p.end.y)] == 1 and not _in_other(plants, p, x, p.end.y):
				_road(data, x, p.end.y)
		_join(data, land, plants, p)
	_prune_stubs(data, land)
	var n := 0
	for i in land.size():
		if land[i] == 1 and data.road[i] != 0:
			n += 1
	return n


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
## Puts up to TOWER_COUNT towers on free land along the streets (each lot touches a street),
## the lots tried in the order of a hash so they spread over the whole island. Returns how
## many were built.
static func _build_towers(data: CityData, land: PackedByteArray, cells: Array[Vector2i],
		plants: Array[Rect2i]) -> int:
	var free := land.duplicate()
	for p in plants:
		for y in range(p.position.y - PLANT_AIR - 1, p.end.y + PLANT_AIR + 1):
			for x in range(p.position.x - PLANT_AIR - 1, p.end.x + PLANT_AIR + 1):
				if data.in_bounds(x, y):
					free[data.idx(x, y)] = 0
	_keep_landing_free(data, free)
	for c in cells:
		var i := data.idx(c.x, c.y)
		if data.road[i] != 0:
			free[i] = 0
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				if data.in_bounds(x, y):
					free[data.idx(x, y)] = 0
	var order := cells.duplicate()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return CityTypes.hash2(a.x, a.y, SALT + 2) < CityTypes.hash2(b.x, b.y, SALT + 2))
	var built := 0
	# First the lots right on a street, then (when the count is not reached) the ones a little
	# back from it.
	for reach in STREET_REACH:
		built += _towers_pass(data, free, order, plants, reach, TOWER_COUNT - built)
	return built


## One pass of _build_towers: up to `count` lots within `reach` cells of a street.
static func _towers_pass(data: CityData, free: PackedByteArray, order: Array[Vector2i],
		plants: Array[Rect2i], reach: int, count: int) -> int:
	var built := 0
	for c: Vector2i in order:
		if built >= count:
			break
		if free[data.idx(c.x, c.y)] == 0:
			continue
		var shape := _fit_shape(data, free, c.x, c.y)
		if shape.x == 0:
			continue
		var r := Rect2i(c, shape)
		if not _on_street(data, r, reach):
			continue
		var seed := CityTypes.hash2(c.x, c.y, SALT) & 0x7fffffff
		var allowed := _allowed_towers(r, plants)
		if allowed.is_empty():
			continue
		var facing := 1 if (seed >> 7) & 1 == 1 else 2
		var id := data.add_building(r, Kind.FUTURE_BLDG, facing, seed, 0.5)
		if allowed.size() < RAMP.size():
			data.b_model[id] = allowed[seed % allowed.size()]
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				free[data.idx(xx, yy)] = 0
		built += 1
	return built


## True when a street runs along a side of lot `r`, at most `reach` cells from it (not at a
## corner).
static func _on_street(data: CityData, r: Rect2i, reach: int) -> bool:
	for k in range(1, reach + 1):
		for x in range(r.position.x, r.end.x):
			if data.is_road(x, r.position.y - k) or data.is_road(x, r.end.y - 1 + k):
				return true
		for y in range(r.position.y, r.end.y):
			if data.is_road(r.position.x - k, y) or data.is_road(r.end.x - 1 + k, y):
				return true
	return false


## The towers (model names) that may stand on lot `r` without hiding a plant: all of them when
## the lot is on no line of sight, the low ones near a plant, none right in front of it.
static func _allowed_towers(r: Rect2i, plants: Array[Rect2i]) -> Array[String]:
	var limit := INF
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
		limit = minf(limit, PLANT_TOP + HIDDEN_ALLOWED + VIEW_SLOPE * float(k) * 1.4142)
	var out: Array[String] = []
	for t in RAMP:
		if float(t[1]) <= limit:
			out.append(t[0])
	return out


## The shape (w, h) of the lot that fits at (x, y), the one its hash picks first.
static func _fit_shape(data: CityData, free: PackedByteArray, x: int, y: int) -> Vector2i:
	var pick: Vector2i = SHAPES[CityTypes.hash2(x, y, SALT + 1) % SHAPES.size()]
	var order: Array[Vector2i] = [pick]
	var rest: Array[Vector2i] = []
	for s in SHAPES:
		if s != pick and not rest.has(s):
			rest.append(s)
	rest.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y > b.x * b.y)
	order.append_array(rest)
	for s in order:
		if _free_rect(data, free, Rect2i(x, y, s.x, s.y)):
			return s
	return Vector2i.ZERO


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
