class_name ServicePlanner
extends RefCounted
## Places public services like a real city would: one city hall downtown, one
## stadium, and hospitals / schools / fire and police stations spread out with
## a minimum distance between two of the same type (never clustered together).

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind

## kind, lot size (the building + its square / parking), spacing between two of
## the same kind (cells on a 640 map, 0 = unique), allowed zones
const SPECS := [
	{"kind": Kind.CITY_HALL, "size": Vector2i(4, 4), "spacing": 0,
		"zones": [Zone.COMMERCIAL]},
	{"kind": Kind.STADIUM, "size": Vector2i(5, 4), "spacing": 0,
		"zones": [Zone.APARTMENT, Zone.COMMERCIAL, Zone.SUBURBAN]},
	{"kind": Kind.HOSPITAL, "size": Vector2i(4, 4), "spacing": 130,
		"zones": [Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN]},
	{"kind": Kind.FIRE_STATION, "size": Vector2i(2, 2), "spacing": 85,
		"zones": [Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN, Zone.INDUSTRIAL]},
	{"kind": Kind.POLICE, "size": Vector2i(2, 2), "spacing": 95,
		"zones": [Zone.DOWNTOWN, Zone.COMMERCIAL, Zone.APARTMENT, Zone.SUBURBAN]},
	{"kind": Kind.SCHOOL, "size": Vector2i(3, 3), "spacing": 55,
		"zones": [Zone.APARTMENT, Zone.SUBURBAN]},
]
## Any two services keep at least this distance (no "service clusters").
const ANY_SERVICE_GAP := 10.0

var _cfg: CityConfig
var _data: CityData
var _districts: DistrictPlanner
var _lots: LotPlanner
var _placed: Array[Dictionary] = [] # {kind, pos}
var _removed := {}
var counts := {}


func _init(cfg: CityConfig, data: CityData, districts: DistrictPlanner, lots: LotPlanner) -> void:
	_cfg = cfg
	_data = data
	_districts = districts
	_lots = lots


func build(blocks: Array[Rect2i], zones: PackedByteArray) -> void:
	var scale := float(_data.size) / 640.0
	for spec in SPECS:
		var order := _candidate_order(spec, blocks, zones)
		var spacing: float = spec["spacing"] * scale
		for b in order:
			if _try_place(spec, blocks[b], spacing):
				counts[spec["kind"]] = counts.get(spec["kind"], 0) + 1
				if spacing <= 0.0:
					break
	_data.remove_buildings(_removed)


## Block indices ordered by how well they suit the service.
func _candidate_order(spec: Dictionary, blocks: Array[Rect2i], zones: PackedByteArray) -> Array:
	var size: Vector2i = spec["size"]
	var kind: int = spec["kind"]
	var scored := []
	for i in blocks.size():
		var r := blocks[i]
		if not spec["zones"].has(int(zones[i])):
			continue
		if mini(r.size.x, r.size.y) < mini(size.x, size.y) \
				or maxi(r.size.x, r.size.y) < maxi(size.x, size.y):
			continue
		var c := Vector2(r.get_center())
		var score: float
		match kind:
			Kind.CITY_HALL:
				# Civic center at the edge of downtown, not hidden among towers.
				score = -absf(c.distance_to(_districts.main_center) - _data.size * 0.09)
			Kind.STADIUM:
				score = -absf(c.distance_to(_districts.main_center) - _data.size * 0.16)
			Kind.HOSPITAL, Kind.POLICE:
				score = _districts.density(c.x, c.y) + CityTypes.hashf(r.position.x, r.position.y, kind) * 0.3
			_:
				score = CityTypes.hashf(r.position.x, r.position.y, kind)
		scored.append([score, i])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored.map(func(e): return e[1])


func _try_place(spec: Dictionary, block: Rect2i, spacing: float) -> bool:
	var size: Vector2i = spec["size"]
	if block.size.x < size.x or block.size.y < size.y:
		size = Vector2i(size.y, size.x)
	var c := Vector2(block.get_center())
	if not _respects_spacing(spec["kind"], c, spacing):
		return false
	# Try the four corners of the block (each touches roads on two sides).
	var corners := [
		block.position,
		Vector2i(block.end.x - size.x, block.position.y),
		Vector2i(block.position.x, block.end.y - size.y),
		block.end - size,
	]
	for p in corners:
		var r := Rect2i(p, size)
		if not _all_land(r):
			continue
		var facing := LotPlanner.road_facing(_data, r, CityTypes.hash2(p.x, p.y))
		if facing < 0:
			continue
		_claim(r, spec["kind"], facing)
		_placed.append({"kind": spec["kind"], "pos": Vector2(r.get_center())})
		return true
	return false


func _respects_spacing(kind: int, c: Vector2, spacing: float) -> bool:
	for p in _placed:
		var d: float = (p["pos"] as Vector2).distance_to(c)
		if d < ANY_SERVICE_GAP:
			return false
		if p["kind"] == kind and d < spacing:
			return false
	return true


## Replaces the lots under `r` with the service building.
func _claim(r: Rect2i, kind: int, facing: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var old := _lots.owner[_data.idx(x, y)]
			if old >= 0:
				_removed[old] = true
	var id := _data.add_building(r, kind, facing, CityTypes.hash2(r.position.x, r.position.y, kind), 0.5)
	_lots.mark(r, id)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_data.zone[_data.idx(x, y)] = Zone.CIVIC


func _all_land(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.terrain[i] != CityTypes.Terrain.LAND or _data.road[i] != 0:
				return false
	return true
