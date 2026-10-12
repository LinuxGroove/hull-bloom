extends Node
## The autopilot: plays a deck through the Tech's own controls, the way a
## person at the keyboard would. Walking, sprint, fire, aim, reload, the
## weapon keys and throws are the game's input actions (held with
## Input.action_press, as a held key is); use, shove, heal, stim and the
## lights are input events, as a key press sends them; the view turns by
## rotating the Tech's body and head, as the mouse does.
##
## It knows the deck map as the map panel shows it (rooms, doors, the growth
## and the roots), sees only what's in front of it and in line of sight, and
## never touches the creatures, the hearts or the Tech's numbers. Its skill
## (see skill.gd) sets its aim, reactions, how often it wanders off, and how
## well it uses the tools.
##
## It goes for the deck's goal: cut out the roots (the sprayer on the Heart,
## or venting its room), freeze back what's left until the deck holds, then
## take the lift, stopping for survivors, logs and supplies it sees on the way.

signal acted(kind: String, data: Dictionary)

const NavGrid := preload("res://tools/autopilot/nav_grid.gd")

## Seconds between decisions; aim and steering run every physics tick.
const THINK := 0.1
## What it notices without turning: the cosine of half its field of view,
## and how close something is heard or felt from any side.
const VIEW_COS := 0.45
const NOTICE_NEAR := 3.5
const MELEE := ["skitter", "stalker", "taken", "quadorb", "raptor", "trilobite", "quadshell"]
const BIG := ["stalker", "taken", "quadorb", "quadshell", "raptor", "trilobite"]
const FLIERS := ["watcher", "eyedrone", "gundrone", "feeder"]
## How far the sprayer reaches from the eye (a little short of its real reach).
const SPRAYER_REACH := 4.7
const FOCUS_REACH := 7.1
## The lift's console is used from the pad.
const USE_REACH := 1.3

var scene: DeckScene
var player: Tech
var level: DeckLevel
var skill := {}
var rng := RandomNumberGenerator.new()
var grid: NavGrid
## Game seconds since it took over.
var time := 0.0
## What it's doing, for the telemetry: "heart", "clear", "fight", "door"...
var mode := "start"
## The deck's goal right now and where it is, for telemetry's progress.
var goal_name := ""
var goal_point := Vector3.INF
## Set when it couldn't move for a long time and gave up.
var stuck_out := false
## Set once it has asked the lift to leave.
var leaving := false

# The path it's walking.
var _path: Array[Vector3] = []
var _doors: Array[String] = []
var _pi := 0
var _path_to := Vector3.INF
var _path_key := ""
var _path_age := 0.0
var _blocked_doors := {}
var _avoid := {}

# Doors on the way.
var _door: Bulkhead
var _door_stage := ""
var _door_t := 0.0
var _door_tries := 0

# What the hands and feet do this tick.
var _move := Vector3.ZERO
var _walk_path := false
var _sprint := false
var _look := Vector3.INF
var _aiming_at_target := false
var _fire := false
var _fire_tap := false
var _focus := false
var _next_tap := 0.0
var _pressed := {}
var _release_next: Array[String] = []
var _events_up: Array[String] = []
var _use_cool := 0.0
var _hold_throw_until := -1.0
## Set while the task only moves the feet (walking on during a fight).
var _feet_only := false
## The last place it stood on thin growth, to fall back toward.
var _safe_spot := Vector3.ZERO
var _grabbed_t := -1.0
var _debug := OS.get_environment("AUTOPILOT_DEBUG") != ""

# Aim wobble: degrees off in yaw and pitch, and a flick when it changes target.
var _err := Vector2.ZERO
var _flick := Vector2.ZERO
var _aim_id := 0

# What it has seen.
var _known := {}
## Things it gave up fighting (no shot for a long while): id -> until when.
var _ignore := {}
var _target: Node3D
var _hurt_from := Vector3.ZERO
var _hurt_t := -10.0
var _things: Array = []
var _things_t := 0.0
var _seen := {}
var _skip := {}
var _decided := {}
var _visited := {}

# The task in hand.
var _task := {}
var _lost_until := -1.0
var _explore_until := -1.0
var _think_t := 0.0
var _eng := {}
var _heart_order: Array = []
var _heart_t := -100.0

# Getting unstuck.
var _anchor := Vector3.ZERO
var _anchor_t := 0.0
var _unstick_until := -1.0
var _unstick_dir := Vector3.ZERO
var _unsticks := 0
var _still_since := 0.0
var _wanted_move := false


func _debug_print() -> void:
	var here := player.global_position
	var near := []
	for c in get_tree().get_nodes_in_group("creatures"):
		var cr := c as Creature
		if cr and not cr.dead and cr.global_position.distance_to(here) < 6.0:
			near.append("%s %.1fm st%d vis%s known%s sight%s" % [cr.kind, cr.global_position.distance_to(here), cr.state, cr.visible,
				_known.has(cr.get_instance_id()), _clear_sight(_eye(), aim_point(cr), cr)])
	print("DBG %.1f real=%d mem=%dMB proc=%.1fms phys=%.1fms fps=%d mode=%s task=%s hp=%d pos=(%.1f,%.1f) known=%d near=%s" % [time, Time.get_ticks_msec(),
		OS.get_static_memory_usage() / 1048576, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Engine.get_frames_per_second(), mode, _task.get("key", ""), player.health, here.x, here.z, _known.size(), near])


func setup(p_scene: DeckScene, p_skill: Dictionary, seed: int) -> void:
	scene = p_scene
	player = scene.player
	level = scene.level
	skill = p_skill
	rng.seed = seed
	name = "Autopilot"
	process_physics_priority = -100
	player.hurt.connect(_on_hurt)
	grid = NavGrid.new()
	grid.build(level, player.get_world_3d().direct_space_state)
	_anchor = player.global_position
	_safe_spot = player.global_position
	_explore_until = -1.0


#region Every tick

func _physics_process(delta: float) -> void:
	if scene == null or not is_instance_valid(scene) or scene.run.over or player.is_dead:
		release_all()
		return
	time += delta
	_flush_taps()
	_use_cool -= delta
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = THINK
		_think()
	_steer_view(delta)
	_drive(delta)
	_triggers()
	if _debug and int(time * 2.0) != int((time - delta) * 2.0):
		_debug_print()


## Lets go of every key it holds.
func release_all() -> void:
	for a in _pressed.keys():
		Input.action_release(a)
	_pressed.clear()
	_flush_taps()


func _hold(action: String, on: bool, strength := 1.0) -> void:
	if on:
		Input.action_press(action, strength)
		_pressed[action] = true
	elif _pressed.has(action):
		Input.action_release(action)
		_pressed.erase(action)


## Presses a held action for this tick only (a key tapped).
func _tap(action: String) -> void:
	Input.action_press(action)
	_release_next.append(action)


