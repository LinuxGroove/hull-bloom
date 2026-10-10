class_name DeckLevel
extends Node3D
## A deck of Marigold Station, laid out in code on the kit's 4 m grid. A deck's
## level extends this and lays it out in [method build]: rooms and corridors
## of tiles, the doors, arches, windows, vents and cable runs between them,
## the lift, the Bloom's root, and everything in the rooms. Then
## [method finish] builds it: the kit's floors, walls and ceilings, doors,
## lights, collision, the Bloom's grid ([member bloom]) and its growth.
##
## Tiles are Vector2i(x, z); tile (x, z) is centred on (x * 4, 0, z * 4). X
## runs east and Z south. Sides are W (-x), N (-z), E (+x) and S (+z).
## Everything a level adds can be read back without building (tests do), and
## [method finish] adds the nodes.

## A wall piece's yaw for each side of its tile.
const SIDES := {"W": 0.0, "S": PI * 0.5, "E": PI, "N": -PI * 0.5}
const STEP := {"W": Vector2i(-1, 0), "N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1)}
const SIDE_ORDER := ["W", "N", "E", "S"]

## The look of a room: kit families for the walls and their upper parts, the
## floor and ceiling plates, and the colour of its lights when powered.
const STYLES := {
	"corridor": {"wall": ["WallBand_Straight"], "top": "TopCables_Straight", "floor": "Platform_DarkPlates", "ceiling": "Platform_Simple", "trim": "BottomMetal_Straight", "light": Color(0.85, 0.92, 1.0)},
	"lab": {"wall": ["WallWideBand_Straight", "WallWideBand_Straight_TallBand"], "top": "TopPlates_Straight", "floor": "Platform_Simple2", "ceiling": "Platform_Simple", "trim": "BottomSimple_Straight", "light": Color(0.9, 0.96, 1.0)},
	"hydro": {"wall": ["WallPipe_Straight", "WallBand_Straight"], "top": "TopCables_Straight", "floor": "Platform_Squares", "ceiling": "Platform_Simple", "trim": "BottomMetal_Straight", "light": Color(0.85, 1.0, 0.8)},
	"crew": {"wall": ["WallPadded_Straight"], "top": "TopPadded_Flat_Straight", "floor": "Platform_Padded", "ceiling": "Platform_Simple", "trim": "", "light": Color(1.0, 0.9, 0.78)},
	"medical": {"wall": ["WallWideBand_Straight"], "top": "TopPlastic_Straight", "floor": "Platform_Simple2", "ceiling": "Platform_Simple", "trim": "BottomSimple_Straight", "light": Color(0.88, 1.0, 0.98)},
	"security": {"wall": ["WallAstra_Straight_Flat", "WallBand_Straight"], "top": "TopPlates_Straight", "floor": "Platform_RedAccent", "ceiling": "Platform_DarkPlates", "trim": "BottomAccent_Straight", "light": Color(1.0, 0.92, 0.88)},
	"engine": {"wall": ["WallPipe_Straight"], "top": "TopCables_Straight", "floor": "Platform_Metal", "ceiling": "Platform_DarkPlates", "trim": "BottomMetal_Straight", "light": Color(1.0, 0.85, 0.62)},
	"cargo": {"wall": ["WallBand_Straight", "WallPipe_Straight"], "top": "TopSimple_Straight", "floor": "Platform_3Plates", "ceiling": "Platform_Metal2", "trim": "BottomAccent_Straight", "light": Color(1.0, 0.95, 0.85)},
	"core": {"wall": ["WallAstra_Straight_Flat"], "top": "TopAstra_Straight", "floor": "Platform_CenterPlate", "ceiling": "Platform_DarkPlates", "trim": "BottomAccent_Straight", "light": Color(0.82, 0.88, 1.0)},
	"window": {"wall": ["WallWindow_Straight"], "top": "TopWindow_Straight", "floor": "Platform_Metal2", "ceiling": "Platform_Simple", "trim": "", "light": Color(0.85, 0.92, 1.0)},
}

## Kinds of thing a level can place (see [method thing]).
const THINGS := ["prop", "pickup", "log", "body", "survivor", "spawn", "turret", "vent_panel", "workbench", "bunk", "column", "decal", "light"]

## Set by whoever builds the level.
var deck: DeckDef
## The deck as it comes back after being lost: grown over, its root a heart.
var overgrown := false
## Shift mode and tests: everything that's placed at random uses this.
var rng := RandomNumberGenerator.new()

## Tile -> room id.
var tiles := {}
## Room id -> {"name", "style", "cells": [Vector2i], "dark": bool, "warm": float, "vent": bool}.
var rooms := {}
var room_ids: Array[String] = []
## Edge key -> {"a", "b", "kind": "door" | "arch" | "window", ...options}.
var ways := {}
## [a, b] pairs: vents (the Bloom and small creatures) and cable runs (the
## Bloom only, slowly). Any two tiles.
var vents: Array = []
var cables: Array = []
var lift_cell := Vector2i.ZERO
var lift_side := "N"
var root_cells: Array[Vector2i] = []
## Starting growth: tile -> level.
var start_growth := {}
## [kind, cell, offset (Vector3 from the tile's centre), yaw (radians), options].
var things: Array = []
## Screenshot spots: name -> [position, yaw (degrees), pitch (degrees)].
var views := {}
## The Bloom's grid, made by [method make_bloom].
var bloom: Bloom
## Door edge key -> Bulkhead node, once finished.
var doors := {}
## Room id -> [OmniLight3D] lit when the room's power is on.
var room_lights := {}
var built := false

var _default_style := "corridor"
var _static: Node3D
var _collision: Node3D


## Lay the deck out here (rooms, ways, things), then call [method finish] or
## leave it to whoever builds it.
func build() -> void:
	pass


## Called after the geometry is built, for anything a deck adds by hand.
func decorate() -> void:
	pass


func _init() -> void:
	rng.seed = 1


#region Laying out

## Sets the style rooms get when they don't name one.
func default_style(style: String) -> void:
	_default_style = style


## A rectangular room: `rect` in tiles (x, z, width, depth).
func room(id: String, name: String, rect: Rect2i, style := "", opts := {}) -> void:
	var cells: Array[Vector2i] = []
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, z))
	room_cells(id, name, cells, style, opts)


