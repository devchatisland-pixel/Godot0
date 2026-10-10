class_name MapAudit
extends RefCounted
## Measures a generated map: what must stay the same when the map is rebuilt (how many
## buildings of each kind, which zones touch, the fog island) and what is wrong with its
## roads. Pure functions on CityData, so the tests and the tools share them.
## See tests/test_map_audit.gd and tests/baseline/map_snapshot.json.

const Zone := CityTypes.Zone
const Terrain := CityTypes.Terrain

## Zones whose buildings must stand on a street.
const STREET_ZONES: Array[int] = [
	Zone.DOWNTOWN, Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN, Zone.QUARTER, Zone.POOR, Zone.URBAN,
]
## Kinds that are not buildings on a lot (ground details, things at sea or in the air).
const NOT_LOTS: Array[String] = [
	"EMPTY", "PLAZA", "GARDEN", "BOAT", "PIER", "BALLOON", "BILLBOARD", "BUS_STOP", "UFO", "TANK",
	"FIRE_TRUCK", "GRAVE", "PIRATE_SHIP", "MOUNTAIN", "MESA", "POND", "FIELD", "LIGHTHOUSE",
	"WATCHTOWER", "BEACH_HUT", "FOUNTAIN",
]


# --- What must be kept ---------------------------------------------------------------------------

## Buildings per kind name (cleared lots are left out).
static func kind_counts(data: CityData) -> Dictionary:
	var names := CityTypes.Kind.keys()
	var out := {}
	for b in data.building_count():
		var k: String = names[data.b_kind[b]]
		if k != "EMPTY":
			out[k] = out.get(k, 0) + 1
	return out


## Land cells per zone name.
static func zone_cells(data: CityData) -> Dictionary:
	var names := CityTypes.Zone.keys()
	var out := {}
	for i in data.zone.size():
		if data.terrain[i] >= Terrain.BEACH:
			var z: String = names[data.zone[i]]
			out[z] = out.get(z, 0) + 1
	return out


## Which zones touch: {"A|B": cells of border} with A < B by name. Roads between two zones
## do not hide the contact: the search looks up to `reach` cells across.
static func zone_adjacency(data: CityData, reach: int = 3) -> Dictionary:
	var names := CityTypes.Zone.keys()
	var out := {}
	for y in data.size:
		for x in data.size:
			var i := data.idx(x, y)
			if data.terrain[i] < Terrain.BEACH or data.zone[i] == Zone.NONE:
				continue
			var a: String = names[data.zone[i]]
			for o: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for k in range(1, reach + 1):
					var q: Vector2i = Vector2i(x, y) + o * k
					if not data.in_bounds(q.x, q.y):
						break
					var j := data.idx(q.x, q.y)
					if data.terrain[j] < Terrain.BEACH:
						break
					if data.zone[j] == data.zone[i]:
						break
					if data.zone[j] == Zone.NONE:
						continue
					var b: String = names[data.zone[j]]
					var key := "%s|%s" % ([a, b] if a < b else [b, a])
					out[key] = out.get(key, 0) + 1
					break
	return out


## Hash of the fog island as it is drawn (its position on the map is not part of it).
static func fog_hash(data: CityData) -> String:
	var fog := data.fog
	if fog == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(fog.elevation)
	ctx.update(fog.colors)
	var rel := PackedStringArray()
	for b in fog.buildings:
		var p: Vector2 = (b[0] as Vector2) - fog.origin
		rel.append("%.2f %.2f %s %s" % [p.x, p.y, b[1], b[2]])
	for t in fog.trees:
		var p: Vector2 = (t[0] as Vector2) - fog.origin
		rel.append("%.2f %.2f %s %s" % [p.x, p.y, t[1], t[2]])
	ctx.update("\n".join(rel).to_utf8_buffer())
	return ctx.finish().hex_encode()


