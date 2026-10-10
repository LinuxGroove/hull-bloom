class_name Watcher
extends Creature
## Floats above the growth with one great eye. When it sees you it screams,
## waking every pod and creature near it, then keeps its distance and spits.
## Kill it first.

const SCREAM_RANGE := 22.0
const SPIT_TIME := 3.2
const KEEP_AWAY := 7.0

var screamed := false
var _spit_t := 0.0
var _scream_t := 0.0


func configure() -> void:
	kind = "watcher"
	max_health = 45.0
	walk_speed = 1.0
	run_speed = 2.2
	damage = 7.0
	reach = 0.0
	sight_range = 24.0
	sight_cone = 0.0
	hearing = 0.8
	flies = true
	hover = 2.6
	radius = 0.55
	height = 1.4
	gib_count = 5
	gib_look = "watcher"


func build() -> void:
	load_model("Alien_Cyclop", 1.5, "watcher")
	model.position.y -= 0.6
	var s := SphereShape3D.new()
	s.radius = 0.6
	add_hitbox(s, Transform3D(Basis(), Vector3(0, 0.1, 0)))
	_capsule.position.y = 0.1
	var eye := OmniLight3D.new()
	eye.light_color = Color(1.0, 0.3, 0.15)
	eye.light_energy = 0.6
	eye.omni_range = 4.0
	eye.position = Vector3(0, 0.3, 0.4)
	add_child(eye)


func setup(lvl: DeckLevel, at: Vector3, asleep := false) -> void:
	super(lvl, at + Vector3(0, hover, 0), asleep)


func _floor_y() -> float:
	return 0.0


func think(delta: float) -> void:
	if model:
		model.position.y = -0.6 + sin(time * 1.3) * 0.12
	if state == State.ASLEEP:
		velocity = Vector3.ZERO
		return
	if not is_instance_valid(target):
		return
	var seen := time - last_seen < 0.5
	if seen and not screamed:
		_scream()
	if state in [State.HUNT, State.ATTACK] and seen:
		var to := target.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		face(target.global_position, delta * turn_rate)
		if flat.length() < KEEP_AWAY:
			velocity.x = -flat.normalized().x * run_speed
			velocity.z = -flat.normalized().z * run_speed
		else:
			velocity.x = move_toward(velocity.x, 0, delta * 4)
			velocity.z = move_toward(velocity.z, 0, delta * 4)
		if time > _spit_t:
			_spit_t = time + SPIT_TIME + randf()
			_spit()
		# Screams again now and then while it can see you.
		if time > _scream_t:
			_scream()
	else:
		super(delta)


func _scream() -> void:
	screamed = true
	_scream_t = time + 12.0
	Sfx.at(self, "watcher_scream", global_position, 6.0)
	Noises.make(self, global_position, SCREAM_RANGE * 1.5, self)
	for p in get_tree().get_nodes_in_group("pods"):
		if p.global_position.distance_to(global_position) < SCREAM_RANGE and p.has_method("wake"):
			p.wake()
	for c in get_tree().get_nodes_in_group("creatures"):
		if c != self and c.global_position.distance_to(global_position) < SCREAM_RANGE:
			c.alert(target.global_position if is_instance_valid(target) else global_position)
	if DeckScene.current:
		DeckScene.current.on_scream(self)


func _spit() -> void:
	var s := Spit.new()
	s.from = self
	s.damage = damage
	get_tree().current_scene.add_child(s)
	s.global_position = global_position + forward() * 0.6
	var aim: Vector3 = target.chest_position() - s.global_position
	s.velocity = aim.normalized() * 9.0 + Vector3(0, aim.length() * 0.12, 0)
	Sfx.at(self, "spit", global_position, -2.0)
