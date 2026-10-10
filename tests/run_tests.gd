extends Node
## Headless tests: run with
##   godot --headless --path . tests/run_tests.tscn
## Add `-- --deck=<id>` to test only one deck (its data, layout, a visit and
## its own tests), `-- --core` for everything but the decks, or
## `-- --only=_test_bloom` for one test of this file. Exits non-zero on
## failure.

## A deck's own tests: game/decks/<id>/<id>_tests.gd, a RefCounted whose
## run(t) uses this runner's check(), frames(), open_deck() and so on.
const DECK_TESTS := "res://game/decks/%s/%s_tests.gd"
const GIFTS := ["", "power", "turrets", "stims", "rail", "shuttle", "survivors"]
## Coverage a deck may reach with nobody there, after five minutes.
const MAX_COVERAGE_5MIN := 0.85

var failures := 0
var checks := 0


func _ready() -> void:
	var deck := ""
	var core := false
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--deck="):
			deck = arg.trim_prefix("--deck=")
		elif arg == "--core":
			core = true
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	StationTheme.apply(get_tree().root, 22)
	LGInput.register_actions(GameConfig.ACTIONS)
	LGInput.extend_ui_actions()
	RenderingServer.global_shader_parameter_set("calm_walls", 1.0)
	Progress.in_memory = true
	Progress.load_progress()
	await get_tree().process_frame
	if only != "":
		printerr("- " + only)
		await call(only)
	elif deck != "":
		_test_unique_ids()
		await test_deck(deck)
	else:
		for t in ["_test_bloom", "_test_bloom_doors_and_light", "_test_bloom_roots", "_test_power", "_test_run",
				"_test_progress", "_test_progress_hours", "_test_gore_lock", "_test_settings_panel", "_test_launch_ping",
				"_test_creatures", "_test_shift", "_test_unique_ids", "_test_menus", "_test_deck_scene", "_test_combat",
				"_test_playtest"]:
			printerr("- " + t)
			await call(t)
		if not core:
			for id in Decks.ids():
				await test_deck(id)
	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A visit to a deck as a test run (no campaign), quiet, with the player at
## the lift. Free it with close_deck().
func open_deck(id: String, mode := "test") -> DeckScene:
	var s := DeckScene.new()
	s.deck_id = id
	s.mode = mode
	s.quiet = true
	get_tree().root.add_child(s)
	await frames(3)
	return s


func close_deck(s: DeckScene) -> void:
	get_tree().paused = false
	if is_instance_valid(s):
		s.queue_free()
	Gore.clear()
	await frames(3)


## Moves the player to a tile's centre (or a spot in it).
func put_player(s: DeckScene, cell: Vector2i, offset := Vector3.ZERO) -> void:
	s.player.global_position = DeckLevel.spot(cell, offset) + Vector3(0, 0.1, 0)
	s.player.velocity = Vector3.ZERO
	s.player.reset_physics_interpolation()
	await physics(2)


## Kills every heart on the deck and runs the Bloom until it's held (at most
## `ticks` ticks). True if it held.
func clear_deck(s: DeckScene, ticks := 200) -> bool:
	for h in s.director.hearts.duplicate():
		if is_instance_valid(h) and not h.dead:
			h.take_hit(Hit.make(Hit.Kind.BURN, 100000.0, h.global_position, Vector3.FORWARD, s.player))
	await frames(2)
	for i in ticks:
		s.tick_bloom()
		if s.run.held:
			return true
	return s.run.held

#region The Bloom

## A little grid for the Bloom: a row of rooms joined as asked.
func _strip(n: int, kinds: Array, seed := 7) -> Bloom:
	var b := Bloom.new(seed)
	for x in n:
		b.add_tile(Vector2i(x, 0), "r%d" % x)
	for x in n - 1:
		var k: Array = kinds[x] if x < kinds.size() else [Bloom.Kind.OPEN, Bloom.Door.OPEN]
		b.link(Vector2i(x, 0), Vector2i(x + 1, 0), k[0], k[1])
	return b


