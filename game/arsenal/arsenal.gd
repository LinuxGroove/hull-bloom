class_name Arsenal
extends Node3D
## What the tech carries in their hands: the plasma cutter and the guns, the
## rounds for them, and the flares, grenades and mines to throw. Lives on the
## camera; [Viewmodel] draws it.
##
## The cutter is the only thing that burns the Bloom back: its beam burns the
## tile it touches down a level at a time and builds heat. The guns kill what
## hatches.

signal changed
signal hit_marker(kill: bool)
signal fired(weapon: String)

## Every weapon, in slot order. Kinds: beam (the cutter), shot (one round
## a pull, or held for automatic), pellets, burst, rail (pierces).
const WEAPONS := {
	"cutter": {"name": "Plasma cutter", "slot": 1, "kind": "beam", "model": "cutter", "damage": 26.0, "focus_damage": 42.0,
		"range": 3.6, "focus_range": 5.5, "heat": 17.0, "focus_heat": 23.0, "cool": 30.0, "burn": 1.15, "focus_burn": 0.6},
	"sidearm": {"name": "Sidearm", "slot": 2, "kind": "shot", "model": "Gun_Pistol", "damage": 14.0, "rate": 0.3, "mag": 12,
		"carry": -1, "reload": 1.7, "spread": 0.014, "aim_spread": 0.004, "range": 60.0, "knock": 1.0, "noise": 24.0, "sound": "sidearm", "recoil": 0.6},
	"scattergun": {"name": "Scattergun", "slot": 3, "kind": "pellets", "model": "Gun_Shotgun", "damage": 9.0, "pellets": 8, "rate": 0.85, "mag": 6,
		"carry": 36, "reload": 2.1, "spread": 0.085, "aim_spread": 0.06, "range": 22.0, "knock": 3.0, "sever": 1.4, "noise": 32.0, "sound": "scattergun", "recoil": 1.6},
	"rifle": {"name": "Pulse rifle", "slot": 4, "kind": "shot", "model": "Gun_Rifle", "damage": 15.0, "rate": 0.11, "auto": true, "mag": 30,
		"carry": 180, "reload": 1.9, "spread": 0.022, "aim_spread": 0.007, "range": 60.0, "knock": 0.7, "noise": 28.0, "sound": "rifle", "recoil": 0.45},
	"smg": {"name": "Burst SMG", "slot": 5, "kind": "burst", "model": "Gun_SMG", "damage": 9.0, "burst": 4, "burst_gap": 0.06, "rate": 0.36, "mag": 32,
		"carry": 192, "reload": 1.5, "spread": 0.04, "aim_spread": 0.02, "range": 40.0, "knock": 0.5, "noise": 26.0, "sound": "smg", "recoil": 0.35},
	"rail": {"name": "Rail rifle", "slot": 6, "kind": "rail", "model": "Gun_Sniper", "damage": 120.0, "rate": 1.4, "mag": 4,
		"carry": 20, "reload": 2.4, "spread": 0.0, "aim_spread": 0.0, "range": 90.0, "knock": 4.0, "sever": 3.0, "noise": 30.0, "sound": "rail", "recoil": 2.0, "zoom": 38.0},
}
## What the red version from the workbench changes.
const RED := {
	"sidearm": {"damage": 20.0, "reload": 1.2},
	"scattergun": {"pellets": 10, "spread": 0.07},
	"rifle": {"damage": 19.0, "mag": 40},
	"smg": {"burst": 5, "mag": 40},
	"rail": {"damage": 170.0, "mag": 5},
}
const THROWABLES := ["flare", "grenade", "mine"]
const THROW_SPEED := 11.0
const HOLD_TO_PICK := 0.35
const OVERHEAT := 100.0
const COOL_AT := 35.0

var player: Tech
var owned: Array[String] = []
var current := "cutter"
## Rounds in each gun's magazine, and carried for it.
var mag := {}
var reserve := {}
var heat := 0.0
var overheated := false
var reloading := 0.0
var swapping := 0.0
var firing := false
var aiming := false
var throwable := "flare"
var view: Viewmodel

var _cool_t := 0.0
var _shot_t := 0.0
var _burst_left := 0
var _burst_t := 0.0
var _throw_held := 0.0
var _burn_t := 0.0
var _beam_hit := {}
var _beam_sound: AudioStreamPlayer


func _ready() -> void:
	view = Viewmodel.new()
	view.name = "Viewmodel"
	view.arsenal = self
	add_child(view)
	if owned.is_empty():
		setup(Progress.START_WEAPONS, {})


