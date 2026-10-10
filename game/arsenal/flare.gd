class_name Flare
extends RigidBody3D
## A flare: a red light that burns where it lands. Lit tiles grow at half
## speed, so a flare in a doorway slows the Bloom for a while.

const BURN := 55.0

var from: Node = null
var _life := BURN
var _light: OmniLight3D
var _cell := Vector2i(99999, 99999)
var _report := 0.0


func _init() -> void:
	collision_layer = Kit.LAYER_GIBS
	collision_mask = Kit.LAYER_SOLID | Kit.LAYER_GLASS
	mass = 0.3
	continuous_cd = true
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.025
	c.height = 0.26
	m.mesh = c
	m.material_override = Kit.flat(Color(0.7, 0.1, 0.06), 0.6, Color(1.0, 0.2, 0.08), 2.0)
	m.rotation.z = PI * 0.5
	add_child(m)
	var cs := CollisionShape3D.new()
	var s := CapsuleShape3D.new()
	s.radius = 0.03
	s.height = 0.26
	cs.shape = s
	cs.rotation.z = PI * 0.5
	add_child(cs)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.25, 0.12)
	_light.light_energy = 2.2
	_light.omni_range = 7.5
	_light.shadow_enabled = false
	add_child(_light)
	add_to_group("flares")


func _ready() -> void:
	Sfx.at(self, "flare", global_position, -6.0)


func _physics_process(delta: float) -> void:
	_life -= delta
	_light.light_energy = 2.2 * clampf(_life / 6.0, 0.0, 1.0) * (0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.03))
	if _life <= 0.0:
		queue_free()
		return
	# Tell the Bloom which tile is lit, now and then.
	_report -= delta
	if _report <= 0.0:
		_report = 2.0
		var c := DeckLevel.cell_at(global_position)
		if DeckScene.current and DeckScene.current.level and DeckScene.current.level.bloom:
			DeckScene.current.level.bloom.add_flare(c, minf(_life, 3.0))
		_cell = c
