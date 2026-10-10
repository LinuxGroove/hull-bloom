class_name Sfx
extends RefCounted
## Plays sounds in the station: one-shots at a place, and loops on a node.
##
## Sounds go by id ("door_open", "cutter_loop"). An id plays
## assets/audio/sfx/<id>.ogg when there is one (made by tools/sfx/make_sfx.py
## or on Ken's Lemonade machine, see tools/lemonade/), else one of the Kenney
## sounds [constant KENNEY] lists for it, picked at random. Ids ending in
## "_loop" loop.

const DIR := "res://assets/audio/sfx/"
const KENNEY_DIR := "res://assets/audio/kenney/"
const VOICE_DIR := "res://assets/audio/voice/"
const MUSIC_DIR := "res://assets/audio/music/"

## Kenney's sci-fi, impact and interface sounds for the ids that have no
## sound of their own yet.
const KENNEY := {
	"door_open": ["doorOpen_000", "doorOpen_001"],
	"door_close": ["doorClose_000", "doorClose_001"],
	"door_seal": ["forceField_000"],
	"door_unseal": ["forceField_002"],
	"door_denied": ["error_004"],
	"lift": ["spaceEngineLow_002"],
	"power_on": ["forceField_003"],
	"power_off": ["forceField_004"],
	"pickup": ["pickup1", "pickup2", "pickup3"],
	"pickup_ammo": ["platesHit4", "platesHit5"],
	"pickup_cell": ["forceField_001"],
	"read": ["computerNoise_000", "computerNoise_001"],
	"ui_select": ["select_001"],
	"ui_back": ["back_001"],
	"sidearm": ["laserSmall_000", "laserSmall_001"],
	"scattergun": ["laserLarge_000", "laserLarge_002"],
	"rifle": ["laserRetro_000", "laserRetro_002"],
	"smg": ["laserSmall_002", "laserSmall_003", "laserSmall_004"],
	"rail": ["laserLarge_004"],
	"turret": ["laserRetro_003", "laserRetro_004"],
	"dry_fire": ["click_001"],
	"reload": ["platesSlide2", "platesSlide3"],
	"swap": ["platesHit1"],
	"cutter_start": ["thrusterFire_000"],
	"cutter_loop": ["spaceEngineSmall_001"],
	"cutter_hot": ["error_006"],
	"hit_metal": ["impactMetal_000", "impactMetal_001", "impactMetal_002"],
	"hit_flesh": ["impactPunch_medium_000", "impactPunch_medium_001", "impactSoft_medium_000"],
	"hit_player": ["impactPunch_heavy_000", "impactPunch_heavy_001"],
	"step_metal": ["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003"],
	"step_wet": ["footstep_snow_000", "footstep_snow_001", "footstep_snow_002"],
	"explosion": ["explosionCrunch_000", "explosionCrunch_002", "lowFrequency_explosion_000"],
	"throw": ["woosh1", "woosh2"],
	"flare": ["thrusterFire_002"],
	"mine_arm": ["toggle_002"],
	"gib": ["slime_000", "slime_001"],
	"splat": ["slime_001", "impactSoft_heavy_000"],
	"pod_burst": ["slime_000", "lowFrequency_explosion_001"],
	"robot_hit": ["impactMetal_003", "impactMetal_004"],
	"robot_die": ["explosionCrunch_001", "computerNoise_003"],
	"vent": ["spaceEngineLarge_000"],
	"alarm": ["glitch_001"],
}

static var _streams := {}
static var _missing := {}


## A sound by id, by path (res://...), or null if there's none.
static func stream(id: String) -> AudioStream:
	if id.begins_with("res://"):
		return _load(id)
	var own := DIR + id + ".ogg"
	if ResourceLoader.exists(own):
		return _load(own)
	var picks: Array = KENNEY.get(id, [])
	if picks.is_empty():
		if not _missing.has(id):
			_missing[id] = true
			push_warning("Sfx: no sound for %s" % id)
		return null
	return _load(KENNEY_DIR + String(picks[randi() % picks.size()]) + ".ogg")


static func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		if not ResourceLoader.exists(path):
			_streams[path] = null
		else:
			var s: AudioStream = load(path)
			if s is AudioStreamOggVorbis and path.get_basename().ends_with("_loop"):
				s.loop = true
			_streams[path] = s
	return _streams[path]


## Plays a sound once at `pos`, then cleans up.
static func at(world: Node, id: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	if world == null or not world.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var s := stream(id)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.bus = &"SFX"
	p.unit_size = 5.0
	p.max_distance = 45.0
	p.attenuation_filter_cutoff_hz = 9000.0
	world.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A sound with no place: the HUD, the player's own gun.
static func ui(world: Node, id: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if world == null or not world.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var s := stream(id)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.bus = &"SFX"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	world.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A sound attached to `node` that follows it, for loops (hums, breathing).
static func on(node: Node3D, id: String, volume_db := 0.0, autoplay := true) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "Sfx_" + id.get_file()
	p.stream = stream(id)
	p.volume_db = volume_db
	p.bus = &"SFX"
	p.unit_size = 4.0
	p.max_distance = 30.0
	p.autoplay = autoplay and DisplayServer.get_name() != "headless"
	node.add_child(p)
	return p


## The recorded line for `text` by `voice` ("mari", a crew member's id), or
## "" when there isn't one. Lines live in assets/audio/voice/<voice>/<slug>.ogg.
static func voice_line(voice: String, text: String) -> String:
	var path := VOICE_DIR + voice + "/" + slug(text) + ".ogg"
	return path if ResourceLoader.exists(path) else ""


## A file name for a line: lower case words joined by underscores, at most
## 48 characters.
static func slug(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif c != "'" and not out.ends_with("_") and out != "":
			out += "_"
	return out.left(48).trim_suffix("_")


## Our music track `id` from assets/audio/music, or `fallback`.
static func music(id: String, fallback := "") -> String:
	var path := MUSIC_DIR + id + ".ogg"
	return path if ResourceLoader.exists(path) else fallback


## Plays the first of `ids` that has a track, or the drone; nothing when
## there's no music at all.
static func play_music(ids: Array, volume_db := -10.0) -> void:
	for id in ids + ["drone"]:
		var path := music(id)
		if path != "":
			LGAudio.play_music(path, volume_db)
			return