## Starts a deck with these guns and carried rounds.
func setup(weapons: Array, carried: Dictionary) -> void:
	owned.clear()
	for w in WEAPONS:
		if w in weapons:
			owned.append(w)
	if owned.is_empty():
		owned.append("cutter")
	for w in WEAPONS:
		var spec := stat(w)
		mag[w] = int(spec.get("mag", 0))
		reserve[w] = int(carried.get(w, int(spec.get("mag", 0)) * 2)) if int(spec.get("carry", 0)) > 0 else 0
	current = owned[0] if not "cutter" in owned else "cutter"
	heat = 0.0
	overheated = false
	if view:
		view.show_weapon(current)
	changed.emit()


## A weapon's numbers, with its red upgrade if bought.
func stat(w: String) -> Dictionary:
	var s: Dictionary = WEAPONS.get(w, {}).duplicate()
	if RED.has(w) and Progress.has_upgrade(w + "_red"):
		s.merge(RED[w], true)
		s["red"] = true
	if w == "cutter":
		if Progress.has_upgrade("cutter_cool"):
			s["heat"] = s["heat"] * 0.7
			s["focus_heat"] = s["focus_heat"] * 0.7
			s["cool"] = s["cool"] * 1.4
		if Progress.has_upgrade("cutter_focus"):
			s["focus_range"] = 7.0
			s["focus_damage"] = s["focus_damage"] * 1.3
	return s


func give(w: String) -> bool:
	if w in owned or not WEAPONS.has(w):
		return false
	owned.append(w)
	owned.sort_custom(func(a, b): return int(WEAPONS[a]["slot"]) < int(WEAPONS[b]["slot"]))
	reserve[w] = maxi(int(reserve.get(w, 0)), int(stat(w).get("mag", 0)))
	select(w)
	return true


func add_ammo(w: String, count: int) -> bool:
	if w == "" or w == "any":
		# Rounds for whatever gun you hold (or the first that has room).
		for x in [current] + owned:
			if int(stat(x).get("carry", 0)) > 0 and reserve.get(x, 0) < int(stat(x)["carry"]):
				w = x
				break
	var cap := int(stat(w).get("carry", 0))
	if cap <= 0 or not WEAPONS.has(w) or reserve.get(w, 0) >= cap:
		return false
	var per := int(stat(w).get("mag", 1))
	reserve[w] = mini(cap, int(reserve[w]) + per * maxi(1, count))
	changed.emit()
	return true


func take_reserve(w: String, want: int) -> int:
	var n := mini(want, int(reserve.get(w, 0)))
	reserve[w] = int(reserve.get(w, 0)) - n
	changed.emit()
	return n


func select(w: String) -> void:
	if not w in owned or w == current:
		return
	_stop_beam()
	current = w
	reloading = 0.0
	swapping = 0.35
	_burst_left = 0
	Sfx.ui(self, "swap", -10.0)
	view.show_weapon(w)
	changed.emit()


func cycle(step: int) -> void:
	var i := owned.find(current)
	select(owned[(i + step + owned.size()) % owned.size()])


func _busy() -> bool:
	return player == null or player.is_dead or player.is_movement_paused or player.is_showing_ui


func _process(delta: float) -> void:
	_tick(delta)


## One frame of the hands; tests call it directly.
func _tick(delta: float) -> void:
	if swapping > 0.0:
		swapping -= delta
	_shot_t -= delta
	var spec := stat(current)
	if current == "cutter":
		_cutter(delta, spec)
	else:
		_cool(delta, spec)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()
	if _busy():
		firing = false
		aiming = false
		_stop_beam()
		return
	aiming = Input.is_action_pressed("action_secondary")
	var pull := Input.is_action_pressed("action_primary")
	var tap := Input.is_action_just_pressed("action_primary")
	if current != "cutter" and swapping <= 0.0 and reloading <= 0.0:
		if _burst_left > 0:
			_burst_t -= delta
			if _burst_t <= 0.0:
				_burst_t = float(spec["burst_gap"])
				_burst_left -= 1
				_shoot(spec)
		elif (tap or (pull and spec.get("auto", false))) and _shot_t <= 0.0:
			if int(mag[current]) <= 0:
				if tap:
					Sfx.ui(self, "dry_fire", -6.0)
					reload()
			else:
				_shot_t = float(spec["rate"])
				if spec["kind"] == "burst":
					_burst_left = int(spec["burst"]) - 1
					_burst_t = float(spec["burst_gap"])
				_shoot(spec)
	firing = pull
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("swap"):
		cycle(1)
	elif Input.is_action_just_pressed("swap_back"):
		cycle(-1)
	for i in 6:
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			for w in owned:
				if int(WEAPONS[w]["slot"]) == i + 1:
					select(w)
	if Input.is_action_pressed("throw"):
		_throw_held += delta
		if _throw_held >= HOLD_TO_PICK and _throw_held - delta < HOLD_TO_PICK:
			next_throwable()
	elif _throw_held > 0.0:
		if _throw_held < HOLD_TO_PICK:
			throw()
		_throw_held = 0.0


