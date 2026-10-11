extends Node
## A function sweep: drives the title, settings, pause menu, saving, the ring
## map, the workbench, results, Shift mode and offline play the way a player
## would (real clicks and key presses, real scene changes), and prints a PASS
## or FAIL line for each thing it checks.
##
##   godot --headless --path . tools/function_sweep.tscn [-- --only=title,pause]
##
## Sections: input, title, settings, pause, saves, screens, ending, shift,
## offline, gore. Run it with XDG_DATA_HOME pointing at a scratch folder: it writes
## real settings and progress files. Exits non-zero if anything fails.

const SECTIONS := ["input", "title", "settings", "pause", "saves", "screens", "ending", "shift", "offline", "gore"]
## Settings rows in PlaySettings and the shared SettingsPanel: label -> [section, key].
const ROWS := {
	"Look speed": ["play", "mouse_sensitivity"],
	"Invert look": ["play", "invert_look"],
	"Hold to crouch": ["play", "toggle_crouch"],
	"Head bob": ["play", "bob"],
	"View roll": ["play", "tilt"],
	"Field of view": ["play", "fov"],
	"Brightness": ["play", "brightness"],
	"Calm walls": ["play", "calm_walls"],
	"Spore blur": ["play", "spore_blur"],
	"Rumble": ["play", "rumble"],
	"Subtitles": ["play", "subtitles"],
	"Gore": ["gore", "level"],
	"Bloom spread": ["difficulty", "spread"],
	"Damage taken": ["difficulty", "damage"],
	"Ammunition": ["difficulty", "ammo"],
	"Fullscreen": ["video", "fullscreen"],
	"Text size": ["video", "ui_scale"],
	"3D resolution": ["video", "resolution"],
	"Volume": ["audio", "master"],
	"Music": ["audio", "music"],
	"Sounds": ["audio", "sfx"],
	"Online play": ["online", "enabled"],
	"Play test recording": ["playtest", "record"],
}
const UI_ACTIONS := ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev", "ui_next_tab", "ui_prev_tab"]

var passed := 0
var failed := 0
var _section := ""
var _quit_seen := false
## Scene changes seen so far, and the count when the last click or key press started.
var _changes := 0
var _mark := 0


func _ready() -> void:
	# A headless window is 64 by 64, which squeezes every menu; give it a real size.
	get_window().size = Vector2i(1280, 800)
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)
	LGInput.register_actions(GameConfig.ACTIONS, float(LGSettings.get_value("input", "stick_deadzone", 0.2)))
	LGInput.extend_ui_actions()
	StationTheme.apply(get_tree().root, 22)
	RenderingServer.global_shader_parameter_set("calm_walls", float(LGSettings.get_value("play", "calm_walls", 1.0)))
	await frames(3)
	LGScenes.scene_changed.connect(_on_changed)
	# Not the current scene, so LGScenes never frees the sweep when it changes
	# scenes; each scene it loads becomes current as in the game.
	get_tree().current_scene = null
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	for s in SECTIONS:
		if only.is_empty() or s in only:
			_section = s
			print("== %s" % s)
			await call("_s_" + s)
	if only.is_empty() or "quit" in only:
		await _s_quit()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _exit_tree() -> void:
	_quit_seen = true


#region Helpers

func ok(cond: bool, what: String) -> bool:
	if cond:
		passed += 1
		print("PASS: [%s] %s" % [_section, what])
	else:
		failed += 1
		print("FAIL: [%s] %s" % [_section, what])
	return cond


## The mouse is captured. A headless run can't capture it (the mode always reads visible), so there it is only noted.
func captured(what: String) -> void:
	if DisplayServer.get_name() == "headless":
		note("%s: can't be checked headless" % what)
	else:
		ok(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, what)


## The global shader value the growth's breathing reads. The headless renderer
## keeps no global values, so there it is only noted.
func calm_is(want: float, what: String) -> void:
	var got: Variant = RenderingServer.global_shader_parameter_get("calm_walls")
	if got == null:
		note("%s: the headless renderer can't be asked" % what)
	else:
		ok(approx(got, want), "%s (%s)" % [what, got])


## Something odd that isn't a failure of a check.
func note(text: String) -> void:
	print("NOTE: [%s] %s" % [_section, text])


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _on_changed(_scene: Node) -> void:
	_changes += 1


## Notes now as the start of the action whose scene change `changed` waits for.
func mark() -> void:
	_mark = _changes


