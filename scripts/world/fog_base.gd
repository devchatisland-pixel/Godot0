class_name FogBase
extends Node3D
## Draws the military base of the fog island (FogBaseSites): its models, one MultiMesh per
## model, the runway and the roads (flat panels with the highway texture, like HighwaySurface)
## and the helipad. Also the three F-111 flying in a V over the sea, far north of the island.
## Everything it draws can be clicked: `picks` lists them for BuildingPicker.add_prop.

const Cat := ModelCatalog.Cat
const TEXTURE := preload("res://textures/highway.jpg")
## Longest road panel (cells) and its height above the ground.
const SEGMENT := 12.0
const LIFT := 0.04
## Extra turn of the models whose front is not +Z.
const FRONT := {Cat.JET_F111: PI}

## The F-111 formation: cell of the leader (north of the main island, over the sea), where
## it flies to, height, distance between the jets and their size.
const FORMATION_AT := Vector2(196, 22)
const FORMATION_DIR := Vector2(1, 0)
const FORMATION_LIFT := 7.0
const FORMATION_GAP := 3.2
const FORMATION_SCALE := 2.0

## Aircraft carriers at sea round the fog island: where (degrees round its centre, east = 0,
## south = 90), how far out (1 = the coast) and how deep the hull lies in the water (cells).
const CARRIER_ANGLES := [38.0, 92.0, 143.0, 216.0, 268.0, 322.0]
## The carriers at these angles sail the first way round the island; the others were turned about.
const CARRIER_KEPT := [216.0, 268.0]
const CARRIER_RING := 1.34
const CARRIER_DRAUGHT := 0.4


## What the picker shows for each model category: [title, kind].
const TITLES := {
	Cat.JET_F14: ["F-14 Tomcat", "AIRCRAFT"], Cat.JET_F111: ["F-111 Aardvark", "AIRCRAFT"],
	Cat.BASE_HALL: ["Barracks", "MILITARY"], Cat.RADAR: ["Radar", "MILITARY"],
	Cat.SAM_NASAMS: ["NASAMS surface-to-air missile launcher", "MILITARY"],
	Cat.TENT_JUNGLE: ["Army tent", "MILITARY"], Cat.TENT_MEDICAL: ["Medical tent", "MILITARY"],
	Cat.TANK_T55: ["T-55 tank", "VEHICLE"], Cat.APC_BMP1: ["BMP-1 infantry fighting vehicle", "VEHICLE"],
	Cat.APC_BRDM: ["BRDM armoured car", "VEHICLE"], Cat.APC_EE11: ["EE-11 anti-aircraft vehicle", "VEHICLE"],
	Cat.NUCLEAR2: ["Nuclear power plant", "MILITARY"], Cat.CARRIER: ["Aircraft carrier", "SHIP"],
	Cat.CHECKPOINT: ["Golden Gate checkpoint", "MILITARY"],
}

## Clickable things: {"mesh": Mesh, "xform": Transform3D, "pick": Dictionary} (see BuildingPicker).
var picks: Array[Dictionary] = []


## Draws mesh `id` at `xform` and makes it clickable.
func _put(lib: ModelLibrary, batch: InstanceBatch, id: int, xform: Transform3D, title: String,
		kind: String, note: String) -> void:
	batch.add(id, xform)
	var cat: int = lib.cats[id]
	picks.append({"mesh": lib.meshes[id], "xform": xform, "pick": {
		"uid": "M-%03d" % picks.size(), "number": picks.size(), "title": title, "kind": kind,
		"model": lib.model_name(id), "category": Cat.keys()[cat] if cat >= 0 else "", "note": note,
	}})


func build(data: CityData, lib: ModelLibrary) -> void:
	var batch := InstanceBatch.new()
	var placed := 0
	if data.fog != null:
		placed = _base(data.fog, lib, batch)
		_carriers(data.fog, lib, batch)
		_roads(data.fog)
	_formation(lib, batch)
	batch.build_nodes(self, lib, null)
	print("[FogBase] %d models on the fog island" % placed)


