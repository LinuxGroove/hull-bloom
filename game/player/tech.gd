class_name Tech
extends CogitoPlayer
## The player: Marigold's night-shift maintenance tech. Cogito's first person
## controller, with a suit that takes hits, the Bloom's infection in your
## blood, a torch, a shove, medkits and stims, and the [Arsenal] in your
## hands. Cogito's own health, pause menu and inventory are left out.
##
## Comfort first (see [method _reload_options]): no head bob, view roll or
## camera kick unless the settings ask for it; the gun model recoils instead.

signal hurt(amount: float, from_dir: Vector3)
signal died
signal items_changed
signal grabbed(on: bool)

## Cogito player nodes Hull Bloom doesn't use.
const UNUSED := ["CogtoTestCurrency", "StrengthAttribute", "LightMeterAttribute",
	"SanityAttribute", "StaminaAttribute", "HealthAttribute", "HealthAutoConsume",
	"StaminaAutoConsume", "AutoPickUpZone"]

const BOB_WALK := 0.03
const BOB_SPRINT := 0.05
const BOB_CROUCH := 0.04

const MAX_HEALTH := 100.0
const SUIT_BONUS := 30.0
const MEDKIT_HEAL := 55.0
const HEALTH_TUBE := 20.0
const STIM_CURE := 60.0
const STIM_TIME := 45.0
## Infection rises slowly while you stand in thick growth.
const GROWTH_INFECT := 0.6
const SHOVE_RANGE := 2.3
const SHOVE_TIME := 0.7
const CARRY := {"medkit": 3, "stim": 3, "flare": 6, "grenade": 4, "mine": 3}
const POCKETS_BONUS := {"medkit": 1, "stim": 1, "flare": 2, "grenade": 2, "mine": 1}

var health := MAX_HEALTH
var max_health := MAX_HEALTH
## 0 to 100: at 100 the Bloom has you.
var infection := 0.0
var immune := 0.0
var items := {"medkit": 0, "stim": 0, "flare": 0, "grenade": 0, "mine": 0}
var keycards: Array[String] = []
var torch_on := true
var grabbed_by: Node3D = null
var arsenal: Arsenal
var torch: SpotLight3D
## Hull Bloom's pause menu, set before the player enters the tree.
var bloom_pause: Node
var level: DeckLevel
var down_reason := ""

var _shove_t := 0.0
var _heal_left := 0.0
var _feet_offset := 0.0
var _tilt := false
var _grab_from := Vector3.ZERO
var _rumble := true


func _ready():
	$PlayerInteractionComponent.stamina_attribute = null
	for n in UNUSED:
		var node := get_node_or_null(n)
		if node:
			remove_child(node)
			node.free()
	var cogito_pause := get_node_or_null(pause_menu)
	if cogito_pause:
		cogito_pause.get_parent().remove_child(cogito_pause)
		cogito_pause.free()
	if bloom_pause:
		pause_menu = bloom_pause.get_path()
	fall_damage = 0
	collision_layer = Kit.LAYER_PLAYER
	collision_mask = Kit.LAYER_SOLID | Kit.LAYER_GLASS | Kit.LAYER_CREATURES
	CAN_BUNNYHOP = false
	disable_roll_anim = true
	WALKING_SPEED = 3.8
	SPRINTING_SPEED = 6.2
	CROUCHING_SPEED = 2.0
	walk_volume_db = -80.0
	sprint_volume_db = -80.0
	crouch_volume_db = -80.0
	_feet_offset = -_feet_height()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	neck.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	eyes.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	camera.near = 0.04
	camera.cull_mask = 0xFFFFF
	_reload_options()
	super()
	max_health = MAX_HEALTH + (SUIT_BONUS if Progress.has_upgrade("suit") else 0.0)
	health = max_health
	torch = SpotLight3D.new()
	torch.name = "Torch"
	torch.light_color = Color(1.0, 0.95, 0.85)
	torch.light_energy = 2.4
	torch.spot_range = 18.0
	torch.spot_angle = 26.0
	torch.spot_angle_attenuation = 0.8
	torch.spot_attenuation = 1.2
	torch.shadow_enabled = true
	torch.shadow_bias = 0.05
	torch.position = Vector3(0.18, -0.12, 0.0)
	camera.add_child(torch)
	arsenal = Arsenal.new()
	arsenal.name = "Arsenal"
	arsenal.player = self
	camera.add_child(arsenal)
	var hud := get_node_or_null(player_hud)
	if hud:
		for n in ["FixedStaminaBar", "InventoryInterface", "MarginContainer_BottomUI", "Crosshair"]:
			var c := hud.get_node_or_null(n) as CanvasItem
			if c:
				c.hide()
				c.process_mode = Node.PROCESS_MODE_DISABLED
		for n in ["PromptUI/PromptArea", "HintArea"]:
			var c := hud.get_node_or_null(n) as CanvasItem
			if c:
				c.modulate.a = 0.0
	add_to_group("tech")


