class_name Bulkhead
extends Node3D
## A bulkhead between two tiles: the kit's door frame and two leaves that
## slide apart. Opening and closing is free; sealing one takes a power cell
## from the deck, and the Bloom can't get through a sealed door (it creeps
## slowly past a closed one). Creatures that can open doors open shut,
## unsealed ones. Locked doors need their keycard, jammed ones are stuck open,
## and doors into a vented room are shut for good.
##
## The leaves open and close it; the panel on the frame seals and unseals.

signal changed(door: Bulkhead)

const FRAME := "Door_Frame_Square"
const LEAF := "Door_Metal"
## How far each leaf slides to open.
const SLIDE := 2.08
const OPEN_TIME := 0.6
const UNSEAL_TIME := 1.2

const LAMP_OPEN := Color(0.3, 1.0, 0.45)
const LAMP_SHUT := Color(1.0, 0.7, 0.2)
const LAMP_SEALED := Color(1.0, 0.15, 0.1)
const LAMP_LOCKED := Color(0.3, 0.55, 1.0)

var key := ""
var a: Vector2i
var b: Vector2i
var level: DeckLevel
## The Bloom's link for this door.
var link_id := -1
var is_open := false
var sealed := false
## A keycard id that opens it, or "".
var locked := ""
var jammed := false
var airless := false
## Asked when sealing (true) or unsealing (false): returns whether a cell was
## taken or given back. Set by the deck's run; without it sealing is free.
var power := Callable()
## Asked when the player tries a locked door: returns whether they have the card.
var has_key := Callable()
## Read by the HUD: what happened last ("Needs the lab keycard").
var last_message := ""

var _leaves: Array[UsableBody] = []
var _panel: UsableBody
var _lamps: Array[MeshInstance3D] = []
var _t := 0.0
var _unsealing := 0.0
var _along := Vector3.RIGHT


## Builds the door for an edge of `lvl` ([member DeckLevel.ways] entry `w`).
static func make(lvl: DeckLevel, edge: String, w: Dictionary) -> Bulkhead:
	var d := Bulkhead.new()
	d.name = "Door_" + edge.replace(",", "_").replace("|", "-")
	d.key = edge
	d.level = lvl
	d.a = w["a"]
	d.b = w["b"]
	d.link_id = int(w.get("link", -1))
	d.sealed = bool(w.get("sealed", false))
	d.locked = String(w.get("locked", ""))
	d.jammed = bool(w.get("jammed", false))
	d.is_open = bool(w.get("open", false)) or d.jammed
	var mid := (DeckLevel.center(d.a) + DeckLevel.center(d.b)) * 0.5
	d.position = mid
	# The frame's width runs along its X: across the corridor between the tiles.
	if d.a.x != d.b.x:
		d.rotation.y = PI * 0.5
	d._build()
	return d


func _build() -> void:
	Kit.model(self, FRAME, Vector3.ZERO)
	# The frame's posts and lintel, as boxes.
	for side in [-1.0, 1.0]:
		Kit.block(self, Vector3(side * 2.3, Kit.HEIGHT * 0.5, 0), Vector3(0.3, Kit.HEIGHT, 0.5))
	Kit.block(self, Vector3(0, 4.55, 0), Vector3(4.9, 0.9, 0.5))
	for i in 2:
		var leaf := UsableBody.new()
		leaf.name = "Leaf%d" % i
		leaf.collision_layer = Kit.LAYER_DOORS | Kit.LAYER_INTERACT
		leaf.display_name = "Bulkhead"
		add_child(leaf)
		var m := Kit.model(leaf, LEAF, Vector3.ZERO)
		if i == 1:
			m.rotation.y = PI
		leaf.add_box(Vector3(-1.05 if i == 0 else 1.05, 2.02, 0), Vector3(2.1, 4.05, 0.2))
		leaf.add_action("interact", "Open", _use_leaf)
		_leaves.append(leaf)
	_panel = UsableBody.new()
	_panel.name = "Panel"
	_panel.display_name = "Door panel"
	add_child(_panel)
	_panel.position = Vector3(2.3, 1.35, 0)
	_panel.add_box(Vector3.ZERO, Vector3(0.34, 0.5, 0.9))
	_panel.add_action("interact", "Seal", _use_panel)
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.22, 0.3)
		lamp.mesh = q
		lamp.position = Vector3(0, 0.05, side * 0.27)
		lamp.rotation.y = 0.0 if side > 0 else PI
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_panel.add_child(lamp)
		_lamps.append(lamp)
	_t = 1.0 if is_open else 0.0
	_place_leaves()
	_refresh()