## A key press the game reads as an input event (use, heal, shove...).
func _press_event(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	_events_up.append(action)


func _flush_taps() -> void:
	for a in _release_next:
		if not _pressed.has(a):
			Input.action_release(a)
	_release_next.clear()
	for a in _events_up:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = false
		Input.parse_input_event(e)
	_events_up.clear()

#endregion

#region Deciding

func _think() -> void:
	_fire = false
	_fire_tap = false
	_focus = false
	_look = Vector3.INF
	_aiming_at_target = false
	_move = Vector3.ZERO
	_walk_path = false
	_perceive()
	_check_stuck()
	if player.grabbed_by != null:
		_break_free()
		return
	_grabbed_t = -1.0
	_look_after_self()
	if _task.get("kind", "") == "throw" or _use_tools():
		_work_throw()
		return
	var pushing := _pushing()
	var falling_back := not pushing and _falling_back()
	if _fight(pushing or falling_back):
		if pushing or falling_back:
			_run_and_gun("fall back" if falling_back else "push")
		return
	_reload_when_quiet()
	_plan()
	_work()


## What it's fighting and how far off, and how many things it knows of, for
## the telemetry's trace.
func target_info() -> Array:
	var kind := ""
	var d := -1.0
	if is_instance_valid(_target) and mode in ["fight", "push", "fall back"]:
		kind = kind_of(_target)
		d = snappedf(_target.global_position.distance_to(player.global_position), 0.1)
	return [kind, d, _known.size(), String(_task.get("key", ""))]


func _set_mode(m: String) -> void:
	if m != mode:
		mode = m


## Where the deck's goal is now: the nearest living Heart, the thickest
## growth once they're cut, then the lift.
func _update_goal() -> void:
	if scene.run.held:
		goal_name = "lift"
		goal_point = DeckLevel.center(level.lift_cell)
	elif level.bloom.roots_alive() > 0:
		var h := _nearest_heart()
		goal_name = "heart"
		goal_point = h.global_position if h else Vector3.INF
	else:
		goal_name = "clear"
		var t := _thickest_tile()
		goal_point = DeckLevel.center(t) if t != Vector2i(9999, 9999) else Vector3.INF

#endregion

#region Seeing

func _eye() -> Vector3:
	return player.camera.global_position


func _forward() -> Vector3:
	return -player.camera.global_transform.basis.z


func _perceive() -> void:
	var eye := _eye()
	var fwd := _forward()
	var room := level.room_at(player.global_position)
	if level.bloom.level_at(DeckLevel.cell_at(player.global_position)) < Director.REGROW_LEVEL:
		_safe_spot = player.global_position
	if room != "":
		_visited[room] = true
	for c in get_tree().get_nodes_in_group("creatures"):
		var cr := c as Creature
		if cr == null or cr.dead or not cr.visible:
			continue
		_notice(cr, eye, fwd, 34.0)
	for p in get_tree().get_nodes_in_group("pods"):
		var pod := p as Pod
		if pod == null or pod.dead:
			continue
		_notice(pod, eye, fwd, 18.0)
	for id in _known.keys():
		var k: Dictionary = _known[id]
		if not is_instance_valid(k["node"]) or (k["node"] as Node).get("dead") == true or time - float(k["last"]) > 6.0 or _ignore.get(id, -1.0) > time:
			_known.erase(id)
	_things_t -= THINK
	if _things_t <= 0.0:
		_things_t = 1.5
		_things = []
		for kind in ["Pickup", "LogTerminal", "Survivor", "VentPanel"]:
			_things.append_array(level.find_children("", kind, true, false))
		# What robots drop lands outside the level.
		_things.append_array(scene.director.find_children("", "Pickup", true, false))
	for t in _things:
		if not is_instance_valid(t):
			continue
		var n := t as Node3D
		if n.is_queued_for_deletion():
			continue
		var id := n.get_instance_id()
		if _seen.has(id):
			continue
		var p := n.global_position + Vector3(0, 0.4, 0)
		var to := p - eye
		var d := to.length()
		if d > 14.0 or (d > 4.0 and fwd.dot(to / d) < 0.2):
			continue
		if _clear_sight(eye, p, n):
			_seen[id] = n


func _notice(n: Node3D, eye: Vector3, fwd: Vector3, most: float) -> void:
	var p := aim_point(n)
	var to := p - eye
	var d := to.length()
	if d > most:
		return
	var id := n.get_instance_id()
	if _ignore.get(id, -1.0) > time:
		return
	var hurt_lately := time - _hurt_t < 1.5 and _hurt_from.dot(to / d) > 0.3
	if fwd.dot(to / maxf(d, 0.01)) < VIEW_COS and d > NOTICE_NEAR and not hurt_lately and not _known.has(id):
		return
	if not _clear_sight(eye, p, n):
		return
	if not _known.has(id):
		_known[id] = {"node": n, "first": time, "last": time}
	else:
		_known[id]["last"] = time


## Whether the line from the eye to a spot is clear of walls and shut doors
## (the thing's own body doesn't count).
func _clear_sight(eye: Vector3, p: Vector3, n: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(eye, p, Kit.LAYER_SOLID)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return true
	var col: Node = h.collider
	return col != null and (col == n or n.is_ancestor_of(col)) or (h.position as Vector3).distance_to(p) < 0.4


## Whether nothing solid stands between two spots.
func _los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Kit.LAYER_SOLID)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	return h.is_empty() or (h.position as Vector3).distance_to(b) < 0.4


## Whether a shot from the eye at a spot would hit `n` (or something else
## alive) before a wall.
func _clear_shot(p: Vector3, n: Node) -> bool:
	var eye := _eye()
	var q := PhysicsRayQueryParameters3D.create(eye, p + (p - eye).normalized() * 0.5, Kit.SHOT_MASK)
	q.collide_with_areas = true
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return true
	var o := Hit.owner_of(h.collider)
	if o == null:
		return false
	return o == n or n.is_ancestor_of(o) or o is Creature or o is Pod or (o is Heart and n is Heart)


## Where to aim at something: the middle of its main hitbox.
func aim_point(n: Node3D) -> Vector3:
	var best: CollisionShape3D = null
	for a in n.find_children("Hit_*", "Area3D", true, false):
		var area := a as Area3D
		if area.collision_layer == 0 or area.get_child_count() == 0:
			continue
		var cs := area.get_child(0) as CollisionShape3D
		if cs == null:
			continue
		if best == null or String(area.name) in ["Hit_body", "Hit_pod", "Hit_heart"]:
			best = cs
	if best:
		return best.global_position
	return n.global_position + Vector3(0, 0.8, 0)


func _on_hurt(_amount: float, from_dir: Vector3) -> void:
	if from_dir.length() > 0.01 and absf(from_dir.normalized().y) < 0.9:
		_hurt_from = -Vector3(from_dir.x, 0, from_dir.z).normalized()
		_hurt_t = time

#endregion

#region Staying alive

func _break_free() -> void:
	_set_mode("grabbed")
	var f := player.grabbed_by as Node3D
	if _grabbed_t < 0.0:
		_grabbed_t = time
	_look = f.global_position
	if _use_cool <= 0.0:
		_use_cool = 0.75 + rng.randf_range(0.0, 0.2)
		_press_event("shove")
		acted.emit("shove", {})
	# Still held after a few shoves: cut the tendril, or shoot the thing.
	if time - _grabbed_t < 2.0 + float(skill["reaction"]) * 2.0:
		return
	var box := f.find_child("Hit_tendril", true, false) as Node3D
	var p := box.global_position if box and _roll("tendril:%d" % f.get_instance_id(), float(skill["weapon_sense"])) else aim_point(f)
	_look = p
	_aiming_at_target = true
	var near := _eye().distance_to(p) < SPRAYER_REACH
	_select("sprayer" if near and not player.arsenal.iced else ("rivet_gun" if "rivet_gun" in player.arsenal.owned else "sprayer"))
	if _forward().angle_to(p - _eye()) < 0.3 and player.arsenal.swapping <= 0.0:
		if player.arsenal.current == "sprayer" or bool(player.arsenal.stat(player.arsenal.current).get("auto", false)):
			_fire = true
		else:
			_fire_tap = true


func _look_after_self() -> void:
	var near := _nearest_threat_distance()
	var heal_at := float(skill["heal_at"])
	if player.items["medkit"] > 0 and player.health < heal_at and player.health < player.max_health:
		var forget := _roll("heal_forget:%d" % int(time / 20.0), float(skill["heal_forget"]))
		var wait: bool = skill["heal_waits"] and near < 5.0 and player.health > heal_at * 0.6
		if not forget and not wait and _use_cool <= 0.0 and player._heal_left <= 0.0:
			_use_cool = 0.4
			_press_event("heal")
			acted.emit("medkit", {"health": roundi(player.health)})
	if player.items["stim"] > 0 and player.infection >= float(skill["stim_at"]) and player.immune <= 0.0 and _use_cool <= 0.0:
		_use_cool = 0.4
		_press_event("stim")
		acted.emit("stim", {"infection": roundi(player.infection)})


func _nearest_threat_distance() -> float:
	var best := INF
	for id in _known:
		var c := _creature(id)
		if c and time - float(_known[id]["last"]) < 1.0:
			best = minf(best, c.global_position.distance_to(player.global_position))
	return best

#endregion

#region Fighting

## Picks what to fight, and fights it. False when there's nothing to.
func _fight(pushing := false) -> bool:
	var best: Node3D = null
	var best_score := -INF
	var reaction := float(skill["reaction"])
	var at_heart: bool = _task.get("kind", "") == "heart" and _task.get("in_reach", false)
	for id in _known:
		var k: Dictionary = _known[id]
		if not is_instance_valid(k["node"]) or time - float(k["last"]) > 2.5 or time - float(k["first"]) < reaction:
			continue
		var n: Node3D = k["node"]
		var d := n.global_position.distance_to(player.global_position)
		var score := 100.0 - d * 3.0
		if n is Pod:
			var pod := n as Pod
			if not _roll("pod:%d" % id, float(skill["shoot_pods"])) or d < Pod.SPORE_RANGE + 0.5 or d > 15.0:
				continue
			if at_heart:
				continue
			score = 30.0 - d + (15.0 if pod.awake else 0.0)
		else:
			var c := n as Creature
			var awake := c.state != Creature.State.ASLEEP
			if not awake and d > 7.0:
				continue
			if c.kind == "feeder":
				var flat := Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length()
				if flat > 9.0 and not c.grabbing:
					continue
				score += 10.0
			if c.state in [Creature.State.HUNT, Creature.State.ATTACK]:
				score += 30.0
			if c.kind == "watcher" and float(skill["weapon_sense"]) > 0.9:
				score += 25.0
			if at_heart and d > 5.0 and c.state != Creature.State.ATTACK and c.kind != "watcher":
				continue
			# Pressing on: at the Heart, only what's on top of it and too big
			# to shrug off when it's already hurt.
			if pushing and at_heart and not (c.kind in BIG and d < 2.2 and player.health < 45.0):
				continue
			if pushing and d > 10.0 and c.state != Creature.State.ATTACK:
				continue
		if n == _target:
			score += 15.0
		if score > best_score:
			best_score = score
			best = n
	if best == null:
		_target = null
		_eng = {}
		return false
	_engage(best)
	return true


## Whether it presses on to a Heart that's near through what's in the way,
## shooting as it goes, rather than standing to fight what the Heart keeps
## hatching: a better player's habit, decided now and then.
func _pushing() -> bool:
	if _task.get("kind", "") != "heart" or not is_instance_valid(_task.get("node")):
		return false
	var h := _task["node"] as Heart
	if h.dead or h.global_position.distance_to(player.global_position) > 22.0 * (1.5 if h.big else 1.0):
		return false
	if player.health < float(skill["heal_at"]) * 0.6 and player.items["medkit"] <= 0:
		return false
	# A pack on its heels: deal with it first, unless the Heart's in reach.
	var near_heart := h.global_position.distance_to(player.global_position) < 8.0 * (1.5 if h.big else 1.0)
	if not near_heart and _awake_near(14.0) > 1 and _roll("clear_first", float(skill["careful"])):
		return false
	return _roll("push:%d:%d" % [h.get_instance_id(), int(time / 30.0)], float(skill["push"]))


## Whether it backs out toward a quiet room, still shooting, once the Heart
## is dead and the growth round it keeps hatching: the regroup task (a
## careful player's habit, see _pick_task) carried on through the fight.
func _falling_back() -> bool:
	if _task.get("kind", "") == "heart":
		var h = _task.get("node")
		if not is_instance_valid(h) or (h as Heart).dead:
			_plan()
	if not _task.get("regroup", false):
		return false
	var p: Vector3 = _task.get("point", Vector3.INF)
	return p != Vector3.INF and Vector3(player.global_position.x, 0, player.global_position.z).distance_to(p) >= 1.5


## How many things it knows of within `r` metres that are after it.
func _awake_near(r: float) -> int:
	var n := 0
	for id in _known:
		var c := _creature(id)
		if c and c.state in [Creature.State.HUNT, Creature.State.ATTACK] and c.global_position.distance_to(player.global_position) < r:
			n += 1
	return n


## Walks on with the task (toward the Heart, or back to a quiet room) while
## the eyes and hands stay on the fight.
func _run_and_gun(m: String) -> void:
	var keep := [_look, _aiming_at_target, _fire, _fire_tap, _focus, mode]
	_move = Vector3.ZERO
	_feet_only = true
	_work()
	_feet_only = false
	_look = keep[0]
	_aiming_at_target = keep[1]
	_fire = keep[2]
	_fire_tap = keep[3]
	_focus = keep[4]
	_set_mode(m)
	if _eng.has("weapon"):
		_select(String(_eng["weapon"]))


func _engage(n: Node3D) -> void:
	_set_mode("fight")
	if n != _target or time - float(_eng.get("weapon_t", -10.0)) > 1.5:
		var first := n != _target
		_target = n
		var d := n.global_position.distance_to(player.global_position)
		var w := _pick_weapon(n, d, first)
		_eng = {"weapon": w, "weapon_t": time, "backs": _roll("back:%d:%d" % [n.get_instance_id(), int(time / 10.0)], float(skill["backs_off"]))}
		if first:
			_new_aim_target(n)
	var w: String = _eng["weapon"]
	_select(w)
	var p := aim_point(n)
	_look = p
	_aiming_at_target = true
	var ars := player.arsenal
	var eye := _eye()
	var to := p - eye
	var d := to.length()
	var radius := 0.5
	if n is Creature:
		radius = maxf(0.25, (n as Creature).radius)
	var tol := maxf(atan2(radius, d), deg_to_rad(1.2)) * float(skill["fire_tolerance"])
	var off := _forward().angle_to(to)
	var shot := _clear_shot(p, n)
	var reach := 60.0
	if w == "sprayer":
		reach = SPRAYER_REACH
	elif w == "scattergun":
		reach = 14.0
	if shot:
		_eng["shot_t"] = time
	elif time - float(_eng.get("shot_t", time)) > 8.0:
		# No shot at it for a long while (behind glass, out of reach): leave it.
		_ignore[n.get_instance_id()] = time + 30.0
		acted.emit("gave_up_target", {"kind": kind_of(n)})
	if not _eng.has("shot_t"):
		_eng["shot_t"] = time
	if shot and off < tol and d <= reach and ars.reloading <= 0.0 and ars.swapping <= 0.0:
		if w == "sprayer" or bool(ars.stat(w).get("auto", false)):
			_fire = true
		else:
			_fire_tap = true
		_focus = w != "sprayer" and d > 8.0 and float(skill["weapon_sense"]) > 0.5
	# Feet: back off from claws, close in when there's no shot.
	var flat := Vector3(player.global_position.x - n.global_position.x, 0, player.global_position.z - n.global_position.z)
	var kind := kind_of(n)
	# A shove buys a moment against something big at arm's length.
	if kind in BIG and flat.length() < 2.0 and off < 0.6 and _use_cool <= 0.0 \
			and _roll("shove:%d:%d" % [n.get_instance_id(), int(time / 3.0)], float(skill["shove"])):
		_use_cool = 0.75
		_press_event("shove")
		acted.emit("shove", {"kind": kind})
	if kind in MELEE and flat.length() < 3.5 and _eng.get("backs", false):
		_move = _kite_dir()
	elif not shot or d > reach:
		var dest := n.global_position
		if kind in FLIERS or n is Pod:
			dest = Vector3(n.global_position.x, 0, n.global_position.z)
		_go(dest, "chase:%d" % n.get_instance_id(), 1.0)
		_walk_path = true


## The way to step back from what's clawing at it: away from the things
## near it, onto free floor, out of thick growth if it can.
func _kite_dir() -> Vector3:
	var here := player.global_position
	var push := Vector3.ZERO
	for id in _known:
		var c := _creature(id)
		if c == null or not c.kind in MELEE:
			continue
		var v := Vector3(here.x - c.global_position.x, 0, here.z - c.global_position.z)
		var d := v.length()
		if d < 7.0 and d > 0.01:
			push += v / d * (7.0 - d)
	if push.length() < 0.01:
		return Vector3.ZERO
	push = push.normalized()
	# Back the way it came, toward thinner growth, rather than into a corner.
	var back := Vector3(_safe_spot.x - here.x, 0, _safe_spot.z - here.z)
	back = back.normalized() if back.length() > 1.0 else Vector3.ZERO
	var best := Vector3.ZERO
	var best_s := -INF
	for k in 16:
		var a := TAU * k / 16.0
		var dir := Vector3(cos(a), 0, sin(a))
		if not grid.free_at(here + dir * 0.8) or not grid.free_at(here + dir * 1.6):
			continue
		var sc := dir.dot(push) + dir.dot(back) * 0.5
		for r: float in [2.4, 3.2]:
			if grid.free_at(here + dir * r):
				sc += 0.1
		if level.bloom.level_at(DeckLevel.cell_at(here + dir * 2.0)) >= 3.0:
			sc -= 0.3
		if sc > best_s:
			best_s = sc
			best = dir
	return best if best_s > -0.2 else Vector3.ZERO


## The gun for the job: the right one for what it's fighting, if the skill
## picks it, with rounds left.
func _pick_weapon(n: Node3D, d: float, fresh: bool) -> String:
	var ars := player.arsenal
	var current := ars.current
	if fresh and not _roll("sense:%d" % n.get_instance_id(), float(skill["weapon_sense"])):
		if current != "sprayer" or d < SPRAYER_REACH:
			if _has_rounds(current):
				return current
	var kind := kind_of(n)
	var order: Array = []
	match kind:
		"pod":
			order = ["rivet_gun", "rifle", "smg", "rail"]
		"skitter":
			# The spray is quick death to spawn close in, while it's clear.
			var beam := d < SPRAYER_REACH and not ars.iced and ars.ice < (75.0 if current == "sprayer" else 45.0)
			if current == "scattergun" and d < 8.0 and _has_rounds(current):
				return current
			order = (["sprayer"] if beam else []) + (["scattergun"] if d < 8.0 else []) + ["smg", "rifle", "rivet_gun"]
		"watcher", "eyedrone", "gundrone", "feeder":
			order = ["rifle", "rivet_gun", "smg", "rail"] + (["scattergun"] if d < 6.0 else [])
		_:
			order = ["rail"] + (["scattergun"] if d < 9.0 else []) + ["rifle", "smg", "rivet_gun"]
	for w in order:
		if w in ars.owned and _has_rounds(w):
			return w
	return "rivet_gun" if "rivet_gun" in ars.owned else "sprayer"


func _has_rounds(w: String) -> bool:
	if w == "sprayer":
		return true
	var ars := player.arsenal
	if int(ars.stat(w).get("carry", 0)) < 0:
		return true
	return int(ars.mag.get(w, 0)) + int(ars.reserve.get(w, 0)) > 0


func _select(w: String) -> void:
	if _feet_only:
		return
	var ars := player.arsenal
	if ars.current == w or not w in ars.owned or ars.swapping > 0.0:
		return
	_tap("weapon_%d" % int(Arsenal.WEAPONS[w]["slot"]))


static func kind_of(n: Node) -> String:
	if n is Creature:
		return (n as Creature).kind
	if n is Heart:
		return "heart"
	if n is Pod:
		return "pod"
	return String(n.name).to_lower()


func _new_aim_target(n: Node) -> void:
	if n == null or n.get_instance_id() == _aim_id:
		return
	_aim_id = n.get_instance_id()
	var e := float(skill["aim_error"]) * 2.5
	_flick = Vector2(rng.randfn(0.0, e), rng.randfn(0.0, e * 0.6))


func _reload_when_quiet() -> void:
	var ars := player.arsenal
	var w := ars.current
	if w == "sprayer" or ars.reloading > 0.0 or not skill["tactical_reload"]:
		return
	var spec := ars.stat(w)
	if int(ars.mag.get(w, 0)) < int(spec["mag"]) * 0.6 and (int(spec["carry"]) < 0 or int(ars.reserve.get(w, 0)) > 0):
		_tap("reload")
		acted.emit("reload", {"weapon": w, "left": int(ars.mag.get(w, 0))})

#endregion

#region Tools

## Grenades, mines, flares and the lights. True when it starts a throw.
func _use_tools() -> bool:
	var ars := player.arsenal
	# A grenade into a pack, or at something big.
	if player.items["grenade"] > 0 and _cool("grenade", 6.0):
		var pack := _pack()
		# Only where it can see to throw: a grenade off a door frame comes back.
		if not pack.is_empty() and _los(_eye(), pack["at"] + Vector3(0, 0.6, 0)) \
				and _roll("grenade:%d" % int(time / 15.0), float(skill["grenade"])):
			_throw("grenade", pack["at"])
			return true
	# A mine in front of something big that's coming, far enough off that the
	# mine arms first and the Tech is out of its blast (a throw lands about
	# six metres out).
	if player.items["mine"] > 0 and _cool("mine", 10.0):
		for id in _known:
			var c := _creature(id)
			if c and c.kind in BIG and c.state == Creature.State.HUNT:
				var d := c.global_position.distance_to(player.global_position)
				if d > 10.0 and d < 16.0 and _los(_eye(), c.global_position + Vector3(0, 0.6, 0)) \
						and _roll("mine:%d" % id, float(skill["mine"])):
					_throw("mine", player.global_position.lerp(c.global_position, 0.4))
					return true
	# A flare where the growth is spreading.
	if player.items["flare"] > 0 and _cool("flare", 40.0) and _known.is_empty():
		var t := _spreading_tile()
		if t != Vector2i(9999, 9999) and _roll("flare:%s" % t, float(skill["flare"])):
			_throw("flare", DeckLevel.center(t))
			return true
	# The lights where the growth is coming, with a cell to spare for the lift.
	var room := level.room_at(player.global_position)
	if room != "" and _cool("lights", 5.0) and scene.power.free_cells() >= 2 and not scene.power.has("lights:" + room):
		var lvl := level.bloom.room_level(room)
		if not level.rooms[room]["dark"] and lvl > 0.2 and lvl < 3.0 and level.bloom.roots_alive() > 0:
			if _roll("lights:" + room, float(skill["lights"])):
				_press_event("power_lights")
				acted.emit("lights", {"room": room})
	if ars.current != "sprayer" and _known.is_empty() and ars.reloading <= 0.0 and _task.get("kind", "") in ["heart", "clear"] and _task.get("in_reach", false):
		_select("sprayer")
	return false


## A creature it knows of, or null if it's gone.
func _creature(id: int) -> Creature:
	var n: Variant = _known[id]["node"]
	if not is_instance_valid(n):
		return null
	return n as Creature


func _cool(what: String, gap: float) -> bool:
	return time - float(_decided.get("t:" + what, -1000.0)) > gap


## A throw: picks the throwable (holding the key cycles them), then taps.
func _throw(what: String, at: Vector3) -> void:
	_decided["t:" + what] = time
	_task = {"kind": "throw", "key": "throw:%s:%d" % [what, int(time)], "what": what, "at": at, "since": time, "cycles": 0}


## Somewhere three or more awake things are bunched up, a safe way off.
func _pack() -> Dictionary:
	var list: Array[Vector3] = []
	var big := false
	for id in _known:
		var c := _creature(id)
		if c == null or c.state == Creature.State.ASLEEP or c.kind in FLIERS:
			continue
		var d := c.global_position.distance_to(player.global_position)
		if d < 7.5 or d > 15.0:
			continue
		list.append(c.global_position)
		big = big or c.kind in ["stalker", "raptor", "trilobite"]
	if list.size() >= 3 or (big and list.size() >= 1):
		var mid := Vector3.ZERO
		for p in list:
			mid += p
		return {"at": mid / list.size()}
	return {}


## A tile in view where the growth is creeping in: low, fed and unlit.
func _spreading_tile() -> Vector2i:
	var b := level.bloom
	var fed := b.fed()
	var eye := _eye()
	var best := Vector2i(9999, 9999)
	var best_d := INF
	for i in b.cells.size():
		var g := b.growth[i]
		if g < 0.3 or g > 2.5 or fed[i] == 0 or b.is_lit(i):
			continue
		var p := DeckLevel.center(b.cells[i]) + Vector3(0, 0.3, 0)
		var d := p.distance_to(eye)
		if d < 4.0 or d > 11.0:
			continue
		if not _los(eye, p):
			continue
		if d < best_d:
			best_d = d
			best = b.cells[i]
	return best

#endregion

#region Tasks

func _plan() -> void:
	_update_goal()
	if not _task.is_empty() and _task["kind"] == "throw":
		return
	var want := _pick_task()
	if want.is_empty():
		_task = {}
		return
	if _task.is_empty() or want["key"] != _task["key"]:
		want["since"] = time
		_task = want
		_drop_path()
		acted.emit("task", {"task": want["key"]})


func _pick_task() -> Dictionary:
	var run := scene.run
	var calm := _known.is_empty()
	# Finish what's in hand when it's a use in progress.
	if not _task.is_empty() and _task.get("busy", false) and time - float(_task["since"]) < 20.0:
		return _task
	if calm:
		var side := _side_trip()
		if not side.is_empty():
			return side
	if run.held:
		if _explore_until < 0.0:
			_explore_until = time + (150.0 if _roll("explore", float(skill["explore"])) else 0.0)
		if time < _explore_until:
			var r := _unvisited_room()
			if r != "":
				return {"kind": "explore", "key": "explore:" + r, "point": _room_point(r)}
		return {"kind": "leave", "key": "leave"}
	if time < _lost_until and not _task.is_empty() and _task["kind"] == "wander":
		return _task
	if level.bloom.roots_alive() > 0:
		if rng.randf() < float(skill["lost_per_min"]) * THINK / 60.0 and calm:
			var r := _random_room()
			if r != "":
				_lost_until = time + rng.randf_range(12.0, 30.0)
				acted.emit("lost", {"to": r})
				return {"kind": "wander", "key": "wander:%s:%d" % [r, int(time)], "point": _room_point(r)}
		var vent := _vent_choice()
		if not vent.is_empty():
			return vent
		if calm:
			var room := _scout_room()
			if room != "":
				return {"kind": "explore", "key": "scout:" + room, "point": _room_point(room), "busy": true}
		var h := _nearest_heart()
		if h:
			return {"kind": "heart", "key": "heart:%d" % h.get_instance_id(), "node": h}
		return {}
	# The Heart's dead but the growth is still thick enough to hatch: a
	# careful player who's hurt or crowded falls back somewhere quiet while
	# it dies back, then freezes the rest.
	if _roll("careful:clear", float(skill["careful"])) and level.bloom.max_level() >= Director.REGROW_LEVEL \
			and (player.health < 60.0 or _known.size() >= 3 or _task.get("regroup", false)):
		var room := _safe_room()
		if room != "":
			if level.room_at(player.global_position) == room:
				var seal := _seal_choice(room)
				if not seal.is_empty():
					return seal
			return {"kind": "explore", "key": "regroup:" + room, "point": _room_point(room), "regroup": true}
	var t := _clear_choice()
	if t != Vector2i(9999, 9999):
		return {"kind": "clear", "key": "clear:%s" % t, "tile": t}
	# Nothing left it can reach: look round while the rest dies back.
	var r2 := _unvisited_room()
	if r2 == "":
		r2 = _random_room()
	return {"kind": "explore", "key": "wait:" + r2, "point": _room_point(r2)}


## Something worth a detour that it has seen: a survivor, supplies it needs,
## a log it's curious about.
func _side_trip() -> Dictionary:
	var best := {}
	var best_d := INF
	for id in _seen:
		if _skip.has(id):
			continue
		if not is_instance_valid(_seen[id]):
			_skip[id] = true
			continue
		var n := _seen[id] as Node3D
		if n.is_queued_for_deletion():
			_skip[id] = true
			continue
		var d := n.global_position.distance_to(player.global_position)
		var kind := ""
		if n is Survivor:
			if (n as Survivor).is_found:
				_skip[id] = true
				continue
			kind = "survivor"
			d -= 10.0
		elif n is Pickup:
			if not _wants(n as Pickup):
				continue
			kind = "pickup"
		elif n is LogTerminal:
			if not _roll("log:%d" % id, float(skill["curiosity"])):
				_skip[id] = true
				continue
			kind = "log"
		else:
			continue
		if d > 16.0:
			continue
		if d < best_d:
			best_d = d
			best = {"kind": kind, "key": "%s:%d" % [kind, id], "node": n}
	return best


func _wants(p: Pickup) -> bool:
	if p.taken:
		return false
	var b := p.base()
	match b:
		"ammo":
			var w := p.detail()
			if w == "" or w == "any":
				return true
			if not w in player.arsenal.owned:
				return false
			return int(player.arsenal.reserve.get(w, 0)) < int(player.arsenal.stat(w).get("carry", 0))
		"health":
			return player.health < player.max_health - 5.0
		"salvage", "cell", "keycard", "weapon":
			return true
	if player.items.has(b):
		return int(player.items[b]) < player.carry_limit(b)
	return true


func _vent_choice() -> Dictionary:
	for t in _things:
		if not is_instance_valid(t) or not t is VentPanel:
			continue
		var v := t as VentPanel
		if v.used:
			continue
		var has_root := false
		for k in level.bloom.roots.size():
			if level.bloom.root_alive[k] == 1 and level.tiles.get(level.bloom.cells[level.bloom.roots[k]], "") == v.room_id:
				has_root = true
		if has_root and _roll("vent:" + v.room_id, float(skill["vent"])):
			return {"kind": "vent", "key": "vent:" + v.room_id, "node": v}
	return {}


func _nearest_heart() -> Heart:
	var best: Heart = null
	var best_d := INF
	for h in scene.director.hearts:
		if not is_instance_valid(h) or h.dead:
			continue
		var d := h.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


## The tile with the most growth on it.
func _thickest_tile() -> Vector2i:
	var b := level.bloom
	var best := Vector2i(9999, 9999)
	var best_g := 0.0
	for i in b.cells.size():
		if b.growth[i] > best_g:
			best_g = b.growth[i]
			best = b.cells[i]
	return best


## The next tile to freeze: near, thick, and somewhere it can stand.
func _clear_choice() -> Vector2i:
	if _task.get("kind", "") == "clear" and level.bloom.level_at(_task["tile"]) >= 0.95 and not _skip.has(str(_task["tile"])):
		return _task["tile"]
	var b := level.bloom
	var best := Vector2i(9999, 9999)
	var best_s := INF
	var here := player.global_position
	for i in b.cells.size():
		if b.growth[i] < 1.0:
			continue
		var c: Vector2i = b.cells[i]
		if _skip.has(str(c)):
			continue
		var s := DeckLevel.center(c).distance_to(here) - b.growth[i] * 2.0
		# Careful players freeze inward from the edge of it.
		if _roll("careful:clear", float(skill["careful"])) and _edge_of(c) == Vector2i(9999, 9999):
			s += 20.0
		if s < best_s:
			best_s = s
			best = c
	return best


func _unvisited_room() -> String:
	var best := ""
	var best_d := INF
	for id in level.room_ids:
		if _visited.has(id) or _skip.has("room:" + id):
			continue
		var p := _room_point(id)
		if p == Vector3.INF:
			continue
		var d := p.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


## A side room near the way that it hasn't looked in yet, if its skill
## makes it look (for supplies, guns and survivors before the Heart).
func _scout_room() -> String:
	var here := player.global_position
	for id in level.room_ids:
		if _visited.has(id) or not _room_ok(id):
			continue
		var p := _room_point(id)
		if p == Vector3.INF or level.bloom.level_at(DeckLevel.cell_at(p)) >= 3.0:
			continue
		var near := INF
		for c in level.rooms[id]["cells"]:
			near = minf(near, DeckLevel.center(c).distance_to(here))
		if near > 9.0:
			continue
		if _roll("scout:" + id, float(skill["scout"])):
			return id
	return ""


## A door from this room into growth to seal behind it, if its skill thinks
## of it and there's a cell to spare beside the lift's.
func _seal_choice(room: String) -> Dictionary:
	if scene.power.free_cells() < 2:
		return {}
	for key in level.doors:
		var d: Bulkhead = level.doors[key]
		if d.sealed or d.jammed or d.airless or d.locked != "" or _skip.has("seal:" + key):
			continue
		var ra: String = level.tiles.get(d.a, "")
		var rb: String = level.tiles.get(d.b, "")
		if ra != room and rb != room:
			continue
		var other: Vector2i = d.b if ra == room else d.a
		if level.bloom.level_at(other) < 1.0:
			continue
		if _roll("seal:" + key, float(skill["seal"])):
			return {"kind": "seal", "key": "seal:" + key, "node": d, "busy": true}
	return {}


func _work_seal() -> void:
	var d := _task["node"] as Bulkhead
	if d.sealed or time - float(_task["since"]) > 20.0:
		_done("seal:" + d.key)
		return
	_set_mode("seal")
	var panel := d.get_node("Panel") as Node3D
	if _use(panel, panel.global_position) == "used":
		acted.emit("seal", {"door": d.key})


## The nearest room with no growth to speak of and nothing known in it.
func _safe_room() -> String:
	if _task.get("regroup", false):
		return String(_task["key"]).trim_prefix("regroup:")
	var here := player.global_position
	var best := ""
	var best_d := INF
	for id in level.room_ids:
		var thin := true
		for c in level.rooms[id]["cells"]:
			if level.bloom.level_at(c) >= 1.0:
				thin = false
				break
		var p := _room_point(id)
		if not thin or p == Vector3.INF or _skip.has("room:" + id):
			continue
		var d := p.distance_to(here)
		for kid in _known:
			var c := _creature(kid)
			if c and c.global_position.distance_to(p) < 8.0:
				d += 30.0
		if d < best_d:
			best_d = d
			best = id
	return best


func _random_room() -> String:
	var ids: Array = level.room_ids.filter(_room_ok)
	if ids.is_empty():
		return ""
	return ids[rng.randi() % ids.size()]


func _room_ok(id: String) -> bool:
	return not _skip.has("room:" + id) and _room_point(id) != Vector3.INF and level.room_at(player.global_position) != id


## A spot to stand in a room: its middle tile, or the nearest free cell.
func _room_point(id: String) -> Vector3:
	var cells: Array = level.rooms[id]["cells"]
	var c: Vector2i = cells[cells.size() / 2]
	var i := grid.nearest_free(DeckLevel.center(c), 2.0)
	if i < 0:
		for k in cells:
			i = grid.nearest_free(DeckLevel.center(k), 2.0)
			if i >= 0:
				break
	return grid.world_of(i) if i >= 0 else Vector3.INF


func _work() -> void:
	if _task.is_empty():
		_set_mode("idle")
		return
	if _task.has("node") and not is_instance_valid(_task["node"]):
		_task = {}
		_drop_path()
		return
	match String(_task["kind"]):
		"heart":
			_work_heart()
		"clear":
			_work_clear()
		"leave":
			_work_leave()
		"pickup":
			_work_pickup()
		"log":
			_work_log()
		"survivor":
			_work_survivor()
		"vent":
			_work_vent()
		"seal":
			_work_seal()
		"wander", "explore":
			_work_walk()
		"throw":
			_work_throw()


func _done(skip_key = null) -> void:
	if skip_key != null:
		_skip[skip_key] = true
	_task = {}
	_drop_path()


func _work_heart() -> void:
	var h := _task["node"] as Heart
	if not is_instance_valid(h) or h.dead:
		_done()
		return
	_set_mode("heart")
	var p := aim_point(h)
	var eye := _eye()
	var d := eye.distance_to(p) - 1.0
	var ars := player.arsenal
	var reach := FOCUS_REACH
	_task["in_reach"] = d < reach and _clear_shot(p, h)
	if _task["in_reach"]:
		_look = p
		_aiming_at_target = true
		_new_aim_target(h)
		var off := _forward().angle_to(p - eye)
		var tol := atan2(0.9, d + 1.0) * float(skill["fire_tolerance"])
		if ars.iced or (ars.current != "sprayer" and ars.ice > Arsenal.THAW_AT):
			# The sprayer's thawing: a gun meanwhile, if it thinks of it.
			if float(skill["weapon_sense"]) > 0.5:
				_select("rivet_gun" if "rivet_gun" in ars.owned else ars.owned[0])
				if ars.current != "sprayer" and off < tol and ars.swapping <= 0.0:
					_fire_tap = not bool(ars.stat(ars.current).get("auto", false))
					_fire = not _fire_tap
			return
		_select("sprayer")
		if ars.current == "sprayer" and off < tol:
			_fire = true
			_focus = true
		# Step in closer than the spray's edge.
		if d > reach - 1.2:
			_go(_stand_near(h.global_position, _heart_stand(h)), "heart", 3.0)
			_walk_path = true
		return
	_go(_stand_near(h.global_position, _heart_stand(h)), "heart", 3.0)
	_walk_path = true


## How far from a Heart's middle to stand: clear of its nest.
func _heart_stand(h: Heart) -> float:
	return 4.4 if h.big else 3.0


## A free spot about `dist` from a point with a clear view of it, nearest
## the Tech.
func _stand_near(p: Vector3, dist: float) -> Vector3:
	var key := "stand:%d:%d:%d" % [roundi(p.x), roundi(p.z), roundi(dist * 10)]
	if _decided.has(key):
		return _decided[key]
	var best := Vector3.INF
	var best_d := INF
	var here := player.global_position
	var space := player.get_world_3d().direct_space_state
	for k in 24:
		var a := TAU * k / 24.0
		for r: float in [dist, dist - 0.6, dist + 0.6]:
			var s := p + Vector3(cos(a), 0, sin(a)) * r
			var i := grid.index_at(s)
			if i < 0 or grid.free[i] == 0:
				continue
			var q := PhysicsRayQueryParameters3D.create(s + Vector3(0, 1.6, 0), p + Vector3(0, 1.0, 0), Kit.LAYER_SOLID)
			var h := space.intersect_ray(q)
			if not h.is_empty() and (h.position as Vector3).distance_to(p + Vector3(0, 1.0, 0)) > 1.6:
				continue
			var d := s.distance_to(here)
			if d < best_d:
				best_d = d
				best = s
	if best == Vector3.INF:
		var i := grid.nearest_free(p, 4.0)
		best = grid.world_of(i) if i >= 0 else p
	_decided[key] = best
	return best


func _work_clear() -> void:
	var t: Vector2i = _task["tile"]
	if level.bloom.level_at(t) < 0.95:
		_done()
		return
	_set_mode("clear")
	var ars := player.arsenal
	var eye := _eye()
	# A spot on the tile's floor in reach of the spray.
	var c := DeckLevel.center(t)
	var flat := Vector3(eye.x, 0, eye.z)
	var to := c - flat
	var aim := c
	if to.length() > 1.6:
		aim = flat + to.normalized() * minf(to.length(), 2.4)
		if DeckLevel.cell_at(aim) != t:
			aim = c - to.normalized() * 1.7
	aim.y = 0.05
	var in_reach := eye.distance_to(aim) < SPRAYER_REACH and DeckLevel.cell_at(aim) == t
	if in_reach:
		var q := PhysicsRayQueryParameters3D.create(eye, aim, Kit.SHOT_MASK)
		q.exclude = [player.get_rid()]
		var h := player.get_world_3d().direct_space_state.intersect_ray(q)
		in_reach = h.is_empty() or DeckLevel.cell_at(h.position) == t
	_task["in_reach"] = in_reach
	if in_reach:
		_look = aim
		_select("sprayer")
		if ars.current == "sprayer" and not ars.iced and _forward().angle_to(aim - eye) < 0.25:
			_fire = true
		return
	if time - float(_task["since"]) > 40.0:
		_done(str(t))
		return
	var stand := _stand_on(t)
	if stand == Vector3.INF:
		_done(str(t))
		return
	_go(stand, "clear:%s" % t, 0.6)
	_walk_path = true


## A neighbouring tile with thinner growth that opens onto this one, to
## freeze it from without standing in it, or (9999, 9999).
func _edge_of(t: Vector2i) -> Vector2i:
	var g0 := level.bloom.level_at(t)
	var best := Vector2i(9999, 9999)
	var best_g := INF
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb := t + n
		if not level.tiles.has(nb):
			continue
		var g := level.bloom.level_at(nb)
		if g >= 3.0 or g >= g0 or g >= best_g:
			continue
		if _edge_stand(t, nb) == Vector3.INF:
			continue
		best = nb
		best_g = g
	return best


## A spot in tile `nb` a little back from its edge with `t`, with a clear
## walk across into `t`, or Vector3.INF.
func _edge_stand(t: Vector2i, nb: Vector2i) -> Vector3:
	var key := "edge:%s:%s" % [t, nb]
	if _decided.has(key):
		return _decided[key]
	var n := Vector3(nb.x - t.x, 0, nb.y - t.y)
	var edge := (DeckLevel.center(t) + DeckLevel.center(nb)) * 0.5
	var out := Vector3.INF
	for side: float in [0.0, -1.0, 1.0]:
		var p := edge + n * 1.3 + Vector3(n.z, 0, n.x) * side
		if grid.free_at(p) and grid.clear_line(p, edge - n * 1.2):
			out = p
			break
	_decided[key] = out
	return out


## Where to stand to freeze a tile: beside it on thinner growth if it's
## careful, else in it.
func _stand_on(t: Vector2i) -> Vector3:
	var key := "clearstand:%s" % t
	if _decided.has(key):
		return _decided[key]
	if _roll("careful:clear", float(skill["careful"])):
		var nb := _edge_of(t)
		if nb != Vector2i(9999, 9999):
			_decided[key] = _edge_stand(t, nb)
			return _decided[key]
	var c := DeckLevel.center(t)
	var i := grid.nearest_free(c, 1.9)
	var p := grid.world_of(i) if i >= 0 else Vector3.INF
	if p != Vector3.INF and DeckLevel.cell_at(p) != t:
		# Its middle is taken up: any free cell in the tile.
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var s := c + Vector3(dx, 0, dy) * NavGrid.CELL
				if grid.free_at(s):
					p = s
	_decided[key] = p
	return p


func _work_leave() -> void:
	_set_mode("leave")
	var lift := scene.lift
	var console := lift.console
	var pad := DeckLevel.center(level.lift_cell)
	var flat := Vector3(player.global_position.x, 0, player.global_position.z)
	if flat.distance_to(pad) > 1.2:
		_go(pad, "lift", 0.8)
		_walk_path = true
		return
	# Survivors on their way: wait for them a while.
	var waiting := false
	for s in get_tree().get_nodes_in_group("survivors"):
		var sv := s as Survivor
		if sv.is_found and not sv.at_lift and sv.global_position.distance_to(pad) > 7.0:
			waiting = true
	var started := float(_task.get("at_lift", -1.0))
	if started < 0.0:
		_task["at_lift"] = time
		started = time
	if waiting and time - started < float(skill["wait_survivors"]):
		_look = player.global_position + (player.global_position - pad).normalized() * 5.0 + Vector3(0, 1.4, 0)
		return
	var look := console.global_position + Vector3(0, 1.0, 0)
	_look = look
	_task["busy"] = true
	if _looking_at(console) and _use_cool <= 0.0:
		_use_cool = 0.8
		var powered := lift.powered
		_press_event("interact")
		acted.emit("lift", {"powered": powered})
		if powered:
			leaving = true
	elif _use_cool <= 0.0 and time - started > 4.0:
		# Not lined up: shuffle a little.
		_move = (Vector3(console.global_position.x, 0, console.global_position.z) - flat).normalized() * 0.5


func _looking_at(body: Node) -> bool:
	var pic := player.player_interaction_component
	if pic == null or pic.interactable == null or not is_instance_valid(pic.interactable):
		return false
	return pic.interactable == body or body.is_ancestor_of(pic.interactable)


## Walks up to a thing, looks at it and uses it. Returns "walking",
## "aiming" or "used".
func _use(body: Node3D, look: Vector3, reach := USE_REACH) -> String:
	var flat := Vector3(player.global_position.x, 0, player.global_position.z)
	var spot := Vector3(look.x, 0, look.z)
	var key := "use:%d" % body.get_instance_id()
	if not _decided.has(key):
		var i := grid.nearest_free(spot + (flat - spot).normalized() * minf(0.8, reach * 0.6), 2.5)
		_decided[key] = grid.world_of(i) if i >= 0 else spot
	var stand: Vector3 = _decided[key]
	if flat.distance_to(spot) > reach + 0.15 and flat.distance_to(stand) > 0.35:
		_go(stand, key, 0.3)
		_walk_path = true
		return "walking"
	_look = look
	_task["busy"] = true
	if _looking_at(body) and _use_cool <= 0.0:
		_use_cool = 0.6
		_press_event("interact")
		return "used"
	if time - float(_task.get("aim_since", time)) > 3.0:
		# Can't line it up from here: step closer.
		_move = (spot - flat).normalized() * 0.6
	if not _task.has("aim_since"):
		_task["aim_since"] = time
	return "aiming"


func _work_pickup() -> void:
	var p := _task["node"] as Pickup
	if not is_instance_valid(p) or p.taken or p.is_queued_for_deletion():
		acted.emit("picked", {"item": _task.get("item", "")})
		_done()
		return
	_task["item"] = p.item
	_set_mode("pickup")
	if time - float(_task["since"]) > 25.0 or int(_task.get("tries", 0)) > 4:
		_done(p.get_instance_id())
		return
	if _use(p, p.global_position + Vector3(0, 0.25, 0), 1.0) == "used":
		_task["tries"] = int(_task.get("tries", 0)) + 1


func _work_log() -> void:
	var l := _task["node"] as LogTerminal
	if not is_instance_valid(l):
		_done()
		return
	_set_mode("read")
	if _task.has("read_at"):
		_look = l.global_position + Vector3(0, 0.5, 0)
		if time - float(_task["read_at"]) > float(_task["read_for"]):
			_done(l.get_instance_id())
		return
	if time - float(_task["since"]) > 25.0:
		_done(l.get_instance_id())
		return
	var h := 0.8 if l.style == "terminal" else (0.3 if l.style == "screen" else 0.1)
	if _use(l, l.global_position + Vector3(0, h, 0)) == "used":
		_task["read_at"] = time
		_task["read_for"] = rng.randf_range(4.0, 10.0)
		acted.emit("read", {"log": l.log_id})


func _work_survivor() -> void:
	var s := _task["node"] as Survivor
	if not is_instance_valid(s) or s.is_found:
		_done(s.get_instance_id() if is_instance_valid(s) else null)
		return
	_set_mode("survivor")
	if time - float(_task["since"]) > 40.0:
		_done(s.get_instance_id())
		return
	if _use(s, s.global_position + Vector3(0, 1.0, 0)) == "used":
		acted.emit("talk", {"survivor": s.survivor_id})


func _work_vent() -> void:
	var v := _task["node"] as VentPanel
	if not is_instance_valid(v) or v.used:
		_done()
		return
	_set_mode("vent")
	if time - float(_task["since"]) > 60.0:
		_done("vent:" + v.room_id)
		_decided["vent:" + v.room_id] = false
		return
	if _use(v, v.global_position + Vector3(0, 1.35, 0)) == "used":
		acted.emit("vent_panel", {"room": v.room_id})


func _work_walk() -> void:
	var p: Vector3 = _task["point"]
	_set_mode(String(_task["kind"]))
	var flat := Vector3(player.global_position.x, 0, player.global_position.z)
	if _task.get("regroup", false) and p != Vector3.INF and flat.distance_to(p) < 1.5:
		# Holding here while the growth dies back.
		_set_mode("regroup")
		return
	if p == Vector3.INF or flat.distance_to(p) < 1.0 or time - float(_task["since"]) > 45.0:
		if p != Vector3.INF and flat.distance_to(p) >= 1.0:
			_skip["room:" + level.room_at(p)] = true
		_done()
		return
	_go(p, _task["key"], 1.0)
	_walk_path = true


func _work_throw() -> void:
	var what: String = _task["what"]
	var ars := player.arsenal
	if player.items.get(what, 0) <= 0 or time - float(_task["since"]) > 5.0:
		_done()
		return
	_set_mode("throw")
	var at: Vector3 = _task["at"]
	var eye := _eye()
	var flat := Vector3(at.x - eye.x, 0, at.z - eye.z)
	var d := flat.length()
	# A rough arc: pitch up more the further it goes.
	var pitch := 0.5 * asin(clampf(d * 9.8 / (Arsenal.THROW_SPEED * Arsenal.THROW_SPEED), 0.0, 1.0)) - 0.12
	if what == "mine":
		pitch = 0.1
	_look = eye + flat.normalized() * 4.0 + Vector3(0, tan(pitch) * 4.0, 0)
	if _hold_throw_until > time - 0.15:
		return
	if ars.throwable != what:
		# Hold the key to pick the next one.
		if int(_task["cycles"]) < 3:
			_hold_throw_until = time + Arsenal.HOLD_TO_PICK + 0.12
			_task["cycles"] = int(_task["cycles"]) + 1
		else:
			_done()
		return
	if _forward().angle_to(_look - eye) < 0.12:
		_tap("throw")
		acted.emit("threw", {"what": what, "at": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]})
		_done()

