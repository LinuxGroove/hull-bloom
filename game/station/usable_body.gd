class_name UsableBody
extends AnimatableBody3D
## Something in the level the player can use: a door, switch, note, pick-up.
## Cogito's interaction raycast finds it (group "interactable", layer 2) and
## shows a prompt for each of its actions.

## Read by Cogito's interaction component and HUD.
var interaction_nodes: Array[Node] = []
var display_name := ""


func _init() -> void:
	collision_layer = Kit.LAYER_STATION | Kit.LAYER_INTERACT
	collision_mask = 0
	sync_to_physics = false
	add_to_group("interactable")


## Adds an action under `input` ("interact" or "interact2").
func add_action(input: String, text: String, on_use: Callable) -> UseAction:
	var a := UseAction.new()
	a.name = "Use_" + input
	a.input_map_action = input
	a.interaction_text = text
	a.on_use = on_use
	add_child(a)
	interaction_nodes.append(a)
	return a


func action(input: String) -> UseAction:
	for a in interaction_nodes:
		if a.input_map_action == input:
			return a
	return null


## Changes an action's prompt text (or hides it with ""), and refreshes the
## prompt if the player is looking at this.
func set_action_text(input: String, text: String) -> void:
	var a := action(input)
	if a == null:
		return
	a.interaction_text = text
	a.is_disabled = text == ""
	refresh_prompt()


func refresh_prompt() -> void:
	if not is_inside_tree():
		return
	for p in get_tree().get_nodes_in_group("tech"):
		var pic: PlayerInteractionComponent = p.player_interaction_component
		if pic and pic.interactable == self:
			pic._rebuild_interaction_prompts()


## A box collider, in this body's space.
func add_box(center: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	add_child(cs)
	return cs


## Says something short on the player's screen (Cogito's hint line).
static func hint(pic: Node, text: String) -> void:
	if pic and pic.has_method("send_hint"):
		pic.send_hint(null, text)
