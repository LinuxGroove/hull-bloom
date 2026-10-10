extends Node
## What happened on one autopilot visit to a deck, for the run's JSON:
## deaths and what did them, damage and infection by source, kills, shots
## and hits by weapon, what the Tech carried and the Bloom's spread every ten
## seconds, roots cut, survivors, logs, doors, power and throws, every
## stretch of more than twenty seconds that got no nearer the deck's goal,
## and Godot's own monitors. It only listens and reads; it changes nothing.

## Seconds between samples of what the Tech carries, the Bloom and the monitors.
const SAMPLE := 10.0
## A stretch this long with no progress toward the goal is kept.
const STRETCH := 20.0

var scene: DeckScene
var pilot: Node
var player: Tech
var time := 0.0
var data := {}

var _sample_t := 0.0
var _tick_t := 0.0
var _last_progress := 0.0
var _best := INF
var _goal_key := ""
var _roots := 0
var _growth_best := INF
var _trail: Array = []
var _trail_t := 0.0
var _modes := {}
var _doors := {}
var _power: Array[String] = []
var _last_source := ""
var _hurt_frame := -1
var _last_inf := 0.0
var _field := PackedFloat32Array()
var _held := false
var _trace_t := 0.0
var _last_hit_by := {}


func setup(p_scene: DeckScene, p_pilot: Node) -> void:
	scene = p_scene
	pilot = p_pilot
	player = scene.player
	name = "Telemetry"
	process_physics_priority = 100
	data = {
		"deaths": [], "damage": {}, "hits_taken": {}, "infection_from": {}, "kills": {}, "kill_times": [],
		"shots": {}, "hits": {}, "cutter_seconds": 0.0, "samples": [], "roots": [], "survivors_found": [],
		"logs_read": [], "doors": {"opened": 0, "closed": 0, "sealed": 0, "unsealed": 0, "events": []},
		"power": [], "throws": {}, "no_progress": [], "monitors": [], "actions": {}, "unstuck": [],
		"lost": [], "doors_blocked": [], "no_path": [],
		"trace_columns": ["t", "x", "z", "room", "doing", "health", "infection", "weapon", "target", "target_m", "known", "task"],
		"trace": [], "hit_log": [], "rapid_hits": {},
	}
	player.hurt.connect(_on_hurt)
	player.died.connect(_on_died)
	player.arsenal.fired.connect(_on_fired)
	player.arsenal.hit_marker.connect(_on_hit_marker)
	scene.director.creature_died.connect(_on_creature_died)
	scene.director.heart_killed.connect(_on_heart_killed)
	scene.power.changed.connect(_on_power)
	for key in scene.level.doors:
		var d: Bulkhead = scene.level.doors[key]
		_doors[key] = [d.is_open, d.sealed]
		d.changed.connect(_on_door)
	for l in scene.level.find_children("", "LogTerminal", true, false):
		(l as LogTerminal).read.connect(_on_log)
	for s in get_tree().get_nodes_in_group("survivors"):
		(s as Survivor).found.connect(_on_survivor)
	pilot.acted.connect(_on_acted)
	_last_inf = player.infection
	_sample()


func _physics_process(delta: float) -> void:
	if scene == null or not is_instance_valid(scene) or scene.run.over:
		return
	time += delta
	var ars := player.arsenal
	if ars.current == "cutter" and ars.firing and not ars.overheated:
		data["cutter_seconds"] = float(data["cutter_seconds"]) + delta
	_infection(delta)
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = 1.0
		_progress()
	_sample_t -= delta
	if _sample_t <= 0.0:
		_sample()


func _sample() -> void:
	_sample_t = SAMPLE
	var ars := player.arsenal
	var ammo := {}
	for w in ars.owned:
		if w != "cutter":
			ammo[w] = int(ars.mag.get(w, 0)) + (int(ars.reserve.get(w, 0)) if int(ars.stat(w).get("carry", 0)) >= 0 else 0)
	var b := scene.level.bloom
	var p := player.global_position
	data["samples"].append({
		"t": _r(time), "health": roundi(player.health), "infection": roundi(player.infection), "ammo": ammo,
		"salvage": scene.run.salvage, "medkit": player.items["medkit"], "stim": player.items["stim"],
		"flare": player.items["flare"], "grenade": player.items["grenade"], "mine": player.items["mine"],
		"coverage": snappedf(b.coverage(), 0.001), "max_growth": snappedf(b.max_level(), 0.01),
		"roots_alive": b.roots_alive(), "alive": scene.director.alive(), "pos": _xz(p),
		"room": scene.level.room_at(p), "doing": pilot.mode, "cells_free": scene.power.free_cells(),
	})
	data["monitors"].append({
		"t": _r(time),
		"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"creatures": get_tree().get_nodes_in_group("creatures").size(),
	})


#region Progress toward the goal

