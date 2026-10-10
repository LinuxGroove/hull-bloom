class_name EndingScreen
extends Node
## How the night shift ends, once the Core is held. With Cargo's shuttle
## fuelled you choose: take it home with the survivors, or stay with the
## station. Without it you stay. Hold every deck and you get both: the
## survivors go home and you stay to finish the job.

const WIDTH := 640
const ENDINGS := {
	"shuttle": ["THE SHUTTLE", [
		"You take the shuttle. The survivors fill the seats you don't, and nobody says much.",
		"Marigold turns below you, lights on in the decks you held and dark in the ones you didn't. Something on the dark decks is still growing. It has nothing left to feed it. Probably.",
		"Your suit radio picks up MARI one last time: \"Organic obstruction reported on all decks. Night shift, please investigate.\"",
	]],
	"burn": ["THE NIGHT SHIFT", [
		"You stay. With the Heart burnt out, the growth has nothing feeding it, and it dies back a deck at a time while you burn what's left.",
		"It takes weeks. The decks you lost stay sealed; you don't go in, and MARI stops asking you to.",
		"Forty days later a relief ship docks at Cargo. You meet it at the lift with the cutter on your back. MARI logs the time, and notes the obstruction as cleared.",
	]],
	"both": ["MARIGOLD HOLDS", [
		"Every deck held. The shuttle takes the survivors home, and you stay to burn out the last of it.",
		"The grow rooms are planted again by the time the relief ship docks. Somebody starts a rota for the night shift. Your name is at the top.",
		"MARI's report to the colonies is three words long: \"Obstruction cleared. Investigating.\"",
	]],
}

var backdrop: MenuBackdrop
var ending := ""
var _ui: Control
var _col: VBoxContainer


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	backdrop = MenuBackdrop.make("")
	add_child(backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)
	_col = LGUi.centered_column(_ui, WIDTH)
	LGScreenFit.center(_col)
	Sfx.play_music(["ending", "title"], -8.0)
	var e := which()
	if e == "":
		show_choice()
	else:
		show_ending(e)


## The ending the shift has earned, or "" when you get to choose.
static func which() -> String:
	var shuttle := Progress.deck_state("cargo") in ["saved", "reclaimed"]
	var all_held := true
	for m in Decks.MIDDLE:
		if Decks.has(m) and not Progress.deck_state(m) in ["saved", "reclaimed"]:
			all_held = false
	if shuttle and all_held:
		return "both"
	return "" if shuttle else "burn"


func _clear() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()


func _text(text: String, color := StationTheme.TEXT, delay := 0.0) -> Label:
	var l := LGUi.label(text)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	_col.add_child(l)
	if delay > 0.0:
		l.modulate.a = 0.0
		var t := l.create_tween()
		t.tween_interval(delay)
		t.tween_property(l, "modulate:a", 1.0, 1.2)
	return l


func show_choice() -> void:
	_clear()
	_col.add_child(StationTheme.hud_label("THE HEART IS BURNT", 40, StationTheme.TEAL))
	_text("The growth on the Core is dying back. At Cargo's dock the shuttle is fuelled, and the survivors are waiting by it.")
	_text("MARI asks whether she should prepare it for launch.", StationTheme.DIM)
	_col.add_child(LGUi.button("Take the shuttle home", show_ending.bind("shuttle"), WIDTH))
	_col.add_child(LGUi.button("Stay with Marigold", show_ending.bind("burn"), WIDTH))
	LGUi.focus_first(_col)


func show_ending(e: String) -> void:
	ending = e
	var first := Progress.endings_seen().is_empty()
	Progress.set_ending(e)
	_clear()
	_col.add_child(StationTheme.hud_label(ENDINGS[e][0], 44, StationTheme.TEAL if e != "shuttle" else StationTheme.AMBER))
	var delay := 0.6
	for p in ENDINGS[e][1]:
		_text(p, StationTheme.TEXT, delay)
		delay += 2.2
	var held := Progress.held_decks().size()
	var lost := Progress.lost_count() - _reclaimed()
	_text("Decks held: %d    Decks lost: %d    Survivors brought out: %d    Hours: %d" % [held, lost, Progress.total_survivors(), Progress.hour()], StationTheme.DIM, delay)
	if first:
		_text("Shift mode is open now, on the title screen.", StationTheme.AMBER, delay + 0.8)
	var b := LGUi.button("Back to the title", _to_title, WIDTH)
	_col.add_child(b)
	LGUi.focus_first(_col)


func _reclaimed() -> int:
	var n := 0
	for id in Decks.ids():
		if Progress.deck_state(id) == "reclaimed":
			n += 1
	return n


## The labels of the buttons showing now (for tests).
func button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _col.find_children("", "Button", true, false):
		if not b.is_queued_for_deletion():
			out.append(b.text)
	return out


func _to_title() -> void:
	LGScenes.change_scene(DeckScene.TITLE)
