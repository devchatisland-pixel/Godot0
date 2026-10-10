class_name VehicleSites
extends RefCounted
## Decides where the vehicles of the catalog (res://vehicles) stand on the island.
## Pure data in, a list of placements out, so it can be checked headless (tests/test_vehicles.gd).
## Each placement: {"id": catalog id, "at": Vector2 (cells, x/z), "yaw": radians, "why": text}.
## The vehicle models face -Z; MapVehicles turns them with `yaw`.
##
## It runs after the generation and the hand edits, so it never moves a building: it only
## looks for free cells (land, no road, no building, nothing placed before).

const Kind := CityTypes.Kind
const Zone := CityTypes.Zone

## Cells per metre (a 4.8 m sedan is 0.82 cell long, like the police cars of the roadblocks).
const CELLS_PER_METRE := 0.17

const CITY_ZONES: Array[int] = [Zone.DOWNTOWN, Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN]
const STREET_CARS: Array[String] = ["m8_long_sedan_black", "m8_long_sedan_silver", "m8_long_sedan_charcoal"]

var out: Array[Dictionary] = []

var _d: CityData
## 1 where a building or an earlier off-road vehicle is.
var _taken := PackedByteArray()
## Length in cells per catalog id (from size_m in the catalog); sedan length otherwise.
var lengths := {}


func _init(data: CityData) -> void:
	_d = data


static func plan(data: CityData, lengths_m: Dictionary = {}) -> Array[Dictionary]:
	var s := VehicleSites.new(data)
	for id in lengths_m:
		s.lengths[id] = float(lengths_m[id]) * CELLS_PER_METRE
	s._run()
	return s.out


func _run() -> void:
	_taken.resize(_d.size * _d.size)
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.EMPTY:
			continue
		var r := _d.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _d.in_bounds(x, y):
					_taken[_d.idx(x, y)] = 1
	_street_sedans()
	_forest_suv()
	_farm_machines()
	_industrial_zones()
	_hospital_ambulance()
	_fire_station_truck()
	_container_tanker()
	_nuclear_plant_convoy()
	_desert()
	_airport()
	_bus_stops()


# --- Streets -----------------------------------------------------------------------------

## 12 long sedans (black, silver, charcoal in turn) on the streets, and 12 mustard sedans:
## half in the red district (the colourful quarter), half in the city.
func _street_sedans() -> void:
	var city := _straight_roads(CITY_ZONES)
	var quarter := _straight_roads([Zone.QUARTER])
	var spots := _spread(city, 12, 9.0, 11)
	for i in spots.size():
		_add_on_road(STREET_CARS[i % 3], spots[i], "street")
	for c in _spread(city, 6, 9.0, 23):
		_add_on_road("m8_sedan_mustard", c, "city street")
	for c in _spread(quarter, 6, 7.0, 29):
		_add_on_road("m8_sedan_mustard", c, "red district street")


## Cells of straight street or avenue (no junction, no bridge) inside the given zones.
func _straight_roads(zones: Array) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for y in range(1, _d.size - 1):
		for x in range(1, _d.size - 1):
			var i := _d.idx(x, y)
			if _d.road[i] == 0 or (_d.road[i] & CityTypes.ROAD_BRIDGE_FLAG) != 0:
				continue
			var m := _d.road_mask(x, y)
			if m != (CityTypes.DIR_E | CityTypes.DIR_W) and m != (CityTypes.DIR_N | CityTypes.DIR_S):
				continue
			if _zone_near(x, y, zones):
				res.append(Vector2i(x, y))
	return res


func _zone_near(x: int, y: int, zones: Array) -> bool:
	if zones.has(_d.zone_at(x, y)):
		return true
	for o in CityTypes.FACING_OFFSETS:
		if zones.has(_d.zone_at(x + o.x, y + o.y)):
			return true
	return false


