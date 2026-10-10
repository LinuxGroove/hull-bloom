class_name Taken
extends Creature
## The crew, taken by the Bloom: still in their coveralls, still walking
## fragments of their old routines, the growth bursting out of their backs.
## They come apart. The cutter's focused beam, the scattergun up close, the
## rail and blasts take limbs off: without arms they can only bite, without a
## leg they crawl, and without a head they keep coming, blind. Only the body
## going down stops them.

## Limb -> its first bone.
const LIMBS := {"arm_l": "upperarm_l", "arm_r": "upperarm_r", "leg_l": "thigh_l", "leg_r": "thigh_r", "head": "Head"}
const LIMB_HP := 26.0

var job := "tech"
## The crew member's looks (a body getting up keeps its own).
var female := randf() < 0.45
var look_seed := randi()
var crew: Crew
## Tiles it walks between when nothing's happening, from its old job.
var routine: Array = []
var rising := false
var crawling := false
var _limb_hp := {}
var _routine_i := 0
var _rise_t := 0.0


func configure() -> void:
	kind = "taken"
	max_health = 85.0
	walk_speed = 0.9
	run_speed = 2.4
	turn_rate = 4.0
	damage = 14.0
	reach = 1.5
	attack_time = 1.4
	strike_at = 0.6
	sight_range = 15.0
	sight_cone = 0.3
	hearing = 1.1
	opens_doors = true
	radius = 0.35
	height = 1.75
	bleeds = "blood"
	gib_count = 6
	for l in LIMBS:
		_limb_hp[l] = LIMB_HP


func build() -> void:
	crew = Crew.make(job, female, look_seed)
	model = crew
	add_child(crew)
	skeleton = crew.skeleton
	anim = crew.anim
	meshes = crew.meshes.duplicate()
	crew.set_instance("dead", 1.0)
	crew.set_instance("blood", randf_range(0.45, 0.85))
	crew.set_instance("bloom", randf_range(0.55, 0.9))
	hider = LimbHider.new()
	skeleton.add_child(hider)
	_add_growths()
	# Hitboxes on the bones.
	var torso := BoxShape3D.new()
	torso.size = Vector3(0.42, 0.62, 0.28)
	add_hitbox(torso, Transform3D(Basis(), Vector3(0, 0.12, 0)), "", "spine_02")
	var head := SphereShape3D.new()
	head.radius = 0.13
	add_hitbox(head, Transform3D(Basis(), Vector3(0, 0.1, 0.02)), "head", "Head")
	for side in ["l", "r"]:
		var upper := CapsuleShape3D.new()
		upper.radius = 0.07
		upper.height = 0.55
		add_hitbox(upper, Transform3D(Basis(), Vector3(0, 0.25, 0)), "arm_" + side, "upperarm_" + side)
		var lower := CapsuleShape3D.new()
		lower.radius = 0.06
		lower.height = 0.5
		add_hitbox(lower, Transform3D(Basis(), Vector3(0, 0.22, 0)), "arm_" + side, "lowerarm_" + side)
		var thigh := CapsuleShape3D.new()
		thigh.radius = 0.09
		thigh.height = 0.5
		add_hitbox(thigh, Transform3D(Basis(), Vector3(0, 0.22, 0)), "leg_" + side, "thigh_" + side)
		var calf := CapsuleShape3D.new()
		calf.radius = 0.07
		calf.height = 0.5
		add_hitbox(calf, Transform3D(Basis(), Vector3(0, 0.22, 0)), "leg_" + side, "calf_" + side)


## Clusters of the Bloom bursting from the back and shoulders.
func _add_growths() -> void:
	for spec in [["spine_03", Vector3(0, 0.1, -0.14), 0.16], ["spine_02", Vector3(0.08, 0.0, -0.13), 0.12],
			["clavicle_l", Vector3(0, 0.05, -0.05), 0.1], ["spine_03", Vector3(-0.1, 0.18, -0.1), 0.09]]:
		if randf() < 0.25:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = spec[0]
		skeleton.add_child(att)
		var m := MeshInstance3D.new()
		m.mesh = Flesh.lump_mesh(spec[2] * randf_range(0.8, 1.3), randi())
		m.material_override = Flesh.material("lump")
		m.position = spec[1]
		att.add_child(m)
		meshes.append(m)


