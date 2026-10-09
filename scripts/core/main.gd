extends Node3D
## Entry point: generates the city on a worker thread, loads the models a few
## per frame, then hands over to the camera and the chunk streamer.

enum Phase { GENERATING, LOADING_MODELS, RUNNING }

var cfg: CityConfig
var data: CityData
var library: ModelLibrary
var camera: IsoCamera
var streamer: ChunkStreamer

var _phase := Phase.GENERATING
var _thread := Thread.new()
var _overlay: LoadingOverlay
var _gen_progress := 0.0
var _gen_text := ""
var _models_progress := 0.0


func _ready() -> void:
	cfg = CityConfig.create()
	_setup_environment()
	_overlay = LoadingOverlay.new()
	add_child(_overlay)
	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	add_child(camera)
	camera.current = true

	library = ModelLibrary.new()
	library.begin(cfg)
	if cfg.use_threads:
		_thread.start(_generate_city)
	else:
		_generate_without_thread()
	if "--capture" in OS.get_cmdline_user_args():
		add_child(load("res://tests/capture_runner.gd").new())


func _generate_city() -> CityData:
	return CityGenerator.new(cfg, _on_gen_progress).generate()


## Single-threaded builds: let the loading screen draw first, then generate.
func _generate_without_thread() -> void:
	_overlay.set_progress(0.0, "Generating the city")
	for i in 3:
		await get_tree().process_frame
	data = _generate_city()
	_gen_progress = 1.0


func _on_gen_progress(value: float, text: String) -> void:
	_gen_progress = value
	_gen_text = text


func _process(_delta: float) -> void:
	match _phase:
		Phase.GENERATING, Phase.LOADING_MODELS:
			_update_loading()
		Phase.RUNNING:
			streamer.update_view(camera.view_polygon(), camera.zoom)


func _update_loading() -> void:
	# Models load on the main thread while the city generates in the background.
	if _models_progress < 1.0:
		_models_progress = library.load_next(3)
	var total := _gen_progress * 0.6 + _models_progress * 0.4
	var text := _gen_text if _gen_progress < 1.0 else "Loading buildings"
	_overlay.set_progress(total, text)
	if data == null and _thread.is_started() and not _thread.is_alive():
		data = _thread.wait_to_finish()
	if data != null and _models_progress >= 1.0:
		_start_city()


func _start_city() -> void:
	ServiceMeshes.build_all(library)
	LandmarkMeshes.build_all(library)
	var ground := GroundLayer.new()
	ground.name = "Ground"
	add_child(ground)
	ground.build(cfg, data)
	# Elevation is now in a texture, the CPU copy is no longer needed.
	data.elevation = PackedByteArray()

	streamer = ChunkStreamer.new()
	streamer.name = "City"
	add_child(streamer)
	streamer.setup(cfg, data, library)

	var c := data.centers[0] if not data.centers.is_empty() else Vector2(data.size, data.size) * 0.5
	camera.setup(cfg, data.size, Vector3(c.x, 0, c.y))
	_overlay.finish(data.city_name)
	_phase = Phase.RUNNING


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = GroundLayer.DEEP_SEA
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.95)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 22.0, 0.0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = cfg.shadows
	add_child(sun)


func _exit_tree() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()
