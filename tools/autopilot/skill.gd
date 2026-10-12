extends RefCounted
## How well the autopilot plays: three presets, novice, average and expert,
## each a set of knobs a person's play varies by.
##
## - aim_error: degrees of wobble round the target (a slow drift, not jitter).
## - reaction: seconds from something coming into view to doing anything
##   about it; turn_speed: degrees a second the view can swing.
## - lost_per_min: chance a minute of wandering off somewhere else for a
##   while; route_noise: how much worse than the best route it may take.
## - Tools, each a chance or a threshold: flares, sealing doors behind it,
##   room lights where the growth is spreading, venting a root's room,
##   grenades into packs, mines for big things, the medkit (heal_at, and
##   whether it waits for a quiet moment), stims (stim_at infection), and
##   reloading in cover (tactical_reload).
## - weapon_sense: chance of picking the right gun for what it's fighting
##   rather than keeping what's in hand; backs_off: steps back from melee.
## - curiosity: chance of going to read a log it sees; explore: chance of
##   looking round the deck for survivors and supplies once it's held.

const PRESETS := {
	"novice": {
		"aim_error": 5.0, "reaction": 0.65, "turn_speed": 170.0,
		"lost_per_min": 0.35, "route_noise": 0.6,
		"flare": 0.1, "seal": 0.0, "lights": 0.0, "vent": 0.0, "grenade": 0.3, "mine": 0.0,
		"heal_at": 25.0, "heal_waits": false, "heal_forget": 0.35, "stim_at": 88.0,
		"tactical_reload": false, "weapon_sense": 0.35, "backs_off": 0.3,
		"shoot_pods": 0.2, "freeze_pods": 0.0, "curiosity": 0.7, "explore": 0.3, "scout": 0.4, "push": 0.25, "shove": 0.2, "careful": 0.2, "wait_survivors": 15.0,
		"fire_tolerance": 1.6, "sprint": 0.8,
	},
	"average": {
		"aim_error": 2.6, "reaction": 0.4, "turn_speed": 280.0,
		"lost_per_min": 0.12, "route_noise": 0.25,
		"flare": 0.4, "seal": 0.2, "lights": 0.3, "vent": 0.4, "grenade": 0.7, "mine": 0.3,
		"heal_at": 40.0, "heal_waits": true, "heal_forget": 0.1, "stim_at": 70.0,
		"tactical_reload": true, "weapon_sense": 0.75, "backs_off": 0.65,
		"shoot_pods": 0.6, "freeze_pods": 0.3, "curiosity": 0.5, "explore": 0.6, "scout": 0.6, "push": 0.6, "shove": 0.5, "careful": 0.6, "wait_survivors": 30.0,
		"fire_tolerance": 1.2, "sprint": 0.5,
	},
	"expert": {
		"aim_error": 1.2, "reaction": 0.25, "turn_speed": 420.0,
		"lost_per_min": 0.02, "route_noise": 0.05,
		"flare": 0.8, "seal": 0.6, "lights": 0.7, "vent": 0.9, "grenade": 0.95, "mine": 0.7,
		"heal_at": 45.0, "heal_waits": true, "heal_forget": 0.0, "stim_at": 55.0,
		"tactical_reload": true, "weapon_sense": 0.95, "backs_off": 0.9,
		"shoot_pods": 0.9, "freeze_pods": 0.7, "curiosity": 0.35, "explore": 0.8, "scout": 0.9, "push": 0.9, "shove": 0.8, "careful": 0.95, "wait_survivors": 45.0,
		"fire_tolerance": 1.0, "sprint": 0.3,
	},
}


static func get_preset(name: String) -> Dictionary:
	return PRESETS.get(name, PRESETS["average"]).duplicate()


static func names() -> Array:
	return PRESETS.keys()
