class_name Noises
extends RefCounted
## Sounds creatures can hear: gunshots, doors, footsteps, a scream. Each
## creature hears a noise within its loudness (in metres) times its hearing,
## less through walls and shut doors.

static func make(world: Node, pos: Vector3, loudness: float, from: Node = null) -> void:
	if world == null or not world.is_inside_tree():
		return
	world.get_tree().call_group("creatures", "hear", pos, loudness, from)
