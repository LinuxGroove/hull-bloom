class_name HowToPlay
extends RefCounted
## How to play, a page at a time: [title, [paragraphs]]. Moves are named by
## what they do, not by a button.

const PAGES := [
	["The Bloom", [
		"The Bloom is a growth. It lives on the station's floor tiles, and every few seconds it creeps on through open doors, vents and cable runs. Dark, warm rooms feed it; lit ones slow it.",
		"Thick growth sprouts pods, and pods hatch things. Shooting what hatches only buys time: the pods keep coming while the growth is there.",
		"A body left on thick growth gets up again.",
	]],
	["The plasma cutter", [
		"The cutter is the only thing that burns growth back. Hold Fire and sweep it over the floor and walls; the growth chars and shrinks a level at a time.",
		"It heats up. Let go before it overheats, or wait while it cools. Aim to focus the beam: it reaches further and takes limbs off.",
		"Your guns are for what hatches. Tap Swap to go back to the last one you held, or hold it for the weapon wheel, point at a gun and let go. Hold Throw to pick a flare, grenade or mine.",
	]],
	["Power", [
		"Each deck has a few power cells. Lights, sealed doors, turrets and the lift each take one, and the lift won't take you anywhere until you've powered it at its console.",
		"Open the deck map to see where the growth is and to switch rooms' lights. A sealed door stops the growth dead, and stops you too.",
		"Some rooms can be opened to space. Everything inside goes, growth and all, and the room stays airless.",
	]],
	["Holding a deck", [
		"Every deck's growth feeds from a root. Find it, burn it out, and the growth stops feeding. What's left dies back on its own in a minute or so; burn it to hurry it along.",
		"A deck is held when its root is gone and nothing thick is left. Survivors you find follow you; bring them to the lift.",
		"A held deck is safe: its workbench turns salvage into upgrades, and its bunk heals you.",
	]],
	["The ring", [
		"Marigold is a ring of decks round the Core. Each visit to a deck takes an hour of the shift, and while you're away the others grow. A deck left too long is lost to the Bloom.",
		"Each deck you save gives something the others need. Lost decks can be taken back, and still give it, but they come back overgrown.",
		"When every deck is saved or lost, the Core opens.",
	]],
	["Comfort and gore", [
		"Head bob and view roll are off unless you turn them on. Calm walls slows or stops the growth's breathing, and the spore blur can be switched off.",
		"Gore can be Full, Less (no limbs coming off, dark ichor, nobody getting up again in front of you) or Off. A four digit code locks the setting.",
	]],
]
