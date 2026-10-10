extends RefCounted
## The autopilot's map of where the Tech can stand: the deck's floor in
## half-metre cells, each free or blocked by the station's collision (walls,
## door frames, props, the hearts' nests), found with physics queries once
## the level is built. Door leaves don't count as blocking: the autopilot
## opens doors as it reaches them. [method find_path] runs A* over it with
## the costs the pilot asks for (a Feeder overhead, thick growth, a sealed or
## locked door), and returns waypoints with the doors they pass through.

const CELL := 0.5
## Half the width of the box each cell is tested with: the Tech's capsule
## and a little room.
const CLEAR := 0.4
const SQRT2 := 1.41421356

var level: DeckLevel
## World x and z of cell (0, 0)'s centre.
var origin := Vector2.ZERO
var w := 0
var h := 0
## 1 where the Tech can stand.
var free := PackedByteArray()
## Extra cost of standing in a cell: near walls, so paths keep to the middle.
var near_wall := PackedFloat32Array()
## Door edge key -> the cells in its doorway.
var door_cells := {}
## Cell index -> door key, for the doorway cells.
var cell_door := {}


## Builds the grid for a finished level. Needs the level in the tree and a
## physics frame since, so the queries see its collision.
func build(lvl: DeckLevel, space: PhysicsDirectSpaceState3D) -> void:
	level = lvl
	var b := lvl.bounds()
	var per := int(Kit.TILE / CELL)
	origin = Vector2(b.position.x * Kit.TILE - Kit.TILE * 0.5 + CELL * 0.5, b.position.y * Kit.TILE - Kit.TILE * 0.5 + CELL * 0.5)
	w = b.size.x * per
	h = b.size.y * per
	free.resize(w * h)
	free.fill(0)
	near_wall.resize(w * h)
	near_wall.fill(0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(CLEAR * 2.0, 1.5, CLEAR * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Kit.LAYER_STATION | Kit.LAYER_GLASS
	q.collide_with_areas = false
	for y in h:
		for x in w:
			var p := world(x, y)
			if not lvl.tiles.has(DeckLevel.cell_at(p)):
				continue
			q.transform = Transform3D(Basis(), p + Vector3(0, 1.15, 0))
			if space.intersect_shape(q, 1).is_empty():
				free[y * w + x] = 1
	# Keep to the middle: a cost for cells next to blocked ones.
	for y in h:
		for x in w:
			var i := y * w + x
			if free[i] == 0:
				continue
			var d := _wall_distance(x, y, 3)
			if d == 1:
				near_wall[i] = 1.2
			elif d == 2:
				near_wall[i] = 0.4
			elif d == 3:
				near_wall[i] = 0.1
	for key in lvl.ways:
		var wy: Dictionary = lvl.ways[key]
		if wy["kind"] != "door":
			continue
		var mid := (DeckLevel.center(wy["a"]) + DeckLevel.center(wy["b"])) * 0.5
		var across: Vector2i = wy["b"] - wy["a"]
		var cells := PackedInt32Array()
		for k in range(-5, 6):
			for s: float in [-0.25, 0.25]:
				var p := mid + Vector3(across.y, 0, across.x) * k * CELL + Vector3(across.x, 0, across.y) * s
				var i := index_at(p)
				if i >= 0 and free[i] == 1 and not cells.has(i):
					cells.append(i)
					cell_door[i] = key
		door_cells[key] = cells


func _wall_distance(x: int, y: int, most: int) -> int:
	for r in range(1, most + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if not is_free(x + dx, y + dy):
					return r
	return most + 1


func world(x: int, y: int) -> Vector3:
	return Vector3(origin.x + x * CELL, 0.0, origin.y + y * CELL)


func world_of(i: int) -> Vector3:
	return world(i % w, i / w)


func coords(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - origin.x) / CELL), roundi((p.z - origin.y) / CELL))


func index_at(p: Vector3) -> int:
	var c := coords(p)
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return -1
	return c.y * w + c.x


func is_free(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and free[y * w + x] == 1


func free_at(p: Vector3) -> bool:
	var i := index_at(p)
	return i >= 0 and free[i] == 1


## The free cell nearest a spot (within `most` metres), or -1.
func nearest_free(p: Vector3, most := 3.0) -> int:
	var c := coords(p)
	var best := -1
	var best_d := INF
	var r := int(ceil(most / CELL))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := c.x + dx
			var y := c.y + dy
			if not is_free(x, y):
				continue
			var d := world(x, y).distance_squared_to(Vector3(p.x, 0, p.z))
			if d < best_d:
				best_d = d
				best = y * w + x
	return best


## Whether a straight walk from a to b stays on free cells, with a little
## room either side so the Tech's shoulders don't catch a corner.
func clear_line(a: Vector3, b: Vector3) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var n := int(ceil(d.length() / (CELL * 0.4)))
	var side := Vector3(-d.z, 0, d.x).normalized() * 0.2 if d.length() > 0.01 else Vector3.ZERO
	for k in n + 1:
		var p := a + d * (float(k) / maxf(1.0, n))
		if not free_at(p) or not free_at(p + side) or not free_at(p - side):
			return false
	return true


## A* from `from` to `to` (world spots). `cost` maps cell index -> extra
## cost (or -1 for blocked); `tile_cost` maps tile -> extra cost per metre;
## `blocked_doors` lists door keys that can't be passed. Returns
## {"points": [Vector3], "doors": [key or "" for the step into each point],
## "length": metres}, or {} if there's no way.
func find_path(from: Vector3, to: Vector3, cost := {}, tile_cost := {}, blocked_doors := {}) -> Dictionary:
	var start := index_at(from)
	if start < 0 or free[start] == 0:
		start = nearest_free(from, 2.0)
	var goal := index_at(to)
	if goal < 0 or free[goal] == 0:
		goal = nearest_free(to, 3.0)
	if start < 0 or goal < 0:
		return {}
	var blocked := {}
	for key in blocked_doors:
		for i in door_cells.get(key, PackedInt32Array()):
			blocked[i] = true
	var g := {start: 0.0}
	var came := {start: -1}
	var heap: Array = [[_h(start, goal), start]]
	var closed := {}
	var gx := goal % w
	var gy := goal / w
	var found := false
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var i: int = top[1]
		if closed.has(i):
			continue
		if i == goal:
			found = true
			break
		closed[i] = true
		var x := i % w
		var y := i / w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if not is_free(nx, ny):
					continue
				var j: int = ny * w + nx
				if closed.has(j) or blocked.has(j):
					continue
				var step := 1.0
				if dx != 0 and dy != 0:
					if not is_free(x + dx, y) or not is_free(x, y + dy):
						continue
					step = SQRT2
				var extra: float = near_wall[j] + float(cost.get(j, 0.0))
				if extra < 0.0:
					continue
				if not tile_cost.is_empty():
					extra += float(tile_cost.get(DeckLevel.cell_at(world_of(j)), 0.0))
				var ng: float = g[i] + step * CELL * (1.0 + extra)
				if ng < float(g.get(j, INF)):
					g[j] = ng
					came[j] = i
					_push(heap, [ng + Vector2(nx - gx, ny - gy).length() * CELL, j])
	if not found:
		return {}
	var cells: Array[int] = []
	var at := goal
	while at != -1:
		cells.push_front(at)
		at = came[at]
	return _waypoints(cells, from, to)


func _h(a: int, b: int) -> float:
	return Vector2(a % w - b % w, a / w - b / w).length() * CELL


## Smooths a cell path into waypoints, keeping a point either side of each
## doorway so the Tech walks through doors square on and knows to open them.
func _waypoints(cells: Array[int], from: Vector3, to: Vector3) -> Dictionary:
	var anchors: Array[int] = [0]
	var doors_at := {}
	var prev_tile := DeckLevel.cell_at(world_of(cells[0]))
	for k in range(1, cells.size()):
		var t := DeckLevel.cell_at(world_of(cells[k]))
		if t != prev_tile:
			var key := DeckLevel.edge_key(prev_tile, t)
			if level.doors.has(key) or String(level.ways.get(key, {}).get("kind", "")) == "door":
				var before := maxi(0, k - 2)
				var after := mini(cells.size() - 1, k + 1)
				if anchors[-1] < before:
					anchors.append(before)
				if anchors[-1] < after:
					anchors.append(after)
				doors_at[after] = key
		prev_tile = t
	if anchors[-1] != cells.size() - 1:
		anchors.append(cells.size() - 1)
	var points: Array[Vector3] = []
	var doors: Array[String] = []
	var length := 0.0
	var last := from
	for a in anchors.size():
		if a == 0:
			continue
		var s0: int = anchors[a - 1]
		var s1: int = anchors[a]
		var k := s0
		while k < s1:
			# The furthest cell along this stretch walkable in a straight line.
			var far := mini(s1, k + 30)
			while far > k + 1 and not clear_line(world_of(cells[k]), world_of(cells[far])):
				far -= 1
			var p := world_of(cells[far])
			if far == cells.size() - 1 and free_at(to):
				p = Vector3(to.x, 0.0, to.z)
			points.append(p)
			doors.append(String(doors_at.get(far, "")) if far == s1 else "")
			length += last.distance_to(p)
			last = p
			k = far
	return {"points": points, "doors": doors, "length": length}


func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap[p][0] <= item[0]:
			break
		heap[i] = heap[p]
		i = p
	heap[i] = item


func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		if l >= n:
			break
		var c := l
		if l + 1 < n and heap[l + 1][0] < heap[l][0]:
			c = l + 1
		if heap[c][0] >= last[0]:
			break
		heap[i] = heap[c]
		i = c
	heap[i] = last
	return top
