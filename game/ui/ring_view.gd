class_name RingView
extends Control
## Marigold from above: the seven decks round the ring, the Core in the
## middle, the feeds between them, each deck in its state's colour with the
## hours an open deck has left as an arc round it.

var selected := ""
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## A deck's state in a word or two, for the list.
static func state_word(id: String) -> String:
	match Progress.deck_state(id):
		"open":
			var h := Progress.hours_left(id)
			return "open" if h <= 0 else ("%d hour left" % h if h == 1 else "%d hours left" % h)
		"saved":
			return "saved"
		"lost":
			return "lost"
		"reclaimed":
			return "taken back"
	return "locked"


static func state_color(id: String) -> Color:
	match Progress.deck_state(id):
		"open":
			return StationTheme.RED if Progress.hours_left(id) == 1 else StationTheme.AMBER
		"saved", "reclaimed":
			return StationTheme.TEAL
		"lost":
			return StationTheme.RED
	return StationTheme.DIM


## Where a deck sits, in this control's space.
func deck_point(id: String) -> Vector2:
	var c := size * 0.5
	if id == "core":
		return c
	var r := minf(size.x, size.y) * 0.4
	var ring_ids: Array = Decks.ORDER.filter(func(d): return d != "core")
	var i := ring_ids.find(id)
	var a := -PI * 0.5 + TAU * float(i) / ring_ids.size()
	return c + Vector2(cos(a), sin(a)) * r


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.4
	var font := LGTheme.heading_font if LGTheme.heading_font else get_theme_default_font()
	var node_r := clampf(r * 0.16, 16.0, 30.0)
	# The ring itself and the feeds to the Core.
	draw_arc(c, r, 0.0, TAU, 96, Color(StationTheme.EDGE, 0.5), 3.0, true)
	for id in Decks.ids():
		if id == "core":
			continue
		var p := deck_point(id)
		var lost := Progress.deck_state(id) in ["lost"]
		draw_line(p.lerp(c, node_r / r), c.lerp(p, node_r * 1.4 / r), Color(StationTheme.RED, 0.5) if lost else Color(StationTheme.EDGE, 0.3), 2.0, true)
	for id in Decks.ids():
		var p := deck_point(id)
		var col := state_color(id)
		var rad := node_r * (1.35 if id == "core" else 1.0)
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(p, rad, Color(0.03, 0.04, 0.05, 0.92))
		draw_circle(p, rad, col, false, 3.0, true)
		if Progress.deck_state(id) in ["lost"]:
			draw_circle(p, rad * 0.6, Color(StationTheme.RED, 0.35 + 0.2 * pulse))
		if Progress.deck_state(id) == "open" and Decks.get_deck(id).hours > 0:
			var f := float(Progress.hours_left(id)) / float(Decks.get_deck(id).hours + 1)
			draw_arc(p, rad + 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(f, 0.0, 1.0), 48, col, 4.0, true)
		if id == selected:
			draw_arc(p, rad + 13.0 + pulse * 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 2.0, true)
		var num := str(Decks.get_deck(id).number)
		var fs := int(rad * 0.9)
		var tw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, p + Vector2(-tw.x * 0.5, fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var name := Decks.get_deck(id).name.to_upper()
		var ns := 13
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns)
		var below := p + Vector2(-nw.x * 0.5, rad + 24.0)
		draw_string(font, below, name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(col, 0.9))
