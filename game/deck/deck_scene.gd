class_name DeckScene
extends Node3D
## One visit to a deck: builds the level, the Bloom's look, the director and
## the tech, ticks the Bloom, routes the deck's power cells, and ends when you
## leave by the lift or go down. [method play] starts one; whoever starts it
## sets [member deck_id] (and the rest) before it enters the tree.
##
## A saved deck is a hub: its lights are on, the Bloom is gone, and its
## workbench and bunk work. A lost deck comes back overgrown.

const TECH := preload("res://game/player/tech.tscn")
const SCENE := "res://game/deck/deck_scene.tscn"
const RING := "res://game/ui/ring_map.tscn"
const TITLE := "res://game/ui/title.tscn"
## Bloom ticks for each hour of the shift a deck waits for you.
const TICKS_PER_HOUR := 10
## Seconds of the Bloom's growth during a visit before it's quiet.
const LEAVE_CONFIRM := 4.0

static var current: DeckScene

## Set before entering the tree.
var deck_id := "hydroponics"
## "campaign", "shift" (a Shift night; [member night] runs it) or "test".
var mode := "campaign"
## A deck made outside Decks (Shift mode), with its level's script.
var custom_deck: DeckDef
var custom_level: GDScript
var night: RefCounted
## For tests and screenshots: no music, no captured mouse.
var quiet := false

var deck: DeckDef
var level: DeckLevel
var player: Tech
var run: DeckRun
var power: Power
var director: Director
var bloom_view: BloomView
var lift: Lift
var hud: DeckHud
var pause: BloomPause
var map_panel: DeckMapPanel
var results: ResultsPanel
var workbench: WorkbenchPanel
var world_env: WorldEnvironment
var hub := false
var overgrown := false
var ui: CanvasLayer

var _tick := 0.0
var _leave_confirm := 0.0
var _down_t := -1.0
var _fade: ColorRect
var _hum: AudioStreamPlayer
var _wet: AudioStreamPlayer
var _hunted_t := 0.0
var _music := ""


## Starts a deck: Progress decides whether it's a hub or overgrown.
static func play(id: String, opts := {}) -> void:
	LGScenes.change_scene(SCENE, func(scene: Node) -> void:
		scene.deck_id = id
		for k in opts:
			scene.set(k, opts[k]))


func _ready() -> void:
	current = self
	deck = custom_deck if custom_deck else Decks.get_deck(deck_id)
	deck_id = deck.id
	if mode == "campaign":
		var st := Progress.deck_state(deck.id)
		hub = st in ["saved", "reclaimed"]
		overgrown = st == "lost"
	run = DeckRun.new(deck)
	_build_environment()
	_build_level()
	_build_power()
	_build_ui()
	_build_player()
	director = Director.new()
	director.setup(level)
	add_child(director)
	director.heart_killed.connect(_on_heart_killed)
	director.creature_died.connect(_on_creature_died)
	if not hub:
		director.start()
	run.roots = level.root_cells.size() if not hub else 0
	bloom_view = BloomView.make(level)
	add_child(bloom_view)
	_wire_things()
	hud.setup(self, player, level, run, power)
	map_panel.setup(self, level, power, run, player)
	if hub:
		run.held = true
		for id in level.room_ids:
			if not level.rooms[id]["dark"]:
				_set_lights(id, true)
		lift.set_powered(true)
		hud.say("MARI", "Deck %d is safe. The workbench and the bunk are working." % deck.number)
	elif deck.arrive != "":
		hud.say("MARI", deck.arrive if not overgrown else "Deck %d is overgrown. Organic obstruction everywhere. I'm sorry." % deck.number)
	if not quiet:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_play_music("calm")
		_hum = _ambience("hum_loop", -22.0)
		_wet = _ambience("bloom_loop", -60.0)


func _exit_tree() -> void:
	if current == self:
		current = null


#region Building

