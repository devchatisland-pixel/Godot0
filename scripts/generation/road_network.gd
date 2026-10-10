class_name RoadNetwork
extends RefCounted
## Makes one clean road network out of what the planners drew. The planners lay roads cell by
## cell (block borders, links, highways); this pass runs once after them and enforces the
## rules of the network, whatever the size of the map:
##   - no two roads side by side outside the highways (they are thinned to one),
##   - no roads touching by a corner only (the corner is filled, or the stub removed),
##   - no short stubs: a dead end is joined to a nearby road when free land allows it,
##     removed when it is shorter than MIN_CUL_DE_SAC, and kept as a cul-de-sac otherwise,
##   - no loose pieces: groups of roads that are not joined to the main network are joined
##     or removed,
##   - a highway (three lanes) ends at a bridge or at a road that crosses its whole width,
##     and that crossing road is an avenue.
## Only free land is used for new road cells (no building, no park, no beach).
## `apply` returns what it did, for the log.

const Terrain := CityTypes.Terrain
const Zone := CityTypes.Zone

## Longest way (cells of new road) built to join a dead end or a loose group to the network.
const JOIN_REACH := 7
## A dead end shorter than this (cells from its last junction) is removed.
const MIN_CUL_DE_SAC := 3
## A loose group with fewer road cells than this is removed when it cannot be joined.
const SMALL_GROUP := 40
## Zones where no new road is drawn.
const NO_ROAD_ZONES: Array[int] = [Zone.PARK, Zone.PRISON, Zone.DEV, Zone.ISLET, Zone.SAND, Zone.CIVIC]

var _d: CityData
## 1 where a building stands.
var _built := PackedByteArray()
## 1 on the highways and on the column of road that closes each of their ends.
var _highway := PackedByteArray()
var stats := {"thinned": 0, "corners": 0, "joined": 0, "trimmed": 0, "groups_removed": 0,
		"groups_joined": 0, "promoted": 0}


static func apply(data: CityData) -> Dictionary:
	var n := RoadNetwork.new()
	n._d = data
	n._mark_buildings()
	n._promote_highway_crossings()
	n._mark_highways()
	n._thin()
	n._fix_corners()
	n._join_groups()
	n._close_dead_ends()
	n._thin()
	return n.stats


func _mark_buildings() -> void:
	_built.resize(_d.size * _d.size)
	for b in _d.building_count():
		if _d.b_kind[b] == CityTypes.Kind.EMPTY:
			continue
		var r := _d.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _d.in_bounds(x, y):
					_built[_d.idx(x, y)] = 1


# --- Helpers -------------------------------------------------------------------------------------
func _road(x: int, y: int) -> bool:
	return _d.is_road(x, y)


func _is_bridge(x: int, y: int) -> bool:
	return (_d.road[_d.idx(x, y)] & CityTypes.ROAD_BRIDGE_FLAG) != 0


## A new road cell may go here.
func _free(x: int, y: int) -> bool:
	if not _d.in_bounds(x, y):
		return false
	var i := _d.idx(x, y)
	return _d.road[i] == 0 and _built[i] == 0 and _d.terrain[i] == Terrain.LAND \
			and not NO_ROAD_ZONES.has(_d.zone[i])


func _degree(x: int, y: int) -> int:
	var n := 0
	for o in CityTypes.FACING_OFFSETS:
		if _road(x + o.x, y + o.y):
			n += 1
	return n


func _mark_highways() -> void:
	_highway = MapAudit.highway_mask(_d)
	for h in MapAudit.highways(_d):
		for x: int in [int(h["from"]) - 1, int(h["to"]) + 1]:
			for dy in range(-1, 2):
				if _d.in_bounds(x, int(h["row"]) + dy):
					_highway[_d.idx(x, int(h["row"]) + dy)] = 1


## True when (x, y) lies on a highway or on the road that closes one of its ends.
func _in_highway(x: int, y: int) -> bool:
	return _highway[_d.idx(x, y)] == 1


