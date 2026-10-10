class_name Creature
extends CharacterBody3D
## Something the Bloom made, took or infected. A creature finds its way
## round the deck on the tile grid (through doors it can open, and vents if
## it fits), sees and hears the player, closes in and attacks. Kinds extend
## this and set its numbers in [method configure], and override
## [method think] or [method attack] where they behave differently.
##
## Shots hit its hitboxes ([method add_hitbox]), which carry the limb they
## cover; its walking capsule only blocks.

signal died(c: Creature)

enum State {ASLEEP, IDLE, WANDER, HUNT, ATTACK, HURT, DEAD}

## Which creature it is ("skitter", "taken", "quadshell").
var kind := "creature"
var max_health := 40.0
var walk_speed := 1.6
var run_speed := 4.0
var turn_rate := 7.0
var damage := 10.0
var reach := 1.6
## Seconds between attacks, and how far into one the blow lands.
var attack_time := 1.2
var strike_at := 0.35
var sight_range := 20.0
## How wide it sees, as the dot of its facing and the way to you.
var sight_cone := 0.2
var hearing := 1.0
var opens_doors := false
var uses_vents := false
## Flying creatures hover this high and ignore gravity.
var flies := false
var hover := 0.0
var radius := 0.4
var height := 1.6
## What it bleeds: "blood", "bloom", "ichor", "oil".
var bleeds := "bloom"
var gib_count := 5
var gib_look := "gib"
var robot := false
## How much each kind of hit hurts it (by [enum Hit.Kind]); missing is 1.
var resist := {}
## Salvage it leaves, for the workbench.
var salvage := 0

var state := State.IDLE
var health := 40.0
var level: DeckLevel
var target: Node3D
var target_pos := Vector3.ZERO
var last_seen := -100.0
var home := Vector3.ZERO
var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var hider: LimbHider
var meshes: Array[MeshInstance3D] = []
## [position, door key or "", vent: bool] steps to where it's going.
var path: Array = []
var stunned := 0.0
var time := 0.0
var dead := false
## Spawned by a pod or the director, rather than placed by the level.
var spawned := false

var _replan := 0.0
var _sense := 0.0
var _attack_t := 0.0
var _striking := -1.0
var _wander_t := 0.0
var _flash := 0.0
var _stuck := 0.0
var _last_pos := Vector3.ZERO
var _knock := Vector3.ZERO
var _venting := 0.0
var _vent_exit := Vector3.ZERO
var _door_wait := 0.0
var _capsule: CollisionShape3D
var _grav := 14.0


func _init() -> void:
	collision_layer = Kit.LAYER_CREATURES
	collision_mask = Kit.LAYER_SOLID | Kit.LAYER_GLASS | Kit.LAYER_CREATURES | Kit.LAYER_PLAYER
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	safe_margin = 0.02
	add_to_group("creatures")
	configure()
	health = max_health


## Set the kind's numbers here.
func configure() -> void:
	pass


## Builds the model and hitboxes; called once it's placed.
func build() -> void:
	pass


func setup(lvl: DeckLevel, at: Vector3, asleep := false) -> void:
	level = lvl
	position = at
	home = at
	_last_pos = at
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_capsule = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0 + 0.01)
	_capsule.shape = cap
	_capsule.position = Vector3(0, cap.height * 0.5, 0)
	add_child(_capsule)
	build()
	for m in meshes:
		m.layers = 2
	state = State.ASLEEP if asleep else State.IDLE


func _ready() -> void:
	if not is_instance_valid(target):
		target = _player()


static func _player() -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	var p := tree.get_first_node_in_group("tech") if tree else null
	return p as Node3D


#region Every tick

func _physics_process(delta: float) -> void:
	if dead:
		return
	time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_set_flash(_flash)
	if _venting > 0.0:
		_venting -= delta
		if _venting <= 0.0:
			_leave_vent()
		return
	if stunned > 0.0:
		stunned -= delta
	_sense -= delta
	if _sense <= 0.0:
		_sense = 0.2 + randf() * 0.1
		sense()
	think(delta)
	_move(delta)


