class_name ShopSites
extends RefCounted
## Decides where the shops of the catalog (res://shops) stand on the island.
## Pure data in, a list of placements out, so it can be checked headless (tests/test_shops.gd).
## Each placement: {"id": catalog id, "at": Vector2 (cells, x/z), "yaw": radians, "why": text}.
## The shop models face -Z; MapShops turns them with `yaw` so the front looks at the street.
##
## It runs after the generation and the hand edits, so it never moves a building: it only
## looks for free cells (land, no road, no building, nothing placed before) in the zones
## each shop is meant for, next to a straight street.

const Kind := CityTypes.Kind

## Cells per metre, like the vehicles (a 6 m wide shop is one cell).
const CELLS_PER_METRE := 0.17
## Minimum distance between two copies of the same shop, and between any two shops (cells).
const SAME_GAP := 9.0
const ANY_GAP := 1.5

## Where a shop goes when its own zones have no free spot left: any built-up zone.
const FALLBACK_ZONES: Array[int] = [
	CityTypes.Zone.DOWNTOWN, CityTypes.Zone.COMMERCIAL, CityTypes.Zone.APARTMENT,
	CityTypes.Zone.SUBURBAN, CityTypes.Zone.QUARTER, CityTypes.Zone.ENTERTAINMENT,
	CityTypes.Zone.POOR, CityTypes.Zone.URBAN,
]

var out: Array[Dictionary] = []

var _d: CityData
## 1 where a building or an earlier shop is.
var _taken := PackedByteArray()
## Possible spots: {"c": Vector2i, "head": Vector2 (towards the street), "zone": int}.
var _spots: Array[Dictionary] = []


func _init(data: CityData) -> void:
	_d = data


## `shops`: [{"id", "width", "depth" (metres), "zones": Array of CityTypes.Zone, "copies"}].
static func plan(data: CityData, shops: Array) -> Array[Dictionary]:
	var s := ShopSites.new(data)
	s._run(shops)
	return s.out


func _run(shops: Array) -> void:
	_taken.resize(_d.size * _d.size)
	for b in _d.building_count():
		if _d.b_kind[b] == Kind.EMPTY:
			continue
		var r := _d.building_rect(b)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _d.in_bounds(x, y):
					_taken[_d.idx(x, y)] = 1
	var wanted := {}
	for z in FALLBACK_ZONES:
		wanted[z] = true
	for sh in shops:
		for z in sh["zones"]:
			wanted[z] = true
	_find_spots(wanted)
	# Most constrained first (fewest zones), then by id: stable result.
	var order := shops.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["zones"].size() != b["zones"].size():
			return a["zones"].size() < b["zones"].size()
		return String(a["id"]) < String(b["id"]))
	# Round robin over the copies, so every shop gets a place before any gets a second one.
	var most := 0
	for sh in order:
		most = maxi(most, int(sh["copies"]))
	for copy in most:
		for sh in order:
			if copy < int(sh["copies"]):
				if not _place(sh, copy):
					push_warning("[Shops] no room for %s (copy %d)" % [sh["id"], copy + 1])


## Free land cells next to a straight street (no junction, no bridge), in a wanted zone.
func _find_spots(wanted: Dictionary) -> void:
	var dirs: Array[Vector2i] = CityTypes.FACING_OFFSETS
	for y in range(1, _d.size - 1):
		for x in range(1, _d.size - 1):
			if not wanted.has(_d.zone_at(x, y)) or not _free(x, y):
				continue
			for o in dirs:
				var rx := x + o.x
				var ry := y + o.y
				if not _straight_street(rx, ry):
					continue
				_spots.append({"c": Vector2i(x, y), "head": Vector2(o), "zone": _d.zone_at(x, y)})
	_spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = a["c"]
		var cb: Vector2i = b["c"]
		return CityTypes.hash2(ca.x, ca.y, 77) < CityTypes.hash2(cb.x, cb.y, 77))


func _straight_street(x: int, y: int) -> bool:
	if not _d.in_bounds(x, y) or _d.road[_d.idx(x, y)] == 0:
		return false
	if (_d.road[_d.idx(x, y)] & CityTypes.ROAD_BRIDGE_FLAG) != 0:
		return false
	var m := _d.road_mask(x, y)
	return m == (CityTypes.DIR_E | CityTypes.DIR_W) or m == (CityTypes.DIR_N | CityTypes.DIR_S)


func _free(x: int, y: int) -> bool:
	return _d.is_land(x, y) and _d.road[_d.idx(x, y)] == 0 and _taken[_d.idx(x, y)] == 0


func _place(shop: Dictionary, copy: int) -> bool:
	# Own zones first, then any built-up zone.
	return _place_in(shop, shop["zones"], "") or _place_in(shop, FALLBACK_ZONES, " (fallback)")


func _place_in(shop: Dictionary, zones: Array, tag: String) -> bool:
	var w := float(shop["width"]) * CELLS_PER_METRE
	var dep := float(shop["depth"]) * CELLS_PER_METRE
	for sp in _spots:
		if not zones.has(sp["zone"]):
			continue
		var c: Vector2i = sp["c"]
		var head: Vector2 = sp["head"]
		# Front edge on the edge of the cell that touches the street.
		var at := Vector2(c) + Vector2(0.5, 0.5) + head * (0.5 - dep * 0.5)
		if not _fits(at, head, w, dep):
			continue
		if _too_close(shop["id"], at):
			continue
		_add(shop["id"], at, head, w, dep, "%s zone%s" % [CityTypes.Zone.keys()[sp["zone"]], tag])
		return true
	return false


## True when the footprint (`w` across, `dep` along `head`) lies only on free ground.
func _fits(at: Vector2, head: Vector2, w: float, dep: float) -> bool:
	var ext := Vector2(absf(head.y) * w, absf(head.x) * w) * 0.5 + Vector2(absf(head.x) * dep, absf(head.y) * dep) * 0.5
	var x0 := int(floor(at.x - ext.x + 0.001))
	var x1 := int(floor(at.x + ext.x - 0.001))
	var y0 := int(floor(at.y - ext.y + 0.001))
	var y1 := int(floor(at.y + ext.y - 0.001))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not _free(x, y):
				return false
	return true


func _too_close(id: String, at: Vector2) -> bool:
	for p in out:
		var dist := (p["at"] as Vector2).distance_to(at)
		if dist < ANY_GAP or (p["id"] == id and dist < SAME_GAP):
			return true
	return false


func _add(id: String, at: Vector2, head: Vector2, w: float, dep: float, why: String) -> void:
	out.append({"id": id, "at": at, "yaw": atan2(-head.x, -head.y), "why": why})
	var ext := Vector2(absf(head.y) * w, absf(head.x) * w) * 0.5 + Vector2(absf(head.x) * dep, absf(head.y) * dep) * 0.5
	for y in range(int(floor(at.y - ext.y + 0.001)), int(floor(at.y + ext.y - 0.001)) + 1):
		for x in range(int(floor(at.x - ext.x + 0.001)), int(floor(at.x + ext.x - 0.001)) + 1):
			if _d.in_bounds(x, y):
				_taken[_d.idx(x, y)] = 1
