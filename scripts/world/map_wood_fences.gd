class_name MapWoodFences
extends Node3D
## The fences made of whole models (res://fences/models), one MultiMesh per model:
##   - the suburban kit fence (Kenney): round the house and garden lots and the central park, with a gap in front
##     of the door;
##   - fence_wood: the sides of the crop fields that face a road (the farm land);
##   - road_separation_fence: along both edges of the highways of the continent.
## Each model is stretched so that one piece is PIECE cells long; its long side (x or z of
## the model) runs along the line.

const Kind := CityTypes.Kind

const WOODEN := "res://FREEMODELS/kenney_city-kit-suburban_20/Models/GLB format/fence.glb"
const FARM := "res://fences/models/fence_wood.glb"
const HIGHWAY := "res://fences/models/road_separation_fence.glb"

## Length of one piece (cells) of each model, and the factor on the height of the wooden one.
const WOODEN_PIECE := 0.8
const WOODEN_HEIGHT := 0.7
const FARM_PIECE := 1.0
const HIGHWAY_PIECE := 1.5
## Gap left in the fence in front of a house (cells).
const GATE := 1.2
## The candy shops: id, absolute scale of the ones of the city, and the room left round a shop.
const SHOP_ID := "shop-general-orange-b-unlit"
const DEV_SHOP_ID := "shop-candy-b"
const SHOP_SCALE := 0.34
const SPOT_PAD := 0.45
## The highway fences stand this far outside the edge of the road, and keep this far from a
## crossing highway.
const HIGHWAY_MARGIN := 0.1
const CROSSING_CLEAR := 3.0

var _count := 0


func build(data: CityData, lib: ModelLibrary) -> void:
	var wood := _Batch.new(lib, "fence:wooden", WOODEN, WOODEN_PIECE, WOODEN_HEIGHT)
	var farm := _Batch.new(lib, "fence:farm", FARM, FARM_PIECE)
	var road := _Batch.new(lib, "fence:highway", HIGHWAY, HIGHWAY_PIECE)
	for b in data.building_count():
		var kind: int = data.b_kind[b]
		var r := data.building_rect(b)
		if kind == Kind.HOUSE or kind == Kind.GARDEN:
			if r.size.x >= 2 and r.size.y >= 2:
				_lot(data, wood, r, int(data.b_facing[b]) if kind == Kind.HOUSE else -1)
		elif kind == Kind.FIELD:
			_field(data, farm, r)
	_candy_shops(data, wood)
	if data.central_park.size.x > 0:
		_lot(data, wood, data.central_park, -1)
	if data.continent != null:
		_highways(data.continent, road)
	for batch in [wood, farm, road]:
		_count += batch.flush(self)
	print("[WoodFences] %d fence pieces placed" % _count)


## The four sides of `r`; `front` (0 N, 1 E, 2 S, 3 W, or -1) leaves a gate in the middle of that side.
func _lot(data: CityData, batch: _Batch, r: Rect2i, front: int) -> void:
	_ring(data, batch, float(r.position.x), float(r.position.y), float(r.end.x), float(r.end.y), front)


func _ring(data: CityData, batch: _Batch, x0: float, y0: float, x1: float, y1: float, front: int, on_grid: bool = true) -> void:
	var sides := [
		[Vector2(x0, y0), Vector2(x1, y0)],  # north
		[Vector2(x1, y0), Vector2(x1, y1)],  # east
		[Vector2(x0, y1), Vector2(x1, y1)],  # south
		[Vector2(x0, y0), Vector2(x0, y1)],  # west
	]
	for s in 4:
		var a: Vector2 = sides[s][0]
		var b: Vector2 = sides[s][1]
		var gate := GATE if s == front else 0.0
		if on_grid:
			batch.line(a, b, gate, func(mid: Vector2) -> bool: return _dry(data, mid))
		else:
			batch.line(a, b, gate, Callable())


## A well-kept spot round every shop of the city (shop-general-orange-b-unlit): the shops of the city
## and of the quarter (buildings with the model "shop:shop-general-orange-b-unlit"), the candy shops of
## the development island and
## those of the fog island. The fence is a ring a little bigger than the shop, with a gate on its front.
func _candy_shops(data: CityData, batch: _Batch) -> void:
	for b in data.building_count():
		var model := String(data.b_model.get(b, ""))
		if data.b_kind[b] == Kind.EMPTY or not model.begins_with("shop:") or not CityShops.ALL_IDS.has(model.trim_prefix("shop:")):
			continue
		var r := data.building_rect(b)
		# b_facing is turned half way round: the front of the model is -Z (CityShops).
		_spot(data, batch, Vector2(r.get_center()), (int(data.b_facing[b]) + 2) % 4, SHOP_SCALE, true, model.trim_prefix("shop:"))
	var catalog := MapShops.catalog()
	for p in ShopSites.plan(data, catalog):
		if String(p["id"]).begins_with(DEV_SHOP_ID):
			_spot(data, batch, p["at"], 2, float(p["scale"]), true, DEV_SHOP_ID)
	if data.fog != null:
		for p in FogBaseSites.plan(data.fog):
			if CityShops.ALL_IDS.has(String(p.get("shop", ""))):
				var dir: Vector2 = p["dir"]
				var look := (0 if dir.y < -0.5 else 2) if absf(dir.y) > absf(dir.x) else (1 if dir.x > 0.0 else 3)
				_spot(data, batch, data.fog.origin + (p["at"] as Vector2), look, float(p["scale"]), false, String(p["shop"]))


