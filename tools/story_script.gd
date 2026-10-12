extends SceneTree
## Writes the story script: every player-facing line of Verdigris Protocol as one
## Markdown file, in the order a player meets it. The title and the story so
## far, then what every deck shares (the HUD, prompts, MARI's own lines, the
## pause menu, results), then each deck in ring order (its briefing, MARI,
## rooms, and its logs, survivors, bodies and the Taken in level order), the
## ring map and workbench between decks, the endings and Shift mode.
##
##   godot --headless --path . -s tools/story_script.gd -- --out=/tmp/story.md
##
## Each line is tagged with the file it comes from and who says it. Lines come
## from the game's data, its screens (built off screen) and its levels (built
## with no player, as the tests do); the few that only exist as code (toasts,
## prompts, the HUD's labels) are read from the source and marked "source".
## Progress is kept in memory, so the player's own shift is never touched.
##
## Everything is loaded at run time: a -s script compiles before the
## autoloads exist, so naming the game's classes here would fail.

## Subtitles faster than this many characters a second are hard to read.
const READ_CPS := 17.0
const DECKS := "res://game/decks/decks.gd"

var _md := PackedStringArray()
var _progress: Node
var _decks: GDScript
## Deck id -> the ring map's briefing for it, as first seen.
var _briefs := {}
## Where screens are built: the current scene, as the game's code expects one.
var _stage: Node
var _lit := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
## Strings that aren't words for a player: ids, node names, theme types.
var _ident := RegEx.create_from_string("^([a-z0-9_:./%]*|[A-Z][a-z]+[A-Z][A-Za-z]*)$|\\[(b|color)")
var _word := RegEx.create_from_string("[A-Za-z]{2}")


func _initialize() -> void:
	_run()


func _run() -> void:
	# Let the autoloads finish their _ready first.
	await process_frame
	var out := "user://story_script.md"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var settings := root.get_node("LGSettings")
	settings.register_defaults(load("res://game/game_config.gd").SETTING_DEFAULTS)
	# Offline, as --set=online/enabled=false does (never saved): the boards
	# screen would sign in otherwise.
	settings._overrides["online/enabled"] = false
	_progress = root.get_node("Progress")
	_progress.in_memory = true
	_progress.load_progress()
	_decks = load(DECKS)
	_stage = Node.new()
	_stage.name = "StoryScript"
	root.add_child(_stage)
	current_scene = _stage
	await _gather_briefings()
	_intro()
	await _title()
	await _every_deck()
	_deck("hydroponics")
	await _ring()
	await _hub()
	_h(1, "The six middle decks")
	_p("Once Hydroponics is held these open together and can be played in any order; they're listed here in ring order.")
	for id in _decks.MIDDLE:
		_deck(id)
	_deck("core")
	await _endings()
	await _shift()
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		printerr("story_script: can't write ", out)
		quit(1)
		return
	f.store_string("\n".join(_md) + "\n")
	f.close()
	print("story_script: wrote %d lines to %s" % [_md.size(), ProjectSettings.globalize_path(out) if out.begins_with("user://") else out])
	quit()


#region Writing

func _h(level: int, text: String) -> void:
	if not _md.is_empty():
		_md.append("")
	_md.append("#".repeat(level) + " " + text)
	_md.append("")


func _p(text: String) -> void:
	_md.append(text)
	_md.append("")


func _li(text: String) -> void:
	_md.append("- " + text)


func _end_list() -> void:
	if not _md.is_empty() and _md[_md.size() - 1] != "":
		_md.append("")


## A quoted block of several paragraphs.
func _quote(text: String) -> void:
	var first := true
	for para in text.split("\n", false):
		if not first:
			_md.append(">")
		_md.append("> " + para)
		first = false
	_md.append("")


func _tag(src: String) -> String:
	return "`%s`" % src.trim_prefix("res://")


