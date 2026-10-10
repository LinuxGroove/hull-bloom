extends RefCounted
## Crew quarters' own tests, run by tests/run_tests.gd after the checks every
## deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.


func run(t: Node) -> void:
	var lvl := Decks.make_level("crew")
	_survivors(t, lvl)
	_taken(t, lvl)
	_lights(t, lvl)
	t.check(lvl.tiles.get(lvl.root_cells[0], "") == "laundry", "crew: the root is in the laundry")
	t.check(float(lvl.rooms["laundry"]["warm"]) > 1.0 and float(lvl.rooms["showers"]["warm"]) > 1.0, "crew: the laundry and the showers are warm and damp")
	lvl.free()
	await _on_deck(t)


## Three of the crew are hiding, every one of them can be reached, and each
## is somewhere different: behind a sealed door, in the dark, and where the
## growth is coming.
func _survivors(t: Node, lvl: DeckLevel) -> void:
	var list := lvl.things_of("survivor")
	t.check(list.size() == 3, "crew: three survivors (%d)" % list.size())
	var reach := lvl.reachable(lvl.lift_cell, true)
	var behind_seal := false
	var in_dark := false
	var near_growth := false
	var b := lvl.make_bloom()
	b.speed = lvl.deck.spread
	for i in 40:
		b.step()
	for s in list:
		var cell: Vector2i = s[1]
		var id := String(s[4]["id"])
		t.check(id.begins_with("crew_"), "crew: survivor %s has the deck's prefix" % id)
		t.check(reach.has(cell), "crew: %s can be reached from the lift" % id)
		var room: String = lvl.tiles.get(cell, "")
		# Behind a sealed door: walking with the doors you can open (not
		# sealed ones) never gets there.
		if lvl.tile_path(lvl.lift_cell, cell, true).is_empty():
			for key in lvl.ways:
				var w: Dictionary = lvl.ways[key]
				if w["kind"] == "door" and w.get("sealed", false) and (lvl.tiles.get(w["a"], "") == room or lvl.tiles.get(w["b"], "") == room):
					behind_seal = true
		if lvl.rooms[room]["dark"]:
			in_dark = true
		# The growth reaches them inside two minutes with nobody there.
		if b.level_at(cell) >= 1.0 and lvl.start_growth.get(cell, 0.0) < 2.0:
			near_growth = true
	t.check(behind_seal, "crew: a survivor waits behind a sealed door")
	t.check(in_dark, "crew: a survivor waits in a dark room")
	t.check(near_growth, "crew: a survivor waits where the growth is coming")


## The Taken walk fragments of their routines, in their own rooms.
func _taken(t: Node, lvl: DeckLevel) -> void:
	var taken := 0
	var cook := false
	for s in lvl.things_of("spawn"):
		var o: Dictionary = s[4]
		if o["what"] != "taken":
			continue
		taken += 1
		var routine: Array = o.get("routine", [])
		var job := String(o.get("job", ""))
		t.check(job != "" and routine.size() >= 3, "crew: a Taken %s has a job and a routine" % job)
		if routine.is_empty():
			continue
		var rooms := {}
		for c in routine:
			t.check(lvl.tiles.has(c), "crew: the %s's routine stays on the deck (%s)" % [job, c])
			rooms[lvl.tiles.get(c, "")] = true
		t.check(rooms.has(lvl.tiles.get(s[1], "")), "crew: the %s starts in a room of its routine" % job)
		# Something that opens doors can walk the whole round.
		for i in routine.size():
			var a: Vector2i = routine[i]
			var c: Vector2i = routine[(i + 1) % routine.size()]
			t.check(a == c or not lvl.tile_path(a, c, true).is_empty(), "crew: the %s can walk from %s to %s" % [job, a, c])
		if job == "cook":
			cook = lvl.tiles.get(s[1], "") == "galley" and rooms.has("mess")
	t.check(taken >= 6, "crew: the Taken walk the deck (%d)" % taken)
	t.check(cook, "crew: the cook walks from the galley to the mess")


## The bunk rooms, the mess and the rec room hold out longer with their
## lights on; the showers' are broken, and the growth is quickest there.
func _lights(t: Node, lvl: DeckLevel) -> void:
	var lit := ["bunks_a", "bunks_b", "mess", "rec"]
	var dark := lvl.make_bloom()
	var bright := lvl.make_bloom()
	for b in [dark, bright]:
		b.speed = lvl.deck.spread
	for r in lit:
		bright.set_room_lit(r, true)
	for i in 60:
		dark.step()
		bright.step()
	var g_dark := 0.0
	var g_bright := 0.0
	for r in lit:
		for c in lvl.rooms[r]["cells"]:
			g_dark += dark.level_at(c)
			g_bright += bright.level_at(c)
	t.check(g_bright < g_dark * 0.85, "crew: lights hold the growth back in the bunk rooms (%.0f lit, %.0f dark)" % [g_bright, g_dark])
	var dark_rooms := 0
	for id in lvl.room_ids:
		if lvl.rooms[id]["dark"]:
			dark_rooms += 1
	t.check(dark_rooms >= 2, "crew: some rooms are dark (%d)" % dark_rooms)
	t.check(lvl.rooms["showers"]["dark"] and lvl.start_growth.get(Vector2i(-3, -6), 0.0) >= 3.0, "crew: the dark showers are thick with growth")


func _on_deck(t: Node) -> void:
	var s: DeckScene = await t.open_deck("crew")
	t.check(s.run.survivors_total == 3, "crew: three survivors on the deck (%d)" % s.run.survivors_total)
	var routines := 0
	var cook_in_galley := false
	for c in s.director.get_children():
		if c is Taken:
			if not (c as Taken).routine.is_empty():
				routines += 1
			if (c as Taken).job == "cook":
				cook_in_galley = s.level.room_at(c.global_position) == "galley"
	t.check(routines >= 6, "crew: the Taken keep their routines on the deck (%d)" % routines)
	t.check(cook_in_galley, "crew: the cook starts in the galley")
	# The cold store's door is sealed, costs nothing, and opens once unsealed.
	var key := DeckLevel.edge_key(Vector2i(3, 2), Vector2i(4, 2))
	var d: Bulkhead = s.level.doors.get(key)
	t.check(d != null and d.sealed, "crew: the cold store is sealed")
	t.check(s.power.free_cells() == s.deck.cells, "crew: the seal costs none of your cells")
	t.check(not s.toggle_lights("showers"), "crew: the showers' lights are broken")
	t.check(s.toggle_lights("bunks_b"), "crew: bunk room B's lights work")
	if d:
		d.unseal()
		await t.physics(int(Bulkhead.UNSEAL_TIME * 60.0) + 10)
		t.check(not d.sealed and d.set_open(true, true), "crew: Brandt's door unseals and opens")
	await t.close_deck(s)