## Settings come from LGSettings, not Cogito's own options file.
func _reload_options():
	MOUSE_SENS = float(LGSettings.get_value("play", "mouse_sensitivity", 0.25))
	INVERT_Y_AXIS = bool(LGSettings.get_value("play", "invert_look", false))
	TOGGLE_CROUCH = bool(LGSettings.get_value("play", "toggle_crouch", true))
	var bob := float(LGSettings.get_value("play", "bob", 0.0))
	HEADBOBBLE = 1
	WIGGLE_ON_WALKING_INTENSITY = BOB_WALK * bob
	WIGGLE_ON_SPRINTING_INTENSITY = BOB_SPRINT * bob
	WIGGLE_ON_CROUCHING_INTENSITY = BOB_CROUCH * bob
	_tilt = bool(LGSettings.get_value("play", "tilt", false))
	camera.fov = float(LGSettings.get_value("play", "fov", 75.0))
	JOY_H_SENS = float(LGSettings.get_value("play", "stick_sensitivity", 2.0))
	JOY_V_SENS = JOY_H_SENS
	_rumble = bool(LGSettings.get_value("play", "rumble", true))
	RenderingServer.global_shader_parameter_set("calm_walls", float(LGSettings.get_value("play", "calm_walls", 1.0)))


## Sets what you carry into a deck.
func load_kit(kit: Dictionary) -> void:
	for k in items:
		items[k] = int(kit.get("items", {}).get(k, 0))
	keycards.clear()
	arsenal.setup(kit.get("weapons", Progress.START_WEAPONS), kit.get("ammo", {}))
	items_changed.emit()


func kit() -> Dictionary:
	return {"weapons": arsenal.owned.duplicate(), "ammo": arsenal.reserve.duplicate(), "items": items.duplicate()}


func _physics_process(delta):
	if is_dead:
		velocity = Vector3.ZERO
		return
	if grabbed_by != null:
		_held(delta)
		return
	super(delta)
	if not _tilt:
		eyes.rotation.z = 0.0
	_shove_t -= delta
	if immune > 0.0:
		immune -= delta
	if _heal_left > 0.0:
		var h := minf(_heal_left, MEDKIT_HEAL * delta / 1.5)
		_heal_left -= h
		health = minf(max_health, health + h)
	_growth_underfoot(delta)


## Standing in thick growth slowly gets into your blood.
func _growth_underfoot(delta: float) -> void:
	if level == null or level.bloom == null or immune > 0.0:
		return
	var lvl := level.bloom.level_at(DeckLevel.cell_at(global_position))
	if lvl >= 3.0:
		add_infection(GROWTH_INFECT * (lvl - 2.0) * delta)