#endregion

#region Walking

## Plans (or keeps) a path to `to` for `key`; replans now and then, or when
## the goal has moved more than `slack` metres.
func _go(to: Vector3, key: String, slack: float) -> void:
	_path_age += THINK
	var moved := _path_to == Vector3.INF or Vector3(to.x, 0, to.z).distance_to(Vector3(_path_to.x, 0, _path_to.z)) > slack
	if key != _path_key or moved or _path.is_empty() or _path_age > 6.0:
		_plan_path(to, key)


func _drop_path() -> void:
	_path.clear()
	_doors.clear()
	_pi = 0
	_path_key = ""
	_path_to = Vector3.INF
	_door = null
	_door_stage = ""


func _plan_path(to: Vector3, key: String) -> void:
	_path_key = key
	_path_to = to
	_path_age = 0.0
	var cost := _avoid.duplicate()
	# Feeders overhead: give them room.
	for c in get_tree().get_nodes_in_group("creatures"):
		var f := c as Feeder
		if f == null or f.dead:
			continue
		var fp := f.global_position
		var extra := 3.0 if float(skill["weapon_sense"]) > 0.5 else 0.5
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var i := grid.index_at(Vector3(fp.x + dx * NavGrid.CELL, 0, fp.z + dy * NavGrid.CELL))
				if i >= 0 and Vector2(dx, dy).length() * NavGrid.CELL < 2.6:
					cost[i] = float(cost.get(i, 0.0)) + extra
	var tile_cost := {}
	var b := level.bloom
	var noise := float(skill["route_noise"])
	for i in b.cells.size():
		var c: Vector2i = b.cells[i]
		var t := 0.0
		if b.growth[i] >= 3.0:
			t += 0.6
		if noise > 0.0:
			t += rng.randf() * noise * 2.0
		if t > 0.0:
			tile_cost[c] = t
	var blocked := _blocked_doors.duplicate()
	for k in level.doors:
		var d: Bulkhead = level.doors[k]
		if d.airless or (d.locked != "" and not player.has_key(d.locked)):
			blocked[k] = true
		elif d.sealed:
			for i in grid.door_cells.get(k, PackedInt32Array()):
				cost[i] = float(cost.get(i, 0.0)) + 6.0
	var r := grid.find_path(player.global_position, to, cost, tile_cost, blocked)
	if r.is_empty():
		_path.clear()
		_doors.clear()
		_pi = 0
		var here := player.global_position
		acted.emit("no_path", {"to": [snappedf(to.x, 0.1), snappedf(to.z, 0.1)], "for": key,
			"start_free": grid.free_at(here), "start_near": grid.nearest_free(here, 2.0) >= 0,
			"goal_near": grid.nearest_free(to, 3.0) >= 0, "blocked": blocked.keys()})
		if not _task.is_empty() and _task.get("kind", "") != "heart":
			var node: Variant = _task.get("node")
			if _task.has("tile"):
				_done(str(_task["tile"]))
			else:
				_done(node.get_instance_id() if is_instance_valid(node) else ("room:" + level.room_at(to)))
		return
	_path.assign(r["points"])
	_doors.assign(r["doors"])
	_pi = 0
	_door = null
	_door_stage = ""