func _test_bloom() -> void:
	var b := _strip(8, [])
	b.add_root(Vector2i(0, 0))
	check(b.level_at(Vector2i(0, 0)) == Bloom.MAX, "a root starts at full growth")
	b.advance(200)
	check(b.level_at(Vector2i(7, 0)) > 1.0, "the Bloom spreads along open links (end at %.2f)" % b.level_at(Vector2i(7, 0)))
	check(b.coverage() > 0.9, "and covers the strip")
	# The same seed grows the same way.
	var a1 := _strip(8, [])
	var a2 := _strip(8, [])
	a1.add_root(Vector2i(0, 0))
	a2.add_root(Vector2i(0, 0))
	a1.advance(40)
	a2.advance(40)
	check(a1.growth == a2.growth, "the same seed grows the same way")
	# Burning.
	var gone := b.burn(Vector2i(3, 0), 1.5)
	check(is_equal_approx(gone, 1.5), "burning takes growth off")
	check(b.scorch[b.index[Vector2i(3, 0)]] > 0.9, "and scorches the tile")
	check(b.burn(Vector2i(20, 0), 1.0) == 0.0, "burning off the grid does nothing")
	# Venting.
	b.vent_room("r5")
	check(b.level_at(Vector2i(5, 0)) == 0.0, "venting a room clears it")
	b.advance(30)
	check(b.level_at(Vector2i(5, 0)) == 0.0, "and it stays clear while airless")
	# Pods only on thick growth.
	var p := _strip(3, [])
	p.add_root(Vector2i(0, 0))
	p.advance(600)
	var any := false
	for i in p.pods:
		any = true
		check(p.growth[i] >= Bloom.POD_WITHER, "pods only on thick growth")
	check(any, "thick growth sprouts pods in time")


func _test_bloom_doors_and_light() -> void:
	# Through a closed door it creeps; a sealed one stops it.
	var open := 0
	var closed := 0
	var sealed := 0
	for seed in 12:
		var bo := _strip(2, [], seed)
		var bc := _strip(2, [[Bloom.Kind.DOOR, Bloom.Door.CLOSED]], seed)
		var bs := _strip(2, [[Bloom.Kind.DOOR, Bloom.Door.SEALED]], seed)
		for b in [bo, bc, bs]:
			b.add_root(Vector2i(0, 0))
		for t in 30:
			for b in [bo, bc, bs]:
				b.step()
		open += 1 if bo.level_at(Vector2i(1, 0)) > 0.0 else 0
		closed += 1 if bc.level_at(Vector2i(1, 0)) > 0.0 else 0
		sealed += 1 if bs.level_at(Vector2i(1, 0)) > 0.0 else 0
	check(open > closed, "a closed door slows the Bloom (%d open, %d closed)" % [open, closed])
	check(sealed == 0, "a sealed door stops it")
	# Light slows the growth.
	var dark := _strip(2, [])
	var lit := _strip(2, [])
	for b in [dark, lit]:
		b.set_level(Vector2i(1, 0), 0.5)
		b.add_root(Vector2i(0, 0))
	lit.set_room_lit("r1", true)
	dark.advance(5)
	lit.advance(5)
	check(lit.level_at(Vector2i(1, 0)) < dark.level_at(Vector2i(1, 0)), "light slows the growth")
	# A flare lights its tile for a while.
	var f := _strip(2, [])
	f.add_flare(Vector2i(1, 0), 9.0)
	check(f.is_lit(1), "a flare lights its tile")
	f.advance(4)
	check(not f.is_lit(1), "and burns out")


func _test_bloom_roots() -> void:
	var b := _strip(6, [])
	b.add_root(Vector2i(0, 0))
	b.advance(120)
	check(not b.is_held(), "a deck with a living root isn't held")
	b.kill_root(Vector2i(0, 0))
	check(b.roots_alive() == 0, "the root is dead")
	var spread_after := b.coverage()
	b.advance(80)
	check(b.coverage() < spread_after, "cut off from its root, the growth dies back")
	check(b.is_held(), "and the deck is held once it's gone")
	# Growth cut off by a sealed door dies back even with the root alive.
	var s := _strip(3, [[Bloom.Kind.OPEN, Bloom.Door.OPEN], [Bloom.Kind.DOOR, Bloom.Door.OPEN]])
	s.add_root(Vector2i(0, 0))
	s.set_level(Vector2i(2, 0), 3.0)
	s.set_door(s.find_link(Vector2i(1, 0), Vector2i(2, 0)), Bloom.Door.SEALED)
	s.advance(10)
	check(s.level_at(Vector2i(2, 0)) < 3.0, "growth sealed off from the root dies back")

