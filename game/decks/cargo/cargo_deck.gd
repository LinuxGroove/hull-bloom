extends RefCounted
## Deck 7, Cargo and docking: two big loading bays with the root in the
## second, bay security's Raptors still on patrol, Stalkers among the
## crates, and the shuttle Corran fuelled in the dock: the way off Marigold.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 7
	d.name = "Cargo and docking"
	d.blurb = "The loading bays and the dock, where the shuttle waits for clearance."
	d.news = ["Big open bays", "Raptors", "The shuttle out"]
	d.cells = 5
	d.hours = 5
	d.spread = 1.2
	d.seed = 707
	d.gives = "shuttle"
	d.gives_text = "The shuttle is fuelled and waiting at Cargo's dock."
	d.music = "cargo"
	d.arrive = "Cargo and docking. The shuttle Corran is fuelled and waiting for clearance. I have not given clearance: there is an organic obstruction in loading bay 2. Bay security is still on its rounds. Please carry your badge."
	d.held = "Organic obstruction cleared. Cargo is holding. The Corran is cleared to leave from the dock whenever you are ready. I will keep her engines warm."
	d.hatches = {"skitter": 0.5, "stalker": 0.3, "feeder": 0.2}
	d.max_alive = 11
	d.color = Color(1.0, 0.84, 0.2)
	return d