## Steers along the path, opening doors on the way. Returns the way to go.
func _follow(delta: float) -> Vector3:
	if _pi >= _path.size():
		return Vector3.ZERO
	var pos := player.global_position
	var flat := Vector3(pos.x, 0, pos.z)
	var key: String = _doors[_pi]
	if key != "" and level.doors.has(key):
		var d: Bulkhead = level.doors[key]
		var dmid := Vector3(d.global_position.x, 0, d.global_position.z)
		if (not d.passable() or (_door == d and _door_stage != "")) and flat.distance_to(dmid) < 3.4:
			var dir := _at_door(d, flat, delta)
			if dir != Vector3.INF:
				return dir
	var wp := _path[_pi]
	var to := wp - flat
	var near := 0.35 if _pi == _path.size() - 1 else 0.6
	if to.length() < near:
		_pi += 1
		_door = null
		_door_stage = ""
		if _pi >= _path.size():
			return Vector3.ZERO
		wp = _path[_pi]
		to = wp - flat
	# Cut the corner when the next point is in a straight line already.
	if _pi + 1 < _path.size() and _doors[_pi] == "" and _doors[_pi + 1] == "" and to.length() < 1.6 and grid.clear_line(flat, _path[_pi + 1]):
		_pi += 1
		to = _path[_pi] - flat
	return to.normalized()


