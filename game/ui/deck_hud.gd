class_name DeckHud
extends Control
## The heads-up display on a deck, on the station's own dark glass: the deck
## and the time at the top left with alerts under it, what to do next at the
## top, MARI's map of the deck at the top right, the suit, infection and power
## at the bottom left, the weapon and what you carry at the bottom right, and
## the crosshair, what you can do with what you look at, subtitles and crew
## logs in the middle, and the weapon wheel while Swap is held. Over
## everything, the view flashes red and its edges stay red a while when
## you're hurt (with a mark pointing at what hit you, and the suit's number
## showing what it lost), and the Bloom's veins creep in as it takes you.
## Your own hits mark the crosshair and tick.

const TOAST_TIME := 4.5
const REPEAT_TIME := 1.5
const HURT_FADE := 1.4
const HURT_DIR_TIME := 1.6
## How long the suit shows what a blow took.
const LOSS_TIME := 1.4

var scene: Node
var player: Tech
var level: DeckLevel
var run: DeckRun
var power: Power

var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _crosshair: Control
var _title: Label
var _sub: Label
var _alerts: VBoxContainer
var _objective: Label
var _bloom_label: Label
var _bloom_bar: ProgressBar
var _map: MapView
var _map_title: Label
var _suit_bar: ProgressBar
var _suit_num: Label
var _suit_loss: Label
var _inf_row: HBoxContainer
var _inf_bar: ProgressBar
var _inf_num: Label
var _power_label: Label
var _pips := {}
var _weapon_name: Label
var _weapon_ammo: Label
var _weapon_bar: ProgressBar
var _items: Label
var _hints: HBoxContainer
var _prompts: VBoxContainer
var _pic: PlayerInteractionComponent
var _prompt_nodes: Array = []
var _subtitle: PanelContainer
var _subtitle_label: RichTextLabel
var _subtitle_t := 0.0
var _log: PanelContainer
var _log_title: Label
var _log_by: Label
var _log_text: Label
var _log_from := Vector3.ZERO
var _banner: Label
var _banner_t := 0.0
var _grab: Control
var _wheel: WeaponWheel
var _hurt := 0.0
## A moment's red over the whole view as a blow lands.
var _pulse := 0.0
var _loss := 0.0
var _loss_t := 0.0
var _spores := 0.0
var _hit_t := 0.0
var _hit_kill := false
## [direction in the view, seconds left]
var _hurt_dirs: Array = []
var _last_toast := ""
var _last_toast_at := -10.0


func _init() -> void:
	name = "DeckHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = preload("res://game/ui/overlay.gdshader")
	_overlay.material = _overlay_mat
	_overlay.visible = false
	add_child(_overlay)
	_crosshair = Control.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	add_child(_crosshair)
	_build_header()
	_build_objective()
	_build_map()
	_build_status()
	_build_weapon()
	_build_middle()
	_wheel = WeaponWheel.new()
	add_child(_wheel)


#region Building

func _build_header() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(24, 20)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var p := StationTheme.hud_panel()
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	_title = StationTheme.hud_label("DECK", 24)
	v.add_child(_title)
	_sub = StationTheme.hud_label("MARIGOLD STATION", 13, StationTheme.DIM)
	v.add_child(_sub)
	_alerts = VBoxContainer.new()
	_alerts.add_theme_constant_override("separation", 6)
	_alerts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_alerts)


func _build_objective() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position += Vector2(-200, 18)
	box.custom_minimum_size = Vector2(400, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var p := StationTheme.hud_panel(Color(StationTheme.AMBER, 0.45))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_objective = StationTheme.hud_label("", 18)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_objective)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_bloom_label = StationTheme.hud_label("BLOOM 0%", 13, StationTheme.AMBER)
	row.add_child(_bloom_label)
	_bloom_bar = StationTheme.bar(Color(0.85, 0.2, 0.1), 220, 7)
	row.add_child(_bloom_bar)