#endregion

#region Power, the run and progress

func _test_power() -> void:
	var p := Power.new(3)
	check(p.free_cells() == 3, "cells start free")
	check(p.take("lights:mess"), "taking a cell")
	check(p.has("lights:mess") and p.free_cells() == 2, "a cell in use")
	check(p.take("lights:mess"), "taking it again is fine")
	check(p.used() == 1, "and doesn't take two")
	p.take("door:a")
	p.take("turret:t1")
	check(not p.take("lift"), "no cell left for the lift")
	check(p.count("door") == 1 and p.count("lights") == 1, "counting by kind")
	p.give("door:a")
	check(p.take("lift"), "a freed cell can go elsewhere")
	p.add_cell()
	check(p.free_cells() == 1, "a spare cell adds one")


func _test_run() -> void:
	var lvl := Decks.make_level("hydroponics")
	var b := lvl.make_bloom()
	var run := DeckRun.new(lvl.deck)
	run.roots = lvl.root_cells.size()
	run.survivors_total = lvl.things_of("survivor").size()
	var objs := run.objectives(b)
	check(not objs.is_empty() and String(objs[0][0]).contains("root"), "the first job is the root")
	check(not run.check_held(b), "not held at the start")
	for c in lvl.root_cells:
		b.kill_root(c)
		run.cut_root()
	for i in b.cells.size():
		b.growth[i] = 0.0
	check(run.check_held(b), "held once the roots are cut and the growth is gone")
	check(not run.check_held(b), "it only becomes held once")
	run.read("log_a")
	run.read("log_a")
	check(run.logs.size() == 1, "a log counts once")
	var r := run.result({"weapons": ["cutter"]})
	check(r["held"] and r["loadout"]["weapons"] == ["cutter"], "the result carries what you hold")
	lvl.free()


func _test_progress() -> void:
	Progress.new_campaign()
	check(Progress.has_campaign(), "a new shift starts")
	check(Progress.deck_state("hydroponics") == "open", "Hydroponics is open")
	for m in Decks.MIDDLE:
		if Decks.has(m):
			check(Progress.deck_state(m) == "locked", "%s waits for Hydroponics" % m)
	var out := Progress.finish_deck("hydroponics", {"held": false})
	check(Progress.deck_state("hydroponics") == "open", "leaving it unheld keeps it open")
	out = Progress.finish_deck("hydroponics", {"held": true, "survivors": 1, "salvage": 5, "time": 300.0})
	check(Progress.deck_state("hydroponics") == "saved", "holding it saves it")
	check(Progress.salvage() == 5, "salvage is kept")
	for m in Decks.MIDDLE:
		if Decks.has(m):
			check(m in out["opened"], "%s opens after Hydroponics" % m)
	check(Progress.hour() == 0, "Hydroponics takes no hour")
	# Upgrades.
	check(not Progress.buy("suit"), "can't buy what you can't pay for")
	Progress._cfg.set_value("shift", "salvage", 20)
	check(Progress.buy("suit") and Progress.has_upgrade("suit"), "buying an upgrade")
	check(not Progress.buy("suit"), "only once")
	check(Progress.salvage() == 12, "it costs salvage")
	# Endings.
	Progress.set_ending("burn")
	check(Progress.ending() == "burn" and "burn" in Progress.endings_seen(), "an ending is kept")
	Progress.new_campaign()
	check(Progress.ending() == "" and "burn" in Progress.endings_seen(), "a new shift forgets the ending but not that you saw it")


