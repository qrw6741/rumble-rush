class_name TouchControls
extends Control
## Mobile controls: floating move stick (left half), attack stick, super stick
## and gadget button (right side). Drag to aim, release to fire; quick-tap to
## auto-aim at the nearest enemy.

const STICK_R := 85.0
const DEADZONE := 16.0

var ctrl: PlayerController
var b: Brawler

var move_vec := Vector2.ZERO
var attack_vec := Vector2.ZERO
var super_vec := Vector2.ZERO
var attack_active := false
var super_active := false

var _move_idx := -1
var _move_center := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _atk_idx := -1
var _sup_idx := -1
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _sensitivity() -> float:
	return 1.0

func attack_center() -> Vector2:
	return Vector2(size.x - 190, size.y - 210)

func super_center() -> Vector2:
	return Vector2(size.x - 385, size.y - 125)

func gadget_center() -> Vector2:
	return Vector2(size.x - 262, size.y - 62)

func move_home() -> Vector2:
	return Vector2(190, size.y - 165)

func _input(event: InputEvent) -> void:
	if not visible or ctrl == null:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if p.distance_to(gadget_center()) < 52.0:
				ctrl.touch_gadget()
				get_viewport().set_input_as_handled()
			elif _sup_idx == -1 and p.distance_to(super_center()) < 66.0:
				_sup_idx = event.index
				super_active = true
				super_vec = Vector2.ZERO
			elif _atk_idx == -1 and p.distance_to(attack_center()) < 120.0:
				_atk_idx = event.index
				attack_active = true
				attack_vec = Vector2.ZERO
			elif _move_idx == -1 and p.x < size.x * 0.5 and p.y > 90.0:
				_move_idx = event.index
				_move_center = p
				_move_knob = p
				move_vec = Vector2.ZERO
		else:
			if event.index == _move_idx:
				_move_idx = -1
				move_vec = Vector2.ZERO
			elif event.index == _atk_idx:
				_atk_idx = -1
				attack_active = false
				ctrl.touch_attack(attack_vec)
				attack_vec = Vector2.ZERO
			elif event.index == _sup_idx:
				_sup_idx = -1
				super_active = false
				ctrl.touch_super(super_vec)
				super_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var p: Vector2 = event.position
		if event.index == _move_idx:
			var v := p - _move_center
			if v.length() > STICK_R:
				# drag the base along so the stick never "runs out"
				_move_center = p - v.normalized() * STICK_R
				v = p - _move_center
			_move_knob = p
			move_vec = (v / STICK_R).limit_length(1.0) if v.length() > 8.0 else Vector2.ZERO
		elif event.index == _atk_idx:
			attack_vec = (p - attack_center()).limit_length(STICK_R)
		elif event.index == _sup_idx:
			super_vec = (p - super_center()).limit_length(STICK_R)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

## Glossy round button: drop shadow, ink rim, radial shading and a top highlight.
func _glossy(c: Vector2, r: float, col: Color, alpha := 1.0) -> void:
	draw_circle(c + Vector2(0, 5), r + 3, Color(0, 0, 0, 0.28 * alpha))
	draw_circle(c, r + 3, Color(0.1, 0.06, 0.16, 0.9 * alpha))
	var steps := 8
	for i in steps:
		var k := float(i) / steps
		var cc := col.darkened(0.28).lerp(col.lightened(0.12), k)
		cc.a = alpha
		draw_circle(c + Vector2(0, -r * 0.08 * k), r * (1.0 - k * 0.55), cc)
	draw_circle(c + Vector2(-r * 0.22, -r * 0.42), r * 0.28, Color(1, 1, 1, 0.28 * alpha))

func _ring(c: Vector2, r: float, col: Color, fill_a: float) -> void:
	var f := col
	f.a = fill_a
	draw_circle(c, r, f)
	var e := col
	e.a = 0.55
	draw_arc(c, r, 0, TAU, 72, e, 5.0, true)
	draw_arc(c, r - 9, 0, TAU, 72, Color(1, 1, 1, 0.12), 2.0, true)

## Thick "coin" button: darker rim showing underneath, flat face with a soft
## top-to-bottom gradient and a subtle highlight band.
func _coin(c: Vector2, r: float, top: Color, bottom: Color, rim: Color, alpha := 1.0) -> void:
	draw_circle(c + Vector2(0, 8), r + 2, Color(0, 0, 0, 0.25 * alpha))
	draw_circle(c + Vector2(0, 6), r, Color(rim.r, rim.g, rim.b, alpha))
	var steps := 10
	for i in steps:
		var k := float(i) / (steps - 1)
		var cc := bottom.lerp(top, k)
		cc.a = alpha
		draw_circle(c + Vector2(0, -r * 0.06 * k), r * (1.0 - k * 0.12), cc)
	draw_arc(c, r - 1.5, 0, TAU, 64, Color(rim.r, rim.g, rim.b, 0.6 * alpha), 3.0, true)

## Thin dark outline ring around a stick's travel area.
func _outline_ring(c: Vector2, r: float, col: Color, fill_a := 0.0) -> void:
	if fill_a > 0.0:
		draw_circle(c, r, Color(col.r, col.g, col.b, fill_a))
	draw_arc(c, r, 0, TAU, 80, col, 9.0, true)