## Picks `count` cells at least `gap` apart (greedy, in hash order) and away from the
## vehicles placed before.
func _spread(cands: Array[Vector2i], count: int, gap: float, salt: int) -> Array[Vector2i]:
	var list := cands.duplicate()
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return CityTypes.hash2(a.x, a.y, salt) < CityTypes.hash2(b.x, b.y, salt))
	var res: Array[Vector2i] = []
	for c: Vector2i in list:
		if res.size() >= count:
			break
		if _near_placed(Vector2(c) + Vector2(0.5, 0.5), gap):
			continue
		var far := true
		for r in res:
			if Vector2(r).distance_to(Vector2(c)) < gap:
				far = false
				break
		if far:
			res.append(c)
	return res


func _near_placed(p: Vector2, gap: float) -> bool:
	for v in out:
		if (v["at"] as Vector2).distance_to(p) < gap:
			return true
	return false


## Puts a vehicle in the middle of a road cell, nose along the road (the direction it
## drives depends on the cell).
func _add_on_road(id: String, c: Vector2i, why: String) -> void:
	var m := _d.road_mask(c.x, c.y)
	var along := Vector2(1, 0) if m == (CityTypes.DIR_E | CityTypes.DIR_W) else Vector2(0, 1)
	if CityTypes.hash2(c.x, c.y, 3) & 1 == 1:
		along = -along
	_add(id, Vector2(c) + Vector2(0.5, 0.5), along, why)


func _add(id: String, at: Vector2, heading: Vector2, why: String) -> void:
	out.append({"id": id, "at": at, "yaw": atan2(-heading.x, -heading.y), "why": why})
	var half := ceili(maxf(0.5, _length(id) * 0.5))
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var cx := int(floor(at.x)) + dx
			var cy := int(floor(at.y)) + dy
			if _d.in_bounds(cx, cy) and _d.road[_d.idx(cx, cy)] == 0:
				_taken[_d.idx(cx, cy)] = 1


func _length(id: String) -> float:
	return lengths.get(id, 4.8 * CELLS_PER_METRE)


# --- Free ground -------------------------------------------------------------------------

func _free(x: int, y: int) -> bool:
	return _d.is_land(x, y) and _d.road[_d.idx(x, y)] == 0 and _taken[_d.idx(x, y)] == 0


## True when a vehicle of `length` cells centred on `at`, nose along `heading`, lies only
## on free ground.
func _fits(at: Vector2, heading: Vector2, length: float) -> bool:
	var h := heading.normalized()
	var side := Vector2(-h.y, h.x) * 0.3
	var n := ceili(length / 0.4)
	for k in range(-n / 2, n / 2 + 1):
		var p := at + h * (float(k) * 0.4)
		for s in [-1.0, 0.0, 1.0]:
			var q: Vector2 = p + side * float(s)
			if not _free(int(floor(q.x)), int(floor(q.y))):
				return false
	return true


## Free spot just outside `rect` (between `gap` and `gap + reach` cells), parallel to the
## nearest side; the closest one to the building wins, the hash breaks ties.
func _beside(id: String, rect: Rect2i, why: String, salt: int, gap: float = 1.2, reach: float = 4.0) -> bool:
	var best := Vector2.ZERO
	var best_head := Vector2.ZERO
	var best_key := -1
	var len := _length(id)
	var m := gap + reach
	var x0 := rect.position.x - ceili(m)
	var y0 := rect.position.y - ceili(m)
	var x1 := rect.end.x + ceili(m)
	var y1 := rect.end.y + ceili(m)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			# Distance to the rect on each axis (0 when level with it).
			var dx := maxf(maxf(float(rect.position.x) - p.x, p.x - float(rect.end.x)), 0.0)
			var dy := maxf(maxf(float(rect.position.y) - p.y, p.y - float(rect.end.y)), 0.0)
			var dist := maxf(dx, dy)
			if dist < gap or dist > m:
				continue
			var head := Vector2(1, 0) if dx >= dy else Vector2(0, 1)
			if dx == 0.0:
				head = Vector2(1, 0)   # above or below: along the long side
			elif dy == 0.0:
				head = Vector2(0, 1)
			if not _fits(p, head, len):
				continue
			var key := int(maxf(0.0, 99.0 - dist * 8.0)) * 65536 + (CityTypes.hash2(x, y, salt) & 0xffff)
			if key > best_key:
				best_key = key
				best = p
				best_head = head
	if best_key < 0:
		push_warning("[Vehicles] no room for %s (%s)" % [id, why])
		return false
	_add(id, best, best_head, why)
	return true