## True when making (x, y) a road would close a 2x2 square of road cells.
func _closes_square(x: int, y: int) -> bool:
	for sy in [-1, 0]:
		for sx in [-1, 0]:
			var full := true
			for dy in 2:
				for dx in 2:
					var cx: int = x + sx + dx
					var cy: int = y + sy + dy
					if (cx != x or cy != y) and not _road(cx, cy):
						full = false
			if full:
				return true
	return false


# --- Two roads side by side ----------------------------------------------------------------------
## Removes road cells of 2x2 squares outside the highways when the roads round them stay
## joined without them (the classic thinning of a raster line). Streets go before avenues.
func _thin() -> void:
	for pass_i in 8:
		var removed := 0
		for want in [CityTypes.ROAD_STREET, CityTypes.ROAD_AVENUE]:
			for y in range(1, _d.size - 1):
				for x in range(1, _d.size - 1):
					var i := _d.idx(x, y)
					if (_d.road[i] & 3) != want or _is_bridge(x, y) or _in_highway(x, y):
						continue
					if _in_square(x, y) and _removable(x, y):
						_d.road[i] = 0
						removed += 1
		stats["thinned"] += removed
		if removed == 0:
			break


func _in_square(x: int, y: int) -> bool:
	for sy in [-1, 0]:
		for sx in [-1, 0]:
			if _road(x + sx, y + sy) and _road(x + sx + 1, y + sy) \
					and _road(x + sx, y + sy + 1) and _road(x + sx + 1, y + sy + 1):
				return true
	return false


## The road neighbours of (x, y) stay joined to each other through the 8 cells round it, and
## none of them becomes a dead end.
func _removable(x: int, y: int) -> bool:
	var ring: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
			Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
	var on := PackedByteArray()
	on.resize(8)
	for k in 8:
		on[k] = 1 if _road(x + ring[k].x, y + ring[k].y) else 0
	# Groups of road cells in the ring, joined by sides only (a diagonal cell joins nothing
	# unless the side cell next to it is road).
	var group := PackedInt32Array([-1, -1, -1, -1, -1, -1, -1, -1])
	var groups := 0
	for k in 8:
		if on[k] == 0 or group[k] >= 0:
			continue
		var stack := [k]
		group[k] = groups
		while not stack.is_empty():
			var c: int = stack.pop_back()
			for step in [-1, 1]:
				var nb: int = (c + step + 8) % 8
				if on[nb] == 1 and group[nb] < 0:
					# Ring neighbours share a side, except two side cells across a corner gap.
					group[nb] = groups
					stack.append(nb)
		groups += 1
	var side_groups := {}
	for k in [0, 2, 4, 6]:
		if on[k] == 1:
			side_groups[group[k]] = true
	if side_groups.size() != 1:
		return false
	for k in [0, 2, 4, 6]:
		if on[k] == 1 and _degree(x + ring[k].x, y + ring[k].y) <= 2 \
				and not _in_square_without(x + ring[k].x, y + ring[k].y, x, y):
			# The neighbour would be left with one way only: only fine inside the fat part.
			return false
	return true


## (x, y) keeps at least two road neighbours once (rx, ry) is gone.
func _in_square_without(x: int, y: int, rx: int, ry: int) -> bool:
	var n := 0
	for o in CityTypes.FACING_OFFSETS:
		var c := Vector2i(x + o.x, y + o.y)
		if (c.x != rx or c.y != ry) and _road(c.x, c.y):
			n += 1
	return n >= 2


# --- Roads touching by a corner ------------------------------------------------------------------
func _fix_corners() -> void:
	for y in range(1, _d.size - 1):
		for x in range(1, _d.size - 1):
			if not _road(x, y):
				continue
			for o: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1)]:
				if not _road(x + o.x, y + o.y) or _road(x + o.x, y) or _road(x, y + o.y):
					continue
				var kind := mini(_d.road[_d.idx(x, y)] & 3, _d.road[_d.idx(x + o.x, y + o.y)] & 3)
				for c: Vector2i in [Vector2i(x + o.x, y), Vector2i(x, y + o.y)]:
					if _free(c.x, c.y) and not _closes_square(c.x, c.y):
						_d.road[_d.idx(c.x, c.y)] = kind
						stats["corners"] += 1
						break


