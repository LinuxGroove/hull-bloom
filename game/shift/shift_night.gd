class_name ShiftNight
extends RefCounted
## A Shift night: a station built from a seed, a few decks, one night.


static func daily_seed() -> int:
	var d := Time.get_date_dict_from_system(true)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


static func start(_seed: int) -> void:
	pass
