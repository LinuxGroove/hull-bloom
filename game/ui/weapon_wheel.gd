class_name WeaponWheel
extends Control
## The weapon wheel, while Swap is held: the weapons you carry round a ring in
## the middle of the screen, in slot order clockwise from the top, each with
## its number and name. What the right stick or the mouse points at lights up
## teal, and letting go of Swap takes it (see [Arsenal]). Time doesn't stop.

const OUTER := 220.0
const INNER := 64.0
## How far out the names sit.
const LABELS := 146.0
const BACK := Color(0.02, 0.03, 0.04, 0.66)

var arsenal: Arsenal

## weapon -> [box, number label, name label]
var _items := {}
var _shown: Array[String] = []


func _init() -> void:
	name = "WeaponWheel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func watch(a: Arsenal) -> void:
	arsenal = a
	arsenal.wheel_changed.connect(_on_wheel_changed)
	_on_wheel_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_place()


func _on_wheel_changed() -> void:
	visible = arsenal != null and arsenal.wheel_open
	if not visible:
		return
	if _shown != arsenal.owned:
		_build()
	for w in _items:
		var name_label: Label = _items[w][2]
		var col := StationTheme.TEAL if w == arsenal.wheel_pick else (StationTheme.TEXT if w == arsenal.current else StationTheme.DIM)
		name_label.add_theme_color_override("font_color", col)
		(_items[w][1] as Label).add_theme_color_override("font_color", Color(col, 0.75))
	_place()
	queue_redraw()


## The names on the wheel now, as "number name" (for tests).
func item_texts() -> Array:
	var out := []
	for w in _shown:
		out.append("%s %s" % [(_items[w][1] as Label).text, (_items[w][2] as Label).text])
	return out


func _build() -> void:
	for w in _items:
		_items[w][0].queue_free()
	_items.clear()
	_shown = arsenal.owned.duplicate()
	for w in _shown:
		var spec: Dictionary = Arsenal.WEAPONS[w]
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := StationTheme.hud_label(str(int(spec["slot"])), 15, StationTheme.DIM)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(num)
		var label := StationTheme.hud_label(String(spec["name"]).to_upper(), 19)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		add_child(box)
		_items[w] = [box, num, label]


func _place() -> void:
	var c := size * 0.5
	for w in _items:
		var box: Control = _items[w][0]
		box.reset_size()
		box.position = c + arsenal.wheel_direction(w) * LABELS - box.size * 0.5


func _draw() -> void:
	if arsenal == null or not arsenal.wheel_open or _shown.is_empty():
		return
	var c := size * 0.5
	var n := _shown.size()
	var seg := TAU / n
	draw_circle(c, OUTER, BACK)
	if arsenal.wheel_pick != "":
		# The wheel's angles go clockwise from the top; draw_arc's from the right.
		var mid := _shown.find(arsenal.wheel_pick) * seg - PI * 0.5
		_sector(c, mid - seg * 0.5, mid + seg * 0.5, Color(StationTheme.TEAL, 0.2))
		draw_arc(c, OUTER - 2.0, mid - seg * 0.5, mid + seg * 0.5, 32, StationTheme.TEAL, 4.0, true)
		var d := Vector2(cos(mid), sin(mid))
		draw_circle(c + d * (INNER - 12.0), 5.0, StationTheme.TEAL)
	if n > 1:
		for i in n:
			var a := (i + 0.5) * seg - PI * 0.5
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * INNER, c + d * OUTER, Color(StationTheme.EDGE, 0.5), 1.0, true)
	draw_arc(c, OUTER, 0.0, TAU, 96, StationTheme.EDGE, 1.5, true)
	draw_arc(c, INNER, 0.0, TAU, 64, Color(StationTheme.EDGE, 0.5), 1.0, true)


## A slice of the ring between two angles.
func _sector(c: Vector2, from: float, to: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * OUTER)
	for i in steps + 1:
		var a := lerpf(to, from, float(i) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * INNER)
	draw_colored_polygon(pts, col)
