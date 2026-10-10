extends RefCounted
## Deck 5, Security: the station's own robots with the Bloom in their joints,
## turret mounts to power, and the gun locker behind the chief's keycard.
## Saving it puts the turrets on every deck on their own power.


static func make() -> DeckDef:
	var d := DeckDef.new()
	d.number = 5
	d.name = "Security"
	d.blurb = "The checkpoint, the brig, the armoury and the robot bay."
	d.news = ["Infected robots", "Turrets of your own", "The gun locker"]
	d.cells = 5
	d.hours = 4
	d.spread = 1.0
	d.seed = 505
	d.gives = "turrets"
	d.gives_text = "Security's turrets run on their own now, on every deck."
	d.music = "security"
	d.arrive = "Security is in lockdown, by order of Chief Kessler. The security units are holding their posts. Please wear your badge. The turret mounts will take a power cell each. The armoury is locked to the chief's card."
	d.held = "Organic obstruction cleared. Security is holding. The lockdown is lifted. The turrets have been told you are a friend."
	d.hatches = {"skitter": 0.7, "stalker": 0.3}
	d.max_alive = 9
	d.color = Color(1.0, 0.35, 0.3)
	return d
