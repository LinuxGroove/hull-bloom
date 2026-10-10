class_name PlaySettings
extends VBoxContainer
## Hull Bloom's own settings, for the pause menu and the title's settings:
## looking and crouching, the comfort settings, the Gore setting (with its
## parental lock) and the difficulty switches. Each change is saved at once.

const LOOK := [[0.15, "Slow"], [0.25, "Normal"], [0.35, "Quick"], [0.5, "Fast"]]
const BOB := [[0.0, "Off"], [0.5, "Gentle"], [1.0, "Full"]]
const FOV := [[65.0, "Narrow"], [75.0, "Normal"], [90.0, "Wide"]]
const BRIGHT := [[0.85, "Darker"], [1.0, "Normal"], [1.25, "Brighter"], [1.5, "Brightest"]]
const CALM := [[1.0, "Off"], [0.4, "Slow"], [0.0, "Still"]]
const GORE := [["full", "Full"], ["less", "Less"], ["off", "Off"]]
const SPREAD := [[0.75, "Slow"], [1.0, "Normal"], [1.3, "Fast"]]
const DAMAGE := [[0.6, "Light"], [1.0, "Normal"], [1.4, "Heavy"]]
const AMMO := [[1.4, "Plenty"], [1.0, "Normal"], [0.7, "Scarce"]]

signal changed

var width := 480
## Where the code keypad opens (the menu's own root).
var popup_parent: Control
var _code: CodePanel
var _locking := false


static func make(p_width := 480) -> PlaySettings:
	var p := PlaySettings.new()
	p.width = p_width
	p.add_theme_constant_override("separation", 8)
	p.rebuild()
	return p


func rebuild() -> void:
	for c in get_children():
		if c != _code:
			remove_child(c)
			c.queue_free()
	_head("Looking")
	add_child(LGCycler.make("Look speed", LOOK, _nearest(LOOK, LGSettings.get_value("play", "mouse_sensitivity")), _on_set.bind("play", "mouse_sensitivity"), width))
	add_child(LGCycler.make("Invert look", SettingsPanel.ON_OFF, LGSettings.get_value("play", "invert_look"), _on_set.bind("play", "invert_look"), width))
	add_child(LGCycler.make("Hold to crouch", [[false, "On"], [true, "Off"]], LGSettings.get_value("play", "toggle_crouch"), _on_set.bind("play", "toggle_crouch"), width))
	_head("Comfort")
	add_child(LGCycler.make("Head bob", BOB, LGSettings.get_value("play", "bob"), _on_set.bind("play", "bob"), width))
	add_child(LGCycler.make("View roll", SettingsPanel.ON_OFF, LGSettings.get_value("play", "tilt"), _on_set.bind("play", "tilt"), width))
	add_child(LGCycler.make("Field of view", FOV, LGSettings.get_value("play", "fov"), _on_set.bind("play", "fov"), width))
	add_child(LGCycler.make("Brightness", BRIGHT, _nearest(BRIGHT, LGSettings.get_value("play", "brightness", 1.0)), _on_set.bind("play", "brightness"), width))
	add_child(LGCycler.make("Calm walls", CALM, LGSettings.get_value("play", "calm_walls"), _on_set.bind("play", "calm_walls"), width))
	add_child(LGCycler.make("Spore blur", SettingsPanel.ON_OFF, LGSettings.get_value("play", "spore_blur"), _on_set.bind("play", "spore_blur"), width))
	add_child(LGCycler.make("Rumble", SettingsPanel.ON_OFF, LGSettings.get_value("play", "rumble"), _on_set.bind("play", "rumble"), width))
	add_child(LGCycler.make("Subtitles", SettingsPanel.ON_OFF, LGSettings.get_value("play", "subtitles"), _on_set.bind("play", "subtitles"), width))
	_head("Gore")
	var locked := locked()
	var gore := LGCycler.make("Gore", GORE, LGSettings.get_value("gore", "level"), _on_set.bind("gore", "level"), width)
	gore.set_read_only(locked)
	add_child(gore)
	add_child(LGUi.button("Unlock the gore setting" if locked else "Lock the gore setting", _ask_code, width))
	_head("Difficulty")
	add_child(LGCycler.make("Bloom spread", SPREAD, _nearest(SPREAD, LGSettings.get_value("difficulty", "spread")), _on_set.bind("difficulty", "spread"), width))
	add_child(LGCycler.make("Damage taken", DAMAGE, _nearest(DAMAGE, LGSettings.get_value("difficulty", "damage")), _on_set.bind("difficulty", "damage"), width))
	add_child(LGCycler.make("Ammunition", AMMO, _nearest(AMMO, LGSettings.get_value("difficulty", "ammo")), _on_set.bind("difficulty", "ammo"), width))


static func locked() -> bool:
	return String(LGSettings.get_value("gore", "lock", "")) != ""


func _head(text: String) -> void:
	var l := LGUi.label(text.to_upper(), "DimLabel")
	l.add_theme_color_override("font_color", StationTheme.AMBER)
	add_child(l)


## The option nearest a stored value, so odd values still show.
static func _nearest(options: Array, v: Variant) -> Variant:
	var best: Variant = options[0][0]
	var d := INF
	for o in options:
		var dd := absf(float(o[0]) - float(v))
		if dd < d:
			d = dd
			best = o[0]
	return best


func _on_set(value: Variant, section: String, key: String) -> void:
	LGSettings.set_value(section, key, value)
	if key == "calm_walls":
		RenderingServer.global_shader_parameter_set("calm_walls", float(value))
	elif key == "brightness" and DeckScene.current and DeckScene.current.world_env:
		DeckScene.light(DeckScene.current.world_env.environment, DeckScene.current.hub)
	changed.emit()


func _ask_code() -> void:
	if _code == null:
		_code = CodePanel.new()
		_code.entered.connect(_on_code)
		_code.cancelled.connect(_on_code_cancelled)
		(popup_parent if popup_parent else self).add_child(_code)
	_locking = not locked()
	_code.ask("Choose a code to lock it" if _locking else "Enter the code to unlock it")


func _on_code(code: String) -> void:
	if _locking:
		LGSettings.set_value("gore", "lock", code)
	elif code == String(LGSettings.get_value("gore", "lock", "")):
		LGSettings.set_value("gore", "lock", "")
	rebuild()
	_focus_first.call_deferred()


func _on_code_cancelled() -> void:
	_focus_first.call_deferred()


## Focuses the first control once the rebuild has settled (several rebuilds
## in a frame would leave an earlier pick out of the tree).
func _focus_first() -> void:
	var c := LGUi.first_focusable(self)
	if c and c.is_inside_tree():
		c.grab_focus()
