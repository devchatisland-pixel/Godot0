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
## The regular cars (street sedans, the off-road SUV, the cinema parking lot) are put on the
## map; false takes them away (their models stay in the catalog).
const REGULAR_CARS := true
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
	_mark_buildings()
	if REGULAR_CARS:
		_street_sedans()
		_forest_suv()
	_farm_machines()
	_farm_extras()
	_industrial_zones()
	_hospital_ambulance()
	_city_hall_cars()
	_police_hq_car()
	_bunker_cars()
	_bunker_helicopter()
	_fire_station_truck()
	_container_tanker()
	_crane_tanker()
	_port_fuel_tanker()
	_desert()
	_ranch_wreck()
	_drive_in_cars()
	_prison_helicopters()
	_plant_road()
	if REGULAR_CARS:
		_cinema_parking()


## Marks the lots of all buildings but `skip` as taken.
func _mark_buildings(skip: int = -1) -> void:
	_taken.resize(_d.size * _d.size)
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.EMPTY or b == skip:
			continue
		var r := _d.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _d.in_bounds(x, y):
					_taken[_d.idx(x, y)] = 1


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
	if not _d.is_land(x, y):
		return false
	var i := _d.idx(x, y)
	return _d.road[i] == 0 and _taken[i] == 0


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


## The farm building the wheel loader is parked in front of (top-left cell of its lot).
const LOADER_RANCH := Vector2i(268, 283)


## The tractor and the harvester together on the biggest crop field, the loader beside the
## farm building nearest to it. Falls back to one machine in each of three fields when
## there is no farm building.
func _farm_machines() -> void:
	var field := _biggest(Kind.FIELD)
	var barn := -1
	if field >= 0:
		var fc := Vector2(_d.building_rect(field).get_center())
		var best := INF
		for b in _d.building_count():
			if _d.b_kind[b] == Kind.OUTPOST:
				var d := Vector2(_d.building_rect(b).get_center()).distance_to(fc)
				if d < best:
					best = d
					barn = b
	if barn < 0 or field < 0:
		_farm_machines_auto()
		return
	var ranch := _nearest_kind(Kind.OUTPOST, LOADER_RANCH)
	if ranch >= 0:
		_in_front("p54_41_loader_claw_yellow", ranch, "in front of the ranch")
	var fr := _d.building_rect(field)
	var c := Vector2(fr.position) + Vector2(fr.size) * 0.5
	_add("p54_43_tractor_vintage_trailer", c + Vector2(-1.0, -0.9), Vector2(-1, 0), "in an agricultural field")
	_add("p54_21_harvester_olive", c + Vector2(0.9, 1.0), Vector2(1, 0), "in an agricultural field")


## One machine in each of three different crop fields (the biggest ones, far apart).
func _farm_machines_auto() -> void:
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


## More machines in the farmland: a harvester in the middle of a wheat field (the yellow
## ones) that has no machine yet, and a red pickup, a forwarder and a tractor with its trailer
## in three other fields, far from each other.
func _farm_extras() -> void:
	var fields: Array[int] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.FIELD and _d.zone_at(_d.building_rect(b).position.x, _d.building_rect(b).position.y) == Zone.FARM:
			fields.append(b)
	fields.sort_custom(func(a: int, b: int) -> bool:
		var pa := _d.building_rect(a).position
		var pb := _d.building_rect(b).position
		return CityTypes.hash2(pa.x, pa.y, 53) < CityTypes.hash2(pb.x, pb.y, 53))
	var ids := ["p54_21_harvester_olive", "p54_26_pickup_40s_red", "p54_42_forwarder_green",
			"p54_43_tractor_vintage_trailer"]
	var k := 0
	for b in fields:
		if k >= ids.size():
			break
		var r := _d.building_rect(b)
		var c := Vector2(r.position) + Vector2(r.size) * 0.5
		# The harvester works a wheat field; BuildingPlacer draws wheat on variant 0.
		if (k == 0) != (absi(_d.b_seed[b] >> 2) % 4 == 0) or _near_placed(c, 9.0):
			continue
		_add(ids[k], c, Vector2(1, 0) if r.size.x >= r.size.y else Vector2(0, 1),
				"in a wheat field" if k == 0 else "in an agricultural field")
		k += 1
	if k < ids.size():
		push_warning("[Vehicles] only %d of the farm machines found a field" % k)


## The construction crane of the red district (top-left cell of its lot).
const QUARTER_CRANE := Vector2i(188, 236)


