class_name Mine
extends RigidBody3D
## A mine for doorways: it lands, arms, and goes off when something walks
## near it.

const ARM := 1.5
const TRIGGER := 2.2
const RADIUS := 4.5
const DAMAGE := 150.0

var from: Node = null
var _arm := ARM
var _armed := false
var _lamp: MeshInstance3D
var _check := 0.0


func _init() -> void:
	collision_layer = Kit.LAYER_GIBS
	collision_mask = Kit.LAYER_SOLID | Kit.LAYER_GLASS
	mass = 1.0
	continuous_cd = true
	var m := Kit.model(self, "ess:Prop_Mine", Vector3.ZERO)
	m.scale = Vector3.ONE * 0.4
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.16
	s.height = 0.1
	cs.shape = s
	add_child(cs)
	_lamp = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.025
	sp.height = 0.05
	_lamp.mesh = sp
	_lamp.position.y = 0.14
	_lamp.material_override = Kit.flat(Color(0.3, 0.1, 0.0), 0.3, Color(1.0, 0.6, 0.1), 2.0)
	add_child(_lamp)


func _physics_process(delta: float) -> void:
	if not _armed:
		_arm -= delta
		if _arm <= 0.0:
			_armed = true
			freeze = true
			Sfx.at(self, "mine_arm", global_position, -6.0)
			_lamp.material_override = Kit.flat(Color(0.3, 0.0, 0.0), 0.3, Color(1.0, 0.05, 0.02), 3.0)
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.1
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Creature and not c.dead and c.global_position.distance_to(global_position) < TRIGGER + c.radius:
			Effects.blast(self, global_position + Vector3(0, 0.3, 0), RADIUS, DAMAGE, from)
			queue_free()
			return


## Shot or caught in a blast: it goes off.
func take_hit(_hit: Hit) -> void:
	Effects.blast(self, global_position + Vector3(0, 0.3, 0), RADIUS, DAMAGE, from)
	queue_free()