## Looks for the player. Asleep creatures only wake to noise or being hurt.
func sense() -> void:
	if state == State.ASLEEP or not is_instance_valid(target):
		return
	if _can_see_target():
		last_seen = time
		target_pos = target.global_position
		if state in [State.IDLE, State.WANDER]:
			alert(target_pos)


## Decides what to do; kinds override it. The default walks its rounds,
## hunts what it saw or heard, and attacks in reach.
func think(delta: float) -> void:
	match state:
		State.ASLEEP:
			velocity.x = 0
			velocity.z = 0
			idle_anim()
		State.IDLE, State.WANDER:
			_wander(delta)
		State.HUNT:
			_hunt(delta)
		State.ATTACK:
			_attacking(delta)
		State.HURT:
			velocity.x = 0
			velocity.z = 0
			if stunned <= 0.0:
				state = State.HUNT


func _wander(delta: float) -> void:
	_wander_t -= delta
	if path.is_empty():
		velocity.x = move_toward(velocity.x, 0, delta * 10)
		velocity.z = move_toward(velocity.z, 0, delta * 10)
		idle_anim()
		if _wander_t <= 0.0:
			_wander_t = randf_range(3.0, 8.0)
			var spot := wander_spot()
			if spot != Vector3.INF:
				plan_to(spot)
	else:
		follow(delta, walk_speed)
		move_anim(walk_speed)


## Somewhere near home to wander to, or INF to stay put.
func wander_spot() -> Vector3:
	if level == null:
		return Vector3.INF
	var c := DeckLevel.cell_at(home)
	var options: Array[Vector2i] = [c]
	for s in DeckLevel.SIDE_ORDER:
		var n: Vector2i = c + DeckLevel.STEP[s]
		if level.walkable(c, n, false):
			options.append(n)
	var pick: Vector2i = options[randi() % options.size()]
	return DeckLevel.center(pick) + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))


func _hunt(delta: float) -> void:
	if not is_instance_valid(target) or _target_gone():
		state = State.WANDER
		path.clear()
		return
	var to := target.global_position - global_position
	var dist := Vector2(to.x, to.z).length()
	var seen := time - last_seen < 0.6
	if seen and dist <= reach and absf(to.y) < height + 1.0:
		_start_attack()
		return
	if seen and dist < 7.0 and _clear_to(target.global_position):
		path.clear()
		steer(target.global_position, run_speed, delta)
	else:
		_replan -= delta
		if _replan <= 0.0 or path.is_empty():
			_replan = 0.8 + randf() * 0.4
			plan_to(target.global_position if seen else target_pos)
		if path.is_empty():
			if global_position.distance_to(target_pos) < 1.5 and not seen:
				state = State.WANDER
				home = global_position
			velocity.x = move_toward(velocity.x, 0, delta * 10)
			velocity.z = move_toward(velocity.z, 0, delta * 10)
		else:
			follow(delta, run_speed)
	move_anim(run_speed)


func _target_gone() -> bool:
	if target.has_method("down") and target.down():
		return true
	# Lost them for a while.
	return time - last_seen > 25.0 and global_position.distance_to(target_pos) < 2.0


func _start_attack() -> void:
	if _attack_t > time:
		face(target.global_position, 1.0)
		velocity.x = 0
		velocity.z = 0
		return
	state = State.ATTACK
	_attack_t = time + attack_time
	_striking = time + strike_at
	attack_anim()


func _attacking(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, delta * 12)
	velocity.z = move_toward(velocity.z, 0, delta * 12)
	if is_instance_valid(target):
		face(target.global_position, delta * turn_rate)
	if _striking > 0.0 and time >= _striking:
		_striking = -1.0
		strike()
	if time >= _attack_t - attack_time * 0.25:
		state = State.HUNT


## The blow lands: hurts the target if it's still in reach and in front.
func strike() -> void:
	if not is_instance_valid(target):
		return
	var to := target.global_position - global_position
	if Vector2(to.x, to.z).length() <= reach + 0.4 and forward().dot(Vector3(to.x, 0, to.z).normalized()) > 0.2:
		var h := Hit.make(Hit.Kind.CLAW, damage, target.global_position + Vector3(0, 1.2, 0), to, self)
		h.knock = 2.0
		if target.has_method("take_hit"):
			target.take_hit(h)