# --- Forest, fields ------------------------------------------------------------------------

## The off-road SUV, on a country road with the densest forest around it.
func _forest_suv() -> void:
	var best := Vector2i(-1, -1)
	var best_score := -1
	for c in _straight_roads([Zone.NATURE, Zone.FARM, Zone.PARK]):
		var score := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var x := c.x + dx
				var y := c.y + dy
				if _d.in_bounds(x, y) and _d.forest[_d.idx(x, y)] > 90:
					score += 1
		score = score * 100 + (CityTypes.hash2(c.x, c.y, 41) & 63)
		if score > best_score:
			best_score = score
			best = c
	if best.x >= 0 and best_score >= 100:
		_add_on_road("p54_01_suv_offroad_navy", best, "beside the forest")
	else:
		push_warning("[Vehicles] no forest road for the SUV")


## One machine in each of three different crop fields (the biggest ones, far apart).
func _farm_machines() -> void:
	var fields: Array[int] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.FIELD:
			fields.append(b)
	fields.sort_custom(func(a: int, b: int) -> bool:
		var ra := _d.building_rect(a)
		var rb := _d.building_rect(b)
		var aa := ra.size.x * ra.size.y
		var ab := rb.size.x * rb.size.y
		if aa != ab:
			return aa > ab
		return CityTypes.hash2(ra.position.x, ra.position.y, 5) < CityTypes.hash2(rb.position.x, rb.position.y, 5))
	var ids := ["p54_21_harvester_olive", "p54_41_loader_claw_yellow", "p54_43_tractor_vintage_trailer"]
	var used: Array[Rect2i] = []
	var k := 0
	for b in fields:
		if k >= ids.size():
			break
		var r := _d.building_rect(b)
		var apart := true
		for u in used:
			if Vector2(u.get_center()).distance_to(Vector2(r.get_center())) < 12.0:
				apart = false
		if not apart:
			continue
		var head := Vector2(1, 0) if r.size.x >= r.size.y else Vector2(0, 1)
		_add(ids[k], Vector2(r.position) + Vector2(r.size) * 0.5, head, "in an agricultural field")
		used.append(r)
		k += 1
	if k < ids.size():
		push_warning("[Vehicles] only %d crop fields found" % k)


# --- Industrial zones, port -------------------------------------------------------------------

## Connected industrial zones, biggest first: [{"cells": n, "center": Vector2, "rect": Rect2i}].
func industrial_zones() -> Array[Dictionary]:
	var seen := {}
	var comps: Array[Dictionary] = []
	for y in _d.size:
		for x in _d.size:
			var i := _d.idx(x, y)
			if _d.zone[i] != Zone.INDUSTRIAL or seen.has(i) or not _d.is_land(x, y):
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[i] = true
			var n := 0
			var sum := Vector2.ZERO
			var lo := Vector2i(x, y)
			var hi := Vector2i(x, y)
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				n += 1
				sum += Vector2(c)
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				for o in CityTypes.FACING_OFFSETS:
					var q: Vector2i = c + o
					if _d.in_bounds(q.x, q.y):
						var qi := _d.idx(q.x, q.y)
						if _d.zone[qi] == Zone.INDUSTRIAL and not seen.has(qi):
							seen[qi] = true
							stack.append(q)
			comps.append({"cells": n, "center": sum / float(n), "rect": Rect2i(lo, hi - lo + Vector2i.ONE)})
	comps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cells"] > b["cells"])
	return comps