## The sky outside Marigold: stars, a nebula and the planet below.
static func space_sky() -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/world/space.gdshader")
	sky.sky_material = mat
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	return sky


func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.environment = make_environment(hub)
	add_child(world_env)


## The station's light: dark but for its own lamps, with space outside the
## windows. Brighter on a held deck.
static func make_environment(bright := false) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = space_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.44)
	env.ambient_light_energy = 0.45 if bright else 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.035, 0.04)
	env.fog_density = 0.018
	return env


func _build_level() -> void:
	var script: GDScript = custom_level if custom_level else load(deck.level_path())
	level = script.new()
	level.name = "Level"
	level.deck = deck
	level.overgrown = overgrown
	level.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	level.build()
	var b := level.make_bloom()
	b.speed = spread()
	if hub:
		for i in b.cells.size():
			b.growth[i] = 0.0
		for k in b.root_alive.size():
			b.root_alive[k] = 0
		b.pods.clear()
	elif mode == "campaign" and not overgrown and deck.hours > 0:
		# The hours the deck waited for you, grown in one go.
		var waited := deck.hours - Progress.hours_left(deck.id) + (1 if Progress.has_spare_cell(deck.id) else 0)
		b.advance(maxi(0, waited) * TICKS_PER_HOUR)
	add_child(level)
	level.finish()
	lift = level.get_node("Lift")


func _build_power() -> void:
	var cells := deck.cells
	if mode == "campaign":
		if Progress.has_gift("power") and deck.id != "engineering":
			cells += 1
		if Progress.has_spare_cell(deck.id):
			cells += 1
	power = Power.new(cells)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	hud = DeckHud.new()
	ui.add_child(hud)
	map_panel = DeckMapPanel.new()
	ui.add_child(map_panel)
	workbench = WorkbenchPanel.new()
	workbench.on_bought = _on_upgrade
	ui.add_child(workbench)
	pause = BloomPause.new()
	pause.set_leave_text("Leave the deck" if mode != "shift" else "End the night")
	pause.leave_deck.connect(_on_leave_from_menu)
	pause.quit_to_title.connect(_on_quit)
	ui.add_child(pause)
	results = ResultsPanel.new()
	ui.add_child(results)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)


func _build_player() -> void:
	player = TECH.instantiate()
	player.bloom_pause = pause
	player.level = level
	add_child(player)
	player.global_transform = level.start_transform()
	player.reset_physics_interpolation()
	if mode == "campaign":
		var kit := Progress.loadout()
		# Medical's gift: its stores top up your stims and medkits.
		if Progress.has_gift("stims"):
			var items: Dictionary = kit["items"]
			items["stim"] = maxi(int(items.get("stim", 0)), 2)
			items["medkit"] = maxi(int(items.get("medkit", 0)), 2)
		player.load_kit(kit)
	elif night and night.has_method("kit"):
		player.load_kit(night.kit())
	else:
		player.load_kit({"weapons": Progress.START_WEAPONS, "items": Progress.START_ITEMS, "ammo": {}})
	player.died.connect(_on_player_died)