func _test_progress_hours() -> void:
	Progress.new_campaign()
	Progress.finish_deck("hydroponics", {"held": true})
	var middle: Array = Decks.MIDDLE.filter(func(m): return Decks.has(m))
	if middle.size() < 2:
		check(true, "too few decks for the clock")
		return
	var first: String = middle[0]
	var hours := {}
	for m in middle:
		hours[m] = Progress.hours_left(m)
	Progress.finish_deck(first, {"held": true})
	check(Progress.hour() == 1, "a middle deck takes an hour")
	for m in middle:
		if m != first:
			check(Progress.hours_left(m) == maxi(0, hours[m] - 1) or Progress.deck_state(m) == "lost", "%s loses an hour" % m)
	check(Progress.hours_left(first) == hours[first], "the deck you went to keeps its hours")
	# A spare cell buys an hour.
	Progress._cfg.set_value("shift", "spare_cells", 1)
	var other: String = middle[1]
	if Progress.deck_state(other) == "open":
		var before := Progress.hours_left(other)
		check(Progress.assign_cell(other), "sending a spare cell")
		check(Progress.hours_left(other) == before + 1, "buys the deck an hour")
		check(not Progress.assign_cell(other), "one cell a deck")
	# Going back to a saved deck costs nothing.
	var h := Progress.hour()
	Progress.finish_deck(first, {"held": true})
	check(Progress.hour() == h, "visiting a saved deck takes no hour")
	# Run the clock out: every other deck is lost, and the Core opens. The
	# deck you're on never loses hours, so the last one open is held.
	for i in 24:
		var open: Array = middle.filter(func(m): return Progress.deck_state(m) == "open")
		if open.is_empty():
			break
		Progress.finish_deck(open[0], {"held": open.size() == 1})
	for m in middle:
		check(Progress.deck_state(m) in ["saved", "lost"], "%s is decided in the end" % m)
	if Decks.has("core"):
		check(Progress.deck_state("core") == "open", "the Core opens when the ring is decided")
	var lost: String = ""
	for m in middle:
		if Progress.deck_state(m) == "lost":
			lost = m
	if lost != "":
		Progress.finish_deck(lost, {"held": true})
		check(Progress.deck_state(lost) == "reclaimed", "a lost deck can be taken back")

#endregion

#region Settings

func _test_gore_lock() -> void:
	LGSettings.set_value("gore", "lock", "", false)
	LGSettings.set_value("gore", "level", "full", false)
	var ps := PlaySettings.make(480)
	add_child(ps)
	check(not PlaySettings.locked(), "the gore setting starts unlocked")
	ps._ask_code()
	ps._on_code("4321")
	check(PlaySettings.locked(), "a code locks it")
	ps._ask_code()
	ps._on_code("1111")
	check(PlaySettings.locked(), "the wrong code leaves it locked")
	ps._ask_code()
	ps._on_code("4321")
	check(not PlaySettings.locked(), "the right code unlocks it")
	LGSettings.set_value("gore", "level", "off", false)
	check(not Gore.shown(), "gore off shows none")
	LGSettings.set_value("gore", "level", "full", false)
	check(Gore.full(), "gore full")
	ps.queue_free()
	await frames(1)


func _test_settings_panel() -> void:
	var ps := PlaySettings.make(480)
	add_child(ps)
	var labels := []
	for c in ps.get_children():
		if c is Label:
			labels.append(c.text)
	for h in ["LOOKING", "COMFORT", "GORE", "DIFFICULTY"]:
		check(h in labels, "the settings have a %s group" % h.to_lower())
	check(float(LGSettings.get_value("play", "bob")) == 0.0, "head bob is off by default")
	check(not bool(LGSettings.get_value("play", "tilt")), "view roll is off by default")
	ps.queue_free()
	await frames(1)


func _test_launch_ping() -> void:
	var main := load("res://game/main.gd") as GDScript
	check(main.source_code.contains("LGLaunchPing.send(GameConfig.GAME_ID)"), "main sends the launch ping")
	check(GameConfig.GAME_ID == "hull-bloom", "the game id is hull-bloom")
	check(OnlineServer.SERVER_KEY == "defaultkey", "the server key in git is the default")

#endregion

#region Play testing