## Once a second: did the Tech get any nearer the deck's goal? Nearer the
## Heart (walking distance), a root cut, the growth burnt back, the deck held.
func _progress() -> void:
	var run := scene.run
	var moved := false
	if run.roots_cut > _roots:
		_roots = run.roots_cut
		moved = true
	if run.held and not _held:
		_held = true
		moved = true
	var goal: String = pilot.goal_name
	if goal == "burn":
		var total := 0.0
		for g in scene.level.bloom.growth:
			if g >= 1.0:
				total += g
		if total < _growth_best - 0.5:
			_growth_best = total
			moved = true
		_goal_key = "burn"
	elif pilot.goal_point != Vector3.INF:
		var key := "%s:%s" % [goal, DeckLevel.cell_at(pilot.goal_point)]
		if key != _goal_key:
			_goal_key = key
			_field = _distance_field(pilot.goal_point)
			_best = INF
		var i: int = pilot.grid.index_at(player.global_position)
		var d := _field[i] if i >= 0 and i < _field.size() else INF
		if d < _best - 1.0:
			_best = d
			moved = true
	_modes[pilot.mode] = int(_modes.get(pilot.mode, 0)) + 1
	_trail_t -= 1.0
	if _trail_t <= 0.0:
		_trail_t = 5.0
		_trail.append(_xz(player.global_position) + [scene.level.room_at(player.global_position)])
	_trace_t -= 1.0
	if _trace_t <= 0.0:
		_trace_t = 2.0
		data["trace"].append([_r(time)] + _xz(player.global_position) + [scene.level.room_at(player.global_position),
			pilot.mode, roundi(player.health), roundi(player.infection), player.arsenal.current] + pilot.target_info())
	if moved:
		_close_stretch(false)
		_last_progress = time
		_trail = [_xz(player.global_position) + [scene.level.room_at(player.global_position)]]
		_modes = {}


func _close_stretch(still_open: bool) -> void:
	if time - _last_progress <= STRETCH:
		return
	var rooms := []
	for t in _trail:
		if not t[2] in rooms:
			rooms.append(t[2])
	var trail := _trail.slice(0, 24)
	data["no_progress"].append({
		"from": _r(_last_progress), "to": _r(time), "seconds": _r(time - _last_progress), "goal": _goal_key,
		"start": trail[0] if not trail.is_empty() else [], "end": _xz(player.global_position) + [scene.level.room_at(player.global_position)],
		"rooms": rooms, "doing": _modes.duplicate(), "trail": trail, "open": still_open,
	})


## Walking distance in metres from every free cell to the goal (the grid,
## doors counted open).
func _distance_field(goal: Vector3) -> PackedFloat32Array:
	var grid = pilot.grid
	var out := PackedFloat32Array()
	out.resize(grid.free.size())
	out.fill(INF)
	var start: int = grid.nearest_free(goal, 4.0)
	if start < 0:
		return out
	out[start] = 0.0
	var queue := PackedInt32Array([start])
	var head := 0
	var w: int = grid.w
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var y := i / w
		for s in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not grid.is_free(x + s.x, y + s.y):
				continue
			var j: int = (y + s.y) * w + x + s.x
			if out[j] != INF:
				continue
			out[j] = out[i] + grid.CELL
			queue.append(j)
	return out

#endregion

#region What happened

func _on_hurt(amount: float, _from_dir: Vector3) -> void:
	var src := source_of(player.last_hit, player)
	_last_source = src
	_hurt_frame = Engine.get_physics_frames()
	data["damage"][src] = snappedf(float(data["damage"].get(src, 0.0)) + amount, 0.1)
	data["hits_taken"][src] = int(data["hits_taken"].get(src, 0)) + 1
	if player.last_hit != null and data["hit_log"].size() < 400:
		data["hit_log"].append([snappedf(time, 0.01), src, snappedf(amount, 0.1)])
	# The same creature landing blows closer together than any attack's
	# own time allows.
	var h := player.last_hit
	if h != null and is_instance_valid(h.from) and h.from is Creature:
		var id := h.from.get_instance_id()
		if time - float(_last_hit_by.get(id, -10.0)) < 0.5:
			data["rapid_hits"][src] = int(data["rapid_hits"].get(src, 0)) + 1
		_last_hit_by[id] = time


## What hurt the Tech: "skitter claw", "heart spit", "feeder drain", "own blast".
static func source_of(hit: Hit, tech: Tech) -> String:
	if hit == null:
		return "feeder drain" if tech.grabbed_by != null else "drain"
	var by := "unknown"
	if hit.from == null or not is_instance_valid(hit.from):
		by = "something gone"
	elif hit.from == tech:
		by = "own"
	elif hit.from is Creature:
		by = (hit.from as Creature).kind
	elif hit.from is Heart:
		by = "heart"
	else:
		by = String(hit.from.name).to_lower()
	return "%s %s" % [by, String(Hit.Kind.keys()[hit.kind]).to_lower()]