func _build_map() -> void:
	var p := StationTheme.hud_panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.position += Vector2(-24 - 300, 20)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_map_title = StationTheme.hud_label("", 13, StationTheme.DIM)
	v.add_child(_map_title)
	_map = MapView.new()
	_map.custom_minimum_size = Vector2(268, 180)
	_map.follow_scale = 18.0
	v.add_child(_map)


func _build_status() -> void:
	var p := StationTheme.hud_panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position += Vector2(24, -24)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(_fixed(StationTheme.hud_label("SUIT", 14, StationTheme.DIM), 98))
	_suit_bar = StationTheme.bar(StationTheme.GREEN, 150, 9)
	row.add_child(_suit_bar)
	_suit_num = StationTheme.hud_label("100", 16)
	row.add_child(_suit_num)
	_suit_loss = StationTheme.hud_label("", 16, StationTheme.RED)
	row.add_child(_suit_loss)
	_inf_row = HBoxContainer.new()
	_inf_row.add_theme_constant_override("separation", 10)
	v.add_child(_inf_row)
	_inf_row.add_child(_fixed(StationTheme.hud_label("BLOOM", 14, Color(0.85, 0.45, 0.7)), 98))
	_inf_bar = StationTheme.bar(Color(0.75, 0.2, 0.55), 150, 9)
	_inf_row.add_child(_inf_bar)
	_inf_num = StationTheme.hud_label("0", 16)
	_inf_row.add_child(_inf_num)
	_power_label = StationTheme.hud_label("POWER", 14, StationTheme.TEXT)
	v.add_child(_power_label)
	for k in [["lights", "LIGHTS"], ["door", "DOORS"], ["turret", "TURRETS"], ["lift", "LIFT"]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		v.add_child(r)
		r.add_child(_fixed(StationTheme.hud_label(k[1], 13, StationTheme.DIM), 98))
		var pips := StationTheme.hud_label("", 14, StationTheme.TEAL, false)
		r.add_child(pips)
		_pips[k[0]] = pips


func _build_weapon() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.position += Vector2(-24, -24)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 18)
	_hints.alignment = BoxContainer.ALIGNMENT_END
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.theme = _hint_theme()
	col.add_child(_hints)
	for h in [["action_primary", "FIRE"], ["quick_swap", "SWAP"], ["throw", "THROW"], ["power_lights", "LIGHTS"], ["power_map", "POWER"], ["heal", "MEDKIT"]]:
		var a := ActionPrompt.make(h[0], h[1], 22)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hints.add_child(a)
	var p := StationTheme.hud_panel()
	p.custom_minimum_size = Vector2(300, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_weapon_name = StationTheme.hud_label("", 20)
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_weapon_name)
	_weapon_ammo = StationTheme.hud_label("", 18, StationTheme.AMBER)
	top.add_child(_weapon_ammo)
	_weapon_bar = StationTheme.bar(StationTheme.TEAL, 260, 7)
	_weapon_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_weapon_bar)
	_items = StationTheme.hud_label("", 13, StationTheme.DIM)
	v.add_child(_items)


## Dark edges on the hints' text, so they read over the gun and lit growth.
static func _hint_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.9))
	t.set_constant("outline_size", "Label", 6)
	return t


