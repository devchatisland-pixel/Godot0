class_name LoadingOverlay
extends CanvasLayer
## Loading screen shown while the city is generated, then a discreet city name.

var _panel: ColorRect
var _label: Label
var _bar: ProgressBar
var _title: Label


func _ready() -> void:
	layer = 10
	_panel = ColorRect.new()
	_panel.color = Color(0.1, 0.27, 0.4)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(320, 0)
	box.position = Vector2(-160, -40)
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(320, 10)
	box.add_child(_bar)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.position = Vector2(-200, 18)
	_title.custom_minimum_size = Vector2(400, 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.3))
	_title.add_theme_constant_override("outline_size", 8)
	_title.visible = false
	add_child(_title)


func set_progress(value: float, text: String) -> void:
	_bar.value = value
	_label.text = text


func finish(_city_name: String) -> void:
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_panel.queue_free)
