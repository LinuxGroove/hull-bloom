class_name MenuBackdrop
extends Node3D
## What the menus show behind them: a deck, grown over and lit only by its
## emergency lights, with the camera drifting slowly between the level's
## views; or just space, the planet below and the stars. The camera only
## drifts, never cuts or shakes.

const DRIFT_TIME := 26.0
const FADE := 2.5

var level: DeckLevel
var camera: Camera3D
var _views: Array = []
var _view_i := 0
var _t := 0.0
var _fade: ColorRect


## A deck's backdrop (`deck_id` "" for space only). `grow` ticks of the Bloom
## run first so the deck looks taken.
static func make(deck_id := "hydroponics", grow := 160) -> MenuBackdrop:
	var b := MenuBackdrop.new()
	b.name = "Backdrop"
	b._build(deck_id, grow)
	return b


func _build(deck_id: String, grow: int) -> void:
	var env := WorldEnvironment.new()
	env.environment = DeckScene.make_environment(false)
	add_child(env)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.current = true
	# It drifts every frame, not on the physics tick.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	# A suit lamp: enough light on the growth to see it's wet.
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.93, 0.82)
	lamp.light_energy = 2.2
	lamp.spot_range = 16.0
	lamp.spot_angle = 34.0
	lamp.spot_attenuation = 1.2
	lamp.shadow_enabled = true
	lamp.position = Vector3(0.25, -0.2, 0.0)
	camera.add_child(lamp)
	if deck_id == "" or not Decks.has(deck_id):
		# Out of a window: the planet below, the stars beyond.
		env.environment.fog_enabled = false
		camera.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(-40.0), 0.0)
		return
	level = Decks.make_level(deck_id, true)
	var b := level.make_bloom()
	b.advance(grow)
	add_child(level)
	level.finish()
	var view := BloomView.make(level)
	add_child(view)
	view.snap()
	# A few of the decks' things for company: the roots, and pods on them.
	for c in level.root_cells:
		var h := Heart.make(level, c)
		level.add_child(h)
	# Views with room ahead of them, so the drift never stares at a wall.
	for v in level.views:
		if _open_ahead(level.views[v]) >= 2:
			_views.append(level.views[v])
	if _views.is_empty():
		for v in level.views:
			_views.append(level.views[v])
	_views.shuffle()
	_place(0.0)


func _process(delta: float) -> void:
	if _views.is_empty():
		camera.rotation.y += delta * 0.004
		return
	_t += delta
	if _t >= DRIFT_TIME:
		_t = 0.0
		_view_i = (_view_i + 1) % _views.size()
	_place(_t / DRIFT_TIME)


## How many tiles you can walk straight on from a view, up to four.
func _open_ahead(v: Array) -> int:
	var yaw := deg_to_rad(float(v[1]))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var step := Vector2i(signi(roundi(fwd.x * 2.0)), 0) if absf(fwd.x) > absf(fwd.z) else Vector2i(0, signi(roundi(fwd.z * 2.0)))
	var c := DeckLevel.cell_at(Vector3(v[0]))
	var n := 0
	while n < 4 and level.walkable(c, c + step):
		c += step
		n += 1
	return n


## Drifts the camera forward through the current view, turning a little.
func _place(f: float) -> void:
	var v: Array = _views[_view_i]
	var yaw := deg_to_rad(float(v[1]))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	camera.position = Vector3(v[0]) + fwd * (f - 0.5) * 2.4
	camera.rotation = Vector3(deg_to_rad(float(v[2])), yaw + (f - 0.5) * 0.12, 0.0)
	# Fades through black between views rather than cutting.
	if _fade:
		var edge := minf(_t, DRIFT_TIME - _t)
		_fade.color.a = clampf(1.0 - edge / FADE, 0.0, 1.0)


## A full-screen black the backdrop fades through between views; put it
## under the menu's own controls.
func fade_rect() -> ColorRect:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _fade