func _build_middle() -> void:
	_prompts = VBoxContainer.new()
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompts.position += Vector2(-300, 44)
	_prompts.custom_minimum_size = Vector2(600, 0)
	_prompts.add_theme_constant_override("separation", 6)
	_prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompts)
	_subtitle = StationTheme.hud_panel()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.position += Vector2(0, -150)
	_subtitle.visible = false
	add_child(_subtitle)
	_subtitle_label = RichTextLabel.new()
	_subtitle_label.bbcode_enabled = true
	_subtitle_label.fit_content = true
	_subtitle_label.scroll_active = false
	_subtitle_label.custom_minimum_size = Vector2(640, 0)
	_subtitle_label.add_theme_font_size_override("normal_font_size", 20)
	_subtitle_label.add_theme_font_size_override("bold_font_size", 20)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_child(_subtitle_label)
	_banner = StationTheme.hud_label("", 40, StationTheme.TEAL)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position += Vector2(-500, -170)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.visible = false
	add_child(_banner)
	_grab = ActionPrompt.make("shove", "SHOVE TO BREAK FREE", 48)
	_grab.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_grab.position += Vector2(-180, 90)
	_grab.visible = false
	add_child(_grab)
	_log = PanelContainer.new()
	_log.theme_type_variation = "ScreenPanel"
	_log.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_log.visible = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_log.add_child(col)
	_log_title = Label.new()
	_log_title.theme_type_variation = "ScreenLabel"
	_log_title.add_theme_font_size_override("font_size", 28)
	col.add_child(_log_title)
	_log_by = Label.new()
	_log_by.theme_type_variation = "ScreenLabel"
	_log_by.add_theme_font_size_override("font_size", 16)
	_log_by.modulate = Color(1, 1, 1, 0.65)
	col.add_child(_log_by)
	_log_text = Label.new()
	_log_text.theme_type_variation = "ScreenLabel"
	_log_text.add_theme_font_size_override("font_size", 20)
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.custom_minimum_size = Vector2(640, 0)
	col.add_child(_log_text)
	var close := ActionPrompt.make("interact", "Close", 28)
	col.add_child(close)


func _fixed(c: Control, w: float) -> Control:
	c.custom_minimum_size.x = w
	return c

#endregion

#region Wiring

func setup(p_scene: Node, p_player: Tech, p_level: DeckLevel, p_run: DeckRun, p_power: Power) -> void:
	scene = p_scene
	player = p_player
	level = p_level
	run = p_run
	power = p_power
	_map.level = level
	_map.show_all_survivors = p_scene.mode == "campaign" and Progress.has_gift("survivors")
	_map.player = player
	var d := level.deck
	_title.text = ("DECK %d · %s" % [d.number, d.name.to_upper()]) if d and d.number > 0 else (d.name.to_upper() if d else "DECK")
	_map_title.text = "DECK %d" % d.number if d and d.number > 0 else "DECK"
	player.hurt.connect(_on_hurt)
	player.grabbed.connect(_on_grabbed)
	player.arsenal.hit_marker.connect(_on_hit_marker)
	_wheel.watch(player.arsenal)
	watch_prompts(player.player_interaction_component)


## Shows what the player can do with whatever they look at, and the short
## messages the things they use send back.
func watch_prompts(pic: PlayerInteractionComponent) -> void:
	_pic = pic
	pic.interactive_object_detected.connect(_on_object_detected)
	pic.nothing_detected.connect(_on_nothing_detected)
	pic.hint_prompt.connect(_on_hint)
	var router := get_node_or_null("/root/LGInput")
	if router:
		router.device_changed.connect(_on_device_changed)


func _on_object_detected(nodes: Array[Node]) -> void:
	_prompt_nodes = nodes
	_build_prompts()


func _on_nothing_detected() -> void:
	_prompt_nodes = []
	_build_prompts()


func _on_device_changed(_family: String) -> void:
	_build_prompts()


func _on_hint(_icon: Texture2D, text: String) -> void:
	toast(text, StationTheme.AMBER)


## The prompts showing now, as [action, text] pairs (for tests).
func prompt_lines() -> Array:
	var out := []
	if not _prompts.is_visible_in_tree():
		return out
	for c in _prompts.get_children():
		if c is ActionPrompt and not c.is_queued_for_deletion():
			out.append([c.action, c.text])
	return out