## Hooks the level's things up to the deck: doors and turrets to the power,
## the lift, vents, logs, survivors and the hub's workbench and bunk.
func _wire_things() -> void:
	for key in level.doors:
		var d: Bulkhead = level.doors[key]
		d.power = _cell_for.bind("door:" + key)
		d.has_key = player.has_key
		if d.sealed:
			# Sealed when the deck starts: no cell of yours.
			pass
	for t in get_tree().get_nodes_in_group("turrets"):
		var tu := t as Turret
		tu.power = _cell_for.bind("turret:%d" % tu.get_instance_id())
		# Security's gift: turrets that run on their own.
		if hub or (mode == "campaign" and Progress.has_gift("turrets")):
			tu.power = _free_cell
	lift.used.connect(_on_lift_used)
	for v in get_tree().get_nodes_in_group("vent_panels"):
		(v as VentPanel).vent_asked.connect(_on_vent_asked)
	for l in level.find_children("", "LogTerminal", true, false):
		var lt := l as LogTerminal
		lt.read.connect(_on_log_read)
	var survivors := get_tree().get_nodes_in_group("survivors")
	for s in survivors:
		var sv := s as Survivor
		if overgrown and Progress.survivors_saved(deck.id) == 0:
			# Nobody reached them in time.
			var t := director.spawn("taken", sv.global_position, false, {"job": sv.job})
			t.rotation.y = sv.rotation.y
			sv.queue_free()
			continue
		if hub:
			sv.is_found = true
			sv.at_lift = true
			continue
		sv.found.connect(_on_survivor_found)
		run.survivors_total += 1
	for h in get_tree().get_nodes_in_group("hub_stations"):
		(h as HubStation).opened.connect(_on_hub_opened)

#endregion

#region Every frame

func _process(delta: float) -> void:
	if run.over:
		return
	run.time += delta
	_leave_confirm = maxf(0.0, _leave_confirm - delta)
	if not hub:
		_tick += delta
		if _tick >= Bloom.TICK:
			_tick -= Bloom.TICK
			tick_bloom()
	_update_music(delta)
	_update_ambience(delta)


## Stops the deck where it is, for screenshots: no Bloom ticks, no clock,
## and the creatures hold still (they still draw).
func freeze() -> void:
	set_process(false)
	director.process_mode = Node.PROCESS_MODE_DISABLED
	for t in get_tree().get_nodes_in_group("turrets") + get_tree().get_nodes_in_group("creatures"):
		t.process_mode = Node.PROCESS_MODE_DISABLED
	hud.hush()


## One tick of the Bloom, and what follows from it.
func tick_bloom() -> void:
	var b := level.bloom
	b.speed = spread()
	b.step()
	director.on_tick()
	for r in b.reached_rooms:
		var id: String = b.room_names[r]
		if id != "" and id != level.tiles.get(DeckLevel.cell_at(player.global_position), ""):
			hud.toast("The Bloom reached the %s" % level.room_name(id).to_lower(), StationTheme.RED)
	if run.check_held(b):
		_on_held()


func _unhandled_input(event: InputEvent) -> void:
	if run.over or player.is_dead or get_tree().paused:
		return
	if event.is_action_pressed("deck_map") or event.is_action_pressed("power_map"):
		get_viewport().set_input_as_handled()
		map_panel.open()
	elif event.is_action_pressed("power_lights"):
		get_viewport().set_input_as_handled()
		var id: String = level.tiles.get(DeckLevel.cell_at(player.global_position), "")
		if id != "":
			toggle_lights(id)
	elif hud.log_open() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		hud.close_log()


## A sound with no place that loops under the deck: the station's hum, the
## wet sound of the growth round you.
func _ambience(id: String, volume_db: float) -> AudioStreamPlayer:
	var s := Sfx.stream(id)
	if s == null or DisplayServer.get_name() == "headless":
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.bus = &"SFX"
	add_child(p)
	p.play()
	return p


## The growth sounds louder the thicker it is where you stand.
func _update_ambience(delta: float) -> void:
	if _wet == null or player == null:
		return
	var g := level.bloom.level_at(DeckLevel.cell_at(player.global_position))
	var want := -60.0 if g < 0.2 else lerpf(-26.0, -8.0, clampf(g / Bloom.MAX, 0.0, 1.0))
	_wet.volume_db = move_toward(_wet.volume_db, want, delta * 20.0)


func _update_music(delta: float) -> void:
	var hunted := false
	for c in director.get_children():
		if c is Creature and not c.dead and c.state in [Creature.State.HUNT, Creature.State.ATTACK]:
			hunted = true
			break
	_hunted_t = 0.0 if hunted else _hunted_t + delta
	if hunted:
		_play_music("hunted")
	elif _hunted_t > 6.0:
		_play_music("calm")