#endregion

#region Moving

func _move(delta: float) -> void:
	if flies:
		var want := _floor_y() + hover
		velocity.y = (want - global_position.y) * 3.0
	elif not is_on_floor():
		velocity.y -= _grav * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	if _knock.length() > 0.05:
		velocity += _knock
		_knock = _knock.move_toward(Vector3.ZERO, delta * 30.0)
	move_and_slide()
	# Stuck against something: plan again.
	if Vector2(velocity.x, velocity.z).length() > 0.5:
		if global_position.distance_to(_last_pos) < 0.02:
			_stuck += delta
			if _stuck > 0.8:
				_stuck = 0.0
				_replan = 0.0
				if not path.is_empty():
					path.pop_front()
		else:
			_stuck = 0.0
	_last_pos = global_position


func _floor_y() -> float:
	return 0.0


## Plans a route to `pos` over the tile grid.
func plan_to(pos: Vector3) -> void:
	path.clear()
	if level == null:
		return
	var from := DeckLevel.cell_at(global_position)
	var to := DeckLevel.cell_at(pos)
	if from == to:
		path.append([pos, "", false])
		return
	var steps := level.tile_path(from, to, opens_doors, uses_vents)
	if steps.is_empty():
		return
	var prev := from
	for s in steps:
		var c: Vector2i = s[0]
		var via: String = s[1]
		if via == "vent":
			path.append([DeckLevel.center(c), "", true])
		else:
			var mid := (DeckLevel.center(prev) + DeckLevel.center(c)) * 0.5
			var key := DeckLevel.edge_key(prev, c) if via == "door" else ""
			path.append([mid, key, false])
		prev = c
	path.append([pos, "", false])


## Walks the planned route.
func follow(delta: float, speed: float) -> void:
	if path.is_empty():
		return
	var step: Array = path[0]
	var wp: Vector3 = step[0]
	if step[2]:
		_enter_vent(wp)
		return
	var key: String = step[1]
	if key != "" and level.doors.has(key):
		var d: Bulkhead = level.doors[key]
		if not d.passable():
			var flat := Vector2(wp.x - global_position.x, wp.z - global_position.z).length()
			if flat < 1.6:
				velocity.x = 0
				velocity.z = 0
				face(wp, delta * turn_rate)
				_door_wait += delta
				if opens_doors and not d.sealed and not d.airless and d.locked == "":
					if _door_wait > 0.6:
						d.creature_open()
				elif _door_wait > 1.0:
					_door_wait = 0.0
					path.clear()
					_replan = 0.0
				return
	_door_wait = 0.0
	steer(wp, speed, delta)
	var reach_wp := 0.6 if path.size() > 1 else 0.3
	if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() < reach_wp:
		path.pop_front()


## Heads straight for a point.
func steer(to: Vector3, speed: float, delta: float) -> void:
	var d := to - global_position
	d.y = 0
	if d.length() < 0.05:
		velocity.x = 0
		velocity.z = 0
		return
	var dir := d.normalized()
	# Keep a little apart from the pack.
	for o in get_tree().get_nodes_in_group("creatures"):
		if o == self or not o is Creature or o.dead:
			continue
		var away: Vector3 = global_position - o.global_position
		away.y = 0
		var dist := away.length()
		var min_d: float = radius + o.radius + 0.2
		if dist < min_d and dist > 0.01:
			dir += away / dist * (min_d - dist) * 1.5
	dir = dir.normalized()
	var mult := 1.0 if stunned <= 0.0 else 0.3
	velocity.x = move_toward(velocity.x, dir.x * speed * mult, delta * 20)
	velocity.z = move_toward(velocity.z, dir.z * speed * mult, delta * 20)
	face(global_position + dir, delta * turn_rate)


## Turns to look at a point, `amount` of the way.
func face(pos: Vector3, amount: float) -> void:
	var d := pos - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var want := atan2(d.x, d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(amount, 0.0, 1.0))


func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0, cos(rotation.y))


func _enter_vent(at: Vector3) -> void:
	# Climb into the ceiling grille here and come out of the one at `at`.
	path.pop_front()
	_venting = clampf(global_position.distance_to(at) / 6.0, 1.0, 5.0)
	_vent_exit = at
	visible = false
	_capsule.disabled = true
	for h in find_children("", "Area3D", true, false):
		(h as Area3D).collision_layer = 0