## Hash of the whole generated map (every cell layer and every building): two maps with the
## same hash are the same map. Used to check that a change of the code moves nothing.
static func data_hash(data: CityData) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for layer: PackedByteArray in [data.terrain, data.zone, data.road, data.elevation, data.forest,
			data.rocky, data.occupied, data.deco, data.edge, data.b_kind, data.b_facing,
			data.b_sign, data.b_sign_facing]:
		ctx.update(layer if not layer.is_empty() else PackedByteArray([0]))
	ctx.update(data.b_rect.to_byte_array())
	ctx.update(data.b_seed.to_byte_array())
	ctx.update(data.b_height.to_byte_array())
	ctx.update(data.b_scale.to_byte_array())
	var models := PackedStringArray()
	var keys := data.b_model.keys()
	keys.sort()
	for k in keys:
		models.append("%s=%s" % [k, data.b_model[k]])
	ctx.update(("%s %s %s %s" % [data.size, data.bridge, data.west_bridge, ",".join(models)]).to_utf8_buffer())
	return ctx.finish().hex_encode() + ":" + fog_hash(data)


# --- Roads ---------------------------------------------------------------------------------------

## True when (x, y) carries traffic: a road cell, or the deck of the metal bridge to the urban
## island (the bridge is a model, not road cells).
static func is_link(data: CityData, x: int, y: int) -> bool:
	if data.is_road(x, y):
		return true
	var wb := data.west_bridge
	return wb.x >= 0 and absi(y - wb.z) <= 1 and x > wb.y and x < wb.x


## True when column x of row y is at the head of one of the two big bridges.
static func at_bridge_head(data: CityData, x: int, y: int) -> bool:
	var wb := data.west_bridge
	if wb.x >= 0 and absi(y - wb.z) <= 1 and (absi(x - wb.x) <= 2 or absi(x - wb.y) <= 2):
		return true
	return data.bridge.x >= 0 and absi(y - data.bridge.y) <= 1 and absi(x - data.bridge.x) <= 2


