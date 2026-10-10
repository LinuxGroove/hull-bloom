extends RefCounted
## Engineering's own tests, run by tests/run_tests.gd after the checks every
## deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.


func run(t: Node) -> void:
	var lvl := Decks.make_level("engineering")
	var d := lvl.deck
	# The power plant: more cells than Hydroponics, spare cells to find, and
	# the gift is power.
	t.check(d.cells > Decks.get_deck("hydroponics").cells, "engineering: more cells than Hydroponics (%d)" % d.cells)
	t.check(d.gives == "power", "engineering: saving it gives power")
	var reach := lvl.reachable(lvl.lift_cell, true)
	var spares := 0
	for p in lvl.things_of("pickup"):
		if p[4]["item"] == "cell" and reach.has(p[1]):
			spares += 1
	t.check(spares >= 2, "engineering: spare cells on the deck, reachable from the lift (%d)" % spares)
	# The way in: lift, gangway, reactor hall, then the jammed door to the core.
	var path := lvl.tile_path(lvl.lift_cell, lvl.root_cells[0], true)
	t.check(not path.is_empty(), "engineering: a way from the lift to the root")
	t.check(lvl.tiles.get(lvl.root_cells[0], "") == "core", "engineering: the root is in the reactor core")
	var through_hall := false
	for step in path:
		if lvl.tiles.get(step[0], "") == "reactor":
			through_hall = true
	t.check(through_hall, "engineering: the way to the root goes through the reactor hall")
	# The long gangway the Stalkers hear down, with a bulkhead halfway to shut.
	var gangway: Array = lvl.rooms["gangway_w"]["cells"] + lvl.rooms["gangway_e"]["cells"]
	var row := true
	for c in gangway:
		row = row and c.y == gangway[0].y
	t.check(row and gangway.size() >= 10, "engineering: the gangway is one long straight run (%d tiles)" % gangway.size())
	t.check(String(lvl.ways.get(DeckLevel.edge_key(Vector2i(-1, -3), Vector2i(0, -3)), {}).get("kind", "")) == "door", "engineering: a bulkhead halfway along the gangway")
	# Stalkers: placed here, and hatched here.
	var stalkers := 0
	for s in lvl.things_of("spawn"):
		if s[4]["what"] == "stalker":
			stalkers += int(s[4]["count"])
	t.check(stalkers >= 2, "engineering: Stalkers on the deck (%d)" % stalkers)
	t.check(float(d.hatches.get("stalker", 0.0)) > 0.0, "engineering: its pods hatch Stalkers")
	lvl.free()
	# On the deck: the crawlway's Stalker sleeps through a run past its shut
	# hatch, and hears the same run once the hatch is open.
	var s: DeckScene = await t.open_deck("engineering")
	var crawler: Creature = null
	var count := 0
	for c in s.director.get_children():
		if c is Creature and c.kind == "stalker":
			count += 1
			if DeckLevel.cell_at(c.global_position) == Vector2i(6, -3):
				crawler = c
	t.check(count >= 2, "engineering: the Stalkers are on the deck (%d)" % count)
	t.check(crawler != null and crawler.state == Creature.State.ASLEEP, "engineering: a Stalker sleeps behind the crawlway hatch")
	if crawler:
		var noise := DeckLevel.center(Vector2i(2, -3)) + Vector3(0, 0.1, 0)
		await t.physics(2)
		Noises.make(s, noise, StepNoise.SPRINT, s.player)
		t.check(crawler.state == Creature.State.ASLEEP, "engineering: a shut hatch keeps a run down the gangway from it")
		var hatch: Bulkhead = s.level.doors[DeckLevel.edge_key(Vector2i(5, -3), Vector2i(6, -3))]
		hatch.set_open(true)
		await t.physics(50)
		Noises.make(s, noise, StepNoise.SPRINT, s.player)
		t.check(crawler.state != Creature.State.ASLEEP, "engineering: with the hatch open it hears you coming")
	t.check(s.power.free_cells() == d.cells, "engineering: the deck starts with its %d cells" % d.cells)
	await t.close_deck(s)
