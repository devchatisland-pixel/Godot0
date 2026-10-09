extends Node
## Test helper: when the game runs with `-- --capture <dir>`, waits for the
## city, then saves screenshots of several places / zoom levels and quits.

const Kind := CityTypes.Kind
const SHOTS := [
	{"zoom": 80.0, "at": "center"},
	{"zoom": 26.0, "at": Kind.LANDMARK},
	{"zoom": 20.0, "at": Kind.QUARTER_BLDG},
	{"zoom": 20.0, "at": Kind.SHOPPING_CENTER},
	{"zoom": 18.0, "at": Kind.CINEMA},
	{"zoom": 20.0, "at": Kind.OUTPOST},
	{"zoom": 22.0, "at": Kind.CASINO},
	{"zoom": 20.0, "at": Kind.CITY_HALL},
	{"zoom": 22.0, "at": Kind.HOUSE},
	{"zoom": 45.0, "at": Kind.POND},
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
		cam.target = base if shot["at"] is String else _find(data, shot["at"], base)
		cam.zoom = shot["zoom"]
		cam.set("_zoom_goal", shot["zoom"])
		var frames := 0
		while frames < 600:
			await get_tree().process_frame
			frames += 1
			if frames > 20 and main.streamer.pending_jobs() == 0:
				break
		for k in 5:
			await get_tree().process_frame
		var path: String = _dir.path_join("shot_%d.png" % s)
		get_viewport().get_texture().get_image().save_png(path)
		print("[Capture] ", path, " at ", shot["at"], " chunks ", main.streamer.loaded_counts())
	get_tree().quit()


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
