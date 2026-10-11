class_name GardenFences
extends RefCounted
## Wooden fences round the gardens of the suburbs: every house, small block and garden lot of
## the SUBURBAN and CIVIC zones gets a fence along the border of its lot, with a gate in the middle of
## its front side. Lots side by side share one fence. Written into CityData.fence_edge
## (GroundPlacer draws it); nothing else of the map changes.

const Kind := CityTypes.Kind

## Kinds whose lot is fenced (a house with its garden, or the garden alone).
const FENCED: Array[int] = [Kind.HOUSE, Kind.APARTMENT, Kind.GARDEN]
## Every house is fenced; small blocks and gardens only in these zones (suburbs, civic land).
const ZONES: Array[int] = [CityTypes.Zone.SUBURBAN, CityTypes.Zone.CIVIC]
## Values of CityData.fence_edge.
const NORTH := 1
const WEST := 2


## Returns how many lots got a fence.
static func apply(data: CityData) -> int:
	data.fence_edge.fill(0)
	var lots := 0
	for b in data.building_count():
		if not FENCED.has(data.b_kind[b]):
			continue
		var r := data.building_rect(b)
		var c := r.get_center()
		if data.b_kind[b] != Kind.HOUSE and not ZONES.has(data.zone_at(c.x, c.y)):
			continue
		_fence_lot(data, r, data.b_facing[b])
		lots += 1
	return lots


static func _fence_lot(data: CityData, r: Rect2i, facing: int) -> void:
	# The gate: the middle cell of the side the building faces.
	var gate := Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)
	match facing:
		0: gate.y = r.position.y
		1: gate.x = r.end.x - 1
		2: gate.y = r.end.y - 1
		3: gate.x = r.position.x
	for x in range(r.position.x, r.end.x):
		if not (facing == 0 and x == gate.x):
			_mark(data, Vector2i(x, r.position.y), NORTH)
		if not (facing == 2 and x == gate.x):
			_mark(data, Vector2i(x, r.end.y), NORTH)
	for y in range(r.position.y, r.end.y):
		if not (facing == 3 and y == gate.y):
			_mark(data, Vector2i(r.position.x, y), WEST)
		if not (facing == 1 and y == gate.y):
			_mark(data, Vector2i(r.end.x, y), WEST)


static func _mark(data: CityData, c: Vector2i, side: int) -> void:
	if data.in_bounds(c.x, c.y):
		var i := data.idx(c.x, c.y)
		data.fence_edge[i] = data.fence_edge[i] | side