## At a shut door: walks up to it, uses the leaf; a sealed one is unsealed
## at its panel first. Returns the way to go, ZERO to stand, or INF when the
## door's open and the path goes on.
func _at_door(d: Bulkhead, flat: Vector3, delta: float) -> Vector3:
	if _door != d:
		_door = d
		_door_stage = "open"
		_door_t = 0.0
		_door_tries = 0
	_set_mode("door")
	_door_t += delta
	var n := DeckLevel.center(d.b) - DeckLevel.center(d.a)
	n = Vector3(n.x, 0, n.z).normalized()
	var mid := Vector3(d.global_position.x, 0, d.global_position.z)
	var side := signf((flat - mid).dot(n))
	if side == 0.0:
		side = -1.0
	if d.airless or (d.locked != "" and not player.has_key(d.locked)):
		_blocked_doors[d.key] = true
		acted.emit("door_blocked", {"door": d.key, "why": "airless" if d.airless else "locked:" + d.locked})
		_plan_path(_path_to, _path_key)
		return Vector3.ZERO
	if d.passable() and not d.sealed:
		_door = null
		_door_stage = ""
		return Vector3.INF
	if d.sealed and _door_stage == "open":
		_door_stage = "unseal"
		_door_t = 0.0
	var along := Vector3(n.z, 0, -n.x)
	if _door_stage == "unseal":
		if not d.sealed:
			_door_stage = "open"
			_door_t = 0.0
			return Vector3.ZERO
		var panel := d.global_transform * Vector3(2.3, 1.35, 0)
		var pflat := Vector3(panel.x, 0, panel.z)
		var stand := mid + (pflat - mid).normalized() * 1.4 + n * side * 0.8
		var si := grid.nearest_free(stand, 1.0)
		if si >= 0:
			stand = grid.world_of(si)
		if flat.distance_to(stand) > 0.3 and _door_t < 6.0:
			_look = panel
			return (stand - flat).normalized()
		_look = panel
		if _door_t > 12.0:
			_give_up_door(d, "panel")
			return Vector3.ZERO
		var pic := player.player_interaction_component
		if pic.interactable != null and is_instance_valid(pic.interactable) and pic.interactable.name == "Panel" and d.is_ancestor_of(pic.interactable) and _use_cool <= 0.0 and d._unsealing <= 0.0:
			_use_cool = 1.6
			_press_event("interact")
			acted.emit("unseal", {"door": d.key})
		return Vector3.ZERO
	# Stand square on, about a metre back, and use the leaf.
	var stand2 := mid + n * side * 1.1
	var lateral := (flat - mid).dot(along)
	if absf((flat - mid).dot(n)) > 1.5 or absf(lateral) > 1.4:
		_look = mid + Vector3(0, 1.6, 0)
		return (stand2 - flat).normalized()
	_look = mid + Vector3(0, 1.5, 0) + n * side * 0.1
	if _door_t > 8.0:
		_door_tries += 1
		_door_t = 0.0
		if _door_tries >= 3:
			_give_up_door(d, "won't open")
			return Vector3.ZERO
	var pic2 := player.player_interaction_component
	var on_leaf: bool = pic2.interactable != null and is_instance_valid(pic2.interactable) and String(pic2.interactable.name).begins_with("Leaf") and d.is_ancestor_of(pic2.interactable)
	if on_leaf and _use_cool <= 0.0:
		if not d.is_open:
			_use_cool = 1.2
			_press_event("interact")
			acted.emit("door_open", {"door": d.key})
	return Vector3.ZERO


