class_name Arsenal
extends Node3D
## What the tech carries in their hands: the cryo sprayer, the rivet gun and
## the guns, the rounds for them, and the flares, grenades and mines to
## throw. Lives on the camera; [Viewmodel] draws it.
##
## The sprayer is the only thing that clears the Bloom: its cone of coolant
## freezes the growth it touches, which dies back and stops growing while
## it's frozen, and chills whatever it catches until it freezes solid. Its
## nozzle ices up as it sprays. Shots shatter frozen growth and frozen
## creatures. The rivet gun never runs out; the other guns need rounds.
##
## Swap (Q, RB) works like Throw: a tap goes back to the weapon you had
## before, and a hold opens the weapon wheel, where the right stick or the
## mouse points at a weapon and letting go takes it. The mouse wheel steps
## through them and the number keys pick one.

signal changed
signal hit_marker(kill: bool)
signal fired(weapon: String)
## The weapon wheel opened, closed or points at another weapon.
signal wheel_changed

## Every weapon, in slot order. Kinds: spray (the sprayer), rivet (one
## heavy rivet a pull), shot (one round a pull, or held for automatic),
## pellets, burst, rail (pierces). `model` is a [Kit] model; guns with a red
## upgrade have a "_Red" one too. Aiming the sprayer narrows its cone to a
## jet that reaches further (the `focus_` numbers).
const WEAPONS := {
	"sprayer": {"name": "Cryo sprayer", "slot": 1, "kind": "spray", "model": "sprayer", "damage": 26.0, "focus_damage": 42.0,
		"range": 5.0, "focus_range": 7.5, "cone": 0.14, "focus_cone": 0.035, "ice": 17.0, "focus_ice": 23.0, "thaw": 30.0,
		"freeze": 1.15, "focus_freeze": 0.6, "chill": 0.9, "focus_chill": 1.3},
	"rivet_gun": {"name": "Rivet gun", "slot": 2, "kind": "rivet", "model": "rivet_gun", "damage": 24.0, "rate": 0.55, "mag": 8,
		"carry": -1, "reload": 1.9, "spread": 0.01, "aim_spread": 0.003, "range": 40.0, "knock": 3.0, "noise": 18.0, "sound": "rivet_gun", "recoil": 0.9},
	"scattergun": {"name": "Scattergun", "slot": 3, "kind": "pellets", "model": "ess:Gun_Shotgun", "damage": 9.0, "pellets": 8, "rate": 0.85, "mag": 6,
		"carry": 36, "reload": 2.1, "spread": 0.085, "aim_spread": 0.06, "range": 22.0, "knock": 3.0, "sever": 1.4, "noise": 32.0, "sound": "scattergun", "recoil": 1.6},
	"rifle": {"name": "Pulse rifle", "slot": 4, "kind": "shot", "model": "ess:Gun_Rifle", "damage": 15.0, "rate": 0.11, "auto": true, "mag": 30,
		"carry": 180, "reload": 1.9, "spread": 0.022, "aim_spread": 0.007, "range": 60.0, "knock": 0.7, "noise": 28.0, "sound": "rifle", "recoil": 0.45},
	"smg": {"name": "Burst SMG", "slot": 5, "kind": "burst", "model": "ess:Gun_SMG", "damage": 9.0, "burst": 4, "burst_gap": 0.06, "rate": 0.36, "mag": 32,
		"carry": 192, "reload": 1.5, "spread": 0.04, "aim_spread": 0.02, "range": 40.0, "knock": 0.5, "noise": 26.0, "sound": "smg", "recoil": 0.35},
	"rail": {"name": "Rail rifle", "slot": 6, "kind": "rail", "model": "ess:Gun_Sniper", "damage": 120.0, "rate": 1.4, "mag": 4,
		"carry": 20, "reload": 2.4, "spread": 0.0, "aim_spread": 0.0, "range": 90.0, "knock": 4.0, "sever": 3.0, "noise": 30.0, "sound": "rail", "recoil": 2.0, "zoom": 38.0},
}
## What the red version from the workbench changes.
const RED := {
	"rivet_gun": {"damage": 34.0, "reload": 1.3, "mag": 10},
	"scattergun": {"pellets": 10, "spread": 0.07},
	"rifle": {"damage": 19.0, "mag": 40},
	"smg": {"burst": 5, "mag": 40},
	"rail": {"damage": 170.0, "mag": 5},
}
const THROWABLES := ["flare", "grenade", "mine"]
const THROW_SPEED := 11.0
const HOLD_TO_PICK := 0.35
## The sprayer's nozzle is iced shut at this much ice, and clear again below
## [constant THAW_AT].
const ICED := 100.0
const THAW_AT := 35.0
## Rays in the sprayer's cone: one down the middle and a ring round it.
const SPRAY_RAYS := 6
## Levels of frozen growth a shot breaks off for each point of its damage
## (up to [constant Bloom.SHATTER_MAX] a shot).
const SHATTER_PER_DAMAGE := 0.025
## How far the right stick leans before the wheel points with it.
const WHEEL_STICK := 0.5
## How far the mouse travels (in pixels) before the wheel points with it, and
## the most it counts, so turning back takes as little as going.
const WHEEL_MOUSE := 30.0
const WHEEL_MOUSE_MAX := 100.0

