class_name CodePanel
extends Control
## A keypad for a four digit code: the parental lock on the Gore setting.
## Works with a controller (a grid of buttons), a mouse, or the number keys.

signal entered(code: String)
signal cancelled

const LENGTH := 4

var _shown: Label
var _title: Label
var _code := ""
var _grid: GridContainer


func _init() -> void:
	name = "CodePanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	_title = LGUi.label("", "HeaderMedium")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_shown = LGUi.label("", "HeaderLarge")
	_shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_shown)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)
	for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]:
		var b := LGUi.button(d, _press.bind(d), 96)
		_grid.add_child(b)
	col.add_child(LGUi.button("Cancel", _cancel, 320))


## Opens it with a title ("Lock the gore setting").
func ask(title: String) -> void:
	_title.text = title
	_code = ""
	_refresh()
	visible = true
	LGUi.focus_first(_grid)


func _press(d: String) -> void:
	match d:
		"<":
			_code = _code.substr(0, maxi(0, _code.length() - 1))
		"OK":
			if _code.length() == LENGTH:
				visible = false
				entered.emit(_code)
				return
		_:
			if _code.length() < LENGTH:
				_code += d
	_refresh()


func _refresh() -> void:
	var s := ""
	for i in LENGTH:
		s += ("* " if i < _code.length() else "_ ")
	_shown.text = s.strip_edges()


func _cancel() -> void:
	visible = false
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_0 and k <= KEY_9:
			_press(str(k - KEY_0))
			get_viewport().set_input_as_handled()
		elif k == KEY_BACKSPACE:
			_press("<")
			get_viewport().set_input_as_handled()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			_press("OK")
			get_viewport().set_input_as_handled()
