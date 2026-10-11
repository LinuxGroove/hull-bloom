extends Node
## The title screen, over Hydroponics as the Bloom has it: carry on with the
## night shift (the ring map), start a new one (the story so far, then
## Hydroponics), Shift mode once the shift has ended once, the boards, how
## to play, settings, about and quit.

const TITLE_COLOR := Color(0.95, 0.42, 0.36)
## Where the menu's shade ends across the screen (0..1).
const SHADE_RIGHT := 0.5
const STORY := [
	"Marigold grows food for the outer colonies. Three weeks ago a seed sample came back from a survey moon.",
	"Tonight the hydroponics deck stopped answering. By the time you wake for your shift, the corridor outside your bunk is warm and wet underfoot.",
	"MARI, the station's maintenance system, is still running. She can open doors and route power. She has no idea what's happening, only that her sensors keep reporting an organic obstruction.",
	"You're the night shift. Get to Hydroponics.",
]
const WIDTH := 560
## The game's name, on two lines to fit the column.
const NAME := "VERDIGRIS\nPROTOCOL"

var backdrop: MenuBackdrop
var _ui: Control
var _col: VBoxContainer
var _board: LGLeaderboardPanel


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	backdrop = MenuBackdrop.make("hydroponics")
	add_child(backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_ui.add_child(backdrop.fade_rect())
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = SHADE_RIGHT
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	var version := LGUi.label("v%s" % GameConfig.version(), "DimLabel")
	_ui.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_col = LGUi.centered_column(_ui, WIDTH)
	_col.get_parent().anchor_right = SHADE_RIGHT
	LGScreenFit.center(_col)
	Sfx.play_music(["title"], -8.0)
	show_main()


## Dark on the left, fading to clear, so the deck shows on the right.
func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.012, 0.016, 0.94))
	g.set_color(1, Color(0.01, 0.012, 0.016, 0.0))
	g.add_point(0.7, Color(0.01, 0.012, 0.016, 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	t.width = 256
	t.height = 4
	return t


func _clear() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	_board = null


func _heading(text: String) -> void:
	var l := StationTheme.hud_label(text.to_upper(), 34, StationTheme.TEXT)
	_col.add_child(l)


func _text(text: String, dim := false) -> Label:
	var l := LGUi.label(text, "DimLabel" if dim else "")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	_col.add_child(l)
	return l


func _back(to: Callable) -> void:
	_col.add_child(LGUi.button("Back", to, WIDTH))


## The labels of the buttons showing now (for tests).
func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _col.find_children("", "Button", true, false):
		if not b.is_queued_for_deletion() and b.is_visible_in_tree():
			out.append(b.text)
	return out


func show_main() -> void:
	_clear()
	var title := StationTheme.hud_label(NAME, 64, TITLE_COLOR)
	_col.add_child(title)
	_text("Night shift on Marigold Station.", true)
	_col.add_child(Control.new())
	if Progress.has_campaign():
		var where := "Hour %d of the night shift" % (Progress.hour() + 1)
		if Progress.ending() != "":
			where = "The shift is over"
		_col.add_child(LGUi.button("Carry on  ·  " + where, _carry_on, WIDTH))
	_col.add_child(LGUi.button("New night shift", _ask_new, WIDTH))
	var shift := LGUi.button("Shift mode", show_shift, WIDTH)
	_col.add_child(shift)
	_col.add_child(LGUi.button("Leaderboards", show_boards, WIDTH))
	_col.add_child(LGUi.button("How to play", show_how.bind(0), WIDTH))
	_col.add_child(LGUi.button("Settings", show_settings, WIDTH))
	_col.add_child(LGUi.button("About", show_about, WIDTH))
	var quit := LGUi.button("Quit", _quit, WIDTH)
	quit.theme_type_variation = "DangerButton"
	_col.add_child(quit)
	LGUi.focus_first(_col)


func _carry_on() -> void:
	if Progress.deck_state("hydroponics") == "open" and Progress.visits("hydroponics") == 0:
		DeckScene.play("hydroponics", {"mode": "campaign"})
	else:
		LGScenes.change_scene(DeckScene.RING)


func _ask_new() -> void:
	if not Progress.has_campaign() or Progress.ending() != "":
		_new_shift()
		return
	_clear()
	_heading("New night shift")
	_text("This forgets the shift you're on: the decks you saved and lost, what you carry and the workbench's upgrades. The logs you've read are kept.")
	var go := LGUi.button("Start again", _new_shift, WIDTH)
	go.theme_type_variation = "DangerButton"
	_col.add_child(go)
	_back(show_main)
	LGUi.focus_first(_col)


func _new_shift() -> void:
	Progress.new_campaign()
	show_story()


## The story so far, before the first deck.
func show_story() -> void:
	_clear()
	_heading("Marigold Station")
	for p in STORY:
		_text(p)
	_col.add_child(LGUi.button("Go to Hydroponics", _start_campaign, WIDTH))
	LGUi.focus_first(_col)


func _start_campaign() -> void:
	DeckScene.play("hydroponics", {"mode": "campaign"})


func show_shift() -> void:
	_clear()
	_heading("Shift mode")
	if Progress.endings_seen().is_empty() and not ShiftNight.unlocked():
		_text("A new station each time, a few decks and one night to save as many as you can. It opens once you've seen the night shift through to the end.")
		_back(show_main)
		LGUi.focus_first(_col)
		return
	_text("A new station each time: %d decks and one night. Hold as many as you can before the Bloom takes them." % ShiftNight.DECKS)
	var today := ShiftNight.daily_seed()
	var best := Progress.shift_best(today)
	var line := "Tonight's station"
	if int(best["score"]) > 0:
		line += "  ·  best %d" % int(best["score"])
	_col.add_child(LGUi.button(line, ShiftNight.start.bind(today), WIDTH))
	_text("Tonight's station is the same for everyone, and its score goes on the online board.", true)
	_col.add_child(LGUi.button("A random station", _random_shift, WIDTH))
	_back(show_main)
	LGUi.focus_first(_col)


func _random_shift() -> void:
	ShiftNight.start(randi_range(1, 999999))


func show_boards() -> void:
	_clear()
	_heading("Leaderboards")
	if not LGOnline.is_enabled():
		_text("Online play is off in Settings.")
		_back(show_main)
		LGUi.focus_first(_col)
		return
	_board = LGLeaderboardPanel.new()
	_board.setup(GameConfig.GAME_ID, GameConfig.player_name(), ShiftNight.BOARDS)
	_col.add_child(_board)
	_back(show_main)
	LGUi.focus_first(_col)


func show_how(page: int) -> void:
	_clear()
	var pages := HowToPlay.PAGES
	page = clampi(page, 0, pages.size() - 1)
	_heading(pages[page][0])
	for p in pages[page][1]:
		_text(p)
	_text("%d of %d" % [page + 1, pages.size()], true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_col.add_child(row)
	if page > 0:
		row.add_child(LGUi.button("Before", show_how.bind(page - 1), 270))
	if page < pages.size() - 1:
		row.add_child(LGUi.button("Next", show_how.bind(page + 1), 270))
	_back(show_main)
	LGUi.focus_first(_col)


func show_settings() -> void:
	_clear()
	_heading("Settings")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH + 20, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_col.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	inner.add_child(SettingsPanel.new())
	var name_row := HBoxContainer.new()
	var name_label := LGUi.label("Name on the boards")
	name_label.custom_minimum_size.x = 240
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = GameConfig.player_name()
	name_edit.max_length = 20
	name_edit.custom_minimum_size.x = WIDTH - 250
	name_edit.text_changed.connect(_on_name_changed)
	LGUi.gamepad_text_entry(name_edit)
	name_row.add_child(name_edit)
	inner.add_child(name_row)
	var play := PlaySettings.make(WIDTH)
	play.popup_parent = _ui
	inner.add_child(play)
	_back(show_main)
	LGUi.focus_first(_col)


func _on_name_changed(text: String) -> void:
	LGSettings.set_value("player", "name", text.strip_edges())


func show_about() -> void:
	_clear()
	_heading("About Verdigris Protocol")
	_text("A first person horror shooter about a growth that spreads room by room through a research station, and the night tech trying to stop it.")
	_text("Made by the LinuxGroove team with Godot and COGITO, Quaternius' Sci-Fi kits, and Kenney's sounds and fonts.", true)
	_text("Version %s" % GameConfig.version(), true)
	_back(show_main)
	LGUi.focus_first(_col)


func _quit() -> void:
	LGScenes.quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _col.get_child_count() > 0:
		var title := _col.get_child(0) as Label
		if title and title.text != NAME:
			get_viewport().set_input_as_handled()
			show_main()
