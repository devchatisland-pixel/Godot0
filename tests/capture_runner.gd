extends Node
## Test helper: when the game runs with `-- --capture <dir>`, waits for the
## city, then saves screenshots of several places / zoom levels and quits.

const Kind := CityTypes.Kind
const SHOTS := [
	{"zoom": 80.0, "at": "center"},
	{"zoom": 80.0, "at": "center", "night": true},
	{"zoom": 120.0, "at": "both"},
	{"zoom": 70.0, "at": "fog"},
	{"zoom": 70.0, "at": "fog", "night": true},
	{"zoom": 30.0, "at": "bridge"},
	{"zoom": 34.0, "at": Kind.AIRBASE},
	{"zoom": 16.0, "at": Kind.CEMETERY},
	{"zoom": 18.0, "at": Kind.MUSEUM},
	{"zoom": 14.0, "at": Kind.HOTEL},
	{"zoom": 16.0, "at": Kind.MAIN_HOSPITAL, "night": true},
	{"zoom": 22.0, "at": Kind.STADIUM, "night": true},
	{"zoom": 14.0, "at": Kind.DRIVE_IN, "night": true},
	{"zoom": 22.0, "at": Kind.UN_HQ},
	{"zoom": 20.0, "at": Kind.POLICE_HQ},
	{"zoom": 22.0, "at": Kind.CITY_HALL},
	{"zoom": 20.0, "at": Kind.MAIN_SCHOOL},
	{"zoom": 22.0, "at": Kind.FERRIS_WHEEL},
	{"zoom": 30.0, "at": Kind.LANDMARK},
	{"zoom": 16.0, "at": Kind.CASINO},
	{"zoom": 22.0, "at": Kind.COLISEUM},
	{"zoom": 14.0, "at": Kind.BUNKER},
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
		"center":
			return base
		"both":
			return Vector3(data.size, 0, data.size * 0.5)
		"fog":
			var c := data.fog.center()
			return Vector3(c.x, 0, c.y)
		"bridge":
			return Vector3(data.bridge.x + 10, 0, data.bridge.y)
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
