class_name UseAction
extends InteractionComponent
## One thing the player can do to a [UsableBody], shown in Cogito's prompt
## (like "F  Open"). Calls `on_use` with the player's interaction component.

var on_use := Callable()


func interact(pic: PlayerInteractionComponent) -> void:
	if on_use.is_valid():
		on_use.call(pic)
	was_interacted_with.emit(interaction_text, input_map_action)
