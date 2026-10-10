class_name UrbanIslandRebuild
extends RefCounted
## The urban island as it is finally built: a solid mass of futuristic towers and the two
## nuclear plants, nothing else. It runs once the whole map is generated and the budget of
## the buildings is applied (CityGenerator), so no other district moves by a single cell:
##   - everything the planners put on the island is taken away (towers, yards and containers,
##     industry, the cooling hall, the fire truck, the billboard, the bus stops), and so are its
##     streets and the fence round the plant: the towers stand too close for any of that;
##   - the two plants get the same size and one is turned half a turn (facing 2 and facing 0),
##     side by side, where as few cells as possible lie on their line of sight to the camera;
##   - the land that is left is tiled with futuristic towers (FUTURE_BLDG) without a gap, but
##     for a short landing for the metal bridge. On the line of sight of a plant the towers
##     rise like the seats of a stadium: no tower is taller than what the camera (30 degrees
##     down) still sees the plant over, so the plants stay in view.
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
## camera. Returns the two lots; the first plant keeps the facing it had, the second is turned
## half a turn.
static func _place_plants(data: CityData, land: PackedByteArray, cells: Array[Vector2i],
		plants: Array[int]) -> Array[Rect2i]:
	var lobe := MapLayout.blob("urban_north")
	var at: Vector2 = lobe["at"]
	var reach: Vector2 = lobe["r"]
	var first := _best_spot(data, land, cells, int(at.y - reach.y), int(at.y + reach.y), [], Vector2i(-1, -1))
	if first.size.x <= 0:
		return []
	var second := _best_spot(data, land, cells, int(at.y - reach.y), int(at.y + reach.y), [first], first.position)
	# The plants of the planners are reused (their numbers stay); missing ones are added.
	while plants.size() < 2:
		plants.append(data.add_building(Rect2i(), Kind.NUCLEAR_PLANT, 2, 0, 0.5))
	var seed := int(data.b_seed[plants[0]]) if data.b_seed[plants[0]] > 0 else CityTypes.hash2(first.position.x, first.position.y, SALT)
	var spots: Array[Rect2i] = [first, second]
	for n in 2:
		var b: int = plants[n]
		if spots[n].size.x <= 0:
			data.b_kind[b] = Kind.EMPTY
			continue
		data.set_building_rect(b, spots[n])
		data.b_facing[b] = 2 if n == 0 else 0
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


# --- The towers -------------------------------------------------------------------------------------
## Tiles the free land with towers, row by row, a lot starting on every free cell that still
## has room for one. Returns how many were built.
static func _build_towers(data: CityData, land: PackedByteArray, cells: Array[Vector2i],
		plants: Array[Rect2i]) -> int:
	var free := land.duplicate()
	for p in plants:
		for y in range(p.position.y - PLANT_AIR, p.end.y + PLANT_AIR):
			for x in range(p.position.x - PLANT_AIR, p.end.x + PLANT_AIR):
				if data.in_bounds(x, y):
					free[data.idx(x, y)] = 0
	_keep_landing_free(data, free)
	var built := 0
	for y in range(0, data.size):
		for x in range(0, data.size):
			if free[data.idx(x, y)] == 0:
				continue
			var shape := _fit_shape(data, free, x, y)
			if shape.x == 0:
				continue
			var r := Rect2i(x, y, shape.x, shape.y)
			var seed := CityTypes.hash2(x, y, SALT) & 0x7fffffff
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
