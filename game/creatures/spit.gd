class_name Spit
extends Node3D
## A glob of the Bloom, spat by a Watcher or a heart: it arcs, splashes, and
## burns a little and infects where it lands.

var velocity := Vector3.ZERO
var damage := 6.0
var infect := 6.0
var from: Node = null
var _life := 4.0


func _ready() -> void:
	var m := MeshInstance3D.new()
	m.mesh = Flesh.lump_mesh(0.09, 1)
	m.material_override = Flesh.material("pod")
	add_child(m)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= 6.0 * delta
	var next := global_position + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, next, Kit.LAYER_SOLID | Kit.LAYER_GLASS | Kit.LAYER_PLAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var n: Node = hit.collider
		if n and n.is_in_group("tech"):
			var h := Hit.make(Hit.Kind.SPIT, damage, hit.position, velocity, from)
			n.take_hit(h)
			if n.has_method("drain"):
				n.drain(0.0, infect)
		else:
			Gore.splat(self, hit.position, hit.normal, 0.6, "bloom")
		Sfx.at(self, "splat", hit.position, -6.0)
		queue_free()
		return
	global_position = next
