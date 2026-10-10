class_name Grenade
extends RigidBody3D
## A grenade for packs: it bounces, then blows.

const FUSE := 1.8
const RADIUS := 5.5
const DAMAGE := 130.0

var from: Node = null
var _fuse := FUSE


func _init() -> void:
	collision_layer = Kit.LAYER_GIBS
	collision_mask = Kit.LAYER_SOLID | Kit.LAYER_GLASS | Kit.LAYER_CREATURES
	mass = 0.5
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.35
	var m := Kit.model(self, "ess:Prop_Grenade", Vector3.ZERO)
	m.scale = Vector3.ONE * 1.2
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.1
	cs.shape = s
	add_child(cs)


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		Effects.blast(self, global_position, RADIUS, DAMAGE, from)
		queue_free()
