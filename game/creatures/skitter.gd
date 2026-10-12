class_name Skitter
extends Creature
## Small, fast and never alone: the Bloom's spawn, hatched from pods and
## crawling out of the vents. They leap the last few metres.

const LEAP_FROM := 4.5
const LEAP_TIME := 2.4

var _leap_t := 0.0
var _leaping := false
## Whether this leap has landed its blow (a leap hits once).
var _leap_hit := false


func configure() -> void:
	kind = "skitter"
	max_health = 16.0
	walk_speed = 2.2
	# A little slower than the Tech's sprint, so you can get away and aim.
	run_speed = 5.4
	turn_rate = 12.0
	damage = 6.0
	reach = 1.2
	attack_time = 0.8
	strike_at = 0.25
	sight_range = 16.0
	sight_cone = -0.2
	hearing = 1.2
	uses_vents = true
	radius = 0.32
	height = 0.7
	gib_count = 3
	gib_look = "skitter"
	resist = {Hit.Kind.FREEZE: 1.6}
	pinnable = true


func build() -> void:
	load_model("Alien_Cephalocorax", 0.8 + randf() * 0.15, "skitter")
	body_hitbox(0.36, 0.75)


func think(delta: float) -> void:
	if _leaping:
		if is_on_floor() and velocity.y <= 0.0:
			_leaping = false
		return
	if state == State.HUNT and is_instance_valid(target) and time > _leap_t and is_on_floor():
		var to := target.global_position - global_position
		var d := Vector2(to.x, to.z).length()
		if d < LEAP_FROM and d > 2.0 and time - last_seen < 0.3:
			_leap_t = time + LEAP_TIME + randf()
			_leaping = true
			_leap_hit = false
			var flat := Vector3(to.x, 0, to.z).normalized()
			velocity = flat * 7.5 + Vector3(0, 4.2, 0)
			face(target.global_position, 1.0)
			_attack_t = 0.0
			Sfx.at(self, "skitter_leap", global_position, -4.0)
			return
	super(delta)


func _physics_process(delta: float) -> void:
	super(delta)
	if _leaping and is_instance_valid(target) and not dead and frozen <= 0.0:
		if not _leap_hit and global_position.distance_to(target.global_position + Vector3(0, 0.8, 0)) < 1.2 and in_reach():
			_leap_hit = true
			strike()
	if model and not dead:
		# A scuttling bob as it runs.
		var sp := Vector2(velocity.x, velocity.z).length()
		model.rotation.x = sin(time * 22.0) * 0.06 * minf(sp, 1.0)


func attack_anim() -> void:
	if model:
		var t := create_tween()
		t.tween_property(model, "position:z", 0.35, 0.12)
		t.tween_property(model, "position:z", 0.0, 0.25)
