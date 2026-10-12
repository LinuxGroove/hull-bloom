class_name Feeder
extends Creature
## Hangs from the ceiling trailing tendrils. Walk under one and it lifts you
## and drains you until you shove free, cut the tendril, freeze it or kill it.

const GRAB_RANGE := 2.0
const DRAIN := 9.0
const INFECT := 5.0
const SHOVES := 3
const TENDRIL_HP := 25.0

var grabbing := false
var _shoves := 0
var _tendril_hp := TENDRIL_HP
var _regrab := 0.0
var _tendrils: Array[MeshInstance3D] = []
var _grab_line: MeshInstance3D
var _grab_box: Area3D


func configure() -> void:
	kind = "feeder"
	max_health = 110.0
	walk_speed = 0.5
	run_speed = 0.8
	damage = 0.0
	reach = 0.0
	sight_range = 10.0
	sight_cone = -1.0
	radius = 0.6
	height = 1.2
	flies = true
	gib_count = 7
	gib_look = "feeder"
	resist = {Hit.Kind.FREEZE: 1.3}


func build() -> void:
	# Hangs: its top against the ceiling.
	var m := load_model("Alien_Paciforix", 3.4, "feeder", true)
	m.position.y += 0.0
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.6
	add_hitbox(cap, Transform3D(Basis(), Vector3(0, -1.3, 0)))
	_capsule.disabled = true
	collision_layer = 0
	for i in 3:
		var t := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.02
		c.height = 2.0
		t.mesh = c
		t.material_override = Flesh.material("feeder")
		t.position = Vector3(randf_range(-0.4, 0.4), -3.2, randf_range(-0.4, 0.4))
		add_child(t)
		_tendrils.append(t)
		meshes.append(t)
	_grab_line = MeshInstance3D.new()
	var gl := CylinderMesh.new()
	gl.top_radius = 0.07
	gl.bottom_radius = 0.05
	gl.height = 1.0
	_grab_line.mesh = gl
	_grab_line.material_override = Flesh.material("feeder")
	_grab_line.visible = false
	add_child(_grab_line)
	meshes.append(_grab_line)
	_grab_box = add_hitbox(SphereShape3D.new(), Transform3D(), "tendril")
	(_grab_box.get_child(0) as CollisionShape3D).shape.radius = 0.25
	_grab_box.collision_layer = 0


func _floor_y() -> float:
	return 0.0


func setup(lvl: DeckLevel, at: Vector3, asleep := false) -> void:
	# The ceiling over its spot.
	super(lvl, Vector3(at.x, Kit.HEIGHT - 0.05, at.z), asleep)
	hover = Kit.HEIGHT - 0.05


func think(delta: float) -> void:
	for i in _tendrils.size():
		var t := _tendrils[i]
		t.rotation.x = sin(time * 0.9 + i * 2.0) * 0.12
		t.rotation.z = cos(time * 0.7 + i) * 0.12
	velocity = Vector3.ZERO
	if not is_instance_valid(target):
		return
	if grabbing:
		_hold(delta)
		return
	_regrab -= delta
	var to := target.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	if _regrab <= 0.0 and flat < GRAB_RANGE and not target.down():
		_grab()
	elif state == State.HUNT and flat < 6.0:
		# Creeps along the ceiling after you.
		var d := Vector3(to.x, 0, to.z).normalized()
		velocity = d * walk_speed


func _move(delta: float) -> void:
	global_position.y = hover
	global_position += Vector3(velocity.x, 0, velocity.z) * delta


func _grab() -> void:
	if not target.has_method("grab"):
		return
	if not target.grab(self):
		return
	grabbing = true
	_shoves = 0
	_tendril_hp = TENDRIL_HP
	_grab_line.visible = true
	_grab_box.collision_layer = Kit.LAYER_HITBOX
	Sfx.at(self, "feeder_grab", global_position + Vector3(0, -2, 0))
	Noises.make(self, global_position, 14.0, self)


func _hold(delta: float) -> void:
	if not is_instance_valid(target) or target.down():
		release(false)
		return
	var chest: Vector3 = target.chest_position()
	var top := global_position + Vector3(0, -2.6, 0)
	var mid := (top + chest) * 0.5
	var length := top.distance_to(chest)
	_grab_line.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, (top - chest).normalized())), mid)
	_grab_line.scale = Vector3(1, maxf(0.1, length), 1)
	_grab_box.global_position = mid
	target.drain(DRAIN * delta, INFECT * delta)


## Shoved: enough shoves and it lets go.
func shoved() -> void:
	if not grabbing:
		return
	_shoves += 1
	stunned = 0.3
	_flash = 1.0
	if _shoves >= SHOVES:
		release(true)


func release(hurt := true) -> void:
	if not grabbing:
		return
	grabbing = false
	_grab_line.visible = false
	_grab_box.collision_layer = 0
	_regrab = 4.0 if hurt else 2.0
	if is_instance_valid(target) and target.has_method("ungrab"):
		target.ungrab(self)


func limb_hit(hit: Hit) -> void:
	if hit.limb != "tendril" or not grabbing:
		return
	_tendril_hp -= hit.amount * (2.5 if hit.kind == Hit.Kind.FREEZE else 1.0)
	if _tendril_hp <= 0.0:
		Gore.spray(self, _grab_box.global_position, Vector3.DOWN, 1.2, bleeds)
		release(true)
		_regrab = 8.0


func take_hit(hit: Hit) -> void:
	# A hit on the tendril doesn't hurt the body much.
	if hit.limb == "tendril":
		limb_hit(hit)
		_flash = 1.0
		return
	super(hit)


func die(hit: Hit) -> void:
	release(false)
	super(hit)


## Frozen solid, it can't hold on.
func freeze_solid() -> void:
	release(true)
	super()


func death(hit: Hit) -> void:
	Sfx.at(self, "gib", global_position + Vector3(0, -1.5, 0))
	Gore.gibs(self, global_position + Vector3(0, -1.8, 0), gib_count, gib_look, 3.0 + hit.knock, bleeds)
	Gore.pool(self, Vector3(global_position.x, 0.02, global_position.z), 2.0, bleeds)
	queue_free()