func _physics_process(delta: float) -> void:
	var want := 1.0 if is_open else 0.0
	if _t != want:
		_t = move_toward(_t, want, delta / OPEN_TIME)
		_place_leaves()
	if _unsealing > 0.0:
		_unsealing -= delta
		if _unsealing <= 0.0:
			_unsealing = 0.0
			_finish_unseal()


func _place_leaves() -> void:
	var e := _t * _t * (3.0 - 2.0 * _t)
	_leaves[0].position = Vector3(-SLIDE * e, 0, 0)
	_leaves[1].position = Vector3(SLIDE * e, 0, 0)
	for l in _leaves:
		# Open leaves are in the frame, out of the way of the use ray.
		l.collision_layer = Kit.LAYER_DOORS | (Kit.LAYER_INTERACT if _t < 0.5 else 0)
		if _t > 0.9:
			l.collision_layer = 0


## Whether something can walk through right now.
func passable() -> bool:
	return _t > 0.85


## Opens or closes it. Returns false if it won't (sealed, locked, jammed, airless).
func set_open(open: bool, by_player := false) -> bool:
	if open == is_open:
		return true
	if open and (sealed or airless):
		return false
	if open and locked != "" and not by_player:
		return false
	if not open and jammed:
		return false
	is_open = open
	_sound("door_open" if open else "door_close")
	_refresh()
	return true


## A creature tries the door: opens it unless it's sealed, locked or airless.
func creature_open() -> bool:
	if sealed or airless or locked != "":
		return false
	return set_open(true)


## Seals it (shutting it first). Returns false if no cell is free.
func seal() -> bool:
	if sealed or jammed or airless:
		return false
	if power.is_valid() and not power.call(true):
		last_message = "No free power cell to seal it"
		return false
	is_open = false
	sealed = true
	_sound("door_seal")
	_refresh()
	return true


## Unsealing takes a moment, and gives the cell back.
func unseal() -> void:
	if not sealed or airless or _unsealing > 0.0:
		return
	_unsealing = UNSEAL_TIME
	_sound("door_unseal")
	_refresh()


func _finish_unseal() -> void:
	sealed = false
	if power.is_valid():
		power.call(false)
	_refresh()


## The room on the far side was vented: shut, and staying shut.
func make_airless() -> void:
	if sealed and power.is_valid():
		power.call(false)
	sealed = false
	jammed = false
	is_open = false
	airless = true
	_refresh()


func _use_leaf(_pic: Node) -> void:
	last_message = ""
	if airless:
		last_message = "Airless on the other side"
	elif sealed:
		last_message = "Sealed. Unseal it at the panel"
	elif locked != "":
		if has_key.is_valid() and has_key.call(locked):
			locked = ""
			set_open(true, true)
		else:
			last_message = "Locked. It needs the %s keycard" % locked
	else:
		set_open(not is_open, true)
	if last_message != "":
		_sound("door_denied")
		UsableBody.hint(_pic, last_message)
	_refresh()


func _use_panel(_pic: Node) -> void:
	last_message = ""
	if airless:
		last_message = "Airless on the other side"
	elif sealed:
		unseal()
	elif jammed:
		last_message = "Jammed open"
	elif is_open:
		set_open(false, true)
	elif not seal():
		pass
	if last_message != "":
		_sound("door_denied")
		UsableBody.hint(_pic, last_message)
	_refresh()


func _refresh() -> void:
	if level and level.bloom and link_id >= 0:
		var st := Bloom.Door.CLOSED
		if sealed or airless:
			st = Bloom.Door.SEALED
		elif is_open:
			st = Bloom.Door.OPEN
		level.bloom.set_door(link_id, st)
	var color := LAMP_OPEN if is_open else LAMP_SHUT
	if sealed or airless:
		color = LAMP_SEALED
	elif locked != "":
		color = LAMP_LOCKED
	for l in _lamps:
		l.material_override = Kit.flat(color * 0.4, 0.4, color, 2.5)
	if _leaves.is_empty():
		return
	var leaf_text := "Open" if not is_open else "Close"
	if airless:
		leaf_text = "Airless"
	elif sealed:
		leaf_text = "Sealed"
	elif locked != "":
		leaf_text = "Locked"
	for l in _leaves:
		l.set_action_text("interact", leaf_text)
	var panel_text := "Seal (1 cell)"
	if airless:
		panel_text = "Airless"
	elif _unsealing > 0.0:
		panel_text = "Unsealing..."
	elif sealed:
		panel_text = "Unseal"
	elif jammed:
		panel_text = "Jammed open"
	elif is_open:
		panel_text = "Close"
	_panel.set_action_text("interact", panel_text)
	changed.emit(self)


func _sound(id: String) -> void:
	if is_inside_tree():
		Sfx.at(self, id, global_position + Vector3(0, 2, 0), -4.0)
