class_name MapMenu
extends CanvasLayer
## Start screen: choose which parts of the map are built. The last choice is remembered.

signal chosen(show_continent: bool, show_fog_island: bool)

const SAVE_PATH := "user://map_options.cfg"

var _continent: CheckBox
var _fog: CheckBox
var _panel: ColorRect


## The remembered choice as [show_continent, show_fog_island] (both on the first time).
static func load_choice() -> Array:
	var f := ConfigFile.new()
	if f.load(SAVE_PATH) != OK:
		return [true, true]
	return [bool(f.get_value("map", "continent", true)), bool(f.get_value("map", "fog_island", true))]


static func save_choice(show_continent: bool, show_fog_island: bool) -> void:
	var f := ConfigFile.new()
	f.set_value("map", "continent", show_continent)
	f.set_value("map", "fog_island", show_fog_island)
	f.save(SAVE_PATH)


func _ready() -> void:
	layer = 11
	var last := load_choice()
	_panel = ColorRect.new()
	_panel.color = Color(0.1, 0.27, 0.4)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Map"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	_continent = CheckBox.new()
	_continent.text = "Continent"
	_continent.button_pressed = last[0]
	_continent.add_theme_font_size_override("font_size", 22)
	box.add_child(_continent)

	_fog = CheckBox.new()
	_fog.text = "Fog island"
	_fog.button_pressed = last[1]
	_fog.add_theme_font_size_override("font_size", 22)
	box.add_child(_fog)

	var start := Button.new()
	start.text = "Start"
	start.custom_minimum_size = Vector2(0, 48)
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(_on_start)
	box.add_child(start)
	start.grab_focus()


func _on_start() -> void:
	var c := _continent.button_pressed
	var f := _fog.button_pressed
	save_choice(c, f)
	chosen.emit(c, f)
	queue_free()