# --- Loose groups --------------------------------------------------------------------------------
## Labels every road cell with its group; the bridges to the urban island and to the fog
## island count as road. Returns the size of each group.
func _label(label: PackedInt32Array) -> PackedInt32Array:
	label.resize(_d.size * _d.size)
	label.fill(-1)
	var sizes := PackedInt32Array()
	for y in _d.size:
		for x in _d.size:
			var i := _d.idx(x, y)
			if _d.road[i] == 0 or label[i] >= 0:
				continue
			var id := sizes.size()
			var n := 0
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			label[i] = id
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				if _d.road[_d.idx(c.x, c.y)] != 0:
					n += 1
				for o in CityTypes.FACING_OFFSETS:
					var q: Vector2i = c + o
					if not _d.in_bounds(q.x, q.y) or not MapAudit.is_link(_d, q.x, q.y):
						continue
					var qi := _d.idx(q.x, q.y)
					if label[qi] < 0:
						label[qi] = id
						stack.append(q)
			sizes.append(n)
	return sizes


func _join_groups() -> void:
	for round_i in 6:
		var label := PackedInt32Array()
		var sizes := _label(label)
		if sizes.size() <= 1:
			return
		var main := 0
		for g in sizes.size():
			if sizes[g] > sizes[main]:
				main = g
		var changed := false
		for g in sizes.size():
			if g == main:
				continue
			var cells: Array[Vector2i] = []
			for y in _d.size:
				for x in _d.size:
					if label[_d.idx(x, y)] == g and _d.road[_d.idx(x, y)] != 0:
						cells.append(Vector2i(x, y))
			var way := _way_to_network(cells, label, g, JOIN_REACH * 2)
			if not way.is_empty():
				for c in way:
					_d.road[_d.idx(c.x, c.y)] = CityTypes.ROAD_STREET
				stats["groups_joined"] += 1
				changed = true
			elif sizes[g] < SMALL_GROUP:
				for c in cells:
					_d.road[_d.idx(c.x, c.y)] = 0
				stats["groups_removed"] += 1
				changed = true
			else:
				push_warning("[Roads] %d road cells round %s are not joined to the network" % [sizes[g], cells[0]])
		if not changed:
			return


## Shortest way over free land from any of `cells` to a road of another group: the new cells.
func _way_to_network(cells: Array[Vector2i], label: PackedInt32Array, own: int, reach: int) -> Array[Vector2i]:
	var prev := {}
	var queue: Array[Vector2i] = []
	for c in cells:
		prev[c] = c
		queue.append(c)
	var dist := {}
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var dcur: int = dist.get(cur, 0)
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = cur + o
			if prev.has(q) or not _d.in_bounds(q.x, q.y):
				continue
			var qi := _d.idx(q.x, q.y)
			if _d.road[qi] != 0:
				if label[qi] != own and dcur > 0:
					return _trace(prev, cur)
				continue
			if dcur >= reach or not _free(q.x, q.y):
				continue
			prev[q] = cur
			dist[q] = dcur + 1
			queue.append(q)
	return []


