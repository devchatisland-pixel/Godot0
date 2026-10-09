class_name DayNight
extends Node
## Automatic day and night cycle. Changes the sun, the ambient light and the
## sky colour, and fades in everything that glows at night (windows, signs,
## lamps, floodlights) through the materials registered in SignAtlas.
## Neon is unshaded, so it simply stands out once the city gets dark.
## No lights are added: the cost is the same by day and by night.

## Share of the cycle (0..1) where dusk starts, night is full, dawn starts and ends.
const DUSK_START := 0.55
const NIGHT_START := 0.65
const DAWN_START := 0.9

const SUN_DAY := Color(1.0, 0.97, 0.92)
const SUN_DUSK := Color(1.0, 0.6, 0.38)
const SUN_NIGHT := Color(0.55, 0.65, 1.0)
const AMBIENT_DAY := Color(0.82, 0.84, 0.95)
const AMBIENT_NIGHT := Color(0.32, 0.38, 0.66)
const SKY_NIGHT := Color(0.03, 0.07, 0.14)

var _sun: DirectionalLight3D
var _env: Environment
var _sky_day: Color
var _cycle := 240.0
var _time := 0.0
## 0 = full day, 1 = full night (read by tests and UI if needed).
var night := 0.0
## The fog over the hidden island darkens with the night.
var fog_island: FogIsland


func setup(sun: DirectionalLight3D, env: Environment, cycle_seconds: float, start_phase: float) -> void:
	_sun = sun
	_env = env
	_sky_day = env.background_color
	_cycle = maxf(cycle_seconds, 10.0)
	_time = start_phase * _cycle
	_apply(start_phase)


## Jumps to a point of the cycle (0 = morning, 0.75 = middle of the night).
func set_phase(phase: float) -> void:
	_time = fposmod(phase, 1.0) * _cycle
	_apply(fposmod(phase, 1.0))


func _process(delta: float) -> void:
	if _sun == null:
		return
	_time += delta
	_apply(fposmod(_time / _cycle, 1.0))


func _apply(phase: float) -> void:
	night = night_amount(phase)
	var warm := 1.0 - absf(night * 2.0 - 1.0) # strongest at dusk and dawn
	_sun.light_color = SUN_DAY.lerp(SUN_NIGHT, night).lerp(SUN_DUSK, warm * 0.7)
	_sun.light_energy = lerpf(0.95, 0.2, night)
	_env.ambient_light_color = AMBIENT_DAY.lerp(AMBIENT_NIGHT, night)
	_env.ambient_light_energy = lerpf(0.55, 0.3, night)
	_env.background_color = _sky_day.lerp(SKY_NIGHT, night)
	for entry in SignAtlas.night_materials():
		(entry[0] as BaseMaterial3D).emission_energy_multiplier = lerpf(entry[1], entry[2], night)
	if fog_island != null:
		fog_island.set_night(night)


static func night_amount(phase: float) -> float:
	if phase < DUSK_START:
		return 0.0
	if phase < NIGHT_START:
		return smoothstep(DUSK_START, NIGHT_START, phase)
	if phase < DAWN_START:
		return 1.0
	return 1.0 - smoothstep(DAWN_START, 1.0, phase)
