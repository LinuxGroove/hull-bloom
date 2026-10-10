class_name DeckMapPanel
extends Control
## The deck map: MARI's view of the whole deck with the rooms named, and the
## power board beside it, where each room's lights take a cell. Sealed doors,
## turrets and the lift show what they're using; they're switched where
## they stand. The game waits while it's open.

signal closed

var scene: Node
var level: DeckLevel
var power: Power
var run: DeckRun
var _map: MapView
var _cells: Label
var _rooms: VBoxContainer
var _others: Label
var _objectives: Label
var _panel: PanelContainer
var _buttons := {}


func _init() -> void:
	name = "DeckMap"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var head := HBoxContainer.new()
	left.add_child(head)
	var title := LGUi.label("Deck map", "HeaderMedium")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(ActionPrompt.make("deck_map", "Close", 32))
	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(map_panel)
	_map = MapView.new()
	_map.show_names = true
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(_map)
	_objectives = LGUi.label("", "")
	_objectives.add_theme_font_size_override("font_size", 18)
	left.add_child(_objectives)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(430, 0)
	row.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	col.add_child(LGUi.label("Power", "HeaderMedium"))
	_cells = LGUi.label("", "")
	_cells.add_theme_color_override("font_color", StationTheme.AMBER)
	col.add_child(_cells)
	var hint := LGUi.label("Pick a room to switch its lights on or off. Lit rooms grow at half speed. Lights, sealed doors, turrets and the lift share the cells.", "DimLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	col.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	_rooms = VBoxContainer.new()
	_rooms.add_theme_constant_override("separation", 6)
	scroll.add_child(_rooms)
	_others = LGUi.label("", "DimLabel")
	_others.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_others.custom_minimum_size = Vector2(400, 0)
	col.add_child(_others)


func setup(p_scene: Node, p_level: DeckLevel, p_power: Power, p_run: DeckRun, player: Node3D) -> void:
	scene = p_scene
	level = p_level
	power = p_power
	run = p_run
	_map.level = level
	_map.show_all_survivors = p_scene.mode == "campaign" and Progress.has_gift("survivors")
	_map.player = player
	for id in level.room_ids:
		if level.rooms[id]["dark"]:
			continue
		var b := LGUi.button("", _toggle.bind(id), 400)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(_on_room_focus.bind(id))
		_rooms.add_child(b)
		_buttons[id] = b
	power.changed.connect(_refresh)


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()
	LGUi.focus_first(_rooms)


func close() -> void:
	if not visible:
		return
	visible = false
	_map.picked = ""
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()
	closed.emit()


func _toggle(id: String) -> void:
	scene.toggle_lights(id)
	_refresh()


func _on_room_focus(id: String) -> void:
	_map.picked = id


func _refresh() -> void:
	if power == null:
		return
	_cells.text = "%d CELLS · %d IN USE · %d FREE" % [power.cells, power.used(), power.free_cells()]
	for id in _buttons:
		var on := power.has("lights:" + id)
		var lvl := level.bloom.room_level(id)
		var state := "LIGHTS ON" if on else "LIGHTS OFF"
		if level.bloom.airless[level.bloom.room_names.find(id)] == 1:
			state = "AIRLESS"
		var growth := "" if lvl < 0.5 else ("   BLOOM %d" % ceili(lvl))
		(_buttons[id] as Button).text = "%s   %s%s" % [level.room_name(id), state, growth]
	var parts := PackedStringArray()
	parts.append("Sealed doors: %d (unseal them at their panels)" % power.count("door"))
	parts.append("Turrets: %d" % power.count("turret"))
	parts.append("Lift: %s" % ("powered" if power.has("lift") else "needs a cell to leave"))
	_others.text = "\n".join(parts)
	if run:
		var lines := PackedStringArray()
		for o in run.objectives(level.bloom):
			lines.append(("✓ " if o[1] else "• ") + String(o[0]))
		_objectives.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("deck_map") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("power_map"):
		get_viewport().set_input_as_handled()
		close()