func _play_music(state: String) -> void:
	if quiet or state == _music:
		return
	_music = state
	var id := deck.music if state == "calm" and deck.music != "" else ("hunted" if state == "hunted" else "drone")
	var path := Sfx.music(id, Sfx.music("drone"))
	if path != "":
		LGAudio.play_music(path, -12.0 if state == "calm" else -9.0)

#endregion

#region Difficulty

func spread() -> float:
	return deck.spread * float(LGSettings.get_value("difficulty", "spread", 1.0)) * (1.25 if overgrown else 1.0)


## How hard creatures hit you.
func creature_damage() -> float:
	return float(LGSettings.get_value("difficulty", "damage", 1.0)) * (1.15 if overgrown else 1.0)


## How hard you hit creatures: a little harder on the lighter setting.
func player_damage() -> float:
	return clampf(1.0 + (1.0 - float(LGSettings.get_value("difficulty", "damage", 1.0))) * 0.35, 0.85, 1.15)


func ammo_scale() -> float:
	return float(LGSettings.get_value("difficulty", "ammo", 1.0))

#endregion

#region Power

## A door or turret asks for a cell (true) or gives one back (false).
func _cell_for(take: bool, key: String) -> bool:
	if take:
		if not power.take(key):
			hud.toast("No free power cell", StationTheme.RED)
			return false
		return true
	power.give(key)
	return true


## On a hub, turrets run free.
func _free_cell(_take: bool) -> bool:
	return true


## Switches a room's lights; on takes a cell. Returns whether they're on.
func toggle_lights(id: String) -> bool:
	if not level.rooms.has(id):
		return false
	var key := "lights:" + id
	if level.rooms[id]["dark"]:
		hud.toast("The lights in the %s are broken" % level.room_name(id).to_lower())
		return false
	if level.bloom.airless[level.bloom.room_names.find(id)] == 1:
		hud.toast("The %s is open to space" % level.room_name(id).to_lower())
		return false
	if hub:
		_set_lights(id, not level.room_lights.get(id, []).any(_light_on))
		return true
	if power.has(key):
		power.give(key)
		_set_lights(id, false)
		return false
	if not power.take(key):
		hud.toast("No free power cell", StationTheme.RED)
		Sfx.ui(self, "door_denied", -6.0)
		return false
	_set_lights(id, true)
	return true


func _light_on(l: Variant) -> bool:
	return (l as Light3D).visible


func _set_lights(id: String, on: bool) -> void:
	level.set_room_lights(id, on)
	level.bloom.set_room_lit(id, on)
	if is_inside_tree() and not quiet:
		Sfx.ui(self, "power_on" if on else "power_off", -8.0)


func add_cell() -> void:
	power.add_cell()
	hud.toast("Power cell: %d free" % power.free_cells(), StationTheme.TEAL)

#endregion

#region Things that happen

func _on_held() -> void:
	hud.banner("DECK HELD", StationTheme.TEAL, 4.0)
	hud.say("MARI", deck.held if deck.held != "" else "Organic obstruction cleared. Deck %d is holding." % deck.number)
	if not quiet:
		Sfx.ui(self, "power_on", -2.0)
	_play_music("calm")


func _on_heart_killed(_h: Heart) -> void:
	run.cut_root()
	hud.banner("ROOT CUT", StationTheme.AMBER, 3.0)
	if run.roots_cut >= run.roots:
		hud.say("MARI", "The obstruction's stopped growing. What's left of it is dying back. Burn it out and the deck holds.")


func _on_creature_died(_c: Creature) -> void:
	run.kills += 1


## The cutter burnt a tile: pods there may wither.
func on_burn(cell: Vector2i, amount: float) -> void:
	run.burnt += amount
	var i: int = level.bloom.index.get(cell, -1)
	if i >= 0:
		director._sync_tile(i)
	if run.check_held(level.bloom):
		_on_held()


