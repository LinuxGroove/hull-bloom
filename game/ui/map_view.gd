class_name MapView
extends Control
## The deck drawn from above, as MARI's sensors see it: each tile coloured by
## how far the Bloom has grown on it, the doors (open, shut, sealed, locked
## or airless), the lift, the roots MARI reads as "organic obstruction", the
## survivors found, and you. The HUD's corner map follows you; the deck map
## shows the whole deck with the rooms' names.

const CLEAN := Color(0.12, 0.3, 0.26, 0.85)
const LIT := Color(0.18, 0.42, 0.38, 0.9)
const AIRLESS := Color(0.12, 0.14, 0.2, 0.9)
const GROWN_LOW := Color(0.9, 0.55, 0.15, 0.9)
const GROWN_HIGH := Color(0.75, 0.08, 0.06, 0.95)

var level: DeckLevel
var player: Node3D
## Follow the player at this many pixels a tile (corner map), or fit the
## whole deck when 0.
var follow_scale := 0.0
var show_names := false
## The room picked on the deck map, outlined.
var picked := ""

var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


## Pixels per tile and the offset that places tile (0,0).
func _frame() -> Array:
	var b := level.bounds()
	if follow_scale > 0.0:
		var s := follow_scale
		var at := Vector2.ZERO
		if is_instance_valid(player):
			at = Vector2(player.global_position.x, player.global_position.z) / Kit.TILE
		return [s, size * 0.5 - at * s]
	var s := minf((size.x - 20.0) / maxf(1.0, b.size.x), (size.y - 20.0) / maxf(1.0, b.size.y))
	var used := Vector2(b.size) * s
	var off := (size - used) * 0.5 - Vector2(b.position) * s + Vector2(s, s) * 0.5
	return [s, off]


## The tile under a point of this control (for picking rooms on the map).
func cell_at_point(p: Vector2) -> Vector2i:
	var f := _frame()
	var s: float = f[0]
	var t: Vector2 = (p - f[1]) / s
	return Vector2i(roundi(t.x), roundi(t.y))


func _draw() -> void:
	if level == null or level.bloom == null:
		return
	var f := _frame()
	var s: float = f[0]
	var off: Vector2 = f[1]
	var bloom := level.bloom
	var gap := maxf(1.0, s * 0.06)
	for i in bloom.cells.size():
		var c: Vector2i = bloom.cells[i]
		var p := off + Vector2(c) * s
		var g := bloom.growth[i]
		var col := LIT if bloom.room_lit[bloom.room[i]] == 1 else CLEAN
		if bloom.airless[bloom.room[i]] == 1:
			col = AIRLESS
		elif g > 0.05:
			var t := clampf(g / Bloom.MAX, 0.0, 1.0)
			col = GROWN_LOW.lerp(GROWN_HIGH, t)
			col.a = 0.55 + 0.4 * minf(1.0, g)
		var r := Rect2(p - Vector2(s, s) * 0.5 + Vector2(gap, gap) * 0.5, Vector2(s, s) - Vector2(gap, gap))
		draw_rect(r, col)
		# Room edges.
		for side in DeckLevel.SIDE_ORDER:
			var n: Vector2i = c + DeckLevel.STEP[side]
			if level.tiles.get(n, "") == level.tiles[c]:
				continue
			var d := Vector2(DeckLevel.STEP[side])
			var mid := p + d * s * 0.5
			var along := Vector2(-d.y, d.x) * s * 0.5
			var edge_col := Color(0.6, 0.85, 0.9, 0.55)
			if level.tiles[c] == picked:
				edge_col = StationTheme.AMBER
			draw_line(mid - along, mid + along, edge_col, maxf(1.0, s * 0.05))
	# Doors.
	for key in level.doors:
		var d: Bulkhead = level.doors[key]
		var a := off + Vector2(d.a) * s
		var b := off + Vector2(d.b) * s
		var mid := (a + b) * 0.5
		var along := Vector2(-(b - a).y, (b - a).x).normalized() * s * 0.3
		var col := Bulkhead.LAMP_OPEN if d.is_open else Bulkhead.LAMP_SHUT
		if d.sealed or d.airless:
			col = Bulkhead.LAMP_SEALED
		elif d.locked != "":
			col = Bulkhead.LAMP_LOCKED
		draw_line(mid - along, mid + along, col, maxf(2.0, s * 0.16))
	# The lift.
	var lp := off + Vector2(level.lift_cell) * s
	draw_circle(lp, s * 0.28, Color(0.3, 0.85, 1.0, 0.85), false, maxf(1.5, s * 0.07))
	# Roots: MARI's "organic obstruction", pulsing.
	for i in bloom.roots.size():
		if bloom.root_alive[i] == 0:
			continue
		var rp := off + Vector2(bloom.cells[bloom.roots[i]]) * s
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(rp, s * (0.2 + 0.08 * pulse), Color(1.0, 0.15, 0.1, 0.9))
		draw_circle(rp, s * (0.36 + 0.1 * pulse), Color(1.0, 0.2, 0.1, 0.5), false, maxf(1.0, s * 0.05))
	# Survivors you've found.
	for sv in get_tree().get_nodes_in_group("survivors"):
		var su := sv as Survivor
		if su and su.is_found:
			var sp := off + Vector2(su.global_position.x, su.global_position.z) / Kit.TILE * s
			draw_circle(sp, maxf(2.5, s * 0.12), StationTheme.GREEN)
	if show_names:
		var font := LGTheme.heading_font if LGTheme.heading_font else get_theme_default_font()
		for id in level.room_ids:
			var cells: Array = level.rooms[id]["cells"]
			var sum := Vector2.ZERO
			for c in cells:
				sum += Vector2(c)
			var at := off + sum / cells.size() * s
			var text := level.room_name(id).to_upper()
			var fs := clampi(int(s * 0.22), 10, 16)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, at + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
			draw_string(font, at + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, StationTheme.TEXT)
	# You.
	if is_instance_valid(player):
		var pp := off + Vector2(player.global_position.x, player.global_position.z) / Kit.TILE * s
		var fwd := -player.global_transform.basis.z
		var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
		if cam:
			fwd = -cam.global_transform.basis.z
		var dir := Vector2(fwd.x, fwd.z).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(0, -1)
		var side := Vector2(-dir.y, dir.x)
		var k := maxf(7.0, s * 0.32)
		var pts := PackedVector2Array([pp + dir * k, pp - dir * k * 0.6 + side * k * 0.6, pp - dir * k * 0.25, pp - dir * k * 0.6 - side * k * 0.6])
		draw_colored_polygon(pts, Color(0.55, 0.9, 1.0))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.5)