## The play test recorder: game events, a note, a death on a deck, the
## survey, the zip, and a session a crash cut short.
func _test_playtest() -> void:
	var dir := "user://test_playtest"
	LGPlaytestPack._remove(dir)
	var main := load("res://game/main.gd") as GDScript
	check(main.source_code.contains("LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)"), "main sets up play test recording")
	check((load("res://game/ui/title.gd") as GDScript).source_code.contains("LGScenes.quit()"), "quitting from the title ends a play test first")
	var p := LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)
	p.dir = dir
	await frames(2)
	check(p.is_inside_tree() and LGPlaytest.current() == p, "the recorder joins the tree")
	check(not LGPlaytest.recording(), "nothing is recorded until asked")
	var button := LGPlaytestButton.make()
	add_child(button)
	check(not button.visible, "Note this moment is hidden with no play test")
	p.begin()
	check(LGPlaytest.recording() and button.visible, "a play test records, and pause menus can note moments")
	button.queue_free()
	var panel := SettingsPanel.new()
	add_child(panel)
	await frames(1)
	var row := false
	for c in panel.get_children():
		row = row or (c is LGCycler and (c as LGCycler).label_text == "Play test recording")
	check(row, "the settings have a Play test recording row")
	panel.queue_free()
	LGPlaytest.event("test", {"at": Vector3(1, 2, 3)})
	p.open_note()
	await frames(1)
	var note: LGPlaytestNote = p.find_children("*", "LGPlaytestNote", true, false).front()
	check(note != null and get_tree().paused, "F8 asks what's happening, and pauses a game nobody else is in")
	note.note.text = "  the vent hissed  "
	note.pick("fun")
	await frames(1)
	check(not get_tree().paused, "the game carries on after the note")
	var s := await open_deck("hydroponics")
	s.player.die("killed")
	await frames(3)
	await close_deck(s)
	p._next_perf = 0.0
	await frames(2)
	p.finish("quit")
	await frames(1)
	var survey: LGPlaytestSurvey = p.find_children("*", "LGPlaytestSurvey", true, false).front()
	check(survey != null, "finishing asks the survey")
	for q in ["fun", "story", "tense", "first_minutes", "best", "name"]:
		check(q in survey.questions(), "the survey asks " + q)
	survey.set_answer("fun", 4)
	survey.set_answer("best", "Burning the first Heart")
	survey.set_answer("genre", "often")
	survey.submit()
	await frames(2)
	var card: LGPlaytestCard = p.find_children("*", "LGPlaytestCard", true, false).front()
	check(card != null and "Quit" in card.button_texts(), "then says where the play test went")
	check(not LGPlaytest.recording(), "and stops recording")
	card.close("done")
	await frames(2)
	check(not get_tree().paused, "the game isn't left paused")
	var zips := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".zip"))
	check(zips.size() == 1 and zips[0].begins_with("hull-bloom-playtest-"), "one zip, named for the game")
	var r := ZIPReader.new()
	r.open(dir.path_join(zips[0]))
	var files := r.get_files()
	for f in ["session.json", "events.jsonl", "survey.json"]:
		check(f in files, "the zip holds " + f)
	var info: Dictionary = JSON.parse_string(r.read_file("session.json").get_string_from_utf8())
	check(info.get("game") == "hull-bloom" and info.get("ended_how") == "quit" and int(info.get("marks", 0)) == 1, "session.json says what was played and how it ended")
	check(info.has("settings") and not info["settings"].get("online", {}).has("server_key"), "the server key never goes in a recording")
	var types := []
	var mark := {}
	var died := {}
	for line in r.read_file("events.jsonl").get_string_from_utf8().split("\n", false):
		var e: Dictionary = JSON.parse_string(line)
		types.append(e["type"])
		if e["type"] == "mark":
			mark = e
		elif e["type"] == "died":
			died = e
	for t in ["start", "test", "mark", "deck_start", "died", "perf", "survey", "end"]:
		check(t in types, "the events hold " + t)
	check(mark.get("tag") == "fun" and mark.get("note") == "the vent hissed", "a note keeps its tag and words")
	var answers: Dictionary = JSON.parse_string(r.read_file("survey.json").get_string_from_utf8())
	check(answers.get("fun") == 4.0 and answers.get("best") == "Burning the first Heart" and answers.get("genre") == "often" and not answers.has("story"),
		"the survey keeps only what was answered")
	check(died.get("moment") == true, "a moment is marked as one in the events")
	var asked: Dictionary = answers.get("questions", {})
	check(asked.get("fun") == LGPlaytestSurvey.RATINGS[0][1] and asked.has("story") and asked.has("tense"),
		"the survey keeps the wording of every question asked")
	r.close()
	# A session the game never ended: packed the next time it starts.
	var cut := dir.path_join("2026-01-01-000000")
	DirAccess.make_dir_recursive_absolute(cut)
	LGPlaytestPack.write_json(cut.path_join("session.json"), {"game": "hull-bloom"})
	FileAccess.open(cut.path_join("events.jsonl"), FileAccess.WRITE).store_line("{}")
	var recovered := LGPlaytestPack.recover(dir)
	check(recovered.size() == 1 and not DirAccess.dir_exists_absolute(cut), "a session a crash cut short is packed")
	r.open(recovered[0])
	var cut_info: Dictionary = JSON.parse_string(r.read_file("session.json").get_string_from_utf8())
	check(cut_info.get("ended_how") == "suddenly", "and marked as ended suddenly")
	r.close()
	p.queue_free()
	await frames(1)
	LGPlaytestPack._remove(dir)

