class_name ShiftNight
extends RefCounted
## A Shift night: a station built from a seed, [constant DECKS] decks one
## after another, and one night to hold as many as you can. Each deck spreads
## faster than the last. You keep what you carry between decks; going down
## ends the night. The score counts decks held, survivors, the time each
## took and what you killed; tonight's station (the date as its seed) goes on
## the online boards.

const DECKS := 3
## The online boards: [id, title] (declared on the game server).
const BOARDS := [["shift_daily", "Tonight's station"], ["shift_best", "Best nights"]]
const START_KIT := {"weapons": ["cutter", "sidearm", "scattergun"], "items": {"flare": 3, "grenade": 1, "mine": 0, "medkit": 1, "stim": 1}, "ammo": {"scattergun": 18}}
const HELD := 1000
const SURVIVOR := 250
const KILL := 5
## Seconds under which holding a deck earns a time bonus, a point a second.
const PAR := 600.0
const NAMES := ["Stores", "Pumps", "Galley", "Annexe", "Workshops", "Greenhouse", "Archive", "Laundry", "Dormitory", "Clinic", "Docking ring", "Hangar"]

## The night being played, kept across the decks' scene changes.
static var current: ShiftNight

var seed := 0
var decks: Array[DeckDef] = []
var index := 0
## Each deck played: {"name", "held", "survivors", "kills", "time", "score"}.
var results: Array = []
var _kit := {}
var over := false


static func daily_seed() -> int:
	var d := Time.get_date_dict_from_system(true)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## Shift mode opens once the campaign has ended once; the developer
## shortcut --shift opens it anyway.
static func unlocked() -> bool:
	return not Progress.endings_seen().is_empty() or OS.get_cmdline_user_args().has("--shift")


## Makes a night from a seed (its decks' data, nothing built yet).
static func make(p_seed: int) -> ShiftNight:
	var n := ShiftNight.new()
	n.seed = p_seed
	var r := RandomNumberGenerator.new()
	r.seed = p_seed
	var names := NAMES.duplicate()
	for i in DECKS:
		var d := DeckDef.new()
		d.id = "shift_%d_%d" % [p_seed, i]
		d.number = i + 1
		var pick := r.randi() % names.size()
		d.name = names[pick]
		names.remove_at(pick)
		d.cells = r.randi_range(3, 5)
		d.spread = 0.9 + 0.18 * i
		d.seed = int(r.randi() % 1000000) + 1
		d.max_alive = 8 + i * 2
		d.hatches = {"skitter": 1.0, "stalker": 0.15 * i, "feeder": 0.1 * i, "watcher": 0.08 * i}
		d.music = ["hydroponics", "labs", "core"][i]
		d.color = Color.from_hsv(r.randf(), 0.5, 0.95)
		d.arrive = "Deck %d of %d tonight: the %s. Organic obstruction on every sensor." % [i + 1, DECKS, d.name.to_lower()]
		d.held = "The %s is holding." % d.name.to_lower()
		d.level = "res://game/shift/shift_level.gd"
		n.decks.append(d)
	n._kit = START_KIT.duplicate(true)
	return n


static func start(p_seed: int) -> void:
	current = make(p_seed)
	current.play_deck()


## Goes to the night's current deck.
func play_deck() -> void:
	var d := decks[index]
	DeckScene.play(d.id, {"mode": "shift", "custom_deck": d, "custom_level": load(d.level), "night": self})


## What the player carries onto a deck.
func kit() -> Dictionary:
	return _kit.duplicate(true)


## The deck's visit ended by the lift (held or not).
func deck_done(scene: DeckScene) -> void:
	_kit = scene.player.kit()
	var r := _record(scene, true)
	var lines := scene._summary_lines()
	lines.append(["Score for the deck", r["score"]])
	lines.append(["The night so far", score()])
	index += 1
	var buttons := []
	if index < decks.size():
		buttons.append(["Next deck: " + decks[index].name, play_deck])
	else:
		buttons.append(["The night's score", _finish.bind(scene)])
	scene.results.show_panel("DECK HELD" if r["held"] else "DECK LEFT", "", lines, buttons, StationTheme.TEAL if r["held"] else StationTheme.AMBER)


## Down on a deck: the night is over.
func deck_down(scene: DeckScene) -> void:
	_record(scene, false)
	index = decks.size()
	_finish(scene, true)


func _record(scene: DeckScene, left: bool) -> Dictionary:
	var run := scene.run
	var held := run.held and left
	var t := run.held_at if run.held else run.time
	var s := run.kills * KILL + run.survivors_saved.size() * SURVIVOR
	if held:
		s += HELD + int(maxf(0.0, PAR - t))
	var r := {"name": scene.deck.name, "held": held, "survivors": run.survivors_saved.size(), "kills": run.kills, "time": t, "score": s}
	results.append(r)
	return r


func score() -> int:
	var s := 0
	for r in results:
		s += int(r["score"])
	return s


func decks_held() -> int:
	var n := 0
	for r in results:
		if r["held"]:
			n += 1
	return n


func survivors() -> int:
	var n := 0
	for r in results:
		n += int(r["survivors"])
	return n


func _finish(scene: DeckScene, down := false) -> void:
	over = true
	var best := Progress.record_shift(seed, decks_held(), survivors(), score())
	var lines := []
	for r in results:
		lines.append([r["name"], "%s · %d" % ["held" if r["held"] else "lost", r["score"]]])
	lines.append(["Decks held", "%d of %d" % [decks_held(), DECKS]])
	lines.append(["Survivors brought out", survivors()])
	lines.append(["Score", score()])
	if best:
		lines.append(["", "Your best on this station"])
	var title := "YOU'RE DOWN" if down else "THE NIGHT IS OVER"
	var sub := "Tonight's station" if seed == daily_seed() else "Station %d" % seed
	scene.results.show_panel(title, sub, lines, [["Back to the title", scene._on_quit], ["Try this station again", ShiftNight.start.bind(seed)]],
		StationTheme.RED if down else StationTheme.TEAL)
	if seed == daily_seed():
		submit(score())


## Puts tonight's score on the online boards, if online play is on. Never
## blocks the night; a failure is only logged.
static func submit(points: int) -> void:
	if points <= 0 or not LGOnline.is_enabled():
		return
	if not await LGOnline.connect_async(GameConfig.player_name(), GameConfig.GAME_ID):
		return
	for b in BOARDS:
		var res: Variant = await LGOnline.rpc_async("core.score_submit", {"board": b[0], "score": points})
		if res == null:
			push_warning("Shift: couldn't submit to %s" % b[0])