var player: Tech
var owned: Array[String] = []
var current := "sprayer"
## The weapon held before this one, for a tap of Swap.
var last := ""
## Whether the weapon wheel is open (Swap held), and the weapon it points at
## ("" for none yet).
var wheel_open := false
var wheel_pick := ""
## Rounds in each gun's magazine, and carried for it.
var mag := {}
var reserve := {}
## Ice on the sprayer's nozzle, 0 to [constant ICED]; iced shut until it
## thaws back to [constant THAW_AT].
var ice := 0.0
var iced := false
var reloading := 0.0
var swapping := 0.0
var firing := false
var aiming := false
var throwable := "flare"
var view: Viewmodel
## Whether the sprayer, held, would reach what's under the crosshair (for
## the HUD; the spray only freezes what it touches).
var spray_reaches := false

var _thaw_t := 0.0
var _shot_t := 0.0
var _burst_left := 0
var _burst_t := 0.0
var _throw_held := 0.0
var _swap_held := 0.0
var _wheel_mouse := Vector2.ZERO
var _wheel_stick := Vector2.ZERO
var _noise_t := 0.0
var _mark_t := 0.0
var _spray_hit := {}
var _spray_sound: AudioStreamPlayer
var _spray_start: AudioStreamPlayer


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
		owned.append("sprayer")
	for w in WEAPONS:
		var spec := stat(w)
		mag[w] = int(spec.get("mag", 0))
		reserve[w] = int(carried.get(w, int(spec.get("mag", 0)) * 2)) if int(spec.get("carry", 0)) > 0 else 0
	current = owned[0] if not "sprayer" in owned else "sprayer"
	last = ""
	close_wheel(false)
	_swap_held = 0.0
	ice = 0.0
	iced = false
	if view:
		view.show_weapon(current)
	changed.emit()


## A weapon's numbers, with its red upgrade if bought.
func stat(w: String) -> Dictionary:
	var s: Dictionary = WEAPONS.get(w, {}).duplicate()
	if RED.has(w) and Progress.has_upgrade(w + "_red"):
		s.merge(RED[w], true)
		s["red"] = true
	if w == "sprayer":
		if Progress.has_upgrade("sprayer_heater"):
			s["ice"] = s["ice"] * 0.7
			s["focus_ice"] = s["focus_ice"] * 0.7
			s["thaw"] = s["thaw"] * 1.4
		if Progress.has_upgrade("sprayer_nozzle"):
			s["focus_range"] = 9.5
			s["focus_damage"] = s["focus_damage"] * 1.3
			s["focus_chill"] = s["focus_chill"] * 1.3
	return s


## The [Kit] model a weapon is drawn with, red if it's been upgraded.
func model_name(w: String) -> String:
	var s := stat(w)
	var m := String(s.get("model", ""))
	if not s.get("red", false):
		return m
	# The kit names its red guns "_Red"; the game's own tools, "_red".
	return m + ("_Red" if m.begins_with("ess:") else "_red")


## Whether a weapon is one of the Essentials Kit's guns, which face +x in
## their files; the tools made for the game face forward (-z).
static func kit_gun(w: String) -> bool:
	return String(WEAPONS.get(w, {}).get("model", "")).begins_with("ess:")


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
	_stop_spray()
	last = current
	current = w
	LGPlaytest.event("weapon", {"weapon": w})
	reloading = 0.0
	swapping = 0.35
	_burst_left = 0
	Sfx.ui(self, "swap", -10.0)
	view.show_weapon(w)
	changed.emit()


func cycle(step: int) -> void:
	var i := owned.find(current)
	select(owned[(i + step + owned.size()) % owned.size()])