## A water tanker next to the construction crane: on free ground beside it, else parked on
## the nearest straight street cell.
func _crane_tanker() -> void:
	var crane := _nearest_kind(Kind.CRANE, QUARTER_CRANE)
	if crane < 0:
		return
	var id := "p54_10_tanker_water"
	var why := "next to the construction crane"
	var r := _d.building_rect(crane)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(r.position.y - 3, r.end.y + 3):
		for x in range(r.position.x - 3, r.end.x + 3):
			if not _d.in_bounds(x, y) or _d.road[_d.idx(x, y)] == 0:
				continue
			var m := _d.road_mask(x, y)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r.get_center()) + Vector2(0.5, 0.5))
			if (m == (CityTypes.DIR_E | CityTypes.DIR_W) or m == (CityTypes.DIR_N | CityTypes.DIR_S)) and d < best_d:
				best_d = d
				best = Vector2i(x, y)
	if best.x >= 0:
		_add_on_road(id, best, why)
	elif not _beside(id, r, why, 59, 0.4, 7.0):
		push_warning("[Vehicles] no room next to the construction crane")


## A fuel tanker next to the oil barrels of the port: the barrel yard (INDUSTRIAL_YARD whose
## seed draws barrels, see BuildingExtras) nearest to the quay of the cargo ship.
func _port_fuel_tanker() -> void:
	# The silos MapAdditions put beside the container yards come first.
	var silos := Rect2i()
	for b in _d.building_count():
		if _d.b_model.get(b, "") == MapAdditions.SILO_MODEL:
			silos = _d.building_rect(b) if silos.size.x == 0 else silos.merge(_d.building_rect(b))
	if silos.size.x > 0 and _beside("p54_18_tanker_fuel", silos, "next to the oil silos of the port", 67, 0.4, 3.0):
		return
	var quay := Vector2(MapLayout.point("cargo_ship"))
	var yards: Array[Rect2i] = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.INDUSTRIAL_YARD and _d.b_seed[b] % 3 == 1:
			yards.append(_d.building_rect(b))
	yards.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return Vector2(a.get_center()).distance_to(quay) < Vector2(b.get_center()).distance_to(quay))
	for r in yards:
		if _beside("p54_18_tanker_fuel", r, "next to the oil barrels of the port", 67, 0.4, 2.5):
			return
	push_warning("[Vehicles] no room next to the oil barrels of the port")


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

## In front of every hospital (main hospitals and clinics): on the side its front looks at.
func _hospital_ambulance() -> void:
	var n := 0
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.MAIN_HOSPITAL or _d.b_kind[b] == Kind.HOSPITAL:
			_in_front("p54_11_ambulance", b, "in front of a hospital")
			n += 1
	if n == 0:
		push_warning("[Vehicles] no hospital")


## A US police cruiser in front of the city hall.
func _city_hall_cars() -> void:
	var b := _biggest(Kind.CITY_HALL)
	if b < 0:
		push_warning("[Vehicles] no city hall")
		return
	var ids := ["police_us_cruiser"]
	var r := _d.building_rect(b)
	var o := CityTypes.FACING_OFFSETS[_d.b_facing[b]]
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	var half := Vector2(r.size) * 0.5
	var front := c + Vector2(o) * (half.x * absf(o.x) + half.y * absf(o.y) + 0.55)
	var head := Vector2(1, 0) if o.y != 0 else Vector2(0, 1)
	for k in ids.size():
		var p := front + head * (float(k) - float(ids.size() - 1) * 0.5) * 1.15
		_add(ids[k], p, head, "in front of the city hall")


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
	if best < 0:
		push_warning("[Vehicles] no fire station")
		return
	_in_front("p54_33_fire_truck", best, "in front of the biggest fire station")
	# The main fire station: its fire truck in the front yard (ManualEdits clears the trees).
	var main := _nearest_kind(Kind.FIRE_STATION, ManualEdits.MAIN_FIRE_STATION)
	if main >= 0 and main != best:
		_in_front("p54_33_fire_truck", main, "in front of the main fire station")


## Building of `kind` whose lot starts nearest to `cell` (-1 when there is none).
func _nearest_kind(kind: int, cell: Vector2i) -> int:
	var best := -1
	var best_d := INF
	for b in _d.building_count():
		if _d.b_kind[b] != kind:
			continue
		var d := Vector2(_d.building_rect(b).position).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = b
	return best


## A US police cruiser in front of the main police station.
func _police_hq_car() -> void:
	var b := _biggest(Kind.POLICE_HQ)
	if b >= 0:
		# On the paved front yard (ManualEdits.finish), a little further out than the others.
		_in_front("police_us_cruiser", b, "in front of the main police station", POLICE_HQ_GAP)
	else:
		push_warning("[Vehicles] no main police station")


