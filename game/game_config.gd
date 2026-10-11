class_name GameConfig
extends RefCounted
## Game-wide constants: identity, version, input map and setting defaults.

const GAME_ID := "hull-bloom"

## This round's own questions at the end of a play test (LGPlaytest), on top
## of the standard ones. Change them for each round of play testing.
const PLAYTEST := {
	"questions": [
		{"id": "first_minutes", "text": "How did your first few minutes on Hydroponics feel?", "kind": "text"},
		{"id": "tense", "text": "How tense or scary was it?", "kind": "rating"},
		{"id": "bloom_clear", "text": "How easy was it to tell where the Bloom was spreading and what slowed it?", "kind": "rating"},
		{"id": "lost_deck", "text": "If you lost a deck to the Bloom, did you want to go back for it? Why?", "kind": "text"},
	],
}

const SETTING_DEFAULTS := {
	"online": {
		"enabled": true,
		"host": OnlineServer.HOST,
		"port": OnlineServer.PORT,
		"scheme": OnlineServer.SCHEME,
		"server_key": OnlineServer.SERVER_KEY,
	},
	"tutorial": {
		"welcomed": false,
		# Set once you've switched a room's lights on; until then MARI tells
		# you how in the first dark room you walk into.
		"lights": false,
	},
	"player": {
		# The name on the online boards ("" for "Night tech").
		"name": "",
	},
	"play": {
		"invert_look": false,
		"mouse_sensitivity": 0.25,
		"stick_sensitivity": 2.0,
		"toggle_crouch": true,
		# Comfort: head bob (0 to 1), the view rolling, and the field of view.
		# Calm by default, for players prone to motion sickness.
		"bob": 0.0,
		"tilt": false,
		"fov": 75.0,
		# How bright the dark is: 1 as the station was built, more to see
		# further on a dim screen.
		"brightness": 1.0,
		# How much the walls breathe: 1 normal, 0.4 slow, 0 still.
		"calm_walls": 1.0,
		# Spore bursts blur the view for a moment.
		"spore_blur": true,
		# Controller rumble when firing and when hurt.
		"rumble": true,
		# Subtitles for MARI and the crew logs.
		"subtitles": true,
	},
	"gore": {
		# "full", "less" (no dismemberment, dark ichor, nobody gets up again
		# on screen) or "off" (no blood or gibs).
		"level": "full",
		# A four digit code that locks the gore setting, or "" for none.
		"lock": "",
	},
	"difficulty": {
		# How fast the Bloom spreads, how hard things hit, and how much
		# ammunition turns up: 0.75 gentle, 1.0 normal, 1.3 hard.
		"spread": 1.0,
		"damage": 1.0,
		"ammo": 1.0,
	},
}

## Every in-game action, with keyboard and controller bindings (see LGInput).
## Movement, interaction and menu names are Cogito's, so its player and
## interaction raycast read them as they are.
const ACTIONS := {
	"forward": ["key:W", "axis:ly-"],
	"back": ["key:S", "axis:ly+"],
	"left": ["key:A", "axis:lx-"],
	"right": ["key:D", "axis:lx+"],
	"jump": ["key:Space", "joy:a"],
	"crouch": ["key:Ctrl", "key:C", "joy:b"],
	"sprint": ["key:Shift", "joy:ls"],
	"menu": ["key:Escape", "joy:start"],
	"free_look": [],
	# Use what you're looking at (hold to carry); reload when there's nothing.
	"interact": ["key:F", "joy:x"],
	"interact2": [],
	# Fire (the cutter: burn) and aim (the cutter: a focused beam for limbs).
	"action_primary": ["mouse:left", "axis:rt+"],
	"action_secondary": ["mouse:right", "axis:lt+"],
	# On a pad, X reloads when there's nothing in view to use.
	"reload": ["key:R", "joy:x"],
	# Swap: tap for the weapon you had before, hold for the weapon wheel.
	"quick_swap": ["key:Q", "joy:rb"],
	# The mouse wheel steps through the weapons either way; the number keys
	# pick one.
	"swap": ["mouse:wheel_down"],
	"swap_back": ["mouse:wheel_up"],
	"weapon_1": ["key:1"],
	"weapon_2": ["key:2"],
	"weapon_3": ["key:3"],
	"weapon_4": ["key:4"],
	"weapon_5": ["key:5"],
	"weapon_6": ["key:6"],
	# Throw a flare, grenade or mine; tap to throw, hold to pick which.
	"throw": ["key:G", "joy:lb"],
	"torch": ["key:T", "joy:y"],
	# Shove: break a Feeder's grip, push the Taken back.
	"shove": ["key:V", "mouse:middle", "joy:rs"],
	# Power: lights in this room, and the power map.
	"power_lights": ["key:L", "joy:up"],
	"power_map": ["key:P", "joy:down"],
	# A stim or a health pack.
	"heal": ["key:H", "joy:left"],
	"stim": ["key:J", "joy:right"],
	"deck_map": ["key:Tab", "key:M", "joy:back"],
	# Cogito reads these; Hull Bloom has no inventory screen.
	"inventory": [],
	"inventory_move_item": [],
	"inventory_use_item": [],
	"inventory_drop_item": [],
	"inventory_assign_item": [],
	"quickslot_1": [],
	"quickslot_2": [],
	"quickslot_3": [],
	"quickslot_4": [],
	"quickslot_prev_wieldable": [],
	"quickslot_next_wieldable": [],
	"lean_left": [],
	"lean_right": [],
	"ui_next_tab": ["key:E", "joy:rb"],
	"ui_prev_tab": ["key:Q", "joy:lb"],
}


static func version() -> String:
	return LGVersion.current()


## The player's name on the online boards.
static func player_name() -> String:
	var n := str(LGSettings.get_value("player", "name", "")).strip_edges()
	return n if n != "" else "Night tech"
