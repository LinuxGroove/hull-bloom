extends Node
## The screens at whatever window size the game is started at, for checking
## that nothing is clipped or overlapping: the title, the ring map, the HUD on
## a deck, the weapon wheel, the pause menu and the deck map. Run under a
## display with a window size:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 tools/function_shots.tscn -- --out=/tmp/shots [--tag=1920x1080] [--scale3d=0.35] [--settle=12]
## --settle= is how many frames each screen gets (default 12). --scale3d draws the 3D scene behind the menus at a fraction of the size
## (the menus stay sharp), which makes huge windows possible on software
## Vulkan.
## Progress stays in memory, so the player's own is never touched.

var _out := "/tmp/shots"
var _tag := ""
## Frames to let each screen settle; software Vulkan needs seconds for every one.
var _settle := 12


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
		elif a.begins_with("--scale3d="):
			get_viewport().scaling_3d_scale = clampf(float(a.trim_prefix("--scale3d=")), 0.25, 1.0)
		elif a.begins_with("--settle="):
			_settle = maxi(2, int(a.trim_prefix("--settle=")))
	if _tag == "":
		_tag = "%dx%d" % [get_window().size.x, get_window().size.y]
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGSettings.set_value("video", "fullscreen", false, false)
	LGSettings.set_value("online", "enabled", false, false)
	LGInput.register_actions(GameConfig.ACTIONS)
	LGInput.extend_ui_actions()
	StationTheme.apply(get_tree().root, 22)
	RenderingServer.global_shader_parameter_set("calm_walls", 1.0)
	Progress.in_memory = true
	Progress.load_progress()
	DirAccess.make_dir_recursive_absolute(_out)
	await _frames(2)
	print("window ", get_window().size, " viewport ", get_viewport().get_visible_rect().size)
	await _title()
	await _ring()
	await _deck()
	get_tree().quit()


func _title() -> void:
	Progress.reset()
	var title: Node = load("res://game/ui/title.tscn").instantiate()
	get_tree().root.add_child(title)
	await _frames(_settle)
	_save("title")
	title.queue_free()
	await _frames(2)


func _ring() -> void:
	Progress.reset()
	Progress.new_campaign()
	Progress.finish_deck("hydroponics", {"held": true, "survivors": 2, "salvage": 6})
	Progress.finish_deck("labs", {"held": true, "survivors": 1, "salvage": 5})
	var ring: Node = load("res://game/ui/ring_map.tscn").instantiate()
	get_tree().root.add_child(ring)
	await _frames(_settle)
	ring.select("medical")
	await _frames(maxi(2, _settle / 3))
	_save("ring")
	ring.queue_free()
	await _frames(2)


func _deck() -> void:
	var scene := DeckScene.new()
	scene.deck_id = "hydroponics"
	scene.mode = "test"
	scene.quiet = true
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.freeze()
	await _frames(_settle)
	scene.hud.say("MARI", Decks.get_deck("hydroponics").arrive)
	scene.hud.toast("The Bloom reached the seed store", StationTheme.RED)
	scene.hud.toast("Power cell: 3 free", StationTheme.TEAL)
	await _frames(maxi(3, _settle / 2))
	_save("hud")
	scene.hud.hush()
	# The weapon wheel, with every gun and one pointed at.
	var ars := scene.player.arsenal
	for w in Arsenal.WEAPONS:
		ars.give(w)
	ars.select("cutter")
	ars.open_wheel()
	ars.point_wheel(ars.wheel_direction("scattergun"))
	await _frames(maxi(3, _settle / 2))
	_save("wheel")
	ars.close_wheel(false)
	scene.pause.open_pause_menu()
	await _frames(maxi(3, _settle / 2))
	_save("pause")
	scene.pause.close_pause_menu()
	scene.map_panel.open()
	await _frames(maxi(3, _settle / 2))
	_save("map")
	scene.map_panel.close()
	get_tree().paused = false
	scene.queue_free()
	await _frames(2)


func _save(name: String) -> void:
	var w := get_window()
	print("%s: window %s, content scale size %s mode %d factor %.2f, final transform scale %.3f, 3d scale %.2f" % [name, w.size, w.content_scale_size, w.content_scale_mode, w.content_scale_factor, w.get_final_transform().x.x, w.scaling_3d_scale])
	var path := "%s/%s_%s.png" % [_out, name, _tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
