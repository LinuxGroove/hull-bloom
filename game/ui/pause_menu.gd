class_name BloomPause
extends Control
## The pause menu on a deck. Cogito's player opens it with the menu button
## and listens for `resume`, so it keeps the names of Cogito's pause menu.

signal resume
signal leave_deck
signal quit_to_title

var _col: VBoxContainer
var _panel: PanelContainer
var _settings: PlaySettings
var _leave: Button


func _init() -> void:
	name = "PauseMenu"
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
	_panel = PanelContainer.new()
	center.add_child(_panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 10)
	_panel.add_child(_col)
	_col.add_child(LGUi.label("Paused", "HeaderMedium"))
	_col.add_child(LGUi.button("Carry on", close_pause_menu, 500))
	_col.add_child(LGPlaytestButton.make(500))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_col.add_child(scroll)
	_settings = PlaySettings.make(500)
	_settings.popup_parent = self
	scroll.add_child(_settings)
	_leave = LGUi.button("Leave the deck", _leave_deck, 500)
	_leave.theme_type_variation = "DangerButton"
	_col.add_child(_leave)
	_col.add_child(LGUi.button("Back to the title", _quit, 500))


func _ready() -> void:
	LGScreenFit.center(_panel)


## What the leave button says ("Back to the ring", "Give up the night").
func set_leave_text(text: String) -> void:
	_leave.text = text


func open_pause_menu() -> void:
	# Cogito opens this from the player's _input; without this the same press
	# reaches _unhandled_input below and closes the menu straight away.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	_settings.rebuild()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	LGUi.focus_first(_col)


func close_pause_menu() -> void:
	var was_open := visible
	visible = false
	if is_inside_tree():
		get_tree().paused = false
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f:
		f.release_focus()
	if was_open:
		resume.emit()


func _leave_deck() -> void:
	close_pause_menu()
	leave_deck.emit()


func _quit() -> void:
	visible = false
	get_tree().paused = false
	quit_to_title.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		get_viewport().set_input_as_handled()
		close_pause_menu()