## A tap of Swap: back to the weapon you had before, or on to the next one
## if you don't have it any more.
func swap_last() -> void:
	if last in owned and last != current:
		select(last)
	else:
		cycle(1)


## Swap (Q, RB), down or not this frame. Like Throw: a tap goes back to the
## last weapon, a hold opens the wheel, and letting go takes what it points
## at. Tests call it directly.
func swap_button(down: bool, delta: float) -> void:
	if down:
		_swap_held += delta
		if not wheel_open and _swap_held >= HOLD_TO_PICK:
			open_wheel()
	elif _swap_held > 0.0:
		if wheel_open:
			close_wheel(true)
		elif _swap_held < HOLD_TO_PICK:
			swap_last()
		_swap_held = 0.0


#region The weapon wheel

func open_wheel() -> void:
	if wheel_open:
		return
	wheel_open = true
	wheel_pick = ""
	_wheel_mouse = Vector2.ZERO
	_wheel_stick = Vector2.ZERO
	_stop_spray()
	Sfx.ui(self, "ui_select", -12.0)
	LGPlaytest.event("weapon_wheel", {"weapons": owned.size()})
	wheel_changed.emit()


## Puts the wheel away, taking what it points at if `take`.
func close_wheel(take: bool) -> void:
	if not wheel_open:
		return
	wheel_open = false
	var pick := wheel_pick
	wheel_pick = ""
	wheel_changed.emit()
	if take and pick != "":
		select(pick)


## Points the wheel: `dir` is on the screen (x right, y down), and anything
## shorter than half a unit leaves it pointing where it was, so letting the
## stick spring back before Swap doesn't lose the pick.
func point_wheel(dir: Vector2) -> void:
	if not wheel_open or dir.length() < 0.5 or owned.is_empty():
		return
	var w := wheel_weapon_at(dir)
	if w != wheel_pick:
		wheel_pick = w
		Sfx.ui(self, "ui_select", -16.0)
		wheel_changed.emit()


## The weapon in this direction of the wheel: the owned weapons in slot order,
## clockwise from the top.
func wheel_weapon_at(dir: Vector2) -> String:
	var n := owned.size()
	var a := fposmod(atan2(dir.x, -dir.y), TAU)
	return owned[roundi(a / (TAU / n)) % n]


## Where a weapon sits on the wheel, as a unit direction on the screen.
func wheel_direction(w: String) -> Vector2:
	var a := TAU * maxi(0, owned.find(w)) / maxf(1.0, owned.size())
	return Vector2(sin(a), -cos(a))


## While the wheel is open the mouse and the right stick point in it instead
## of turning the view. True if it took the event.
func wheel_input(event: InputEvent) -> bool:
	if not wheel_open:
		return false
	if event is InputEventMouseMotion:
		_wheel_mouse = (_wheel_mouse + event.relative).limit_length(WHEEL_MOUSE_MAX)
		if _wheel_mouse.length() >= WHEEL_MOUSE:
			point_wheel(_wheel_mouse.normalized())
		return true
	if event is InputEventJoypadMotion and (event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y):
		if event.axis == JOY_AXIS_RIGHT_X:
			_wheel_stick.x = event.axis_value
		else:
			_wheel_stick.y = event.axis_value
		if _wheel_stick.length() >= WHEEL_STICK:
			point_wheel(_wheel_stick.normalized())
		return true
	return false