func _held(delta: float) -> void:
	velocity = Vector3.ZERO
	main_velocity = Vector3.ZERO
	if not is_instance_valid(grabbed_by):
		ungrab(null)
		return
	var lift := Vector3(grabbed_by.global_position.x, 1.3, grabbed_by.global_position.z) + Vector3(0, -_feet_offset, 0)
	global_position = global_position.lerp(lift, clampf(delta * 1.6, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_movement_paused or is_showing_ui:
		return
	if event.is_action_pressed("torch"):
		torch_on = not torch_on
		torch.visible = torch_on
		Sfx.ui(self, "ui_select", -12.0)
	elif event.is_action_pressed("shove"):
		shove()
	elif event.is_action_pressed("heal"):
		use_medkit()
	elif event.is_action_pressed("stim"):
		use_stim()


#region Being hurt

func take_hit(hit: Hit) -> void:
	if is_dead:
		return
	var amount := hit.amount
	if DeckScene.current:
		amount *= DeckScene.current.creature_damage()
	health -= amount
	Sfx.ui(self, "hit_player", -2.0)
	if hit.kind in [Hit.Kind.CLAW, Hit.Kind.SPIT]:
		add_infection(amount * 0.12)
	if hit.knock > 0.0 and grabbed_by == null:
		var k := hit.dir
		k.y = 0
		velocity += k.normalized() * hit.knock
	_buzz(0.6, 0.2)
	hurt.emit(amount, hit.dir)
	if health <= 0.0:
		die("killed")


## A Feeder's tendril: health out, the Bloom in.
func drain(hp: float, inf: float) -> void:
	if is_dead:
		return
	health -= hp
	if inf > 0.0:
		add_infection(inf)
	if hp > 0.0:
		hurt.emit(hp, Vector3.DOWN)
	if health <= 0.0:
		die("drained")


func add_infection(amount: float) -> void:
	if immune > 0.0 or is_dead:
		return
	infection = minf(100.0, infection + amount)
	if infection >= 100.0:
		die("taken")


func die(reason: String) -> void:
	if is_dead:
		return
	down_reason = reason
	health = 0.0
	is_dead = true
	if grabbed_by and grabbed_by.has_method("release"):
		grabbed_by.release(false)
	grabbed_by = null
	player_interaction_component.on_death()
	velocity = Vector3.ZERO
	_buzz(1.0, 0.6)
	died.emit()


## Whether this player is down (dead), for creatures.
func down() -> bool:
	return is_dead


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)

#endregion

#region Feeders

## A Feeder takes hold: returns false if something already has you.
func grab(by: Node3D) -> bool:
	if grabbed_by != null or is_dead:
		return false
	grabbed_by = by
	_grab_from = global_position
	grabbed.emit(true)
	_buzz(0.8, 0.4)
	return true


func ungrab(by: Node3D) -> void:
	if by != null and by != grabbed_by:
		return
	grabbed_by = null
	reset_physics_interpolation()
	grabbed.emit(false)

#endregion

#region What you carry

## A pickup: false if you can't carry any more of it.
func take_pickup(item: String, count: int, auto := false) -> bool:
	var base := item.get_slice(":", 0)
	var detail := item.get_slice(":", 1) if item.contains(":") else ""
	match base:
		"ammo":
			var scale := DeckScene.current.ammo_scale() if DeckScene.current else 1.0
			return arsenal.add_ammo(detail, maxi(1, roundi(count * scale)))
		"health":
			if health >= max_health:
				return false
			heal(HEALTH_TUBE * count)
			_toast("Health +%d" % int(HEALTH_TUBE * count))
			return true
		"salvage":
			if DeckScene.current:
				DeckScene.current.add_salvage(count)
			_toast("Salvage +%d" % count)
			return true
		"cell":
			if DeckScene.current:
				DeckScene.current.add_cell()
			_toast("A power cell for this deck")
			return true
		"keycard":
			if not detail in keycards:
				keycards.append(detail)
			_toast("The %s keycard" % detail)
			items_changed.emit()
			return true
		"weapon":
			if arsenal.give(detail):
				_toast(String(Arsenal.WEAPONS[detail]["name"]))
				return true
			return arsenal.add_ammo(detail, int(Arsenal.WEAPONS[detail].get("mag", 1)))
		_:
			if not items.has(base):
				return false
			var cap := carry_limit(base)
			if items[base] >= cap:
				if not auto:
					_toast("Can't carry more")
				return false
			items[base] = mini(cap, items[base] + count)
			items_changed.emit()
			_toast("%s +%d" % [base.capitalize(), count])
			return true


func carry_limit(item: String) -> int:
	return int(CARRY.get(item, 9)) + (int(POCKETS_BONUS.get(item, 0)) if Progress.has_upgrade("pockets") else 0)


func has_key(card: String) -> bool:
	return card in keycards


func use_medkit() -> void:
	if items["medkit"] <= 0 or health >= max_health or _heal_left > 0.0:
		return
	items["medkit"] -= 1
	_heal_left = MEDKIT_HEAL
	Sfx.ui(self, "heal", -4.0)
	items_changed.emit()


func use_stim() -> void:
	if items["stim"] <= 0:
		return
	items["stim"] -= 1
	infection = maxf(0.0, infection - STIM_CURE)
	immune = STIM_TIME
	Sfx.ui(self, "stim", -4.0)
	items_changed.emit()


## Hands rifle rounds to a turret; returns how many.
func give_turret_ammo(want: int) -> int:
	return arsenal.take_reserve("rifle", want)


func use_item(item: String) -> bool:
	if items.get(item, 0) <= 0:
		return false
	items[item] -= 1
	items_changed.emit()
	return true

#endregion

#region Actions

## Shoves what's in front: breaks a Feeder's grip, pushes the Taken back.
func shove() -> void:
	if _shove_t > 0.0:
		return
	_shove_t = SHOVE_TIME
	Sfx.ui(self, "shove", -4.0)
	arsenal.shove_anim()
	if grabbed_by and grabbed_by.has_method("shoved"):
		grabbed_by.shoved()
		return
	var fwd := -camera.global_transform.basis.z
	for c in get_tree().get_nodes_in_group("creatures"):
		var cr := c as Creature
		if cr == null or cr.dead:
			continue
		var to := cr.global_position + Vector3(0, 0.8, 0) - camera.global_position
		if to.length() > SHOVE_RANGE + cr.radius or fwd.dot(to.normalized()) < 0.55:
			continue
		var h := Hit.make(Hit.Kind.SHOVE, 5.0, cr.global_position + Vector3(0, 1, 0), Vector3(fwd.x, 0, fwd.z), self)
		h.knock = 6.0 if cr.height < 2.0 else 2.0
		cr.take_hit(h)
		cr.stunned = maxf(cr.stunned, 0.7)
		cr.state = Creature.State.HURT


## Spores from a burst pod: a moment's blur.
func spores(amount: float) -> void:
	add_infection(4.0 * amount)
	if DeckScene.current:
		DeckScene.current.spore_blur(amount)


## Whether creatures see you easily: the torch is on or the room is lit.
func is_seen_easily() -> bool:
	if torch_on:
		return true
	if level == null or level.bloom == null:
		return true
	var i: int = level.bloom.index.get(DeckLevel.cell_at(global_position), -1)
	return i >= 0 and level.bloom.is_lit(i)


func eye_position() -> Vector3:
	return camera.global_position


func chest_position() -> Vector3:
	return global_position + Vector3(0, 0.1 if is_crouching else 0.4, 0)


func feet_position() -> Vector3:
	return global_position + Vector3(0, _feet_offset, 0)


func aim_ray() -> Array:
	var from := camera.global_position
	return [from, -camera.global_transform.basis.z]


func _buzz(strength: float, seconds: float) -> void:
	if _rumble:
		Input.start_joy_vibration(0, strength * 0.6, strength, seconds)


func _toast(text: String) -> void:
	if DeckScene.current and DeckScene.current.hud:
		DeckScene.current.hud.toast(text)

#endregion


func _feet_height() -> float:
	var s := standing_collision_shape
	return -(s.position.y - _shape_half_height(s.shape))


static func _shape_half_height(shape: Shape3D) -> float:
	if shape is BoxShape3D:
		return shape.size.y * 0.5
	if shape is CapsuleShape3D or shape is CylinderShape3D:
		return shape.height * 0.5
	return 0.9
