class_name Heart
extends Node3D
## The Bloom's root on a deck: a nest with a heart in it. The deck's growth
## feeds from it, and it guards itself, hatching spawn and spitting while you
## are near. Hurt it from further off, or from somewhere its spit can't
## reach, and it's roused: it hatches spawn that come for you and spits back
## from where it was hit, which you can see. Cut it out and the growth
## starves. The Core's Heart is the root of them all.

signal killed(h: Heart)

## Within these it hatches and spits on its own.
const SPAWN_RANGE := 18.0
const SPIT_RANGE := 14.0
## How long it answers a hit from out of its reach.
const ROUSED_TIME := 8.0
## An answering spit flies faster and flatter, to reach across a room.
const ANSWER_SPEED := 16.0

var cell := Vector2i.ZERO
var level: DeckLevel
var max_health := 320.0
var health := 320.0
var big := false
var dead := false
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var _time := 0.0
var _spawn_t := 6.0
var _spit_t := 4.0
var _flash := 0.0
## How much frost is on it from the sprayer, 0 to 1.
var _frost := 0.0
var _scale := 1.0
var _beat: AudioStreamPlayer3D
var _roused := 0.0
## Where it was last hit while roused: a spot the shooter could see.
var _hit_at := Vector3.ZERO


static func make(lvl: DeckLevel, at_cell: Vector2i, core := false) -> Heart:
	var h := Heart.new()
	h.name = "Heart"
	h.level = lvl
	h.cell = at_cell
	h.big = core
	h.max_health = 1000.0 if core else 320.0
	if lvl and lvl.overgrown:
		h.max_health *= 1.4
	h.health = h.max_health
	h.add_to_group("hearts")
	h._build()
	return h


func _build() -> void:
	model = Node3D.new()
	add_child(model)
	var ps := Kit.scene("Alien_Scolitex")
	var m: Node3D = ps.instantiate() if ps else Node3D.new()
	model.add_child(m)
	var box := Kit.aabb_of(m)
	_scale = 2.2 if big else 0.85
	m.position.y = -box.position.y
	model.scale = Vector3.ONE * _scale
	Flesh.apply(m, "heart")
	for mi in m.find_children("", "MeshInstance3D", true, false):
		meshes.append(mi)
		(mi as MeshInstance3D).layers = 2
	for ap in m.find_children("", "AnimationPlayer", true, false):
		var a: AnimationPlayer = ap
		if a.has_animation("Alien_Idle"):
			a.get_animation("Alien_Idle").loop_mode = Animation.LOOP_LINEAR
			a.play("Alien_Idle")
			a.speed_scale = 0.5
	# The nest round it: lumps of growth.
	for i in 14 if big else 8:
		var lump := MeshInstance3D.new()
		var r := randf_range(0.3, 0.7) * (2.0 if big else 1.0)
		lump.mesh = Flesh.lump_mesh(r, i)
		lump.material_override = Flesh.material("lump")
		var ang := randf() * TAU
		var dist := randf_range(1.2, 2.0) * (2.2 if big else 1.0)
		lump.position = Vector3(cos(ang) * dist, r * 0.3, sin(ang) * dist)
		lump.scale = Vector3(1.3, 0.6, 1.3)
		lump.layers = 2
		add_child(lump)
	var a3 := Area3D.new()
	a3.name = "Hit_heart"
	a3.collision_layer = Kit.LAYER_HITBOX
	a3.collision_mask = 0
	a3.monitoring = false
	a3.set_meta("owner", self)
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.3 * _scale
	cs.shape = s
	cs.position = Vector3(0, 1.4 * _scale, 0)
	a3.add_child(cs)
	add_child(a3)
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_STATION
	body.collision_mask = 0
	var bcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2 * _scale
	cyl.height = 2.6 * _scale
	bcs.shape = cyl
	bcs.position = Vector3(0, 1.3 * _scale, 0)
	body.add_child(bcs)
	add_child(body)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.1)
	glow.light_energy = 1.2
	glow.omni_range = 8.0 * (2.0 if big else 1.0)
	glow.position = Vector3(0, 1.5 * _scale, 0)
	add_child(glow)
	_beat = Sfx.on(self, "heart_beat_loop", 2.0 if big else -2.0)
	_beat.position = glow.position
	_beat.max_distance = 40.0 if big else 26.0
	_beat.pitch_scale = 0.8 if big else 1.0


