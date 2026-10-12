class_name Stalker
extends Creature
## A skitter grown to three metres. It hunts by sound: it barely sees, but it
## hears gunfire across the deck and footsteps through a wall. Its big claws
## snap off in the sprayer's focused jet, or to a rail round.

const CLAWS := {"claw_l": "ClawBig_1.L", "claw_r": "ClawBig_1.R"}

var _claw_hp := {"claw_l": 40.0, "claw_r": 40.0}


func configure() -> void:
	kind = "stalker"
	max_health = 170.0
	walk_speed = 1.3
	run_speed = 4.6
	turn_rate = 5.0
	damage = 22.0
	reach = 2.3
	attack_time = 1.5
	strike_at = 0.55
	sight_range = 9.0
	sight_cone = 0.5
	hearing = 1.8
	opens_doors = true
	radius = 0.7
	height = 2.6
	gib_count = 9
	resist = {Hit.Kind.PELLET: 0.8}
	salvage = 0


func build() -> void:
	load_model("Alien_Cephalocorax", 2.6, "alien")
	body_hitbox(0.75, 2.4)
	for limb in CLAWS:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.12
		cap.height = 0.9
		add_hitbox(cap, Transform3D(Basis(), Vector3(0, 0.4, 0)), limb, CLAWS[limb])


## Footsteps carry: crouching halves what it hears.
func hear(pos: Vector3, loudness: float, from: Node) -> void:
	super(pos, loudness, from)


func limb_hit(hit: Hit) -> void:
	if not _claw_hp.has(hit.limb):
		return
	var cut := hit.amount * hit.sever * (2.0 if hit.kind in [Hit.Kind.FREEZE, Hit.Kind.RAIL] else 0.6)
	_claw_hp[hit.limb] -= cut
	if _claw_hp[hit.limb] <= 0.0 and skeleton and hider:
		_claw_hp.erase(hit.limb)
		Gore.sever(self, skeleton, hider, CLAWS[hit.limb], hit.dir, bleeds)
		damage *= 0.6
		reach -= 0.3
		stunned = 0.6
		state = State.HURT


func attack_anim() -> void:
	if model:
		var t := create_tween()
		t.tween_property(model, "rotation:x", 0.35, 0.3)
		t.tween_property(model, "rotation:x", 0.0, 0.5)


func death(hit: Hit) -> void:
	Sfx.at(self, "stalker_die", global_position + Vector3(0, 1.5, 0))
	Gore.gibs(self, global_position + Vector3(0, 1.4, 0), gib_count, gib_look, 5.0 + hit.knock, bleeds)
	Gore.pool(self, global_position + Vector3(0, 0.02, 0), 2.6, bleeds)
	queue_free()
