extends Node
## The ring map between decks: Marigold's seven decks round the Core, what
## state each is in and how long the open ones have left, and a briefing
## for the one you pick, with the way in. Engineering's spare cells are sent
## from here.

const WIDTH := 440

var backdrop: MenuBackdrop
var ring: RingView
var _ui: Control
var _list: VBoxContainer
var _brief: VBoxContainer
var _status: Label
var _selected := ""
var _buttons := {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	backdrop = MenuBackdrop.make("")
	add_child(backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 28)
	_ui.add_child(root)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	margin.add_child(cols)
	# The list of decks on the left.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = WIDTH
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(StationTheme.hud_label("MARIGOLD STATION", 34))
	_status = StationTheme.hud_label("", 15, StationTheme.DIM)
	left.add_child(_status)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	left.add_child(_list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(LGUi.button("Back to the title", _to_title, WIDTH))
	# The ring and the briefing on the right.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	cols.add_child(right)
	ring = RingView.new()
	ring.custom_minimum_size = Vector2(0, 330)
	ring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ring)
	var panel := StationTheme.hud_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(panel)
	_brief = VBoxContainer.new()
	_brief.add_theme_constant_override("separation", 8)
	panel.add_child(_brief)
	LGScreenFit.fill(root)
	Sfx.play_music(["ring", "title"], -10.0)
	refresh()


## Rebuilds the list and the briefing from Progress.
func refresh() -> void:
	_status.text = "HOUR %d OF THE NIGHT SHIFT  ·  SALVAGE %d" % [Progress.hour() + 1, Progress.salvage()]
	if Progress.spare_cells() > 0:
		_status.text += "  ·  SPARE CELLS %d" % Progress.spare_cells()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_buttons.clear()
	for id in Decks.ids():
		var d := Decks.get_deck(id)
		var b := LGUi.button("%d  ·  %s  ·  %s" % [d.number, d.name, RingView.state_word(id)], _pressed.bind(id), WIDTH)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(select.bind(id))
		b.mouse_entered.connect(select.bind(id))
		b.add_theme_color_override("font_color", RingView.state_color(id))
		_list.add_child(b)
		_buttons[id] = b
	var first := _first_open()
	select(_selected if _selected != "" else first)
	if _buttons.has(_selected):
		_buttons[_selected].grab_focus.call_deferred()


func _first_open() -> String:
	for id in Decks.ids():
		if Progress.deck_state(id) == "open":
			return id
	return Decks.ids()[0]


## Shows a deck's briefing.
func select(id: String) -> void:
	_selected = id
	ring.selected = id
	ring.queue_redraw()
	for c in _brief.get_children():
		_brief.remove_child(c)
		c.queue_free()
	var d := Decks.get_deck(id)
	var head := StationTheme.hud_label("DECK %d  ·  %s" % [d.number, d.name.to_upper()], 24, d.color)
	_brief.add_child(head)
	_line(_state_line(id), RingView.state_color(id))
	_line(d.blurb)
	if not d.news.is_empty():
		var news := PackedStringArray()
		for n in d.news:
			news.append(n[0].to_lower() + n.substr(1) if not n.begins_with("MARI") else n)
		_line("New here: " + ", ".join(news) + ".", StationTheme.DIM)
	if d.gives != "" and Progress.deck_state(id) in ["open", "locked", "lost"]:
		_line(("Take it back: " if Progress.deck_state(id) == "lost" else "Save it: ") + d.gives_text, StationTheme.DIM)
	if Progress.survivors_saved(id) > 0:
		_line("Survivors brought out: %d" % Progress.survivors_saved(id), StationTheme.GREEN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_brief.add_child(row)
	if Progress.can_visit(id):
		var go := LGUi.button(_go_text(id), _go.bind(id), 300)
		row.add_child(go)
	if Progress.deck_state(id) == "open" and Progress.spare_cells() > 0 and not Progress.has_spare_cell(id) and id in Decks.MIDDLE:
		row.add_child(LGUi.button("Send a spare cell", _send_cell.bind(id), 300))


func _line(text: String, color := StationTheme.TEXT) -> void:
	var l := LGUi.label(text)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	_brief.add_child(l)


func _state_line(id: String) -> String:
	match Progress.deck_state(id):
		"open":
			if Progress.hours_left(id) <= 0:
				return "Open. It won't be lost while you're away."
			var h := Progress.hours_left(id)
			var cell := " A spare cell keeps its lights on." if Progress.has_spare_cell(id) else ""
			return ("Open. %d hour before the Bloom takes it." % h if h == 1 else "Open. %d hours before the Bloom takes it." % h) + cell
		"saved":
			return "Saved. Its workbench and bunk are yours, and going back costs no time."
		"lost":
			return "Lost to the Bloom. It's overgrown now, but it can be taken back."
		"reclaimed":
			return "Taken back from the Bloom."
	if id == "core":
		return "Locked. Every feed on Marigold leads here. It opens once every deck on the ring is saved or lost."
	return "Locked. The ring's lifts open once Hydroponics is held."


func _go_text(id: String) -> String:
	match Progress.deck_state(id):
		"saved", "reclaimed":
			return "Visit the deck"
		"lost":
			return "Take it back"
	return "Go to " + Decks.get_deck(id).name


func _pressed(id: String) -> void:
	select(id)
	var b := LGUi.first_focusable(_brief)
	if b:
		b.grab_focus()


func _go(id: String) -> void:
	LGPlaytest.event("deck_picked", {"deck": id, "hours": Progress.hours_left(id), "state": Progress.deck_state(id)})
	DeckScene.play(id, {"mode": "campaign"})


func _send_cell(id: String) -> void:
	if Progress.assign_cell(id):
		Sfx.ui(self, "power_on")
		refresh()


## The labels of the buttons showing now (for tests).
func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _ui.find_children("", "Button", true, false):
		if not b.is_queued_for_deletion():
			out.append(b.text)
	return out


func briefing_text() -> String:
	var out := PackedStringArray()
	for c in _brief.get_children():
		if c is Label and not c.is_queued_for_deletion():
			out.append(c.text)
	return "\n".join(out)


func _to_title() -> void:
	LGScenes.change_scene(DeckScene.TITLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		var f := get_viewport().gui_get_focus_owner()
		if f and _brief.is_ancestor_of(f) and _buttons.has(_selected):
			_buttons[_selected].grab_focus()
		else:
			_to_title()