func _leave_vent() -> void:
	global_position = _vent_exit + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5))
	reset_physics_interpolation()
	visible = true
	_capsule.disabled = false
	for h in find_children("", "Area3D", true, false):
		(h as Area3D).collision_layer = Kit.LAYER_HITBOX
	Sfx.at(self, "vent_crawl", global_position + Vector3(0, 4, 0), -6.0)

#endregion

#region Senses

func _can_see_target() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var eye := global_position + Vector3(0, height * 0.8, 0)
	var at: Vector3 = target.chest_position() if target.has_method("chest_position") else target.global_position + Vector3(0, 1, 0)
	var to := at - eye
	var range_ := sight_range
	if target.has_method("is_seen_easily") and not target.is_seen_easily():
		range_ *= 0.55
	if to.length() > range_:
		return false
	if state in [State.IDLE, State.WANDER] and forward().dot(Vector3(to.x, 0, to.z).normalized()) < sight_cone and to.length() > 3.0:
		return false
	return _clear(eye, at)


func _clear_to(pos: Vector3) -> bool:
	return _clear(global_position + Vector3(0, 0.6, 0), pos + Vector3(0, 0.6, 0))


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Kit.LAYER_SOLID)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A noise somewhere: loud enough and it comes to look.
func hear(pos: Vector3, loudness: float, from: Node) -> void:
	if dead or from == self:
		return
	var d := global_position.distance_to(pos)
	var heard := loudness * hearing
	if d > heard:
		return
	if d > heard * 0.5 and not _clear(global_position + Vector3(0, 1, 0), pos + Vector3(0, 0.5, 0)):
		return
	if state in [State.ASLEEP, State.IDLE, State.WANDER]:
		alert(pos)
	elif state == State.HUNT and time - last_seen > 2.0:
		target_pos = pos


## Something's there: go and look.
func alert(pos: Vector3) -> void:
	if dead:
		return
	target_pos = pos
	if state == State.ASLEEP:
		wake()
	state = State.HUNT
	_replan = 0.0


func wake() -> void:
	if state == State.ASLEEP:
		state = State.IDLE

#endregion

#region Being hurt

func take_hit(hit: Hit) -> void:
	if dead:
		return
	var amount := hit.amount * float(resist.get(hit.kind, 1.0))
	if hit.by_player() and DeckScene.current:
		amount *= DeckScene.current.player_damage()
	health -= amount
	_flash = 1.0
	_set_flash(1.0)
	if hit.knock > 0.0:
		var k := hit.dir
		k.y = 0
		_knock += k.normalized() * hit.knock
	if hit.kind != Hit.Kind.BURN or randf() < 0.2:
		bleed(hit)
	limb_hit(hit)
	if state in [State.ASLEEP, State.IDLE, State.WANDER]:
		var src := hit.from as Node3D
		alert(src.global_position if src else hit.point)
		last_seen = time
	if health <= 0.0:
		die(hit)
		return
	if amount >= max_health * 0.3 and state != State.ATTACK:
		stunned = 0.35
		state = State.HURT
		hurt_anim()


## Blood (or ichor, or oil) where it was hit.
func bleed(hit: Hit) -> void:
	if robot:
		Sfx.at(self, "robot_hit", hit.point, -4.0)
	else:
		Sfx.at(self, "hit_flesh", hit.point, -6.0)
	Gore.spray(self, hit.point, hit.dir, clampf(hit.amount / 15.0, 0.3, 1.5), bleeds)


## A hit landed on a limb; kinds that come apart override it.
func limb_hit(_hit: Hit) -> void:
	pass


func die(hit: Hit) -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	health = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = Kit.LAYER_SOLID
	for h in find_children("", "Area3D", true, false):
		(h as Area3D).collision_layer = 0
	remove_from_group("creatures")
	died.emit(self)
	death(hit)


