extends RefCounted
## The menus' tests, run by tests/run_tests.gd: the title, the ring map and
## the endings, each built as a plain child with progress in memory.


func run(t: Node) -> void:
	await _title(t)
	await _ring(t)
	await _endings(t)


func _title(t: Node) -> void:
	Progress.reset()
	var title: Node = load("res://game/ui/title.tscn").instantiate()
	t.add_child(title)
	await t.frames(3)
	var b: PackedStringArray = title.button_texts()
	t.check("New night shift" in b, "the title offers a new shift")
	t.check(not Array(b).any(func(x): return x.begins_with("Carry on")), "no carrying on without a shift")
	Progress.new_campaign()
	title.show_main()
	await t.frames(1)
	t.check(Array(title.button_texts()).any(func(x): return x.begins_with("Carry on")), "carry on once a shift has started")
	title.show_shift()
	await t.frames(1)
	t.check(not Array(title.button_texts()).any(func(x): return x.begins_with("Tonight")), "Shift mode waits for an ending")
	for i in HowToPlay.PAGES.size():
		title.show_how(i)
		await t.frames(1)
	title.show_settings()
	await t.frames(2)
	t.check(title.find_children("", "PlaySettings", true, false).size() == 1, "the title's settings have the game's own")
	title.show_story()
	await t.frames(1)
	t.check("Go to Hydroponics" in title.button_texts(), "the story leads to Hydroponics")
	title.queue_free()
	await t.frames(2)


func _ring(t: Node) -> void:
	Progress.new_campaign()
	var ring: Node = load("res://game/ui/ring_map.tscn").instantiate()
	t.add_child(ring)
	await t.frames(3)
	var b: PackedStringArray = ring.button_texts()
	t.check(Array(b).any(func(x): return x.contains("Hydroponics") and x.contains("open")), "Hydroponics is open on the ring")
	ring.select("hydroponics")
	t.check("Go to Hydroponics" in ring.button_texts(), "and can be gone to")
	if Decks.has("crew"):
		ring.select("crew")
		t.check(ring.briefing_text().contains("Locked"), "the ring's decks wait for Hydroponics")
		t.check(not ring.button_texts().has("Go to Crew quarters"), "a locked deck has no way in")
		Progress.finish_deck("hydroponics", {"held": true})
		Progress._cfg.set_value("shift", "spare_cells", 1)
		ring.refresh()
		ring.select("crew")
		t.check(ring.briefing_text().contains("hours before the Bloom"), "an open deck shows its hours")
		t.check("Send a spare cell" in ring.button_texts(), "a spare cell can be sent")
		var before := Progress.hours_left("crew")
		ring._send_cell("crew")
		t.check(Progress.hours_left("crew") == before + 1, "sending one buys an hour")
	ring.queue_free()
	await t.frames(2)


func _endings(t: Node) -> void:
	Progress.new_campaign()
	for m in Decks.MIDDLE:
		if Decks.has(m):
			var d := Progress._deck(m)
			d["state"] = "lost"
			Progress._set_deck(m, d)
	t.check(EndingScreen.which() == "stay", "no shuttle: you stay")
	if Decks.has("cargo"):
		var d := Progress._deck("cargo")
		d["state"] = "saved"
		Progress._set_deck("cargo", d)
		t.check(EndingScreen.which() == "", "with the shuttle you choose")
		for m in Decks.MIDDLE:
			var md := Progress._deck(m)
			md["state"] = "saved"
			Progress._set_deck(m, md)
		t.check(EndingScreen.which() == "both", "every deck held: both")
	var e: Node = load("res://game/ui/ending.tscn").instantiate()
	t.add_child(e)
	await t.frames(3)
	t.check(Progress.ending() != "" or "Take the shuttle home" in e.button_texts(), "the ending is chosen or offered")
	e.show_ending("stay")
	await t.frames(1)
	t.check(Progress.ending() == "stay" and "stay" in Progress.endings_seen(), "the ending is kept")
	t.check(ShiftNight.unlocked(), "and Shift mode opens")
	e.queue_free()
	await t.frames(2)