func _base(fog: FogIslandShaper, lib: ModelLibrary, batch: InstanceBatch) -> int:
	var n := 0
	for p in FogBaseSites.plan():
		var at: Vector2 = p["at"]
		var cell := Vector2i(at.floor())
		if fog.elevation[cell.y * FogIslandShaper.SIZE + cell.x] <= 128:
			push_warning("[FogBase] %s is in the sea" % at)
			continue
		var id := -1
		var scale: float = p["scale"]
		var turn := 0.0
		var label := ["Military model", "MILITARY"]
		if p.has("veh"):
			id = MapVehicles.mesh_id(lib, p["veh"])
			scale *= VehicleSites.CELLS_PER_METRE
			turn = PI # the vehicles of the catalog face -Z
			label = [MapVehicles.entry(p["veh"]).get("name", p["veh"]), "VEHICLE"]
		else:
			var ids := lib.ids(p["cat"])
			id = ids[0] if not ids.is_empty() else -1
			turn = FRONT.get(p["cat"], 0.0)
			label = TITLES.get(p["cat"], label)
		if id < 0:
			continue
		var dir: Vector2 = p["dir"]
		var lift := MapVehicles.HELIPAD_LIFT if p.get("veh", "") == FogBaseSites.HELICOPTER else 0.0
		var ground := Vector3(fog.origin.x + at.x, lift, fog.origin.y + at.y)
		var yaw := atan2(dir.x, dir.y) + turn
		# A model built round its own origin (the checkpoint: the middle of its road) stands
		# with that origin on `at`, not the middle of its box.
		var xform := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale), ground) 				if p.get("origin", false) else _standing(lib, id, ground, yaw, scale)
		_put(lib, batch, id, xform, label[0], label[1], "military base of the fog island")
		n += 1
	var pad := MapVehicles.helipad_id(lib)
	if pad >= 0:
		var c := fog.origin + FogBaseSites.HELIPAD
		_put(lib, batch, pad, MapVehicles.helipad_xform(Vector3(c.x, 0, c.y), FogBaseSites.HELIPAD_SIZE),
				"Helipad", "MILITARY", "military base of the fog island")
	return n


## One carrier per angle of CARRIER_ANGLES, sailing round the island (its side to the coast).
func _carriers(fog: FogIslandShaper, lib: ModelLibrary, batch: InstanceBatch) -> void:
	var ids := lib.ids(Cat.CARRIER)
	if ids.is_empty():
		return
	var c := fog.center()
	var radius := Vector2(FogIslandShaper.SIZE, FogIslandShaper.SIZE) * 0.5 * Vector2(0.8, 0.7) * CARRIER_RING
	for deg: float in CARRIER_ANGLES:
		var a := deg_to_rad(deg)
		var p := c + Vector2(cos(a), sin(a)) * radius
		var yaw := atan2(-sin(a), cos(a)) + (0.0 if CARRIER_KEPT.has(deg) else PI)
		_put(lib, batch, ids[0], _standing(lib, ids[0], Vector3(p.x, -CARRIER_DRAUGHT, p.y), yaw, 1.0),
				"Aircraft carrier", "SHIP", "at sea round the fog island")


## Model `id` standing on the ground at `at`, its front (+Z) turned by `yaw`.
static func _standing(lib: ModelLibrary, id: int, at: Vector3, yaw: float, scale: float) -> Transform3D:
	var box := lib.bounds[id]
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale)
	return Transform3D(basis, at - basis * Vector3(box.get_center().x, box.position.y, box.get_center().z))


func _roads(fog: FogIslandShaper) -> void:
	var panels: Array[Transform3D] = []
	for r in FogBaseSites.ROADS:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
		var length := a.distance_to(b)
		var count := maxi(1, ceili(length / SEGMENT))
		var step := length / float(count)
		var dir := (b - a).normalized()
		for k in count:
			var c := fog.origin + a + dir * (step * (float(k) + 0.5))
			var basis := Basis.from_scale(Vector3(step, 1.0, float(r[2])))
			if not along_x:
				basis = Basis(Vector3.UP, PI * 0.5) * basis
			panels.append(Transform3D(basis, Vector3(c.x, LIFT, c.y)))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEXTURE
	mat.roughness = 0.95
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = panels.size()
	for i in panels.size():
		mm.set_instance_transform(i, panels[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BaseRoads"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Three F-111 in a V: the leader in front, a wingman behind it on each side.
func _formation(lib: ModelLibrary, batch: InstanceBatch) -> void:
	var jets := lib.ids(Cat.JET_F111)
	if jets.is_empty():
		return
	var dir := FORMATION_DIR.normalized()
	var side := Vector2(-dir.y, dir.x)
	var yaw := atan2(dir.x, dir.y) + float(FRONT.get(Cat.JET_F111, 0.0))
	for o in [Vector2.ZERO, -dir + side, -dir - side]:
		var c: Vector2 = FORMATION_AT + (o as Vector2) * FORMATION_GAP
		_put(lib, batch, jets[0], _standing(lib, jets[0], Vector3(c.x, FORMATION_LIFT, c.y), yaw, FORMATION_SCALE),
				"F-111 Aardvark", "AIRCRAFT", "flying in formation over the north sea")
