class_name Heart
extends Node3D
## The Bloom's root on a deck: a nest with a heart in it. The deck's growth
## feeds from it, and it guards itself, hatching spawn and spitting while you
## are near. Cut it out and the growth starves. The Core's Heart is the root
## of them all.

signal killed(h: Heart)

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
var _scale := 1.0


static func make(lvl: DeckLevel, at_cell: Vector2i, core := false) -> Heart:
	var h := Heart.new()
	h.name = "Heart"
	h.level = lvl
	h.cell = at_cell
	h.big = core
	h.max_health = 1500.0 if core else 320.0
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
	var player := get_tree().get_first_node_in_group("tech") as Node3D
	if player == null:
		return
	var d := player.global_position.distance_to(global_position)
	if d > 18.0 * (1.6 if big else 1.0):
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(7.0, 12.0) * (0.7 if big else 1.0) * (0.6 + 0.4 * health / max_health)
		if DeckScene.current and DeckScene.current.director:
			DeckScene.current.director.heart_spawn(self)
	_spit_t -= delta
	if _spit_t <= 0.0 and d < 14.0:
		_spit_t = randf_range(2.5, 4.5) * (0.6 if big else 1.0)
		var s := Spit.new()
		s.from = self
		s.damage = 9.0 if big else 6.0
		get_tree().current_scene.add_child(s)
		# From under the ceiling: the Core's Heart is taller than a storey.
		s.global_position = global_position + Vector3(0, minf(2.4 * _scale, Kit.HEIGHT - 0.8), 0)
		var aim: Vector3 = (player.chest_position() if player.has_method("chest_position") else player.global_position) - s.global_position
		s.velocity = aim.normalized() * 10.0 + Vector3(0, aim.length() * 0.15, 0)


func take_hit(hit: Hit) -> void:
	if dead:
		return
	var amount := hit.amount * (2.5 if hit.kind == Hit.Kind.BURN else 1.0)
	health -= amount
	_flash = 1.0
	if randf() < 0.4:
		Gore.spray(self, hit.point, hit.dir, 1.0, "bloom")
	if health <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("hearts")
	Sfx.at(self, "heart_die", global_position + Vector3(0, 2, 0), 6.0)
	Gore.gibs(self, global_position + Vector3(0, 1.5 * _scale, 0), 12, "heart", 6.0, "bloom")
	Gore.pool(self, global_position + Vector3(0, 0.02, 0), 4.0 * _scale, "bloom")
	for m in meshes:
		m.material_override = Flesh.material("charred", m.skin != null)
	if level and level.bloom:
		level.bloom.kill_root(cell)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3(1.1, 0.5, 1.1) * _scale, 2.5).set_ease(Tween.EASE_OUT)
	killed.emit(self)
