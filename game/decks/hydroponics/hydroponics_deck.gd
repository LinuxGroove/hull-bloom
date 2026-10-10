extends RefCounted
## Deck 1, Hydroponics: where it started. The cutter, pods, sealing doors and
## the first root, in the seed vault behind the lab.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 1
	d.name = "Hydroponics"
	d.blurb = "Where it started: the seed lab, and the vault behind it."
	d.news = ["The plasma cutter", "Pods", "Sealing doors", "The first root"]
	d.cells = 4
	d.hours = 0
	d.spread = 0.75
	d.seed = 101
	d.gives_text = "The ring's lifts are open. Six decks, and the Bloom on every one of them."
	d.music = "hydroponics"
	d.arrive = "Good evening, night shift. Hydroponics stopped answering at 21:40. My sensors report an organic obstruction in the seed lab. Please investigate. The lift needs a power cell before it will take you anywhere."
	d.held = "Organic obstruction cleared. Hydroponics is holding. The ring's lifts are open again, but every other deck is reporting the same obstruction."
	d.hatches = {"skitter": 1.0}
	d.max_alive = 8
	d.color = Color(0.55, 0.95, 0.6)
	return d
