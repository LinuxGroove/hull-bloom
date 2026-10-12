class_name Viewmodel
extends Node3D
## The tech's hands and what they hold, drawn in front of the camera. The gun
## model carries the recoil (the camera never kicks), sways a little as you
## look and walk, and pulls back when you stand against a wall. The
## sprayer's cold spray, its pressure screen and its coolant's glow live here
## too.

## Each weapon's place in the hands: where, how big, and whether the other
## hand holds it too.
const POSES := {
	"sprayer": {"pos": Vector3(0.17, -0.21, -0.38), "scale": 0.8, "two": true},
	"rivet_gun": {"pos": Vector3(0.19, -0.2, -0.34), "scale": 1.0, "two": false},
	"scattergun": {"pos": Vector3(0.18, -0.21, -0.3), "scale": 1.0, "two": true},
	"rifle": {"pos": Vector3(0.17, -0.21, -0.2), "scale": 0.8, "two": true},
	"smg": {"pos": Vector3(0.18, -0.21, -0.32), "scale": 1.0, "two": true},
	"rail": {"pos": Vector3(0.17, -0.2, -0.12), "scale": 0.62, "two": true},
}
const SLEEVE := Color(0.82, 0.34, 0.08)
const GLOVE := Color(0.09, 0.09, 0.1)
const LAYER := 4

var arsenal: Arsenal
var hand: Node3D
var gun: Node3D
var muzzle: Node3D
var _arms: Array[MeshInstance3D] = []
var _kick := 0.0
var _kick_v := 0.0
var _sway := Vector2.ZERO
var _sway_target := Vector2.ZERO
var _bob := 0.0
var _retract := 0.0
var _lower := 0.0
var _spray: CPUParticles3D
var _spray_light: OmniLight3D
var _frost_puffs: CPUParticles3D
var _screen_mat: StandardMaterial3D
var _glow_mats: Array[StandardMaterial3D] = []
var _coolant_mats: Array[StandardMaterial3D] = []
var _pose := {}
var _anim_t := 0.0
var _anim := ""


func _ready() -> void:
	hand = Node3D.new()
	hand.name = "Hand"
	add_child(hand)
	_build_spray()
	if arsenal and arsenal.player:
		arsenal.player.mouse_movement.connect(_on_look)


func _on_look(rel: Vector2) -> void:
	_sway_target += rel * 0.0006


func show_weapon(w: String) -> void:
	if hand == null:
		return
	for c in hand.get_children():
		c.queue_free()
	_arms.clear()
	_glow_mats.clear()
	_coolant_mats.clear()
	_screen_mat = null
	_pose = POSES.get(w, POSES["rivet_gun"])
	gun = Node3D.new()
	gun.name = "Gun"
	hand.add_child(gun)
	var model_name: String = arsenal.model_name(w) if arsenal else String(Arsenal.WEAPONS[w]["model"])
	var m: Node3D
	if Arsenal.kit_gun(w):
		m = Kit.model(gun, model_name, Vector3.ZERO, -PI * 0.5)
	else:
		m = Kit.model(gun, model_name, Vector3.ZERO)
		_tool_materials(m)
	m.scale = Vector3.ONE * float(_pose["scale"])
	var box := Kit.aabb_of(m)
	# The grip sits at the hand; the muzzle is the model's own Muzzle, or the
	# front of the model.
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	var mark := m.find_child("Muzzle", true, false) as Node3D
	if mark:
		muzzle.position = _in_gun(mark).origin
	else:
		muzzle.position = Vector3(box.get_center().x, box.position.y + box.size.y * 0.72, box.position.z)
	gun.add_child(muzzle)
	for mi in gun.find_children("", "MeshInstance3D", true, false):
		var v := mi as MeshInstance3D
		v.layers = LAYER
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Arms: the right hand on the grip, the left under the barrel.
	_arm(Vector3(0.16, -0.32, 0.38), Vector3(0.0, -0.04, 0.03))
	if _pose["two"]:
		_arm(Vector3(-0.32, -0.36, 0.3), Vector3(box.get_center().x - 0.02, box.position.y + 0.02, lerpf(box.position.z, box.end.z, 0.35)))
	hand.position = _pose["pos"]
	_lower = 1.0