#endregion


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
	if current == "sprayer":
		_sprayer(delta, spec)
	else:
		_thaw(delta)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()
	if _busy():
		firing = false
		aiming = false
		_stop_spray()
		close_wheel(false)
		_swap_held = 0.0
		return
	aiming = Input.is_action_pressed("action_secondary")
	# Fire does nothing while the wheel is open.
	var pull := Input.is_action_pressed("action_primary") and not wheel_open
	var tap := Input.is_action_just_pressed("action_primary") and not wheel_open
	if current != "sprayer" and swapping <= 0.0 and reloading <= 0.0:
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
					if int(reserve.get(current, 0)) <= 0:
						LGPlaytest.event("out_of_ammo", {"weapon": current})
					reload()
			else:
				_shot_t = float(spec["rate"])
				if spec["kind"] == "burst":
					_burst_left = int(spec["burst"]) - 1
					_burst_t = float(spec["burst_gap"])
				_shoot(spec)
	firing = pull
	if Input.is_action_just_pressed("reload") and not _using():
		reload()
	# The mouse wheel steps either way; Swap is the quick swap and the wheel.
	if Input.is_action_just_pressed("swap"):
		cycle(1)
	elif Input.is_action_just_pressed("swap_back"):
		cycle(-1)
	swap_button(Input.is_action_pressed("quick_swap"), delta)
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
	if current == "sprayer" or reloading > 0.0:
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
				_shatter_growth(h.position, h.normal, float(spec["damage"]))
				if spec["kind"] == "rivet":
					Effects.rivet(self, h.position, h.normal, dir, h.collider as Node)
		var end: Vector3 = r[-1].position if not r.is_empty() else from + dir * float(spec["range"])
		if i < 3:
			match String(spec["kind"]):
				"rail":
					Effects.tracer(self, view.muzzle_position(), end, Color(0.5, 0.85, 1.0), 0.05, 0.25)
				"rivet":
					Effects.tracer(self, view.muzzle_position(), end, Color(0.75, 0.78, 0.8), 0.01, 0.04)
				_:
					Effects.tracer(self, view.muzzle_position(), end, Color(1.0, 0.85, 0.55), 0.015, 0.05)
	if any_hit:
		hit_marker.emit(killed)
	Sfx.ui(self, String(spec["sound"]), -3.0)
	Noises.make(self, player.global_position, float(spec["noise"]), player)
	# The rivet gun is driven by air: no flash, a puff.
	if spec["kind"] == "rivet":
		Effects.puff(self, view.muzzle_position(), -cam.global_transform.basis.z)
	else:
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
		"rivet":
			return Hit.Kind.RIVET
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

#region The sprayer

## The nozzle thaws while the sprayer's put away.
func _thaw(delta: float) -> void:
	ice = maxf(0.0, ice - float(stat("sprayer")["thaw"]) * delta)
	if iced and ice <= THAW_AT:
		iced = false
		changed.emit()


func _sprayer(delta: float, spec: Dictionary) -> void:
	var on := not _busy() and swapping <= 0.0 and not iced and not wheel_open and Input.is_action_pressed("action_primary")
	var focus := Input.is_action_pressed("action_secondary") and not _busy()
	var reach := float(spec["focus_range"] if focus else spec["range"])
	var cone := float(spec["focus_cone"] if focus else spec["cone"])
	_mark_t -= delta
	if not on:
		spray_reaches = not _centre_ray(reach).is_empty()
		_stop_spray()
		_thaw_t -= delta
		if _thaw_t <= 0.0:
			_thaw(delta)
		elif iced and ice <= THAW_AT:
			iced = false
			changed.emit()
		view.spray(false, Vector3.ZERO, focus)
		return
	_thaw_t = 0.4
	ice += float(spec["focus_ice"] if focus else spec["ice"]) * delta
	if ice >= ICED:
		ice = ICED
		iced = true
		Sfx.ui(self, "sprayer_iced", -2.0)
		LGPlaytest.event("sprayer_iced", {})
		_stop_spray()
		changed.emit()
		return
	if _spray_sound == null:
		_spray_start = Sfx.ui(self, "sprayer_start", -6.0)
		_spray_sound = Sfx.ui(self, "sprayer_loop", -8.0)
	var hits := spray_hits(reach, cone)
	var centre: Dictionary = hits["centre"]
	spray_reaches = not centre.is_empty()
	var end: Vector3 = centre["position"] if centre else player.camera.global_position - player.camera.global_transform.basis.z * reach
	var dps := float(spec["focus_damage"] if focus else spec["damage"])
	var chill := float(spec["focus_chill"] if focus else spec["chill"]) * delta
	var dir := -player.camera.global_transform.basis.z
	for o in hits["things"]:
		var h: Dictionary = hits["things"][o]
		var hit := Hit.make(Hit.Kind.FREEZE, dps * delta, h["position"], dir, player)
		hit.normal = h["normal"]
		# The focused jet freezes a limb brittle enough to snap off.
		hit.sever = 1.2 if focus else 0.5
		Hit.deal(h["collider"], hit)
		if not is_instance_valid(o):
			continue
		if o.has_method("chill_by"):
			o.chill_by(chill)
		if o.get("dead") == true and not _spray_hit.has(o):
			_spray_hit[o] = true
			hit_marker.emit(true)
		elif o.get("dead") != true and _mark_t <= 0.0:
			# The spray is hurting it: a marker every so often says so.
			_mark_t = 0.2
			hit_marker.emit(false)
	var amount := float(spec["focus_freeze"] if focus else spec["freeze"]) * delta
	for cell in hits["cells"]:
		_freeze_growth(cell, amount)
	view.spray(true, end, focus, spray_reaches)
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.5
		Noises.make(self, player.global_position, 10.0, player)
	changed.emit()