## A room of any shape. Options: "dark" (its lights are broken), "warm"
## (the Bloom grows faster here: 1.5 for damp hydroponics), "vent" (it can
## be opened to space), "cold" (slower, 0.7).
func room_cells(id: String, name: String, cells: Array, style := "", opts := {}) -> void:
	if not rooms.has(id):
		rooms[id] = {"name": name, "style": style if style != "" else _default_style, "cells": [] as Array[Vector2i],
			"dark": opts.get("dark", false), "warm": float(opts.get("warm", 1.0)), "vent": opts.get("vent", false)}
		room_ids.append(id)
	for c in cells:
		if tiles.has(c) and tiles[c] != id:
			push_error("%s: tile %s is in both %s and %s" % [_name(), c, tiles[c], id])
			continue
		tiles[c] = id
		rooms[id]["cells"].append(c)


## A straight corridor from one tile to another, both included.
func corridor(id: String, name: String, from: Vector2i, to: Vector2i, style := "corridor", opts := {}) -> void:
	var cells: Array[Vector2i] = []
	var d := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	if d.x != 0 and d.y != 0:
		push_error("%s: corridor %s isn't straight" % [_name(), id])
		return
	var c := from
	cells.append(c)
	while c != to:
		c += d
		cells.append(c)
	room_cells(id, name, cells, style, opts)


## A bulkhead between two neighbouring tiles. Options: "sealed" (sealed when
## the deck starts, costing no cell), "locked" (a keycard id that opens it),
## "jammed" (stuck open), "open" (starts open).
func door(a: Vector2i, b: Vector2i, opts := {}) -> void:
	_way(a, b, "door", opts)


