class_name BrawlerModel
extends Node3D
## Procedural 3D "toy" model for each brawler, built from primitive meshes with
## toon shading and inked outlines, plus code-driven animation (walk cycle,
## idle breathing, aiming, weapon recoil, signature swings).
## The model faces +Z; feet are at y = 0.

const TOON := preload("res://assets/shaders/toon.gdshader")
const OUTLINE := preload("res://assets/shaders/outline.gdshader")
const TOON_VC := preload("res://assets/shaders/toon_vc.gdshader")
const INK := Color("1a1028")

static var _mat_cache: Dictionary = {}
static var _outline_mats: Dictionary = {}
static var _vc_mats: Dictionary = {}

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
	m.radial_segments = 32
	m.rings = 16
	return m

static func capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0)
	m.radial_segments = 24
	m.rings = 8
	return m

static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func cyl(top: float, bottom: float, h: float, segs := 24) -> CylinderMesh:
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
	mi.set_meta("col", col)
	mi.set_meta("glow", glow)
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

# ------------------------------------------------------------------ face / detail helpers
## Glossy cartoon eye: sclera, coloured iris, pupil and two highlights.
func eye(parent: Node3D, pos: Vector3, r: float, iris := Color("3b2a1a"), squint := 0.0) -> void:
	part(parent, sphere(r), Color.WHITE, pos, Vector3.ZERO, Vector3(1.0, 1.25, 0.55))
	part(parent, sphere(r * 0.66), iris, pos + Vector3(0, -r * 0.08, r * 0.3), Vector3.ZERO, Vector3(1.0, 1.2, 0.5))
	part(parent, sphere(r * 0.36), INK, pos + Vector3(0, -r * 0.1, r * 0.42), Vector3.ZERO, Vector3(1.0, 1.2, 0.45))
	part(parent, sphere(r * 0.2), Color.WHITE, pos + Vector3(-r * 0.25, r * 0.28, r * 0.52), Vector3.ZERO, Vector3.ONE, 1.2)
	part(parent, sphere(r * 0.1), Color.WHITE, pos + Vector3(r * 0.22, -r * 0.3, r * 0.52), Vector3.ZERO, Vector3.ONE, 1.0)
	if squint > 0.0:
		# heavy upper lid for a determined look
		part(parent, sphere(r * 1.08), parent.get_meta("skin", Color("e8b48f")), pos + Vector3(0, r * (1.15 - squint * 0.6), 0.0), Vector3.ZERO, Vector3(1.05, 0.7, 0.6))

func brow(parent: Node3D, pos: Vector3, length: float, tilt_deg: float, col: Color, thick := 0.035) -> void:
	part(parent, capsule(thick, length), col, pos, Vector3(0, 0, 90 + tilt_deg), Vector3(1, 1, 0.6))

func smile(parent: Node3D, pos: Vector3, w: float, open := 0.3, teeth := true) -> void:
	part(parent, sphere(w * 0.5), Color("5a1a2a"), pos, Vector3.ZERO, Vector3(1.0, open, 0.35))
	if teeth:
		part(parent, sphere(w * 0.38), Color.WHITE, pos + Vector3(0, w * open * 0.18, w * 0.06), Vector3.ZERO, Vector3(1.0, open * 0.45, 0.3))

func shoe(leg: Node3D, hip_y: float, col: Color, size := 1.0) -> void:
	part(leg, sphere(0.13 * size), col, Vector3(0, -hip_y + 0.075 * size, 0.05 * size), Vector3.ZERO, Vector3(1.0, 0.62, 1.45))
	part(leg, box(0.2 * size, 0.035, 0.34 * size), col.darkened(0.45), Vector3(0, -hip_y + 0.02, 0.05 * size))

func limb_legs(col: Color, shoe_col: Color, spread: float, hip_y: float, r: float, shoe_size := 1.0) -> void:
	leg_l = pivot(self, Vector3(-spread, hip_y, 0))
	leg_r = pivot(self, Vector3(spread, hip_y, 0))
	for lg in [leg_l, leg_r]:
		part(lg, capsule(r, hip_y * 0.95), col, Vector3(0, -hip_y * 0.45, 0))
		shoe(lg, hip_y, shoe_col, shoe_size)