## Two Japanese police cars side by side in front of the bunker of the secret base.
func _bunker_cars() -> void:
	var b := _biggest(Kind.BUNKER)
	if b < 0:
		return
	var r := _d.building_rect(b)
	var o := CityTypes.FACING_OFFSETS[_d.b_facing[b]]
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	var half := Vector2(r.size) * 0.5
	var front := c + Vector2(o) * (half.x * absf(o.x) + half.y * absf(o.y) + 0.6)
	var side := Vector2(1, 0) if o.y != 0 else Vector2(0, 1)
	for k in 2:
		# Noses towards the bunker.
		_add("police_jp_black", front + side * (float(k) - 0.5) * 0.7, -Vector2(o), "in front of the bunker")


## Size of the helipad of the secret base (cells across).
const BUNKER_PAD := 3.4


## A helicopter parked on a helipad near the bunker of the secret base ("pad": MapVehicles
## draws the helipad under it).
func _bunker_helicopter() -> void:
	var b := _biggest(Kind.BUNKER)
	if b < 0:
		return
	var n := out.size()
	if _beside("p54_46_helicopter_military", _d.building_rect(b), "on the helipad of the secret base", 101, 2.2, 7.0):
		out[n]["pad"] = BUNKER_PAD
	else:
		push_warning("[Vehicles] no room for the helipad of the bunker")


## Distance (cells) from the front of a lot to the middle of a car parked in front of it.
const FRONT_GAP := 0.35
const POLICE_HQ_GAP := 0.45


## Parked on the front side of building `b`, along the road that runs there.
func _in_front(id: String, b: int, why: String, gap: float = FRONT_GAP) -> void:
	var r := _d.building_rect(b)
	var o := CityTypes.FACING_OFFSETS[_d.b_facing[b]]
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	var half := Vector2(r.size) * 0.5
	var p := c + Vector2(o) * (half.x * absf(o.x) + half.y * absf(o.y) + gap)
	# The road in front of a building runs across the way it looks.
	var head := Vector2(1, 0) if o.y != 0 else Vector2(0, 1)
	if CityTypes.hash2(r.position.x, r.position.y, 6) & 1 == 1:
		head = -head
	_add(id, p, head, why)


# --- Desert, buses -----------------------------------------------------------------------------

## A rusted chassis wreck beside the farm building at RANCH_WRECK.
const RANCH_WRECK := Vector2i(298, 238)


func _ranch_wreck() -> void:
	var b := _nearest_kind(Kind.OUTPOST, RANCH_WRECK)
	if b >= 0:
		_beside("p54_12_wreck_chassis", _d.building_rect(b), "beside the farm building", 131, 0.4, 3.0)


## The drive-in cinema: real cars (the lightest of the catalog) in two rows on its lot, their
## noses towards the screen at the back (the drive-in model is the screen and its lot).
const DRIVE_IN_CARS: Array[String] = ["p54_24_sedan_hardtop_teal", "p54_03_sedan_classic_maroon",
		"p54_04_sedan_modern_silver", "p54_01_suv_offroad_navy", "p54_02_van_conversion_white"]
## Rows (share of the lot depth from its back edge) and cars per row.
const DRIVE_IN_ROWS: Array[float] = [0.36, 0.6]
const DRIVE_IN_PER_ROW := 6


func _drive_in_cars() -> void:
	for b in _d.building_count():
		if _d.b_kind[b] != Kind.DRIVE_IN:
			continue
		var r := _d.building_rect(b)
		var o := Vector2(CityTypes.FACING_OFFSETS[_d.b_facing[b]])
		var side := Vector2(-o.y, o.x)
		var depth := float(r.size.y if o.y != 0 else r.size.x)
		var width := float(r.size.x if o.y != 0 else r.size.y)
		var back := Vector2(r.position) + Vector2(r.size) * 0.5 - o * depth * 0.5
		var k := 0
		for row in DRIVE_IN_ROWS.size():
			for i in DRIVE_IN_PER_ROW:
				k += 1
				var h := CityTypes.hash2(b, k, 451)
				if h % 6 == 0:
					continue   # an empty spot
				var u := (float(i) + 0.5) / float(DRIVE_IN_PER_ROW) - 0.5
				var p := back + o * depth * DRIVE_IN_ROWS[row] + side * u * width * 0.86
				out.append({"id": DRIVE_IN_CARS[(h >> 3) % DRIVE_IN_CARS.size()], "at": p,
						"yaw": atan2(o.x, o.y), "why": "at the drive-in cinema"})


