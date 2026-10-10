extends RefCounted
## Shift mode's tests, run by tests/run_tests.gd: stations from seeds are
## sound (every tile reachable, a root, a loop), the same seed builds the same
## station, a night counts its score, and a deck of one plays.

const SEEDS := [1, 7, 42, 20261010, 999983]


func run(t: Node) -> void:
	t.check(ShiftNight.daily_seed() > 20260000, "the daily seed is a date")
	for s in SEEDS:
		var night := ShiftNight.make(s)
		t.check(night.decks.size() == ShiftNight.DECKS, "seed %d: %d decks" % [s, ShiftNight.DECKS])
		for d in night.decks:
			var lvl: DeckLevel = load(d.level).new()
			lvl.deck = d
			lvl.build()
			var reach := lvl.reachable(lvl.lift_cell, true)
			t.check(reach.size() == lvl.tiles.size(), "seed %d %s: every tile can be reached (%d of %d)" % [s, d.name, reach.size(), lvl.tiles.size()])
			t.check(lvl.root_cells.size() == 1 and reach.has(lvl.root_cells[0]), "seed %d %s: a root that can be reached" % [s, d.name])
			# The loop: with the spine's door to the nest shut for good, the
			# outer corridor still gets there.
			var top := lvl.root_cells[0]
			var spine_end := Vector2i(0, top.y + 1)
			lvl.ways.erase(DeckLevel.edge_key(spine_end, Vector2i(0, top.y)))
			t.check(lvl.reachable(lvl.lift_cell, true).has(top), "seed %d %s: a second way to the nest" % [s, d.name])
			for v in lvl.views:
				t.check(lvl.tiles.has(DeckLevel.cell_at(lvl.views[v][0])), "seed %d %s: view %s on a tile" % [s, d.name, v])
			var b := lvl.make_bloom()
			b.speed = d.spread
			b.advance(100)
			t.check(b.coverage() < 0.9, "seed %d %s: not overgrown in five minutes (%.0f%%)" % [s, d.name, b.coverage() * 100.0])
			lvl.free()
	# The same seed, the same station.
	var a := ShiftNight.make(42)
	var b2 := ShiftNight.make(42)
	t.check(a.decks[0].name == b2.decks[0].name and a.decks[0].seed == b2.decks[0].seed, "the same seed makes the same night")
	# A deck played: its score.
	var night := ShiftNight.make(5)
	ShiftNight.current = night
	var s: DeckScene = DeckScene.new()
	s.deck_id = night.decks[0].id
	s.custom_deck = night.decks[0]
	s.custom_level = load(night.decks[0].level)
	s.night = night
	s.mode = "shift"
	s.quiet = true
	t.get_tree().root.add_child(s)
	await t.frames(3)
	t.check(s.player.arsenal.owned.has("scattergun"), "a night starts with the scattergun")
	t.check(await t.clear_deck(s, 300), "a Shift deck can be held")
	s.run.kills = 4
	s.leave()
	await t.frames(2)
	t.check(night.results.size() == 1 and night.results[0]["held"], "the night counts the deck as held")
	t.check(night.score() >= ShiftNight.HELD + 4 * ShiftNight.KILL, "and scores it (%d)" % night.score())
	t.check(night.index == 1, "and moves on to the next deck")
	t.check(s.results.visible and Array(s.results.button_texts()).any(func(x): return x.begins_with("Next deck")), "the results offer the next deck")
	ShiftNight.current = null
	await t.close_deck(s)