#endregion

#region Creatures, combat and a visit

func _test_creatures() -> void:
	var lvl := Decks.make_level("hydroponics")
	add_child(lvl)
	lvl.finish()
	for what in Creatures.KINDS:
		var c := Creatures.make(what)
		c.setup(lvl, DeckLevel.center(lvl.lift_cell), true)
		lvl.add_child(c)
		await frames(2)
		check(c.health > 0.0 and c.max_health > 0.0, "%s has health" % what)
		check(c.model != null, "%s has a model" % what)
		c.take_hit(Hit.make(Hit.Kind.BULLET, 100000.0, c.global_position + Vector3(0, 1, 0), Vector3.FORWARD))
		await frames(2)
		check(not is_instance_valid(c) or c.dead, "%s dies" % what)
	lvl.queue_free()
	Gore.clear()
	await frames(3)


func _test_deck_scene() -> void:
	var s := await open_deck("hydroponics")
	check(DeckScene.current == s, "the deck is current")
	check(s.player != null and s.player.is_inside_tree(), "the tech is on the deck")
	check(s.power.free_cells() == s.deck.cells, "every cell starts free")
	check(not s.run.held, "the deck isn't held at the start")
	# Lights: a cell each, and the growth slows there.
	var room: String = s.level.room_ids[0]
	check(s.toggle_lights(room), "lights take a cell")
	check(s.power.has("lights:" + room), "the room has power")
	s.toggle_lights(room)
	check(not s.power.has("lights:" + room), "and give it back")
	# The lift wants a cell before it goes.
	s._on_lift_used()
	check(s.lift.powered, "the lift takes a cell")
	check(s.power.has("lift"), "the lift holds its cell")
	# Bloom ticks run the director.
	for i in 5:
		s.tick_bloom()
	check(s.level.bloom.ticks == 5, "the Bloom ticks")
	check(await clear_deck(s), "cutting the roots holds the deck")
	check(s.run.roots_cut == s.run.roots, "every root is counted")
	s.leave()
	check(s.run.over, "leaving ends the visit")
	check(s.results.visible, "the results show")
	check(s.results.line_texts().size() > 0, "with lines")
	await close_deck(s)