func _build_prompts() -> void:
	for c in _prompts.get_children():
		_prompts.remove_child(c)
		c.queue_free()
	if _prompt_nodes.is_empty() or _pic == null:
		return
	var thing: Node = _prompt_nodes[0].get_parent()
	var title: String = thing.get("display_name") if thing.get("display_name") else ""
	if title != "":
		var l := StationTheme.hud_label(title.to_upper(), 16, StationTheme.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompts.add_child(l)
	for node in _prompt_nodes:
		if not is_instance_valid(node) or not node is InteractionComponent:
			continue
		var ic: InteractionComponent = node
		if ic.set_disabled(_pic.get_parent()) or ic.is_disabled or ic.interaction_text == "":
			continue
		var a := ActionPrompt.make(ic.input_map_action, tr(ic.interaction_text).to_upper(), 32)
		a.alignment = BoxContainer.ALIGNMENT_CENTER
		_prompts.add_child(a)

#endregion

#region Messages

## A short alert under the deck's name that fades after a while: amber for
## what needs you, red for trouble, teal for good news.
func toast(text: String, color := StationTheme.AMBER) -> void:
	if text == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if text == _last_toast and now - _last_toast_at < REPEAT_TIME:
		return
	_last_toast = text
	_last_toast_at = now
	LGPlaytest.event("toast", {"text": text})
	var p := StationTheme.hud_panel(Color(color, 0.55))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := StationTheme.hud_label("▲ " + text.to_upper(), 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	p.add_child(l)
	p.set_meta("text", text)
	_alerts.add_child(p)
	while _alerts.get_child_count() > 4:
		var old := _alerts.get_child(0)
		_alerts.remove_child(old)
		old.queue_free()
	var t := p.create_tween()
	t.tween_interval(TOAST_TIME)
	t.tween_property(p, "modulate:a", 0.0, 0.6)
	t.tween_callback(p.queue_free)


## The alerts showing now (for tests).
func toast_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _alerts.get_children():
		if not c.is_queued_for_deletion():
			out.append(c.get_meta("text", ""))
	return out


## A line of speech at the bottom: MARI, a survivor or a log. Shown when
## subtitles are on (MARI's lines always are, since she has no voice yet).
func say(person: String, line: String, seconds := -1.0) -> void:
	if line == "":
		return
	if not LGSettings.get_value("play", "subtitles", true) and person != "MARI":
		return
	LGPlaytest.event("said", {"who": person, "text": line})
	var col := StationTheme.TEAL if person == "MARI" else StationTheme.AMBER
	_subtitle_label.text = "[b][color=#%s]%s[/color][/b]  %s" % [col.to_html(false), person.to_upper(), line]
	_subtitle.visible = true
	_subtitle_t = seconds if seconds > 0.0 else clampf(2.0 + line.length() * 0.065, 3.0, 16.0)


## Clears the subtitle, alerts and banner at once.
func hush() -> void:
	_subtitle.visible = false
	_subtitle_t = 0.0
	_banner.visible = false
	for c in _alerts.get_children():
		_alerts.remove_child(c)
		c.queue_free()


func subtitle_text() -> String:
	return _subtitle_label.get_parsed_text() if _subtitle.visible else ""


## Big words in the middle for a moment: "DECK HELD".
func banner(text: String, color := StationTheme.TEAL, seconds := 3.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_t = seconds


## A crew log on a screen. Reading the same one again, walking away or
## using anything puts it away. Returns whether it opened.
func show_log(title: String, by: String, text: String) -> bool:
	if _log.visible and _log_title.text == title:
		close_log()
		return false
	_log_title.text = title
	_log_by.text = by
	_log_by.visible = by != ""
	_log_text.text = text
	_log.visible = true
	if player:
		_log_from = player.global_position
	_log.reset_size()
	_log.position = (size - _log.size) * 0.5
	return true


func close_log() -> void:
	_log.visible = false


func log_open() -> bool:
	return _log.visible


## The weapon wheel (for tests and screenshots).
func weapon_wheel() -> WeaponWheel:
	return _wheel


## Spores in your eyes: a blur, or a tint with the Spore blur setting off.
func spores(amount: float) -> void:
	_spores = maxf(_spores, clampf(amount, 0.0, 1.0) * 1.6)

#endregion

#region Every frame

func _on_hurt(amount: float, from_dir: Vector3) -> void:
	_hurt = clampf(_hurt + 0.3 + amount / 30.0, 0.0, 1.0)
	# A Feeder's drain is a trickle: no flash for each sip.
	if from_dir != Vector3.DOWN or amount >= 3.0:
		_pulse = clampf(0.45 + amount / 30.0, 0.0, 1.0)
	_loss = (_loss if _loss_t > 0.0 else 0.0) + amount
	_loss_t = LOSS_TIME
	# `from_dir` is the way the blow travelled; the marker points back at
	# where it came from.
	if from_dir != Vector3.ZERO and absf(from_dir.normalized().y) < 0.9 and player:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var local := cam.global_transform.basis.inverse() * -from_dir
			_hurt_dirs.append([Vector2(local.x, local.z).normalized(), HURT_DIR_TIME])


func _on_grabbed(on: bool) -> void:
	_grab.visible = on


func _on_hit_marker(kill: bool) -> void:
	_hit_t = 0.3 if not kill else 0.55
	_hit_kill = kill
	Sfx.ui(self, "kill_marker" if kill else "hit_marker", -6.0 if kill else -12.0)


func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta / HURT_FADE)
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	_loss_t = maxf(0.0, _loss_t - delta)
	_spores = maxf(0.0, _spores - delta * 0.5)
	_hit_t = maxf(0.0, _hit_t - delta)
	for h in _hurt_dirs:
		h[1] -= delta
	_hurt_dirs = _hurt_dirs.filter(_dir_alive)
	if _subtitle.visible:
		_subtitle_t -= delta
		if _subtitle_t <= 0.0:
			_subtitle.visible = false
	if _banner.visible:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
		if _banner_t <= 0.0:
			_banner.visible = false
	_crosshair.queue_redraw()
	if player == null:
		return
	if _log.visible and player.global_position.distance_to(_log_from) > 1.8:
		close_log()
	var busy: bool = player.is_showing_ui or get_tree().paused
	_prompts.visible = not busy and not _log.visible and not _wheel.visible
	_update_overlay()
	_update_status()
	_update_weapon()
	_update_top()


func _dir_alive(h: Array) -> bool:
	return h[1] > 0.0


func _update_overlay() -> void:
	var blur_on: bool = LGSettings.get_value("play", "spore_blur", true)
	var low := clampf(1.0 - player.health / maxf(1.0, player.max_health), 0.0, 1.0)
	var hurt := maxf(_hurt, maxf(0.0, low - 0.55) * 1.2)
	var inf := clampf(player.infection / 100.0, 0.0, 1.0)
	var down := 1.0 if player.down() else 0.0
	_overlay_mat.set_shader_parameter("hurt", hurt)
	_overlay_mat.set_shader_parameter("pulse", _pulse)
	_overlay_mat.set_shader_parameter("infection", inf)
	_overlay_mat.set_shader_parameter("blur", minf(1.0, _spores) if blur_on else 0.0)
	_overlay_mat.set_shader_parameter("tint", minf(1.0, _spores) * (0.6 if not blur_on else 0.0))
	_overlay_mat.set_shader_parameter("down", down)
	_overlay.visible = hurt > 0.01 or _pulse > 0.01 or inf > 0.01 or _spores > 0.01 or down > 0.0


func _update_status() -> void:
	_suit_bar.value = player.health / maxf(1.0, player.max_health)
	_suit_num.text = str(ceili(player.health))
	# What the last blows took, by the number, and the number flashes red.
	_suit_loss.text = "-%d" % ceili(_loss) if _loss_t > 0.0 and _loss >= 0.5 else ""
	_suit_loss.modulate.a = clampf(_loss_t / 0.4, 0.0, 1.0)
	_suit_num.add_theme_color_override("font_color", StationTheme.TEXT.lerp(StationTheme.RED, clampf(_loss_t / LOSS_TIME * 1.5, 0.0, 1.0)))
	_inf_row.visible = player.infection > 0.5 or player.immune > 0.0
	_inf_bar.value = player.infection / 100.0
	_inf_num.text = "STIM" if player.immune > 0.0 else str(int(player.infection))
	if power:
		_power_label.text = "POWER   %d CELLS · %d FREE" % [power.cells, power.free_cells()]
		_pips["lights"].text = _pip_text(power.count("lights"))
		_pips["door"].text = _pip_text(power.count("door"))
		_pips["turret"].text = _pip_text(power.count("turret"))
		_pips["lift"].text = _pip_text(power.count("lift"))


static func _pip_text(n: int) -> String:
	return "■ ".repeat(n).strip_edges() if n > 0 else "—"


func _update_weapon() -> void:
	var a := player.arsenal
	if a == null:
		return
	var spec: Dictionary = Arsenal.WEAPONS.get(a.current, {})
	_weapon_name.text = String(spec.get("name", a.current)).to_upper()
	_weapon_ammo.text = a.ammo_text().to_upper()
	if a.current == "cutter":
		_weapon_bar.value = a.heat / Arsenal.OVERHEAT
		_weapon_bar.add_theme_stylebox_override("fill", StationTheme.box(StationTheme.RED if a.overheated else StationTheme.TEAL.lerp(StationTheme.AMBER, a.heat / Arsenal.OVERHEAT), Color(0, 0, 0, 0), 0, 2))
	else:
		var st := a.stat(a.current)
		_weapon_bar.value = float(a.mag.get(a.current, 0)) / maxf(1.0, float(st.get("mag", 1)))
		_weapon_bar.add_theme_stylebox_override("fill", StationTheme.box(StationTheme.AMBER if a.reloading > 0.0 else StationTheme.TEAL, Color(0, 0, 0, 0), 0, 2))
	var parts := PackedStringArray()
	for t in Arsenal.THROWABLES:
		var n := int(player.items.get(t, 0))
		var label := "%s %d" % [t.to_upper(), n]
		parts.append(("[%s]" % label) if t == a.throwable else label)
	parts.append("MEDKIT %d" % int(player.items.get("medkit", 0)))
	parts.append("STIM %d" % int(player.items.get("stim", 0)))
	_items.text = "  ".join(parts)


func _update_top() -> void:
	if run:
		var t := int(run.time)
		var hour := Progress.hour() if level.deck and level.deck.id in Decks.ORDER else 0
		_sub.text = "MARIGOLD STATION · NIGHT SHIFT · HOUR %d · %02d:%02d" % [hour + 1, t / 60, t % 60]
		var objs: Array = run.objectives(level.bloom)
		var next := ""
		for o in objs:
			if not o[1]:
				next = o[0]
				break
		if next == "":
			next = "Take the lift" if not objs.is_empty() else ""
		_objective.text = next.to_upper()
	if level and level.bloom:
		var cov := level.bloom.coverage()
		_bloom_label.text = "BLOOM %d%%" % roundi(cov * 100.0)
		_bloom_bar.value = cov
		_map_title.text = "%s   ·   BLOOM %d%%" % [_title.text, roundi(cov * 100.0)]


func _draw_crosshair() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.8)
	var ring := 0.45
	if player and player.arsenal and player.arsenal.current == "cutter":
		# The ring lights up when the beam would touch what's under it, and
		# fades when that's out of the cutter's reach.
		col = Color(0.55, 0.95, 1.0, 0.85)
		ring = 0.8 if player.arsenal.beam_reaches else 0.15
	_crosshair.draw_circle(c, 2.0, col)
	_crosshair.draw_arc(c, 11.0, 0, TAU, 32, Color(col, ring), 2.0 if ring > 0.5 else 1.5, true)
	if _hit_t > 0.0:
		var hc := Color(1.0, 0.25, 0.15) if _hit_kill else Color(1, 1, 1)
		hc.a = clampf(_hit_t * 4.0, 0.0, 1.0)
		var long := 24.0 if _hit_kill else 19.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_crosshair.draw_line(c + d * 7.0, c + d * long, Color(0, 0, 0, hc.a * 0.6), 5.5, true)
			_crosshair.draw_line(c + d * 7.0, c + d * long, hc, 3.0, true)
	for h in _hurt_dirs:
		var dir: Vector2 = h[0]
		var ang := atan2(dir.y, dir.x)
		_crosshair.draw_arc(c, 150.0, ang - 0.45, ang + 0.45, 20, Color(1.0, 0.15, 0.1, clampf(h[1], 0.0, 1.0)), 10.0, true)

#endregion
