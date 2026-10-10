class_name StationThings
extends RefCounted
## Builds the things a deck's level places (see [method DeckLevel.thing]):
## pickups, logs, bodies, survivors, spawn points, turrets, vent panels and a
## saved deck's workbench and bunk.

static func make(kind: String, level: DeckLevel, pos: Vector3, yaw: float, opts: Dictionary) -> Node3D:
	var n: Node3D = null
	match kind:
		"pickup":
			n = Pickup.make(String(opts.get("item", "ammo")), int(opts.get("count", 1)))
		"log":
			n = LogTerminal.make(opts)
		"body":
			n = CrewBody.make(level, opts)
		"survivor":
			n = Survivor.make(level, opts)
		"spawn":
			n = SpawnPoint.make(opts)
		"turret":
			n = Turret.make(opts)
		"vent_panel":
			n = VentPanel.make(level, String(opts.get("room", "")))
		"workbench", "bunk":
			n = HubStation.make(kind)
	if n:
		n.position = pos
		n.rotation.y = yaw
	return n