## An open way between neighbouring tiles of different rooms, with no door.
func arch(a: Vector2i, b: Vector2i) -> void:
	_way(a, b, "arch", {})


## A window between neighbouring tiles: you can see through, not walk.
func window(a: Vector2i, b: Vector2i) -> void:
	_way(a, b, "window", {})


## A vent duct between any two tiles: the Bloom spreads through it, and
## skitters crawl out of it. Its grilles show on both ceilings.
func vent(a: Vector2i, b: Vector2i) -> void:
	vents.append([a, b])


## A cable run between any two tiles: the Bloom creeps along it, slowly.
func cable(a: Vector2i, b: Vector2i) -> void:
	cables.append([a, b])


## The lift: where you arrive and how you leave. It stands against the
## tile's `side` wall.
func lift(cell: Vector2i, side := "N") -> void:
	lift_cell = cell
	lift_side = side


## The Bloom's root on this deck: a nest with a heart in it.
func root(cell: Vector2i) -> void:
	root_cells.append(cell)


## Starting growth: a level for a tile, or for every tile of a room.
func grow(cell: Vector2i, level: float) -> void:
	start_growth[cell] = level


func grow_room(id: String, level: float) -> void:
	for c in rooms[id]["cells"]:
		start_growth[c] = level


## Places a thing. `kind` is one of [constant THINGS]; `offset` is from the
## tile's centre (y up); `yaw` in degrees. Options depend on the kind:
## - prop: "name" (a kit model), "solid" (default true), "scale".
## - pickup: "item": "ammo", "medkit", "health", "stim", "cell", "salvage",
##   "flare", "grenade", "mine", "keycard:<id>", "weapon:<id>"; "count".
## - log: "id", "title", "text" (several paragraphs, \n between), "by".
## - body: a dead crew member ("job" for the suit's colour); on grown tiles
##   they get up again.
## - survivor: "id", "name", "line" (what they say when found), "job".
## - spawn: "what" (skitter, stalker, feeder, watcher, pod, taken, eyedrone,
##   gundrone, quadorb, quadshell, raptor, trilobite), "count", "asleep".
## - turret: a mount; power it to hold a corridor.
## - vent_panel: "room" (the room it vents).
## - workbench, bunk: a saved deck's hub.
## - column: "name" (a kit column).
## - decal: "name" (a kit decal), lies on the floor.
## - light: an extra emergency light, "color".
func thing(kind: String, cell: Vector2i, offset := Vector3.ZERO, yaw := 0.0, opts := {}) -> void:
	if not kind in THINGS:
		push_error("%s: no thing called %s" % [_name(), kind])
		return
	things.append([kind, cell, offset, deg_to_rad(yaw), opts])


## Shorthands for the common things.
func prop(name: String, cell: Vector2i, offset := Vector3.ZERO, yaw := 0.0, opts := {}) -> void:
	var o := opts.duplicate()
	o["name"] = name
	thing("prop", cell, offset, yaw, o)


func pickup(item: String, cell: Vector2i, offset := Vector3.ZERO, count := 1) -> void:
	thing("pickup", cell, offset, 0.0, {"item": item, "count": count})


func log_entry(id: String, title: String, text: String, cell: Vector2i, offset := Vector3.ZERO, yaw := 0.0, by := "") -> void:
	thing("log", cell, offset, yaw, {"id": id, "title": title, "text": text, "by": by})


func spawn(what: String, cell: Vector2i, offset := Vector3.ZERO, count := 1, opts := {}) -> void:
	var o := opts.duplicate()
	o["what"] = what
	o["count"] = count
	thing("spawn", cell, offset, 0.0, o)


func survivor(id: String, name: String, cell: Vector2i, line: String, offset := Vector3.ZERO, yaw := 0.0, job := "tech") -> void:
	thing("survivor", cell, offset, yaw, {"id": id, "name": name, "line": line, "job": job})


