class_name BrawlerModel
extends Node3D
## Procedural 3D "toy" model for each brawler, built from primitive meshes with
## toon shading and inked outlines, plus code-driven animation (walk cycle,
## idle breathing, aiming, weapon recoil, signature swings).
## The model faces +Z; feet are at y = 0.

const TOON := preload("res://assets/shaders/toon.gdshader")
const OUTLINE := preload("res://assets/shaders/outline.gdshader")
const INK := Color("1a1028")

static var _mat_cache: Dictionary = {}
static var _outline_mats: Dictionary = {}

var id := ""
var outline_width := 0.022
var d: Dictionary
var body: Node3D      # everything above the legs (bobs while walking)
var head: Node3D
var arm_l: Node3D     # off hand
var arm_r: Node3D     # weapon hand
var leg_l: Node3D
var leg_r: Node3D
var weapon: Node3D
var extra: Dictionary = {}

var _yaw := 0.0
var _t := 0.0

# ------------------------------------------------------------------ materials / parts
static func mat(col: Color, glow := 0.0, rim := 0.18, ow := 0.022) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.3f" % [col.to_html(), glow, rim, ow]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("emission", col)
	m.set_shader_parameter("emission_strength", glow)
	m.set_shader_parameter("rim_strength", rim)
	if not _outline_mats.has(ow):
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", ow)
		_outline_mats[ow] = o
	m.next_pass = _outline_mats[ow]
	_mat_cache[key] = m
	return m

static func sphere(r: float, h := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if h < 0.0 else h
	m.radial_segments = 24
	m.rings = 12
	return m

static func capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0)
	m.radial_segments = 20
	m.rings = 6
	return m

static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func cyl(top: float, bottom: float, h: float, segs := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m

static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 10
	return m

func part(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(col, glow, 0.18, outline_width)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func eye(parent: Node3D, pos: Vector3, r: float, pupil := INK) -> void:
	part(parent, sphere(r), Color.WHITE, pos, Vector3.ZERO, Vector3(1, 1.15, 0.55))
	part(parent, sphere(r * 0.58), pupil, pos + Vector3(0, -r * 0.05, r * 0.32), Vector3.ZERO, Vector3(1, 1.15, 0.5))
	part(parent, sphere(r * 0.2), Color.WHITE, pos + Vector3(-r * 0.22, r * 0.3, r * 0.5), Vector3.ZERO, Vector3.ONE, 1.0)

# ------------------------------------------------------------------ build
func build(brawler_id: String) -> void:
	id = brawler_id
	d = Config.BRAWLERS[id]
	body = pivot(self, Vector3.ZERO)
	match id:
		"bront": _bront()
		"vex": _vex()
		"nova": _nova()
		"mira": _mira()
		"sprig": _sprig()

func _legs(col: Color, shoe: Color, spread: float, hip_y: float, r: float, len: float) -> void:
	leg_l = pivot(self, Vector3(-spread, hip_y, 0))
	leg_r = pivot(self, Vector3(spread, hip_y, 0))
	for lg in [leg_l, leg_r]:
		part(lg, capsule(r, len), col, Vector3(0, -len * 0.45, 0))
		part(lg, sphere(r * 1.35), shoe, Vector3(0, -hip_y + r * 0.8, r * 0.45), Vector3.ZERO, Vector3(1, 0.7, 1.35))

func _bront() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	_legs(sec.darkened(0.15), Color("3a2a22"), 0.22, 0.42, 0.13, 0.42)
	# barrel torso + overalls
	part(body, sphere(0.52), prim, Vector3(0, 0.86, 0), Vector3.ZERO, Vector3(1.15, 0.9, 0.95))
	part(body, sphere(0.47), prim.darkened(0.15), Vector3(0, 0.78, 0.07), Vector3.ZERO, Vector3(1.1, 0.75, 0.9))
	part(body, box(0.1, 0.42, 0.06), acc, Vector3(-0.2, 1.05, 0.42), Vector3(12, 0, 0))
	part(body, box(0.1, 0.42, 0.06), acc, Vector3(0.2, 1.05, 0.42), Vector3(12, 0, 0))
	part(body, torus(0.5, 0.6), sec, Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1.05, 0.9, 0.9))
	part(body, box(0.16, 0.14, 0.08), acc, Vector3(0, 0.6, 0.52))
	# head
	head = pivot(body, Vector3(0, 1.38, 0.04))
	part(head, sphere(0.34), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.95, 0.95))
	part(head, sphere(0.31), sec.lightened(0.15), Vector3(0, -0.15, 0.13), Vector3.ZERO, Vector3(1.05, 0.75, 0.8)) # beard
	part(head, sphere(0.06), skin.darkened(0.1), Vector3(0, 0.0, 0.33)) # nose
	eye(head, Vector3(-0.12, 0.08, 0.26), 0.075)
	eye(head, Vector3(0.12, 0.08, 0.26), 0.075)
	part(head, box(0.15, 0.04, 0.04), INK, Vector3(-0.13, 0.2, 0.3), Vector3(0, 0, -14))
	part(head, box(0.15, 0.04, 0.04), INK, Vector3(0.13, 0.2, 0.3), Vector3(0, 0, 14))
	# hard hat
	part(head, sphere(0.37, 0.42), acc, Vector3(0, 0.17, -0.02), Vector3.ZERO, Vector3(1, 1, 1))
	part(head, cyl(0.47, 0.47, 0.05), acc.darkened(0.12), Vector3(0, 0.15, 0.03))
	part(head, box(0.1, 0.12, 0.5), acc.lightened(0.3), Vector3(0, 0.36, -0.02))
	# arms
	arm_l = pivot(body, Vector3(-0.58, 1.02, 0))
	part(arm_l, capsule(0.13, 0.45), prim, Vector3(0, -0.18, 0))
	part(arm_l, sphere(0.16), skin, Vector3(0, -0.42, 0))
	arm_r = pivot(body, Vector3(0.58, 1.02, 0))
	part(arm_r, capsule(0.13, 0.45), prim, Vector3(0, -0.18, 0))
	part(arm_r, sphere(0.16), skin, Vector3(0, -0.42, 0))
	# hammer (held in the right fist, pointing forward)
	weapon = pivot(arm_r, Vector3(0, -0.42, 0))
	part(weapon, cyl(0.05, 0.05, 0.9), Color("8a5a36"), Vector3(0, 0, 0.35), Vector3(90, 0, 0))
	part(weapon, box(0.36, 0.3, 0.52), Color("7d869a"), Vector3(0, 0, 0.82))
	part(weapon, box(0.38, 0.32, 0.12), prim, Vector3(0, 0, 0.82))

