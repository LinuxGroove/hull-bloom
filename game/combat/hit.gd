class_name Hit
extends RefCounted
## One blow: a bullet, a rivet, the sprayer's cold, a blast, a claw. Anything that
## can be hurt has `take_hit(hit: Hit)`; creatures, the player, pods and the
## hearts all take the same thing.

enum Kind {BULLET, PELLET, FREEZE, BLAST, CLAW, SHOVE, RAIL, SPIT, RIVET}

var kind := Kind.BULLET
var amount := 10.0
var point := Vector3.ZERO
var normal := Vector3.UP
## Which way the blow travels.
var dir := Vector3.FORWARD
## Who struck it (the player, a creature, a turret), or null.
var from: Node = null
## The limb a shot landed on ("arm_l", "leg_r", "head", ""), from its hitbox.
var limb := ""
## How hard it pushes (metres a second).
var knock := 0.0
## How much more a limb comes off from this (the rail, the scattergun up close).
var sever := 1.0


static func make(kind_: Kind, amount_: float, point_: Vector3, dir_: Vector3, from_: Node = null) -> Hit:
	var h := Hit.new()
	h.kind = kind_
	h.amount = amount_
	h.point = point_
	h.dir = dir_.normalized() if dir_.length() > 0.0 else Vector3.FORWARD
	h.from = from_
	h.normal = -h.dir
	return h


func by_player() -> bool:
	return from != null and from.is_in_group("tech")


## The thing a collider belongs to: hitboxes point at their owner.
static func owner_of(collider: Object) -> Node:
	if collider == null:
		return null
	if collider.has_meta("owner"):
		var o: Object = collider.get_meta("owner")
		return o as Node if is_instance_valid(o) else null
	return collider as Node


## Hurts whatever a collider belongs to, if it can be hurt.
static func deal(collider: Object, hit: Hit) -> Node:
	var o := owner_of(collider)
	if o == null:
		return null
	if collider.has_meta("limb"):
		hit.limb = String(collider.get_meta("limb"))
	if o.has_method("take_hit"):
		o.take_hit(hit)
		return o
	return null
