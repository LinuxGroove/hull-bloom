class_name Creatures
extends RefCounted
## Makes a creature by name: the Bloom's spawn, the Taken and infected robots.

const KINDS := ["skitter", "stalker", "feeder", "watcher", "taken", "eyedrone", "gundrone", "quadorb", "quadshell", "raptor", "trilobite"]


static func make(what: String, opts := {}) -> Creature:
	var c: Creature
	match what:
		"skitter":
			c = Skitter.new()
		"stalker":
			c = Stalker.new()
		"feeder":
			c = Feeder.new()
		"watcher":
			c = Watcher.new()
		"taken":
			var t := Taken.new()
			t.job = String(opts.get("job", "tech"))
			if opts.has("routine"):
				t.routine = opts["routine"]
			if opts.has("female"):
				t.female = bool(opts["female"])
			if opts.has("seed"):
				t.look_seed = int(opts["seed"])
			t.badge = String(opts.get("badge", ""))
			c = t
		_:
			if Robot.KINDS.has(what):
				var r := Robot.new()
				r.set_kind(what)
				c = r
			else:
				push_error("Creatures: no creature called %s" % what)
				c = Skitter.new()
	c.name = what.capitalize()
	return c