## Ring round a shop standing at `at`, its front towards `look` (0 N, 1 E, 2 S, 3 W), `scale` cells per metre.
func _spot(data: CityData, batch: _Batch, at: Vector2, look: int, scale: float, on_grid: bool = true, shop_id: String = SHOP_ID) -> void:
	var entry := MapShops.entry(shop_id)
	if entry.is_empty():
		return
	var w := float(entry["width"]) * scale
	var d := float(entry["depth"]) * scale
	if look == 1 or look == 3:
		var t := w
		w = d
		d = t
	var hx := w * 0.5 + SPOT_PAD
	var hy := d * 0.5 + SPOT_PAD
	_ring(data, batch, at.x - hx, at.y - hy, at.x + hx, at.y + hy, look, on_grid)


## Only the sides of the field whose neighbour cells are road.
func _field(data: CityData, batch: _Batch, r: Rect2i) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	for x in range(x0, x1):
		_field_edge(data, batch, Vector2(x, y0), Vector2(x + 1, y0), Vector2i(x, y0 - 1))
		_field_edge(data, batch, Vector2(x, y1), Vector2(x + 1, y1), Vector2i(x, y1))
	for y in range(y0, y1):
		_field_edge(data, batch, Vector2(x0, y), Vector2(x0, y + 1), Vector2i(x0 - 1, y))
		_field_edge(data, batch, Vector2(x1, y), Vector2(x1, y + 1), Vector2i(x1, y))


func _field_edge(data: CityData, batch: _Batch, a: Vector2, b: Vector2, outside: Vector2i) -> void:
	if data.in_bounds(outside.x, outside.y) and data.road[data.idx(outside.x, outside.y)] != 0:
		batch.line(a, b, 0.0, Callable())


func _dry(data: CityData, p: Vector2) -> bool:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	return data.in_bounds(x, y) and data.terrain[data.idx(x, y)] == CityTypes.Terrain.LAND \
			and data.road[data.idx(x, y)] == 0


func _highways(c: ContinentShaper, batch: _Batch) -> void:
	var half := ContinentShaper.HIGHWAY_WIDTH * 0.5 + HIGHWAY_MARGIN
	for hi in c.highways.size():
		var h: PackedVector2Array = c.highways[hi]
		var clear := func(mid: Vector2) -> bool:
			for oi in c.highways.size():
				if oi == hi:
					continue
				if _near_line(c.highways[oi], mid, ContinentShaper.HIGHWAY_WIDTH * 0.5 + CROSSING_CLEAR):
					return false
			return true
		for i in h.size() - 1:
			var d := h[i + 1] - h[i]
			if d.length() < 0.05:
				continue
			var n := Vector2(-d.y, d.x).normalized() * half
			batch.line(h[i] + n, h[i + 1] + n, 0.0, clear)
			batch.line(h[i] - n, h[i + 1] - n, 0.0, clear)


static func _near_line(poly: PackedVector2Array, p: Vector2, dist: float) -> bool:
	for i in poly.size() - 1:
		var a := poly[i]
		var ab := poly[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(p) < dist:
			return true
	return false


## Collects the pieces of one model and draws them as one MultiMesh.
class _Batch:
	var _mesh: Mesh
	var _piece: float
	var _scale := 1.0
	var _height := 1.0
	var _long_is_x := false
	var _center := Vector3.ZERO
	var _xforms: Array[Transform3D] = []

	func _init(lib: ModelLibrary, name: String, path: String, piece: float, height: float = 1.0) -> void:
		_piece = piece
		_height = height
		var id := lib.load_named(name, path)
		if id < 0:
			return
		_mesh = lib.meshes[id]
		var box: AABB = lib.bounds[id]
		_long_is_x = box.size.x > box.size.z
		var length := maxf(box.size.x, box.size.z)
		if length <= 0.0001:
			_mesh = null
			return
		_scale = piece / length
		# Centre of the footprint, bottom of the model on the ground.
		_center = Vector3(box.get_center().x, box.position.y, box.get_center().z)

	## Pieces along a -> b, skipping `gate` cells in the middle and every piece whose middle is
	## refused by `allow` (an invalid Callable allows all).
	func line(a: Vector2, b: Vector2, gate: float, allow: Callable) -> void:
		if _mesh == null:
			return
		var d := b - a
		var len := d.length()
		var n := maxi(1, int(round(len / _piece)))
		var step := len / float(n)
		var dir := d / len
		var yaw := atan2(-dir.y, dir.x) if _long_is_x else atan2(dir.x, dir.y)
		var s := _scale * step / _piece
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s, _scale * _height, s))
		for k in n:
			var mid := a + dir * (step * (float(k) + 0.5))
			if gate > 0.0 and mid.distance_to((a + b) * 0.5) < gate * 0.5 + step * 0.5:
				continue
			if allow.is_valid() and not allow.call(mid):
				continue
			_xforms.append(Transform3D(basis, Vector3(mid.x, 0.0, mid.y) - basis * _center))

	func flush(parent: Node3D) -> int:
		if _mesh == null or _xforms.is_empty():
			return 0
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh
		mm.instance_count = _xforms.size()
		for i in _xforms.size():
			mm.set_instance_transform(i, _xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "WoodFence_%d" % parent.get_child_count()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		return _xforms.size()
