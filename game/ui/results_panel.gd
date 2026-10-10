class_name ResultsPanel
extends Control
## What happened on a deck, when you leave it or go down: a title, a few
## lines of how it went, and what to do next.

var _title: Label
var _sub: Label
var _lines: VBoxContainer
var _buttons: VBoxContainer
var _panel: PanelContainer


func _init() -> void:
	name = "Results"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	_title = LGUi.label("", "HeaderLarge")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_sub = LGUi.label("", "")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size = Vector2(560, 0)
	col.add_child(_sub)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 4)
	col.add_child(_lines)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)


func _ready() -> void:
	LGScreenFit.center(_panel)


## Shows it. `lines` are [label, value] pairs; `buttons` are [text, Callable].
func show_panel(title: String, sub: String, lines: Array, buttons: Array, color := StationTheme.TEAL) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_sub.text = sub
	_sub.visible = sub != ""
	for c in _lines.get_children():
		c.queue_free()
	for c in _buttons.get_children():
		c.queue_free()
	for l in lines:
		var row := HBoxContainer.new()
		var a := LGUi.label(String(l[0]), "DimLabel")
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(LGUi.label(str(l[1]), ""))
		_lines.add_child(row)
	var first: Button = null
	for b in buttons:
		var btn := LGUi.button(String(b[0]), b[1], 520)
		if b.size() > 2 and b[2]:
			btn.theme_type_variation = "DangerButton"
		_buttons.add_child(btn)
		if first == null:
			first = btn
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if first:
		first.grab_focus.call_deferred()


## The lines showing now (for tests).
func line_texts() -> PackedStringArray:
	var out := PackedStringArray([_title.text])
	for row in _lines.get_children():
		if row.is_queued_for_deletion():
			continue
		var parts := PackedStringArray()
		for l in row.get_children():
			parts.append((l as Label).text)
		out.append(": ".join(parts))
	return out


func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _buttons.get_children():
		if not b.is_queued_for_deletion():
			out.append((b as Button).text)
	return out