#region Guns

func reload() -> void:
	var spec := stat(current)
	if current == "cutter" or reloading > 0.0:
		return
	var m := int(spec["mag"])
	if int(mag[current]) >= m:
		return
	if int(spec["carry"]) > 0 and int(reserve[current]) <= 0:
		return
	reloading = float(spec["reload"])
	_burst_left = 0
	Sfx.ui(self, "reload", -6.0)
	view.reload_anim(reloading)
	changed.emit()


func _finish_reload() -> void:
	var spec := stat(current)
	var m := int(spec["mag"])
	var need := m - int(mag[current])
	if int(spec["carry"]) < 0:
		mag[current] = m
	else:
		var n := mini(need, int(reserve[current]))
		reserve[current] = int(reserve[current]) - n
		mag[current] = int(mag[current]) + n
	changed.emit()


func _shoot(spec: Dictionary) -> void:
	if int(mag[current]) <= 0:
		_burst_left = 0
		return
	mag[current] = int(mag[current]) - 1
	var cam := player.camera
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var spread := float(spec["aim_spread"] if aiming else spec["spread"])
	if not player.is_on_floor():
		spread *= 1.5
	var pellets := int(spec.get("pellets", 1))
	var any_hit := false
	var killed := false
	for i in pellets:
		var dir := (fwd + cam.global_transform.basis.x * randfn(0.0, spread) + cam.global_transform.basis.y * randfn(0.0, spread)).normalized()
		var r := _ray(from, dir, float(spec["range"]), spec["kind"] == "rail")
		for h in r:
			var hit := Hit.make(_kind(spec), float(spec["damage"]), h.position, dir, player)
			hit.normal = h.normal
			hit.knock = float(spec.get("knock", 0.0)) / pellets * 2.0
			hit.sever = float(spec.get("sever", 1.0))
			var o := Hit.deal(h.collider, hit)
			if o:
				any_hit = true
				if o.get("dead") == true:
					killed = true
			else:
				Effects.impact(self, h.position, h.normal)
		var end: Vector3 = r[-1].position if not r.is_empty() else from + dir * float(spec["range"])
		if i < 3:
			Effects.tracer(self, view.muzzle_position(), end, Color(1.0, 0.85, 0.55) if spec["kind"] != "rail" else Color(0.5, 0.85, 1.0), 0.015 if spec["kind"] != "rail" else 0.05, 0.05 if spec["kind"] != "rail" else 0.25)
	if any_hit:
		hit_marker.emit(killed)
	Sfx.ui(self, String(spec["sound"]), -3.0)
	Noises.make(self, player.global_position, float(spec["noise"]), player)
	Effects.flash(self, view.muzzle_position(), Color(1.0, 0.75, 0.4) if spec["kind"] != "rail" else Color(0.5, 0.8, 1.0), 1.6, 5.0)
	view.recoil(float(spec["recoil"]))
	player._buzz(0.25 * float(spec["recoil"]), 0.08)
	fired.emit(current)
	changed.emit()
	if int(mag[current]) <= 0 and (int(spec["carry"]) < 0 or int(reserve[current]) > 0):
		reload()


func _kind(spec: Dictionary) -> Hit.Kind:
	match String(spec["kind"]):
		"pellets":
			return Hit.Kind.PELLET
		"rail":
			return Hit.Kind.RAIL
	return Hit.Kind.BULLET


## What a shot hits: the first thing, or everything up to a wall for the rail.
func _ray(from: Vector3, dir: Vector3, length: float, pierce: bool) -> Array:
	var space := get_world_3d().direct_space_state
	var out := []
	var exclude: Array[RID] = [player.get_rid()]
	var start := from
	for i in 6 if pierce else 1:
		var q := PhysicsRayQueryParameters3D.create(start, from + dir * length, Kit.SHOT_MASK)
		q.collide_with_areas = true
		q.exclude = exclude
		var h := space.intersect_ray(q)
		if h.is_empty():
			break
		out.append(h)
		if not pierce or not (h.collider is Area3D):
			break
		exclude.append(h.rid)
		start = h.position
	return out

#endregion

#region The cutter

## The cutter cools while it's put away.
func _cool(delta: float, _spec: Dictionary) -> void:
	var cool := float(stat("cutter")["cool"])
	heat = maxf(0.0, heat - cool * delta)
	if overheated and heat <= COOL_AT:
		overheated = false
		changed.emit()