func _arm(from: Vector3, to: Vector3) -> void:
	var sleeve := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.045
	c.bottom_radius = 0.06
	var length := from.distance_to(to)
	c.height = length
	sleeve.mesh = c
	sleeve.material_override = Kit.flat(SLEEVE, 0.85)
	var mid := (from + to) * 0.5
	sleeve.transform = Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), mid)
	var glove := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.045
	s.height = 0.08
	glove.mesh = s
	glove.material_override = Kit.flat(GLOVE, 0.6)
	glove.position = to
	glove.scale = Vector3(1.0, 0.8, 1.4)
	for x in [sleeve, glove]:
		x.layers = LAYER
		x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(x)
		_arms.append(x)


## A node's place in the gun's own space.
func _in_gun(n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var at: Node = n
	while at != null and at != gun:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


## The tools made for the game light parts of themselves: the screen, the
## glowing rings and lights, and the sprayer's coolant. Each gets its own
## copy of its material so the game can drive it.
func _tool_materials(root: Node) -> void:
	for mi in root.find_children("", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s)
			if mat == null:
				continue
			var n := String(mat.resource_name)
			if n.contains("Screen") or n.contains("Glow") or n.contains("Coolant"):
				var copy := (mat as StandardMaterial3D).duplicate() if mat is StandardMaterial3D else StandardMaterial3D.new()
				copy.emission_enabled = true
				m.set_surface_override_material(s, copy)
				if n.contains("Screen"):
					_screen_mat = copy
				elif n.contains("Coolant"):
					_coolant_mats.append(copy)
				else:
					_glow_mats.append(copy)


func _build_spray() -> void:
	# The spray: soft white mist that widens and fades as it flies.
	_spray = CPUParticles3D.new()
	_spray.name = "Spray"
	_spray.amount = 70
	_spray.lifetime = 0.3
	_spray.emitting = false
	_spray.local_coords = false
	_spray.direction = Vector3.FORWARD
	_spray.gravity = Vector3(0, -0.6, 0)
	_spray.scale_amount_min = 0.6
	_spray.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.0))
	_spray.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.94, 1.0, 0.55))
	ramp.set_color(1, Color(0.85, 0.94, 1.0, 0.0))
	_spray.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	_spray.mesh = q
	_spray.material_override = Effects._mist()
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)
	_spray_light = OmniLight3D.new()
	_spray_light.light_color = Color(0.6, 0.85, 1.0)
	_spray_light.light_energy = 0.0
	_spray_light.omni_range = 3.5
	add_child(_spray_light)
	# Frost kicked up where it lands.
	_frost_puffs = CPUParticles3D.new()
	_frost_puffs.amount = 20
	_frost_puffs.lifetime = 0.45
	_frost_puffs.emitting = false
	_frost_puffs.local_coords = false
	_frost_puffs.direction = Vector3.UP
	_frost_puffs.spread = 80.0
	_frost_puffs.initial_velocity_min = 0.4
	_frost_puffs.initial_velocity_max = 1.6
	_frost_puffs.gravity = Vector3(0, -2.0, 0)
	_frost_puffs.scale_amount_min = 0.5
	_frost_puffs.scale_amount_max = 1.5
	var fq := QuadMesh.new()
	fq.size = Vector2(0.03, 0.03)
	_frost_puffs.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.85, 0.95, 1.0)
	_frost_puffs.material_override = fm
	_frost_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_frost_puffs)


## Shows the sprayer's spray out to `end`, or stops it. Focused, it's a
## tight jet that carries further. When it `touches` nothing it's a faint
## mist with no frost kicked up, so it doesn't look as if it reaches whatever
## is under the crosshair beyond it.
func spray(on: bool, end: Vector3, focus: bool, touches := true) -> void:
	if _spray == null:
		return
	_spray.emitting = on
	_frost_puffs.emitting = on and touches
	_spray_light.light_energy = (0.9 if touches else 0.3) if on else 0.0
	if not on or muzzle == null:
		return
	var a := muzzle.global_position
	var length := maxf(0.3, a.distance_to(end))
	var dir := (end - a).normalized()
	_spray.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT), a)
	# Fast enough that the mist just reaches where it lands.
	var speed := length / _spray.lifetime
	_spray.initial_velocity_min = speed * 0.85
	_spray.initial_velocity_max = speed
	_spray.spread = 4.0 if focus else 9.0
	_spray.color_ramp.set_color(0, Color(0.85, 0.94, 1.0, (0.55 if touches else 0.25)))
	_spray_light.global_position = a.lerp(end, 0.7)
	_frost_puffs.global_position = end