func body(cell: Vector2i, offset := Vector3.ZERO, yaw := 0.0, job := "tech") -> void:
	thing("body", cell, offset, yaw, {"job": job})


## A screenshot spot: the eye's position, facing (yaw in degrees, 0 looking
## north, 90 west) and pitch (degrees, up positive).
func view(name: String, pos: Vector3, yaw := 0.0, pitch := -5.0) -> void:
	views[name] = [pos, yaw, pitch]


func _way(a: Vector2i, b: Vector2i, kind: String, opts: Dictionary) -> void:
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		push_error("%s: %s between %s and %s, which aren't neighbours" % [_name(), kind, a, b])
		return
	var w := opts.duplicate()
	w["a"] = a
	w["b"] = b
	w["kind"] = kind
	ways[edge_key(a, b)] = w

#endregion

#region Reading the layout

static func edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a
		a = b
		b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


static func center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * Kit.TILE, 0.0, cell.y * Kit.TILE)


static func cell_at(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / Kit.TILE), roundi(pos.z / Kit.TILE))


## The world position of a thing's spot.
static func spot(cell: Vector2i, offset: Vector3) -> Vector3:
	return center(cell) + offset


func room_at(pos: Vector3) -> String:
	return tiles.get(cell_at(pos), "")


func room_name(id: String) -> String:
	return String(rooms[id]["name"]) if rooms.has(id) else ""


## Whether you can walk from one tile to its neighbour (same room, an arch,
## or a door; `doors_open` false counts doors as shut).
func walkable(a: Vector2i, b: Vector2i, doors_open := true) -> bool:
	if not tiles.has(a) or not tiles.has(b):
		return false
	if tiles[a] == tiles[b]:
		return true
	var w: Dictionary = ways.get(edge_key(a, b), {})
	match String(w.get("kind", "")):
		"arch":
			return true
		"door":
			return doors_open or bool(w.get("jammed", false))
	return false


## Every tile you can walk to from `from`.
func reachable(from: Vector2i, doors_open := true) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for s in SIDE_ORDER:
			var n: Vector2i = c + STEP[s]
			if not seen.has(n) and walkable(c, n, doors_open):
				seen[n] = true
				queue.append(n)
	return seen


## The way from one tile to another for something walking: each step is
## [tile, "walk" | "door" | "vent"], not counting `from`. Shut doors count if
## it can open them; sealed, locked and airless ones never do. Empty if
## there's no way.
func tile_path(from: Vector2i, to: Vector2i, opens_doors := false, uses_vents := false) -> Array:
	if from == to or not tiles.has(from) or not tiles.has(to):
		return []
	var came := {from: null}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var found := false
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == to:
			found = true
			break
		for step in _steps_from(c, opens_doors, uses_vents):
			var n: Vector2i = step[0]
			if not came.has(n):
				came[n] = [c, step[1]]
				queue.append(n)
	if not found:
		return []
	var out := []
	var at := to
	while at != from:
		var back: Array = came[at]
		out.push_front([at, back[1]])
		at = back[0]
	return out


func _steps_from(c: Vector2i, opens_doors: bool, uses_vents: bool) -> Array:
	var out := []
	for s in SIDE_ORDER:
		var n: Vector2i = c + STEP[s]
		if not tiles.has(n):
			continue
		if tiles[n] == tiles[c]:
			out.append([n, "walk"])
			continue
		var key := edge_key(c, n)
		var w: Dictionary = ways.get(key, {})
		match String(w.get("kind", "")):
			"arch":
				out.append([n, "walk"])
			"door":
				if doors.has(key):
					var d: Bulkhead = doors[key]
					if d.passable() or (opens_doors and not d.sealed and not d.airless and d.locked == "" and not d.is_open):
						out.append([n, "door"])
					elif d.is_open:
						out.append([n, "door"])
				elif w.get("open", false) or w.get("jammed", false) or (opens_doors and not w.get("sealed", false) and String(w.get("locked", "")) == ""):
					out.append([n, "door"])
	if uses_vents:
		for v in vents:
			if v[0] == c:
				out.append([v[1], "vent"])
			elif v[1] == c:
				out.append([v[0], "vent"])
	return out


