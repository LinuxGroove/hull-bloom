extends RefCounted
## The Core's own tests, run by tests/run_tests.gd after the checks every
## deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.

const LEVEL := preload("res://game/decks/core/core_level.gd")


func run(t: Node) -> void:
	var lvl := Decks.make_level("core")
	# The Heart's root: the middle of the sample chamber.
	t.check(lvl.root_cells.size() == 1, "core: one root, the Heart's")
	var root: Vector2i = lvl.root_cells[0] if not lvl.root_cells.is_empty() else LEVEL.ROOT
	t.check(lvl.tiles.get(root, "") == "chamber", "core: the root is in the sample chamber")
	t.check(lvl.start_growth.get(root, 0.0) >= 4.0, "core: the chamber starts overgrown")
	# The ring: two ways round to the chamber, so sealing either bulkhead
	# where the south ring meets the others still leaves a way to the Heart.
	t.check(not lvl.tile_path(lvl.lift_cell, root, true).is_empty(), "core: a way from the lift to the Heart")
	var via := []
	for d in LEVEL.RING_DOORS:
		var w: Dictionary = lvl.ways.get(DeckLevel.edge_key(d[0], d[1]), {})
		t.check(w.get("kind", "") == "door", "core: a bulkhead on the ring at %s" % d[0])
		w["sealed"] = true
		var path := lvl.tile_path(lvl.lift_cell, root, true)
		t.check(not path.is_empty(), "core: with the ring door at %s sealed, the other way round reaches the Heart" % d[0])
		via.append(_rooms_on(lvl, path))
		w.erase("sealed")
	if via.size() == 2:
		t.check("conduits" in via[0] and "decon" in via[1], "core: the two ways come at the Heart from either side (%s, %s)" % via)
	for d in LEVEL.RING_DOORS:
		lvl.ways[DeckLevel.edge_key(d[0], d[1])]["sealed"] = true
	t.check(lvl.tile_path(lvl.lift_cell, root, true).is_empty(), "core: with both sealed there's no way round")
	for d in LEVEL.RING_DOORS:
		lvl.ways[DeckLevel.edge_key(d[0], d[1])].erase("sealed")
	# MARI's own log, in her server hall.
	var mari := false
	for l in lvl.things_of("log"):
		if l[4]["id"] == "core_mari":
			mari = lvl.tiles.get(l[1], "") == "mari" and l[4]["by"] == "MARI"
	t.check(mari, "core: MARI's own log is in the MARI core")
	# Everything the Bloom has, and Dr Okafor among the Taken.
	var kinds := {}
	var okafor := false
	for s in lvl.things_of("spawn"):
		kinds[s[4]["what"]] = true
		if s[4]["what"] == "taken" and s[4].get("job", "") == "science" and lvl.tiles.get(s[1], "") == "chamber":
			okafor = true
	for k in ["pod", "skitter", "stalker", "feeder", "watcher", "taken"]:
		t.check(kinds.has(k), "core: %s on the deck" % k)
	t.check(okafor, "core: Dr Okafor walks the chamber, Taken")
	var b := lvl.make_bloom()
	t.check(b.coverage() >= 0.4 and b.coverage() <= 0.6, "core: the heaviest start, but not all of it (%.0f%%)" % (b.coverage() * 100.0))
	lvl.free()
	# A campaign visit: the Heart is the Core's, and killing it and freezing
	# out what's left holds the deck and offers the ending.
	Progress.new_campaign()
	var cd: Dictionary = Progress._deck("core")
	cd["state"] = "open"
	Progress._set_deck("core", cd)
	var s: DeckScene = await t.open_deck("core", "campaign")
	t.check(s.director.hearts.size() == 1, "core: the Heart is on the deck")
	if not s.director.hearts.is_empty():
		var h: Heart = s.director.hearts[0]
		t.check(h.big, "core: it's the Core's own Heart")
		t.check(h.cell == root and s.level.tiles.get(h.cell, "") == "chamber", "core: the Heart sits at the root in the sample chamber")
	t.check(s.hud.subtitle_text().contains("Core"), "core: MARI speaks on arrival")
	t.check(not s.run.held, "core: not held at the start")
	# Its spit leaves from under the chamber's ceiling, so it can reach you.
	if not s.director.hearts.is_empty():
		await t.put_player(s, Vector2i(-1, 0), Vector3(-1.0, 0, 0))
		s.director.hearts[0]._spit_t = 0.0
		await t.frames(2)
		var spits := s.get_tree().current_scene.get_children().filter(_is_spit)
		t.check(not spits.is_empty() and spits.all(_under_ceiling), "core: the Heart's spit flies under the ceiling (%d)" % spits.size())
	t.check(await t.clear_deck(s, 300), "core: killing the Heart and freezing out the rest holds the deck")
	t.check(s.run.roots_cut == 1, "core: the Heart counts as its root")
	s.leave()
	t.check("See how it ends" in s.results.button_texts(), "core: holding it offers the ending")
	await t.close_deck(s)
	Progress.new_campaign()


func _is_spit(n: Node) -> bool:
	return n is Spit


func _under_ceiling(n: Node) -> bool:
	return (n as Spit).global_position.y < Kit.HEIGHT


func _rooms_on(lvl: DeckLevel, path: Array) -> Array:
	var out := []
	for step in path:
		var r: String = lvl.tiles.get(step[0], "")
		if not r in out:
			out.append(r)
	return out
