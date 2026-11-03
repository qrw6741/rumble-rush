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
	return Vector2(size.x - 175, size.y - 160)

func super_center() -> Vector2:
	return Vector2(size.x - 345, size.y - 105)

func gadget_center() -> Vector2:
	return Vector2(size.x - 320, size.y - 245)

func move_home() -> Vector2:
	return Vector2(190, size.y - 160)

func _input(event: InputEvent) -> void:
	if not visible or ctrl == null:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if p.distance_to(gadget_center()) < 52.0:
				ctrl.touch_gadget()
				get_viewport().set_input_as_handled()
			elif _sup_idx == -1 and p.distance_to(super_center()) < 62.0:
				_sup_idx = event.index
				super_active = true
				super_vec = Vector2.ZERO
			elif _atk_idx == -1 and p.distance_to(attack_center()) < 105.0:
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

func _draw() -> void:
	if b == null:
		return
	var outline := Color(0.1, 0.06, 0.16, 0.6)
	# move stick
	var mc := _move_center if _move_idx != -1 else move_home()
	draw_circle(mc, STICK_R, Color(1, 1, 1, 0.08 if _move_idx == -1 else 0.14))
	draw_arc(mc, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.3), 3.0, true)
	var knob := mc + move_vec * STICK_R
	draw_circle(knob, 34, Color(1, 1, 1, 0.35))
	draw_arc(knob, 34, 0, TAU, 32, outline, 3.0, true)
	# attack stick
	var ac := attack_center()
	draw_circle(ac, 82, Color(1, 0.55, 0.15, 0.16 if not attack_active else 0.28))
	draw_arc(ac, 82, 0, TAU, 48, Color(1, 0.7, 0.3, 0.6), 3.0, true)
	var ak := ac + attack_vec
	draw_circle(ak, 44, Color(1, 0.55, 0.15, 0.85))
	draw_arc(ak, 44, 0, TAU, 32, outline, 4.0, true)
	_crosshair(ak, 16)
	# ammo pips around attack button
	for i in b.max_ammo:
		var a0 := PI * 1.15 + i * 0.32
		var fillk := clampf(b.ammo - i, 0.0, 1.0)
		draw_arc(ac, 94, a0, a0 + 0.26, 8, Color(0.2, 0.12, 0.08, 0.6), 8.0, true)
		draw_arc(ac, 94, a0, a0 + 0.26 * fillk, 8, Color("ff9d2e"), 8.0, true)
	# super stick
	var sc := super_center()
	var is_ready := b.super_charge >= 1.0
	draw_circle(sc, 56, Color(0.1, 0.06, 0.16, 0.45))
	draw_arc(sc, 56, -PI / 2, -PI / 2 + TAU * b.super_charge, 48, Color("ffd23a"), 7.0, true)
	var sk := sc + super_vec
	var pulse := 0.85 + 0.15 * sin(_t * 8.0)
	draw_circle(sk, 40, Color("ffd23a") * Color(1, 1, 1, pulse if is_ready else 0.3))
	draw_arc(sk, 40, 0, TAU, 32, outline, 4.0, true)
	_skull(sk, is_ready)
	# gadget
	var gc := gadget_center()
	var cd := b.gadget_cd / b.gadget_max_cd
	draw_circle(gc, 38, Color("4fd36a") if cd <= 0.0 else Color(0.25, 0.35, 0.28, 0.7))
	if cd > 0.0:
		draw_arc(gc, 38, -PI / 2, -PI / 2 + TAU * (1.0 - cd), 36, Color("4fd36a"), 6.0, true)
	draw_arc(gc, 38, 0, TAU, 32, outline, 4.0, true)
	var f := FX._font()
	var label := "G" if cd <= 0.0 else str(int(ceil(b.gadget_cd)))
	var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	draw_string(f, gc + Vector2(-ls.x * 0.5, 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func _crosshair(c: Vector2, r: float) -> void:
	var col := Color(1, 1, 1, 0.9)
	draw_arc(c, r, 0, TAU, 24, col, 3.0, true)
	draw_line(c + Vector2(-r - 6, 0), c + Vector2(-r + 5, 0), col, 3.0)
	draw_line(c + Vector2(r - 5, 0), c + Vector2(r + 6, 0), col, 3.0)
	draw_line(c + Vector2(0, -r - 6), c + Vector2(0, -r + 5), col, 3.0)
	draw_line(c + Vector2(0, r - 5), c + Vector2(0, r + 6), col, 3.0)

func _skull(c: Vector2, is_ready: bool) -> void:
	var col := Color(0.15, 0.08, 0.02, 0.9 if is_ready else 0.5)
	# lightning bolt icon
	var pts := PackedVector2Array([c + Vector2(4, -20), c + Vector2(-10, 3), c + Vector2(-1, 3), c + Vector2(-5, 20), c + Vector2(10, -4), c + Vector2(1, -4)])
	draw_colored_polygon(pts, col)
