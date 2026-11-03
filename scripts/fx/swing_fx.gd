class_name SwingFX
extends Node2D
## Hammer swing wedge flash.

var dir := Vector2.RIGHT
var reach := 100.0
var half := 0.6
var color := Color.WHITE
var _t := 0.0
const LIFE := 0.22

static func spawn(parent: Node, b: Brawler, d: Vector2, r: float, h: float, c: Color) -> void:
	var s := SwingFX.new()
	s.position = b.global_position + Vector2(0, -16)
	s.dir = d
	s.reach = r
	s.half = h
	s.color = c
	parent.add_child(s)

func _ready() -> void:
	z_index = 12

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := _t / LIFE
	var a0 := dir.angle() - half
	var a1 := dir.angle() + half
	var sweep := lerpf(a0, a1, minf(1.0, k * 2.2))
	if sweep - a0 < 0.08:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	var n := 16
	for i in n + 1:
		var a := lerpf(a0, sweep, float(i) / n)
		pts.append(Vector2(cos(a), sin(a)) * reach)
	if pts.size() >= 3:
		var c := color
		c.a = 0.35 * (1.0 - k)
		draw_colored_polygon(pts, c)
		var e := Color(1, 1, 1, 0.8 * (1.0 - k))
		var arc := pts.slice(1)
		draw_polyline(arc, e, 5.0, true)
