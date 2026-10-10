extends RefCounted
## Hydroponics' own tests, run by tests/run_tests.gd after the checks every
## deck gets. `t` is the runner: t.check(), t.frames(), t.open_deck() and so on.


func run(t: Node) -> void:
	var lvl := Decks.make_level("hydroponics")
	# The way in: lift, spine, seed lab, then the jammed vault door to the root.
	var path := lvl.tile_path(lvl.lift_cell, lvl.root_cells[0], true)
	t.check(not path.is_empty(), "hydroponics: a way from the lift to the root")
	t.check(lvl.tiles.get(path[path.size() - 1][0], "") == "vault", "hydroponics: the root is in the vault")
	var through_lab := false
	for step in path:
		if lvl.tiles.get(step[0], "") == "seed_lab":
			through_lab = true
	t.check(through_lab, "hydroponics: the way to the root goes through the seed lab")
	# The cook still works in the mess.
	var cook := false
	for s in lvl.things_of("spawn"):
		if s[4]["what"] == "taken" and s[4].get("job", "") == "cook":
			cook = lvl.tiles.get(s[1], "") == "mess"
	t.check(cook, "hydroponics: the Taken cook is in the mess")
	# The scattergun is here, so the next decks can count on it.
	var gun := false
	for p in lvl.things_of("pickup"):
		if p[4]["item"] == "weapon:scattergun":
			gun = true
	t.check(gun, "hydroponics: the scattergun is on the deck")
	lvl.free()
	# On the deck: the grow rooms' growth gets the toast when it reaches the
	# corridor, and the seed lab's pods are real.
	var s: DeckScene = await t.open_deck("hydroponics")
	var pods := 0
	for k in s.director.pods:
		pods += s.director.pods[k].size()
	t.check(pods >= 2, "hydroponics: the seed lab's pods are on the deck (%d)" % pods)
	t.check(s.hud.subtitle_text().contains("Hydroponics"), "hydroponics: MARI speaks on arrival")
	await t.close_deck(s)
