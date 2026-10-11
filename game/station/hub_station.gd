class_name HubStation
extends UsableBody
## A saved deck's workbench (upgrades from salvage) or bunk (rest and save).
## Both only work once the deck is a safe hub.

signal opened(station: HubStation)

var kind := "workbench"


static func make(k: String) -> HubStation:
	var h := HubStation.new()
	h.kind = k
	h.name = k.capitalize()
	h.add_to_group("hub_stations")
	h._build()
	return h


func _build() -> void:
	collision_layer = Kit.LAYER_STATION | Kit.LAYER_INTERACT
	if kind == "workbench":
		display_name = "Workbench"
		Kit.model(self, "ess:Prop_Desk_Medium", Vector3.ZERO)
		# The kit's guns stand upright with the barrel along x: laid on
		# their side on the desk's top.
		var gun := Kit.model(self, "ess:Gun_Shotgun", Vector3(-0.6, 0.0, 0.1), 0.4)
		gun.rotation.x = PI * 0.5
		gun.position.y = 0.95 - Kit.aabb_of(gun).position.y
		Kit.model(self, "ess:Prop_Ammo_Small", Vector3(0.7, 0.94, 0.0), -0.3)
		Kit.model(self, "ess:Prop_Screen", Vector3(0.05, 0.94, -0.3))
		add_box(Vector3(0, 0.47, 0), Vector3(2.8, 0.94, 1.0))
		add_action("interact", "Use the workbench", _use)
	else:
		display_name = "Bunk"
		Kit.model(self, "Prop_Pod_Short", Vector3.ZERO)
		add_box(Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 2.0))
		add_action("interact", "Rest", _use)


func _use(pic: Node) -> void:
	if DeckScene.current == null or not DeckScene.current.hub:
		UsableBody.hint(pic, "Not while the Bloom is still here")
		return
	opened.emit(self)
