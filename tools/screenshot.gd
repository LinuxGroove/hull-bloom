extends Node
## Takes screenshots, for checking how the game looks without a screen. Run
## with a display (xvfb-run on a server), software Vulkan if there's no GPU,
## and --resolution 1280x800:
##   godot --path . --resolution 1280x800 tools/screenshot.tscn -- --out=/tmp/shots --deck=hydroponics [--view=name] [--hud] [--overgrown] [--grow=ticks]
## saves a deck's views (the level's own) as PNGs, and
##   godot --path . --resolution 1280x800 tools/screenshot.tscn -- --all=docs/screenshots [group=hydroponics]
## saves every deck's views and the menus (group "menus") into a folder per
## group, with a README listing them. Progress stays in memory, so the
## player's own is never touched.

const SETTLE_FRAMES := 30

var _scene: DeckScene
var _index := {}


func _ready() -> void:
	var out := "/tmp/shots"
	var deck := "hydroponics"
	var only := ""
	var hud := false
	var overgrown := false
	var grow := 0
	var all := ""
	var group := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--deck="):
			deck = a.trim_prefix("--deck=")
		elif a.begins_with("--view="):
			only = a.trim_prefix("--view=")
		elif a == "--hud":
			hud = true
		elif a == "--overgrown":
			overgrown = true
		elif a.begins_with("--grow="):
			grow = int(a.trim_prefix("--grow="))
		elif a.begins_with("--all="):
			all = a.trim_prefix("--all=")
		elif a.begins_with("group="):
			group = a.trim_prefix("group=")
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGSettings.set_value("video", "fullscreen", false, false)
	# Staged scores must never reach the online boards.
	LGSettings.set_value("online", "enabled", false, false)
	LGInput.register_actions(GameConfig.ACTIONS)
	StationTheme.apply(get_tree().root, 22)
	RenderingServer.global_shader_parameter_set("calm_walls", 1.0)
	Progress.in_memory = true
	Progress.load_progress()
	# The root is still adding its children.
	await get_tree().process_frame
	if all != "":
		await _all(all, group)
	else:
		DirAccess.make_dir_recursive_absolute(out)
		await _deck_views(deck, out, only, hud, overgrown, grow)
	get_tree().quit()


## Every deck's views, then the menus, and the README.
func _all(dir: String, group: String) -> void:
	for id in Decks.ids():
		if group == "" or group == id:
			DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, id])
			await _deck_views(id, "%s/%s" % [dir, id], "", id == "hydroponics", false, 0)
			await _overgrown_shot(id, "%s/%s" % [dir, id])
	if group == "" or group == "menus":
		DirAccess.make_dir_recursive_absolute(dir + "/menus")
		var menus := ScreenshotMenus.new()
		menus.tool = self
		add_child(menus)
		await menus.shoot(dir + "/menus")
	_write_readme(dir)


func _deck_views(id: String, out: String, only: String, hud: bool, overgrown: bool, grow: int) -> void:
	await _open(id, overgrown, grow)
	_scene.hud.visible = hud
	var shots: Array = []
	for v in _scene.level.views:
		if only != "" and not v.begins_with(only):
			continue
		await _stand(_scene.level.views[v])
		save("%s/%s.png" % [out, v])
		shots.append(v)
	_index[id] = [Decks.get_deck(id).name, shots]
	_scene.queue_free()
	_scene = null
	await _frames(2)


## The deck once the Bloom has had it for a while, as a lost deck looks
## when you go back to take it: the view standing in the thickest growth
## that isn't the Heart's own room.
func _overgrown_shot(id: String, out: String) -> void:
	await _open(id, true, 160)
	_scene.hud.visible = false
	var best := ""
	var most := -1.0
	for v in _scene.level.views:
		var cell := DeckLevel.cell_at(_scene.level.views[v][0])
		var g := _scene.level.bloom.level_at(cell)
		if g > most and g < Bloom.MAX - 0.5:
			best = v
			most = g
	if best == "":
		best = _scene.level.views.keys()[0]
	await _stand(_scene.level.views[best])
	save("%s/%s_overgrown.png" % [out, best])
	_index[id][1].append(best + "_overgrown")
	_scene.queue_free()
	_scene = null
	await _frames(2)


## Saves the screen; prints the path so a long run shows its progress.
func save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## Notes a group of shots for the README: [title, [names]].
func note(group: String, title: String, names: Array) -> void:
	_index[group] = [title, names]


func _open(id: String, overgrown: bool, grow: int) -> void:
	_scene = DeckScene.new()
	_scene.deck_id = id
	_scene.mode = "test"
	_scene.quiet = true
	if overgrown:
		_scene.mode = "campaign"
		Progress.new_campaign()
		var d := Progress._deck(id)
		d["state"] = "lost"
		Progress._set_deck(id, d)
	get_tree().root.add_child(_scene)
	if grow > 0:
		for k in grow:
			_scene.tick_bloom()
		_scene.bloom_view.snap()
	_scene.freeze()
	await _frames(SETTLE_FRAMES)


## Puts the tech's eyes at a view: [eye position, yaw, pitch] in degrees.
func _stand(view: Array) -> void:
	var p := _scene.player
	p.global_position = view[0]
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	p.body.rotation.y = deg_to_rad(view[1])
	p.head.rotation.x = deg_to_rad(view[2])
	await _frames(2)
	var eye := p.camera.global_position
	p.global_position += view[0] - eye
	p.reset_physics_interpolation()
	await _frames(10)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _write_readme(dir: String) -> void:
	# Sections by title, the old README's first so a run of one group keeps
	# the others, in the decks' order with the menus last.
	var sections := {}
	var old := FileAccess.get_file_as_string(dir + "/README.md")
	for section in old.split("\n## ").slice(1):
		sections[section.get_slice("\n", 0)] = section.strip_edges()
	for g in _index:
		var body := PackedStringArray([_index[g][0], ""])
		for n in _index[g][1]:
			body.append("- [%s](%s/%s.png)" % [String(n).replace("_", " ").capitalize(), g, n])
		sections[_index[g][0]] = "\n".join(body)
	var lines := PackedStringArray(["# Screenshots", "",
		"Every deck's views and the menus, made by `tools/screenshot.tscn -- --all=docs/screenshots` (see CLAUDE.md). The decks are shown as they are when you step out of the lift, before anything moves.", ""])
	var titles: Array = []
	for id in Decks.ids():
		titles.append(Decks.get_deck(id).name)
	titles.append(ScreenshotMenus.TITLE)
	for t in sections:
		if not t in titles:
			titles.append(t)
	for t in titles:
		if sections.has(t):
			lines.append("## " + sections[t])
			lines.append("")
	var f := FileAccess.open(dir + "/README.md", FileAccess.WRITE)
	f.store_string("\n".join(lines))