func _test_combat() -> void:
	var s := await open_deck("hydroponics")
	var cell := s.level.lift_cell
	await put_player(s, cell)
	var forward := -s.player.camera.global_transform.basis.z
	var at := s.player.global_position + Vector3(forward.x, 0, forward.z).normalized() * 4.0
	var sk := s.director.spawn("skitter", at, false)
	await physics(4)
	check(sk != null and not sk.dead, "a skitter appears")
	var before := s.run.kills
	sk.take_hit(Hit.make(Hit.Kind.BULLET, 1000.0, sk.global_position + Vector3(0, 0.3, 0), forward, s.player))
	await frames(2)
	check(not is_instance_valid(sk) or sk.dead, "the skitter dies")
	check(s.run.kills == before + 1, "a kill is counted")
	# The cutter heats as it fires and cools when you stop.
	var ars := s.player.arsenal
	ars.select("cutter")
	await frames(30)
	Input.action_press("action_primary")
	await frames(30)
	check(ars.heat > 0.0, "the cutter heats as it fires")
	Input.action_release("action_primary")
	var hot := ars.heat
	await frames(60)
	check(ars.heat < hot, "and cools")
	# A health tube with the suit whole stays put, and says why.
	check(not s.player.take_pickup("health", 1), "a whole suit leaves a health tube")
	check("Suit's whole. Leave it for later" in s.hud.toast_lines(), "and says why")
	# Getting hurt, and the Bloom getting in.
	var suit := s.player.health
	s.player.take_hit(Hit.make(Hit.Kind.CLAW, 10.0, s.player.global_position, forward))
	check(s.player.health < suit, "the suit takes damage")
	check(s.player.infection > 0.0, "claws carry the Bloom in")
	# Dropping low with a medkit in your pocket says how to use it.
	s.player.items["medkit"] = 1
	s.player.take_hit(Hit.make(Hit.Kind.BULLET, s.player.health - s.player.max_health * 0.3, s.player.global_position, forward))
	check(Array(s.hud.toast_lines()).any(_is_medkit_reminder), "a low suit reminds you of your medkit")
	var sk2 := s.director.spawn("skitter", at, false)
	await physics(2)
	s.player.take_hit(Hit.make(Hit.Kind.CLAW, 1000.0, s.player.global_position, forward, sk2))
	check(s.player.is_dead, "too much and you're down")
	check(s.player.last_hit_by == "skitter" and DeckScene.DOWNED_BY.has("skitter"), "and you're told what got you")
	await frames(2)
	await close_deck(s)


func _is_medkit_reminder(line: String) -> bool:
	return line.begins_with("Suit low:")

#endregion

#region Menus and Shift

func _test_menus() -> void:
	for path in ["res://game/ui/title.tscn", "res://game/ui/ring_map.tscn", "res://game/ui/ending.tscn"]:
		check(ResourceLoader.exists(path), "%s exists" % path.get_file())
	if ResourceLoader.exists("res://game/ui/menu_tests.gd"):
		await (load("res://game/ui/menu_tests.gd").new()).run(self)


func _test_shift() -> void:
	if ResourceLoader.exists("res://game/shift/shift_tests.gd"):
		await (load("res://game/shift/shift_tests.gd").new()).run(self)
	else:
		check(ShiftNight.daily_seed() > 20260000, "the daily seed is a date")

#endregion

#region Decks

## No two decks share a log or survivor id.
func _test_unique_ids() -> void:
	var seen := {}
	for id in Decks.ids():
		var lvl := Decks.make_level(id)
		for kind in ["log", "survivor"]:
			for t in lvl.things_of(kind):
				var key := "%s:%s" % [kind, t[4]["id"]]
				check(not seen.has(key), "%s %s is used once (%s and %s)" % [kind, t[4]["id"], seen.get(key, ""), id])
				seen[key] = id
		lvl.free()


## Everything every deck must have, then a visit, then its own tests.
func test_deck(id: String) -> void:
	printerr("- deck " + id)
	_test_deck_data(id)
	_test_deck_layout(id)
	_test_deck_balance(id)
	await _test_deck_visit(id)
	var path := DECK_TESTS % [id, id]
	check(ResourceLoader.exists(path), "%s has its own tests" % id)
	if ResourceLoader.exists(path):
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "%s's tests compile" % id)
		if script and script.can_instantiate():
			await script.new().run(self)


func _test_deck_data(id: String) -> void:
	var d := Decks.get_deck(id)
	check(d.name != "", "%s has a name" % id)
	check(d.number == Decks.ORDER.find(id) + 1, "%s is deck %d" % [id, Decks.ORDER.find(id) + 1])
	check(d.blurb != "" and not d.news.is_empty(), "%s has a blurb and news for the ring map" % id)
	check(d.cells >= 2 and d.cells <= 8, "%s has 2 to 8 cells" % id)
	check(d.arrive != "" and d.held != "", "%s has MARI's lines" % id)
	check(d.gives in GIFTS, "%s gives something known" % id)
	check((d.hours > 0) == (id in Decks.MIDDLE), "%s holds out for hours only if it's on the ring" % id)
	for k in d.hatches:
		check(k in Creatures.KINDS and float(d.hatches[k]) > 0.0, "%s hatches %s" % [id, k])
	check(d.music == "" or ResourceLoader.exists("res://assets/audio/music/%s.ogg" % d.music) or true, "%s music" % id)


