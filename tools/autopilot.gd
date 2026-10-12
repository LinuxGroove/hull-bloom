extends Node
## The autopilot: plays decks headless through the Tech's own controls, for
## play tests and balance checks, and writes what happened as JSON.
##   godot --headless --path . tools/autopilot.tscn -- --deck=hydroponics --skill=average --seed=1 --runs=3 --minutes=20 --out=/tmp/ap.json
##   godot --headless --path . tools/autopilot.tscn -- --campaign --skill=expert --seed=1 --out=/tmp/campaign.json
## --skill is novice, average or expert (tools/autopilot/skill.gd). --kit=start
## starts every deck with the first kit (the sprayer and rivet gun); the default
## for decks after Hydroponics adds the scattergun Hydroponics gives you, and
## --kit=late adds the rifle and SMG from Security's armoury, for the Core.
## --campaign plays Hydroponics, the middle decks in an order from the seed,
## then the Core, carrying Progress (hours, gifts, salvage, the kit) between
## them. With a display (xvfb-run, software Vulkan),
## --shots=<dir> --every=<seconds> saves what the Tech sees, HUD and all, as
## numbered JPEGs. Time runs as fast as the machine can in fixed 1/60 s steps,
## and Progress stays in memory, so the player's own is never touched.

const Pilot := preload("res://tools/autopilot/pilot.gd")
const Telemetry := preload("res://tools/autopilot/telemetry.gd")
const Skill := preload("res://tools/autopilot/skill.gd")

## How many times faster than real time the game may run: physics ticks a
## second are this many times 60, one tick a frame.
const SPEED := 100
## Game seconds it may spend after the deck holds: looking round for
## survivors and supplies, then the lift.
const AFTER_HELD := 300.0
## Deaths on a middle deck before the campaign gives it up and goes back to
## the ring.
const TRIES := 3
## Tries at Hydroponics and the Core, which can't be left for later: a
## player would keep at them.
const MUST_TRIES := 8
## What a Tech carries onto a deck after Hydroponics: the scattergun found
## there and some of its rounds.
const AFTER_HYDROPONICS := {"weapons": ["sprayer", "rivet_gun", "scattergun"],
	"items": {"flare": 3, "grenade": 0, "mine": 0, "medkit": 1, "stim": 0}, "ammo": {"scattergun": 18}}
## What a Tech might carry onto the Core or a deck late in the ring: the rifle
## and SMG from Security's armoury, and a few things to throw.
const LATE := {"weapons": ["sprayer", "rivet_gun", "scattergun", "rifle", "smg"],
	"items": {"flare": 3, "grenade": 1, "mine": 0, "medkit": 2, "stim": 0}, "ammo": {"scattergun": 24, "rifle": 120, "smg": 128}}
## Upgrades the campaign buys at a held deck's workbench, in order.
const BUY_ORDER := ["sprayer_heater", "suit", "pockets", "scattergun_red", "sprayer_nozzle", "rifle_red", "smg_red", "rivet_gun_red", "rail_red"]


## Warnings and errors from Godot and the game while a run plays.
class RunLog extends Logger:
	var _lock := Mutex.new()
	var _lines: Array = []
	var _counts := {}

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind := "warning" if error_type == 1 else "error"
		var what := rationale if rationale != "" else code
		_add(kind, "%s (%s:%d %s)" % [what, file.get_file(), line, function])

	func _log_message(message: String, error: bool) -> void:
		if error or message.begins_with("WARNING") or message.contains("ISSUE:"):
			_add("error" if error else "warning", message.strip_edges())

	func _add(kind: String, text: String) -> void:
		_lock.lock()
		var key := kind + ": " + text
		if not _counts.has(key):
			_lines.append(key)
		_counts[key] = int(_counts.get(key, 0)) + 1
		_lock.unlock()

	## What was logged since the last take, as [{kind, text, count}].
	func take() -> Array:
		_lock.lock()
		var out := []
		for key in _lines:
			var k: String = key.get_slice(": ", 0)
			out.append({"kind": k, "text": key.substr(k.length() + 2), "count": _counts[key]})
		_lines.clear()
		_counts.clear()
		_lock.unlock()
		return out


var _log := RunLog.new()
var _shots := ""
var _every := 10.0
var _shot_n := 0
var _quiet_print := false