func arm(side: float, shoulder: Vector3, sleeve: Color, hand: Color, upper_r := 0.075, length := 0.34, hand_r := 0.105) -> Node3D:
	var a := pivot(body, Vector3(shoulder.x * side, shoulder.y, shoulder.z))
	part(a, sphere(upper_r * 1.35), sleeve, Vector3.ZERO)
	part(a, capsule(upper_r, length), sleeve, Vector3(0, -length * 0.42, 0))
	part(a, sphere(hand_r), hand, Vector3(0, -length * 0.95, 0.01))
	return a

# ------------------------------------------------------------------ build
func build(brawler_id: String, skin := "") -> void:
	id = brawler_id
	d = Progression.palette(id, skin)
	body = pivot(self, Vector3.ZERO)
	match id:
		"bront": _bront()
		"vex": _vex()
		"nova": _nova()
		"mira": _mira()
		"sprig": _sprig()
	_merge_parts()

# ------------------------------------------------------------------ BRONT: tank, big-hearted brute
func _bront() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var denim := sec.darkened(0.1)
	limb_legs(denim, Color("3a2a22"), 0.2, 0.34, 0.12, 1.25)
	# barrel chest work shirt + overalls
	part(body, sphere(0.5), prim, Vector3(0, 0.82, 0), Vector3.ZERO, Vector3(1.22, 0.98, 1.02))
	part(body, sphere(0.47), denim, Vector3(0, 0.62, 0.02), Vector3.ZERO, Vector3(1.2, 0.62, 1.0))
	part(body, box(0.42, 0.3, 0.1), denim, Vector3(0, 0.84, 0.44), Vector3(10, 0, 0))
	part(body, box(0.14, 0.1, 0.06), denim.darkened(0.2), Vector3(0, 0.84, 0.5), Vector3(10, 0, 0))
	for sx in [-1.0, 1.0]:
		part(body, box(0.09, 0.42, 0.06), acc, Vector3(0.2 * sx, 1.0, 0.43), Vector3(14, 0, 0))
		part(body, sphere(0.05), Color("d9dde8"), Vector3(0.2 * sx, 0.9, 0.5))
	part(body, torus(0.5, 0.6), Color("4a2e1e"), Vector3(0, 0.56, 0), Vector3.ZERO, Vector3(1.12, 0.9, 1.0))
	part(body, box(0.18, 0.13, 0.07), acc, Vector3(0, 0.56, 0.6))
	# shoulders + huge forearms + leather gloves
	for sx in [-1.0, 1.0]:
		part(body, sphere(0.2), prim.darkened(0.08), Vector3(0.5 * sx, 1.08, 0))
	arm_l = arm(-1.0, Vector3(0.6, 1.02, 0), prim, Color("6b3f22"), 0.13, 0.36, 0.17)
	arm_r = arm(1.0, Vector3(0.6, 1.02, 0), prim, Color("6b3f22"), 0.13, 0.36, 0.17)
	for a in [arm_l, arm_r]:
		part(a, sphere(0.16), skin, Vector3(0, -0.22, 0.01), Vector3.ZERO, Vector3(1, 1.15, 1))
	# head
	head = pivot(body, Vector3(0, 1.36, 0.06))
	head.set_meta("skin", skin)
	part(head, sphere(0.34), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.96, 0.98))
	part(head, sphere(0.09), skin.darkened(0.1), Vector3(0, -0.02, 0.33), Vector3.ZERO, Vector3(1.1, 0.9, 1.0))
	eye(head, Vector3(-0.13, 0.07, 0.27), 0.07, Color("3a5aa0"), 0.5)
	eye(head, Vector3(0.13, 0.07, 0.27), 0.07, Color("3a5aa0"), 0.5)
	brow(head, Vector3(-0.14, 0.18, 0.3), 0.17, -16, sec.lightened(0.1), 0.045)
	brow(head, Vector3(0.14, 0.18, 0.3), 0.17, 16, sec.lightened(0.1), 0.045)
	# beard + mustache
	var beard := sec.lightened(0.18)
	part(head, sphere(0.33), beard, Vector3(0, -0.17, 0.12), Vector3.ZERO, Vector3(1.08, 0.8, 0.85))
	part(head, sphere(0.1), beard.lightened(0.08), Vector3(-0.09, -0.1, 0.32), Vector3(0, 0, 20), Vector3(1.4, 0.6, 0.7))
	part(head, sphere(0.1), beard.lightened(0.08), Vector3(0.09, -0.1, 0.32), Vector3(0, 0, -20), Vector3(1.4, 0.6, 0.7))
	smile(head, Vector3(0, -0.19, 0.34), 0.16, 0.35)
	# hard hat with lamp
	part(head, sphere(0.37, 0.4), acc, Vector3(0, 0.18, -0.02))
	part(head, cyl(0.46, 0.48, 0.05, 32), acc.darkened(0.12), Vector3(0, 0.16, 0.03))
	part(head, box(0.08, 0.14, 0.5), acc.lightened(0.25), Vector3(0, 0.36, -0.02))
	part(head, cyl(0.07, 0.08, 0.08), Color("3a3f58"), Vector3(0, 0.3, 0.32), Vector3(80, 0, 0))
	part(head, sphere(0.055), Color("fff6c2"), Vector3(0, 0.3, 0.37), Vector3.ZERO, Vector3(1, 1, 0.5), 2.2)
	# hammer
	weapon = pivot(arm_r, Vector3(0, -0.34, 0))
	var wood := Color("8a5a36")
	part(weapon, cyl(0.055, 0.06, 1.0), wood, Vector3(0, 0, 0.38), Vector3(90, 0, 0))
	for z in [0.05, 0.15]:
		part(weapon, cyl(0.07, 0.07, 0.05), Color("3a2a22"), Vector3(0, 0, z), Vector3(90, 0, 0))
	var steel := Color("8d97ad")
	part(weapon, box(0.38, 0.32, 0.5), steel, Vector3(0, 0, 0.88))
	for sz in [-1.0, 1.0]:
		part(weapon, cyl(0.19, 0.19, 0.08, 24), steel.lightened(0.15), Vector3(0, 0, 0.88 + 0.28 * sz), Vector3(90, 0, 0))
	part(weapon, box(0.41, 0.35, 0.12), prim, Vector3(0, 0, 0.88))
	for rx in [-0.14, 0.14]:
		part(weapon, sphere(0.03), Color("d9dde8"), Vector3(rx, 0.17, 0.72))

