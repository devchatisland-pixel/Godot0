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
## The modular houses (tools/build_modular_buildings.py) have their fronts towards -Z.
const FRONT := {Cat.JET_F111: PI, Cat.FOG_MOD_HOUSE: PI, Cat.FOG_MOD_HOME: PI}

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
	Cat.FOG_OFFICE: ["Office building", "OFFICE"], Cat.FOG_HOUSE: ["House", "HOUSE"],
	Cat.FOG_NIGHT_TOWER: ["Night tower", "SKYSCRAPER"], Cat.FOG_OFFICE_TOWER: ["Office tower", "SKYSCRAPER"],
	Cat.FOG_FLOOR: ["Block of flats", "APARTMENT"], Cat.FOG_MOD_HOUSE: ["Town house", "HOUSE"],
	Cat.FOG_MOD_TOWER: ["Tower", "SKYSCRAPER"], Cat.FOG_MOD_HOME: ["Town house", "HOUSE"],
	Cat.FOG_MARKET: ["Country market store", "SHOP"], Cat.FOG_WAREHOUSE: ["Food warehouse", "BUILDING"],
}

## Clickable things: {"mesh": Mesh, "xform": Transform3D, "pick": Dictionary} (see BuildingPicker).
var picks: Array[Dictionary] = []


## Draws mesh `id` at `xform` and makes it clickable.
func _put(lib: ModelLibrary, batch: InstanceBatch, id: int, xform: Transform3D, title: String,
		kind: String, note: String) -> void:
	batch.add(id, xform)
	NavLights.add_to(batch, lib, id, xform)
	var cat: int = lib.cats[id]
	picks.append({"mesh": lib.meshes[id], "xform": xform, "pick": {
		"uid": "M-%03d" % picks.size(), "number": picks.size(), "title": title, "kind": kind,
		"model": lib.model_name(id), "category": Cat.keys()[cat] if cat >= 0 else "", "note": note,
	}})


func build(data: CityData, lib: ModelLibrary) -> void:
	var batch := InstanceBatch.new()
	var placed := 0
	if data.fog != null:
		placed = _base(data, lib, batch)
		_carriers(data.fog, lib, batch)
		_roads(data.fog)
		_fences(data.fog)
	_formation(lib, batch)
	batch.build_nodes(self, lib, null)
	print("[FogBase] %d models on the fog island" % placed)


