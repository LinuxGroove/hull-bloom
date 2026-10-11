extends Node
## The night shift so far, kept between runs (autoload: Progress): which
## decks are saved or lost, the hour, what you carry, the workbench's
## upgrades, the logs you've read, how it ended, and the best Shift nights.
##
## The ring: Hydroponics comes first. Once it's held the six middle decks
## open, each with a few hours left before the Bloom takes it; every visit
## to a deck takes an hour of the shift, so the decks you don't go to lose
## an hour each time. When all six are saved or lost, the Core opens.

signal changed

const PATH := "user://progress.cfg"
## What a fresh shift carries: the cutter and the sidearm.
const START_WEAPONS := ["cutter", "sidearm"]
const START_ITEMS := {"flare": 3, "grenade": 0, "mine": 0, "medkit": 1, "stim": 0}
## Spare cells from Engineering, each worth an hour to the deck it powers.
const SPARE_CELLS := 3
## Workbench upgrades: id -> [name, what it does, salvage].
const UPGRADES := {
	"cutter_cool": ["Cutter heat sink", "The cutter heats up a third slower.", 6],
	"cutter_focus": ["Focusing lens", "Aiming the cutter reaches further and takes limbs off faster.", 8],
	"suit": ["Suit plating", "Your suit takes a quarter more before it gives out.", 8],
	"pockets": ["Webbing", "Carry one more of every throwable and health pack.", 6],
	"sidearm_red": ["Heavy sidearm", "Hits harder and holds more.", 4],
	"scattergun_red": ["Heavy scattergun", "Hits harder and holds more.", 8],
	"rifle_red": ["Heavy pulse rifle", "Hits harder and holds more.", 10],
	"smg_red": ["Heavy burst SMG", "Hits harder and holds more.", 8],
	"rail_red": ["Heavy rail rifle", "Hits harder and holds more.", 10],
}

var _cfg := ConfigFile.new()
## Tests and tools set this so they never touch the player's real file.
var in_memory := false


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	_cfg = ConfigFile.new()
	if not in_memory:
		_cfg.load(PATH)


func reset() -> void:
	_cfg = ConfigFile.new()
	_save()
	changed.emit()


#region The shift

func has_campaign() -> bool:
	return bool(_cfg.get_value("shift", "started", false))


## Starts a new night shift, forgetting the last one (Shift mode bests and
## the logs you've read are kept).
func new_campaign() -> void:
	for section in ["shift", "decks", "carry", "upgrades"]:
		if _cfg.has_section(section):
			_cfg.erase_section(section)
	_cfg.set_value("shift", "started", true)
	_cfg.set_value("shift", "hour", 0)
	_cfg.set_value("shift", "salvage", 0)
	_cfg.set_value("shift", "spare_cells", 0)
	_cfg.set_value("shift", "ending", "")
	_cfg.set_value("carry", "weapons", START_WEAPONS.duplicate())
	_cfg.set_value("carry", "items", START_ITEMS.duplicate())
	_cfg.set_value("carry", "ammo", {})
	for id in Decks.ids():
		var d := Decks.get_deck(id)
		_cfg.set_value("decks", id, {"state": "open" if id == "hydroponics" else "locked", "hours": d.hours,
			"survivors": 0, "visits": 0, "cell": false, "best": 0.0})
	_save()
	changed.emit()


## The hour of the night shift (each deck you go to takes one).
func hour() -> int:
	return int(_cfg.get_value("shift", "hour", 0))


func _deck(id: String) -> Dictionary:
	return _cfg.get_value("decks", id, {"state": "locked", "hours": 0, "survivors": 0, "visits": 0, "cell": false, "best": 0.0})


func _set_deck(id: String, d: Dictionary) -> void:
	_cfg.set_value("decks", id, d)


## "locked", "open", "saved", "lost" or "reclaimed" (lost, then held).
func deck_state(id: String) -> String:
	return String(_deck(id)["state"])


## Hours before an open deck is lost (0 for decks that are never lost on
## their own).
func hours_left(id: String) -> int:
	return int(_deck(id)["hours"])


func survivors_saved(id: String) -> int:
	return int(_deck(id)["survivors"])


func total_survivors() -> int:
	var n := 0
	for id in Decks.ids():
		n += survivors_saved(id)
	return n