## Connected groups of road cells, biggest first: [{"cells": n, "at": Vector2i (one cell)}].
static func road_components(data: CityData) -> Array[Dictionary]:
	var seen := PackedByteArray()
	seen.resize(data.size * data.size)
	var out: Array[Dictionary] = []
	for y in data.size:
		for x in data.size:
			var i := data.idx(x, y)
			if data.road[i] == 0 or seen[i] == 1:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[i] = 1
			var n := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				if data.is_road(c.x, c.y):
					n += 1
				for o in CityTypes.FACING_OFFSETS:
					var q: Vector2i = c + o
					if is_link(data, q.x, q.y) and seen[data.idx(q.x, q.y)] == 0:
						seen[data.idx(q.x, q.y)] = 1
						stack.append(q)
			out.append({"cells": n, "at": Vector2i(x, y)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cells"] > b["cells"])
	return out


## Road cells on water that are not flagged as a bridge.
static func roads_on_water(data: CityData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in data.size:
		for x in data.size:
			var i := data.idx(x, y)
			if data.road[i] != 0 and data.terrain[i] < Terrain.BEACH \
					and (data.road[i] & CityTypes.ROAD_BRIDGE_FLAG) == 0:
				out.append(Vector2i(x, y))
	return out


## Buildings (not cleared lots) with a road cell under them: [building id].
static func buildings_on_roads(data: CityData) -> PackedInt32Array:
	var out := PackedInt32Array()
	for b in data.building_count():
		# Balloons float: what is under them does not matter.
		if data.b_kind[b] == CityTypes.Kind.EMPTY or data.b_kind[b] == CityTypes.Kind.BALLOON:
			continue
		var r := data.building_rect(b)
		var hit := false
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if data.is_road(x, y):
					hit = true
		if hit:
			out.append(b)
	return out


## Buildings that overlap another building: [building id] (the later one of each pair).
static func overlapping_buildings(data: CityData) -> PackedInt32Array:
	var names := CityTypes.Kind.keys()
	var owner := {}
	var out := PackedInt32Array()
	for b in data.building_count():
		var k: String = names[data.b_kind[b]]
		if k == "EMPTY" or k == "BALLOON":
			continue
		var r := data.building_rect(b)
		var hit := false
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if owner.has(c):
					hit = true
				else:
					owner[c] = b
		if hit:
			out.append(b)
	return out


## Buildings of the street zones with no road within `reach` cells of their lot: [building id].
## The urban island is left out: it has no streets on purpose (UrbanIslandRebuild).
static func lots_without_road(data: CityData, reach: int = 2) -> PackedInt32Array:
	var names := CityTypes.Kind.keys()
	var out := PackedInt32Array()
	for b in data.building_count():
		if NOT_LOTS.has(names[data.b_kind[b]]):
			continue
		var r := data.building_rect(b)
		if not STREET_ZONES.has(data.zone_at(r.position.x, r.position.y)):
			continue
		if MapLayout.on_urban_island(r.get_center()):
			continue
		var found := false
		for y in range(r.position.y - reach, r.end.y + reach):
			for x in range(r.position.x - reach, r.end.x + reach):
				if data.is_road(x, y):
					found = true
		if not found:
			out.append(b)
	return out


## Cells of the dead end at `tip`, back to its first junction (the junction left out).
static func dead_end_length(data: CityData, tip: Vector2i) -> int:
	var n := 1
	var prev := tip
	var cur := tip
	while n < 64:
		var next := Vector2i(-1, -1)
		var ways := 0
		for o in CityTypes.FACING_OFFSETS:
			var q: Vector2i = cur + o
			if q != prev and data.is_road(q.x, q.y):
				ways += 1
				next = q
		if ways != 1:
			break
		var deg := 0
		for o in CityTypes.FACING_OFFSETS:
			if data.is_road(next.x + o.x, next.y + o.y):
				deg += 1
		if deg != 2:
			break
		n += 1
		prev = cur
		cur = next
	return n


## Dead ends shorter than `min_length` cells: stubs, a bug. The longer ones are cul-de-sacs.
static func stubs(data: CityData, min_length: int = 3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for tip in dead_ends(data):
		if dead_end_length(data, tip) < min_length:
			out.append(tip)
	return out


## Road cells that are a dead end (one neighbour or none), the heads of the two big bridges
## left out.
static func dead_ends(data: CityData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in data.size:
		for x in data.size:
			if not data.is_road(x, y) or at_bridge_head(data, x, y):
				continue
			var m := data.road_mask(x, y)
			if m == CityTypes.DIR_N or m == CityTypes.DIR_E or m == CityTypes.DIR_S or m == CityTypes.DIR_W or m == 0:
				out.append(Vector2i(x, y))
	return out


## Road cells that touch another road only by a corner (it reads as a gap in the street).
static func diagonal_gaps(data: CityData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in data.size:
		for x in data.size:
			if not data.is_road(x, y):
				continue
			for o: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1)]:
				if data.is_road(x + o.x, y + o.y) and not data.is_road(x + o.x, y) and not data.is_road(x, y + o.y):
					out.append(Vector2i(x, y))
	return out


## True when (x, y) is the middle lane of a highway: three avenue cells one above the other.
static func is_highway_lane(data: CityData, x: int, y: int) -> bool:
	if y < 1 or y >= data.size - 1 or x < 0 or x >= data.size:
		return false
	for dy in range(-1, 2):
		if (data.road[data.idx(x, y + dy)] & 3) != CityTypes.ROAD_AVENUE:
			return false
	return true


## 1 on the cells of the highways (the three lanes of every run found by `highways`).
static func highway_mask(data: CityData) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(data.size * data.size)
	for h in highways(data):
		for x in range(int(h["from"]), int(h["to"]) + 1):
			for dy in range(-1, 2):
				mask[data.idx(x, int(h["row"]) + dy)] = 1
	return mask


## 2x2 squares of road outside the highways, counted by their top-left cell: two streets side
## by side, drawn as a carpet of junction tiles (the texture bug of the wide roads). A square
## with two cells or more on a highway is the mouth of a road that joins it, not a bug.
static func fat_roads(data: CityData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hw_mask := highway_mask(data)
	for y in data.size - 1:
		for x in data.size - 1:
			if data.is_road(x, y) and data.is_road(x + 1, y) and data.is_road(x, y + 1) and data.is_road(x + 1, y + 1):
				var hw := 0
				for c: Vector2i in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
					hw += hw_mask[data.idx(c.x, c.y)]
				if hw < 2:
					out.append(Vector2i(x, y))
	return out


## The highways (runs of the middle lane along x) and how each end is closed:
## [{"row", "from", "to", "west", "east"}], an end being "bridge" (it goes on over the water),
## "avenue" or "street" (a road crosses its whole width there and goes on at least on one
## side: a proper junction), or "open" (the three lanes just stop: a bug).
static func highways(data: CityData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for y in range(1, data.size - 1):
		var x := 0
		while x < data.size:
			if not is_highway_lane(data, x, y) or is_highway_lane(data, x, y - 1):
				x += 1
				continue
			var from := x
			while x < data.size and is_highway_lane(data, x, y):
				x += 1
			if x - from < 4:
				continue # a wide junction, not a highway
			out.append({"row": y, "from": from, "to": x - 1,
					"west": _highway_end(data, from, y, -1), "east": _highway_end(data, x - 1, y, 1)})
	return out


static func _highway_end(data: CityData, x: int, y: int, dir: int) -> String:
	if at_bridge_head(data, x, y):
		return "bridge"
	# A bridge: the lanes themselves carry the flag near the end, or the cell beyond is water.
	for k in range(0, 3):
		var bx := x - dir * k
		if data.in_bounds(bx, y) and (data.road[data.idx(bx, y)] & CityTypes.ROAD_BRIDGE_FLAG) != 0:
			return "bridge"
	var nx := x + dir
	if not data.in_bounds(nx, y) or data.terrain[data.idx(nx, y)] < Terrain.BEACH:
		return "bridge" if data.in_bounds(nx, y) and data.is_road(nx, y) else "coast"
	# A crossing road: in the last column of the lanes or just beyond, over the whole width
	# and further on one side at least.
	for cx: int in [nx, x]:
		var across := true
		var avenue := true
		for dy in range(-1, 2):
			if not data.is_road(cx, y + dy):
				across = false
			elif (data.road[data.idx(cx, y + dy)] & 3) != CityTypes.ROAD_AVENUE:
				avenue = false
		if not across:
			continue
		var up := data.is_road(cx, y - 2)
		var down := data.is_road(cx, y + 2)
		if up or down:
			var big := avenue
			for sy: int in [y - 2, y + 2]:
				if data.is_road(cx, sy) and (data.road[data.idx(cx, sy)] & 3) != CityTypes.ROAD_AVENUE:
					big = false
			return "avenue" if big else "street"
	return "open"


# --- Report --------------------------------------------------------------------------------------

## Everything above in one dictionary of plain values (written as JSON for the baseline).
static func snapshot(data: CityData) -> Dictionary:
	var comps := road_components(data)
	var road_cells := 0
	for c in comps:
		road_cells += c["cells"]
	var ends := {}
	var hw := []
	for h in highways(data):
		hw.append(h)
		for side: String in ["west", "east"]:
			ends[h[side]] = ends.get(h[side], 0) + 1
	return {
		"size": data.size,
		"buildings": data.building_count(),
		"kinds": kind_counts(data),
		"zone_cells": zone_cells(data),
		"zone_adjacency": zone_adjacency(data),
		"fog_hash": fog_hash(data),
		"roads": {
			"cells": road_cells,
			"components": comps.size(),
			"cells_off_network": road_cells - (comps[0]["cells"] if not comps.is_empty() else 0),
			"on_water": roads_on_water(data).size(),
			"under_buildings": buildings_on_roads(data).size(),
			"overlapping_buildings": overlapping_buildings(data).size(),
			"lots_without_road": lots_without_road(data).size(),
			"stubs": stubs(data).size(),
			"cul_de_sacs": dead_ends(data).size() - stubs(data).size(),
			"diagonal_gaps": diagonal_gaps(data).size(),
			"fat_roads": fat_roads(data).size(),
			"highways": hw,
			"highway_ends": ends,
		},
	}
