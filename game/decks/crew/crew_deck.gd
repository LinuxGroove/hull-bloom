extends RefCounted
## Deck 2, Crew quarters: where the crew slept, ate and washed. The Taken
## still walk their rounds, the lights hold the growth back, and three of the
## crew are hiding: the first survivors.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 2
	d.name = "Crew quarters"
	d.blurb = "Bunks, the galley and the laundry. Some of the crew are still walking their rounds."
	d.news = ["The Taken", "Lights against the growth", "The first survivors"]
	d.cells = 4
	d.hours = 2
	d.spread = 1.0
	d.seed = 202
	d.gives = "survivors"
	d.gives_text = "The crew's roll call: MARI marks every survivor on the deck map, found or not."
	d.music = "crew"
	d.arrive = "Crew quarters. Most of the crew are up and moving through their rooms on their usual schedules. None of them answer me. Organic obstruction in the laundry. Lit rooms report slower obstruction."
	d.held = "Organic obstruction cleared. Crew quarters is holding. I have restarted the roll call. Several names are not answering, and several are answering from the wrong rooms."
	d.hatches = {"skitter": 1.0}
	d.max_alive = 5
	d.color = Color(1.0, 0.72, 0.32)
	return d