func _test_deck_layout(id: String) -> void:
	var lvl := Decks.make_level(id)
	check(lvl.tiles.has(lvl.lift_cell), "%s: the lift is on a tile" % id)
	var reach := lvl.reachable(lvl.lift_cell, true)
	for c in lvl.tiles:
		check(reach.has(c) or _vent_only(lvl, c, reach), "%s: tile %s can be reached from the lift" % [id, c])
	check(not lvl.root_cells.is_empty() or id == "core", "%s has a root" % id)
	for c in lvl.root_cells:
		check(reach.has(c), "%s: the root at %s can be reached" % [id, c])
	for t in lvl.things:
		check(lvl.tiles.has(t[1]), "%s: %s at %s is on a tile" % [id, t[0], t[1]])
		match String(t[0]):
			"spawn":
				var what := String(t[4]["what"])
				check(what in Creatures.KINDS or what == "pod", "%s: spawns a known creature (%s)" % [id, what])
			"log":
				check(String(t[4]["title"]) != "" and String(t[4]["text"]).length() > 40, "%s: log %s has words" % [id, t[4]["id"]])
			"survivor":
				check(String(t[4]["name"]) != "" and String(t[4]["line"]) != "", "%s: survivor %s speaks" % [id, t[4]["id"]])
	check(lvl.things_of("log").size() >= 3, "%s has at least three logs" % id)
	check(lvl.views.size() >= 6, "%s has at least six views (%d)" % [id, lvl.views.size()])
	for v in lvl.views:
		var p: Vector3 = lvl.views[v][0]
		check(lvl.tiles.has(DeckLevel.cell_at(p)), "%s: view %s stands on a tile" % [id, v])
	var b := lvl.make_bloom()
	check(b.cells.size() == lvl.tiles.size(), "%s: the Bloom has every tile" % id)
	check(b.roots.size() == lvl.root_cells.size(), "%s: the Bloom has every root" % id)
	lvl.free()


func _vent_only(lvl: DeckLevel, c: Vector2i, reach: Dictionary) -> bool:
	# A space reached only through a vent counts if a vent leads there.
	for v in lvl.vents:
		if (v[0] == c and reach.has(v[1])) or (v[1] == c and reach.has(v[0])):
			return true
	return false


## How fast the Bloom takes the deck with nobody there: printed for tuning,
## and checked so no deck is lost before you can reach the root.
func _test_deck_balance(id: String) -> void:
	var lvl := Decks.make_level(id)
	var b := lvl.make_bloom()
	b.speed = lvl.deck.spread
	var line := "%s: coverage %.0f%%" % [id, b.coverage() * 100.0]
	for minute in [2, 5, 10]:
		while b.ticks < minute * 60 / int(Bloom.TICK):
			b.step()
		line += ", %d min %.0f%%" % [minute, b.coverage() * 100.0]
		if minute == 5:
			check(b.coverage() <= MAX_COVERAGE_5MIN or lvl.deck.id == "core", "%s isn't overgrown in five minutes (%.0f%%)" % [id, b.coverage() * 100.0])
	print(line)
	lvl.free()


func _test_deck_visit(id: String) -> void:
	var s := await open_deck(id)
	check(s.level.built, "%s builds" % id)
	check(s.player.global_position.y > -0.5 and s.player.global_position.y < 1.5, "%s: the tech stands on the floor (at %s)" % [id, s.player.global_position])
	await physics(30)
	check(s.player.global_position.y > -0.5, "%s: and doesn't fall through it (at %s)" % [id, s.player.global_position])
	check(s.director.hearts.size() == s.level.root_cells.size() or id == "core", "%s: a heart at every root" % id)
	check(s.director.alive() <= s.deck.max_alive + s.level.things_of("spawn").size() * 3, "%s: not too many creatures" % id)
	for i in 20:
		s.tick_bloom()
	check(await clear_deck(s, 300), "%s: cutting the roots holds it" % id)
	await close_deck(s)

#endregion
