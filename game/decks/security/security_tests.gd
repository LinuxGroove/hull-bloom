extends RefCounted
## Security's own tests, run by tests/run_tests.gd after the checks every
## deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.

const ROBOTS := ["eyedrone", "gundrone", "quadorb", "quadshell", "raptor", "trilobite"]


func run(t: Node) -> void:
	var lvl := Decks.make_level("security")
	t.check(lvl.tiles.get(lvl.root_cells[0], "") == "bay", "security: the root is in the robot bay")
	# The armoury: behind one door, locked to its card, with the guns inside.
	var armoury_doors := []
	for key in lvl.ways:
		var w: Dictionary = lvl.ways[key]
		if w["kind"] != "window" and "armoury" in [lvl.tiles[w["a"]], lvl.tiles[w["b"]]]:
			armoury_doors.append(w)
	t.check(armoury_doors.size() == 1 and String(armoury_doors[0].get("locked", "")) == "armoury", "security: the armoury's only door is locked to its card")
	var inside: Vector2i = lvl.rooms["armoury"]["cells"][0]
	t.check(lvl.tile_path(lvl.lift_cell, inside, true).is_empty(), "security: no way into the armoury without the card")
	var guns := {}
	for p in lvl.things_of("pickup"):
		if lvl.tiles.get(p[1], "") == "armoury":
			guns[p[4]["item"]] = true
	for item in ["weapon:rifle", "weapon:smg", "ammo:rifle", "ammo:smg"]:
		t.check(guns.has(item), "security: the armoury holds %s" % item)
	# Each keycard lies outside what it opens, on a way from the lift that
	# needs no locked door.
	for card in ["armoury", "brig"]:
		var at := Vector2i(99, 99)
		for p in lvl.things_of("pickup"):
			if p[4]["item"] == "keycard:" + card:
				at = p[1]
		t.check(lvl.tiles.has(at), "security: the %s keycard is on the deck" % card)
		var locked_room := ""
		for key in lvl.ways:
			var w: Dictionary = lvl.ways[key]
			if String(w.get("locked", "")) == card:
				locked_room = lvl.tiles[w["a"]] if lvl.rooms[lvl.tiles[w["a"]]]["cells"].size() <= lvl.rooms[lvl.tiles[w["b"]]]["cells"].size() else lvl.tiles[w["b"]]
		t.check(lvl.tiles.get(at, "") != locked_room, "security: the %s keycard isn't behind its own door" % card)
		var path := lvl.tile_path(lvl.lift_cell, at, true)
		t.check(not path.is_empty() or at == lvl.lift_cell, "security: the %s keycard can be reached with no card" % card)
		var through := false
		for step in path:
			through = through or lvl.tiles.get(step[0], "") == locked_room
		t.check(not through, "security: and not through the %s" % locked_room)
	# Somebody is locked in the brig.
	var jailed := false
	for s in lvl.things_of("survivor"):
		var room: String = lvl.tiles.get(s[1], "")
		if room.begins_with("cell_"):
			for key in lvl.ways:
				var w: Dictionary = lvl.ways[key]
				if (lvl.tiles[w["a"]] == room or lvl.tiles[w["b"]] == room) and String(w.get("locked", "")) != "":
					jailed = true
	t.check(jailed, "security: a survivor is locked in a brig cell")
	# The station's robots, every kind, and turret mounts facing open floor.
	var kinds := {}
	for s in lvl.things_of("spawn"):
		kinds[s[4]["what"]] = true
	for r in ROBOTS:
		t.check(kinds.has(r), "security: an infected %s on the deck" % r)
	var mounts := lvl.things_of("turret")
	t.check(mounts.size() >= 3, "security: turret mounts to hold the corridors (%d)" % mounts.size())
	for m in mounts:
		var pos := DeckLevel.spot(m[1], m[2])
		var ahead := pos + Vector3(-sin(m[3]), 0, -cos(m[3])) * Kit.TILE * 2.0
		t.check(lvl.reachable(m[1]).has(DeckLevel.cell_at(ahead)), "security: the turret at %s faces open floor" % m[1])
	lvl.free()
	await _visit(t)


func _visit(t: Node) -> void:
	var s: DeckScene = await t.open_deck("security")
	t.check(s.hud.subtitle_text().contains("Security"), "security: MARI speaks on arrival")
	# The robots: a Raptor still guarding its post, a Trilobite on the ceiling.
	var guard := false
	var hanging := false
	for c in s.director.get_children():
		if c is Robot:
			guard = guard or (c.kind == "raptor" and c.guard_range > 0.0 and s.level.room_at(c.home) == "spine")
			hanging = hanging or (c.kind == "trilobite" and c.hanging and c.global_position.y > 2.0)
	t.check(guard, "security: the Raptor guards the corridor by the armoury")
	t.check(hanging, "security: the Trilobite waits on the brig's ceiling")
	# The armoury door: locked to creatures and to you until you have the card.
	var door: Bulkhead = null
	for key in s.level.doors:
		if s.level.doors[key].locked == "armoury":
			door = s.level.doors[key]
	t.check(door != null, "security: the armoury door is on the deck")
	if door:
		t.check(not door.creature_open(), "security: creatures can't open the armoury")
		door._use_leaf(null)
		t.check(not door.is_open, "security: nor can you without the card")
		var card: Pickup = null
		for p in s.level.find_children("", "Pickup", true, false):
			if (p as Pickup).item == "keycard:armoury":
				card = p
		t.check(card != null, "security: the armoury card is on the deck")
		if card:
			card._try(s.player, false)
		door._use_leaf(null)
		t.check(door.is_open and door.locked == "", "security: the card opens the armoury")
	# A turret takes a cell and fires at a creature in front of it.
	var tu: Turret = null
	for n in s.get_tree().get_nodes_in_group("turrets"):
		if s.level.room_at(n.global_position) == "spine":
			tu = n
	t.check(tu != null, "security: a turret in the main corridor")
	if tu:
		var free := s.power.free_cells()
		tu._use(null)
		t.check(tu.powered and s.power.free_cells() == free - 1, "security: powering a turret takes a cell")
		var fwd := -tu.global_transform.basis.z
		var sk := s.director.spawn("skitter", tu.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 5.0, true)
		var belt := tu.ammo
		for i in 90:
			await t.physics(1)
			if not is_instance_valid(sk) or sk.dead:
				break
		t.check(tu.ammo < belt, "security: the turret fires (%d rounds)" % (belt - tu.ammo))
		t.check(not is_instance_valid(sk) or sk.dead or sk.health < sk.max_health, "security: and hits the creature")
		tu._use(null)
		t.check(not tu.powered and s.power.free_cells() == free, "security: switching it off gives the cell back")
	await t.close_deck(s)