func _cutter(delta: float, spec: Dictionary) -> void:
	var on := not _busy() and swapping <= 0.0 and not overheated and Input.is_action_pressed("action_primary")
	var focus := Input.is_action_pressed("action_secondary") and not _busy()
	if not on:
		_stop_beam()
		_cool_t -= delta
		if _cool_t <= 0.0:
			heat = maxf(0.0, heat - float(spec["cool"]) * delta)
		if overheated and heat <= COOL_AT:
			overheated = false
			changed.emit()
		view.beam(false, Vector3.ZERO, focus)
		return
	_cool_t = 0.4
	heat += float(spec["focus_heat"] if focus else spec["heat"]) * delta
	if heat >= OVERHEAT:
		heat = OVERHEAT
		overheated = true
		Sfx.ui(self, "cutter_hot", -2.0)
		_stop_beam()
		changed.emit()
		return
	if _beam_sound == null:
		Sfx.ui(self, "cutter_start", -6.0)
		_beam_sound = Sfx.ui(self, "cutter_loop", -8.0)
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var reach := float(spec["focus_range"] if focus else spec["range"])
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Kit.SHOT_MASK)
	q.collide_with_areas = true
	q.exclude = [player.get_rid()]
	var h := space.intersect_ray(q)
	var end := from + dir * reach
	if h:
		end = h.position
		var dps := float(spec["focus_damage"] if focus else spec["damage"])
		var hit := Hit.make(Hit.Kind.BURN, dps * delta, h.position, dir, player)
		hit.normal = h.normal
		hit.sever = 1.2 if focus else 0.5
		var o := Hit.deal(h.collider, hit)
		if o:
			if o.has_method("char_by"):
				o.char_by(delta * 0.5)
			if o.get("dead") == true and not _beam_hit.has(o):
				_beam_hit[o] = true
				hit_marker.emit(true)
		else:
			_burn_growth(h.position + h.normal * 0.3, float(spec["focus_burn"] if focus else spec["burn"]) * delta)
	view.beam(true, end, focus)
	_burn_t -= delta
	if _burn_t <= 0.0:
		_burn_t = 0.5
		Noises.make(self, player.global_position, 10.0, player)
	changed.emit()


func _burn_growth(at: Vector3, amount: float) -> void:
	if player.level == null or player.level.bloom == null:
		return
	var cell := DeckLevel.cell_at(at)
	var burnt := player.level.bloom.burn(cell, amount)
	if burnt > 0.0 and DeckScene.current:
		DeckScene.current.on_burn(cell, burnt)


func _stop_beam() -> void:
	if _beam_sound and is_instance_valid(_beam_sound):
		_beam_sound.stop()
		_beam_sound.queue_free()
	_beam_sound = null
	_beam_hit.clear()
	if view:
		view.beam(false, Vector3.ZERO, false)

#endregion

#region Throwing

func next_throwable() -> void:
	var i := THROWABLES.find(throwable)
	for k in range(1, 4):
		var t: String = THROWABLES[(i + k) % THROWABLES.size()]
		if player.items.get(t, 0) > 0:
			throwable = t
			break
	Sfx.ui(self, "ui_select", -10.0)
	changed.emit()


func throw() -> void:
	if player.items.get(throwable, 0) <= 0:
		next_throwable()
		if player.items.get(throwable, 0) <= 0:
			return
	if not player.use_item(throwable):
		return
	var cam := player.camera
	var t: RigidBody3D
	match throwable:
		"flare":
			t = Flare.new()
		"grenade":
			t = Grenade.new()
		_:
			t = Mine.new()
	t.set("from", player)
	get_tree().current_scene.add_child(t)
	t.global_position = cam.global_position + (-cam.global_transform.basis.z) * 0.6 + Vector3(0, -0.15, 0)
	t.linear_velocity = -cam.global_transform.basis.z * THROW_SPEED * (0.6 if throwable == "mine" else 1.0) + Vector3(0, 2.5, 0) + player.velocity * 0.5
	t.angular_velocity = Vector3(randf(), randf(), randf()) * 6.0
	Sfx.ui(self, "throw", -6.0)
	view.throw_anim()
	changed.emit()

#endregion


func shove_anim() -> void:
	if view:
		view.shove_anim()


## For the HUD: "12 / 36", "Heat 45%", "OVERHEATED".
func ammo_text() -> String:
	if current == "cutter":
		return "OVERHEATED" if overheated else "Heat %d%%" % int(heat)
	var spec := stat(current)
	if int(spec["carry"]) < 0:
		return "%d" % int(mag[current])
	return "%d / %d" % [int(mag[current]), int(reserve[current])]
