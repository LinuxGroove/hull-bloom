class_name Pickup
extends UsableBody
## Something to take: ammunition, a medkit, a stim, a power cell, salvage,
## flares, grenades, mines, a keycard or a gun. Use it to take it; ammunition,
## health and salvage are also taken by walking over them.

## Items: [label, model, scale, glow].
const ITEMS := {
	"ammo": ["ammunition", "ess:Prop_Ammo_Small", 0.8, false],
	"medkit": ["a medkit", "ess:Prop_HealthPack", 0.9, true],
	"health": ["a health tube", "ess:Prop_HealthPack_Tube", 1.2, false],
	"stim": ["a stim", "ess:Prop_Syringe", 0.8, true],
	"cell": ["a power cell", "", 1.0, true],
	"salvage": ["salvage", "Prop_Crate3", 0.32, false],
	"flare": ["flares", "", 1.0, false],
	"grenade": ["a grenade", "ess:Prop_Grenade", 1.4, false],
	"mine": ["a mine", "ess:Prop_Mine", 0.45, false],
	"keycard": ["a keycard", "ess:Prop_KeyCard", 0.9, true],
	"weapon": ["a gun", "", 1.0, true],
}
## Taken by walking over them.
const AUTO := ["ammo", "health", "salvage", "flare"]

var item := "ammo"
var count := 1
var taken := false


## `id` is an item, "ammo:rifle", "keycard:lab" or "weapon:scattergun".
static func make(id: String, n := 1) -> Pickup:
	var p := Pickup.new()
	p.name = "Pickup_" + id.replace(":", "_")
	p.item = id
	p.count = n
	p._build()
	return p


func base() -> String:
	return item.get_slice(":", 0)


func detail() -> String:
	return item.get_slice(":", 1) if item.contains(":") else ""


func label() -> String:
	var b := base()
	match b:
		"ammo":
			var w: Dictionary = Arsenal.WEAPONS.get(detail(), {})
			return "%s rounds" % String(w.get("name", "")).to_lower() if not w.is_empty() else "ammunition"
		"keycard":
			return "the %s keycard" % detail()
		"weapon":
			return "the " + String(Arsenal.WEAPONS.get(detail(), {}).get("name", "gun")).to_lower()
		"flare":
			return "%d flare%s" % [count, "s" if count > 1 else ""]
		"salvage":
			return "salvage"
	return String(ITEMS.get(b, ["something"])[0])


func _build() -> void:
	var spec: Array = ITEMS.get(base(), ITEMS["ammo"])
	var model_name: String = spec[1]
	if base() == "weapon":
		model_name = "ess:" + String(Arsenal.WEAPONS.get(detail(), {}).get("model", "Gun_Pistol"))
	var m: Node3D
	if base() == "cell":
		m = _cell_model()
		add_child(m)
	elif base() == "flare":
		m = _flare_model()
		add_child(m)
	else:
		m = Kit.model(self, model_name, Vector3.ZERO, 0.0, float(spec[2]))
	if base() in ["weapon", "keycard", "stim", "health", "grenade"]:
		# Lying on the floor. The kit's guns stand upright with the barrel
		# along x, so they're laid on their side, not stood on end.
		if base() == "weapon":
			m.rotation.x = PI * 0.5
		else:
			m.rotation.z = PI * 0.5
		var box := Kit.aabb_of(m)
		m.position.y = -box.position.y + 0.02
	add_box(Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 0.7))
	collision_layer = Kit.LAYER_INTERACT
	display_name = label().capitalize()
	add_action("interact", "Take " + label(), _take)
	if spec[3]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 0.9, 1.0) if base() == "cell" else Color(1.0, 0.85, 0.6)
		l.light_energy = 0.35
		l.omni_range = 1.6
		l.position = Vector3(0, 0.4, 0)
		add_child(l)
	if base() in AUTO:
		var a := Area3D.new()
		a.collision_layer = 0
		a.collision_mask = Kit.LAYER_PLAYER
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.9
		cs.shape = sh
		a.add_child(cs)
		add_child(a)
		a.body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if b.is_in_group("tech"):
		_try(b, true)


func _take(pic: Node) -> void:
	_try(pic.get_parent() if pic else null, false)


func _try(player: Node, auto: bool) -> void:
	if taken or player == null or not player.has_method("take_pickup"):
		return
	if player.take_pickup(item, count, auto):
		taken = true
		Sfx.at(self, "pickup_cell" if base() == "cell" else ("pickup_ammo" if base() == "ammo" else "pickup"), global_position, -4.0)
		queue_free()


static func _cell_model() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.12
	c.bottom_radius = 0.12
	c.height = 0.42
	body.mesh = c
	body.material_override = Kit.flat(Color(0.18, 0.2, 0.22), 0.4)
	body.position.y = 0.21
	n.add_child(body)
	var core := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.125
	cc.bottom_radius = 0.125
	cc.height = 0.22
	core.mesh = cc
	core.material_override = Kit.flat(Color(0.2, 0.7, 1.0), 0.2, Color(0.2, 0.75, 1.0), 2.5)
	core.position.y = 0.21
	n.add_child(core)
	return n


static func _flare_model() -> Node3D:
	var n := Node3D.new()
	for i in 3:
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.025
		c.height = 0.28
		m.mesh = c
		m.material_override = Kit.flat(Color(0.75, 0.12, 0.08), 0.6)
		m.rotation.z = PI * 0.5
		m.rotation.y = i * 0.5
		m.position = Vector3(0, 0.03 + i * 0.05, 0)
		n.add_child(m)
	return n
