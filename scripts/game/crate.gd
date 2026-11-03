class_name Crate
extends StaticBody2D
## Destructible cover. Blocks movement and shots until it is smashed.

const T := 48.0
const LIFT := 12.0
const MAX_HP := 2600.0

var cell := Vector2i.ZERO
var theme: Dictionary
var hp := MAX_HP
var map: ArenaMap
var _shake := 0.0
var _flash := 0.0

func setup(m: ArenaMap, c: Vector2i, th: Dictionary) -> void:
	map = m
	cell = c
	theme = th
	position = Vector2((c.x + 0.5) * T, (c.y + 1) * T)
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(T - 2, T - 2)
	cs.shape = rs
	cs.position = Vector2(0, -T * 0.5)
	add_child(cs)
	add_to_group("crates")

func take_damage(amount: float, _source = null) -> void:
	if hp <= 0:
		return
	hp -= amount
	_shake = 0.18
	_flash = 1.0
	if hp <= 0:
		_break()
	else:
		Sfx.play_at("hit", global_position, -8.0)

func _break() -> void:
	map.crate_destroyed(cell)
	Sfx.play_at("crate_break", global_position, -2.0)
	FX.burst(get_parent(), global_position + Vector2(0, -T * 0.5), theme.crate, 18, 260.0, 0.6, 5.0)
	FX.burst(get_parent(), global_position + Vector2(0, -T * 0.5), theme.crate_dark, 10, 200.0, 0.5, 4.0)
	FX.debris_ring(get_parent(), global_position + Vector2(0, -T * 0.4), theme.crate_dark)
	queue_free()

func _process(delta: float) -> void:
	if _shake > 0 or _flash > 0:
		_shake = max(0.0, _shake - delta)
		_flash = max(0.0, _flash - delta * 6.0)
		queue_redraw()

func _draw() -> void:
	var off := Vector2(randf_range(-2, 2), 0) if _shake > 0 else Vector2.ZERO
	var base: Color = theme.crate.lerp(Color.WHITE, _flash * 0.6)
	var dark: Color = theme.crate_dark.lerp(Color.WHITE, _flash * 0.4)
	var ink := Color("1a1028")
	var x0 := -T * 0.5 + 3
	var w := T - 6
	var lift := 22.0
	# cast shadow on the floor
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + w, -T + 4), Vector2(x0 + w + 14, -T + 16), Vector2(x0 + w + 14, 12), Vector2(x0 + 12, 12), Vector2(x0, 0), Vector2(x0 + w, 0)]), Color(0, 0, 0, 0.2))
	# front face with planks
	var front := Rect2(Vector2(x0, -lift) + off, Vector2(w, lift))
	draw_rect(front, dark)
	draw_rect(Rect2(front.position + Vector2(0, lift * 0.5), Vector2(w, lift * 0.5)), dark.darkened(0.12))
	for i in 3:
		var px := front.position.x + 8 + i * 14
		draw_line(Vector2(px, front.position.y + 2), Vector2(px, front.end.y - 2), dark.darkened(0.3), 2.0)
	# top face
	var top := Rect2(Vector2(x0, -T - lift + 8) + off, Vector2(w, T - 8))
	draw_rect(top, base)
	draw_rect(Rect2(top.position, Vector2(top.size.x, 5)), base.lightened(0.2))
	draw_rect(Rect2(top.position, Vector2(4, top.size.y)), base.lightened(0.1))
	draw_rect(top.grow(-7), base.darkened(0.06))
	# cross braces
	draw_line(top.position + Vector2(7, 7), top.end - Vector2(7, 7), dark, 5.0)
	draw_line(Vector2(top.position.x + 7, top.end.y - 7), Vector2(top.end.x - 7, top.position.y + 7), dark, 5.0)
	# metal corner caps
	for cpt in [top.position + Vector2(5, 5), Vector2(top.end.x - 5, top.position.y + 5), Vector2(top.position.x + 5, top.end.y - 5), top.end - Vector2(5, 5)]:
		draw_circle(cpt, 3.0, Color("c9d0de"))
	draw_rect(top, ink, false, 3.0)
	draw_rect(front, ink, false, 3.0)
	# damage cracks
	var dmg := 1.0 - hp / MAX_HP
	if dmg > 0.33:
		draw_polyline(PackedVector2Array([top.position + Vector2(8, 12), top.position + Vector2(16, 18), top.position + Vector2(13, 27)]), ink, 2.0)
	if dmg > 0.66:
		draw_polyline(PackedVector2Array([top.end - Vector2(8, 10), top.end - Vector2(17, 16), top.end - Vector2(12, 26)]), ink, 2.0)
