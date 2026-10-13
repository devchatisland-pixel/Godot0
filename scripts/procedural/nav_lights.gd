class_name NavLights
extends RefCounted
## Navigation lights of the ships and aircraft, as on real ones: red on the left (port) side,
## green on the right (starboard) side. Tiny glowing neon boxes like the light of the church
## cross (no light is added). They sit on the model's own widest points: the wingtips of an
## aircraft, the sides of the hull in the bow half of a ship.
## Each model's front was read from its shape (tools: hull profile along the long axis):
## the pointed end or the bow half of a ship (superstructure of the tanker aft, gantry of the
## trawler aft, missile deck of the submarine before its sail, island of the carrier on the
## right), the nose of an aircraft.

const Cat := ModelCatalog.Cat
const RED := Color("ff2a3a")
const GREEN := Color("2aff7a")
## Front of each model in its own space: +Z is Vector3.BACK, -Z is Vector3.FORWARD.
const FRONT := {
	Cat.BOAT_SIMPLE: Vector3.BACK, Cat.BOAT_WOODEN: Vector3.BACK, Cat.BOAT_FISHING: Vector3.FORWARD,
	Cat.BOAT_CARGO: Vector3.BACK, Cat.BOAT_SUB: Vector3.BACK, Cat.CARRIER: Vector3.FORWARD,
	Cat.JET_F14: Vector3.BACK, Cat.JET_F111: Vector3.FORWARD,
}
const SHIPS := [Cat.BOAT_SIMPLE, Cat.BOAT_WOODEN, Cat.BOAT_FISHING, Cat.BOAT_CARGO, Cat.BOAT_SUB, Cat.CARRIER]
## The aircraft of the vehicle catalog face -Z (vehicles/CATALOG.md).
const VEHICLE_FRONT := Vector3.FORWARD
## Share of a helicopter's height searched for its sides (keeps the lights off the rotor tips).
const HELICOPTER_LOW := 0.55
## Size of a light: share of the model's length, and its limits (cells).
const SIZE_SHARE := 0.025
const SIZE_MIN := 0.05
const SIZE_MAX := 0.2

## Mesh -> [port, starboard] points in the mesh's own space (read once per mesh).
static var _sides := {}


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("nav_red", _light(RED))
	lib.add_named("nav_green", _light(GREEN))


static func _light(color: Color) -> ArrayMesh:
	var k := MeshKit.new()
	k.neon(true)
	k.box(Vector3(-0.5, -0.5, -0.5), Vector3.ONE, color)
	k.neon(false)
	return k.commit()


## The lights of library model `id` drawn at `xform`, when it is a ship or an aircraft of the
## model catalog: [[library id, transform], ...] (empty for anything else).
static func for_model(lib: ModelLibrary, id: int, xform: Transform3D) -> Array:
	var cat: int = lib.cats[id]
	if not FRONT.has(cat):
		return []
	return _lights(lib, id, xform, FRONT[cat], SHIPS.has(cat), 1.0)


## The lights of catalog vehicle `vehicle` (mesh `id` drawn at `xform`) when it is an aircraft.
static func for_vehicle(lib: ModelLibrary, vehicle: String, id: int, xform: Transform3D) -> Array:
	if MapVehicles.entry(vehicle).get("category", "") != "Aircraft":
		return []
	return _lights(lib, id, xform, VEHICLE_FRONT, false,
			HELICOPTER_LOW if vehicle.contains("helicopter") else 1.0)


## Adds the lights of `for_model` to `batch`.
static func add_to(batch: InstanceBatch, lib: ModelLibrary, id: int, xform: Transform3D) -> void:
	for l in for_model(lib, id, xform):
		batch.add(l[0], l[1])


static func _lights(lib: ModelLibrary, id: int, xform: Transform3D, front: Vector3, ship: bool,
		low: float) -> Array:
	var red := lib.named_id("nav_red")
	var green := lib.named_id("nav_green")
	if red < 0 or green < 0:
		return []
	var mesh: Mesh = lib.meshes[id]
	if not _sides.has(mesh):
		_sides[mesh] = _find_sides(mesh, front, ship, low)
	var sides: Array = _sides[mesh]
	if sides.is_empty():
		return []
	var box := xform * lib.bounds[id]
	var size := clampf(maxf(box.size.x, box.size.z) * SIZE_SHARE, SIZE_MIN, SIZE_MAX)
	var basis := Basis.from_scale(Vector3.ONE * size)
	return [[red, Transform3D(basis, xform * (sides[0] as Vector3))],
			[green, Transform3D(basis, xform * (sides[1] as Vector3))]]


## The leftmost and rightmost points of the mesh seen from its front `front` (up is +Y):
## for a ship only in its bow half above the waterline, for a helicopter only in the lower
## `low` of its height.
static func _find_sides(mesh: Mesh, front: Vector3, ship: bool, low: float) -> Array:
	var right := front.cross(Vector3.UP)
	var box := mesh.get_aabb()
	var middle := box.get_center().dot(front)
	var top := box.position.y + box.size.y * low
	var port := Vector3.ZERO
	var starboard := Vector3.ZERO
	var least := INF
	var most := -INF
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			# Ships: the bow half, above the waterline (y 0, the hull below is hidden by the sea).
			if (ship and (v.dot(front) < middle or v.y < 0.0)) or v.y > top:
				continue
			var side := v.dot(right)
			if side < least:
				least = side
				port = v
			if side > most:
				most = side
				starboard = v
	if least == INF:
		return []
	return [port, starboard]
