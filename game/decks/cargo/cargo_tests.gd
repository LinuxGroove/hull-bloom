extends RefCounted
## Cargo and docking's own tests, run by tests/run_tests.gd after the checks
## every deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck()
## and so on.


func run(t: Node) -> void:
	var lvl := Decks.make_level("cargo")
	t.check(lvl.deck.gives == "shuttle", "cargo: saving it gives the shuttle")
	# Two big open bays.
	for id in ["bay1", "bay2"]:
		var r := Rect2i()
		var cells: Array = lvl.rooms[id]["cells"]
		for i in cells.size():
			r = Rect2i(cells[i], Vector2i.ONE) if i == 0 else r.expand(cells[i]).expand(cells[i] + Vector2i.ONE)
		t.check(cells.size() >= 12 and r.size.x >= 3 and r.size.y >= 3 and r.get_area() == cells.size(), "cargo: %s is a big open bay (%s)" % [id, r.size])
	t.check(lvl.tiles.get(lvl.root_cells[0], "") == "bay2", "cargo: the root is in loading bay 2")
	# The dock: reached from the lift, looking out through windows.
	var dock: Array = lvl.rooms["dock"]["cells"]
	t.check(lvl.rooms["dock"]["style"] == "window", "cargo: the dock's walls are windows")
	t.check(not lvl.tile_path(lvl.lift_cell, dock[0], true).is_empty(), "cargo: the dock can be reached from the lift")
	var windows := 0
	for key in lvl.ways:
		var w: Dictionary = lvl.ways[key]
		if w["kind"] == "window" and (w["a"] in dock or w["b"] in dock):
			windows += 1
	t.check(windows >= 2, "cargo: the office and the dock walk look into the dock (%d)" % windows)
	# Who's here: Raptors and Stalkers in the bays, a survivor at the shuttle.
	var in_bays := {"raptor": 0, "stalker": 0}
	for s in lvl.things_of("spawn"):
		var what: String = s[4]["what"]
		if in_bays.has(what) and String(lvl.tiles.get(s[1], "")).begins_with("bay"):
			in_bays[what] += 1
	t.check(in_bays["raptor"] >= 1 and in_bays["stalker"] >= 2, "cargo: Raptors and Stalkers in the bays (%s)" % in_bays)
	var at_dock := false
	for s in lvl.things_of("survivor"):
		at_dock = at_dock or lvl.tiles.get(s[1], "") == "dock"
	t.check(at_dock, "cargo: someone waits at the shuttle")
	# The cold store is cold.
	var b := lvl.make_bloom()
	var i: int = b.index[lvl.rooms["cold"]["cells"][0]]
	t.check(b.mult[i] < 1.0, "cargo: the Bloom grows slower in the cold store")
	lvl.free()
	# On the deck: the shuttle stands in the dock, bay security is awake, and
	# venting bay 1 still leaves a way to the dock, the office and the cold store.
	var sc: DeckScene = await t.open_deck("cargo")
	var shuttle := sc.level.get_node_or_null("Shuttle") as Node3D
	t.check(shuttle != null and sc.level.tiles.get(DeckLevel.cell_at(shuttle.global_position), "") == "dock", "cargo: the shuttle is in the dock")
	var raptors := 0
	for c in sc.director.get_children():
		if c is Creature and c.kind == "raptor":
			raptors += 1
	t.check(raptors >= 2, "cargo: the Raptors are on the deck (%d)" % raptors)
	var panel := false
	for v in t.get_tree().get_nodes_in_group("vent_panels"):
		panel = panel or (v as VentPanel).room_id == "bay1"
	t.check(panel, "cargo: bay 1 has an emergency vent")
	sc.vent_room("bay1")
	for id in ["dock", "dockmaster", "cold"]:
		var to: Vector2i = sc.level.rooms[id]["cells"][0]
		t.check(not sc.level.tile_path(sc.level.lift_cell, to, true).is_empty(), "cargo: with bay 1 vented the %s can still be reached" % id)
	await t.close_deck(sc)