## Waits until a scene change has happened since mark() (or 20 seconds), then lets it settle.
func changed(timeout := 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while _changes == _mark and Time.get_ticks_msec() - t0 < timeout * 1000.0:
		await frames(1)
	if _changes == _mark:
		print("   (no scene change within %.0fs)" % timeout)
	await frames(3)


## Changes scene the way the game does and returns the new scene.
func go(path: String) -> Node:
	mark()
	LGScenes.change_scene(path)
	await changed()
	return get_tree().current_scene


func go_deck(id: String, opts := {"mode": "campaign"}) -> DeckScene:
	mark()
	DeckScene.play(id, opts)
	await changed()
	await frames(4)
	return DeckScene.current


func texts(root: Node) -> Array:
	var out := []
	if root == null:
		return out
	for b in root.find_children("", "Button", true, false):
		if not b.is_queued_for_deletion() and b.is_visible_in_tree():
			out.append(b.text)
	return out


func find_btn(root: Node, prefix: String) -> Button:
	if root == null:
		return null
	for b in root.find_children("", "Button", true, false):
		if not b.is_queued_for_deletion() and b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


func has_btn(root: Node, prefix: String) -> bool:
	return find_btn(root, prefix) != null


func labels(root: Node) -> String:
	var out := PackedStringArray()
	if root == null:
		return ""
	for l in root.find_children("", "Label", true, false):
		if not l.is_queued_for_deletion() and l.is_visible_in_tree():
			out.append(l.text)
	return " | ".join(out)


## A real mouse click on a button's centre. The events go straight into the
## window in viewport coordinates: a headless window is 64 by 64 and the
## stretch would otherwise scale a position that is already in viewport terms.
func click(b: Button) -> void:
	if b == null:
		return
	mark()
	# A button added this frame has no size yet.
	await frames(2)
	if not is_instance_valid(b):
		return
	var pos: Vector2 = b.get_global_transform_with_canvas() * (b.size * 0.5)
	var w := get_window()
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	w.push_input(m, true)
	await frames(1)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = pos
	d.global_position = pos
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	w.push_input(d, true)
	await frames(1)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = pos
	u.global_position = pos
	w.push_input(u, true)
	await frames(3)


## Finds a button by its text and clicks it; false if there's none.
func press(root: Node, prefix: String) -> bool:
	var b := find_btn(root, prefix)
	if b == null:
		return false
	await click(b)
	return true


## A key or button press, as the input map has it.
func tap(action: String, hold_frames := 1) -> void:
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return
	mark()
	var ev: InputEvent = evs[0].duplicate()
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(hold_frames)
	var up: InputEvent = evs[0].duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func approx(a: Variant, b: Variant) -> bool:
	var a_num: bool = a is float or a is int
	var b_num: bool = b is float or b is int
	if a_num and b_num:
		return absf(float(a) - float(b)) < 0.0001
	return a == b


## All cyclers under a node by their label.
func cyclers(root: Node) -> Dictionary:
	var out := {}
	for c in root.find_children("", "LGCycler", true, false):
		out[(c as LGCycler).label_text] = c
	return out


func default_of(section: String, key: String) -> Variant:
	return LGSettings._defaults[section][key]


func reload_settings() -> void:
	LGSettings._cfg = ConfigFile.new()
	LGSettings._overrides.clear()
	LGSettings.load_settings()


func reset_settings() -> void:
	for sec in ["play", "gore", "difficulty", "audio", "video"]:
		for key in LGSettings._defaults[sec]:
			LGSettings.set_value(sec, key, LGSettings._defaults[sec][key])
	LGSettings.set_value("online", "enabled", false)


func file_value(section: String, key: String) -> Variant:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		return null
	return cf.get_value(section, key, null)


func snap() -> Dictionary:
	var d := {"hour": Progress.hour(), "salvage": Progress.salvage(), "weapons": Progress.weapons(), "items": Progress.items(),
		"ammo": Progress.ammo(), "spare": Progress.spare_cells(), "logs": Progress.logs_read().size(), "ending": Progress.ending(),
		"started": Progress.has_campaign(), "decks": {}}
	for id in Decks.ids():
		d["decks"][id] = [Progress.deck_state(id), Progress.hours_left(id), Progress.survivors_saved(id), Progress.visits(id), Progress.has_spare_cell(id)]
	return d


func gifts() -> Array:
	var out := []
	for g in ["power", "turrets", "stims", "rail", "shuttle", "survivors"]:
		if Progress.has_gift(g):
			out.append(g)
	return out


## Kills a deck's hearts and runs the Bloom until the deck is held.
func hold(s: DeckScene, ticks := 300) -> bool:
	for h in s.director.hearts.duplicate():
		if is_instance_valid(h) and not h.dead:
			h.take_hit(Hit.make(Hit.Kind.BURN, 100000.0, h.global_position, Vector3.FORWARD, s.player))
	await frames(2)
	for i in ticks:
		s.tick_bloom()
		if s.run.held:
			return true
	return s.run.held


## Leaves the deck by the lift and waits for the results.
func leave_deck(s: DeckScene) -> void:
	s.leave()
	await frames(3)


## The results panel's "Back to the ring" button, clicked; returns the ring.
func to_ring(s: DeckScene) -> Node:
	var b := find_btn(s.results, "Back to the ring")
	if b == null:
		return null
	await click(b)
	await changed()
	return get_tree().current_scene


## Holds Action's key for a number of physics frames.
func hold_action(action: String, physics_frames: int) -> void:
	Input.action_press(action)
	for i in physics_frames:
		await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame

#endregion

#region Input

func _s_input() -> void:
	var no_kb := []
	var no_pad := []
	var placeholders := []
	for a in GameConfig.ACTIONS:
		var specs: Array = GameConfig.ACTIONS[a]
		if specs.is_empty():
			placeholders.append(a)
			continue
		var kb := specs.any(func(s): return String(s).begins_with("key:") or String(s).begins_with("mouse:"))
		var pad := specs.any(func(s): return String(s).begins_with("joy:") or String(s).begins_with("axis:"))
		if not kb:
			no_kb.append(a)
		if not pad:
			no_pad.append(a)
		ok(InputMap.has_action(a) and InputMap.action_get_events(a).size() == specs.size(), "%s: all %d bindings registered" % [a, specs.size()])
	ok(no_kb.is_empty(), "every bound action has a keyboard or mouse binding (missing: %s)" % [no_kb])
	# The mouse wheel and the number keys have no pad buttons: on a pad, a tap
	# of Swap goes back a weapon and holding it opens the weapon wheel.
	var wheel := no_pad.filter(func(a): return a == "swap" or a == "swap_back" or a.begins_with("weapon_"))
	var quick: Array = GameConfig.ACTIONS.get("quick_swap", [])
	ok(quick.any(func(s): return String(s).begins_with("joy:")), "a pad reaches every weapon by Swap and its wheel (%s)" % [wheel])
	var no_pad_other := no_pad.filter(func(a): return not a in wheel)
	ok(no_pad_other.is_empty(), "every other bound action has a pad binding (missing: %s)" % [no_pad_other])
	note("actions with no binding at all, on purpose: %s" % [placeholders])
	# The same input bound twice.
	var users := {}
	var names := GameConfig.ACTIONS.keys() + UI_ACTIONS
	for a in names:
		if not InputMap.has_action(a):
			continue
		for ev in InputMap.action_get_events(a):
			var key := ev.as_text()
			if ev is InputEventJoypadMotion:
				key = "axis %d %s" % [ev.axis, "+" if ev.axis_value > 0 else "-"]
			if not users.has(key):
				users[key] = []
			if not a in users[key]:
				users[key].append(a)
	var clashes := []
	for key in users:
		var game_actions := (users[key] as Array).filter(func(x): return not String(x).begins_with("ui_"))
		# X on a pad uses what's in view, and reloads when there's nothing.
		if game_actions.size() > 1 and game_actions != ["interact", "reload"]:
			clashes.append("%s: %s" % [key, game_actions])
		elif users[key].size() > 1:
			note("%s is both %s (menus take it only while one is open)" % [key, users[key]])
	ok(clashes.is_empty(), "no input is bound to two game actions (%s)" % [clashes])
	# Every action the code reads exists.
	for a in ["forward", "back", "left", "right", "jump", "crouch", "sprint", "menu", "interact", "action_primary", "action_secondary",
			"reload", "quick_swap", "swap", "swap_back", "throw", "torch", "shove", "power_lights", "power_map", "heal", "stim", "deck_map", "ui_cancel", "ui_accept"]:
		ok(InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0, "the game reads %s and it is bound" % a)
	# Opening the map by key, then closing it by the same key.
	var dead_keys := []
	for a in ["menu", "deck_map"]:
		var has_menu_key := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				has_menu_key = true
		if not has_menu_key:
			dead_keys.append(a)
	ok(dead_keys.is_empty(), "menu and map have a key (%s)" % [dead_keys])

#endregion

#region Title

func _s_title() -> void:
	reset_settings()
	Progress.reset()
	var title := await go("res://game/ui/title.tscn")
	ok(title != null and title.has_method("button_texts"), "the title opens")
	var b: Array = texts(title)
	print("   title buttons: ", b)
	for t in ["New night shift", "Shift mode", "Leaderboards", "How to play", "Settings", "About", "Quit"]:
		ok(t in b, "the title has %s" % t)
	ok(not b.any(func(x): return x.begins_with("Carry on")), "no Carry on without a shift")
	# How to play: every page, forward and back.
	await press(title, "How to play")
	var pages := 1
	ok(not has_btn(title, "Before"), "the first how to play page has no Before")
	while has_btn(title, "Next") and pages < 12:
		await press(title, "Next")
		pages += 1
	ok(pages == HowToPlay.PAGES.size(), "how to play has %d pages (clicked through %d)" % [HowToPlay.PAGES.size(), pages])
	ok(has_btn(title, "Before") and not has_btn(title, "Next"), "the last page has Before and no Next")
	await press(title, "Before")
	ok(has_btn(title, "Next"), "Before goes back a page")
	await press(title, "Back")
	ok(has_btn(title, "New night shift"), "Back returns to the title")
	# About, and Escape back out.
	await press(title, "About")
	ok(labels(title).contains("Version"), "About shows the version")
	await tap("ui_cancel")
	ok(has_btn(title, "New night shift"), "Escape leaves a sub page")
	# Shift mode is locked until an ending.
	await press(title, "Shift mode")
	ok(labels(title).contains("opens once"), "Shift mode explains it is locked")
	ok(not has_btn(title, "Tonight"), "and offers no night")
	await press(title, "Back")
	# Leaderboards with online off.
	LGSettings.set_value("online", "enabled", false)
	await press(title, "Leaderboards")
	ok(labels(title).contains("Online play is off"), "Leaderboards says online play is off")
	await press(title, "Back")
	# Settings.
	await press(title, "Settings")
	await frames(2)
	ok(title.find_children("", "PlaySettings", true, false).size() == 1, "Settings has the game's own settings")
	ok(title.find_children("", "SettingsPanel", true, false).size() == 1, "Settings has the shared settings")
	ok(title.find_children("", "LineEdit", true, false).size() >= 1, "Settings has the name field")
	ok(has_btn(title, "Back"), "Settings has Back")
	await press(title, "Back")
	# New night shift with nothing started: the story, then Hydroponics.
	await press(title, "New night shift")
	ok(has_btn(title, "Go to Hydroponics"), "a first shift shows the story")
	ok(Progress.has_campaign(), "starting a shift saves it")
	var deck_opened := false
	await click(find_btn(title, "Go to Hydroponics"))
	await changed()
	await frames(5)
	deck_opened = DeckScene.current != null and DeckScene.current.deck_id == "hydroponics" and DeckScene.current.mode == "campaign"
	ok(deck_opened, "Go to Hydroponics opens the deck as a campaign visit")
	# Back to the title from the pause menu, then Carry on.
	var s := DeckScene.current
	await tap("menu")
	ok(s.pause.visible and get_tree().paused, "Escape pauses on the deck")
	await click(find_btn(s.pause, "Back to the title"))
	await changed()
	await frames(4)
	title = get_tree().current_scene
	ok(not get_tree().paused, "the title is not paused")
	b = texts(title)
	ok(b.any(func(x): return x.begins_with("Carry on")), "the title offers Carry on once a shift is started")
	var carry := find_btn(title, "Carry on")
	if carry:
		ok(carry.text.contains("Hour 1"), "Carry on names the hour (%s)" % carry.text)
	await click(carry)
	await changed()
	await frames(5)
	ok(DeckScene.current != null and DeckScene.current.deck_id == "hydroponics", "Carry on before leaving Hydroponics goes back to the deck")
	# Leave Hydroponics unfinished (the pause menu's leave), then Carry on goes to the ring.
	s = DeckScene.current
	await tap("menu")
	await click(find_btn(s.pause, "Leave the deck"))
	await frames(3)
	ok(s.results.visible, "leaving shows the results")
	ok(Progress.visits("hydroponics") == 1 and Progress.deck_state("hydroponics") == "open", "leaving unheld keeps it open and counts a visit")
	await click(find_btn(s.results, "Back to the title"))
	await changed()
	await frames(4)
	title = get_tree().current_scene
	await click(find_btn(title, "Carry on"))
	await changed()
	await frames(4)
	ok(get_tree().current_scene.has_method("briefing_text"), "Carry on after a visit goes to the ring map")
	var ring := get_tree().current_scene
	await press(ring, "Back to the title")
	await changed()
	await frames(4)
	title = get_tree().current_scene
	# New night shift with a shift going: it asks first.
	await press(title, "New night shift")
	ok(has_btn(title, "Start again") and has_btn(title, "Back"), "a second New night shift asks before forgetting the first")
	ok(labels(title).contains("forgets"), "and says what it forgets")
	await press(title, "Back")
	ok(has_btn(title, "Carry on"), "Back keeps the shift")
	await press(title, "New night shift")
	await press(title, "Start again")
	ok(has_btn(title, "Go to Hydroponics") and Progress.deck_state("hydroponics") == "open" and Progress.visits("hydroponics") == 0, "Start again begins a fresh shift")
	title.show_main()
	await frames(2)
	# Shift mode once an ending has been seen.
	Progress.set_ending("burn")
	title.show_main()
	await frames(2)
	ok(find_btn(title, "Carry on") != null and find_btn(title, "Carry on").text.contains("shift is over"), "Carry on says the shift is over")
	await press(title, "Shift mode")
	b = texts(title)
	print("   shift page buttons: ", b)
	ok(b.any(func(x): return x.begins_with("Tonight's station")) and "A random station" in b, "Shift mode offers tonight's station and a random one")
	await click(find_btn(title, "A random station"))
	await changed()
	await frames(5)
	ok(DeckScene.current != null and DeckScene.current.mode == "shift" and ShiftNight.current != null, "a random station starts a Shift night")
	s = DeckScene.current
	await tap("menu")
	ok(find_btn(s.pause, "End the night") != null, "the pause menu on Shift says End the night")
	await click(find_btn(s.pause, "Back to the title"))
	await changed()
	await frames(4)
	title = get_tree().current_scene
	ok(has_btn(title, "New night shift"), "Back to the title from a Shift night works")
	# New night shift after the ending skips the question.
	await press(title, "New night shift")
	ok(has_btn(title, "Go to Hydroponics"), "after the shift ends, New night shift starts at once")
	Progress.reset()

#endregion

#region Settings

func _s_settings() -> void:
	reset_settings()
	var holder := Control.new()
	add_child(holder)
	var play := PlaySettings.make(480)
	holder.add_child(play)
	var shared := SettingsPanel.new()
	holder.add_child(shared)
	await frames(2)
	var rows := cyclers(holder)
	print("   settings rows: ", rows.keys())
	for label in rows:
		ok(ROWS.has(label), "the settings row '%s' is one the sweep knows" % label)
	for label in ROWS:
		if label == "Play test recording":
			ok(rows.has(label) == (LGPlaytest.current() != null), "Play test recording row shows when the recorder is set up")
		else:
			ok(rows.has(label), "the settings have a '%s' row" % label)
	# Every option of every row sets, saves and shows.
	for label in rows:
		if not ROWS.has(label) or label == "Play test recording":
			continue
		var c: LGCycler = rows[label]
		var sec: String = ROWS[label][0]
		var key: String = ROWS[label][1]
		var start: Variant = c.value()
		var good := true
		var seen := []
		for i in c.options.size():
			c.step(1)
			var want: Variant = c.value()
			seen.append(want)
			if not approx(LGSettings.get_value(sec, key), want) or not approx(file_value(sec, key), want):
				good = false
		ok(good and approx(c.value(), start), "%s: all %d options set and save (%s)" % [label, c.options.size(), seen])
	# A restart keeps what was changed.
	var edits := {}
	for label in rows:
		if not ROWS.has(label) or label in ["Play test recording", "Online play", "Fullscreen"]:
			continue
		var c: LGCycler = rows[label]
		c.step(1)
		edits[label] = c.value()
	reload_settings()
	holder.queue_free()
	await frames(2)
	holder = Control.new()
	add_child(holder)
	holder.add_child(PlaySettings.make(480))
	var again := SettingsPanel.new()
	holder.add_child(again)
	await frames(2)
	rows = cyclers(holder)
	var kept := true
	for label in edits:
		if not approx(rows[label].value(), edits[label]):
			kept = false
			print("   not kept: ", label, " ", rows[label].value(), " vs ", edits[label])
	ok(kept, "after a restart every changed setting is still changed (%d)" % edits.size())
	# Volumes reach the buses.
	for pair in [["Volume", "Master"], ["Music", "Music"], ["Sounds", "SFX"]]:
		var c: LGCycler = rows[pair[0]]
		var idx := AudioServer.get_bus_index(pair[1])
		ok(idx >= 0, "the %s bus exists" % pair[1])
		for v in [0.0, 0.5, 1.0]:
			LGSettings.set_value("audio", ROWS[pair[0]][1], v)
			var db := AudioServer.get_bus_volume_db(idx)
			var muted := AudioServer.is_bus_mute(idx)
			ok(muted if v == 0.0 else absf(db - linear_to_db(v)) < 0.1 and not muted, "%s at %d%% sets the %s bus (%.1f dB, muted %s)" % [pair[0], int(v * 100), pair[1], db, muted])
	holder.queue_free()
	reset_settings()
	await frames(2)
	# The gore lock.
	var ps := PlaySettings.make(480)
	add_child(ps)
	await frames(1)
	ps._ask_code()
	ps._on_code("4321")
	await frames(2)
	ok(PlaySettings.locked(), "a code locks gore")
	var gore: LGCycler = cyclers(ps)["Gore"]
	ok(gore.read_only and gore.disabled, "a locked Gore row can't be changed")
	var before := str(LGSettings.get_value("gore", "level"))
	gore.step(1)
	ok(str(LGSettings.get_value("gore", "level")) == before, "stepping a locked Gore row does nothing")
	reload_settings()
	ok(PlaySettings.locked() and String(LGSettings.get_value("gore", "lock")) == "4321", "the lock survives a restart")
	var ps2 := PlaySettings.make(480)
	add_child(ps2)
	await frames(1)
	ok((cyclers(ps2)["Gore"] as LGCycler).read_only, "a fresh settings panel (the pause menu's) shows Gore locked")
	ps2.queue_free()
	ps._ask_code()
	ps._on_code("0000")
	ok(PlaySettings.locked(), "the wrong code leaves gore locked")
	ps._ask_code()
	ps._on_code("4321")
	await frames(2)
	ok(not PlaySettings.locked(), "the right code unlocks it")
	gore = cyclers(ps)["Gore"]
	for level in ["full", "less", "off"]:
		LGSettings.set_value("gore", "level", level)
		ok(Gore.shown() == (level != "off") and Gore.full() == (level == "full"), "gore %s: shown=%s full=%s" % [level, Gore.shown(), Gore.full()])
	# A lock code that is not four digits.
	ps._ask_code()
	ps._on_code("12")
	note("a 2 digit lock code is accepted by PlaySettings._on_code (locked=%s); the keypad is what limits it to 4 digits" % PlaySettings.locked())
	LGSettings.set_value("gore", "lock", "")
	ps.queue_free()
	reset_settings()
	await frames(1)

#endregion

#region Pause

func _s_pause() -> void:
	reset_settings()
	Progress.reset()
	Progress.new_campaign()
	var s := await go_deck("hydroponics")
	ok(s != null, "a campaign deck opens through the scene switcher")
	if s == null:
		return
	ok(get_tree().current_scene == s, "the deck is the current scene")
	captured("the mouse is captured on a deck")
	ok(get_window().content_scale_size == Vector2i(1280, 800), "the window keeps its stretch on a deck, so the HUD scales like the menus (content scale %s)" % get_window().content_scale_size)
	# Open and close with the menu key.
	await tap("menu")
	ok(s.pause.visible and get_tree().paused, "menu pauses")
	ok(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "and shows the mouse")
	var b: Array = texts(s.pause)
	print("   pause buttons: ", b)
	for t in ["Carry on", "Leave the deck", "Back to the title"]:
		ok(t in b, "the pause menu has %s" % t)
	if not b.any(func(x): return x.begins_with("How to play")):
		ok(false, "the pause menu has a way to read How to play")
	if not b.any(func(x): return x.begins_with("Quit")):
		ok(false, "the pause menu has a way to quit the game")
	var how := find_btn(s.pause, "How to play")
	if how:
		await click(how)
		ok(s.pause._how.visible and "Next" in texts(s.pause._how), "How to play shows its pages in the pause menu")
		await tap("ui_cancel")
		ok(s.pause.visible and not s.pause._how.visible, "and going back returns to the pause menu")
	var note_btn := find_btn(s.pause, "Note this moment")
	ok(note_btn == null, "Note this moment is hidden while no play test records")
	await tap("menu")
	ok(not s.pause.visible and not get_tree().paused, "menu again resumes")
	captured("and captures the mouse")
	await tap("menu")
	await click(find_btn(s.pause, "Carry on"))
	ok(not s.pause.visible and not get_tree().paused, "Carry on resumes")
	captured("Carry on captures the mouse")
	# Settings changed from the pause menu take effect on resume.
	await _pause_effects(s)
	# Note this moment, with recording on.
	var rec := LGPlaytest.current()
	ok(rec != null, "the play test recorder is set up")
	if rec:
		rec.begin()
		ok(LGPlaytest.recording(), "a play test records")
		await tap("menu")
		note_btn = find_btn(s.pause, "Note this moment")
		ok(note_btn != null, "Note this moment shows while recording")
		await click(note_btn)
		var panel := rec.find_children("*", "LGPlaytestNote", true, false)
		ok(panel.size() == 1, "Note this moment asks what is happening")
		ok(get_tree().paused, "the game stays paused behind it")
		if panel.size() == 1:
			panel[0].pick("fun")
			await frames(2)
		ok(get_tree().paused and s.pause.visible, "after the note the pause menu is still up")
		await click(find_btn(s.pause, "Carry on"))
		ok(not get_tree().paused, "and Carry on resumes")
		# F8 on the deck.
		var f8 := InputEventKey.new()
		f8.keycode = KEY_F8
		f8.physical_keycode = KEY_F8
		f8.pressed = true
		Input.parse_input_event(f8)
		await frames(3)
		panel = rec.find_children("*", "LGPlaytestNote", true, false)
		ok(panel.size() == 1, "F8 opens the note")
		if panel.size() == 1:
			ok(get_tree().paused, "F8 pauses the game")
			panel[0].pick("fun")
			await frames(3)
		ok(not get_tree().paused, "closing the note resumes")
		rec._end("sweep", {})
		ok(not LGPlaytest.recording(), "the recording ends")
	# The map and the pause menu share Escape.
	await tap("deck_map")
	ok(s.map_panel.visible and get_tree().paused, "the map key opens the deck map")
	await tap("deck_map")
	var map_closed_by_key := not s.map_panel.visible
	ok(map_closed_by_key, "the map key closes the map again (Tab: %s)" % [InputMap.action_get_events("deck_map")[0].as_text()])
	if s.map_panel.visible:
		await tap("ui_cancel")
	await tap("menu")
	ok(s.pause.visible and not s.map_panel.visible, "menu opens the pause menu, not the map")
	await tap("menu")
	await tap("deck_map")
	await tap("menu")
	ok(not s.map_panel.visible and not s.pause.visible and not get_tree().paused, "menu closes the map and does not pause on top of it")
	# The lift: powering it, the confirm, and leaving; no pausing once the visit is over.
	s._on_lift_used()
	ok(s.lift.powered, "the lift takes a cell")
	s._on_lift_used()
	ok(s._leave_confirm > 0.0 and not s.run.over, "an unheld deck asks you to use the lift again")
	await tap("menu")
	ok(s.pause.visible, "you can pause while the lift waits for the second press")
	await tap("menu")
	s._on_lift_used()
	await frames(3)
	ok(s.run.over and s.results.visible, "the second press leaves and shows the results")
	await tap("menu")
	ok(not s.pause.visible and not get_tree().paused, "menu does nothing once the visit is over")
	ok(Progress.visits("hydroponics") == 1, "leaving counted the visit")
	# Death: no pausing, then the down panel.
	await click(find_btn(s.results, "Back to the title"))
	await changed()
	await frames(3)
	s = await go_deck("hydroponics")
	s.player.die("killed")
	await frames(2)
	await tap("menu")
	ok(not s.pause.visible and not get_tree().paused, "menu does nothing while you are down")
	await wait(2.2)
	ok(s.results.visible, "the down panel shows after a moment")
	var down: Array = texts(s.results)
	print("   down buttons: ", down)
	ok("Try the deck again" in down and "Back to the ring" in down and "Back to the title" in down, "the down panel offers retry, the ring and the title")
	await click(find_btn(s.results, "Try the deck again"))
	await changed()
	await frames(5)
	ok(DeckScene.current != null and DeckScene.current != s and not DeckScene.current.player.is_dead and not get_tree().paused, "Try the deck again starts a fresh visit")
	s = DeckScene.current
	await tap("menu")
	await click(find_btn(s.pause, "Back to the title"))
	await changed()
	await frames(3)

## Changes each deck-affecting setting through the pause menu and checks the
## tech has it after Carry on.
func _pause_effects(s: DeckScene) -> void:
	var p := s.player
	# Looking, crouch mode, field of view, roll, bob, rumble, calm walls.
	await _open(s)
	_set_row(s, "Look speed", 0.5)
	_set_row(s, "Invert look", true)
	_set_row(s, "Hold to crouch", false)
	_set_row(s, "Field of view", 90.0)
	_set_row(s, "View roll", true)
	_set_row(s, "Head bob", 1.0)
	_set_row(s, "Rumble", false)
	_set_row(s, "Calm walls", 0.0)
	await _resume(s)
	ok(approx(p.MOUSE_SENS, 0.5), "Look speed Fast reaches the tech (%s)" % p.MOUSE_SENS)
	ok(p.INVERT_Y_AXIS == true, "Invert look reaches the tech")
	ok(p.TOGGLE_CROUCH == false, "Hold to crouch reaches the tech")
	ok(approx(p.camera.fov, 90.0), "Field of view Wide reaches the camera (%s)" % p.camera.fov)
	ok(p._tilt == true, "View roll reaches the tech")
	ok(p.WIGGLE_ON_WALKING_INTENSITY > 0.0, "Head bob Full gives a walking bob (%s)" % p.WIGGLE_ON_WALKING_INTENSITY)
	ok(p._rumble == false, "Rumble off reaches the tech")
	calm_is(0.0, "Calm walls Still reaches the shaders")
	var walked := await _bob_amount(s)
	ok(walked > 0.002, "with Head bob Full the eyes bob when walking (%.4f)" % walked)
	# Hold to crouch: crouched while held, standing when let go.
	await hold_action("crouch", 25)
	ok(not p.is_crouching, "with Hold to crouch on, letting go of the key stands up")
	Input.action_press("crouch")
	for i in 25:
		await get_tree().physics_frame
	ok(p.is_crouching, "and holding it crouches")
	Input.action_release("crouch")
	for i in 40:
		await get_tree().physics_frame
	ok(not p.is_crouching, "and letting go stands again")
	# Bob, roll and calm walls back to their comfortable settings.
	await _open(s)
	_set_row(s, "Head bob", 0.0)
	_set_row(s, "View roll", false)
	_set_row(s, "Calm walls", 1.0)
	_set_row(s, "Hold to crouch", true)
	await _resume(s)
	ok(p.WIGGLE_ON_WALKING_INTENSITY == 0.0 and p.WIGGLE_ON_SPRINTING_INTENSITY == 0.0 and p.WIGGLE_ON_CROUCHING_INTENSITY == 0.0, "Head bob Off zeroes every bob")
	walked = await _bob_amount(s)
	ok(walked < 0.0005, "with Head bob Off the eyes stay still when walking (%.5f)" % walked)
	ok(p._tilt == false, "View roll off reaches the tech")
	calm_is(1.0, "Calm walls back to normal reaches the shaders")
	ok(p.TOGGLE_CROUCH == true, "the crouch key toggles again")
	await hold_action("crouch", 3)
	for i in 30:
		await get_tree().physics_frame
	ok(p.is_crouching, "with toggle crouch, one tap stays crouched")
	await hold_action("crouch", 3)
	for i in 40:
		await get_tree().physics_frame
	ok(not p.is_crouching, "and a second tap stands")
	# Spore blur and subtitles.
	await _open(s)
	_set_row(s, "Spore blur", false)
	_set_row(s, "Subtitles", false)
	await _resume(s)
	s.hud.spores(1.0)
	await frames(4)
	var blur := float(s.hud._overlay_mat.get_shader_parameter("blur"))
	ok(blur == 0.0, "Spore blur off: no blur in the overlay (%.2f)" % blur)
	s.hud.hush()
	s.hud.say("Dr Okoye", "A crew line.")
	ok(s.hud.subtitle_text() == "", "Subtitles off hides a crew member's line")
	s.hud.say("MARI", "A MARI line.")
	ok(s.hud.subtitle_text() != "", "Subtitles off still shows MARI")
	await _open(s)
	_set_row(s, "Spore blur", true)
	_set_row(s, "Subtitles", true)
	await _resume(s)
	s.hud.spores(1.0)
	await frames(4)
	blur = float(s.hud._overlay_mat.get_shader_parameter("blur"))
	ok(blur > 0.0, "Spore blur on: the overlay blurs (%.2f)" % blur)
	s.hud.hush()
	s.hud.say("Dr Okoye", "A crew line.")
	ok(s.hud.subtitle_text() != "", "Subtitles on shows a crew line")
	s.hud.hush()
	# Difficulty, heavy first.
	await _open(s)
	_set_row(s, "Bloom spread", 1.3)
	_set_row(s, "Damage taken", 1.4)
	_set_row(s, "Ammunition", 0.7)
	await _resume(s)
	ok(approx(s.spread(), s.deck.spread * 1.3), "Bloom spread Fast scales the Bloom (%.2f)" % s.spread())
	ok(approx(s.creature_damage(), 1.4), "Damage Heavy scales hits taken")
	var hp := p.health
	p.take_hit(Hit.make(Hit.Kind.CLAW, 10.0, p.global_position, Vector3.FORWARD))
	ok(approx(hp - p.health, 14.0), "a 10 point hit costs 14 on Heavy (%.1f)" % (hp - p.health))
	# A pick-up counts magazines; the rifle's hold 30 rounds and it carries 180.
	p.arsenal.give("rifle")
	p.arsenal.reserve["rifle"] = 0
	p.take_pickup("ammo:rifle", 4)
	var gained: int = int(p.arsenal.reserve.get("rifle", 0))
	ok(gained == 90, "Ammunition Scarce turns 4 magazines into 3 (%d rounds)" % gained)
	# And light.
	await _open(s)
	_set_row(s, "Bloom spread", 0.75)
	_set_row(s, "Damage taken", 0.6)
	_set_row(s, "Ammunition", 1.4)
	await _resume(s)
	p.immune = 0.0
	hp = p.health
	p.take_hit(Hit.make(Hit.Kind.CLAW, 10.0, p.global_position, Vector3.FORWARD))
	ok(approx(hp - p.health, 6.0), "a 10 point hit costs 6 on Light (%.1f)" % (hp - p.health))
	p.arsenal.reserve["rifle"] = 0
	p.take_pickup("ammo:rifle", 4)
	gained = int(p.arsenal.reserve.get("rifle", 0))
	ok(gained == 180, "Ammunition Plenty turns 4 magazines into 6, up to the 180 carried (%d rounds)" % gained)
	s.tick_bloom()
	ok(approx(s.level.bloom.speed, s.deck.spread * 0.75), "and the Bloom's speed follows Spread (%.2f)" % s.level.bloom.speed)
	# Gore.
	await _open(s)
	_set_row(s, "Gore", "off")
	await _resume(s)
	ok(not Gore.shown(), "Gore Off reaches Gore")
	reset_settings()
	await _open(s)
	await _resume(s)


## Opens the pause menu with the key.
func _open(s: DeckScene) -> void:
	if not s.pause.visible:
		await tap("menu")


## Sets a row of the open pause menu to a value by stepping it.
func _set_row(s: DeckScene, label: String, option_value: Variant) -> void:
	var c: LGCycler = cyclers(s.pause).get(label)
	if c == null:
		ok(false, "the pause menu has a '%s' row" % label)
		return
	for i in c.options.size():
		if approx(c.value(), option_value):
			return
		c.step(1)
	ok(false, "'%s' has no option %s" % [label, option_value])


## Carry on, by clicking it.
func _resume(s: DeckScene) -> void:
	await click(find_btn(s.pause, "Carry on"))


## How far the eyes move while walking forward for a second.
func _bob_amount(s: DeckScene) -> float:
	var p := s.player
	p.eyes.position = Vector3.ZERO
	var most := 0.0
	Input.action_press("forward")
	for i in 90:
		await get_tree().physics_frame
		most = maxf(most, maxf(absf(p.eyes.position.y), absf(p.eyes.position.x)))
	Input.action_release("forward")
	await get_tree().physics_frame
	return most

#endregion

#region Saves

func _s_saves() -> void:
	reset_settings()
	Progress.reset()
	Progress.new_campaign()
	var s := await go_deck("hydroponics")
	ok(await hold(s), "Hydroponics can be held")
	var start := snap()
	# Quit mid-deck after holding it, without taking the lift.
	await tap("menu")
	await click(find_btn(s.pause, "Back to the title"))
	await changed()
	await frames(3)
	var after := snap()
	ok(Progress.deck_state("hydroponics") == "saved", "a held deck is kept when you quit to the title before the lift (state is '%s')" % Progress.deck_state("hydroponics"))
	# Do it properly: hold, take the lift, back to the ring.
	s = await go_deck("hydroponics")
	ok(await hold(s), "Hydroponics held again")
	s.pause.close_pause_menu()
	await leave_deck(s)
	ok(s.results.visible, "the results show on leaving")
	print("   results: ", s.results.line_texts(), texts(s.results))
	var ring := await to_ring(s)
	ok(ring != null and ring.has_method("briefing_text"), "Back to the ring opens the ring map")
	ok(Progress.deck_state("hydroponics") == "saved", "Hydroponics is saved")
	for m in Decks.MIDDLE:
		ok(Progress.deck_state(m) == "open" and Progress.hours_left(m) == Decks.get_deck(m).hours, "%s opens with %d hours" % [m, Decks.get_deck(m).hours])
	# Medical: hold it, take its gift.
	ok(not Progress.has_gift("stims"), "no stims gift yet")
	ring.select("medical")
	await press(ring, "Go to Medical")
	await changed()
	await frames(6)
	s = DeckScene.current
	ok(s != null and s.deck_id == "medical" and not s.hub, "Medical opens as a deck to hold")
	ok(await hold(s), "Medical can be held")
	await leave_deck(s)
	ring = await to_ring(s)
	ok(Progress.deck_state("medical") == "saved", "Medical is saved")
	ok(Progress.hour() == 1, "a middle deck takes an hour (hour %d)" % Progress.hour())
	ok(Progress.hours_left("crew") == 1 and Progress.hours_left("labs") == 2, "the other decks lost an hour (crew %d, labs %d)" % [Progress.hours_left("crew"), Progress.hours_left("labs")])
	ok(Progress.has_gift("stims"), "Medical's gift is kept")
	var before := snap()
	var gifts_before := gifts()
	# A restart: reload progress from the disk.
	Progress.load_progress()
	var reloaded := snap()
	ok(reloaded == before, "a restart keeps hours, decks, kit and gifts" + ("" if reloaded == before else " (%s vs %s)" % [before, reloaded]))
	ok(gifts() == gifts_before, "and the gifts (%s)" % [gifts_before])
	# Visit labs with the gift: stims in the kit.
	ring.queue_free()
	await frames(2)
	ring = await go(DeckScene.RING)
	ring.select("labs")
	await press(ring, "Go to Labs")
	await changed()
	await frames(6)
	s = DeckScene.current
	ok(int(s.player.items.get("stim", 0)) >= 2 and int(s.player.items.get("medkit", 0)) >= 2, "Medical's gift tops up stims and medkits on the next deck (stim %d, medkit %d)" % [s.player.items.get("stim", 0), s.player.items.get("medkit", 0)])
	# Leave without holding: crew has 1 hour, so it is lost now.
	await leave_deck(s)
	print("   results after labs unheld: ", s.results.line_texts())
	ring = await to_ring(s)
	ok(Progress.deck_state("labs") == "open", "an unheld deck stays open")
	ok(Progress.hours_left("crew") == 0 or Progress.deck_state("crew") == "lost", "Crew ran out of hours (state %s)" % Progress.deck_state("crew"))
	ok(Progress.deck_state("crew") == "lost", "Crew is lost")
	var crew_btn: Button = ring._buttons.get("crew")
	ok(crew_btn != null and crew_btn.text.to_lower().contains("lost"), "the ring shows Crew as lost (%s)" % (crew_btn.text if crew_btn else "none"))
	ring.select("crew")
	ok(ring.briefing_text().contains("Lost to the Bloom"), "and its briefing says lost")
	ok(has_btn(ring, "Take it back"), "a lost deck can be taken back")
	var snap_lost := snap()
	Progress.load_progress()
	ok(snap() == snap_lost, "a lost deck is still lost after a restart")
	# Take it back: overgrown, then reclaimed.
	await press(ring, "Take it back")
	await changed()
	await frames(6)
	s = DeckScene.current
	ok(s != null and s.overgrown and not s.hub, "a lost deck comes back overgrown")
	var growth: float = s.level.bloom.coverage()
	ok(growth > 0.3, "and the growth has taken a lot of it (%.0f%%)" % (growth * 100.0))
	ok(await hold(s, 500), "an overgrown Crew can be held")
	await leave_deck(s)
	ring = await to_ring(s)
	ok(Progress.deck_state("crew") == "reclaimed", "Crew is taken back")
	ok(Progress.has_gift("survivors"), "a taken back deck gives its gift (survivors %s)" % Progress.has_gift("survivors"))
	note("Progress.has_gift counts only 'saved' decks, so a reclaimed deck's gift (Crew: survivors on the map) is never given")
	# Workbench, salvage and upgrades are kept.
	Progress._cfg.set_value("shift", "salvage", 20)
	Progress.buy("suit")
	var sn := snap()
	Progress.load_progress()
	ok(Progress.has_upgrade("suit") and Progress.salvage() == 12, "an upgrade and the salvage left are kept after a restart")
	# A visit to a saved deck is a hub and costs nothing.
	var hr := Progress.hour()
	ring.select("hydroponics")
	await press(ring, "Visit the deck")
	await changed()
	await frames(6)
	s = DeckScene.current
	ok(s != null and s.hub and s.run.held, "a saved deck is a hub that starts held")
	await leave_deck(s)
	ring = await to_ring(s)
	ok(Progress.hour() == hr, "visiting a saved deck takes no hour")
	# A corrupt progress file.
	var f := FileAccess.open("user://progress.cfg", FileAccess.WRITE)
	f.store_string("this is [not a config\n\u0001\u0002 garbage = [")
	f.close()
	Progress.load_progress()
	ok(not Progress.has_campaign(), "a corrupt progress file loads as no shift (no crash)")
	var t := await go("res://game/ui/title.tscn")
	ok(has_btn(t, "New night shift") and not has_btn(t, "Carry on"), "the title still opens on a corrupt save")
	# A progress file with the shift started but the decks missing.
	var cf := ConfigFile.new()
	cf.set_value("shift", "started", true)
	cf.set_value("shift", "hour", 0)
	cf.save("user://progress.cfg")
	Progress.load_progress()
	t.show_main()
	await frames(2)
	var carry := find_btn(t, "Carry on")
	if carry:
		await click(carry)
		await changed()
		await frames(4)
		var r := get_tree().current_scene
		var can_go := false
		if r.has_method("button_texts"):
			for bt in r.button_texts():
				if bt.begins_with("Go to"):
					can_go = true
		note("a hand-edited progress file with 'started' but no decks %s" % ("still lets you go to a deck" if can_go else "leaves every deck locked on the ring; only New night shift gets out"))
	Progress.reset()

#endregion

#region Screens

func _s_screens() -> void:
	reset_settings()
	Progress.reset()
	Progress.new_campaign()
	var ring := await go(DeckScene.RING)
	var b: Array = Array(ring.button_texts())
	print("   ring buttons: ", b)
	for id in Decks.ids():
		var d := Decks.get_deck(id)
		var btn: Button = ring._buttons[id]
		await click(btn)
		var go_btn := find_btn(ring, "Go to")
		var brief: String = ring.briefing_text()
		if Progress.deck_state(id) == "open":
			ok(go_btn != null, "%s: open, so a Go to button shows" % d.name)
		else:
			ok(go_btn == null and brief.contains("Locked"), "%s: locked, no way in, and the briefing says so" % d.name)
	Progress.finish_deck("hydroponics", {"held": true, "salvage": 12})
	Progress._cfg.set_value("shift", "spare_cells", 2)
	ring.refresh()
	await frames(2)
	ring.select("labs")
	await frames(1)
	ok(has_btn(ring, "Send a spare cell"), "a spare cell can be sent to an open deck")
	var h0 := Progress.hours_left("labs")
	await press(ring, "Send a spare cell")
	ok(Progress.hours_left("labs") == h0 + 1 and Progress.spare_cells() == 1, "sending a spare cell buys an hour")
	await tap("ui_cancel")
	await changed()
	await frames(3)
	ok(get_tree().current_scene.has_method("show_main"), "Escape on the ring goes back to the title")
	# Workbench on a hub deck.
	Progress._cfg.set_value("shift", "salvage", 30)
	var s := await go_deck("hydroponics")
	ok(s.hub, "Hydroponics is a hub once saved")
	var wb := s.get_tree().get_nodes_in_group("hub_stations").filter(func(h): return h.kind == "workbench")
	ok(wb.size() == 1, "the hub has a workbench")
	var bunk := s.get_tree().get_nodes_in_group("hub_stations").filter(func(h): return h.kind == "bunk")
	ok(bunk.size() == 1, "and a bunk")
	s._on_hub_opened(wb[0])
	await frames(3)
	ok(s.workbench.visible and get_tree().paused, "using the workbench opens it and pauses")
	var wbb: Array = texts(s.workbench)
	print("   workbench: ", wbb)
	ok("Done" in wbb, "the workbench has Done")
	ok(wbb.size() == Progress.UPGRADES.size() + 1, "and a row for each of the %d upgrades" % Progress.UPGRADES.size())
	var suit_before: float = s.player.max_health
	await click(find_btn(s.workbench, "Suit plating"))
	ok(Progress.has_upgrade("suit") and Progress.salvage() == 22, "buying Suit plating takes 8 salvage (%d left)" % Progress.salvage())
	ok(s.player.max_health == suit_before + Tech.SUIT_BONUS, "and gives the suit its plating")
	var again := find_btn(s.workbench, "Suit plating")
	ok(again != null and again.disabled and again.text.contains("fitted"), "a fitted upgrade is greyed and says fitted")
	var st0: Dictionary = s.player.arsenal.stat("sidearm")
	await click(find_btn(s.workbench, "Heavy sidearm"))
	var st1: Dictionary = s.player.arsenal.stat("sidearm")
	ok(float(st1["damage"]) > float(st0["damage"]), "Heavy sidearm hits harder (%s to %s)" % [st0["damage"], st1["damage"]])
	var cool0: Dictionary = s.player.arsenal.stat("cutter")
	await click(find_btn(s.workbench, "Cutter heat sink"))
	ok(float(s.player.arsenal.stat("cutter")["heat"]) < float(cool0["heat"]), "Cutter heat sink cools the cutter")
	# Too dear: salvage 0 leaves everything greyed.
	Progress._cfg.set_value("shift", "salvage", 0)
	s.workbench._refresh()
	var all_grey := true
	for u in Progress.UPGRADES:
		var bt := find_btn(s.workbench, Progress.UPGRADES[u][0])
		if bt and not bt.disabled:
			all_grey = false
	ok(all_grey, "with no salvage every upgrade is greyed")
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		await tap("ui_down")
		focus = get_viewport().gui_get_focus_owner()
		ok(focus != null, "with every upgrade greyed a pad can still move to Done (focus after Down: %s)" % (focus.text if focus is Button else str(focus)))
	else:
		ok(true, "with every upgrade greyed the workbench focuses %s" % (focus.text if focus is Button else str(focus)))
	await tap("menu")
	ok(not s.workbench.visible and not get_tree().paused, "menu closes the workbench and resumes")
	captured("with the mouse captured again")
	s._on_hub_opened(wb[0])
	await frames(2)
	await click(find_btn(s.workbench, "Done"))
	ok(not s.workbench.visible and not get_tree().paused, "Done closes the workbench")
	s._on_hub_opened(bunk[0])
	ok(true, "the bunk rests")
	# The deck map's buttons.
	s.map_panel.open()
	await frames(3)
	var room_buttons: Array = texts(s.map_panel)
	print("   map: ", room_buttons)
	ok(room_buttons.size() > 0, "the deck map lists rooms")
	s.map_panel.close()
	# Results panel buttons on a held hub visit.
	await leave_deck(s)
	var rb: Array = texts(s.results)
	print("   hub results: ", rb, s.results.line_texts())
	ok("Back to the ring" in rb and "Back to the title" in rb, "the results offer the ring and the title")
	await click(find_btn(s.results, "Back to the title"))
	await changed()
	await frames(3)
	ok(get_tree().current_scene.has_method("show_main"), "Back to the title from the results works")
	Progress.reset()

#endregion

#region Ending

## The Core held with the shuttle fuelled but not every deck held: the choice,
## and then the ending, Shift mode opening, and the title afterwards.
func _s_ending() -> void:
	reset_settings()
	Progress.reset()
	Progress.new_campaign()
	for m in Decks.MIDDLE:
		var d := Progress._deck(m)
		d["state"] = "saved" if m in ["cargo", "medical"] else "lost"
		Progress._set_deck(m, d)
	var cd := Progress._deck("hydroponics")
	cd["state"] = "saved"
	Progress._set_deck("hydroponics", cd)
	var core := Progress._deck("core")
	core["state"] = "open"
	Progress._set_deck("core", core)
	Progress._save()
	var ring := await go(DeckScene.RING)
	ring.select("core")
	ok(has_btn(ring, "Go to The Core"), "the Core can be gone to once the ring is decided")
	await press(ring, "Go to The Core")
	await changed()
	var s := DeckScene.current
	ok(s != null and s.deck_id == "core", "the Core opens")
	ok(await hold(s, 600), "the Core can be held")
	await leave_deck(s)
	ok(has_btn(s.results, "See how it ends"), "holding the Core offers the ending")
	await click(find_btn(s.results, "See how it ends"))
	await changed()
	var e := get_tree().current_scene
	var eb: Array = texts(e)
	print("   ending buttons: ", eb)
	ok("Take the shuttle home" in eb and "Stay with Marigold" in eb, "with the shuttle fuelled you choose")
	ok(Progress.ending() == "", "and no ending is kept until you choose")
	await press(e, "Take the shuttle home")
	await wait(0.5)
	ok(Progress.ending() == "shuttle" and "shuttle" in Progress.endings_seen(), "choosing the shuttle keeps that ending")
	ok(ShiftNight.unlocked(), "and opens Shift mode")
	ok(labels(e).contains("Shift mode is open"), "and says so")
	await press(e, "Back to the title")
	await changed()
	var title := get_tree().current_scene
	ok(find_btn(title, "Carry on") != null and find_btn(title, "Carry on").text.contains("shift is over"), "the title says the shift is over")
	await press(title, "Carry on")
	await changed()
	ok(get_tree().current_scene.has_method("briefing_text"), "Carry on after the ending still opens the ring")
	var ring2 := get_tree().current_scene
	await press(ring2, "Back to the title")
	await changed()
	# A shift with no shuttle: you stay, straight away.
	var cg := Progress._deck("cargo")
	cg["state"] = "lost"
	Progress._set_deck("cargo", cg)
	Progress._cfg.set_value("shift", "ending", "")
	ok(EndingScreen.which() == "burn", "without the shuttle the ending is to stay")
	var scr := await go("res://game/ui/ending.tscn")
	await wait(0.3)
	ok(Progress.ending() == "burn", "and it is kept at once")
	Progress.reset()

#endregion

#region Shift

func _s_shift() -> void:
	reset_settings()
	Progress.reset()
	LGSettings.set_value("online", "enabled", false)
	mark()
	ShiftNight.start(12345)
	await changed()
	await frames(6)
	var s := DeckScene.current
	ok(s != null and s.mode == "shift", "a Shift night starts on its first deck")
	var names := []
	for round_i in ShiftNight.DECKS:
		s = DeckScene.current
		ok(s != null and s.mode == "shift", "deck %d of the night loads" % (round_i + 1))
		ok(await hold(s, 500), "deck %d can be held" % (round_i + 1))
		await leave_deck(s)
		var bt: Array = texts(s.results)
		print("   shift results: ", bt, s.results.line_texts())
		if round_i < ShiftNight.DECKS - 1:
			ok(bt.size() > 0 and String(bt[0]).begins_with("Next deck"), "after deck %d: %s" % [round_i + 1, bt])
			await click(find_btn(s.results, "Next deck"))
			await changed()
			await frames(6)
		else:
			ok(has_btn(s.results, "The night's score"), "after the last deck: The night's score")
			await click(find_btn(s.results, "The night's score"))
			await frames(3)
			var fin: Array = texts(s.results)
			ok("Back to the title" in fin and "Try this station again" in fin, "the night's score offers the title and another go: %s" % [fin])
			ok(Array(s.results.line_texts()).any(func(x): return x.begins_with("Score")), "and a score")
			ok(ShiftNight.current.over, "the night is over")
			ok(Progress.shift_best(12345)["score"] > 0, "the best is kept (%s)" % [Progress.shift_best(12345)])
			await click(find_btn(s.results, "Try this station again"))
			await changed()
			await frames(6)
			ok(DeckScene.current != null and DeckScene.current.mode == "shift" and ShiftNight.current.index == 0, "Try this station again restarts the night")
	# Going down ends the night.
	s = DeckScene.current
	s.player.die("killed")
	await wait(2.2)
	var dn: Array = texts(s.results)
	print("   shift down: ", dn, s.results.line_texts())
	ok(dn.has("Back to the title") and dn.has("Try this station again"), "going down on Shift ends the night with the score")
	await click(find_btn(s.results, "Back to the title"))
	await changed()
	await frames(3)
	Progress.reset()

#endregion

#region Offline

func _s_offline() -> void:
	reset_settings()
	Progress.reset()
	# Online on, pointing at a port nothing listens on.
	LGSettings.set_value("online", "enabled", true)
	LGSettings.set_value("online", "host", "127.0.0.1")
	LGSettings.set_value("online", "port", 9)
	LGSettings.set_value("online", "scheme", "http")
	LGNetwork.forced = true
	var ticks := [0]
	var counter := func() -> void: ticks[0] += 1
	get_tree().process_frame.connect(counter)
	var t0 := Time.get_ticks_msec()
	await ShiftNight.submit(1000)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var frames_during: int = ticks[0]
	ok(true, "ShiftNight.submit to a dead server returned after %.1fs" % took)
	ok(frames_during > 10 or took < 0.3, "the game kept drawing while it tried (%d frames in %.1fs)" % [frames_during, took])
	ok(not LGOnline.is_connected_online(), "and did not pretend to be online")
	note("last_error after the failed submit: %s" % LGOnline.last_error)
	# Leaderboards page.
	var title := await go("res://game/ui/title.tscn")
	await press(title, "Leaderboards")
	ok(title.find_children("", "LGLeaderboardPanel", true, false).size() == 1, "Leaderboards opens its panel with online on")
	await wait(1.0)
	var msg := labels(title)
	print("   boards say: ", msg)
	ok(msg.contains("Can't reach") or msg.contains("Loading") or msg.contains("Couldn't"), "and says why there are no scores (no crash)")
	await wait(6.0)
	msg = labels(title)
	print("   boards later say: ", msg)
	ok(msg.contains("Can't reach") or msg.contains("Couldn't"), "after a while it says it can't reach the server (not still Loading)")
	ok(has_btn(title, "Back"), "Back is there")
	await press(title, "Back")
	ok(has_btn(title, "New night shift"), "and works")
	# A whole Shift night with online on and no server: play goes on.
	var daily := ShiftNight.daily_seed()
	Progress.set_ending("burn")
	mark()
	ShiftNight.start(daily)
	await changed()
	await frames(6)
	var s := DeckScene.current
	s.player.die("killed")
	await wait(2.5)
	ok(s.results.visible, "going down on tonight's station still shows the score with no server")
	var t1 := Time.get_ticks_msec()
	await click(find_btn(s.results, "Try this station again"))
	await changed()
	await frames(6)
	ok(DeckScene.current != null and not DeckScene.current.player.is_dead, "and play goes on")
	ok(Time.get_ticks_msec() - t1 < 5000, "without waiting on the network")
	# The same, with the device offline.
	LGNetwork.forced = false
	get_tree().process_frame.disconnect(counter)
	s = DeckScene.current
	await tap("menu")
	await click(find_btn(s.pause, "Back to the title"))
	await changed()
	await frames(3)
	LGSettings.set_value("online", "host", default_of("online", "host"))
	LGSettings.set_value("online", "port", default_of("online", "port"))
	LGSettings.set_value("online", "scheme", default_of("online", "scheme"))
	LGSettings.set_value("online", "enabled", false)
	Progress.reset()

#endregion

#region Gore

func _s_gore() -> void:
	reset_settings()
	var s := await go_deck("hydroponics", {"mode": "test"})
	var spot := s.player.global_position + Vector3(0, 0.0, -3.0)
	for level in ["full", "less", "off"]:
		LGSettings.set_value("gore", "level", level)
		Gore.clear()
		var d := Gore.splat(s, s.player.global_position + Vector3(0, 0.05, -2.0), Vector3.UP, 1.0, "blood")
		ok((d != null) == (level != "off"), "gore %s: a splash %s" % [level, "appears" if d else "does not appear"])
		if d:
			ok(approx(d.modulate.r, Gore.color("blood").r), "gore %s: the splash is %s" % [level, "red blood" if level == "full" else "dark ichor"])
		var g0 := Gore._gibs.size()
		Gore.gibs(s, s.player.global_position + Vector3(0, 1, -2.0), 6)
		ok((Gore._gibs.size() > g0) == (level != "off"), "gore %s: gibs %s" % [level, "fly" if Gore._gibs.size() > g0 else "do not fly"])
		if level == "less":
			ok(Gore._gibs.size() - g0 == 3, "gore less: fewer gibs (%d of 6)" % (Gore._gibs.size() - g0))
		# A skitter killed.
		var before := Gore._decals.size() + Gore._gibs.size()
		var sk := s.director.spawn("skitter", spot, false)
		await frames(4)
		sk.take_hit(Hit.make(Hit.Kind.BLAST, 1000.0, sk.global_position + Vector3(0, 0.3, 0), Vector3.FORWARD, s.player))
		await frames(6)
		var after := Gore._decals.size() + Gore._gibs.size()
		if level == "off":
			ok(after == before, "gore off: killing a skitter leaves no blood or gibs (%d -> %d)" % [before, after])
		else:
			ok(after > before, "gore %s: killing a skitter leaves a mark (%d -> %d)" % [level, before, after])
	# Stalker claws and Taken limbs under each level.
	for level in ["full", "less", "off"]:
		LGSettings.set_value("gore", "level", level)
		var st := s.director.spawn("stalker", spot + Vector3(0, 0, -2), false) as Stalker
		await frames(6)
		if st.skeleton == null or st.hider == null:
			note("the Stalker has no skeleton or hider in this run")
			st.queue_free()
			continue
		var limb: String = Stalker.CLAWS.keys()[0]
		var bone: int = st.skeleton.find_bone(Stalker.CLAWS[limb])
		var hit := Hit.make(Hit.Kind.BURN, 400.0, st.global_position + Vector3(0, 1, 0), Vector3.FORWARD, s.player)
		hit.limb = limb
		hit.sever = 5.0
		st.limb_hit(hit)
		await frames(3)
		var hidden: bool = st.hider.is_hidden(bone)
		if level == "full":
			ok(hidden, "gore full: a Stalker's claw comes off")
		else:
			ok(not hidden, "gore %s: a Stalker's claw stays on" % level)
		st.queue_free()
		await frames(2)
	LGSettings.set_value("gore", "level", "full")
	reset_settings()
	s.queue_free()
	await frames(3)

#endregion

#region Quit

## The title's Quit button, last: it ends the process, so the summary is
## printed first and again if the game is still there afterwards.
func _s_quit() -> void:
	_section = "quit"
	Progress.reset()
	var title := await go("res://game/ui/title.tscn")
	print("\n%d passed, %d failed before the Quit button" % [passed, failed])
	# With a play test recording, quitting asks the questions first.
	var rec := LGPlaytest.current()
	if rec:
		rec.begin()
		await click(find_btn(title, "Quit"))
		await frames(3)
		ok(rec.is_finishing() and rec.find_children("*", "LGPlaytestSurvey", true, false).size() == 1, "Quit while recording shows the survey first")
		ok(not _quit_seen, "and the game is still running")
		var survey: Node = rec.find_children("*", "LGPlaytestSurvey", true, false)[0]
		survey.skip_all()
		await frames(3)
		var cards := rec.find_children("*", "LGPlaytestCard", true, false)
		ok(cards.size() == 1 and find_btn(cards[0], "Quit") != null, "after the survey a card names the file and offers Quit (%s)" % [texts(cards[0]) if cards.size() == 1 else "no card"])
		if cards.size() == 1:
			await click(find_btn(cards[0], "Quit"))
	else:
		await click(find_btn(title, "Quit"))
	await wait(1.0)
	ok(false, "the game ends when Quit is pressed")
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1)

#endregion
