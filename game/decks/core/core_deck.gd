extends RefCounted
## Deck 8, the Core: the station's spine, where every deck's feed meets. The
## sample chamber at its centre is where SV-3 grew into the Heart, the root
## of every root on Marigold. It opens once the six middle decks are each
## saved or lost, and is never lost on its own.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 8
	d.name = "The Core"
	d.blurb = "Where every deck's feed leads: the sample chamber, and the Heart."
	d.news = ["The Heart", "Everything the Bloom has", "The end of the shift"]
	d.cells = 5
	d.hours = 0
	d.spread = 1.3
	d.seed = 808
	d.gives = ""
	d.gives_text = "The Heart of the Bloom, and the end of the shift."
	d.music = "core"
	d.arrive = "This is the Core, night shift. Every feed on Marigold leads here: water, air, power, nutrients. The organic obstruction has followed all of them. Its centre is in the sample chamber. Dr Okafor's badge is still reading in there."
	d.held = "Organic obstruction: none. Every feed is clear. Thank you, night shift. It's very quiet down here now."
	d.root_name = "the Heart"
	d.cut_banner = "THE HEART IS CUT"
	d.cut_line = "The Heart has stopped. I'm reading the obstruction go quiet on every deck, one after another. Burn out what's left down here, night shift."
	d.hatches = {"skitter": 0.4, "stalker": 0.3, "watcher": 0.15, "feeder": 0.15}
	d.max_alive = 6
	d.color = Color(0.78, 0.12, 0.1)
	return d
