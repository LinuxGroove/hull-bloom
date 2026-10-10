class_name ScreenshotMenus
extends Node
## The menus' screenshots for tools/screenshot.gd's --all: the title and its
## pages, the ring map, the panels on a deck and the endings, each staged
## with made-up progress in memory.

const TITLE := "Menus"

## The screenshot tool, for saving and noting the shots.
var tool: Node
var _names: Array = []


func shoot(dir: String) -> void:
	await _deck_panels(dir)
	tool.note("menus", TITLE, _names)


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