## What dying looks like; the default bursts into gibs.
func death(hit: Hit) -> void:
	Sfx.at(self, "gib", global_position + Vector3(0, 0.6, 0))
	Gore.gibs(self, global_position + Vector3(0, height * 0.5, 0), gib_count, gib_look, 4.0 + hit.knock, bleeds)
	queue_free()


func _set_flash(v: float) -> void:
	for m in meshes:
		if is_instance_valid(m) and m.material_override is ShaderMaterial:
			m.set_instance_shader_parameter("hurt", v)


## Burns from the cutter char it for good.
func char_by(amount: float) -> void:
	for m in meshes:
		if is_instance_valid(m) and m.material_override is ShaderMaterial:
			var c = m.get_instance_shader_parameter("charred")
			m.set_instance_shader_parameter("charred", minf(1.0, (c if c != null else 0.0) + amount))

#endregion

#region Models

## Loads a kit model, standing on its feet (or hanging from its top) and
## scaled to `want_height`, with `look` flesh unless it's a robot.
func load_model(name: String, want_height: float, look := "", hang := false) -> Node3D:
	var ps := Kit.scene(name)
	model = ps.instantiate() if ps else Node3D.new()
	add_child(model)
	var box := Kit.aabb_of(model)
	var s := want_height / maxf(box.size.y, 0.01)
	model.scale = Vector3.ONE * s
	if hang:
		model.position.y = -(box.end.y) * s
	else:
		model.position.y = -box.position.y * s
	skeleton = model.find_child("Skeleton3D", true, false)
	for ap in model.find_children("", "AnimationPlayer", true, false):
		anim = ap
		break
	for mi in model.find_children("", "MeshInstance3D", true, false):
		meshes.append(mi)
	if look != "":
		Flesh.apply(model, look)
	if skeleton:
		hider = LimbHider.new()
		skeleton.add_child(hider)
	return model


## A hitbox: a box or capsule shots can hit. `bone` makes it follow a bone.
func add_hitbox(shape: Shape3D, at: Transform3D, limb := "", bone := "") -> Area3D:
	var a := Area3D.new()
	a.name = ("Hit_" + (limb if limb != "" else "body")).validate_node_name()
	a.collision_layer = Kit.LAYER_HITBOX
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	a.set_meta("owner", self)
	if limb != "":
		a.set_meta("limb", limb)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = at
	a.add_child(cs)
	if bone != "" and skeleton and skeleton.find_bone(bone) >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = bone
		skeleton.add_child(att)
		att.add_child(a)
	else:
		add_child(a)
	return a


## Stops shots landing on a limb that's gone.
func drop_hitboxes(limb: String) -> void:
	for h in find_children("Hit_*", "Area3D", true, false):
		if h.has_meta("limb") and String(h.get_meta("limb")) == limb:
			(h as Area3D).collision_layer = 0


## A capsule hitbox round the whole body.
func body_hitbox(r := -1.0, h := -1.0) -> Area3D:
	var cap := CapsuleShape3D.new()
	cap.radius = r if r > 0 else radius
	cap.height = maxf(h if h > 0 else height, cap.radius * 2.0 + 0.01)
	return add_hitbox(cap, Transform3D(Basis(), Vector3(0, cap.height * 0.5, 0)))


func idle_anim() -> void:
	_play("Idle", 1.0)


func move_anim(speed: float) -> void:
	_play("Walk" if speed <= walk_speed + 0.1 else "Run", 1.0)


func attack_anim() -> void:
	_play("Attack", 1.0)


func hurt_anim() -> void:
	_play("Hit", 1.0)


func _play(clip: String, speed: float) -> void:
	if anim == null:
		return
	if not anim.has_animation(clip):
		if clip in ["Walk", "Run"] and anim.has_animation("Alien_Idle"):
			clip = "Alien_Idle"
			speed *= 2.0
		elif anim.has_animation("Alien_Idle"):
			clip = "Alien_Idle"
		elif anim.has_animation("Idle"):
			clip = "Idle"
		else:
			return
	if anim.current_animation != clip:
		anim.play(clip, 0.15)
		var a := anim.get_animation(clip)
		if a and clip in ["Idle", "Walk", "Run", "Alien_Idle", "Look", "Hanging"]:
			a.loop_mode = Animation.LOOP_LINEAR
	anim.speed_scale = speed

#endregion
