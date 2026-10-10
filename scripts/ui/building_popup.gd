class_name BuildingPopup
extends CanvasLayer
## The information bubble of the selected building: a dark card with an orange frame
## that floats over the building and follows it while the map moves, joined to it by a
## thin line. Shows the name, the code name, the id and where it is. Closes with the X,
## with Esc or by clicking elsewhere (see BuildingPicker).

signal closed

const ACCENT := Color(1.0, 0.72, 0.18)
## Distance between the building and the card, in pixels.
const GAP := 46.0

var _panel: PanelContainer
var _stem: Control
var _title: Label
var _subtitle: Label
var _grid: GridContainer
var _copy: Button
var _text := ""
var _anchor := Vector2.ZERO
var _shown := false
var _tween: Tween


func _ready() -> void:
	layer = 6
	_stem = Control.new()
	_stem.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stem.draw.connect(_draw_stem)
	add_child(_stem)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style())
	_panel.custom_minimum_size = Vector2(300, 0)
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	titles.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.add_theme_color_override("font_color", ACCENT)
	titles.add_child(_subtitle)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)

	box.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_grid)

	_copy = Button.new()
	_copy.text = "Copy info"
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.pressed.connect(_on_copy)
	box.add_child(_copy)


func is_open() -> bool:
	return _shown


## Fills the card and pops it up.
func show_info(info: Dictionary) -> void:
	_title.text = String(info["name"])
	_subtitle.text = "%s   %s" % [info["uid"], info["kind"]]
	for c in _grid.get_children():
		c.queue_free()
	var cell: Vector2i = info["cell"]
	var size: Vector2i = info["size"]
	var world: Vector3 = info["world"]
	_row("ID", "%s  (#%d)" % [info["uid"], info["id"]])
	_row("Kind", String(info["kind"]))
	_row("Model", String(info["model"]))
	if String(info["category"]) != "":
		_row("Category", String(info["category"]))
	_row("Cell", "%d, %d   (%d x %d)" % [cell.x, cell.y, size.x, size.y])
	_row("World", "%.1f, %.1f" % [world.x, world.z])
	_row("Facing", String(info["facing"]))
	_row("Zone", String(info["zone"]))
	_row("Seed", str(info["seed"]))
	_text = BuildingInfo.to_text(info)
	_copy.text = "Copy info"
	_shown = true
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.86, 0.86)
	# Pop up from the bottom centre of the card, once its size is known.
	await get_tree().process_frame
	if not _shown:
		return
	_panel.pivot_offset = Vector2(_panel.size.x * 0.5, _panel.size.y)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_popup() -> void:
	_shown = false
	_panel.visible = false
	_stem.queue_redraw()


## Screen position of the selected building (called every frame).
func set_anchor(screen_pos: Vector2) -> void:
	_anchor = screen_pos
	if not _shown:
		return
	var view := get_viewport().get_visible_rect().size
	var size := _panel.size
	var pos := Vector2(screen_pos.x - size.x * 0.5, screen_pos.y - size.y - GAP)
	if pos.y < 8.0: # no room above: put the card below the building
		pos.y = screen_pos.y + GAP
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - size.y - 8.0))
	_panel.position = pos
	_stem.queue_redraw()


func _draw_stem() -> void:
	if not _shown or not _panel.visible:
		return
	var from := Vector2(clampf(_anchor.x, _panel.position.x + 12.0, _panel.position.x + _panel.size.x - 12.0),
			_panel.position.y + (_panel.size.y if _anchor.y > _panel.position.y else 0.0))
	_stem.draw_line(from, _anchor, ACCENT, 2.0, true)
	_stem.draw_circle(_anchor, 5.0, ACCENT)
	_stem.draw_arc(_anchor, 9.0, 0.0, TAU, 24, Color(ACCENT, 0.5), 1.5, true)


func _row(key: String, value: String) -> void:
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
	_grid.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.custom_minimum_size = Vector2(190, 0)
	_grid.add_child(v)


func _on_copy() -> void:
	DisplayServer.clipboard_set(_text)
	_copy.text = "Copied!"


func _style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.09, 0.15, 0.93)
	s.border_color = ACCENT
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	return s
