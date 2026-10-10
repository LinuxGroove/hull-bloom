extends RefCounted
## Medical's own tests, run by tests/run_tests.gd after the checks every
## deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.


func run(t: Node) -> void:
	var lvl := Decks.make_level("medical")
	_pharmacy(t, lvl)
	_morgue(t, lvl)
	_quarantine(t, lvl)
	_supplies(t, lvl)
	lvl.free()
	await _on_deck(t)


## The pharmacy is locked, and its keycard lies where you can reach it
## without going through the pharmacy.
func _pharmacy(t: Node, lvl: DeckLevel) -> void:
	var ways_in := 0
	var all_locked := true
	for key in lvl.ways:
		var w: Dictionary = lvl.ways[key]
		var into: bool = lvl.tiles.get(w["a"], "") == "pharmacy" or lvl.tiles.get(w["b"], "") == "pharmacy"
		var from_outside: bool = lvl.tiles.get(w["a"], "") != lvl.tiles.get(w["b"], "")
		if into and from_outside:
			ways_in += 1
			all_locked = all_locked and w["kind"] == "door" and String(w.get("locked", "")) == "pharmacy"
	t.check(ways_in > 0 and all_locked, "medical: the only way into the pharmacy is a door locked with its keycard")
	var inside: Vector2i = lvl.rooms["pharmacy"]["cells"][0]
	t.check(lvl.tile_path(lvl.lift_cell, inside, true).is_empty(), "medical: without the card there's no way into the pharmacy")
	var card := []
	for p in lvl.things_of("pickup"):
		if p[4]["item"] == "keycard:pharmacy":
			card.append(p[1])
	t.check(card.size() == 1, "medical: the pharmacy's keycard is on the deck")
	if card.size() == 1:
		var c: Vector2i = card[0]
		t.check(lvl.tiles.get(c, "") != "pharmacy", "medical: the keycard isn't locked in with the stims")
		var path := lvl.tile_path(lvl.lift_cell, c, true)
		var through := false
		for step in path:
			through = through or lvl.tiles.get(step[0], "") == "pharmacy"
		t.check(not path.is_empty() and not through, "medical: the keycard can be reached without the pharmacy")


## The morgue's dead lie on growth that gets them up again before long.
func _morgue(t: Node, lvl: DeckLevel) -> void:
	var cells: Array[Vector2i] = []
	for b in lvl.things_of("body"):
		if lvl.tiles.get(b[1], "") == "morgue":
			cells.append(b[1])
	t.check(cells.size() >= 3, "medical: bodies in the morgue (%d)" % cells.size())
	var bloom := lvl.make_bloom()
	bloom.speed = lvl.deck.spread
	var fed := bloom.fed()
	for c in cells:
		t.check(fed[bloom.index[c]] == 1, "medical: the morgue body at %s lies on growth fed by the root" % c)
	# Two minutes with nobody there.
	for i in 40:
		bloom.step()
	for c in cells:
		t.check(bloom.level_at(c) >= Bloom.TAKE_LEVEL, "medical: the morgue body at %s will get up (growth %.1f)" % [c, bloom.level_at(c)])
	t.check(float(lvl.rooms["morgue"]["warm"]) < 1.0, "medical: the morgue is cold")


## The first patients are behind sealed doors, with the root, and the Bloom
## got out through the vents.
func _quarantine(t: Node, lvl: DeckLevel) -> void:
	t.check(lvl.tiles.get(lvl.root_cells[0], "") == "quarantine", "medical: the root is in quarantine")
	var sealed := 0
	var unsealed := 0
	for key in lvl.ways:
		var w: Dictionary = lvl.ways[key]
		if lvl.tiles.get(w["a"], "") == lvl.tiles.get(w["b"], ""):
			continue
		if lvl.tiles.get(w["a"], "") == "quarantine" or lvl.tiles.get(w["b"], "") == "quarantine":
			if w["kind"] == "door" and w.get("sealed", false):
				sealed += 1
			else:
				unsealed += 1
	t.check(sealed >= 2 and unsealed == 0, "medical: quarantine is behind sealed doors (%d sealed, %d not)" % [sealed, unsealed])
	var vented := false
	for v in lvl.vents:
		vented = vented or lvl.tiles.get(v[0], "") == "quarantine" or lvl.tiles.get(v[1], "") == "quarantine"
	t.check(vented, "medical: the Bloom got out of quarantine through the vents")
	t.check(lvl.rooms["isolation"]["dark"], "medical: the isolation corridor is dark")