## Infection by where it came from: blows, a Feeder, standing in growth,
## spores.
func _infection(_delta: float) -> void:
	var gain := player.infection - _last_inf
	_last_inf = player.infection
	if gain <= 0.0:
		return
	var src := "spores or other"
	if player.grabbed_by != null:
		src = "feeder drain"
	elif _hurt_frame == Engine.get_physics_frames() or Engine.get_physics_frames() - _hurt_frame <= 1:
		src = _last_source
	elif scene.level.bloom.level_at(DeckLevel.cell_at(player.global_position)) >= 3.0:
		src = "standing in growth"
	data["infection_from"][src] = snappedf(float(data["infection_from"].get(src, 0.0)) + gain, 0.01)


func _on_died() -> void:
	var p := player.global_position
	data["deaths"].append({"t": _r(time), "how": player.down_reason, "by": _last_source, "at": _xz(p),
		"room": scene.level.room_at(p), "medkits_left": player.items["medkit"], "stims_left": player.items["stim"],
		"infection": roundi(player.infection), "doing": pilot.mode})


func _on_fired(w: String) -> void:
	data["shots"][w] = int(data["shots"].get(w, 0)) + 1


func _on_hit_marker(_kill: bool) -> void:
	var w := player.arsenal.current
	data["hits"][w] = int(data["hits"].get(w, 0)) + 1


func _on_creature_died(c: Creature) -> void:
	data["kills"][c.kind] = int(data["kills"].get(c.kind, 0)) + 1
	data["kill_times"].append([_r(time), c.kind])


func _on_heart_killed(h: Heart) -> void:
	data["roots"].append({"t": _r(time), "cell": [h.cell.x, h.cell.y], "room": scene.level.tiles.get(h.cell, ""),
		"by": "vent" if pilot.mode == "vent" else player.arsenal.current})


func _on_door(d: Bulkhead) -> void:
	var was: Array = _doors.get(d.key, [false, false])
	var near := d.global_position.distance_to(player.global_position) < 4.0
	var what := ""
	if d.sealed and not was[1]:
		what = "sealed"
	elif not d.sealed and was[1]:
		what = "unsealed"
	elif d.is_open and not was[0]:
		what = "opened"
	elif not d.is_open and was[0]:
		what = "closed"
	_doors[d.key] = [d.is_open, d.sealed]
	if what == "":
		return
	data["doors"][what] = int(data["doors"][what]) + 1
	data["doors"]["events"].append({"t": _r(time), "door": d.key, "what": what, "by": "tech" if near else "other"})


func _on_log(l: LogTerminal) -> void:
	data["logs_read"].append({"t": _r(time), "log": l.log_id})


func _on_survivor(s: Survivor) -> void:
	data["survivors_found"].append({"t": _r(time), "survivor": s.survivor_id})


func _on_power() -> void:
	var now: Array[String] = scene.power.users.duplicate()
	for u in now:
		if not u in _power:
			data["power"].append({"t": _r(time), "on": u})
	for u in _power:
		if not u in now:
			data["power"].append({"t": _r(time), "off": u})
	_power = now


func _on_acted(kind: String, info: Dictionary) -> void:
	data["actions"][kind] = int(data["actions"].get(kind, 0)) + 1
	var at := _xz(player.global_position)
	match kind:
		"threw":
			data["throws"][info["what"]] = int(data["throws"].get(info["what"], 0)) + 1
		"unstick":
			if data["unstuck"].size() < 60:
				data["unstuck"].append({"t": _r(time), "at": info.get("at", at), "doing": info.get("mode", "")})
		"lost":
			data["lost"].append({"t": _r(time), "from": scene.level.room_at(player.global_position), "to": info.get("to", "")})
		"door_blocked":
			data["doors_blocked"].append({"t": _r(time), "door": info.get("door", ""), "why": info.get("why", "")})
		"no_path":
			if data["no_path"].size() < 40:
				var row := info.duplicate()
				row["t"] = _r(time)
				row["from"] = at
				data["no_path"].append(row)

#endregion


## Closes the record: an open stretch, the last sample, and the run's own
## numbers.
func finish() -> Dictionary:
	_close_stretch(true)
	_sample()
	var run := scene.run
	data["roots_cut"] = run.roots_cut
	data["roots_total"] = run.roots
	data["survivors_total"] = run.survivors_total
	data["survivors_saved"] = run.survivors_saved.size()
	data["salvage"] = run.salvage
	data["kills_total"] = run.kills
	data["burnt"] = snappedf(run.burnt, 0.1)
	data["cutter_seconds"] = _r(float(data["cutter_seconds"]))
	return data


static func _r(t: float) -> float:
	return snappedf(t, 0.1)


static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]