func _vex() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	_legs(sec, Color("1a1028"), 0.13, 0.38, 0.09, 0.38)
	# cloak
	part(body, cyl(0.22, 0.42, 0.7), prim, Vector3(0, 0.7, 0))
	part(body, cyl(0.1, 0.1, 0.62), prim.darkened(0.3), Vector3(0, 0.72, 0.3), Vector3(-8, 0, 0))
	part(body, torus(0.2, 0.3), acc, Vector3(0, 1.03, 0), Vector3.ZERO, Vector3(1, 0.8, 1), 0.6) # scarf
	var tail := pivot(body, Vector3(0, 1.0, -0.25))
	part(tail, box(0.14, 0.05, 0.55), acc, Vector3(0, 0, -0.25), Vector3.ZERO, Vector3.ONE, 0.5)
	extra["tail"] = tail
	# hooded head
	head = pivot(body, Vector3(0, 1.32, 0))
	part(head, sphere(0.36), prim, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.05, 1))
	part(head, cyl(0.001, 0.2, 0.42), prim, Vector3(0, 0.3, -0.22), Vector3(-55, 0, 0))
	part(head, sphere(0.28), sec, Vector3(0, -0.04, 0.16), Vector3.ZERO, Vector3(1, 0.85, 0.75))
	part(head, sphere(0.06), acc, Vector3(-0.1, 0.0, 0.36), Vector3(0, 0, 15), Vector3(1.4, 0.7, 0.6), 2.5)
	part(head, sphere(0.06), acc, Vector3(0.1, 0.0, 0.36), Vector3(0, 0, -15), Vector3(1.4, 0.7, 0.6), 2.5)
	# arms + blades
	arm_l = pivot(body, Vector3(-0.32, 0.98, 0))
	part(arm_l, capsule(0.08, 0.4), prim, Vector3(0, -0.16, 0))
	part(arm_l, sphere(0.1), sec, Vector3(0, -0.36, 0))
	arm_r = pivot(body, Vector3(0.32, 0.98, 0))
	part(arm_r, capsule(0.08, 0.4), prim, Vector3(0, -0.16, 0))
	part(arm_r, sphere(0.1), sec, Vector3(0, -0.36, 0))
	weapon = pivot(arm_r, Vector3(0, -0.38, 0))
	_blade(weapon, acc)
	var w2 := pivot(arm_l, Vector3(0, -0.38, 0))
	_blade(w2, acc)
	extra["blade_l"] = w2