func _give_up_door(d: Bulkhead, why: String) -> void:
	_blocked_doors[d.key] = true
	acted.emit("door_blocked", {"door": d.key, "why": why})
	_door = null
	_door_stage = ""
	_plan_path(_path_to, _path_key)


func _drive(delta: float) -> void:
	var dir := Vector3.ZERO
	if _unstick_until > time:
		dir = _unstick_dir
	elif _walk_path:
		dir = _follow(delta)
	if dir == Vector3.ZERO and _move != Vector3.ZERO:
		dir = _move
	_wanted_move = dir != Vector3.ZERO
	_set_move(dir)
	var sprint := _walk_path and _known.is_empty() and _path_key != "" and _pi < _path.size() and _roll("sprint:%s" % _path_key, float(skill["sprint"]))
	_hold("sprint", sprint and dir != Vector3.ZERO)
	_hold("throw", _hold_throw_until > time)


## Presses the movement keys for a way to go in the world, as the body faces.
func _set_move(dir: Vector3) -> void:
	if dir.length() < 0.01:
		for a in ["forward", "back", "left", "right"]:
			_hold(a, false)
		return
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var yaw := player.body.global_rotation.y
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var x := dir.dot(right)
	var y := -dir.dot(fwd)
	_hold("right", x > 0.05, maxf(x, 0.0))
	_hold("left", x < -0.05, maxf(-x, 0.0))
	_hold("back", y > 0.05, maxf(y, 0.0))
	_hold("forward", y < -0.05, maxf(-y, 0.0))