# ------------------------------------------------------------------ VEX: rooftop assassin
func _vex() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	limb_legs(sec, Color("1a1028"), 0.12, 0.38, 0.075, 0.9)
	for lg in [leg_l, leg_r]:
		for y in [-0.12, -0.22]:
			part(lg, torus(0.07, 0.095), sec.lightened(0.25), Vector3(0, y, 0))
		part(lg, cyl(0.001, 0.06, 0.16), sec, Vector3(0, -0.33, 0.2), Vector3(80, 0, 0))
	# tapered tunic + cloak flaps
	part(body, cyl(0.2, 0.31, 0.56, 24), prim, Vector3(0, 0.68, 0))
	part(body, cyl(0.31, 0.36, 0.12, 24), prim.darkened(0.25), Vector3(0, 0.42, 0))
	part(body, box(0.1, 0.46, 0.05), prim.darkened(0.35), Vector3(0, 0.7, 0.27), Vector3(-6, 0, 0))
	part(body, torus(0.26, 0.33), Color("3a2a4a"), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	for sx in [-1.0, 1.0]:
		part(body, box(0.09, 0.1, 0.07), Color("4a3a5a"), Vector3(0.22 * sx, 0.53, 0.2))
		part(body, sphere(0.12), sec.lightened(0.15), Vector3(0.27 * sx, 0.95, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		part(body, box(0.18, 0.5, 0.03), prim.darkened(0.15), Vector3(0.12 * sx, 0.55, -0.27), Vector3(10, 0, 4 * sx))
	part(body, torus(0.18, 0.28), acc, Vector3(0, 1.03, 0), Vector3.ZERO, Vector3(1, 0.85, 1), 0.7)
	var tail := pivot(body, Vector3(0, 1.0, -0.25))
	part(tail, box(0.14, 0.04, 0.4), acc, Vector3(0, 0, -0.18), Vector3.ZERO, Vector3.ONE, 0.6)
	part(tail, box(0.11, 0.035, 0.3), acc.lightened(0.15), Vector3(0.06, -0.04, -0.46), Vector3(0, 12, 0), Vector3.ONE, 0.6)
	extra["tail"] = tail
	arm_l = arm(-1.0, Vector3(0.32, 0.96, 0), prim, Color("2b1f3d"), 0.07, 0.34, 0.095)
	arm_r = arm(1.0, Vector3(0.32, 0.96, 0), prim, Color("2b1f3d"), 0.07, 0.34, 0.095)
	# hooded head with glowing eyes and face mask
	head = pivot(body, Vector3(0, 1.36, 0))
	part(head, sphere(0.4), prim, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.05, 1.0))
	part(head, cyl(0.001, 0.2, 0.46, 20), prim, Vector3(0, 0.3, -0.26), Vector3(-58, 0, 0))
	# face opening: skin around the eyes, dark cloth mask over nose and mouth
	var skin: Color = d.skin
	head.set_meta("skin", skin)
	part(head, sphere(0.3), sec, Vector3(0, -0.02, 0.2), Vector3.ZERO, Vector3(1.05, 0.95, 0.8))
	part(head, sphere(0.27), skin, Vector3(0, 0.05, 0.22), Vector3.ZERO, Vector3(1.12, 0.62, 0.8))
	part(head, sphere(0.27), sec.lightened(0.12), Vector3(0, -0.12, 0.25), Vector3.ZERO, Vector3(1.05, 0.55, 0.78))
	for sx in [-1.0, 1.0]:
		eye(head, Vector3(0.105 * sx, 0.06, 0.4), 0.07, Color("1f8f80"), 0.15)
		brow(head, Vector3(0.11 * sx, 0.16, 0.42), 0.11, -20 * sx, sec, 0.026)
	part(head, torus(0.37, 0.43), prim.darkened(0.12), Vector3(0, 0.0, 0.08), Vector3(80, 0, 0), Vector3(1.0, 1.0, 1.05))
	# twin energy blades (curved, glowing)
	weapon = pivot(arm_r, Vector3(0, -0.34, 0))
	_blade(weapon, acc)
	var w2 := pivot(arm_l, Vector3(0, -0.34, 0))
	_blade(w2, acc)
	extra["blade_l"] = w2

func _blade(parent: Node3D, acc: Color) -> void:
	part(parent, cyl(0.035, 0.035, 0.16), Color("2b1a4d"), Vector3(0, 0, 0.04), Vector3(90, 0, 0))
	part(parent, box(0.14, 0.05, 0.05), Color("4a3a5a"), Vector3(0, 0, 0.13))
	for k in 4:
		var t := float(k) / 3.0
		part(parent, sphere(0.085 - t * 0.035), acc.lightened(0.1 + t * 0.2), Vector3(0, 0.03 + t * t * 0.18, 0.22 + t * 0.32), Vector3(-30 * t, 0, 0), Vector3(0.35, 0.8, 1.6), 1.4 + t)

# ------------------------------------------------------------------ NOVA: sci-fi sharpshooter
func _nova() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	var hair := Color("2a1a14")
	limb_legs(sec.lightened(0.06), acc, 0.12, 0.4, 0.085, 1.05)
	for lg in [leg_l, leg_r]:
		part(lg, sphere(0.075), acc, Vector3(0, -0.2, 0.06), Vector3.ZERO, Vector3(1, 0.8, 0.7))
	# flight jacket
	part(body, capsule(0.27, 0.6), sec, Vector3(0, 0.74, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.92))
	part(body, box(0.06, 0.48, 0.04), prim, Vector3(0, 0.76, 0.25), Vector3.ZERO, Vector3.ONE, 1.2)
	part(body, box(0.5, 0.06, 0.05), prim, Vector3(0, 0.58, 0.22), Vector3.ZERO, Vector3.ONE, 0.8)
	part(body, cyl(0.2, 0.26, 0.12, 24), sec.lightened(0.15), Vector3(0, 1.03, 0))
	part(body, box(0.2, 0.08, 0.24), acc, Vector3(-0.3, 1.0, 0), Vector3(0, 0, 18))
	part(body, torus(0.25, 0.31), Color("3a4766"), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	arm_l = arm(-1.0, Vector3(0.33, 0.95, 0), sec.lightened(0.08), Color("3a4766"), 0.075, 0.34, 0.095)
	arm_r = arm(1.0, Vector3(0.33, 0.95, 0), sec.lightened(0.08), Color("3a4766"), 0.075, 0.34, 0.095)
	# head
	head = pivot(body, Vector3(0, 1.38, 0))
	head.set_meta("skin", skin)
	part(head, sphere(0.4), skin)
	part(head, sphere(0.42), hair, Vector3(0, 0.1, -0.06), Vector3(-22, 0, 0), Vector3(1.0, 0.82, 0.95))
	part(head, sphere(0.16), hair, Vector3(-0.2, 0.22, 0.24), Vector3(0, 0, 30), Vector3(1.6, 0.6, 0.8))
	part(head, sphere(0.12), hair, Vector3(0.18, 0.25, 0.24), Vector3(0, 0, -25), Vector3(1.5, 0.55, 0.8))
	var tail := pivot(head, Vector3(0, 0.2, -0.34))
	part(tail, sphere(0.16), hair, Vector3(0, -0.04, -0.1), Vector3.ZERO, Vector3(0.85, 1.1, 0.85))
	part(tail, sphere(0.13), hair, Vector3(0, -0.22, -0.18))
	part(tail, sphere(0.09), hair, Vector3(0, -0.38, -0.2))
	part(tail, torus(0.05, 0.08), prim, Vector3(0, 0.06, -0.06), Vector3(30, 0, 0), Vector3.ONE, 0.8)
	extra["tail"] = tail
	# visor + headset
	part(head, sphere(0.29), prim, Vector3(0, 0.04, 0.2), Vector3.ZERO, Vector3(1.45, 0.42, 0.75), 1.4)
	part(head, sphere(0.1), Color.WHITE, Vector3(-0.15, 0.08, 0.38), Vector3(0, 0, 10), Vector3(1.5, 0.28, 0.3), 1.0)
	part(head, cyl(0.09, 0.09, 0.08), Color("3a4766"), Vector3(0.38, 0.02, 0), Vector3(0, 0, 90))
	part(head, cyl(0.012, 0.012, 0.3), Color("3a4766"), Vector3(0.42, 0.2, -0.02), Vector3(0, 0, -12))
	part(head, sphere(0.035), prim, Vector3(0.45, 0.36, -0.02), Vector3.ZERO, Vector3.ONE, 2.5)
	part(head, sphere(0.06), Color("5a1a2a"), Vector3(0.06, -0.19, 0.36), Vector3(0, 0, -12), Vector3(1.4, 0.35, 0.35))
	# arc rifle
	weapon = pivot(arm_r, Vector3(-0.08, -0.34, 0))
	part(weapon, box(0.15, 0.17, 0.78), acc, Vector3(0, 0.02, 0.3))
	part(weapon, box(0.11, 0.2, 0.26), Color("3a4766"), Vector3(0, -0.06, -0.14))
	part(weapon, cyl(0.045, 0.05, 0.5), Color("3a4766"), Vector3(0, 0.03, 0.88), Vector3(90, 0, 0))
	for k in 3:
		part(weapon, torus(0.05, 0.075), prim, Vector3(0, 0.03, 0.72 + k * 0.1), Vector3(90, 0, 0), Vector3.ONE, 1.8)
	part(weapon, cyl(0.05, 0.05, 0.3), Color("2b3350"), Vector3(0, 0.17, 0.28), Vector3(90, 0, 0))
	part(weapon, sphere(0.045), prim, Vector3(0, 0.17, 0.44), Vector3.ZERO, Vector3(1, 1, 0.4), 2.5)
	part(weapon, sphere(0.085), prim, Vector3(0, 0.03, 1.15), Vector3.ZERO, Vector3.ONE, 3.0)

# ------------------------------------------------------------------ MIRA: lantern keeper
func _mira() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	limb_legs(Color("f5e8f0"), prim.darkened(0.25), 0.11, 0.34, 0.07, 0.95)
	for lg in [leg_l, leg_r]:
		part(lg, torus(0.065, 0.085), prim, Vector3(0, -0.1, 0))
	# bell dress with apron and trims
	part(body, cyl(0.17, 0.46, 0.56, 32), sec, Vector3(0, 0.66, 0))
	part(body, torus(0.42, 0.5), prim, Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
	part(body, cyl(0.12, 0.3, 0.42, 24), Color("fff3f8"), Vector3(0, 0.62, 0.12), Vector3(-8, 0, 0), Vector3(1, 1, 0.55))
	part(body, sphere(0.2), sec.lightened(0.1), Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(1.05, 0.7, 0.9))
	part(body, torus(0.14, 0.21), Color("fff3f8"), Vector3(0, 1.05, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	part(body, sphere(0.08), acc, Vector3(-0.07, 0.86, 0.2), Vector3(0, 0, 25), Vector3(1.2, 0.7, 0.6), 0.4)
	part(body, sphere(0.08), acc, Vector3(0.07, 0.86, 0.2), Vector3(0, 0, -25), Vector3(1.2, 0.7, 0.6), 0.4)
	part(body, sphere(0.04), acc.lightened(0.2), Vector3(0, 0.86, 0.23), Vector3.ZERO, Vector3.ONE, 0.6)
	arm_l = arm(-1.0, Vector3(0.24, 0.95, 0), sec.lightened(0.1), skin, 0.065, 0.3, 0.085)
	arm_r = arm(1.0, Vector3(0.24, 0.95, 0), sec.lightened(0.1), skin, 0.065, 0.3, 0.085)
	# head + big hair with twin buns
	head = pivot(body, Vector3(0, 1.36, 0))
	head.set_meta("skin", skin)
	part(head, sphere(0.47), prim, Vector3(0, 0.06, -0.1))
	for sx in [-1.0, 1.0]:
		part(head, sphere(0.2), prim, Vector3(0.38 * sx, 0.34, -0.06))
		part(head, torus(0.08, 0.13), acc, Vector3(0.3 * sx, 0.26, -0.02), Vector3(0, 0, 40 * sx), Vector3.ONE, 0.5)
		part(head, capsule(0.08, 0.38), prim, Vector3(0.36 * sx, -0.14, 0.06), Vector3(0, 0, 8 * sx))
	part(head, sphere(0.37), skin, Vector3(0, -0.04, 0.09))
	for k in 3:
		var x := (k - 1) * 0.17
		part(head, sphere(0.14), prim.lightened(0.06), Vector3(x, 0.24, 0.24 - absf(x) * 0.3), Vector3(-30, 0, -x * 60), Vector3(1.0, 0.75, 0.9))
	eye(head, Vector3(-0.14, -0.03, 0.42), 0.095, prim.darkened(0.25))
	eye(head, Vector3(0.14, -0.03, 0.42), 0.095, prim.darkened(0.25))
	brow(head, Vector3(-0.14, 0.12, 0.43), 0.1, 8, prim.darkened(0.35), 0.022)
	brow(head, Vector3(0.14, 0.12, 0.43), 0.1, -8, prim.darkened(0.35), 0.022)
	for sx in [-1.0, 1.0]:
		part(head, sphere(0.06), Color("ff8aa8"), Vector3(0.23 * sx, -0.13, 0.4), Vector3.ZERO, Vector3(1.3, 0.6, 0.4))
	smile(head, Vector3(0, -0.2, 0.42), 0.09, 0.45, false)
	# lantern
	weapon = pivot(arm_r, Vector3(0, -0.3, 0.05))
	var gold := Color("e0b44a")
	part(weapon, cyl(0.025, 0.025, 0.2), gold, Vector3(0, 0.0, 0.12), Vector3(60, 0, 0))
	part(weapon, cyl(0.001, 0.15, 0.1, 24), gold, Vector3(0, 0.0, 0.3))
	part(weapon, cyl(0.14, 0.14, 0.04, 24), gold.darkened(0.1), Vector3(0, -0.05, 0.3))
	part(weapon, cyl(0.11, 0.11, 0.24, 24), acc, Vector3(0, -0.19, 0.3), Vector3.ZERO, Vector3.ONE, 0.9)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		part(weapon, cyl(0.015, 0.015, 0.26), gold, Vector3(cos(a) * 0.12, -0.19, 0.3 + sin(a) * 0.12))
	part(weapon, cyl(0.14, 0.12, 0.05, 24), gold.darkened(0.1), Vector3(0, -0.33, 0.3))
	extra["flame"] = part(weapon, sphere(0.055), Color.WHITE, Vector3(0, -0.19, 0.3), Vector3.ZERO, Vector3(1, 1.4, 1), 3.0)

# ------------------------------------------------------------------ SPRIG: goblin gardener
func _sprig() -> void:
	var prim: Color = d.primary
	var sec: Color = d.secondary
	var acc: Color = d.accent
	var skin: Color = d.skin
	limb_legs(Color("6b4a2a"), Color("5a3a1e"), 0.12, 0.3, 0.075, 1.15)
	# overalls body
	part(body, sphere(0.3), skin, Vector3(0, 0.66, 0), Vector3.ZERO, Vector3(1.0, 1.05, 0.92))
	part(body, sphere(0.31), prim, Vector3(0, 0.55, 0.01), Vector3.ZERO, Vector3(1.04, 0.72, 0.95))
	part(body, box(0.26, 0.18, 0.06), prim, Vector3(0, 0.7, 0.25), Vector3(8, 0, 0))
	part(body, box(0.12, 0.08, 0.04), prim.darkened(0.2), Vector3(0, 0.67, 0.29))
	for sx in [-1.0, 1.0]:
		part(body, box(0.06, 0.28, 0.04), acc, Vector3(0.1 * sx, 0.82, 0.22), Vector3(12, 0, 0))
		part(body, sphere(0.03), Color("d9dde8"), Vector3(0.1 * sx, 0.74, 0.27))
	# seed sack backpack with sprouts
	part(body, sphere(0.25), Color("9a6a3e"), Vector3(0, 0.72, -0.3), Vector3.ZERO, Vector3(1.0, 1.1, 0.75))
	part(body, torus(0.12, 0.17), Color("6b4a2a"), Vector3(0, 0.95, -0.3))
	for k in 3:
		part(body, cyl(0.001, 0.04, 0.14), prim.lightened(0.1), Vector3(-0.08 + k * 0.08, 1.04 + (k % 2) * 0.03, -0.3), Vector3(0, 0, -15 + k * 15))
	part(body, sphere(0.05), acc, Vector3(0.14, 0.88, -0.42))
	arm_l = arm(-1.0, Vector3(0.27, 0.74, 0), skin, skin, 0.06, 0.28, 0.085)
	arm_r = arm(1.0, Vector3(0.27, 0.74, 0), skin, skin, 0.06, 0.28, 0.085)
	# big goblin head
	head = pivot(body, Vector3(0, 1.12, 0))
	head.set_meta("skin", skin)
	part(head, sphere(0.42), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.12, 0.94, 0.98))
	var ear_l := pivot(head, Vector3(-0.42, 0.06, 0))
	var ear_r := pivot(head, Vector3(0.42, 0.06, 0))
	for e in [[ear_l, -1.0], [ear_r, 1.0]]:
		var ep: Node3D = e[0]
		var sx: float = e[1]
		part(ep, cyl(0.001, 0.13, 0.48, 16), skin, Vector3(0.18 * sx, 0.07, 0), Vector3(0, 0, -72 * sx), Vector3(1, 1, 0.55))
		part(ep, cyl(0.001, 0.08, 0.34, 16), Color("ff9fb0"), Vector3(0.18 * sx, 0.07, 0.04), Vector3(0, 0, -72 * sx), Vector3(1, 1, 0.3))
	extra["ear_l"] = ear_l
	extra["ear_r"] = ear_r
	part(head, sphere(0.09), skin.darkened(0.08), Vector3(0, -0.06, 0.4), Vector3(-10, 0, 0), Vector3(0.9, 0.8, 1.3))
	eye(head, Vector3(-0.16, 0.0, 0.37), 0.1, Color("e8a51a"))
	eye(head, Vector3(0.16, 0.0, 0.37), 0.1, Color("e8a51a"))
	brow(head, Vector3(-0.16, 0.13, 0.4), 0.1, 18, Color("2f4a1f"), 0.025)
	brow(head, Vector3(0.16, 0.13, 0.4), 0.1, -18, Color("2f4a1f"), 0.025)
	smile(head, Vector3(0, -0.2, 0.34), 0.2, 0.32)
	for sx in [-1.0, 1.0]:
		part(head, cyl(0.022, 0.001, 0.07, 8), Color.WHITE, Vector3(0.06 * sx, -0.19, 0.39))
	# goggles on the forehead
	part(head, torus(0.4, 0.44), Color("6b3f1f"), Vector3(0, 0.2, 0), Vector3(-12, 0, 0), Vector3(1.12, 1, 1))
	for sx in [-1.0, 1.0]:
		part(head, torus(0.07, 0.115), acc, Vector3(0.14 * sx, 0.25, 0.34), Vector3(76, 0, 0))
		part(head, sphere(0.075), Color("bff4ff"), Vector3(0.14 * sx, 0.25, 0.35), Vector3.ZERO, Vector3(1, 1, 0.4), 0.8)
	part(head, cyl(0.022, 0.022, 0.18), sec, Vector3(0, 0.46, 0))
	var sprout := pivot(head, Vector3(0, 0.55, 0))
	part(sprout, sphere(0.13), prim.lightened(0.05), Vector3(-0.11, 0.03, 0), Vector3(0, 0, 32), Vector3(1.35, 0.4, 0.75))
	part(sprout, sphere(0.13), prim.lightened(0.05), Vector3(0.11, 0.03, 0), Vector3(0, 0, -32), Vector3(1.35, 0.4, 0.75))
	extra["sprout"] = sprout
	# seed bomb in hand
	weapon = pivot(arm_r, Vector3(0, -0.28, 0.02))
	part(weapon, sphere(0.12), acc, Vector3(0, 0, 0.08))
	part(weapon, sphere(0.05), Color.WHITE, Vector3(-0.04, 0.05, 0.17), Vector3.ZERO, Vector3.ONE, 0.6)
	part(weapon, cyl(0.015, 0.015, 0.1), sec, Vector3(0, 0.13, 0.08))
	part(weapon, sphere(0.06), prim, Vector3(0.05, 0.18, 0.08), Vector3(0, 0, -30), Vector3(1.4, 0.5, 0.8))

# ------------------------------------------------------------------ draw-call merging
static func _vc_mat(ow: float) -> ShaderMaterial:
	if _vc_mats.has(ow):
		return _vc_mats[ow]
	var m := ShaderMaterial.new()
	m.shader = TOON_VC
	mat(Color.WHITE, 0.0, 0.18, ow) # makes sure the outline material for this width exists
	m.next_pass = _outline_mats[ow]
	_vc_mats[ow] = m
	return m

## Welds all the static pieces of each body part into one mesh with vertex colours,
## so each limb is a single draw call instead of one per piece.
func _merge_parts() -> void:
	var keep: Array = extra.values()
	var pivots: Array = [self]
	for n in find_children("*", "Node3D", true, false):
		if not (n is MeshInstance3D):
			pivots.append(n)
	for pv in pivots:
		var parts: Array = []
		for c in pv.get_children():
			if c is MeshInstance3D and not (c in keep) and c.has_meta("col"):
				parts.append(c)
		if parts.size() < 2:
			continue
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var uv2 := PackedVector2Array()
		var idx := PackedInt32Array()
		for mi: MeshInstance3D in parts:
			var arr: Array = (mi.mesh as PrimitiveMesh).get_mesh_arrays()
			var xf: Transform3D = mi.transform
			var nb: Basis = xf.basis.inverse().transposed()
			var base := verts.size()
			var col: Color = mi.get_meta("col")
			var glow: float = mi.get_meta("glow")
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var miny := INF
			var maxy := -INF
			for v in vs:
				miny = minf(miny, v.y)
				maxy = maxf(maxy, v.y)
			var span := maxf(0.001, maxy - miny)
			for k in vs.size():
				verts.append(xf * vs[k])
				normals.append((nb * ns[k]).normalized())
				# soft occlusion: each piece darkens slightly toward its underside
				var shade := lerpf(0.82, 1.04, clampf((vs[k].y - miny) / span, 0.0, 1.0)) if glow < 0.5 else 1.0
				colors.append(Color(col.r * shade, col.g * shade, col.b * shade, 1.0))
				uv2.append(Vector2(glow, 0.0))
			var ind = arr[Mesh.ARRAY_INDEX]
			if ind == null or (ind as PackedInt32Array).is_empty():
				for k in vs.size():
					idx.append(base + k)
			else:
				for i in (ind as PackedInt32Array):
					idx.append(base + i)
			pv.remove_child(mi)
			mi.free()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var merged := MeshInstance3D.new()
		merged.mesh = am
		merged.material_override = _vc_mat(outline_width)
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pv.add_child(merged)
		pv.move_child(merged, 0)

# ------------------------------------------------------------------ animation
## state: t, moving, recoil (1 -> 0), yaw (radians, 0 = facing camera), instant
var _move_blend := 0.0

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

	# chunky, bouncy cartoon run: big leg swing, a hop on every step with
	# squash on landing and stretch in the air, forward lean, lagging head.
	var walk := sin(_t * 13.0)
	var hop := absf(walk)
	var swing := walk * 0.85 if moving else 0.0
	_move_blend = move_toward(_move_blend, 1.0 if moving else 0.0, delta * 8.0)
	var mb := _move_blend
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	var breathe := sin(_t * 2.6)
	body.position.y = lerpf(breathe * 0.012, hop * 0.11, mb)
	var stretch := lerpf(breathe * 0.02, (hop - 0.5) * 0.12, mb)
	body.scale = Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5)
	body.rotation.z = walk * 0.07 * mb
	body.rotation.x = 0.16 * mb
	body.rotation.y = walk * 0.08 * mb
	arm_l.rotation.x = -swing * 0.9
	arm_l.rotation.z = -0.18 - hop * 0.15 * mb
	head.rotation.z = sin(_t * 1.7) * 0.05 * (1.0 - mb) - walk * 0.05 * mb
	head.rotation.x = -0.08 * mb + cos(_t * 13.0) * 0.04 * mb
	# attack lunge: whole body jolts forward and squashes a little
	if recoil > 0.0:
		body.position.z = recoil * 0.12
		body.scale *= Vector3(1.0 + recoil * 0.06, 1.0 - recoil * 0.06, 1.0 + recoil * 0.06)
	else:
		body.position.z = 0.0

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