func _blade(parent: Node3D, acc: Color) -> void:
	part(parent, box(0.16, 0.08, 0.12), Color("2b1a4d"), Vector3(0, 0, 0.05))
	part(parent, sphere(0.2), acc.lightened(0.15), Vector3(0, 0.05, 0.36), Vector3(-10, 0, 0), Vector3(0.28, 0.45, 1.6), 1.2)

func _nova() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var hair := Color("2a1a14")
	_legs(sec.lightened(0.08), Color("f5f7ff"), 0.13, 0.42, 0.1, 0.42)
	part(body, capsule(0.27, 0.62), sec, Vector3(0, 0.74, 0))
	part(body, box(0.1, 0.5, 0.05), prim, Vector3(0, 0.76, 0.26), Vector3.ZERO, Vector3.ONE, 0.6)
	part(body, torus(0.2, 0.3), prim, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	head = pivot(body, Vector3(0, 1.34, 0))
	part(head, sphere(0.34), skin)
	part(head, sphere(0.36), hair, Vector3(0, 0.08, -0.05), Vector3(-20, 0, 0), Vector3(1, 0.85, 0.95))
	var tail := pivot(head, Vector3(0, 0.12, -0.3))
	part(tail, sphere(0.15), hair, Vector3(0, -0.05, -0.12), Vector3.ZERO, Vector3(0.8, 1.2, 0.8))
	part(tail, sphere(0.1), hair, Vector3(0, -0.25, -0.18))
	extra["tail"] = tail
	part(head, box(0.56, 0.13, 0.12), prim, Vector3(0, 0.03, 0.29), Vector3.ZERO, Vector3.ONE, 1.6) # visor
	part(head, box(0.5, 0.03, 0.13), Color.WHITE, Vector3(0, 0.07, 0.3), Vector3.ZERO, Vector3.ONE, 1.0)
	part(head, box(0.08, 0.02, 0.02), INK, Vector3(0, -0.17, 0.32))
	arm_l = pivot(body, Vector3(-0.33, 0.98, 0))
	part(arm_l, capsule(0.08, 0.4), sec.lightened(0.1), Vector3(0, -0.16, 0))
	part(arm_l, sphere(0.1), skin, Vector3(0, -0.36, 0))
	arm_r = pivot(body, Vector3(0.33, 0.98, 0))
	part(arm_r, capsule(0.08, 0.4), sec.lightened(0.1), Vector3(0, -0.16, 0))
	part(arm_r, sphere(0.1), skin, Vector3(0, -0.36, 0))
	weapon = pivot(arm_r, Vector3(-0.08, -0.38, 0))
	part(weapon, box(0.14, 0.16, 0.85), acc, Vector3(0, 0.02, 0.32))
	part(weapon, box(0.1, 0.1, 0.3), Color("3a4766"), Vector3(0, -0.06, -0.12))
	part(weapon, cyl(0.04, 0.04, 0.4), Color("3a4766"), Vector3(0, 0.02, 0.9), Vector3(90, 0, 0))
	part(weapon, box(0.06, 0.1, 0.25), Color("3a4766"), Vector3(0, 0.14, 0.3))
	part(weapon, box(0.03, 0.04, 0.6), prim, Vector3(0.075, 0.02, 0.32), Vector3.ZERO, Vector3.ONE, 1.5)
	part(weapon, sphere(0.08), prim, Vector3(0, 0.02, 1.12), Vector3.ZERO, Vector3.ONE, 2.5)

func _mira() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	_legs(sec.darkened(0.1), prim.darkened(0.2), 0.12, 0.36, 0.08, 0.34)
	part(body, cyl(0.18, 0.44, 0.62), sec, Vector3(0, 0.66, 0))
	part(body, torus(0.4, 0.47), prim, Vector3(0, 0.37, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	part(body, sphere(0.06), acc, Vector3(0, 0.82, 0.25), Vector3.ZERO, Vector3.ONE, 1.5)
	head = pivot(body, Vector3(0, 1.3, 0))
	part(head, sphere(0.42), prim, Vector3(0, 0.05, -0.08)) # hair mass
	part(head, sphere(0.19), prim, Vector3(-0.36, 0.3, -0.05)) # buns
	part(head, sphere(0.19), prim, Vector3(0.36, 0.3, -0.05))
	part(head, sphere(0.33), skin, Vector3(0, -0.04, 0.08))
	part(head, sphere(0.3), prim.lightened(0.08), Vector3(0, 0.17, 0.12), Vector3(-25, 0, 0), Vector3(1.05, 0.55, 0.9)) # bangs
	eye(head, Vector3(-0.12, -0.05, 0.34), 0.085, Color("3b2350"))
	eye(head, Vector3(0.12, -0.05, 0.34), 0.085, Color("3b2350"))
	part(head, sphere(0.05), Color("ff8aa8"), Vector3(-0.22, -0.15, 0.3), Vector3.ZERO, Vector3(1.3, 0.6, 0.5))
	part(head, sphere(0.05), Color("ff8aa8"), Vector3(0.22, -0.15, 0.3), Vector3.ZERO, Vector3(1.3, 0.6, 0.5))
	arm_l = pivot(body, Vector3(-0.27, 0.92, 0))
	part(arm_l, capsule(0.07, 0.36), skin, Vector3(0, -0.15, 0))
	arm_r = pivot(body, Vector3(0.27, 0.92, 0))
	part(arm_r, capsule(0.07, 0.36), skin, Vector3(0, -0.15, 0))
	weapon = pivot(arm_r, Vector3(0, -0.34, 0.05))
	var gold := Color("e0b44a")
	part(weapon, cyl(0.03, 0.03, 0.22), gold, Vector3(0, 0.0, 0.12), Vector3(60, 0, 0))
	part(weapon, cyl(0.12, 0.12, 0.05), gold, Vector3(0, -0.05, 0.3))
	part(weapon, cyl(0.1, 0.1, 0.22), acc, Vector3(0, -0.19, 0.3), Vector3.ZERO, Vector3.ONE, 0.9)
	part(weapon, cyl(0.12, 0.12, 0.05), gold, Vector3(0, -0.32, 0.3))
	extra["flame"] = part(weapon, sphere(0.05), Color.WHITE, Vector3(0, -0.19, 0.3), Vector3.ZERO, Vector3(1, 1.4, 1), 3.0)

func _sprig() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	_legs(sec, Color("6b3f1f"), 0.12, 0.3, 0.08, 0.28)
	part(body, box(0.42, 0.5, 0.25), Color("8a5a36"), Vector3(0, 0.65, -0.3), Vector3(8, 0, 0)) # backpack
	part(body, sphere(0.07), acc, Vector3(-0.1, 0.85, -0.44), Vector3.ZERO, Vector3.ONE, 0.5)
	part(body, sphere(0.06), acc, Vector3(0.1, 0.8, -0.44), Vector3.ZERO, Vector3.ONE, 0.5)
	part(body, sphere(0.3), prim, Vector3(0, 0.58, 0), Vector3.ZERO, Vector3(1, 1.05, 0.9))
	part(body, sphere(0.18), skin.lightened(0.25), Vector3(0, 0.55, 0.16), Vector3.ZERO, Vector3(1, 1, 0.6))
	head = pivot(body, Vector3(0, 1.08, 0))
	part(head, sphere(0.4), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.08, 0.92, 0.95))
	var ear_l := pivot(head, Vector3(-0.36, 0.05, 0))
	part(ear_l, cyl(0.001, 0.13, 0.42), skin, Vector3(-0.15, 0.06, 0), Vector3(0, 0, 70))
	var ear_r := pivot(head, Vector3(0.36, 0.05, 0))
	part(ear_r, cyl(0.001, 0.13, 0.42), skin, Vector3(0.15, 0.06, 0), Vector3(0, 0, -70))
	extra["ear_l"] = ear_l
	extra["ear_r"] = ear_r
	part(head, cyl(0.02, 0.02, 0.2), sec, Vector3(0, 0.44, 0))
	var sprout := pivot(head, Vector3(0, 0.54, 0))
	part(sprout, sphere(0.12), prim, Vector3(-0.1, 0.02, 0), Vector3(0, 0, 30), Vector3(1.3, 0.4, 0.7))
	part(sprout, sphere(0.12), prim, Vector3(0.1, 0.02, 0), Vector3(0, 0, -30), Vector3(1.3, 0.4, 0.7))
	extra["sprout"] = sprout
	# goggles on the forehead
	part(head, torus(0.06, 0.11), acc, Vector3(-0.13, 0.2, 0.3), Vector3(75, 0, 0))
	part(head, torus(0.06, 0.11), acc, Vector3(0.13, 0.2, 0.3), Vector3(75, 0, 0))
	part(head, sphere(0.07), Color("bff4ff"), Vector3(-0.13, 0.2, 0.31), Vector3.ZERO, Vector3(1, 1, 0.4), 0.8)
	part(head, sphere(0.07), Color("bff4ff"), Vector3(0.13, 0.2, 0.31), Vector3.ZERO, Vector3(1, 1, 0.4), 0.8)
	eye(head, Vector3(-0.14, -0.04, 0.32), 0.085)
	eye(head, Vector3(0.14, -0.04, 0.32), 0.085)
	part(head, box(0.16, 0.035, 0.03), INK, Vector3(0, -0.2, 0.36), Vector3(0, 0, 0))
	part(head, box(0.04, 0.05, 0.02), Color.WHITE, Vector3(0.03, -0.235, 0.36))
	arm_l = pivot(body, Vector3(-0.27, 0.72, 0))
	part(arm_l, capsule(0.065, 0.3), skin, Vector3(0, -0.12, 0))
	arm_r = pivot(body, Vector3(0.27, 0.72, 0))
	part(arm_r, capsule(0.065, 0.3), skin, Vector3(0, -0.12, 0))
	weapon = pivot(arm_r, Vector3(0, -0.28, 0.02))
	part(weapon, sphere(0.12), acc, Vector3(0, 0, 0.08))
	part(weapon, cyl(0.015, 0.015, 0.1), sec, Vector3(0, 0.13, 0.08))
	part(weapon, sphere(0.06), prim, Vector3(0.05, 0.18, 0.08), Vector3(0, 0, -30), Vector3(1.4, 0.5, 0.8))

# ------------------------------------------------------------------ animation
## state: t, moving, recoil (1 -> 0), yaw (radians, 0 = facing camera), instant
func animate(delta: float, state: Dictionary) -> void:
	_t = state.get("t", _t + delta)
	var moving: bool = state.get("moving", false)
	var recoil: float = state.get("recoil", 0.0)
	var target_yaw: float = state.get("yaw", 0.0)
	if state.get("instant", false):
		_yaw = target_yaw
	else:
		_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 16.0, 0.0, 1.0))
	rotation.y = _yaw

	var walk := sin(_t * 12.0)
	var swing := walk * 0.7 if moving else 0.0
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	body.position.y = absf(walk) * 0.06 if moving else sin(_t * 2.6) * 0.012
	body.rotation.z = walk * 0.04 if moving else 0.0
	body.rotation.x = 0.08 if moving else 0.0
	arm_l.rotation.x = -swing * 0.8
	arm_l.rotation.z = -0.15
	head.rotation.z = sin(_t * 1.7) * 0.04

	# weapon arm: raised to aim forward, with per-brawler recoil
	match id:
		"bront":
			# overhead hammer smash: wind up high, slam down
			var r := recoil
			arm_r.rotation.x = lerpf(-1.25, -2.6, r) if r > 0.6 else lerpf(-0.35, -1.25, r / 0.6)
			arm_r.rotation.z = 0.1
		"vex":
			arm_r.rotation.x = -1.35 - recoil * 0.4
			arm_r.rotation.y = -recoil * 1.2
			arm_l.rotation.x = -1.1 + (0.0 if not moving else -swing * 0.3)
			weapon.rotation.x = -arm_r.rotation.x * 0.85
			var bl: Node3D = extra.blade_l
			bl.rotation.x = -arm_l.rotation.x * 0.85
			var tail: Node3D = extra.tail
			tail.rotation.x = 0.3 + sin(_t * (14.0 if moving else 4.0)) * 0.25
			tail.rotation.y = sin(_t * 3.0) * 0.2
		"nova":
			arm_r.rotation.x = -1.5 + recoil * 0.45
			arm_l.rotation.x = -1.3
			arm_l.rotation.z = 0.5
			weapon.rotation.x = -arm_r.rotation.x - 0.05
			weapon.position.z = -recoil * 0.12
			var tail: Node3D = extra.tail
			tail.rotation.x = sin(_t * (12.0 if moving else 3.0)) * 0.25
		"mira":
			arm_r.rotation.x = -1.0 - recoil * 0.5
			weapon.rotation.x = -arm_r.rotation.x
			weapon.position.y = -0.34 + sin(_t * 3.0) * 0.02
			var flame: MeshInstance3D = extra.flame
			flame.scale = Vector3(1, 1.4, 1) * (1.0 + sin(_t * 11.0) * 0.15)
		"sprig":
			arm_r.rotation.x = -0.6 - recoil * 1.6 + (0.0 if recoil > 0.0 else sin(_t * 2.0) * 0.1)
			weapon.rotation.x = -arm_r.rotation.x
			var s: Node3D = extra.sprout
			s.rotation.z = sin(_t * 3.5) * 0.25
			var el: Node3D = extra.ear_l
			var er: Node3D = extra.ear_r
			el.rotation.z = sin(_t * 3.0) * 0.12
			er.rotation.z = -sin(_t * 3.0) * 0.12
