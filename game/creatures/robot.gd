class_name Robot
extends Creature
## Station security with the Bloom in its joints: the Essentials Kit's robots.
## Half still follow their programs. Drones float and shoot, the quads charge,
## Raptors guard what they always guarded, Trilobites drop from the ceiling.
## They bleed oil, shrug off the cutter, and lose legs to heavy hits and keep
## crawling.

## Each robot's numbers: model, height, health, speeds, damage, reach, what
## it shoots (damage, seconds between, range; 0 for none), flies, legs.
const KINDS := {
	"eyedrone": {"model": "ess:Enemy_EyeDrone", "h": 0.8, "hp": 40, "walk": 1.4, "run": 3.2, "dmg": 0, "reach": 0.0, "shot": [7.0, 1.8, 14.0], "fly": 2.2, "legs": []},
	"gundrone": {"model": "ess:Enemy_GunDrone", "h": 0.75, "hp": 34, "walk": 1.6, "run": 3.6, "dmg": 0, "reach": 0.0, "shot": [4.0, 0.35, 16.0], "fly": 2.4, "legs": [], "burst": 3},
	"quadorb": {"model": "ess:Enemy_QuadOrb", "h": 1.4, "hp": 110, "walk": 1.4, "run": 4.4, "dmg": 18, "reach": 1.8, "shot": [], "fly": 0.0, "legs": ["Front_Leg1.L", "Front_Leg1.R", "Back_Leg1.L", "Back_Leg1.R"]},
	"quadshell": {"model": "ess:Enemy_QuadShell", "h": 1.45, "hp": 140, "walk": 1.2, "run": 3.6, "dmg": 16, "reach": 1.8, "shot": [5.0, 1.2, 12.0], "fly": 0.0, "legs": ["Front_Leg1.L", "Front_Leg1.R", "Back_Leg1.L", "Back_Leg1.R"]},
	"raptor": {"model": "ess:Enemy_Raptor", "h": 2.5, "hp": 260, "walk": 1.3, "run": 4.8, "dmg": 26, "reach": 2.4, "shot": [6.0, 0.9, 18.0], "fly": 0.0, "legs": ["Leg1.L", "Leg1.R"], "guard": true},
	"trilobite": {"model": "ess:Enemy_Trilobite", "h": 2.3, "hp": 200, "walk": 1.2, "run": 4.0, "dmg": 22, "reach": 2.2, "shot": [], "fly": 0.0, "legs": ["Leg1.L", "Leg1.R"], "hangs": true},
}

var spec: Dictionary = {}
## Guards stay within this of home.
var guard_range := 0.0
var hanging := false
var _shot_t := 0.0
var _burst := 0
var _legs_hp := {}
var _legs_lost := 0
var _muzzle_glow: OmniLight3D


func set_kind(k: String) -> void:
	kind = k
	spec = KINDS.get(k, KINDS["quadshell"])
	configure()
	health = max_health


func configure() -> void:
	if spec.is_empty():
		return
	robot = true
	bleeds = "oil"
	max_health = float(spec["hp"])
	walk_speed = float(spec["walk"])
	run_speed = float(spec["run"])
	damage = float(spec["dmg"])
	reach = float(spec["reach"])
	height = float(spec["h"])
	radius = clampf(height * 0.4, 0.3, 1.0)
	flies = float(spec["fly"]) > 0.0
	hover = float(spec["fly"])
	sight_range = 20.0
	sight_cone = 0.35
	hearing = 0.9
	attack_time = 1.1
	strike_at = 0.3
	resist = {Hit.Kind.BURN: 0.45, Hit.Kind.CLAW: 0.5, Hit.Kind.PELLET: 0.8, Hit.Kind.RAIL: 1.3}
	salvage = int(max_health / 40.0) + 1
	gib_count = 0
	if spec.get("guard", false):
		guard_range = 10.0
	hanging = spec.get("hangs", false)
	for l in spec["legs"]:
		_legs_hp[l] = max_health * 0.3


func build() -> void:
	load_model(spec["model"], height)
	if flies:
		model.position.y = -height * 0.5
		var s := SphereShape3D.new()
		s.radius = height * 0.55
		add_hitbox(s, Transform3D())
		_capsule.position.y = 0.0
	else:
		body_hitbox(radius, height)
		for l in _legs_hp:
			var cap := CapsuleShape3D.new()
			cap.radius = 0.1 * height
			cap.height = 0.5 * height
			add_hitbox(cap, Transform3D(Basis(), Vector3(0, 0.2 * height, 0)), "leg:" + l, l)
	# The Bloom in its joints.
	var body_bone := "Body"
	if skeleton and skeleton.find_bone(body_bone) >= 0:
		for i in 3 + randi() % 3:
			var att := BoneAttachment3D.new()
			att.bone_name = body_bone
			skeleton.add_child(att)
			var m := MeshInstance3D.new()
			m.mesh = Flesh.lump_mesh(randf_range(0.06, 0.12) * height / model.scale.y, randi())
			m.material_override = Flesh.material("lump")
			m.position = Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.4), randf_range(-0.4, 0.4)) * height / model.scale.y
			att.add_child(m)
			meshes.append(m)
	_muzzle_glow = OmniLight3D.new()
	_muzzle_glow.light_color = Color(1.0, 0.25, 0.15)
	_muzzle_glow.omni_range = 4.0
	_muzzle_glow.light_energy = 0.0
	_muzzle_glow.position = Vector3(0, height * 0.5 if not flies else 0.0, 0.5)
	add_child(_muzzle_glow)