## A mobile crane truck in the biggest industrial zone and a grapple loader in the second.
func _industrial_zones() -> void:
	var zones := industrial_zones()
	var ids := ["p54_35_crane_truck_mobile", "p54_38_loader_grapple_yellow"]
	for k in mini(ids.size(), zones.size()):
		var z: Dictionary = zones[k]
		if not _in_zone(ids[k], z["center"], "industrial zone %d" % (k + 1)):
			push_warning("[Vehicles] no room in industrial zone %d" % (k + 1))
	if zones.size() < ids.size():
		push_warning("[Vehicles] only %d industrial zone(s)" % zones.size())


## Free spot closest to `center` on industrial ground.
func _in_zone(id: String, center: Vector2, why: String) -> bool:
	var len := _length(id)
	var best := Vector2.ZERO
	var best_head := Vector2(1, 0)
	var best_d := 1e9
	var r := 30
	for y in range(int(center.y) - r, int(center.y) + r):
		for x in range(int(center.x) - r, int(center.x) + r):
			if not _d.in_bounds(x, y) or _d.zone[_d.idx(x, y)] != Zone.INDUSTRIAL:
				continue
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			var d := p.distance_to(center)
			if d >= best_d:
				continue
			for head in [Vector2(1, 0), Vector2(0, 1)]:
				if _fits(p, head, len):
					best_d = d
					best = p
					best_head = head
					break
	if best_d > 1e8:
		return false
	_add(id, best, best_head, why)
	return true


## A water tanker next to a stack of cargo containers (the yards of the port).
func _container_tanker() -> void:
	var zones := industrial_zones()
	var anchor := Vector2(_d.size, _d.size) * 0.5
	if not zones.is_empty():
		anchor = zones[0]["center"]
	var yards: Array[Rect2i] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.INDUSTRIAL_YARD:
			yards.append(_d.building_rect(b))
	yards.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return Vector2(a.get_center()).distance_to(anchor) < Vector2(b.get_center()).distance_to(anchor))
	for r in yards:
		if _beside("p54_10_tanker_water", r, "next to the container yard", 17, 0.6, 2.0):
			return


# --- Public buildings -------------------------------------------------------------------------

## In front of the main hospital (the biggest one when the city has two): on the side its
## front looks at.
func _hospital_ambulance() -> void:
	var b := _biggest(Kind.MAIN_HOSPITAL)
	if b >= 0:
		_in_front("p54_11_ambulance", b, "in front of the main hospital")
	else:
		push_warning("[Vehicles] no main hospital")


## Building of `kind` with the biggest lot (-1 when there is none).
func _biggest(kind: int) -> int:
	var best := -1
	var best_area := -1
	for b in _d.building_count():
		if _d.b_kind[b] != kind:
			continue
		var r := _d.building_rect(b)
		if r.size.x * r.size.y > best_area:
			best_area = r.size.x * r.size.y
			best = b
	return best


func _fire_station_truck() -> void:
	var best := _biggest(Kind.FIRE_STATION)
	if best >= 0:
		_in_front("p54_33_fire_truck", best, "in front of the biggest fire station")
	else:
		push_warning("[Vehicles] no fire station")


## Parked on the front side of building `b`, along the road that runs there.
func _in_front(id: String, b: int, why: String) -> void:
	var r := _d.building_rect(b)
	var o := CityTypes.FACING_OFFSETS[_d.b_facing[b]]
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	var half := Vector2(r.size) * 0.5
	var p := c + Vector2(o) * (half.x * absf(o.x) + half.y * absf(o.y) + 0.55)
	# The road in front of a building runs across the way it looks.
	var head := Vector2(1, 0) if o.y != 0 else Vector2(0, 1)
	if CityTypes.hash2(r.position.x, r.position.y, 6) & 1 == 1:
		head = -head
	_add(id, p, head, why)


## Fuel tanker, two silver box trailers, an orange crane flatbed and a brown semi trailer on
## the free ground round the nuclear plant.
func _nuclear_plant_convoy() -> void:
	var pb := _biggest(Kind.NUCLEAR_PLANT)
	if pb < 0:
		push_warning("[Vehicles] no nuclear plant")
		return
	var plant := _d.building_rect(pb)
	var ids := ["p54_18_tanker_fuel", "p54_50_trailer_box_silver", "p54_50_trailer_box_silver",
			"p54_09_flatbed_crane_orange", "p54_52_trailer_semi_brown"]
	for k in ids.size():
		_beside(ids[k], plant, "near the nuclear plant", 100 + k * 7, 1.0, 6.0)