## The tile bounds: Rect2i covering every tile.
func bounds() -> Rect2i:
	var r := Rect2i()
	var first := true
	for c in tiles:
		if first:
			r = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			r = r.expand(c).expand(c + Vector2i.ONE)
	return r


## The things of one kind.
func things_of(kind: String) -> Array:
	var out := []
	for t in things:
		if t[0] == kind:
			out.append(t)
	return out


## The lift's spot: where the player stands on arrival, facing out.
func start_transform() -> Transform3D:
	var c := center(lift_cell)
	var back := Vector3(STEP[lift_side].x, 0, STEP[lift_side].y)
	var pos := c + back * 0.6 + Vector3(0, Lift.TOP + 0.05, 0)
	var look := -back
	return Transform3D(Basis.looking_at(look, Vector3.UP), pos)

#endregion

#region The Bloom

## The Bloom's grid from the layout: a tile for each tile, links for each
## way through, and the starting growth. Overgrown decks start grown over.
func make_bloom(seed := -1) -> Bloom:
	var b := Bloom.new(seed if seed >= 0 else (deck.seed if deck else 1))
	for id in room_ids:
		var r: Dictionary = rooms[id]
		for c in r["cells"]:
			b.add_tile(c, id, float(r["warm"]))
	for c in tiles:
		for s in ["E", "S"]:
			var n: Vector2i = c + STEP[s]
			if not tiles.has(n):
				continue
			if tiles[c] == tiles[n]:
				b.link(c, n, Bloom.Kind.OPEN)
				continue
			var w: Dictionary = ways.get(edge_key(c, n), {})
			match String(w.get("kind", "")):
				"arch":
					b.link(c, n, Bloom.Kind.OPEN)
				"door":
					var state := Bloom.Door.OPEN if (w.get("open", false) or w.get("jammed", false)) else Bloom.Door.CLOSED
					if w.get("sealed", false):
						state = Bloom.Door.SEALED
					w["link"] = b.link(c, n, Bloom.Kind.DOOR, state)
	for v in vents:
		b.link(v[0], v[1], Bloom.Kind.VENT)
	for v in cables:
		b.link(v[0], v[1], Bloom.Kind.CABLE)
	for c in start_growth:
		b.set_level(c, start_growth[c])
	for c in root_cells:
		b.add_root(c)
	if overgrown:
		_overgrow(b)
	bloom = b
	return b


## A lost deck, come back: the Bloom has had hours to grow.
func _overgrow(b: Bloom) -> void:
	for i in b.cells.size():
		var c: Vector2i = b.cells[i]
		if c == lift_cell:
			continue
		var d := 99
		for r in root_cells:
			d = mini(d, absi(r.x - c.x) + absi(r.y - c.y))
		b.growth[i] = clampf(4.0 - d * 0.18, 2.6, 4.0)

#endregion

#region Building

## Builds the nodes: the station, its collision, doors, lights, and the
## things in it. The Bloom's look is added by the deck scene.
func finish() -> void:
	if built:
		return
	built = true
	if bloom == null:
		make_bloom()
	_static = Node3D.new()
	_static.name = "Station"
	add_child(_static)
	_collision = Node3D.new()
	_collision.name = "Collision"
	add_child(_collision)
	var doors_node := Node3D.new()
	doors_node.name = "Doors"
	add_child(doors_node)
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	var r := RandomNumberGenerator.new()
	r.seed = hash(deck.id if deck else "deck")
	for c in tiles:
		_build_tile(c, r)
	for key in ways:
		var w: Dictionary = ways[key]
		match String(w["kind"]):
			"door":
				var d := Bulkhead.make(self, key, w)
				doors_node.add_child(d)
				doors[key] = d
			"window":
				pass
	_build_lights(lights)
	_build_vents()
	_build_lift()
	for t in things:
		_build_thing(t)
	decorate()
	_batch(_static)