func _base(data: CityData, lib: ModelLibrary, batch: InstanceBatch) -> int:
	var fog := data.fog
	var n := 0
	for p in FogBaseSites.plan():
		var at: Vector2 = p["at"]
		if not _on_land(fog, at, float(p.get("fit", 0.0)) * 0.5):
			push_warning("[FogBase] %s is in the sea" % at)
			continue
		var id := -1
		var scale: float = p.get("scale", 1.0)
		var turn := 0.0
		var label := ["Military model", "MILITARY"]
		var note := "military base of the fog island"
		if p.get("landing_zone", false):
			var zone := _landing_zone(data, lib, fog.origin + at)
			if not zone.is_empty():
				_put(lib, batch, zone["id"], zone["xform"], "Landing zone", "MILITARY", note)
				n += 1
			continue
		if p.has("veh"):
			id = MapVehicles.mesh_id(lib, p["veh"])
			scale *= VehicleSites.CELLS_PER_METRE
			turn = PI # the vehicles of the catalog face -Z
			label = [MapVehicles.entry(p["veh"]).get("name", p["veh"]), "VEHICLE"]
			note = "on the fog island"
		elif p.has("named"):
			id = lib.named_id(p["named"])
			label = ["Crop field", "FIELD"]
			note = "farmland of the fog island"
			if String(p["named"]).begins_with("yardbox:"):
				label = ["Shipping container", "PROP"]
				note = "industrial zone of the fog island"
		else:
			var ids := lib.ids(p["cat"])
			id = ids[int(p.get("v", 0)) % ids.size()] if not ids.is_empty() else -1
			turn = FRONT.get(p["cat"], 0.0)
			label = TITLES.get(p["cat"], [lib.model_name(id), "BUILDING"])
			if label[1] != "MILITARY" and label[1] != "VEHICLE":
				note = "town of the fog island"
		if id < 0:
			continue
		var box := lib.bounds[id]
		if p.has("fit"):
			scale = float(p["fit"]) / maxf(maxf(box.size.x, box.size.z), 0.01)
		var dir: Vector2 = p["dir"]
		var lift := MapVehicles.HELIPAD_LIFT if p.get("veh", "") == FogBaseSites.HELICOPTER else 0.0
		var ground := Vector3(fog.origin.x + at.x, lift, fog.origin.y + at.y)
		var yaw := atan2(dir.x, dir.y) + turn
		var xform: Transform3D
		if p.has("size"):
			# A flat model (a crop field) stretched over its lot.
			var size: Vector2 = p["size"]
			var basis := Basis.from_scale(Vector3(size.x / maxf(box.size.x, 0.01), 1.0, size.y / maxf(box.size.z, 0.01)))
			xform = Transform3D(basis, ground - basis * Vector3(box.get_center().x, box.position.y, box.get_center().z))
		elif p.get("origin", false):
			# A model built round its own origin (the checkpoint: the middle of its road) stands
			# with that origin on `at`, not the middle of its box.
			xform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale), ground)
		else:
			xform = _standing(lib, id, ground, yaw, scale)
		# Storeys piled up (the block storey of the fog_city pack).
		for k in int(p.get("stack", 1)):
			var up := Transform3D(Basis(), Vector3(0, box.size.y * scale * k, 0)) * xform
			_put(lib, batch, id, up, label[0], label[1], note)
		if p.has("veh"):
			for l in NavLights.for_vehicle(lib, p["veh"], id, xform):
				batch.add(l[0], l[1])
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


## True when the cell of `at` and the corners `half` cells round it are land of the island.
static func _on_land(fog: FogIslandShaper, at: Vector2, half: float) -> bool:
	for o in [Vector2.ZERO, Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
		var c := Vector2i((at + (o as Vector2)).floor())
		if c.x < 0 or c.y < 0 or c.x >= FogIslandShaper.SIZE or c.y >= FogIslandShaper.SIZE:
			return false
		if fog.elevation[c.y * FogIslandShaper.SIZE + c.x] <= 128:
			return false
	return true


## The landing zone of the army base: the model of the secret base of the main island (Kind.AIRBASE),
## drawn exactly as big as there, its middle on `at` (world x, z). {} when there is no secret base.
static func _landing_zone(data: CityData, lib: ModelLibrary, at: Vector2) -> Dictionary:
	for b in data.building_count():
		if data.b_kind[b] != CityTypes.Kind.AIRBASE:
			continue
		var pick := BuildingPlacer.pick_for(data, lib, b)
		if pick.is_empty():
			return {}
		var xform: Transform3D = pick["xform"]
		var box: AABB = xform * lib.bounds[pick["id"]]
		var shift := Vector3(at.x - box.get_center().x, 0.0, at.y - box.get_center().z)
		return {"id": pick["id"], "xform": Transform3D(xform.basis, xform.origin + shift)}
	return {}


## The wire fences of FogBaseSites.FENCES (round the army base and the nuclear plant).
func _fences(fog: FogIslandShaper) -> void:
	for f in FogBaseSites.FENCES:
		var r: Rect2 = f[0]
		var mesh := MapFences.fence_mesh(Rect2(r.position + fog.origin, r.size), float(f[2]), int(f[1]), MapFences.BASE_GATE)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Fence_%d" % get_child_count()
		add_child(mi)
		picks.append({"mesh": mesh, "xform": Transform3D.IDENTITY, "pick": {
			"uid": "M-%03d" % picks.size(), "number": picks.size(), "title": "Wire fence", "kind": "FENCE",
			"model": "wire fence", "category": "Prop", "note": "fog island",
		}})
