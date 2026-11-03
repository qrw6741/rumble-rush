class_name BeamFX
extends Node2D
## Nova's Lance Beam visual.

var a := Vector2.ZERO
var b := Vector2.ZERO
var color := Color.CYAN
var width := 40.0
var _t := 0.0
const LIFE := 0.45

static func spawn(parent: Node, from: Vector2, to: Vector2, c: Color, w: float) -> void:
	var f := BeamFX.new()
	f.a = from
	f.b = to
	f.color = c
	f.width = w
	parent.add_child(f)
	FX.burst(parent, to, c, 18, 300.0, 0.4, 6.0)
	FX.shockwave(parent, to, 50.0, c, 0.3)

func _ready() -> void:
	z_index = 14

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := _t / LIFE
	var w := width * (1.0 - k * k)
	var c := color
	c.a = 0.35 * (1.0 - k)
	draw_line(a, b, c, w * 1.8, true)
	c.a = 0.9 * (1.0 - k)
	draw_line(a, b, c, w, true)
	draw_line(a, b, Color(1, 1, 1, 1.0 - k), w * 0.4, true)
	draw_circle(a, w * 0.6, Color(1, 1, 1, 0.8 * (1.0 - k)))
