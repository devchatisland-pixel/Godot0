class_name DevInspector
extends Node
## Developer tool: right-click (or right tap) anywhere on the map to see where you are.
## A square marks the cell and a card gives the coordinates the generator works with:
## cell, world position, chunk, terrain, zone, road, and the parcel (lot) under the
## cursor with its building id. The same line is printed in the console and can be
## copied. Left click still selects things (BuildingPicker); this is the second way.

const ACCENT := Color(0.35, 0.9, 1.0)

var _cam: IsoCamera
var _data: CityData
var _marker: MeshInstance3D
var _parcel: MeshInstance3D
var _layer := CanvasLayer.new()
var _panel: PanelContainer
var _label: Label
var _copy: Button
var _text := ""
var _cell := Vector2i(-1, -1)
var _shown := false


func setup(cam: IsoCamera, data: CityData) -> void:
	_cam = cam
	_data = data
	_cam.right_tapped.connect(_on_right_tap)
	_marker = _quad(Color(ACCENT, 0.55))
	_parcel = _quad(Color(ACCENT, 0.18))
	_layer.layer = 7
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.12, 0.92)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEV  -  map position"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_copy = Button.new()
	_copy.text = "Copy"
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_text)
		_copy.text = "Copied!")
	row.add_child(_copy)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_info)
	row.add_child(close)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _shown:
		hide_info()


func hide_info() -> void:
	_shown = false
	_panel.visible = false
	_marker.visible = false
	_parcel.visible = false


func _on_right_tap(screen_pos: Vector2) -> void:
	var p := _cam.ground_point(screen_pos)
	_cell = Vector2i(floori(p.x), floori(p.z))
	_shown = true
	var info := inspect(_cell, p)
	_text = info["text"]
	_label.text = info["lines"]
	_copy.text = "Copy"
	print("[Dev] ", _text)
	_marker.visible = true
	_marker.position = Vector3(_cell.x + 0.5, 0.09, _cell.y + 0.5)
	_marker.scale = Vector3.ONE
	var lot: Rect2i = info["lot"]
	_parcel.visible = lot.size.x > 0
	if _parcel.visible:
		_parcel.position = Vector3(lot.position.x + lot.size.x * 0.5, 0.08, lot.position.y + lot.size.y * 0.5)
		_parcel.scale = Vector3(lot.size.x, lot.size.y, 1.0)
	_panel.visible = true
	await get_tree().process_frame
	var view := get_viewport().get_visible_rect().size
	var pos := screen_pos + Vector2(18, 18)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - _panel.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - _panel.size.y - 8.0))
	_panel.position = pos


## What is known about `cell`: {text, lines, lot} (lot is the parcel Rect2i, size 0 when empty).
func inspect(cell: Vector2i, world: Vector3) -> Dictionary:
	var d := _data
	if not d.in_bounds(cell.x, cell.y):
		return {"text": "cell %d,%d outside the map" % [cell.x, cell.y],
				"lines": "Cell %d, %d\n(outside the map)" % [cell.x, cell.y], "lot": Rect2i()}
	var i := d.idx(cell.x, cell.y)
	var chunk := Vector2i(cell.x / d.chunk_size, cell.y / d.chunk_size)
	var terrain: String = CityTypes.Terrain.keys()[d.terrain[i]]
	var zone: String = CityTypes.Zone.keys()[d.zone[i]]
	var road := "road (mask %d)" % d.road_mask(cell.x, cell.y) if d.road[i] != 0 else "no road"
	var lot := Rect2i()
	var b := -1
	for k in d.building_count():
		var r := d.building_rect(k)
		if r.has_point(cell):
			b = k
			lot = r
			# Keep looking: a small building can stand inside a bigger plot.
	var parcel := "none"
	if b >= 0:
		parcel = "B-%05d %s  [%d,%d  %dx%d]" % [b, CityTypes.Kind.keys()[d.b_kind[b]], lot.position.x, lot.position.y, lot.size.x, lot.size.y]
	var lines := "Cell: %d, %d\nWorld: %.2f, %.2f\nChunk: %d, %d\nTerrain: %s   Zone: %s\n%s   Elevation: %d\nParcel: %s" % [
			cell.x, cell.y, world.x, world.z, chunk.x, chunk.y, terrain, zone, road.capitalize(), d.elevation[i] if not d.elevation.is_empty() else -1, parcel]
	var text := "cell %d,%d | world %.2f,%.2f | chunk %d,%d | %s | %s | %s | parcel %s" % [
			cell.x, cell.y, world.x, world.z, chunk.x, chunk.y, terrain, zone, road, parcel]
	return {"text": text, "lines": lines, "lot": lot}


func _quad(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90, 0, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 3
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi
