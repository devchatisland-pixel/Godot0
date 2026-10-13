class_name ScenicProps
extends RefCounted
## A few single props put by hand on the finished map (drawn by MapVehicles):
##   - on the beach between a lighthouse and the north watchtower: two deck chairs and a beach
##     ball;
##   - one deck chair on a beach near the north-east lighthouse (not on its own sand strip);
##   - deck chairs and a beach ball on a few lonely beaches, far from the lighthouses and from
##     everything else;
##   - a billboard on the border of the central park, by a downtown tower.
## Pure data in, a list of placements out: {"file", "title", "at": Vector3, "yaw", "length", "front"}
## (`length`: longest side of the model, in cells; the model stands on the ground at `at`; `front`:
## the side of the model that is its front, -Z unless said otherwise: the deck chair looks along +X).

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

const BALL := "res://props/beach/beach_ball.glb"
const CHAIR := "res://props/beach/deck_chair.glb"
const BILLBOARD := "res://props/park/park_billboard.glb"

## The beach between these two (top-left cells of their lots): lighthouse, watchtower.
const BEACH_FROM := Vector2i(118, 94)
const BEACH_TO := Vector2i(150, 78)
## The lighthouse near which one more deck chair stands, on another beach than its own zone.
const LONE_CHAIR_NEAR := Vector2i(279, 96)
const LONE_CHAIR_REACH := 30
## The downtown tower the park billboard stands next to (top-left cell of its lot).
const BILLBOARD_NEAR := Vector2i(179, 165)
const BILLBOARD_WIDTH := 4.5

## The deck chair of the pack looks along +X (its backrest is at -X).
const CHAIR_FRONT := Vector3(1, 0, 0)

## Chairs turned by hand (they look the way their yaw says, not at the sea): the lone chair looks
## north; on the lonely beaches nearest to these cells (sand cell of the set) the listed chairs
## (indexes in the set, empty = all of them) look at the beach ball, or west.
const LONE_CHAIR_LOOK := Vector3(0, 0, -1)
const LOOK_AT_BALL := {Vector2i(300, 129): [1], Vector2i(232, 61): []}
const LOOK_WEST := {Vector2i(171, 62): []}
const HAND_REACH := 3.0

## Sizes in cells (a little bigger than life, so they can be seen).
const BALL_LEN := 0.16
const CHAIR_LEN := 0.45

## Lonely beaches: how many get chairs and a ball, how far they keep from each other, from
## the lighthouses, and from any building, road or other prop (cells).
const LONELY_SETS := 6
const LONELY_APART := 34.0
const LONELY_FROM_LIGHTHOUSE := 26.0
const LONELY_CLEAR := 12


var out: Array[Dictionary] = []
var _d: CityData
var _taken := PackedByteArray()


static func plan(data: CityData) -> Array[Dictionary]:
	var s := ScenicProps.new()
	s._d = data
	s._taken.resize(data.size * data.size)
	for b in data.building_count():
		if data.b_kind[b] == Kind.EMPTY:
			continue
		var r := data.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.in_bounds(x, y):
					s._taken[data.idx(x, y)] = 1
	s._beach_set()
	s._lone_chair()
	s._lonely_beaches()
	s._park_billboard()
	return s.out


# --- Beach ---------------------------------------------------------------------------------------
## Two deck chairs facing the sea and a ball, on the beach cell nearest to the middle
## of BEACH_FROM - BEACH_TO.
func _beach_set() -> void:
	var a := _anchor(Kind.LIGHTHOUSE, BEACH_FROM)
	var b := _anchor(Kind.WATCHTOWER, BEACH_TO)
	var mid := (a + b) * 0.5
	var c := _beach_cell(mid, int(a.distance_to(b) * 0.6), -1)
	if c.x < 0:
		push_warning("[Props] no beach between %s and %s" % [BEACH_FROM, BEACH_TO])
		return
	var p := Vector3(c.x + 0.5, 0, c.y + 0.5)
	var sea := _to_sea(c)
	var side := Vector3(-sea.z, 0, sea.x)
	var face := atan2(sea.x, sea.z)
	_add(CHAIR, "Deck chair", p + side * 0.28 + sea * 0.3, face, CHAIR_LEN, CHAIR_FRONT)
	_add(CHAIR, "Deck chair", p - side * 0.28 + sea * 0.3, face, CHAIR_LEN, CHAIR_FRONT)
	_add(BALL, "Beach ball", p + sea * 0.7 + side * 0.45, 0.0, BALL_LEN)


