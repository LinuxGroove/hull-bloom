extends RefCounted
## Deck 4, Labs: where the research team studied SV-3. Watchers float over
## the growth, the sample's containment lab can be opened to space, and
## saving the deck gives the team's prototype rail rifle.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 4
	d.name = "Labs"
	d.blurb = "The research labs, and the containment where they kept the sample."
	d.news = ["Watchers", "The sample's containment", "Venting a room"]
	d.cells = 4
	d.hours = 3
	d.spread = 1.1
	d.seed = 404
	d.gives = "rail"
	d.gives_text = "The research team's prototype rail rifle is yours."
	d.music = "labs"
	d.arrive = "Welcome to Labs. Containment C-1 reports a breach. Its emergency vent was locked out by Dr Vos at 21:14. Dr Vos has not signed in since, so the lockout has lapsed. You may vent it from the panel outside its door."
	d.held = "Organic obstruction cleared. Labs is holding. The prototype rail rifle is signed out to you. Please return it in good condition."
	d.hatches = {"skitter": 0.6, "watcher": 0.25, "stalker": 0.15}
	d.max_alive = 10
	d.color = Color(0.45, 0.7, 1.0)
	return d