## A spoken line: who, when, where it's from, and whether it's on screen
## long enough to read (the HUD shows a line for 2 s plus 0.055 s a
## character, between 3 and 9 s).
func _say(who: String, when: String, text: String, src: String) -> void:
	var secs := clampf(2.0 + text.length() * 0.055, 3.0, 9.0)
	var cps := text.length() / secs
	var flag := ""
	if cps > READ_CPS:
		flag = " _[%d characters in %d s: %d a second]_" % [text.length(), roundi(secs), roundi(cps)]
	_li("**%s**%s %s: \"%s\"%s" % [who, " (" + when + ")" if when != "" else "", _tag(src), text, flag])


## Every Label, button and setting row under `node`, in screen order.
func _ui_lines(node: Node, out: PackedStringArray) -> void:
	if node.is_queued_for_deletion():
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is OptionButton:
		var items := PackedStringArray()
		for i in (node as OptionButton).item_count:
			items.append((node as OptionButton).get_item_text(i))
		out.append("[%s]" % " / ".join(items))
		return
	if node is Button:
		var label: Variant = node.get("label_text")
		if label != null and String(label) != "":
			var opts := PackedStringArray()
			for o in node.get("options"):
				opts.append(String(o[1]))
			out.append("%s: %s" % [label, " / ".join(opts)])
		elif (node as Button).text != "":
			out.append("[%s]" % (node as Button).text)
		return
	if node is Label and (node as Label).text.strip_edges() != "":
		out.append((node as Label).text)
	elif node is RichTextLabel and (node as RichTextLabel).get_parsed_text().strip_edges() != "":
		out.append((node as RichTextLabel).get_parsed_text())
	for c in node.get_children():
		_ui_lines(c, out)


## Writes a screen's lines as a list, buttons in [brackets].
func _screen(node: Node, src: String, what: String) -> void:
	var lines := PackedStringArray()
	_ui_lines(node, lines)
	_li("%s %s:" % [what, _tag(src)])
	for l in lines:
		_md.append("  - " + l.replace("\n", " / "))
	_end_list()