## What the sprayer's cone touches from the eye: {"centre": the middle ray's
## hit or {}, "things": {owner: hit} for what can be hurt (each once),
## "cells": the tiles whose growth it reaches (each once)}.
func spray_hits(reach: float, cone: float) -> Dictionary:
	var out := {"centre": {}, "things": {}, "cells": []}
	if player == null or not is_inside_tree():
		return out
	var basis := player.camera.global_transform.basis
	var fwd := -basis.z
	for k in SPRAY_RAYS + 1:
		var dir := fwd
		if k > 0:
			var a := TAU * (k - 1) / SPRAY_RAYS
			dir = (fwd + (basis.x * cos(a) + basis.y * sin(a)) * tan(cone)).normalized()
		var h := _ray_from_eye(dir, reach)
		if k == 0:
			out["centre"] = h
		if h.is_empty():
			continue
		var o := Hit.owner_of(h.collider)
		if o != null and o.has_method("take_hit"):
			if not out["things"].has(o):
				out["things"][o] = h
		else:
			var cell := DeckLevel.cell_at(h.position + h.normal * 0.3)
			if not cell in out["cells"]:
				out["cells"].append(cell)
	return out


## What the middle of the spray touches from the eye, within `reach`, or {}.
func _centre_ray(reach: float) -> Dictionary:
	if player == null or not is_inside_tree():
		return {}
	return _ray_from_eye(-player.camera.global_transform.basis.z, reach)


func _ray_from_eye(dir: Vector3, reach: float) -> Dictionary:
	var from := player.camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Kit.SHOT_MASK)
	q.collide_with_areas = true
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _freeze_growth(cell: Vector2i, amount: float) -> void:
	if player.level == null or player.level.bloom == null:
		return
	var gone := player.level.bloom.freeze(cell, amount)
	if gone > 0.0 and DeckScene.current:
		DeckScene.current.on_cleared(cell, gone)


## A shot landed on the station here: frozen growth on that tile shatters.
func _shatter_growth(at: Vector3, normal: Vector3, damage: float) -> void:
	if player.level == null or player.level.bloom == null:
		return
	var cell := DeckLevel.cell_at(at + normal * 0.3)
	if not player.level.bloom.is_frozen(cell):
		return
	var gone := player.level.bloom.shatter(cell, damage * SHATTER_PER_DAMAGE)
	if gone > 0.0:
		Effects.ice_chips(self, at, normal, clampf(gone * 2.0, 0.4, 1.5))
		Sfx.at(self, "ice_crack", at, -4.0)
		if DeckScene.current:
			DeckScene.current.on_cleared(cell, gone)


func _stop_spray() -> void:
	if _spray_sound and is_instance_valid(_spray_sound):
		# The spray's sounds stop when it does, with the valve shutting.
		Sfx.ui(self, "sprayer_stop", -9.0)
		_fade_out(_spray_sound)
		if _spray_start and is_instance_valid(_spray_start):
			_fade_out(_spray_start)
	_spray_sound = null
	_spray_start = null
	_spray_hit.clear()
	if view:
		view.spray(false, Vector3.ZERO, false)


## Turns a sound down over a few hundredths of a second (a hard stop clicks)
## and frees it.
static func _fade_out(p: AudioStreamPlayer) -> void:
	var t := p.create_tween()
	t.tween_property(p, "volume_db", -60.0, 0.06)
	t.tween_callback(p.queue_free)

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
	LGPlaytest.event("threw", {"what": throwable})
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


## For the HUD: "12 / 36", "Ice 45%", "ICED UP".
func ammo_text() -> String:
	if current == "sprayer":
		return "ICED UP" if iced else "Ice %d%%" % int(ice)
	var spec := stat(current)
	if int(spec["carry"]) < 0:
		return "%d" % int(mag[current])
	return "%d / %d" % [int(mag[current]), int(reserve[current])]


## Whether this press of the use button (X on a pad, which also reloads) is
## using something in view, so it doesn't reload as well.
func _using() -> bool:
	if not Input.is_action_just_pressed("interact") or player == null:
		return false
	var pic: Variant = player.get("player_interaction_component")
	return pic != null and is_instance_valid(pic) and pic.interactable != null and is_instance_valid(pic.interactable)