## Watches for not getting anywhere while trying to: steps aside and jumps,
## then plans round the spot; after two minutes of it, gives up.
func _check_stuck() -> void:
	var pos := player.global_position
	var moved := pos.distance_to(_anchor) > 1.0
	if moved or not _wanted_move:
		_anchor = pos
		_anchor_t = time
		_still_since = time
	if _wanted_move and time - _anchor_t > 2.5 and _unstick_until < time:
		_unsticks += 1
		_anchor_t = time
		var a := rng.randf() * TAU
		_unstick_dir = Vector3(cos(a), 0, sin(a))
		_unstick_until = time + 0.7
		_tap("jump")
		var i := grid.index_at(pos + _move_dir_hint() * 0.8)
		if i >= 0:
			_avoid[i] = float(_avoid.get(i, 0.0)) + 4.0
		acted.emit("unstick", {"at": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)], "mode": mode})
		if _unsticks % 3 == 0:
			_drop_path()
	if _wanted_move and time - _still_since > 120.0:
		stuck_out = true


func _move_dir_hint() -> Vector3:
	if _pi < _path.size():
		var to := _path[_pi] - Vector3(player.global_position.x, 0, player.global_position.z)
		return to.normalized()
	return Vector3.ZERO

#endregion

#region Aim and triggers