func _trace(prev: Dictionary, last: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := last
	while prev[c] != c:
		out.append(c)
		c = prev[c]
	return out


# --- Dead ends -----------------------------------------------------------------------------------
func _close_dead_ends() -> void:
	for pass_i in 4:
		var changed := 0
		for y in range(1, _d.size - 1):
			for x in range(1, _d.size - 1):
				if not _road(x, y) or _degree(x, y) != 1 or _is_bridge(x, y) or _at_bridge_head(x, y):
					continue
				var way := _way_from_tip(Vector2i(x, y))
				if not way.is_empty():
					for c in way:
						_d.road[_d.idx(c.x, c.y)] = CityTypes.ROAD_STREET
					stats["joined"] += 1
					changed += 1
					continue
				var branch := _branch(Vector2i(x, y))
				if branch.size() < MIN_CUL_DE_SAC:
					for c in branch:
						_d.road[_d.idx(c.x, c.y)] = 0
					stats["trimmed"] += 1
					changed += 1
		if changed == 0:
			break


func _at_bridge_head(x: int, y: int) -> bool:
	var wb := _d.west_bridge
	if wb.x >= 0 and absi(y - wb.z) <= 1 and (absi(x - wb.x) <= 1 or absi(x - wb.y) <= 1):
		return true
	return _d.bridge.x >= 0 and absi(y - _d.bridge.y) <= 1 and absi(x - _d.bridge.x) <= 2


## The cells of the dead end from its tip back to (not including) the first junction.
func _branch(tip: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [tip]
	var prev := tip
	var cur := tip
	while out.size() < 64:
		var next := Vector2i(-1, -1)
		var ways := 0
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = cur + o
			if q != prev and _road(q.x, q.y):
				ways += 1
				next = q
		if ways != 1 or _degree(next.x, next.y) != 2:
			break
		out.append(next)
		prev = cur
		cur = next
	return out


## New road cells from the tip of a dead end to another road: straight on first, then the
## shortest way over free land. No new cell may lie beside a road it does not join.
func _way_from_tip(tip: Vector2i) -> Array[Vector2i]:
	var back := Vector2i.ZERO
	for o in CityTypes.FACING_OFFSETS:
		if _road(tip.x + o.x, tip.y + o.y):
			back = o
	var prev := {tip: tip}
	var dist := {tip: 0}
	var queue: Array[Vector2i] = [tip]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var dcur: int = dist[cur]
		# Straight on first, so that the street goes on in its line when it can.
		var dirs: Array[Vector2i] = [-back, Vector2i(-back.y, back.x), Vector2i(back.y, -back.x), back]
		for o in dirs:
			var q: Vector2i = cur + o
			if prev.has(q) or not _free(q.x, q.y) or dcur >= JOIN_REACH:
				continue
			# Roads beside the new cell, the one it comes from left out.
			var beside := 0
			for o2 in CityTypes.FACING_OFFSETS:
				var s: Vector2i = q + o2
				if s != cur and _road(s.x, s.y):
					beside += 1
			if cur == tip and beside == 0 or cur != tip and beside == 0:
				prev[q] = cur
				dist[q] = dcur + 1
				queue.append(q)
			elif beside == 1 and not _closes_square_with(q, prev, cur):
				prev[q] = cur
				return _trace(prev, q)
	return []


## True when the new cell `q` (after the path cells up to `cur`) closes a 2x2 road square.
func _closes_square_with(q: Vector2i, prev: Dictionary, cur: Vector2i) -> bool:
	var path := {}
	var c := cur
	while prev[c] != c:
		path[c] = true
		c = prev[c]
	for sy in [-1, 0]:
		for sx in [-1, 0]:
			var full := true
			for dy in 2:
				for dx in 2:
					var p := Vector2i(q.x + sx + dx, q.y + sy + dy)
					if p != q and not _road(p.x, p.y) and not path.has(p):
						full = false
			if full:
				return true
	return false


# --- Highways ------------------------------------------------------------------------------------
## The road that crosses the end of a highway becomes an avenue along its straight run.
func _promote_highway_crossings() -> void:
	for h in MapAudit.highways(_d):
		for side: String in ["west", "east"]:
			if h[side] != "street":
				continue
			var x: int = h["from"] if side == "west" else h["to"]
			var dir := -1 if side == "west" else 1
			for cx: int in [x + dir, x]:
				if not (_road(cx, h["row"] - 1) and _road(cx, h["row"]) and _road(cx, h["row"] + 1)):
					continue
				if not (_road(cx, h["row"] - 2) or _road(cx, h["row"] + 2)):
					continue
				for step in [-1, 1]:
					var y: int = h["row"]
					while _road(cx, y):
						var i := _d.idx(cx, y)
						if (_d.road[i] & 3) != CityTypes.ROAD_AVENUE:
							_d.road[i] = (_d.road[i] & ~3) | CityTypes.ROAD_AVENUE
						y += step
				stats["promoted"] += 1
				break
