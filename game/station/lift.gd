class_name Lift
extends Node3D
## The deck's lift: a pad on the lift tile and a console against its wall.
## You arrive on it, and leave from it once it has a power cell. The deck's
## run decides what using it does ([signal used]).

signal used

const PAD := "Prop_Teleporter"
const CONSOLE := "ess:Prop_Computer"
## The pad's top.
const TOP := 0.28

var level: DeckLevel
var console: UsableBody
var powered := false
var _ring: OmniLight3D
var _glow: MeshInstance3D


static func make(lvl: DeckLevel) -> Lift:
	var l := Lift.new()
	l.name = "Lift"
	l.level = lvl
	l.position = DeckLevel.center(lvl.lift_cell)
	l._build()
	return l


func _build() -> void:
	# The kit's pad is 0.8 m tall and wider than a tile: squashed to a low
	# step that fits.
	var pad := Kit.model(self, PAD, Vector3.ZERO)
	pad.scale = Vector3(0.8, 0.35, 0.8)
	Kit.block(self, Vector3(0, TOP * 0.5, 0), Vector3(3.5, TOP, 3.5))
	var back := Vector3(DeckLevel.STEP[level.lift_side].x, 0, DeckLevel.STEP[level.lift_side].y)
	console = UsableBody.new()
	console.name = "Console"
	console.display_name = "Lift"
	add_child(console)
	console.position = back * 1.45
	# The screen faces into the room.
	console.rotation.y = atan2(-back.x, -back.z)
	var m := Kit.model(console, CONSOLE, Vector3.ZERO)
	m.rotation.y = PI
	console.add_box(Vector3(0, 0.8, 0), Vector3(0.8, 1.6, 0.6))
	console.add_action("interact", "Power the lift", _use)
	_glow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.6
	disc.height = 0.02
	_glow.mesh = disc
	_glow.position = Vector3(0, TOP + 0.01, 0)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_ring = OmniLight3D.new()
	_ring.position = Vector3(0, 1.4, 0)
	_ring.omni_range = 6.0
	_ring.light_energy = 0.0
	add_child(_ring)
	set_powered(false)


func set_powered(on: bool) -> void:
	powered = on
	var c := Color(0.3, 0.85, 1.0) if on else Color(0.5, 0.12, 0.08)
	_glow.material_override = Kit.flat(Color(c, 0.35), 0.3, c, 1.6 if on else 0.4)
	_ring.light_color = c
	_ring.light_energy = 1.4 if on else 0.25
	console.set_action_text("interact", "Leave the deck" if on else "Power the lift (1 cell)")


func _use(_pic: Node) -> void:
	used.emit()