func on_scream(_w: Node) -> void:
	hud.toast("A Watcher screamed. The pods are waking", StationTheme.RED)


func add_salvage(n: int) -> void:
	run.salvage += n
	hud.toast("Salvage +%d" % n, StationTheme.TEAL)


func spore_blur(amount: float) -> void:
	hud.spores(amount)


## Someone speaks: MARI, a survivor, a log.
func say(person: String, line: String, voice := "") -> void:
	hud.say(person, line)
	var path := Sfx.voice_line(voice if voice != "" else person.to_lower(), line)
	if path != "" and not quiet:
		LGAudio.play_sfx(path)


func _on_log_read(log: LogTerminal) -> void:
	run.read(log.log_id)
	Progress.read_log(log.log_id)
	log.set_read(true)
	hud.show_log(log.title, log.by, log.text)


func _on_survivor_found(s: Survivor) -> void:
	run.found(s.survivor_id)
	hud.toast("%s is heading for the lift" % s.person, StationTheme.TEAL)


func _on_vent_asked(panel: VentPanel) -> void:
	if level.tiles.get(DeckLevel.cell_at(player.global_position), "") == panel.room_id:
		hud.toast("Not while you're in there", StationTheme.RED)
		return
	vent_room(panel.room_id)
	panel.mark_used()


## Opens a room to space: its growth, its pods and everything in it are
## gone, and its doors stay shut for good.
func vent_room(id: String) -> void:
	level.bloom.vent_room(id)
	if power.has("lights:" + id):
		power.give("lights:" + id)
	_set_lights(id, false)
	var cells: Array = level.rooms[id]["cells"]
	for c in director.get_children():
		var n := c as Node3D
		if n == null or level.tiles.get(DeckLevel.cell_at(n.global_position), "") != id:
			continue
		if n is Creature and not n.dead:
			var h := Hit.make(Hit.Kind.BLAST, 9999.0, n.global_position, Vector3.UP, null)
			n.die(h)
		elif n is Pod:
			(n as Pod).pop(false)
		elif n is Heart and not (n as Heart).dead:
			(n as Heart).die()
	for g in ["bodies", "survivors"]:
		for b in get_tree().get_nodes_in_group(g):
			if level.tiles.get(DeckLevel.cell_at(b.global_position), "") == id:
				b.queue_free()
	for key in level.doors:
		var d: Bulkhead = level.doors[key]
		if d.a in cells or d.b in cells:
			d.make_airless()
	for c in cells:
		var i: int = level.bloom.index.get(c, -1)
		if i >= 0:
			director._sync_tile(i)
	if not quiet:
		Sfx.at(self, "vent", DeckLevel.center(cells[0]) + Vector3(0, 2, 0), 6.0)
	hud.toast("The %s is vented" % level.room_name(id).to_lower(), StationTheme.AMBER)
	if run.check_held(level.bloom):
		_on_held()


func _on_hub_opened(st: HubStation) -> void:
	if st.kind == "workbench":
		workbench.open()
	else:
		player.heal(player.max_health)
		player.infection = 0.0
		hud.toast("Rested. Suit patched and blood clean.", StationTheme.TEAL)
		if mode == "campaign":
			Progress.set_loadout(player.kit())


func _on_upgrade(u: String) -> void:
	if u == "suit":
		player.max_health = Tech.MAX_HEALTH + Tech.SUIT_BONUS
		player.heal(Tech.SUIT_BONUS)
	player.arsenal.changed.emit()

#endregion

#region Leaving

func _on_lift_used() -> void:
	if run.over:
		return
	if not lift.powered:
		if hub or power.take("lift"):
			lift.set_powered(true)
			hud.say("MARI", "The lift has power. Use it again when you're ready to go.")
		else:
			hud.toast("The lift needs a free power cell", StationTheme.RED)
		return
	if not run.held and _leave_confirm <= 0.0:
		_leave_confirm = LEAVE_CONFIRM
		hud.toast("The deck isn't held. Use the lift again to leave anyway", StationTheme.AMBER)
		return
	leave()


