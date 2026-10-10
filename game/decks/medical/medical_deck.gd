extends RefCounted
## Deck 3, Medical: where the first patients came from hydroponics, what the
## Bloom does to a body, the feeders on the ceilings, the morgue that won't
## stay still, and the pharmacy's stims.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 3
	d.name = "Medical"
	d.blurb = "Triage, the ward, the morgue and a quarantine nobody was meant to open."
	d.news = ["Feeders", "What the Bloom does to a body", "Stims"]
	d.cells = 4
	d.hours = 3
	d.spread = 1.0
	d.seed = 303
	d.gives = "stims"
	d.gives_text = "Medical's stores: every deck starts you with two stims and two medkits."
	d.music = "medical"
	d.arrive = "Medical. Admissions tonight: fourteen. Discharges: none. The quarantine ward is sealed and reports organic obstruction. The morgue reports more occupants than it did an hour ago. Please take a stim if you feel unwell."
	d.held = "Organic obstruction cleared. Medical is holding. The pharmacy's stores are yours, and I have reset the morgue's count."
	d.hatches = {"skitter": 0.7, "feeder": 0.3}
	d.max_alive = 9
	d.color = Color(0.62, 0.92, 0.88)
	return d