## The player-facing string literals on lines of a script that match
## `pattern`, as a list tagged "source" with each line number.
func _source(path: String, pattern: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var re := RegEx.create_from_string(pattern)
	var n := 0
	for line in text.split("\n"):
		n += 1
		var code := line.strip_edges()
		if code.begins_with("#") or code.begins_with("push_") or re.search(line) == null:
			continue
		var strs := PackedStringArray()
		for m in _lit.search_all(line):
			var s := m.get_string(1).c_unescape()
			if s != "MARI" and _word.search(s) != null and _ident.search(s) == null and not s.begins_with("res://"):
				strs.append("\"%s\"" % s)
		if not strs.is_empty():
			_li("source %s: %s" % [_tag("%s:%d" % [path, n]), " · ".join(strs)])
	_end_list()


## The first line of a script that has every one of `needles`, for tags.
func _line_of(path: String, needles: Array) -> String:
	var n := 0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		n += 1
		if needles.all(line.contains):
			return "%s:%d" % [path, n]
	return path

#endregion

#region The title

func _intro() -> void:
	_h(1, "Verdigris Protocol: the story script")
	_p("Every player-facing line, in the order a player meets it, written by `tools/story_script.gd` from the game's own data, screens and level builds. Each line names its file and who says it. Buttons are in [brackets]; setting rows list their choices. Lines marked **source** are read from the code (prompts, toasts, the HUD), with `%%d`/`%%s` where the game fills in a number or a name. Spoken lines that the HUD shows too briefly to read at %d characters a second are marked with their timing." % READ_CPS)


func _title() -> void:
	_h(1, "The title and the story so far")
	var path := "res://game/ui/title.gd"
	_progress.reset()
	var title: Node = load("res://game/ui/title.tscn").instantiate()
	_stage.add_child(title)
	await process_frame
	var col: Node = title.get("_col")
	_screen(col, path, "The title, first time")
	_progress.new_campaign()
	title.show_main()
	await process_frame
	_screen(col, path, "The title, with a shift under way")
	title._ask_new()
	await process_frame
	_screen(col, path, "New night shift, over one under way")
	title.show_story()
	await process_frame
	_screen(col, path, "The story so far, before Hydroponics")
	title.show_about()
	await process_frame
	_screen(col, path, "About")
	_h(2, "How to play")
	for i in load("res://game/ui/how_to_play.gd").PAGES.size():
		title.show_how(i)
		await process_frame
		_screen(col, "res://game/ui/how_to_play.gd", "Page %d" % (i + 1))
	_h(2, "Settings")
	title.show_settings()
	await process_frame
	await process_frame
	_screen(col, "res://game/ui/play_settings.gd", "Settings from the title (the shared add-on's rows, then the game's)")
	_source("res://game/ui/play_settings.gd", "button\\(|ask\\(")
	title.show_boards()
	await process_frame
	_screen(col, path, "Leaderboards")
	title.show_shift()
	await process_frame
	_screen(col, path, "Shift mode, before the first ending")
	title.queue_free()
	await process_frame

#endregion

#region What every deck shares

func _every_deck() -> void:
	_h(1, "On every deck")
	_p("The HUD, prompts and alerts a player meets from Hydroponics on. Most of these are uppercased on screen.")
	_h(2, "MARI, on any deck")
	_source("res://game/deck/deck_scene.gd", "say\\(\"MARI\"")
	_h(2, "Objectives (the line under the deck's name)")
	var run: Object = load("res://game/deck/deck_run.gd").new(_decks.get_deck("hydroponics"))
	var lvl: Node = _decks.make_level("hydroponics")
	var bloom: Object = lvl.make_bloom()
	run.roots = 1
	run.survivors_total = 3
	_li("live `game/deck/deck_run.gd`, one root: " + _objectives(run, bloom))
	run.roots = 2
	run.roots_cut = 1
	_li("live, two roots, one cut: " + _objectives(run, bloom))
	run.roots_cut = 2
	_li("live, roots cut: " + _objectives(run, bloom))
	run.held = true
	_li("live, held: " + _objectives(run, bloom))
	lvl.free()
	_end_list()
	_source("res://game/ui/deck_hud.gd", "next = ")
	_h(2, "The HUD")
	_source("res://game/ui/deck_hud.gd", "hud_label\\(|ActionPrompt\\.make|\\.text = |parts\\.append|for . in \\[\\[")
	_source("res://game/arsenal/arsenal.gd", "return \"|ICED UP")
	var names := PackedStringArray()
	for w in load("res://game/arsenal/arsenal.gd").WEAPONS.values():
		names.append(String(w["name"]))
	_li("live `game/arsenal/arsenal.gd`, the guns: " + ", ".join(names))
	_end_list()
	_h(2, "Banners, alerts and spoken lines on a deck")
	_source("res://game/deck/deck_scene.gd", "toast\\(|banner\\(")
	_source("res://game/player/tech.gd", "_toast\\(\"")
	_h(2, "Prompts on things you use")
	var items := PackedStringArray()
	for k in load("res://game/station/pickup.gd").ITEMS:
		items.append(String(load("res://game/station/pickup.gd").ITEMS[k][0]))
	_li("live `game/station/pickup.gd`, \"Take ...\": " + ", ".join(items))
	_end_list()
	for f in ["pickup", "log_terminal", "survivor", "bulkhead", "lift", "turret", "vent_panel", "hub_station"]:
		_source("res://game/station/%s.gd" % f, "add_action|set_action_text|hint\\(|last_message = |_text = |text = \"|display_name = \"|say\\(|return \"|opts\\.get\\(\"(name|line)")
	_h(2, "The deck map")
	_source("res://game/ui/deck_map.gd", "label\\(|ActionPrompt|parts\\.append|state = |\\.text = ")
	_h(2, "The pause menu")
	var pause: Node = load("res://game/ui/pause_menu.gd").new()
	_stage.add_child(pause)
	pause.visible = true
	await process_frame
	_screen(pause, "res://game/ui/pause_menu.gd", "Paused on a deck")
	_source("res://game/deck/deck_scene.gd", "set_leave_text")
	pause.queue_free()
	_h(2, "Leaving a deck, and going down")
	_source("res://game/deck/deck_scene.gd", "show_panel\\(|lines\\.append|buttons\\.append|(why|title|buttons|lines) :?= ")
	await process_frame


func _objectives(run: Object, bloom: Object) -> String:
	var out := PackedStringArray()
	for o in run.objectives(bloom):
		out.append("\"%s\"%s" % [o[0], " (done)" if o[1] else ""])
	return ", ".join(out)

#endregion

#region Decks

## Builds the ring map with the shift at each point a deck is first seen, and
## keeps each deck's briefing.
func _gather_briefings() -> void:
	_progress.new_campaign()
	var ring: Node = load("res://game/ui/ring_map.tscn").instantiate()
	_stage.add_child(ring)
	await process_frame
	ring.select("hydroponics")
	_briefs["hydroponics"] = ring.briefing_text()
	ring.select("core")
	_briefs["core_locked"] = ring.briefing_text()
	_progress.finish_deck("hydroponics", {"held": true})
	ring.refresh()
	await process_frame
	for id in _decks.MIDDLE:
		ring.select(id)
		_briefs[id] = ring.briefing_text()
	for id in _decks.MIDDLE:
		var d: Dictionary = _progress._deck(id)
		d["state"] = "saved"
		_progress._set_deck(id, d)
	var core: Dictionary = _progress._deck("core")
	core["state"] = "open"
	_progress._set_deck("core", core)
	ring.refresh()
	await process_frame
	ring.select("core")
	_briefs["core"] = ring.briefing_text()
	await process_frame
	ring.queue_free()
	await process_frame


func _deck(id: String) -> void:
	var d: Object = _decks.get_deck(id)
	var data: String = _decks.DEF % [id, id]
	var path: String = d.level_path()
	_h(2 if id in _decks.MIDDLE else 1, "Deck %d: %s" % [d.number, d.name])
	_li("ring map %s: %s" % [_tag("game/ui/ring_map.gd"), _brief_text("core_locked" if id == "core" else id)])
	if id == "core":
		_li("ring map, once open: " + _brief_text("core"))
	_li("hours before it's lost: %d · power cells: %d · saving it gives: %s" % [d.hours, d.cells, d.gives if d.gives != "" else "nothing"])
	_say("MARI", "stepping out of the lift", d.arrive, data)
	_end_list()
	_h(3, "Rooms, as the deck map names them")
	var lvl: Node = _decks.make_level(id)
	var rooms := PackedStringArray()
	for r in lvl.room_ids:
		rooms.append(lvl.rooms[r]["name"])
	_p(", ".join(rooms) + ".")
	_h(3, "On the deck, in level order")
	var logs := 0
	for t in lvl.things:
		var kind: String = t[0]
		var opts: Dictionary = t[4]
		var room: String = lvl.rooms.get(lvl.tiles.get(t[1], ""), {}).get("name", "?")
		match kind:
			"log":
				logs += 1
				var by := String(opts.get("by", ""))
				_end_list()
				_md.append("**Log: %s** · %s · %s · %s%s" % [opts.get("title", "Log"), room, opts.get("style", "pad"),
					_tag(_line_of(path, ["\"%s\"" % opts.get("id", ""), "\"%s\"" % opts.get("title", "")])), (" · " + by) if by != "" else ""])
				_md.append("")
				var text := String(opts.get("text", ""))
				if text == "":
					text = "(no text)"
				_quote(text)
			"survivor":
				_say("%s (%s, survivor)" % [opts.get("name", "A survivor"), opts.get("job", "tech")], "found in " + room,
					String(opts.get("line", "")), _line_of(path, ["\"%s\"" % opts.get("id", ""), "\"%s\"" % opts.get("name", "")]))
			"body":
				_li("a body in %s (%s)" % [room, opts.get("job", "tech")])
			"spawn":
				if String(opts.get("what", "")) == "taken":
					_li("one of the Taken in %s (%s)" % [room, opts.get("job", "tech")])
			"pickup":
				var item := String(opts.get("item", ""))
				if item.begins_with("keycard:") or item.begins_with("weapon:"):
					var p: Node = load("res://game/station/pickup.gd").make(item)
					_li("in %s: \"Take %s\"" % [room, p.label()])
					p.free()
			"vent_panel":
				_li("an emergency vent panel for %s" % String(lvl.rooms.get(opts.get("room", ""), {}).get("name", "?")))
			"turret":
				_li("a turret mount in %s" % room)
			"workbench", "bunk":
				_li("the %s, in %s" % [kind, room])
	_end_list()
	if logs == 0:
		_p("No logs.")
	var dir := path.get_base_dir()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not f.ends_with("_tests.gd") and not f.ends_with("_deck.gd") and not f.ends_with("_level.gd"):
			_source(dir.path_join(f), "\\.text = ")
	lvl.free()
	_h(3, "When it's held")
	_say("MARI", "the deck is held", d.held, data)
	if d.gives_text != "":
		_li("results, under DECK HELD %s: \"%s\"" % [_tag(data), d.gives_text])
	_end_list()


func _brief_text(key: String) -> String:
	return String(_briefs.get(key, "")).replace("\n", " / ")

#endregion

#region Between decks

func _ring() -> void:
	_h(1, "The ring map, between decks")
	_p("After Hydroponics, the ring map is where every deck is picked. Its briefings for each deck are listed with the decks.")
	_progress.new_campaign()
	_progress.finish_deck("hydroponics", {"held": true})
	var ring: Node = load("res://game/ui/ring_map.tscn").instantiate()
	_stage.add_child(ring)
	await process_frame
	ring.select("crew")
	_screen(ring.get("_ui"), "res://game/ui/ring_map.gd", "The ring map after Hydroponics, Crew quarters picked")
	_li("the states a deck can be in %s:" % _tag("game/ui/ring_map.gd"))
	for st in ["open", "saved", "lost", "reclaimed"]:
		var d: Dictionary = _progress._deck("crew")
		d["state"] = st
		_progress._set_deck("crew", d)
		_md.append("  - %s (%s): \"%s\"" % [st, load("res://game/ui/ring_view.gd").state_word("crew"), ring._state_line("crew")])
	_end_list()
	_source("res://game/ui/ring_map.gd", "return \"|_status\\.text|button\\(")
	ring.queue_free()
	await process_frame


func _hub() -> void:
	_h(2, "A held deck: the workbench and the bunk")
	var bench: Node = load("res://game/ui/workbench_panel.gd").new()
	_stage.add_child(bench)
	await process_frame
	bench.visible = true
	bench._refresh()
	await process_frame
	_screen(bench, "res://game/ui/workbench_panel.gd", "The workbench")
	_source("res://game/deck/deck_scene.gd", "Rested")
	bench.queue_free()
	await process_frame

#endregion

#region Endings and Shift

func _endings() -> void:
	_h(1, "How it ends")
	var path := "res://game/ui/ending.gd"
	var screen: GDScript = load(path)
	_progress.new_campaign()
	var lines := PackedStringArray()
	for case in [["Cargo lost", {"cargo": "lost"}], ["Cargo saved, one deck lost", {"cargo": "saved", "crew": "lost"}], ["every deck saved", {}]]:
		for m in _decks.MIDDLE:
			var d: Dictionary = _progress._deck(m)
			d["state"] = case[1].get(m, "saved")
			_progress._set_deck(m, d)
		var e: String = screen.which()
		lines.append("%s: %s" % [case[0], "the player chooses" if e == "" else "\"" + e + "\""])
	_li("which ending `EndingScreen.which()` gives (live): " + "; ".join(lines))
	_end_list()
	_p("Screens below are built with Cargo saved and Crew quarters lost, so the counts are a sample.")
	for m in _decks.MIDDLE:
		var d: Dictionary = _progress._deck(m)
		d["state"] = "lost" if m == "crew" else "saved"
		_progress._set_deck(m, d)
	var end: Node = load("res://game/ui/ending.tscn").instantiate()
	_stage.add_child(end)
	await process_frame
	var col: Node = end.get("_col")
	_screen(col, path, "With Cargo's shuttle fuelled: the choice")
	for e in screen.ENDINGS:
		end.show_ending(e)
		await process_frame
		_screen(col, path, "Ending \"%s\"" % e)
	end.queue_free()
	await process_frame


func _shift() -> void:
	_h(1, "Shift mode")
	var night_script: GDScript = load("res://game/shift/shift_night.gd")
	var level_script: GDScript = load("res://game/shift/shift_level.gd")
	_progress.set_ending("stay")
	var title: Node = load("res://game/ui/title.tscn").instantiate()
	_stage.add_child(title)
	await process_frame
	title.show_shift()
	await process_frame
	_screen(title.get("_col"), "res://game/ui/title.gd", "Shift mode, once open")
	title.queue_free()
	await process_frame
	var c: Dictionary = night_script.get_script_constant_map()
	_li("deck names %s: %s" % [_tag("game/shift/shift_night.gd"), ", ".join(c["NAMES"])])
	var boards := PackedStringArray()
	for b in c["BOARDS"]:
		boards.append(b[1])
	_li("online boards: " + ", ".join(boards))
	var lc: Dictionary = level_script.get_script_constant_map()
	var kinds := PackedStringArray()
	for k in lc["KINDS"]:
		kinds.append(k[1])
	_li("room kinds %s: %s" % [_tag("game/shift/shift_level.gd"), ", ".join(kinds)])
	_li("crew names: " + ", ".join(lc["FIRST_NAMES"]) + " / " + ", ".join(lc["LAST_NAMES"]))
	_end_list()
	_h(2, "Survivors' lines and logs (picked at random)")
	for l in lc["LINES"]:
		_say("A survivor", "", l, "res://game/shift/shift_level.gd")
	_end_list()
	for l in lc["LOGS"]:
		_md.append("**Log: %s** %s" % [l[0], _tag("game/shift/shift_level.gd")])
		_md.append("")
		_quote(String(l[1]))
	var seed := 20261010
	var night: Object = night_script.make(seed)
	_h(2, "A sample night (seed %d)" % seed)
	for d in night.decks:
		_say("MARI", "deck %d, %s, arriving" % [d.number, d.name], d.arrive, "res://game/shift/shift_night.gd")
		var lvl: Node = level_script.new()
		lvl.deck = d
		lvl.build()
		for t in lvl.things:
			var room: String = lvl.rooms.get(lvl.tiles.get(t[1], ""), {}).get("name", "?")
			if t[0] == "log":
				_li("log in %s: \"%s\", by %s" % [room, t[4]["title"], t[4]["by"]])
			elif t[0] == "survivor":
				_li("survivor in %s: %s" % [room, t[4]["name"]])
		lvl.free()
		_say("MARI", "held", d.held, "res://game/shift/shift_night.gd")
	_end_list()
	_h(2, "Shift results")
	_source("res://game/shift/shift_night.gd", "show_panel\\(|lines\\.append|buttons\\.append|title = |sub = ")

#endregion