## One deck chair on the beach nearest to the lighthouse at LONE_CHAIR_NEAR whose zone is not
## the lighthouse's own.
func _lone_chair() -> void:
	var at := _anchor(Kind.LIGHTHOUSE, LONE_CHAIR_NEAR)
	var own := _d.zone_at(int(at.x), int(at.y))
	var c := _beach_cell(at, LONE_CHAIR_REACH, own)
	if c.x < 0:
		push_warning("[Props] no other beach near %s" % LONE_CHAIR_NEAR)
		return
	_add(CHAIR, "Deck chair", Vector3(c.x + 0.5, 0, c.y + 0.5), _look_yaw(LONE_CHAIR_LOOK), CHAIR_LEN, CHAIR_FRONT)


## Free sand cell (with free sand all round it) nearest to `at` within `reach`, whose zone is not
## `not_zone`; (-1, -1) when there is none.
func _beach_cell(at: Vector2, reach: int, not_zone: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(int(at.y) - reach, int(at.y) + reach + 1):
		for x in range(int(at.x) - reach, int(at.x) + reach + 1):
			if not _sand(x, y) or _d.zone_at(x, y) == not_zone:
				continue
			var room := true
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _sand(x + o.x, y + o.y) and _d.is_land(x + o.x, y + o.y):
					room = false
			if not room:
				continue
			var d := Vector2(x, y).distance_to(at)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


func _sand(x: int, y: int) -> bool:
	if not _d.in_bounds(x, y):
		return false
	var i := _d.idx(x, y)
	return _d.terrain[i] == CityTypes.Terrain.BEACH and _d.rocky[i] == 0 and _d.road[i] == 0 \
			and _taken[i] == 0 and _d.deco[i] == 0


## Unit vector (x, z) from cell `c` towards the nearest water.
func _to_sea(c: Vector2i) -> Vector3:
	var sum := Vector2.ZERO
	for y in range(c.y - 4, c.y + 5):
		for x in range(c.x - 4, c.x + 5):
			if _d.in_bounds(x, y) and not _d.is_land(x, y):
				sum += Vector2(x - c.x, y - c.y)
	if sum == Vector2.ZERO:
		return Vector3(0, 0, 1)
	sum = sum.normalized()
	return Vector3(sum.x, 0, sum.y)


## Deck chairs facing the sea and a beach ball on LONELY_SETS beaches of the main island with
## nothing around: no lighthouse within LONELY_FROM_LIGHTHOUSE cells, no building, road or
## prop within LONELY_CLEAR. Two or three chairs, by the hash of the cell.
func _lonely_beaches() -> void:
	var lights: Array[Vector2] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.LIGHTHOUSE:
			lights.append(Vector2(_d.building_rect(b).get_center()))
	var cands: Array[Vector2i] = []
	for y in range(LONELY_CLEAR, _d.size - LONELY_CLEAR):
		for x in range(LONELY_CLEAR, _d.size - LONELY_CLEAR):
			if _sand(x, y) and _d.zone_at(x, y) != Zone.DEV and _lonely(x, y, lights):
				cands.append(Vector2i(x, y))
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return CityTypes.hash2(a.x, a.y, 83) < CityTypes.hash2(b.x, b.y, 83))
	var sets: Array[Vector2i] = []
	for c in cands:
		if sets.size() >= LONELY_SETS:
			break
		var apart := true
		for o in sets:
			if Vector2(o).distance_to(Vector2(c)) < LONELY_APART:
				apart = false
				break
		if not apart:
			continue
		sets.append(c)
		var p := Vector3(c.x + 0.5, 0, c.y + 0.5)
		var sea := _to_sea(c)
		var side := Vector3(-sea.z, 0, sea.x)
		var face := atan2(sea.x, sea.z)
		var chairs := 2 + (CityTypes.hash2(c.x, c.y, 89) & 1)
		var ball := p + sea * 0.45 + side * 0.2
		var at_ball: Variant = _hand_set(LOOK_AT_BALL, c)
		var west: Variant = _hand_set(LOOK_WEST, c)
		for k in chairs:
			var at := p + side * (float(k) - float(chairs - 1) * 0.5) * 0.55
			var yaw := face
			if _hand_has(at_ball, k):
				yaw = _look_yaw(ball - at)
			elif _hand_has(west, k):
				yaw = _look_yaw(Vector3(-1, 0, 0))
			_add(CHAIR, "Deck chair", at, yaw, CHAIR_LEN, CHAIR_FRONT)
		_add(BALL, "Beach ball", ball, 0.0, BALL_LEN)
	if sets.size() < LONELY_SETS:
		push_warning("[Props] only %d lonely beaches" % sets.size())


