extends RefCounted
## Labs' own tests, run by tests/run_tests.gd after the checks every deck
## gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.

const VENTED := ["containment", "xeno"]


func run(t: Node) -> void:
	var lvl := Decks.make_level("labs")
	t.check(lvl.tiles.get(lvl.root_cells[0], "") == "containment", "labs: the root is the sample, in containment")
	var sealed := false
	for key in lvl.ways:
		var w: Dictionary = lvl.ways[key]
		if w["kind"] == "door" and "containment" in [lvl.tiles[w["a"]], lvl.tiles[w["b"]]]:
			sealed = w.get("sealed", false)
	t.check(sealed, "labs: containment's door starts sealed")
	var windows := 0
	for key in lvl.ways:
		var w: Dictionary = lvl.ways[key]
		if w["kind"] == "window" and "containment" in [lvl.tiles[w["a"]], lvl.tiles[w["b"]]]:
			windows += 1
	t.check(windows >= 2, "labs: the gallery looks into containment (%d windows)" % windows)
	for id in VENTED:
		t.check(lvl.rooms[id]["vent"], "labs: the %s can be vented" % id)
		var panel: Array = []
		for p in lvl.things_of("vent_panel"):
			if p[4]["room"] == id:
				panel = p
		t.check(not panel.is_empty(), "labs: the %s has a vent panel" % id)
		if panel.is_empty():
			continue
		var at: Vector2i = DeckLevel.cell_at(DeckLevel.spot(panel[1], panel[2]))
		t.check(lvl.tiles.get(at, "") != id and lvl.tiles.has(at), "labs: the %s's vent panel is outside it" % id)
		# With the room vented its doors shut for good: nothing else may be
		# cut off, and the panel is reached without going through it.
		var reach := _reach_without(lvl, lvl.lift_cell, id)
		t.check(reach.has(at), "labs: the %s's panel is reached without going in" % id)
		var cut := 0
		for c in lvl.tiles:
			if lvl.tiles[c] != id and not reach.has(c):
				cut += 1
		t.check(cut == 0, "labs: venting the %s cuts nothing else off (%d tiles)" % [id, cut])
	# Watchers float over the growth in the big rooms.
	var watchers := 0
	for s in lvl.things_of("spawn"):
		if s[4]["what"] != "watcher":
			continue
		watchers += 1
		var room: String = lvl.tiles.get(s[1], "")
		t.check(lvl.rooms[room]["cells"].size() >= 9, "labs: a watcher in a big room (%s)" % room)
		t.check(float(lvl.start_growth.get(s[1], 0.0)) >= 2.0, "labs: a watcher over the growth (%s)" % room)
	t.check(watchers >= 2, "labs: watchers on the deck (%d)" % watchers)
	# The cold store is cold, and somebody hid there because of it.
	t.check(float(lvl.rooms["store"]["warm"]) < 1.0, "labs: the sample store is cold")
	var hid := false
	for s in lvl.things_of("survivor"):
		hid = hid or lvl.tiles.get(s[1], "") == "store"
	t.check(hid, "labs: a survivor hides in the cold store")
	for s in lvl.things_of("survivor"):
		t.check(not lvl.rooms[lvl.tiles[s[1]]]["vent"], "labs: survivor %s isn't in a room that can be vented" % s[4]["id"])
	lvl.free()
	await _visit(t)


## Every tile reachable from `from` with the doors of `room` shut for good.
func _reach_without(lvl: DeckLevel, from: Vector2i, room: String) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for s in DeckLevel.SIDE_ORDER:
			var n: Vector2i = c + DeckLevel.STEP[s]
			if seen.has(n) or not lvl.walkable(c, n, true):
				continue
			if lvl.tiles[n] == room or lvl.tiles[c] == room:
				continue
			seen[n] = true
			queue.append(n)
	return seen


## On the deck: the panel won't vent with you inside; from outside it
## clears containment, kills the sample's heart and its watcher, and the room
## stays clean and shut.
func _visit(t: Node) -> void:
	var s: DeckScene = await t.open_deck("labs")
	t.check(s.hud.subtitle_text().contains("Labs"), "labs: MARI speaks on arrival")
	var panel: VentPanel = null
	for v in s.get_tree().get_nodes_in_group("vent_panels"):
		if (v as VentPanel).room_id == "containment":
			panel = v
	t.check(panel != null, "labs: containment's vent panel is on the deck")
	if panel == null:
		await t.close_deck(s)
		return
	var b := s.level.bloom
	var before := b.room_level("containment")
	t.check(before >= 3.0, "labs: containment starts overgrown (%.1f)" % before)
	await t.put_player(s, Vector2i(1, -6))
	panel._use(null)
	panel._use(null)
	t.check(b.room_level("containment") == before and not panel.used, "labs: it won't vent with you inside")
	await t.put_player(s, DeckLevel.cell_at(panel.global_position))
	var watcher: Creature = null
	for c in s.director.get_children():
		if c is Watcher and s.level.room_at(c.global_position) == "containment":
			watcher = c
	panel._use(null)
	panel._use(null)
	await t.frames(2)
	t.check(panel.used, "labs: the panel vents containment")
	t.check(b.room_level("containment") == 0.0, "labs: venting clears containment's growth")
	t.check(s.run.roots_cut == 1, "labs: and kills the sample's heart")
	t.check(watcher == null or not is_instance_valid(watcher) or watcher.dead, "labs: and the watcher in there")
	var shut := true
	for key in s.level.doors:
		var d: Bulkhead = s.level.doors[key]
		if s.level.tiles[d.a] == "containment" or s.level.tiles[d.b] == "containment":
			shut = shut and d.airless and not d.set_open(true, true)
	t.check(shut, "labs: containment's door stays shut")
	for i in 30:
		s.tick_bloom()
	t.check(b.room_level("containment") == 0.0, "labs: and it stays clean")
	await t.close_deck(s)
