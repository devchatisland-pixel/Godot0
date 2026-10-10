extends Node
## Test helper: when the game runs with `-- --capture <dir>`, waits for the
## city, then saves screenshots of several places / zoom levels and quits.

const Kind := CityTypes.Kind
const SHOTS := [
	{"zoom": 62.0, "at": "start"},
	{"zoom": 230.0, "at": "center"},
	{"zoom": 230.0, "at": "center", "night": true},
	{"zoom": 40.0, "at": "bridge"},
	{"zoom": 70.0, "at": "urban"},
	{"zoom": 50.0, "at": "port"},
	{"zoom": 26.0, "at": Kind.MCDONALDS},
	{"zoom": 40.0, "at": Kind.PRISON},
	{"zoom": 40.0, "at": Kind.MOUNTAIN},
	{"zoom": 30.0, "at": Kind.CASINO},
	{"zoom": 45.0, "at": Kind.NUCLEAR_PLANT},
	{"zoom": 30.0, "at": Kind.BT_TOWER, "night": true},
	{"zoom": 22.0, "at": Kind.WATCHTOWER},
	{"zoom": 30.0, "at": Kind.NIGHTCLUB},
]

var _dir := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_dir = args[i + 1]
	_run()


func _run() -> void:
	var main := get_parent()
	while main.streamer == null:
		await get_tree().process_frame
	var cam: IsoCamera = main.camera
	var data: CityData = main.data
	var args := OS.get_cmdline_user_args()
	var bi := args.find("--building")
	if bi >= 0 and bi + 1 < args.size():
		await _single(main, int(args[bi + 1]))
		return
	var base := cam.target
	for s in SHOTS.size():
		var shot: Dictionary = SHOTS[s]
		cam.target = _place(data, shot["at"], base)
		cam.zoom = shot["zoom"]
		cam.set("_zoom_goal", shot["zoom"])
		var frames := 0
		while frames < 600:
			await get_tree().process_frame
			frames += 1
			if frames > 20 and main.streamer.pending_jobs() == 0:
				break
		if main.day_night != null:
			main.day_night.set_phase(0.78 if shot.get("night", false) else 0.2)
		for k in 5:
			await get_tree().process_frame
		var path: String = _dir.path_join("shot_%d.png" % s)
		get_viewport().get_texture().get_image().save_png(path)
		print("[Capture] ", path, " at ", shot["at"], " chunks ", main.streamer.loaded_counts())
	get_tree().quit()


func _place(data: CityData, at, base: Vector3) -> Vector3:
	match at:
		"center", "start":
			return base
		"both":
			return Vector3(data.size, 0, data.size * 0.5)
		"fog":
			var c := data.fog.center()
			return Vector3(c.x, 0, c.y)
		"bridge":
			return Vector3(data.bridge.x + 4, 0, data.bridge.y)
		"west_bridge":
			return Vector3(data.west_bridge.x - 6, 0, data.west_bridge.z)
		"urban":
			return Vector3(28, 0, 138)
		"port":
			return Vector3(84, 0, 182)
	return _find(data, at, base)


## Centre of the building of `kind` closest to `near` (at a little distance for houses).
func _find(data: CityData, kind: int, near: Vector3) -> Vector3:
	var best := near
	var best_d := INF
	for b in data.building_count():
		if data.b_kind[b] != kind:
			continue
		var r := data.building_rect(b)
		var p := Vector3(r.get_center().x, 0, r.get_center().y)
		var d := p.distance_to(near)
		if kind == Kind.HOUSE:
			d = absf(d - 50.0)
		if d < best_d:
			best_d = d
			best = p
	return best


## One close shot of building `id` (zoom 9, by day) saved as building.png, then quit.
func _single(main: Node, id: int) -> void:
	var cam: IsoCamera = main.camera
	var r: Rect2i = main.data.building_rect(id)
	cam.target = Vector3(r.get_center().x, 0, r.get_center().y)
	cam.zoom = 9.0
	cam.set("_zoom_goal", 9.0)
	var frames := 0
	while frames < 900:
		await get_tree().process_frame
		frames += 1
		if frames > 30 and main.streamer.pending_jobs() == 0:
			break
	if main.day_night != null:
		main.day_night.set_phase(0.2)
	for k in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_dir.path_join("building.png"))
	print("[Capture] building ", id, " saved")
	get_tree().quit()