## Turns the view toward what it wants to look at, no faster than its
## skill's turn speed, with its aim's wobble.
func _steer_view(delta: float) -> void:
	var eye := _eye()
	var want := Vector3.ZERO
	if _look != Vector3.INF:
		want = _look - eye
	elif _wanted_move:
		var m := _current_move()
		want = Vector3(m.x, -0.12, m.z)
	if want.length() < 0.01:
		return
	want = want.normalized()
	# The wobble drifts slowly round the true aim; a flick decays fast.
	var sd := float(skill["aim_error"])
	var tau := 0.6
	_err += -_err / tau * delta + Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)) * sd * sqrt(2.0 / tau * delta)
	_flick = _flick.move_toward(Vector2.ZERO, delta * maxf(4.0, _flick.length() * 4.0))
	var wobble := (_err + _flick) if _aiming_at_target else Vector2.ZERO
	var want_yaw := atan2(-want.x, -want.z) + deg_to_rad(wobble.x)
	var want_pitch := atan2(want.y, Vector2(want.x, want.z).length()) + deg_to_rad(wobble.y * 0.6)
	var yaw := player.body.global_rotation.y
	var pitch := player.head.rotation.x
	var max_turn := deg_to_rad(float(skill["turn_speed"])) * delta
	var dy := wrapf(want_yaw - yaw, -PI, PI)
	var dp := want_pitch - pitch
	var ease := clampf(delta * 14.0, 0.0, 1.0)
	player.body.rotation.y += clampf(dy * ease, -max_turn, max_turn)
	player.head.rotation.x = clampf(pitch + clampf(dp * ease, -max_turn, max_turn), deg_to_rad(-85), deg_to_rad(85))


func _current_move() -> Vector3:
	if _unstick_until > time:
		return _unstick_dir
	if _walk_path and _pi < _path.size():
		var to := _path[_pi] - Vector3(player.global_position.x, 0, player.global_position.z)
		if to.length() > 0.05:
			return to.normalized()
	return _move


func _triggers() -> void:
	var ars := player.arsenal
	if _fire_tap:
		_hold("action_primary", false)
		if time >= _next_tap:
			_tap("action_primary")
			var rate := float(ars.stat(ars.current).get("rate", 0.3))
			_next_tap = time + rate + rng.randf_range(0.03, 0.12) * (1.5 - float(skill["weapon_sense"]))
	else:
		_hold("action_primary", _fire)
	_hold("action_secondary", _focus)

#endregion


## A yes or no for something it decides once (by key) with chance `p`.
func _roll(key: String, p: float) -> bool:
	if not _decided.has(key):
		_decided[key] = rng.randf() < p
	return _decided[key]
