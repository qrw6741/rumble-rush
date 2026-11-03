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
	return Vector2(size.x - 160, size.y - 150)

func super_center() -> Vector2:
	return Vector2(size.x - 335, size.y - 95)

func gadget_center() -> Vector2:
	return Vector2(size.x - 300, size.y - 235)

func move_home() -> Vector2:
	return Vector2(150, size.y - 140)

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

func _draw() -> void:
	if b == null:
		return
	var ink := Color(0.1, 0.06, 0.16, 0.9)
	# ---------- MOVE: blue button at rest; translucent base + blue knob while held
	if _move_idx == -1:
		_ring(move_home(), STICK_R, Color(0.25, 0.5, 1.0), 0.08)
		_glossy(move_home(), 46, Color("2f7bf0"))
		UIKit.draw_icon(self, "dpad", move_home(), 78.0, Color(1, 1, 1, 0.95))
	else:
		_ring(_move_center, STICK_R, Color(0.25, 0.5, 1.0), 0.16)
		var knob := _move_center + move_vec * STICK_R
		_glossy(knob, 42, Color("2f7bf0"))
		UIKit.draw_icon(self, "dpad", knob, 70.0)
	# ---------- ATTACK: big translucent red ring, glossy red knob with crosshair
	var ac := attack_center()
	_ring(ac, 104, Color(1.0, 0.25, 0.25), 0.14 if not attack_active else 0.24)
	var ak := ac + attack_vec
	if attack_active and attack_vec.length() > DEADZONE:
		draw_line(ac, ak, Color(1, 1, 1, 0.35), 6.0, true)
	_glossy(ak, 48, Color("f0443c"), 0.92)
	_crosshair(ak, 19)
	# ammo segments hugging the ring
	for i in b.max_ammo:
		var a0 := PI * 1.1 + i * 0.3
		var fillk := clampf(b.ammo - i, 0.0, 1.0)
		draw_arc(ac, 116, a0, a0 + 0.25, 8, ink, 11.0, true)
		draw_arc(ac, 116, a0, a0 + 0.25 * fillk, 8, Color("ff9d2e"), 6.0, true)
	# ---------- SUPER: charges with a yellow ring, turns solid glowing yellow when ready
	var sc0 := super_center()
	var is_ready := b.super_charge >= 1.0
	if super_active:
		_ring(sc0, STICK_R, Color(1.0, 0.82, 0.2), 0.18)
	var sc := sc0 + super_vec
	if is_ready:
		for k in 3:
			draw_circle(sc, 58 + k * 7 + sin(_t * 6.0) * 3.0, Color(1, 0.85, 0.2, 0.13))
		_glossy(sc, 50, Color("ffcc1f"))
		UIKit.draw_icon(self, "ab_%s_super" % b.id, sc, 72.0)
	else:
		_glossy(sc, 50, Color("3a3f58"), 0.9)
		draw_arc(sc, 44, -PI / 2, -PI / 2 + TAU * b.super_charge, 56, Color("ffd23a"), 8.0, true)
		UIKit.draw_icon(self, "ab_%s_super" % b.id, sc, 60.0, Color(0.6, 0.6, 0.66, 0.8))
	# ---------- GADGET: small glossy green button
	var gc := gadget_center()
	var cd := b.gadget_cd / b.gadget_max_cd
	_glossy(gc, 34, Color("33b54a") if cd <= 0.0 else Color("3a4258"))
	UIKit.draw_icon(self, "ab_%s_gadget" % b.id, gc, 56.0, Color.WHITE if cd <= 0.0 else Color(0.55, 0.55, 0.6))
	if cd > 0.0:
		draw_arc(gc, 30, -PI / 2, -PI / 2 + TAU * (1.0 - cd), 36, Color("4dff7a"), 5.0, true)
		var f := FX._font()
		var label := str(int(ceil(b.gadget_cd)))
		var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		draw_string_outline(f, gc + Vector2(-ls.x * 0.5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 7, ink)
		draw_string(f, gc + Vector2(-ls.x * 0.5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)

func _crosshair(c: Vector2, r: float) -> void:
	var ink := Color(0.35, 0.05, 0.05, 0.9)
	var col := Color(1, 1, 1, 0.95)
	for pass_i in 2:
		var w := 6.0 if pass_i == 0 else 3.0
		var cc := ink if pass_i == 0 else col
		draw_arc(c, r, 0, TAU, 28, cc, w, true)
		draw_line(c + Vector2(-r - 7, 0), c + Vector2(-r + 6, 0), cc, w)
		draw_line(c + Vector2(r - 6, 0), c + Vector2(r + 7, 0), cc, w)
		draw_line(c + Vector2(0, -r - 7), c + Vector2(0, -r + 6), cc, w)
		draw_line(c + Vector2(0, r - 6), c + Vector2(0, r + 7), cc, w)
	draw_circle(c, 3.0, col)