## Four chunky movement arrows embossed on the blue knob.
func _arrows(c: Vector2, r: float, col: Color) -> void:
	for k in 4:
		var d := Vector2.UP.rotated(k * PI / 2.0)
		var n := d.orthogonal()
		var tip := c + d * r * 0.95
		var base := c + d * r * 0.55
		draw_colored_polygon(PackedVector2Array([tip, base + n * r * 0.3, base + n * r * 0.13, c + d * r * 0.3 + n * r * 0.13, c + d * r * 0.3 - n * r * 0.13, base - n * r * 0.13, base - n * r * 0.3]), col)

func _draw() -> void:
	if b == null:
		return
	var ink := Color(0.1, 0.06, 0.16, 0.9)
	var blue_top := Color("2f8dff")
	var blue_bot := Color("1f68e0")
	var blue_rim := Color("0d3d9a")
	# ---------- MOVE
	var mc := move_home() if _move_idx == -1 else _move_center
	_outline_ring(mc, STICK_R + 30, Color("0e2a66", 0.9), 0.0 if _move_idx == -1 else 0.12)
	var knob := mc + move_vec * STICK_R
	_coin(knob, 58, blue_top, blue_bot, blue_rim)
	_arrows(knob + Vector2(0, -2), 50, Color("1a5ccf"))
	# ---------- ATTACK
	var ac := attack_center()
	_outline_ring(ac, 112, Color("6a0b0b", 0.95), 0.18 if attack_active else 0.0)
	var ak := ac + attack_vec
	if attack_active and attack_vec.length() > DEADZONE:
		draw_line(ac, ak, Color(1, 1, 1, 0.35), 6.0, true)
	_coin(ak, 64, Color("f2533f"), Color("d93a2c"), Color("8a1712"))
	_crosshair(ak, 26)
	# ammo segments hugging the ring
	for i in b.max_ammo:
		var a0 := PI * 1.12 + i * 0.3
		var fillk := clampf(b.ammo - i, 0.0, 1.0)
		draw_arc(ac, 128, a0, a0 + 0.25, 8, ink, 11.0, true)
		draw_arc(ac, 128, a0, a0 + 0.25 * fillk, 8, Color("ff9d2e"), 6.0, true)
	# ---------- SUPER
	var sc0 := super_center()
	var is_ready := b.super_charge >= 1.0
	if super_active:
		_outline_ring(sc0, STICK_R + 10, Color("7a5200", 0.9), 0.15)
	var sc := sc0 + super_vec
	if is_ready:
		for k in 3:
			draw_circle(sc, 50 + k * 7 + sin(_t * 6.0) * 3.0, Color(1, 0.85, 0.2, 0.12))
		_coin(sc, 46, Color("ffd93a"), Color("f2a01a"), Color("b8560e"))
		UIKit.draw_icon(self, "ab_%s_super" % b.id, sc + Vector2(0, -2), 62.0)
	else:
		_coin(sc, 46, Color("5a6078"), Color("454b62"), Color("262a3c"), 0.92)
		draw_arc(sc, 40, -PI / 2, -PI / 2 + TAU * b.super_charge, 56, Color("ffd23a"), 7.0, true)
		UIKit.draw_icon(self, "ab_%s_super" % b.id, sc, 52.0, Color(0.6, 0.6, 0.66, 0.8))
	# ---------- GADGET
	var gc := gadget_center()
	var cd := b.gadget_cd / b.gadget_max_cd
	if cd <= 0.0:
		_coin(gc, 36, Color("3fdc3c"), Color("22b522"), Color("0e6e12"))
	else:
		_coin(gc, 36, Color("4a5268"), Color("3a4258"), Color("22283a"))
	UIKit.draw_icon(self, "ab_%s_gadget" % b.id, gc + Vector2(0, -1), 50.0, Color.WHITE if cd <= 0.0 else Color(0.55, 0.55, 0.6))
	if cd > 0.0:
		draw_arc(gc, 31, -PI / 2, -PI / 2 + TAU * (1.0 - cd), 36, Color("4dff7a"), 5.0, true)
		var f := FX._font()
		var label := str(int(ceil(b.gadget_cd)))
		var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		draw_string_outline(f, gc + Vector2(-ls.x * 0.5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 7, ink)
		draw_string(f, gc + Vector2(-ls.x * 0.5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)

func _crosshair(c: Vector2, r: float) -> void:
	var col := Color("b52a20")
	draw_arc(c, r, 0, TAU, 40, col, 7.0, true)
	draw_line(c + Vector2(-r - 10, 0), c + Vector2(-r + 8, 0), col, 7.0, true)
	draw_line(c + Vector2(r - 8, 0), c + Vector2(r + 10, 0), col, 7.0, true)
	draw_line(c + Vector2(0, -r - 10), c + Vector2(0, -r + 8), col, 7.0, true)
	draw_line(c + Vector2(0, r - 8), c + Vector2(0, r + 10), col, 7.0, true)
	draw_circle(c, 5.0, col)