func visits(id: String) -> int:
	return int(_deck(id)["visits"])


## Whether you can go to the deck now.
func can_visit(id: String) -> bool:
	return deck_state(id) in ["open", "saved", "lost", "reclaimed"]


## Decks held (saved, or lost and taken back).
func held_decks() -> Array[String]:
	var out: Array[String] = []
	for id in Decks.ids():
		if deck_state(id) in ["saved", "reclaimed"]:
			out.append(id)
	return out


func saved_count() -> int:
	var n := 0
	for id in Decks.ids():
		if deck_state(id) == "saved":
			n += 1
	return n


func lost_count() -> int:
	var n := 0
	for id in Decks.ids():
		if deck_state(id) in ["lost", "reclaimed"]:
			n += 1
	return n


## Whether every middle deck is saved or lost, so the Core is open.
func core_open() -> bool:
	return deck_state("core") != "locked"


## What a deck being saved gives: whether it's been given yet.
func has_gift(gift: String) -> bool:
	for id in Decks.ids():
		if deck_state(id) in ["saved", "reclaimed"] and Decks.get_deck(id).gives == gift:
			return true
	return false


## A deck's run has ended. `result` comes from [method DeckRun.result]:
## {"held": bool, "survivors": n, "salvage": n, "time": s, "loadout": {...},
## "logs": [...]} . A run that's abandoned or lost still takes the hour.
## Returns {"lost": [decks the Bloom took meanwhile], "opened": [...]}.
func finish_deck(id: String, result: Dictionary) -> Dictionary:
	var d := _deck(id)
	var was := String(d["state"])
	d["visits"] = int(d["visits"]) + 1
	var held := bool(result.get("held", false))
	if held:
		match String(d["state"]):
			"open":
				d["state"] = "saved"
			"lost":
				d["state"] = "reclaimed"
		d["survivors"] = maxi(int(d["survivors"]), int(result.get("survivors", 0)))
		var t := float(result.get("time", 0.0))
		if float(d["best"]) <= 0.0 or t < float(d["best"]):
			d["best"] = t
	_set_deck(id, d)
	_cfg.set_value("shift", "salvage", salvage() + int(result.get("salvage", 0)))
	if result.has("loadout"):
		set_loadout(result["loadout"])
	for l in result.get("logs", []):
		read_log(l)
	var out := {"lost": [], "opened": []}
	# Hydroponics and the Core are outside the ring's clock, and going back to
	# a saved deck (its workbench and bunk) costs nothing. Every other visit
	# is an hour the other decks don't get.
	if id in Decks.MIDDLE and was in ["open", "lost"]:
		out["lost"] = _pass_hour(id)
	if id == "hydroponics" and held:
		for m in Decks.MIDDLE:
			if Decks.has(m) and deck_state(m) == "locked":
				var md := _deck(m)
				md["state"] = "open"
				_set_deck(m, md)
				out["opened"].append(m)
	if Decks.has("core") and deck_state("core") == "locked" and _middle_resolved():
		var cd := _deck("core")
		cd["state"] = "open"
		_set_deck("core", cd)
		out["opened"].append("core")
	if id == "engineering" and held and was == "open":
		_cfg.set_value("shift", "spare_cells", SPARE_CELLS)
	# The labs' prototype rail rifle comes with saving them.
	if held and was == "open" and Decks.get_deck(id).gives == "rail":
		var w := weapons()
		if not "rail" in w:
			w.append("rail")
			_cfg.set_value("carry", "weapons", w)
			var a := ammo()
			a["rail"] = int(a.get("rail", 0)) + 12
			_cfg.set_value("carry", "ammo", a)
	_save()
	changed.emit()
	return out


func _middle_resolved() -> bool:
	for m in Decks.MIDDLE:
		if Decks.has(m) and not deck_state(m) in ["saved", "lost", "reclaimed"]:
			return false
	return true


## An hour passes: every other open deck loses one, and those at none are lost.
func _pass_hour(visited: String) -> Array:
	_cfg.set_value("shift", "hour", hour() + 1)
	var lost := []
	for m in Decks.MIDDLE:
		if m == visited or not Decks.has(m) or deck_state(m) != "open":
			continue
		var d := _deck(m)
		d["hours"] = maxi(0, int(d["hours"]) - 1)
		if int(d["hours"]) == 0:
			d["state"] = "lost"
			lost.append(m)
		_set_deck(m, d)
	return lost


