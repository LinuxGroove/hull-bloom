extends RefCounted
## Deck 6, Engineering: the plant that powers the ring. Stalkers in the long
## gangway and the crawlways, the reactor with the root grown into its core,
## and the spare cells that can buy the other decks time.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 6
	d.name = "Engineering"
	d.blurb = "The reactor that powers the ring, and the crawlways over it."
	d.news = ["Stalkers", "The power plant", "Spare cells"]
	d.cells = 6
	d.hours = 4
	d.spread = 1.15
	d.seed = 606
	d.gives = "power"
	d.gives_text = "Engineering's plant: one more cell on every deck, and three spare cells to send to decks on the ring."
	d.music = "engineering"
	d.arrive = "Engineering. Reactor output is stable. Reactor temperature is above normal. My sensors report an organic obstruction in coolant loop B and in both crawlways. Sound carries on this deck. Please walk."
	d.held = "Organic obstruction cleared. Engineering is holding, and the plant is back on every deck. Three spare cells are charged. I can send them to any deck that is still answering."
	d.hatches = {"skitter": 0.5, "stalker": 0.5}
	d.max_alive = 10
	d.color = Color(1.0, 0.58, 0.18)
	return d
