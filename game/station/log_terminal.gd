class_name LogTerminal
extends UsableBody
## A crew log: a terminal on a desk, a datapad on the floor, or a recorder.
## Reading it opens the log on screen and remembers it for the campaign.

signal read(log: LogTerminal)

var log_id := ""
var title := ""
var text := ""
var by := ""
var style := "pad"
var _screen: MeshInstance3D


static func make(opts: Dictionary) -> LogTerminal:
	var t := LogTerminal.new()
	t.log_id = String(opts.get("id", ""))
	t.name = "Log_" + t.log_id
	t.title = String(opts.get("title", "Log"))
	t.text = String(opts.get("text", ""))
	t.by = String(opts.get("by", ""))
	t.style = String(opts.get("style", "pad"))
	t._build()
	return t


func _build() -> void:
	display_name = title
	collision_layer = Kit.LAYER_STATION | Kit.LAYER_INTERACT
	match style:
		"terminal":
			Kit.model(self, "ess:Prop_Computer", Vector3.ZERO)
			add_box(Vector3(0, 0.8, 0), Vector3(0.74, 1.6, 0.56))
			_screen = _glow_quad(Vector2(0.5, 0.32), Vector3(0, 1.28, 0.2))
		"screen":
			Kit.model(self, "ess:Prop_Screen", Vector3.ZERO)
			add_box(Vector3(0, 0.3, 0), Vector3(0.74, 0.6, 0.4))
			_screen = _glow_quad(Vector2(0.5, 0.3), Vector3(0, 0.33, 0.06))
		_:
			# A datapad: a thin slab with a lit face.
			var pad := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.24, 0.02, 0.32)
			pad.mesh = b
			pad.material_override = Kit.flat(Color(0.08, 0.09, 0.1), 0.4)
			pad.position.y = 0.01
			add_child(pad)
			_screen = _glow_quad(Vector2(0.2, 0.26), Vector3(0, 0.022, 0))
			_screen.rotation.x = -PI * 0.5
			add_box(Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5))
			collision_layer = Kit.LAYER_INTERACT
	add_action("interact", "Read: " + title, _read)
	set_read(Progress.has_read(log_id))


func _glow_quad(size: Vector2, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func set_read(was_read: bool) -> void:
	var c := Color(0.25, 0.8, 0.95) if not was_read else Color(0.2, 0.35, 0.4)
	_screen.material_override = Kit.flat(c * 0.3, 0.3, c, 2.0 if not was_read else 0.6)


func _read(_pic: Node) -> void:
	Progress.read_log(log_id)
	set_read(true)
	read.emit(self)
