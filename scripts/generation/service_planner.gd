class_name ServicePlanner
extends RefCounted
## Places the public buildings of Chat City: each one once (casinos twice), in
## the block closest to its district anchor, and never two services in the same
## spot. Also offers `claim` to the landmark planner.

const Zone := CityTypes.Zone
const Kind := CityTypes.Kind

## kind, lot size (building + its square / parking), how many, district anchor
## it should be close to, zones it may replace lots in.
const SPECS := [
	{"kind": Kind.CITY_HALL, "size": Vector2i(4, 4), "count": 1, "near": "civic",
		"zones": [Zone.COMMERCIAL]},
	{"kind": Kind.BANK, "size": Vector2i(2, 2), "count": 1, "near": "civic",
		"zones": [Zone.COMMERCIAL]},
	{"kind": Kind.POLICE, "size": Vector2i(2, 2), "count": 1, "near": "civic",
		"zones": [Zone.COMMERCIAL, Zone.SUBURBAN]},
	{"kind": Kind.FIRE_STATION, "size": Vector2i(2, 2), "count": 1, "near": "civic",
		"zones": [Zone.COMMERCIAL, Zone.SUBURBAN]},
	{"kind": Kind.HOSPITAL, "size": Vector2i(4, 4), "count": 1, "near": "shops",
		"zones": [Zone.COMMERCIAL, Zone.APARTMENT]},
	{"kind": Kind.SCHOOL, "size": Vector2i(3, 3), "count": 1, "near": "suburb_ne",
		"zones": [Zone.SUBURBAN]},
	{"kind": Kind.CHURCH, "size": Vector2i(2, 3), "count": 1, "near": "suburb_ne",
		"zones": [Zone.SUBURBAN]},
	{"kind": Kind.STADIUM, "size": Vector2i(5, 4), "count": 1, "near": "sports",
		"zones": [Zone.APARTMENT, Zone.COMMERCIAL, Zone.SUBURBAN]},
	{"kind": Kind.DRIVE_IN, "size": Vector2i(4, 3), "count": 1, "near": "sports",
		"zones": [Zone.APARTMENT, Zone.COMMERCIAL, Zone.SUBURBAN, Zone.ENTERTAINMENT]},
	{"kind": Kind.CASINO, "size": Vector2i(3, 3), "count": 2, "near": "vegas",
		"zones": [Zone.ENTERTAINMENT]},
	{"kind": Kind.FERRIS_WHEEL, "size": Vector2i(2, 2), "count": 1, "near": "vegas",
		"zones": [Zone.ENTERTAINMENT]},
]
## Any two services keep at least this distance (no "service clusters").
const ANY_SERVICE_GAP := 5.0
## Two buildings of the same kind keep at least this distance.
const SAME_KIND_GAP := 10.0

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
	for spec in SPECS:
		var placed := 0
		for b in _candidate_order(spec, blocks, zones):
			if placed >= int(spec["count"]):
				break
			if _try_place(spec, blocks[b]):
				placed += 1
		counts[spec["kind"]] = placed


## Removes the lots replaced by services; call once everything is placed.
func finish() -> void:
	_data.remove_buildings(_removed)


## Blocks able to hold the service, closest to its district anchor first.
func _candidate_order(spec: Dictionary, blocks: Array[Rect2i], zones: PackedByteArray) -> Array:
	var size: Vector2i = spec["size"]
	var anchor: Vector2 = _districts.anchors[spec["near"]]
	var scored := []
	for i in blocks.size():
		var r := blocks[i]
		if not spec["zones"].has(int(zones[i])):
			continue
		if mini(r.size.x, r.size.y) < mini(size.x, size.y) \
				or maxi(r.size.x, r.size.y) < maxi(size.x, size.y):
			continue
		scored.append([Vector2(r.get_center()).distance_to(anchor), i])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	return scored.map(func(e): return e[1])


func _try_place(spec: Dictionary, block: Rect2i) -> bool:
	var size: Vector2i = spec["size"]
	if block.size.x < size.x or block.size.y < size.y:
		size = Vector2i(size.y, size.x)
	if not _respects_spacing(spec["kind"], Vector2(block.get_center())):
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
		if not is_free_land(r):
			continue
		var facing := LotPlanner.road_facing(_data, r, CityTypes.hash2(p.x, p.y))
		if facing < 0:
			continue
		claim(r, spec["kind"], facing, Zone.CIVIC)
		return true
	return false


func _respects_spacing(kind: int, c: Vector2) -> bool:
	for p in _placed:
		var d: float = (p["pos"] as Vector2).distance_to(c)
		if d < ANY_SERVICE_GAP or (p["kind"] == kind and d < SAME_KIND_GAP):
			return false
	return true


## Replaces the lots under `r` with the building. `zone` repaints its ground
## (-1 keeps the current zone).
func claim(r: Rect2i, kind: int, facing: int, zone: int = -1) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var old := _lots.owner[_data.idx(x, y)]
			if old >= 0:
				_removed[old] = true
	var id := _data.add_building(r, kind, facing, CityTypes.hash2(r.position.x, r.position.y, kind), 0.5)
	_lots.mark(r, id)
	_placed.append({"kind": kind, "pos": Vector2(r.get_center())})
	if zone < 0:
		return
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_data.zone[_data.idx(x, y)] = zone


## True when every cell of `r` is dry land without road.
func is_free_land(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _data.in_bounds(x, y):
				return false
			var i := _data.idx(x, y)
			if _data.terrain[i] != CityTypes.Terrain.LAND or _data.road[i] != 0:
				return false
	return true