func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position


func recoil(amount: float) -> void:
	_kick_v += amount * 2.2


func reload_anim(seconds: float) -> void:
	_anim = "reload"
	_anim_t = seconds


func throw_anim() -> void:
	_anim = "throw"
	_anim_t = 0.35


func shove_anim() -> void:
	_anim = "shove"
	_anim_t = 0.3


func _process(delta: float) -> void:
	if hand == null or arsenal == null or arsenal.player == null:
		return
	var p := arsenal.player
	# Recoil: a spring that kicks the gun back and up, then settles.
	_kick_v -= _kick * 140.0 * delta
	_kick_v *= exp(-16.0 * delta)
	_kick += _kick_v * delta
	# Sway as you look, a gentle bob as you walk.
	_sway_target = _sway_target.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	_sway = _sway.lerp(_sway_target.clamp(Vector2(-0.05, -0.05), Vector2(0.05, 0.05)), clampf(delta * 10.0, 0.0, 1.0))
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	if p.is_on_floor() and speed > 0.5:
		_bob += delta * speed * 1.8
	var bob := Vector3(sin(_bob) * 0.006, -absf(cos(_bob)) * 0.006, 0) * clampf(speed / 4.0, 0.0, 1.0)
	# Pull back from walls right in front.
	var cam := p.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 0.75, Kit.LAYER_SOLID | Kit.LAYER_GLASS)
	var wall := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_retract = move_toward(_retract, 1.0 if wall else 0.0, delta * 4.0)
	var lowered := 1.0 if arsenal.swapping > 0.0 or p.is_dead else 0.0
	_lower = move_toward(_lower, lowered, delta * 5.0)
	var pos: Vector3 = _pose.get("pos", Vector3(0.2, -0.2, -0.35))
	if arsenal.aiming and arsenal.current != "sprayer":
		pos = Vector3(0.0, -0.13, pos.z + 0.02)
	var extra := Vector3.ZERO
	var rot := Vector3.ZERO
	if _anim_t > 0.0:
		_anim_t -= delta
		match _anim:
			"reload":
				extra = Vector3(0, -0.08, 0.04)
				rot = Vector3(-0.3, 0.0, 0.5)
			"throw":
				extra = Vector3(0, -0.12, 0.05)
			"shove":
				extra = Vector3(-0.08, 0.02, -0.12)
				rot = Vector3(0, 0.4, 0.3)
	var want := pos + extra + bob + Vector3(-_sway.x, _sway.y, 0) + Vector3(0, -0.25 * _lower - 0.08 * _retract, 0.12 * _retract + _kick * 0.06)
	hand.position = hand.position.lerp(want, clampf(delta * 18.0, 0.0, 1.0))
	hand.rotation = hand.rotation.lerp(rot + Vector3(_kick * 0.12 + 0.5 * _retract, _sway.x * 2.0, _sway.x * -1.5), clampf(delta * 14.0, 0.0, 1.0))
	_sprayer_glow()


## The sprayer's coolant and screen show how iced up its nozzle is: pale cyan
## when it's clear, white as it ices, and blinking amber when it's iced up.
func _sprayer_glow() -> void:
	if arsenal.current != "sprayer":
		return
	var h := arsenal.ice / Arsenal.ICED
	var c := Color(0.35, 0.85, 1.0).lerp(Color(0.92, 0.97, 1.0), smoothstep(0.5, 0.9, h))
	if arsenal.iced:
		c = Color(1.0, 0.62, 0.25) if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.35 else Color(0.3, 0.18, 0.08)
	var spraying := arsenal.firing and not arsenal.iced
	for m in _glow_mats:
		m.emission = c
		m.emission_energy_multiplier = 1.0 + (2.0 if spraying else 0.0)
	for m in _coolant_mats:
		m.emission = c
		m.emission_energy_multiplier = 0.8 + (0.8 if spraying else 0.0)
	if _screen_mat:
		_screen_mat.emission = c
		_screen_mat.emission_energy_multiplier = 0.6 + h
