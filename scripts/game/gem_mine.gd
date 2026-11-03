class_name GemMine
extends Node2D
## The glowing crystal mine in the centre of Gem Rush maps. Pulses just before a
## new crystal pops out.

var mode: ModeGem
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var outline := Color("1a1028")
	var charge := 0.0
	if mode:
		charge = 1.0 - clampf(mode.spawn_t / ModeGem.SPAWN_INTERVAL, 0.0, 1.0)
	var glow := Color("b25bff")
	glow.a = 0.12 + 0.25 * charge * charge
	draw_circle(Vector2.ZERO, 44 + 6 * sin(_t * 3.0), glow)
	# rim stones
	for i in 10:
		var a := i * TAU / 10.0
		var p := Vector2(cos(a) * 30, sin(a) * 20)
		draw_circle(p, 9, outline)
		draw_circle(p, 7, Color("8a7a9a").lightened(0.1 if i % 2 == 0 else 0.0))
	# pit
	var pit := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		pit.append(Vector2(cos(a) * 26, sin(a) * 16))
	draw_colored_polygon(pit, Color("1b1030"))
	pit.append(pit[0])
	draw_polyline(pit, outline, 3.0, true)
	# crystals poking out
	var shards := [[Vector2(-12, -2), 14.0, -0.3], [Vector2(2, -6), 20.0, 0.05], [Vector2(14, 0), 12.0, 0.35]]
	for sh in shards:
		var base: Vector2 = sh[0]
		var h: float = sh[1] * (1.0 + 0.15 * charge)
		var rot: float = sh[2]
		var pts := PackedVector2Array([base + Vector2(-5, 4).rotated(rot), base + Vector2(0, -h).rotated(rot), base + Vector2(5, 4).rotated(rot)])
		draw_colored_polygon(pts, Color("b25bff"))
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], base + Vector2(0, 4).rotated(rot)]), Color("e8c8ff"))
		pts.append(pts[0])
		draw_polyline(pts, outline, 2.5, true)
	if charge > 0.8:
		var sp := Color(1, 1, 1, (charge - 0.8) * 4.0)
		draw_circle(Vector2(2, -26 - sin(_t * 12.0) * 3.0), 3, sp)