func _process(delta: float) -> void:
	if dead:
		return
	_time += delta
	var beat := pow(maxf(0.0, sin(_time * 3.4)), 8.0) * 0.06 * float(LGSettings.get_value("play", "calm_walls", 1.0))
	model.scale = Vector3.ONE * _scale * (1.0 + beat)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		for m in meshes:
			m.set_instance_shader_parameter("hurt", _flash)
	if _frost > 0.0:
		_set_frost(_frost - delta * 0.12)
	var player := get_tree().get_first_node_in_group("tech") as Node3D
	if player == null:
		return
	var d := player.global_position.distance_to(global_position)
	_roused = maxf(0.0, _roused - delta)
	if d > SPAWN_RANGE and _roused <= 0.0:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(7.0, 12.0) * (0.6 + 0.4 * health / max_health)
		if DeckScene.current and DeckScene.current.director:
			DeckScene.current.director.heart_spawn(self)
	_spit_t -= delta
	if _spit_t <= 0.0 and (d < SPIT_RANGE or _roused > 0.0):
		_spit_t = randf_range(2.5, 4.5) * (0.8 if big else 1.0)
		spit_at(player)


## Spits at the player: from its top, or, roused and with that way blocked,
## from where it was hit.
func spit_at(player: Node3D) -> Spit:
	var s := Spit.new()
	s.from = self
	s.damage = 7.0 if big else 6.0
	s.infect = 4.0 if big else 6.0
	get_tree().current_scene.add_child(s)
	var target := _chest(player)
	var from := _mouth()
	if _roused > 0.0 and not _clear(from, target):
		from = _hit_at + (target - _hit_at).normalized() * 0.5
	s.global_position = from
	var aim := target - from
	if _roused > 0.0:
		# Lifted just enough to land on target.
		s.velocity = aim.normalized() * ANSWER_SPEED + Vector3(0, 3.0 * aim.length() / ANSWER_SPEED, 0)
	else:
		s.velocity = aim.normalized() * 10.0 + Vector3(0, aim.length() * 0.15, 0)
	return s


func roused() -> bool:
	return _roused > 0.0


## From under the ceiling: the Core's Heart is taller than a storey.
func _mouth() -> Vector3:
	return global_position + Vector3(0, minf(2.4 * _scale, Kit.HEIGHT - 0.8), 0)


static func _chest(player: Node3D) -> Vector3:
	return player.chest_position() if player.has_method("chest_position") else player.global_position


func _clear(a: Vector3, b: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, Kit.LAYER_SOLID | Kit.LAYER_GLASS)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func take_hit(hit: Hit) -> void:
	if dead:
		return
	if hit.from is Node3D and (hit.from as Node3D).is_in_group("tech"):
		var shooter := hit.from as Node3D
		if shooter.global_position.distance_to(global_position) >= SPIT_RANGE or not _clear(_mouth(), _chest(shooter)):
			_hit_at = hit.point
			if _roused <= 0.0:
				_spit_t = minf(_spit_t, 0.6)
				_spawn_t = minf(_spawn_t, 1.5)
			_roused = ROUSED_TIME
	var amount := hit.amount * (2.5 if hit.kind == Hit.Kind.FREEZE else 1.0)
	health -= amount
	_flash = 1.0
	if hit.kind == Hit.Kind.FREEZE:
		_set_frost(_frost + amount / 90.0)
	elif randf() < 0.4:
		Gore.spray(self, hit.point, hit.dir, 1.0, "bloom")
	if health <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("hearts")
	_beat.stop()
	Sfx.at(self, "heart_die", global_position + Vector3(0, 2, 0), 6.0)
	Gore.gibs(self, global_position + Vector3(0, 1.5 * _scale, 0), 12, "heart", 6.0, "bloom")
	Gore.pool(self, global_position + Vector3(0, 0.02, 0), 4.0 * _scale, "bloom")
	for m in meshes:
		m.material_override = Flesh.material("frozen", m.skin != null)
	_set_frost(1.0)
	if level and level.bloom:
		level.bloom.kill_root(cell)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3(1.1, 0.5, 1.1) * _scale, 2.5).set_ease(Tween.EASE_OUT)
	killed.emit(self)


func _set_frost(v: float) -> void:
	var was := _frost
	_frost = clampf(v, 0.0, 1.0)
	if absf(_frost - was) < 0.001 and _frost > 0.0:
		return
	for m in meshes:
		if m.material_overlay == null and _frost > 0.0:
			m.material_overlay = Flesh.frost_material(m.mesh != null and m.mesh.has_meta("rest_baked"))
		m.set_instance_shader_parameter("frost", _frost)