func _on_leave_from_menu() -> void:
	leave()


## Ends the visit by the lift: survivors near it come too.
func leave() -> void:
	if run.over:
		return
	for s in get_tree().get_nodes_in_group("survivors"):
		var sv := s as Survivor
		if sv.is_found and (sv.at_lift or sv.global_position.distance_to(DeckLevel.center(level.lift_cell)) < 7.0):
			run.saved(sv.survivor_id)
	run.left = true
	_finish()


func _on_player_died() -> void:
	if run.over:
		return
	run.downs += 1
	run.over = true
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_callback(_show_down)


func _show_down() -> void:
	var why := "The Bloom took you."
	match player.down_reason:
		"drained":
			why = "A Feeder drained you dry."
		"killed":
			why = "Your suit gave out."
	if mode == "shift" and night:
		night.deck_down(self)
		return
	var buttons := [["Try the deck again", _retry]]
	if mode == "campaign":
		buttons.append(["Back to the ring", _down_to_ring])
	buttons.append(["Back to the title", _on_quit])
	results.show_panel("YOU'RE DOWN", why, _summary_lines(), buttons, StationTheme.RED)


func _finish() -> void:
	run.over = true
	player.is_movement_paused = true
	if mode == "shift" and night:
		night.deck_done(self)
		return
	var lines := _summary_lines()
	var out := {}
	if mode == "campaign":
		out = Progress.finish_deck(deck.id, run.result(player.kit()))
		for id in out.get("lost", []):
			lines.append(["Lost to the Bloom", Decks.get_deck(id).name])
		for id in out.get("opened", []):
			lines.append(["Open now", Decks.get_deck(id).name])
	var title := "DECK HELD" if run.held else "DECK LEFT"
	var sub := deck.gives_text if run.held and deck.gives_text != "" and not hub else ""
	if hub:
		title = deck.name.to_upper()
	var buttons := []
	if mode == "campaign" and deck.id == "core" and run.held and Progress.ending() == "":
		buttons.append(["See how it ends", _to_ending])
	elif mode == "campaign":
		buttons.append(["Back to the ring", _to_ring])
	else:
		buttons.append(["Again", _retry])
	buttons.append(["Back to the title", _on_quit])
	results.show_panel(title, sub, lines, buttons, StationTheme.TEAL if run.held else StationTheme.AMBER)


func _summary_lines() -> Array:
	var t := int(run.held_at if run.held else run.time)
	var lines := [["Time", "%d:%02d" % [t / 60, t % 60]]]
	if run.roots > 0:
		lines.append(["Roots cut", "%d of %d" % [run.roots_cut, run.roots]])
	if run.survivors_total > 0:
		lines.append(["Survivors brought out", "%d of %d" % [run.survivors_saved.size(), run.survivors_total]])
	lines.append(["Things killed", run.kills])
	if run.salvage > 0:
		lines.append(["Salvage", run.salvage])
	if not run.logs.is_empty():
		lines.append(["Logs read", run.logs.size()])
	return lines


func _retry() -> void:
	get_tree().paused = false
	if mode == "test" or mode == "campaign":
		DeckScene.play(deck.id, {"mode": mode})


## Down: the visit still counts, and the hour passes.
func _down_to_ring() -> void:
	Progress.finish_deck(deck.id, {"held": false, "survivors": 0, "salvage": 0, "time": run.time})
	_to_ring()


func _to_ring() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	LGScenes.change_scene(RING)


func _to_ending() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	LGScenes.change_scene("res://game/ui/ending.tscn")


func _on_quit() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	LGScenes.change_scene(TITLE)

#endregion