## Cells of the desert, the clearest first (no road, building or water around them), every
## third cell; the lot of building `skip` counts as free. ManualEdits.swap_base reads them.
static func desert_spots(data: CityData, skip: int = -1) -> Array[Vector2i]:
	var s := VehicleSites.new(data)
	s._mark_buildings(skip)
	var out: Array[Vector2i] = []
	for e in s._desert_scored():
		out.append(e["c"])
	return out


func _desert_scored() -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for y in range(4, _d.size - 4, 3):
		for x in range(4, _d.size - 4, 3):
			if _d.zone[_d.idx(x, y)] == Zone.DESERT and _d.is_land(x, y) and _free(x, y):
				scored.append({"c": Vector2i(x, y), "r": _clear_radius(Vector2i(x, y), 14)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["r"] != b["r"]:
			return a["r"] > b["r"]
		return CityTypes.hash2(a["c"].x, a["c"].y, 71) < CityTypes.hash2(b["c"].x, b["c"].y, 71))
	return scored


## A motorhome in the middle of nowhere (where the secret base stood, when it moved: see
## ManualEdits.swap_base) and a wreck elsewhere in the desert.
func _desert() -> void:
	var scored := _desert_scored()
	if scored.is_empty():
		push_warning("[Vehicles] no desert")
		return
	var rv := _rv_spot(scored)
	_add("p54_31_rv_class_a_beige", Vector2(rv) + Vector2(0.5, 0.5), Vector2(1, 0), "middle of the south of the desert")
	for s in scored:
		var c: Vector2i = s["c"]
		if s["r"] >= 3 and Vector2(c).distance_to(Vector2(rv)) > 18.0 and _free(c.x, c.y):
			_add("p54_12_wreck_chassis", Vector2(c) + Vector2(0.5, 0.5), Vector2(0, 1), "in the desert")
			return
	push_warning("[Vehicles] no spot for the wreck")


## The motorhome: in the south half of the desert, as far from roads and buildings as it gets
## (the clear radius), away from the secret base and the flying saucer, and near the middle of
## that half. `scored`: desert cells, clearest first (_desert_scored).
const RV_AWAY_BASE := 30.0
const RV_AWAY_UFO := 20.0


func _rv_spot(scored: Array[Dictionary]) -> Vector2i:
	var sum := Vector2.ZERO
	var n := 0
	for y in _d.size:
		for x in _d.size:
			if _d.zone[_d.idx(x, y)] == Zone.DESERT and _d.is_land(x, y):
				sum += Vector2(x, y)
				n += 1
	var middle := sum / float(maxi(n, 1))
	var south := Vector2.ZERO
	var ns := 0
	for e in scored:
		if float(e["c"].y) >= middle.y:
			south += Vector2(e["c"])
			ns += 1
	if ns > 0:
		middle = south / float(ns)
	var avoid: Array = []
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.AIRBASE:
			avoid.append([Vector2(_d.building_rect(b).get_center()), RV_AWAY_BASE])
		elif _d.b_kind[b] == Kind.UFO:
			avoid.append([Vector2(_d.building_rect(b).get_center()), RV_AWAY_UFO])
	var best: Vector2i = scored[0]["c"]
	var best_key := -INF
	for e in scored:
		var c := Vector2(e["c"])
		if c.y < middle.y - 6.0:
			continue
		var ok := true
		for a in avoid:
			if c.distance_to(a[0]) < a[1]:
				ok = false
		if not ok:
			continue
		var key := float(e["r"]) * 10.0 - c.distance_to(middle)
		if key > best_key:
			best_key = key
			best = e["c"]
	return best


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


# --- Prison island, cinema -----------------------------------------------------------------------

## The street in front of the southern nuclear plant of the urban island: a police car and a
## fire truck parked on it (UrbanIslandRebuild lays the street and the yard beside it).
func _plant_road() -> void:
	var plant := Rect2i()
	for b in _d.building_count():
		var r := _d.building_rect(b)
		if _d.b_kind[b] == Kind.NUCLEAR_PLANT and MapLayout.on_urban_island(r.get_center()) 				and (plant.size.x == 0 or r.position.y > plant.position.y):
			plant = r
	if plant.size.x == 0:
		return
	var spots: Array[Vector2i] = []
	for x in range(plant.position.x + 3, plant.end.x - 2):
		var m := _d.road_mask(x, plant.end.y)
		if _d.is_road(x, plant.end.y) and m == (CityTypes.DIR_E | CityTypes.DIR_W):
			spots.append(Vector2i(x, plant.end.y))
	if spots.size() < 2:
		push_warning("[Vehicles] no straight road in front of the plant")
		return
	_add_on_road("police_us_cruiser", spots[1], "on the road of the power plant")
	_add_on_road("p54_33_fire_truck", spots[spots.size() - 2], "on the road of the power plant")


## Prison island: a military helicopter hovering over the sea between the main island and
## the prison island, and an armoured car (Rosomak) beside the lighthouse of the island. The
## helicopter that stood there is now on the helipad of the fog island (FogBaseSites).
const HELI_LIFT := 3.0
## The lighthouse of the prison island (top-left cell of its lot).
const PRISON_LIGHTHOUSE := Vector2i(29, 46)


func _prison_helicopters() -> void:
	var b := _biggest(Kind.PRISON)
	if b < 0:
		push_warning("[Vehicles] no prison island")
		return
	var id := "p54_46_helicopter_military"
	var prison := Vector2(_d.building_rect(b).get_center())
	# In the air: halfway across the water from the prison island towards the city.
	var air := _over_strait(prison, Vector2(_d.size, _d.size) * 0.5)
	if air.x >= 0:
		out.append({"id": id, "at": air, "yaw": atan2(-1.0, 0.0), "why": "over the sea, off the prison island",
				"lift": HELI_LIFT})
	# On the ground beside the lighthouse of the prison island.
	var light := _nearest_kind(Kind.LIGHTHOUSE, PRISON_LIGHTHOUSE)
	if light < 0:
		push_warning("[Vehicles] no lighthouse on the prison island")
		return
	_beside("rosomak_apc", _d.building_rect(light), "next to the lighthouse of the prison island", 97, 0.6, 4.0)


## Middle of the water met going from `from` towards `to` (first sea after the land of
## `from`, up to the next land), or (-1, -1).
func _over_strait(from: Vector2, to: Vector2) -> Vector2:
	var dir := (to - from).normalized()
	var p := from
	var sea_start := Vector2(-1, -1)
	for i in int(from.distance_to(to) * 2.0):
		p += dir * 0.5
		var c := Vector2i(p.floor())
		if not _d.in_bounds(c.x, c.y):
			break
		var land := _d.is_land(c.x, c.y)
		if not land and sea_start.x < 0:
			sea_start = p
		elif land and sea_start.x >= 0:
			return (sea_start + p) * 0.5
	return Vector2(-1, -1)


const PARKING_CARS: Array[String] = [
	"m8_sedan_black", "m8_sedan_dark_red", "m8_sedan_mustard", "m8_wagon_mustard", "m8_wagon_blue",
	"m8_wagon_teal", "m8_wagon_sloped_red", "m8_wagon_sloped_black", "m8_wagon_sloped_burgundy",
	"m8_pickup_blue", "m8_pickup_mustard", "m8_pickup_olive", "m8_long_sedan_silver",
	"p54_03_sedan_classic_maroon", "p54_04_sedan_modern_silver", "p54_05_sedan_90s_teal",
	"p54_24_sedan_hardtop_teal", "p54_02_van_conversion_white",
]


## Parking lot: cars of random models on the free ground within 6 cells of the main cinema,
## their noses towards the building.
func _cinema_parking() -> void:
	var b := _biggest(Kind.CINEMA_MAIN)
	if b < 0:
		push_warning("[Vehicles] no main cinema")
		return
	var r := _d.building_rect(b)
	var n := 0
	for y in range(r.position.y - 6, r.end.y + 6):
		for x in range(r.position.x - 6, r.end.x + 6):
			var dx := maxi(maxi(r.position.x - x, x - (r.end.x - 1)), 0)
			var dy := maxi(maxi(r.position.y - y, y - (r.end.y - 1)), 0)
			if maxi(dx, dy) < 1 or maxi(dx, dy) > 6 or not _free(x, y):
				continue
			var h := CityTypes.hash2(x, y, 313)
			if h % 100 >= 78:
				continue
			# Nose towards the cinema along the axis it is furthest on.
			var head := Vector2(0, 1 if y < r.position.y else -1) if dy >= dx else Vector2(1 if x < r.position.x else -1, 0)
			if dx == dy and dx > 0 and (h >> 8) & 1 == 1:
				head = Vector2(1 if x < r.position.x else -1, 0)
			var id: String = PARKING_CARS[(h >> 12) % PARKING_CARS.size()]
			out.append({"id": id, "at": Vector2(x, y) + Vector2(0.5, 0.5),
					"yaw": atan2(-head.x, -head.y), "why": "parking lot of the cinema"})
			_taken[_d.idx(x, y)] = 1
			n += 1
	if n == 0:
		push_warning("[Vehicles] no room for the cinema parking")