func _ready() -> void:
	var deck := "hydroponics"
	var skill := "average"
	var seed_n := 1
	var runs := 1
	var minutes := 20.0
	var out := ""
	var campaign := false
	var kit := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--deck="):
			deck = a.trim_prefix("--deck=")
		elif a.begins_with("--skill="):
			skill = a.trim_prefix("--skill=")
		elif a.begins_with("--seed="):
			seed_n = int(a.trim_prefix("--seed="))
		elif a.begins_with("--runs="):
			runs = maxi(1, int(a.trim_prefix("--runs=")))
		elif a.begins_with("--minutes="):
			minutes = float(a.trim_prefix("--minutes="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--campaign":
			campaign = true
		elif a.begins_with("--kit="):
			kit = a.trim_prefix("--kit=")
		elif a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
		elif a.begins_with("--every="):
			_every = maxf(0.5, float(a.trim_prefix("--every=")))
	if not Skill.PRESETS.has(skill):
		printerr("autopilot: no skill called %s (%s)" % [skill, ", ".join(Skill.names())])
		get_tree().quit(1)
		return
	if not campaign and not Decks.has(deck):
		printerr("autopilot: no deck called %s" % deck)
		get_tree().quit(1)
		return
	OS.add_logger(_log)
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGSettings.set_value("video", "fullscreen", false, false)
	# Autopilot runs must never reach the online boards.
	LGSettings.set_value("online", "enabled", false, false)
	LGInput.register_actions(GameConfig.ACTIONS)
	StationTheme.apply(get_tree().root, 22)
	Progress.in_memory = true
	Progress.load_progress()
	_fast()
	if _shots != "":
		if DisplayServer.get_name() == "headless":
			printerr("autopilot: --shots needs a display (xvfb-run), not --headless")
			_shots = ""
		else:
			DirAccess.make_dir_recursive_absolute(_shots)
			RenderingServer.render_loop_enabled = false
	await get_tree().process_frame
	_log.take()
	var result := {}
	if campaign:
		result = await _campaign(skill, seed_n, minutes, kit)
	else:
		var list := []
		for i in runs:
			var opts := {"kit": kit if kit != "" else ("start" if deck == "hydroponics" else "after_hydroponics")}
			list.append(await play(deck, skill, seed_n + i, minutes, opts))
		result = {"runs": list}
	result["speed"] = SPEED
	result["version"] = ProjectSettings.get_setting("application/config/version", "")
	_print_table(result)
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(result, "\t", false))
		f.close()
		print("autopilot: wrote ", out)
	if _shots != "":
		RenderingServer.render_loop_enabled = true
	get_tree().quit()


## Fixed 1/60 s steps as fast as the machine runs them (up to SPEED times
## real time): one physics tick and one frame each step, and no sleeping
## between frames. Runs of one seed still drift apart after a while, even
## under Godot's --fixed-fps, so a seed sets up a run rather than replaying it.
func _fast() -> void:
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Engine.max_fps = 0
	Engine.physics_jitter_fix = 0.0
	Engine.physics_ticks_per_second = 60 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 1


## One visit to a deck: the autopilot plays until the deck is held and it
## takes the lift, the Tech goes down, it's stuck for good or time runs out.
## opts: "mode" ("test" or "campaign"), "kit" ("start", "after_hydroponics",
## "late" or "" for what the mode gives).
func play(deck_id: String, skill_name: String, seed_n: int, minutes: float, opts := {}) -> Dictionary:
	seed(seed_n * 7919 + deck_id.hash())
	var s := DeckScene.new()
	s.deck_id = deck_id
	s.mode = String(opts.get("mode", "test"))
	s.quiet = true
	get_tree().root.add_child(s)
	if String(opts.get("kit", "")) == "after_hydroponics":
		s.player.load_kit(AFTER_HYDROPONICS.duplicate(true))
	elif String(opts.get("kit", "")) == "late":
		s.player.load_kit(LATE.duplicate(true))
	await _frames(3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pilot = Pilot.new()
	add_child(pilot)
	pilot.setup(s, Skill.get_preset(skill_name), seed_n)
	var tel = Telemetry.new()
	add_child(tel)
	tel.setup(s, pilot)
	if _shots != "":
		# Under software Vulkan the HUD costs seconds a frame to lay out, so
		# it's only shown for the pictures.
		s.hud.visible = false
	var tag := "%s %s %d" % [deck_id, skill_name, seed_n]
	var limit := minutes * 60.0
	var held_t := -1.0
	var outcome := ""
	var next_print := 60.0
	var next_shot := 0.0
	var real0 := Time.get_ticks_msec()
	while true:
		await get_tree().physics_frame
		var t: float = pilot.time
		if _shots != "" and t >= next_shot:
			next_shot += _every
			await _shoot(deck_id, skill_name, seed_n)
		if s.run.left:
			outcome = "held" if s.run.held else "left"
			break
		if s.player.is_dead:
			outcome = "died"
			break
		if pilot.stuck_out:
			outcome = "stuck"
			break
		if s.run.held and held_t < 0.0:
			held_t = t
		if held_t >= 0.0 and t - held_t > AFTER_HELD:
			outcome = "held"
			break
		if t >= limit:
			outcome = "held" if s.run.held else "timed out"
			break
		if t >= next_print:
			next_print += 60.0
			print("  [%s] %s %s roots %d/%d growth %.1f%% hp %d inf %d kills %d" % [tag, _clock(t), pilot.mode,
				s.run.roots_cut, s.run.roots, s.level.bloom.coverage() * 100.0, roundi(s.player.health),
				roundi(s.player.infection), s.run.kills])
	pilot.release_all()
	var rec: Dictionary = tel.finish()
	var t_end: float = pilot.time
	rec = _head(deck_id, skill_name, seed_n, s, outcome, t_end, held_t, opts).merged(rec)
	rec["real_seconds"] = snappedf((Time.get_ticks_msec() - real0) / 1000.0, 0.1)
	if _shots != "":
		await _shoot(deck_id, skill_name, seed_n)
	# The campaign's record of the visit, as the results screen and the ring
	# would make it.
	if s.mode == "campaign" and outcome != "died":
		if not s.run.over:
			s._on_leave_from_menu()
	rec["log"] = _log.take()
	print("[%s] %s at %s: roots %d/%d, %d deaths, %d kills, %d log lines (%.0f s real)" % [tag, outcome, _clock(t_end),
		s.run.roots_cut, s.run.roots, rec["deaths"].size(), s.run.kills, rec["log"].size(), rec["real_seconds"]])
	await _close(s)
	return rec


func _head(deck_id: String, skill_name: String, seed_n: int, s: DeckScene, outcome: String, t: float, held_t: float, opts: Dictionary) -> Dictionary:
	return {
		"deck": deck_id, "skill": skill_name, "seed": seed_n, "mode": s.mode, "kit": String(opts.get("kit", "")),
		"outcome": outcome, "time": snappedf(t, 0.1), "minutes": snappedf(t / 60.0, 0.01),
		"held": s.run.held, "held_at": snappedf(s.run.held_at, 0.1) if s.run.held else null,
		"held_pilot_time": snappedf(held_t, 0.1) if held_t >= 0.0 else null, "left": s.run.left,
		"downs": s.run.downs, "ammo_left": _ammo(s.player), "items_left": s.player.items.duplicate(),
		"health_left": roundi(s.player.health), "infection_left": roundi(s.player.infection),
	}


func _ammo(p: Tech) -> Dictionary:
	var out := {}
	for w in p.arsenal.owned:
		if w != "sprayer" and int(p.arsenal.stat(w).get("carry", 0)) >= 0:
			out[w] = int(p.arsenal.mag.get(w, 0)) + int(p.arsenal.reserve.get(w, 0))
	return out


func _close(s: DeckScene) -> void:
	get_tree().paused = false
	for c in get_children():
		c.queue_free()
	if is_instance_valid(s):
		s.queue_free()
	Gore.clear()
	await _frames(3)


## Draws one frame and saves it: what the Tech sees, HUD and all.
func _shoot(deck_id: String, skill_name: String, seed_n: int) -> void:
	var hud: Control = DeckScene.current.hud if DeckScene.current else null
	if hud:
		hud.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	if hud:
		hud.visible = false
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		printerr("autopilot: nothing drawn for shot %d" % _shot_n)
		return
	img.save_jpg("%s/%s_%s_%d_%04d.jpg" % [_shots, deck_id, skill_name, seed_n, _shot_n], 0.85)
	_shot_n += 1

#region The campaign

## Hydroponics, then the middle decks in an order from the seed (lost ones
## too, to take them back), then the Core, as a player at the ring would
## choose them. A death tries the deck again (as "Try the deck again" does)
## up to TRIES times (MUST_TRIES for Hydroponics and the Core), then goes
## back to the ring, which takes the hour. Between decks it spends salvage at
## a held deck's workbench and sends Engineering's spare cells where hours
## are shortest. Stops where a deck it needs can't be held.
func _campaign(skill_name: String, seed_n: int, minutes: float, kit: String) -> Dictionary:
	Progress.new_campaign()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var order: Array = Decks.MIDDLE.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var visits := []
	var reached := "hydroponics"
	var ok := await _campaign_deck("hydroponics", skill_name, seed_n, minutes, visits)
	if ok:
		reached = "middle"
		var guard := 0
		while not Progress.core_open() and guard < 18:
			guard += 1
			_at_ring(skill_name)
			# The next deck in its order, fewest visits first, open ones before
			# lost ones: a deck it couldn't hold waits its turn while the
			# others are tried, and a try at taking a lost deck back still
			# passes the hour, so a deck it can't hold is lost in the end.
			var next := ""
			for id in order:
				if not Progress.deck_state(id) in ["open", "lost"]:
					continue
				if next == "" or Progress.visits(id) < Progress.visits(next) \
						or (Progress.visits(id) == Progress.visits(next) and Progress.deck_state(id) == "open" and Progress.deck_state(next) == "lost"):
					next = id
			if next == "":
				break
			await _campaign_deck(next, skill_name, seed_n, minutes, visits)
		if Progress.core_open():
			reached = "core"
			_at_ring(skill_name)
			if await _campaign_deck("core", skill_name, seed_n, minutes, visits):
				reached = "ending"
	var states := {}
	for id in Decks.ORDER:
		states[id] = {"state": Progress.deck_state(id), "hours": Progress.hours_left(id),
			"survivors": Progress.survivors_saved(id), "visits": Progress.visits(id)}
	return {"campaign": true, "skill": skill_name, "seed": seed_n, "order": order, "reached": reached,
		"ending": EndingScreen.which() if reached == "ending" else null, "decks": states,
		"salvage_left": Progress.salvage(), "hour": Progress.hour(), "runs": visits, "kit": kit}


## One deck of the campaign, with tries; true if it was held.
func _campaign_deck(id: String, skill_name: String, seed_n: int, minutes: float, visits: Array) -> bool:
	var tries := MUST_TRIES if id == "hydroponics" or id == "core" else TRIES
	for attempt in tries:
		var rec := await play(id, skill_name, seed_n + attempt * 1000, minutes, {"mode": "campaign"})
		rec["attempt"] = attempt + 1
		rec["state_after"] = Progress.deck_state(id)
		rec["salvage_after"] = Progress.salvage()
		visits.append(rec)
		if rec["outcome"] != "died":
			return bool(rec["held"])
	# Down too often: back to the ring, which still takes the hour.
	Progress.finish_deck(id, {"held": false, "survivors": 0, "salvage": 0, "time": 0.0})
	return false


## Between decks: upgrades at a held deck's workbench, and spare cells.
func _at_ring(_skill_name: String) -> void:
	if Progress.held_decks().is_empty():
		return
	for u in BUY_ORDER:
		Progress.buy(u)
	while Progress.spare_cells() > 0:
		var best := ""
		for m in Decks.MIDDLE:
			if Progress.deck_state(m) == "open" and not Progress.has_spare_cell(m):
				if best == "" or Progress.hours_left(m) < Progress.hours_left(best):
					best = m
		if best == "" or not Progress.assign_cell(best):
			break

#endregion


func _print_table(result: Dictionary) -> void:
	print("")
	print("deck         skill    seed  outcome     min  deaths  kills  ammo left")
	for r in result.get("runs", []):
		print("%-12s %-8s %4d  %-10s %5.1f  %6d  %5d  %s" % [r["deck"], r["skill"], r["seed"], r["outcome"],
			r["minutes"], r["deaths"].size(), r["kills_total"], JSON.stringify(r["ammo_left"])])
	if result.get("campaign", false):
		print("campaign reached %s, ending %s" % [result["reached"], result["ending"]])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