# --- Desert, airport, buses ---------------------------------------------------------------------

## A motorhome in the middle of nowhere and a wreck elsewhere in the desert.
func _desert() -> void:
	var scored: Array[Dictionary] = []
	for y in range(4, _d.size - 4, 3):
		for x in range(4, _d.size - 4, 3):
			if _d.zone[_d.idx(x, y)] == Zone.DESERT and _d.is_land(x, y) and _free(x, y):
				scored.append({"c": Vector2i(x, y), "r": _clear_radius(Vector2i(x, y), 14)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["r"] != b["r"]:
			return a["r"] > b["r"]
		return CityTypes.hash2(a["c"].x, a["c"].y, 71) < CityTypes.hash2(b["c"].x, b["c"].y, 71))
	if scored.is_empty():
		push_warning("[Vehicles] no desert")
		return
	var rv: Vector2i = scored[0]["c"]
	_add("p54_31_rv_class_a_beige", Vector2(rv) + Vector2(0.5, 0.5), Vector2(1, 0), "middle of the desert")
	for s in scored:
		var c: Vector2i = s["c"]
		if s["r"] >= 3 and Vector2(c).distance_to(Vector2(rv)) > 18.0 and _free(c.x, c.y):
			_add("p54_12_wreck_chassis", Vector2(c) + Vector2(0.5, 0.5), Vector2(0, 1), "in the desert")
			return
	push_warning("[Vehicles] no spot for the wreck")


## Largest r <= max_r so that no road, building or water lies within r cells (square) of `c`.
func _clear_radius(c: Vector2i, max_r: int) -> int:
	for r in range(1, max_r + 1):
		for k in range(-r, r + 1):
			for p in [Vector2i(c.x + k, c.y - r), Vector2i(c.x + k, c.y + r),
					Vector2i(c.x - r, c.y + k), Vector2i(c.x + r, c.y + k)]:
				if not _d.in_bounds(p.x, p.y):
					return r - 1
				var i := _d.idx(p.x, p.y)
				if _taken[i] == 1 or _d.road[i] != 0 or _d.terrain[i] < CityTypes.Terrain.BEACH:
					return r - 1
	return max_r


func _airport() -> void:
	var b := _biggest(Kind.AIRPORT)
	if b < 0:
		push_warning("[Vehicles] no airport")
		return
	var r := _d.building_rect(b)
	_beside("police_jp_black", r, "at the airport", 201, 1.0, 5.0)
	_beside("p54_08_tow_truck_yellow", r, "at the airport", 207, 1.0, 5.0)


## A coach and an intercity bus on the road in front of two different stops of the city.
func _bus_stops() -> void:
	var middle := Vector2(_d.size, _d.size) * 0.5
	var stops: Array[int] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.BUS_STOP:
			stops.append(b)
	stops.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(_d.building_rect(a).get_center()).distance_to(middle) \
				< Vector2(_d.building_rect(b).get_center()).distance_to(middle))
	var ids := ["p54_32_bus_coach_white", "p54_34_bus_intercity_dark"]
	var k := 0
	var first := Vector2.ZERO
	for b in stops:
		if k >= ids.size():
			break
		var r := _d.building_rect(b)
		var c := Vector2(r.get_center())
		if k > 0 and c.distance_to(first) < 10.0:
			continue
		var o := CityTypes.FACING_OFFSETS[_d.b_facing[b]]
		var half := Vector2(r.size) * 0.5
		var p := c + Vector2(o) * (half.x * absf(o.x) + half.y * absf(o.y) + 0.5)
		var head := Vector2(1, 0) if o.y != 0 else Vector2(0, 1)
		_add(ids[k], p, head, "at a city bus stop")
		if k == 0:
			first = c
		k += 1
	if k < ids.size():
		push_warning("[Vehicles] only %d bus stops" % k)