## True when sand cell (x, y) has sand or sea all round it, no lighthouse near and nothing
## built or placed within LONELY_CLEAR cells.
func _lonely(x: int, y: int, lights: Array[Vector2]) -> bool:
	for l in lights:
		if l.distance_to(Vector2(x, y)) < LONELY_FROM_LIGHTHOUSE:
			return false
	for dy in range(-LONELY_CLEAR, LONELY_CLEAR + 1):
		for dx in range(-LONELY_CLEAR, LONELY_CLEAR + 1):
			var i := _d.idx(x + dx, y + dy)
			if _taken[i] != 0 or _d.road[i] != 0 or _d.deco[i] != 0:
				return false
			if maxi(absi(dx), absi(dy)) <= 1 and _d.is_land(x + dx, y + dy) and not _sand(x + dx, y + dy):
				return false
	return true


# --- Park billboard -----------------------------------------------------------------------------
## The billboard stands on park ground of the central park, on the free run of cells along X
## nearest to the tower at BILLBOARD_NEAR, its face towards the tower.
func _park_billboard() -> void:
	var park := _d.central_park
	if park.size.x <= 0:
		return
	var tower := _anchor(Kind.SKYSCRAPER, BILLBOARD_NEAR)
	var w := int(ceil(BILLBOARD_WIDTH))
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(park.position.y, park.end.y):
		for x in range(park.position.x, park.end.x - w + 1):
			var ok := true
			for k in w:
				if not _park_free(x + k, y):
					ok = false
					break
			if not ok:
				continue
			var d := Vector2(x + w * 0.5, y + 0.5).distance_to(tower)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	if best.x < 0:
		push_warning("[Props] no room for the park billboard")
		return
	var p := Vector3(best.x + w * 0.5, 0, best.y + 0.5)
	var face := 0.0 if tower.y > p.z else PI
	_add(BILLBOARD, "Billboard (central park)", p, face, BILLBOARD_WIDTH)


func _park_free(x: int, y: int) -> bool:
	if not _d.in_bounds(x, y):
		return false
	var i := _d.idx(x, y)
	return _d.zone[i] == Zone.PARK and _d.road[i] == 0 and _taken[i] == 0 and _d.deco[i] == 0


# --- Helpers -----------------------------------------------------------------------------------
## Centre (cells) of the building of `kind` whose lot starts nearest to `cell`; `cell` itself
## when there is none.
func _anchor(kind: int, cell: Vector2i) -> Vector2:
	var best := Vector2(cell) + Vector2(0.5, 0.5)
	var best_d := INF
	for b in _d.building_count():
		if _d.b_kind[b] != kind:
			continue
		var r := _d.building_rect(b)
		var d := Vector2(r.position).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = Vector2(r.position) + Vector2(r.size) * 0.5
	return best


## Yaw that turns a model whose front is +X (the deck chair) to look along `dir` (x, z).
static func _look_yaw(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)


## The hand-made list of `table` for the set whose sand cell `c` is within HAND_REACH of its key:
## the chair indexes (empty = all), or null when the set is not in the table.
static func _hand_set(table: Dictionary, c: Vector2i) -> Variant:
	for cell: Vector2i in table:
		if Vector2(cell).distance_to(Vector2(c)) <= HAND_REACH:
			return table[cell]
	return null


static func _hand_has(list: Variant, k: int) -> bool:
	return list != null and ((list as Array).is_empty() or (list as Array).has(k))


func _add(file: String, title: String, at: Vector3, yaw: float, length: float, front: Vector3 = Vector3(0, 0, -1)) -> void:
	out.append({"file": file, "title": title, "at": at, "yaw": yaw, "length": length, "front": front})
	var c := Vector2i(int(floor(at.x)), int(floor(at.z)))
	if _d.in_bounds(c.x, c.y):
		_taken[_d.idx(c.x, c.y)] = 1
