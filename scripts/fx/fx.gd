class_name FX
extends RefCounted
## Visual-effects helpers: particle bursts, shockwaves, floating damage numbers.

static var font: Font

static func _font() -> Font:
	if font == null:
		font = load("res://assets/fonts/Poppins-Bold.ttf")
	return font

static func burst(parent: Node, pos: Vector2, color: Color, amount := 14, speed := 220.0, life := 0.5, size := 5.0, spread := 180.0, dir := Vector2.UP) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 20
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.gravity = Vector2.ZERO
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, color.lightened(0.3))
	var end := color
	end.a = 0.0
	g.set_color(1, end)
	p.color_ramp = g
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.2, false).timeout.connect(p.queue_free)

static func debris_ring(parent: Node, pos: Vector2, color: Color) -> void:
	shockwave(parent, pos, 40.0, color, 0.3, 4.0)

static func shockwave(parent: Node, pos: Vector2, radius: float, color: Color, duration := 0.35, width := 6.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := Shockwave.new()
	s.position = pos
	s.max_radius = radius
	s.color = color
	s.duration = duration
	s.width = width
	parent.add_child(s)

static func number(parent: Node, pos: Vector2, text: String, color: Color, big := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if not Save.setting("damage_numbers"):
		return
	var n := FloatingText.new()
	n.position = pos + Vector2(randf_range(-10, 10), 0)
	n.text = text
	n.color = color
	n.big = big
	parent.add_child(n)


class Shockwave extends Node2D:
	var max_radius := 60.0
	var color := Color.WHITE
	var duration := 0.35
	var width := 6.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 15

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		var e := 1.0 - pow(1.0 - k, 3.0)
		var c := color
		c.a = (1.0 - k) * 0.9
		draw_arc(Vector2.ZERO, max_radius * e, 0, TAU, 48, c, width * (1.0 - k * 0.6), true)
		c.a *= 0.25
		draw_circle(Vector2.ZERO, max_radius * e, c)


class FloatingText extends Node2D:
	var text := ""
	var color := Color.WHITE
	var big := false
	var _t := 0.0
	const LIFE := 0.85

	func _ready() -> void:
		z_index = 40

	func _process(delta: float) -> void:
		_t += delta
		position.y -= delta * (70.0 if _t < 0.3 else 22.0)
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var f := FX._font()
		var size := 30 if big else 22
		var pop: float = 1.0 + maxf(0.0, 0.25 - _t) * 2.2
		var a := clampf((LIFE - _t) / 0.3, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := Vector2(-w * 0.5, 0)
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0.08, 0.05, 0.15, a))
		var c := color
		c.a = a
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