## Feeders on the corridor ceilings, stims and medkits plenty, and the logs
## that tell what happened here.
func _supplies(t: Node, lvl: DeckLevel) -> void:
	var feeders := 0
	for s in lvl.things_of("spawn"):
		if s[4]["what"] == "feeder":
			feeders += 1
			t.check(lvl.rooms[lvl.tiles[s[1]]]["style"] == "corridor", "medical: a feeder hangs in a corridor (%s)" % lvl.tiles[s[1]])
	t.check(feeders >= 2, "medical: feeders hang in the corridors (%d)" % feeders)
	var stims := 0
	var medkits := 0
	for p in lvl.things_of("pickup"):
		match String(p[4]["item"]):
			"stim":
				stims += int(p[4]["count"])
			"medkit":
				medkits += int(p[4]["count"])
	t.check(stims >= 5 and medkits >= 4, "medical: stims and medkits are plentiful (%d stims, %d medkits)" % [stims, medkits])
	var logs := {}
	for l in lvl.things_of("log"):
		logs[l[4]["id"]] = true
	for id in ["medical_cmo", "medical_letter", "medical_quarantine"]:
		t.check(logs.has(id), "medical: the log %s is here" % id)
	var survivors := lvl.things_of("survivor")
	t.check(survivors.size() >= 1 and survivors.size() <= 2, "medical: one or two survivors (%d)" % survivors.size())
	for s in survivors:
		t.check(String(s[4]["id"]).begins_with("medical_"), "medical: survivor %s has the deck's prefix" % s[4]["id"])


func _on_deck(t: Node) -> void:
	var s: DeckScene = await t.open_deck("medical")
	var feeders := 0
	for c in s.director.get_children():
		if c is Feeder:
			feeders += 1
			t.check(c.global_position.y > Kit.HEIGHT - 0.5, "medical: the feeder hangs from the ceiling")
	t.check(feeders == 2, "medical: two feeders on the deck (%d)" % feeders)
	# The pharmacy door: shut to everything without the card.
	var d: Bulkhead = s.level.doors.get(DeckLevel.edge_key(Vector2i(4, 0), Vector2i(4, -1)))
	t.check(d != null and d.locked == "pharmacy", "medical: the pharmacy door is locked")
	if d:
		t.check(not d.creature_open() and not d.set_open(true), "medical: nothing gets through it without the card")
		t.check(not s.player.has_key("pharmacy"), "medical: the tech starts without the card")
		s.player.take_pickup("keycard:pharmacy", 1)
		d._use_leaf(null)
		t.check(d.is_open, "medical: the card opens the pharmacy")
	# The morgue's dead get up.
	var before := _morgue_bodies(s)
	for i in 30:
		s.tick_bloom()
		await t.frames(1)
	var risen := 0
	for c in s.director.get_children():
		if c is Taken and s.level.room_at(c.global_position) == "morgue":
			risen += 1
	t.check(before >= 3 and _morgue_bodies(s) < before and risen > 0, "medical: the dead in the morgue get up (%d of %d)" % [before - _morgue_bodies(s), before])
	await t.close_deck(s)


func _morgue_bodies(s: DeckScene) -> int:
	var n := 0
	for b in s.get_tree().get_nodes_in_group("bodies"):
		if not (b as CrewBody).gone and s.level.room_at((b as Node3D).global_position) == "morgue":
			n += 1
	return n