func setup(lvl: DeckLevel, at: Vector3, asleep := false) -> void:
	super(lvl, at + (Vector3(0, hover, 0) if flies else Vector3.ZERO), asleep)
	if hanging and asleep:
		# Waits on the ceiling.
		position.y = Kit.HEIGHT - height * 0.6
		_play("Hanging", 1.0)


func _floor_y() -> float:
	return 0.0


func think(delta: float) -> void:
	_muzzle_glow.light_energy = maxf(0.0, _muzzle_glow.light_energy - delta * 12.0)
	if hanging:
		velocity = Vector3.ZERO
		if state != State.ASLEEP or (is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.0):
			_drop()
		return
	if guard_range > 0.0 and state == State.HUNT and global_position.distance_to(home) > guard_range and time - last_seen > 1.0:
		plan_to(home)
		state = State.WANDER
	var shot: Array = spec["shot"]
	if not shot.is_empty() and state == State.HUNT and is_instance_valid(target) and time - last_seen < 0.4:
		var d := global_position.distance_to(target.global_position)
		if d < float(shot[2]) and (reach <= 0.0 or d > reach + 0.5):
			face(target.global_position, delta * turn_rate)
			if time > _shot_t:
				_fire(shot)
			if flies:
				# Drones hold off and circle.
				var to := target.global_position - global_position
				var side := Vector3(-to.z, 0, to.x).normalized()
				var want := side * walk_speed + (Vector3(to.x, 0, to.z).normalized() * (d - 7.0) * 0.4)
				velocity.x = move_toward(velocity.x, want.x, delta * 4)
				velocity.z = move_toward(velocity.z, want.z, delta * 4)
				move_anim(walk_speed)
				return
	super(delta)


func _drop() -> void:
	hanging = false
	state = State.HUNT
	velocity = Vector3.ZERO
	Sfx.at(self, "robot_drop", global_position)
	Noises.make(self, global_position, 14.0, self)


func _fire(shot: Array) -> void:
	var burst: int = int(spec.get("burst", 1))
	_burst += 1
	if _burst >= burst:
		_burst = 0
		_shot_t = time + float(shot[1]) * (3.0 if burst > 1 else 1.0)
	else:
		_shot_t = time + float(shot[1])
	_play("AttackAuto" if anim and anim.has_animation("AttackAuto") else "Attack", 1.0)
	_muzzle_glow.light_energy = 2.0
	Sfx.at(self, "turret", global_position, -3.0, 1.3)
	var from := global_position + Vector3(0, (height * 0.55) if not flies else 0.0, 0) + forward() * radius
	var aim: Vector3 = (target.chest_position() if target.has_method("chest_position") else target.global_position) - from
	aim = (aim.normalized() + Vector3(randf_range(-0.05, 0.05), randf_range(-0.04, 0.04), randf_range(-0.05, 0.05))).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + aim * float(shot[2]), Kit.LAYER_SOLID | Kit.LAYER_GLASS | Kit.LAYER_PLAYER)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + aim * float(shot[2])
	if hit:
		end = hit.position
		var n: Node = hit.collider
		if n and n.is_in_group("tech"):
			n.take_hit(Hit.make(Hit.Kind.BULLET, float(shot[0]), hit.position, aim, self))
		else:
			Effects.impact(self, hit.position, hit.normal, Color(1.0, 0.3, 0.2))
	Effects.tracer(self, from, end, Color(1.0, 0.3, 0.2), 0.025)


func limb_hit(hit: Hit) -> void:
	if not hit.limb.begins_with("leg:"):
		return
	var l := hit.limb.trim_prefix("leg:")
	if not _legs_hp.has(l):
		return
	var cut := hit.amount * hit.sever * (1.5 if hit.kind in [Hit.Kind.RAIL, Hit.Kind.BLAST, Hit.Kind.PELLET] else 0.3)
	_legs_hp[l] -= cut
	if _legs_hp[l] <= 0.0 and skeleton and hider:
		_legs_hp.erase(l)
		var bi := skeleton.find_bone(l)
		if bi >= 0:
			hider.hide_bone(bi)
		Effects.impact(self, hit.point, -hit.dir, Color(1.0, 0.6, 0.2))
		Sfx.at(self, "robot_hit", hit.point)
		_legs_lost += 1
		walk_speed *= 0.6
		run_speed *= 0.55
		if model:
			model.rotation.z = 0.12 * _legs_lost * (1 if randf() < 0.5 else -1)
		drop_hitboxes("leg:" + l)


func move_anim(speed: float) -> void:
	_play("Walk" if speed <= walk_speed + 0.1 else "Run", 1.0)


func idle_anim() -> void:
	_play("Idle" if randf() < 0.995 else "Look", 1.0)


func death(_hit: Hit) -> void:
	Sfx.at(self, "robot_die", global_position)
	Effects.impact(self, global_position + Vector3(0, height * 0.5, 0), Vector3.UP, Color(1.0, 0.6, 0.2))
	Gore.splat(self, Vector3(global_position.x, 0.02, global_position.z), Vector3.UP, 1.4, "oil")
	if anim and anim.has_animation("TurnOff"):
		anim.play("TurnOff", 0.1)
	if flies:
		var t := create_tween()
		t.tween_property(self, "global_position:y", 0.3, 0.6).set_ease(Tween.EASE_IN)
	if salvage > 0 and is_inside_tree():
		var p := Pickup.make("salvage", salvage)
		get_parent().add_child(p)
		p.global_position = Vector3(global_position.x + 0.6, 0.0, global_position.z)
	var timer := get_tree().create_timer(45.0)
	timer.timeout.connect(queue_free)