func spare_cells() -> int:
	return int(_cfg.get_value("shift", "spare_cells", 0))


func has_spare_cell(id: String) -> bool:
	return bool(_deck(id).get("cell", false))


## Sends one of Engineering's spare cells to an open deck: its lights come
## on remotely, which buys it an hour.
func assign_cell(id: String) -> bool:
	if spare_cells() <= 0 or deck_state(id) != "open" or has_spare_cell(id):
		return false
	var d := _deck(id)
	d["cell"] = true
	d["hours"] = int(d["hours"]) + 1
	_set_deck(id, d)
	_cfg.set_value("shift", "spare_cells", spare_cells() - 1)
	_save()
	changed.emit()
	return true


func ending() -> String:
	return String(_cfg.get_value("shift", "ending", ""))


## "burn" (the Heart burnt, staying aboard) or "shuttle" (leaving with the
## survivors) or "both".
func set_ending(e: String) -> void:
	_cfg.set_value("shift", "ending", e)
	var endings := PackedStringArray(_cfg.get_value("record", "endings", PackedStringArray()))
	if not e in endings:
		endings.append(e)
	_cfg.set_value("record", "endings", endings)
	_save()
	changed.emit()


func endings_seen() -> PackedStringArray:
	return PackedStringArray(_cfg.get_value("record", "endings", PackedStringArray()))

#endregion

#region What you carry

func salvage() -> int:
	return int(_cfg.get_value("shift", "salvage", 0))


## Salvage from a visit that's still going, to spend at its workbench.
func add_salvage(n: int) -> void:
	if n > 0:
		_cfg.set_value("shift", "salvage", salvage() + n)
		changed.emit()


func weapons() -> Array:
	return Array(_cfg.get_value("carry", "weapons", START_WEAPONS.duplicate()))


func items() -> Dictionary:
	return Dictionary(_cfg.get_value("carry", "items", START_ITEMS.duplicate()))


func ammo() -> Dictionary:
	return Dictionary(_cfg.get_value("carry", "ammo", {}))


## {"weapons": [...], "items": {...}, "ammo": {...}}, as the player leaves a deck.
func loadout() -> Dictionary:
	return {"weapons": weapons(), "items": items(), "ammo": ammo()}


func set_loadout(l: Dictionary) -> void:
	_cfg.set_value("carry", "weapons", Array(l.get("weapons", weapons())))
	_cfg.set_value("carry", "items", Dictionary(l.get("items", items())))
	_cfg.set_value("carry", "ammo", Dictionary(l.get("ammo", ammo())))


func has_upgrade(u: String) -> bool:
	return bool(_cfg.get_value("upgrades", u, false))


## Buys a workbench upgrade with salvage; false if it can't.
func buy(u: String) -> bool:
	if not UPGRADES.has(u) or has_upgrade(u) or salvage() < int(UPGRADES[u][2]):
		return false
	_cfg.set_value("shift", "salvage", salvage() - int(UPGRADES[u][2]))
	_cfg.set_value("upgrades", u, true)
	_save()
	changed.emit()
	return true

#endregion

#region Logs and Shift mode

func read_log(id: String) -> void:
	var logs := logs_read()
	if not id in logs:
		logs.append(id)
		_cfg.set_value("record", "logs", logs)
		_save()


func has_read(id: String) -> bool:
	return id in logs_read()


func logs_read() -> PackedStringArray:
	return PackedStringArray(_cfg.get_value("record", "logs", PackedStringArray()))


## The most decks saved on a Shift night with this seed, and survivors.
func shift_best(seed: int) -> Dictionary:
	return Dictionary(_cfg.get_value("shift_mode", str(seed), {"decks": 0, "survivors": 0, "score": 0}))


## Keeps a Shift night's score if it beats the last; true if it did.
func record_shift(seed: int, decks_saved: int, survivors: int, score: int) -> bool:
	var best := shift_best(seed)
	if score <= int(best["score"]):
		return false
	_cfg.set_value("shift_mode", str(seed), {"decks": decks_saved, "survivors": survivors, "score": score})
	_save()
	changed.emit()
	return true

#endregion


func _save() -> void:
	if not in_memory:
		_cfg.save(PATH)