func setup(lvl: DeckLevel, at: Vector3, asleep := false) -> void:
	super(lvl, at, asleep)
	if level and routine.is_empty():
		var room: String = level.tiles.get(DeckLevel.cell_at(at), "")
		if room != "":
			for c in level.rooms[room]["cells"]:
				routine.append(c)


## Gets up off the floor as one of the Taken.
func rise() -> void:
	rising = true
	_rise_t = crew.clip_length("LayToIdle")
	crew.play("LayToIdle", 0.0, 1.0, true)
	Sfx.at(self, "taken_rise", global_position)


func think(delta: float) -> void:
	if rising:
		_rise_t -= delta
		velocity = Vector3(0, velocity.y, 0)
		if _rise_t <= 0.0:
			rising = false
			state = State.HUNT if is_instance_valid(target) and _can_see_target() else State.WANDER
		return
	super(delta)


func wander_spot() -> Vector3:
	if routine.is_empty():
		return super()
	_routine_i = (_routine_i + 1 + randi() % 2) % routine.size()
	return DeckLevel.center(routine[_routine_i]) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))


func idle_anim() -> void:
	if crawling:
		crew.play("Swim_Idle")
	else:
		crew.play("Zombie_Idle")


func move_anim(speed: float) -> void:
	if crawling:
		crew.play("Swim_Fwd", -1.0, 0.8)
	else:
		crew.play("Zombie_Walk_Fwd", -1.0, 1.0 if speed <= walk_speed + 0.1 else 1.6)
		crew.anim.speed_scale = 1.0 if speed <= walk_speed + 0.1 else 1.6


func attack_anim() -> void:
	if crawling:
		return
	crew.play("Zombie_Scratch", 0.1, 1.0, true)


func hurt_anim() -> void:
	if not crawling:
		crew.play("Hit_Chest", 0.05, 1.0, true)


func strike() -> void:
	if not _has("arm_l") and not _has("arm_r"):
		damage = 8.0
	super()


func _has(limb: String) -> bool:
	return _limb_hp.has(limb)


func limb_hit(hit: Hit) -> void:
	if not _limb_hp.has(hit.limb):
		return
	var cut := hit.amount * hit.sever
	match hit.kind:
		Hit.Kind.BURN:
			cut *= 1.6
		Hit.Kind.PELLET, Hit.Kind.RAIL, Hit.Kind.BLAST:
			cut *= 1.3
		_:
			cut *= 0.35
	_limb_hp[hit.limb] -= cut
	# The body takes less from a hit that lands on a limb.
	health += hit.amount * 0.4
	if _limb_hp[hit.limb] <= 0.0:
		_cut(hit.limb, hit.dir)


func _cut(limb: String, dir: Vector3) -> void:
	_limb_hp.erase(limb)
	var flying := Gore.sever(self, skeleton, hider, LIMBS[limb], dir, bleeds)
	if not Gore.full():
		# Less gore: nothing comes off, it just slows.
		hider._hidden.erase(skeleton.find_bone(LIMBS[limb]))
	if flying == null and Gore.full():
		return
	drop_hitboxes(limb)
	Sfx.at(self, "sever", global_position + Vector3(0, 1.2, 0))
	if limb.begins_with("leg") and not crawling:
		crawling = true
		walk_speed = 0.5
		run_speed = 0.9
		reach = 1.1
		height = 0.6
		crew.rotation.x = deg_to_rad(80)
		crew.position = Vector3(0, 0.25, 0.55)
		(_capsule.shape as CapsuleShape3D).height = 0.7
		_capsule.position.y = 0.35
	elif limb == "head":
		sight_range = 2.5
		hearing *= 1.3
	stunned = 0.6
	state = State.HURT


func death(hit: Hit) -> void:
	Sfx.at(self, "taken_die", global_position + Vector3(0, 1.0, 0))
	if hit.kind == Hit.Kind.BLAST and Gore.full():
		Gore.gibs(self, global_position + Vector3(0, 1.0, 0), 8, "gib", 6.0, bleeds)
		queue_free()
		return
	if crawling:
		crew.play("Swim_Idle")
		crew.anim.pause()
	else:
		crew.play("Death01", 0.1, 1.0, true)
	Gore.pool(self, global_position + Vector3(0, 0.02, 0), 1.8, bleeds)
	collision_layer = 0
	_capsule.disabled = true
	# The body stays a while, then goes.
	var t := get_tree().create_timer(40.0)
	t.timeout.connect(queue_free)
