class_name ScreenshotMenus
extends Node
## The menus' screenshots for tools/screenshot.gd's --all: the title and its
## pages, the ring map, the panels on a deck, the endings and Shift mode,
## each staged with made-up progress in memory.

const TITLE := "Menus"

## The screenshot tool, for saving and noting the shots.
var tool: Node
var _names: Array = []


func shoot(dir: String) -> void:
	await _title(dir)
	await _ring(dir)
	await _deck_panels(dir)
	await _endings(dir)
	await _shift(dir)
	tool.note("menus", TITLE, _names)


## The title and its pages, with no shift started, then with one.
func _title(dir: String) -> void:
	Progress.reset()
	var title: Node = load("res://game/ui/title.tscn").instantiate()
	get_tree().root.add_child(title)
	await _frames(30)
	await _save(dir, "title")
	title.show_story()
	await _save(dir, "title_story")
	title.show_how(0)
	await _save(dir, "how_to_play")
	title.show_settings()
	await _save(dir, "settings")
	title.queue_free()
	await _frames(2)


## The ring partway through a shift: three decks saved, one lost, the rest
## running out of hours, with Engineering's spare cells to send.
func _ring(dir: String) -> void:
	Progress.reset()
	Progress.new_campaign()
	Progress.finish_deck("hydroponics", {"held": true, "survivors": 2, "salvage": 6})
	for id in ["labs", "engineering"]:
		if Decks.has(id):
			Progress.finish_deck(id, {"held": true, "survivors": 1, "salvage": 5})
	var ring: Node = load("res://game/ui/ring_map.tscn").instantiate()
	get_tree().root.add_child(ring)
	await _frames(30)
	ring.select("medical" if Decks.has("medical") else "hydroponics")
	await _save(dir, "ring_map")
	ring.queue_free()
	await _frames(2)


## The ending's choice, and two of the endings with their text shown.
func _endings(dir: String) -> void:
	Progress.reset()
	Progress.new_campaign()
	var screen: Node = load("res://game/ui/ending.tscn").instantiate()
	get_tree().root.add_child(screen)
	await _frames(30)
	screen.show_choice()
	await _save(dir, "ending_choice")
	for e in ["stay", "both"]:
		screen.show_ending(e)
		await _frames(2)
		_finish_fades()
		await _save(dir, "ending_" + e)
	screen.queue_free()
	await _frames(2)


## Shift mode: its page on the title, a deck from tonight's station, and the
## night's score.
func _shift(dir: String) -> void:
	var title: Node = load("res://game/ui/title.tscn").instantiate()
	get_tree().root.add_child(title)
	await _frames(20)
	title.show_shift()
	await _save(dir, "shift_mode")
	title.queue_free()
	await _frames(2)
	var night := ShiftNight.make(ShiftNight.daily_seed())
	ShiftNight.current = night
	var d: DeckDef = night.decks[0]
	var scene := DeckScene.new()
	scene.deck_id = d.id
	scene.mode = "shift"
	scene.custom_deck = d
	scene.custom_level = load(d.level)
	scene.night = night
	scene.quiet = true
	get_tree().root.add_child(scene)
	scene.freeze()
	await _frames(20)
	for v in ["spine", "first_room", "nest"]:
		await _stand(scene, scene.level.views[v])
		await _save(dir, "shift_" + v)
	night.results = [
		{"name": night.decks[0].name, "held": true, "survivors": 1, "kills": 31, "time": 402.0, "score": 1603},
		{"name": night.decks[1].name, "held": true, "survivors": 0, "kills": 44, "time": 515.0, "score": 1305},
		{"name": night.decks[2].name, "held": false, "survivors": 1, "kills": 19, "time": 380.0, "score": 345},
	]
	night._finish(scene, true)
	await _save(dir, "shift_score")
	get_tree().paused = false
	scene.queue_free()
	ShiftNight.current = null
	await _frames(2)


## Puts the tech's eyes at a view, as tools/screenshot.gd does.
func _stand(scene: DeckScene, view: Array) -> void:
	var p := scene.player
	p.global_position = view[0]
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	p.body.rotation.y = deg_to_rad(view[1])
	p.head.rotation.x = deg_to_rad(view[2])
	await _frames(2)
	p.global_position += view[0] - p.camera.global_position
	p.reset_physics_interpolation()
	await _frames(10)


## Ends every tween now (the endings fade their paragraphs in).
func _finish_fades() -> void:
	for t in get_tree().get_processed_tweens():
		t.custom_step(60.0)


func _save(dir: String, name: String) -> void:
	await _frames(12)
	tool.save("%s/%s.png" % [dir, name])
	_names.append(name)


## The HUD and the panels you open on a deck.
func _deck_panels(dir: String) -> void:
	var scene := DeckScene.new()
	scene.deck_id = "hydroponics"
	scene.mode = "test"
	scene.quiet = true
	get_tree().root.add_child(scene)
	scene.freeze()
	await _frames(20)
	scene.player.body.rotation.y = 0.0
	scene.hud.say("MARI", Decks.get_deck("hydroponics").arrive)
	await _save(dir, "deck_hud")
	scene.hud.hush()
	scene.map_panel.open()
	await _save(dir, "deck_map")
	scene.map_panel.close()
	scene.workbench.open()
	await _save(dir, "workbench")
	scene.workbench.close()
	scene.pause.open_pause_menu()
	await _save(dir, "pause")
	scene.pause.close_pause_menu()
	scene.run.salvage = 7
	scene.run.kills = 23
	scene.run.time = 611.0
	scene.run.held = true
	scene.results.show_panel("DECK HELD", "Hydroponics is safe again.", scene._summary_lines(), [["Back to the ring", Callable()]], StationTheme.TEAL)
	await _save(dir, "results")
	get_tree().paused = false
	scene.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