func _build_tile(c: Vector2i, r: RandomNumberGenerator) -> void:
	var id: String = tiles[c]
	var st: Dictionary = STYLES.get(rooms[id]["style"], STYLES["corridor"])
	var p := center(c)
	Kit.model(_static, st["floor"], p)
	var ceil := Kit.model(_static, st["ceiling"], p + Vector3(0, Kit.HEIGHT, 0))
	ceil.rotation.x = PI
	Kit.block(_collision, p + Vector3(0, -0.1, 0), Vector3(Kit.TILE, 0.2, Kit.TILE))
	Kit.block(_collision, p + Vector3(0, Kit.HEIGHT + 0.1, 0), Vector3(Kit.TILE, 0.2, Kit.TILE))
	for s in SIDE_ORDER:
		var n: Vector2i = c + STEP[s]
		var kind := "wall"
		if tiles.has(n):
			if tiles[n] == id:
				continue
			var w: Dictionary = ways.get(edge_key(c, n), {})
			kind = String(w.get("kind", "wall"))
		match kind:
			"arch":
				continue
			"door":
				# The frame is placed once, by the bulkhead; the walls above
				# are the frame's own.
				continue
			"window":
				_wall(c, s, STYLES["window"], r, true)
			_:
				_wall(c, s, st, r, false)


## One side of a tile: the wall piece, its upper part and the floor trim,
## set in so its back sits on the tile's edge, and a box of collision.
func _wall(c: Vector2i, side: String, st: Dictionary, r: RandomNumberGenerator, glass: bool) -> void:
	var p := center(c)
	var yaw: float = SIDES[side]
	var walls: Array = st["wall"]
	var piece: String = walls[r.randi() % walls.size()]
	for name in [piece, st["top"], st.get("trim", "")]:
		if name == "":
			continue
		var m := Kit.model(_static, name, p, yaw)
		var inset := _inset(name)
		if inset != 0.0:
			m.position += Vector3(cos(yaw), 0, -sin(yaw)) * inset
	var out := Vector3(STEP[side].x, 0, STEP[side].y)
	var along := Vector3(absf(out.z), 0, absf(out.x))
	var size := along * Kit.TILE + Vector3(0, Kit.HEIGHT, 0) + out.abs() * 0.3
	Kit.block(_collision, p + out * (Kit.TILE * 0.5 + 0.05) + Vector3(0, Kit.HEIGHT * 0.5, 0), size, Kit.LAYER_GLASS if glass else Kit.LAYER_STATION)
	if glass:
		# Glass stops bodies; the wall below the window still stops shots.
		Kit.block(_collision, p + out * (Kit.TILE * 0.5 + 0.05) + Vector3(0, 0.5, 0), along * Kit.TILE + Vector3(0, 1.0, 0) + out.abs() * 0.3)


static var _insets := {}


## How far a wall piece reaches past its tile's edge, so it can be set in:
## every room's walls then stand back to back on the edge.
static func _inset(name: String) -> float:
	if not _insets.has(name):
		var n := Kit.model(Node3D.new(), name, Vector3.ZERO)
		var box := Kit.aabb_of(n)
		var parent := n.get_parent()
		parent.free()
		# Pieces stand on the -x edge (x = -2) and may reach past it.
		_insets[name] = clampf(-Kit.TILE * 0.5 - box.position.x, 0.0, 0.35) if box.size.y > 0.5 else 0.0
	return _insets[name]


