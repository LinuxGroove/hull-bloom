class_name VentPanel
extends UsableBody
## The emergency vent for a room: opens it to space. Every tile in it goes
## back to bare metal and everything inside dies, but the room stays airless
## for good and its doors shut. It won't vent with you inside.

signal vent_asked(panel: VentPanel)

const CONFIRM_TIME := 3.0

var room_id := ""
var level: DeckLevel
var used := false
var _confirm := 0.0
var _lamp: MeshInstance3D


static func make(lvl: DeckLevel, room: String) -> VentPanel:
	var v := VentPanel.new()
	v.name = "Vent_" + room
	v.level = lvl
	v.room_id = room
	v.add_to_group("vent_panels")
	v._build()
	return v


func _build() -> void:
	collision_layer = Kit.LAYER_INTERACT
	var rname := level.room_name(room_id) if level else room_id
	display_name = "Emergency vent"
	Kit.model(self, "Prop_AccessPoint_Short", Vector3.ZERO)
	add_box(Vector3(0, 1.35, 0), Vector3(0.45, 0.5, 0.7))
	_lamp = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.12)
	_lamp.mesh = q
	_lamp.position = Vector3(0.23, 1.62, 0)
	_lamp.rotation.y = PI * 0.5
	add_child(_lamp)
	add_action("interact", "Vent the %s" % rname.to_lower(), _use)
	_refresh()


func _process(delta: float) -> void:
	if _confirm > 0.0:
		_confirm -= delta
		if _confirm <= 0.0:
			_refresh()


func _use(pic: Node) -> void:
	if used:
		return
	if _confirm <= 0.0:
		_confirm = CONFIRM_TIME
		UsableBody.hint(pic, "Use it again to vent. Everything inside dies.")
		Sfx.at(self, "alarm", global_position, -6.0)
		_refresh()
		return
	_confirm = 0.0
	vent_asked.emit(self)


## Called once the room is vented.
func mark_used() -> void:
	used = true
	_refresh()


func _refresh() -> void:
	var c := Color(0.3, 0.3, 0.3) if used else (Color(1.0, 0.1, 0.05) if _confirm > 0.0 else Color(1.0, 0.65, 0.1))
	_lamp.material_override = Kit.flat(c * 0.3, 0.3, c, 2.5)
	var rname := level.room_name(room_id).to_lower() if level else room_id
	var text := "Vent the %s" % rname
	if used:
		text = "Vented"
	elif _confirm > 0.0:
		text = "Confirm: vent the %s" % rname
	set_action_text("interact", text)
