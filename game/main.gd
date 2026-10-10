extends Node
## Boots the game: settings, input map, theme and window, then the title.
##
## Developer shortcuts (after `--`):
##   --deck=hydroponics   straight onto a deck, as a test run (the campaign
##                        isn't touched)
##   --campaign           with --deck: as part of the campaign
##   --shift[=seed]       straight into a Shift night
##   --playtest           record a play test (see LGPlaytest)
##   --set=section/key=value   any setting, for one run


func _ready() -> void:
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGLaunchPing.send(GameConfig.GAME_ID)
	LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)
	LGInput.register_actions(GameConfig.ACTIONS, float(LGSettings.get_value("input", "stick_deadzone", 0.2)))
	LGInput.extend_ui_actions()
	StationTheme.apply(get_tree().root, 22)
	get_window().title = "Hull Bloom"
	RenderingServer.global_shader_parameter_set("calm_walls", float(LGSettings.get_value("play", "calm_walls", 1.0)))
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--deck="):
			DeckScene.play(a.trim_prefix("--deck="), {"mode": "campaign" if "--campaign" in args else "test"})
			return
		if a.begins_with("--shift"):
			var seed := int(a.trim_prefix("--shift=")) if a.contains("=") else ShiftNight.daily_seed()
			ShiftNight.start(seed)
			return
	LGScenes.change_scene("res://game/ui/title.tscn")