func _build_lights(parent: Node3D) -> void:
	for id in room_ids:
		var rm: Dictionary = rooms[id]
		var st: Dictionary = STYLES.get(rm["style"], STYLES["corridor"])
		var list: Array = []
		var cells: Array = rm["cells"]
		for i in cells.size():
			var c: Vector2i = cells[i]
			var p := center(c)
			# A fitting on every tile; a lamp in every other one when powered.
			var fit := Kit.model(_static, "Prop_Light_Wide", p + Vector3(0, Kit.HEIGHT - 0.02, 0), PI * 0.5 if (c.x + c.y) % 2 == 0 else 0.0)
			fit.name = "Fitting"
			if i % 2 == 0 or cells.size() <= 2:
				var l := OmniLight3D.new()
				l.position = p + Vector3(0, Kit.HEIGHT - 0.6, 0)
				l.light_color = st["light"]
				l.light_energy = 1.6
				l.omni_range = 9.0
				l.omni_attenuation = 1.2
				l.shadow_enabled = false
				l.visible = false
				l.light_specular = 0.6
				parent.add_child(l)
				list.append(l)
		room_lights[id] = list
		# The emergency lights: dim and red, on whatever the power.
		if not rm["dark"]:
			var c0: Vector2i = cells[cells.size() / 2]
			var e := OmniLight3D.new()
			e.name = "Emergency_" + id
			e.position = center(c0) + Vector3(0, Kit.HEIGHT - 0.4, 0)
			e.light_color = Color(1.0, 0.3, 0.2)
			e.light_energy = 0.45
			e.omni_range = 5.0 + cells.size() * 0.35
			e.omni_attenuation = 1.8
			e.shadow_enabled = false
			parent.add_child(e)


func set_room_lights(id: String, on: bool) -> void:
	for l in room_lights.get(id, []):
		l.visible = on


func _build_vents() -> void:
	var seen := {}
	for v in vents:
		for c in v:
			if seen.has(c):
				continue
			seen[c] = true
			var m := Kit.model(_static, "Prop_Vent_Big", center(c) + Vector3(1.0, Kit.HEIGHT - 0.02, -1.0), 0.0)
			m.rotation.x = PI


func _build_lift() -> void:
	var lift_node := Lift.make(self)
	add_child(lift_node)


func _build_thing(t: Array) -> void:
	var kind: String = t[0]
	var cell: Vector2i = t[1]
	var pos := spot(cell, t[2])
	var yaw: float = t[3]
	var opts: Dictionary = t[4]
	match kind:
		"prop":
			if opts.get("solid", true):
				Kit.boxed(self, opts["name"], pos, yaw, float(opts.get("scale", 1.0)))
			else:
				Kit.model(_static, opts["name"], pos, yaw, float(opts.get("scale", 1.0)))
		"column":
			var col := Kit.model(_static, opts.get("name", "Column_Simple"), pos, yaw)
			col.name = "Column"
			Kit.block(_collision, pos + Vector3(0, Kit.HEIGHT * 0.5, 0), Vector3(0.8, Kit.HEIGHT, 0.8))
		"decal":
			Kit.model(_static, opts.get("name", "Decal_Caution"), pos + Vector3(0, 0.012, 0), yaw)
		"light":
			var l := OmniLight3D.new()
			l.position = pos + Vector3(0, 0.4, 0)
			l.light_color = opts.get("color", Color(1.0, 0.25, 0.12))
			l.light_energy = float(opts.get("energy", 1.0))
			l.omni_range = float(opts.get("range", 6.0))
			add_child(l)
		_:
			var node: Node3D = StationThings.make(kind, self, pos, yaw, opts)
			if node:
				add_child(node)


## Every static kit mesh drawn with one MultiMesh per mesh, so a deck of a
## few thousand pieces is a few dozen draws.
func _batch(root: Node3D) -> void:
	var groups := {}
	for pair in Kit.meshes_of(root):
		var mi: MeshInstance3D = pair[0]
		if mi.skeleton != NodePath() and mi.skin != null:
			continue
		var key: Mesh = Kit.clear_glass(mi.mesh)
		if mi.material_override:
			continue
		if not groups.has(key):
			groups[key] = []
		groups[key].append(pair[1])
	var batched := Node3D.new()
	batched.name = "Batched"
	for mesh in groups:
		var xfs: Array = groups[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		batched.add_child(mmi)
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	root.add_child(batched)

#endregion


func _name() -> String:
	return deck.id if deck else String(name)
