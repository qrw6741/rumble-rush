class_name WallBlock
extends Node2D
## A raised, lit wall block. Lives in the y-sorted entity layer so brawlers walk
## convincingly in front of / behind it. Drawn as a chunky 3D block: bevelled top
## face, shaded front face, highlights on exposed edges and an inked outline.

const T := 48.0
const LIFT := 30.0

var cell := Vector2i.ZERO
var theme: Dictionary
var nb: Dictionary
var _seed := 0

func setup(c: Vector2i, th: Dictionary, neighbors: Dictionary) -> void:
	cell = c
	theme = th
	nb = neighbors
	_seed = c.x * 7349 + c.y * 3011
	position = Vector2((c.x + 0.5) * T, (c.y + 1) * T)

func _draw() -> void:
	var top: Color = theme.wall_top
	var side: Color = theme.wall_side
	var ln: Color = theme.wall_line
	var ink := Color("1a1028")
	var x0 := -T * 0.5
	var yt := -T - LIFT          # top face y
	# ---- front face (only where nothing sits below), vertical gradient
	if not nb.down:
		var bands := 6
		for i in bands:
			var k := float(i) / bands
			draw_rect(Rect2(x0, -LIFT + LIFT * k, T, LIFT / bands + 0.5), side.lerp(side.darkened(0.35), k))
		# masonry seams on the front
		var seam := side.darkened(0.3)
		draw_line(Vector2(x0, -LIFT * 0.5), Vector2(x0 + T, -LIFT * 0.5), seam, 2.0)
		var off := 12.0 if cell.x % 2 == 0 else 26.0
		draw_line(Vector2(x0 + off, -LIFT), Vector2(x0 + off, -LIFT * 0.5), seam, 2.0)
		draw_line(Vector2(x0 + off + 18, -LIFT * 0.5), Vector2(x0 + off + 18, 0), seam, 2.0)
		# contact shadow / AO at the base
		draw_rect(Rect2(x0, -5, T, 5), Color(0, 0, 0, 0.25))
	# ---- top face
	draw_rect(Rect2(x0, yt, T, T), top)
	# soft light gradient (lit from the top-left)
	draw_rect(Rect2(x0, yt, T, T * 0.5), Color(1, 1, 1, 0.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# surface detail: stones / panels
	var det := top.darkened(0.12)
	for i in 3:
		var p := Vector2(x0 + rng.randf_range(8, T - 8), yt + rng.randf_range(8, T - 8))
		var r := rng.randf_range(3.0, 6.0)
		draw_circle(p, r, det)
		draw_circle(p + Vector2(-1, -1), r * 0.5, top.lightened(0.08))
	# bevels on exposed edges
	var hi := top.lightened(0.25)
	var lo := top.darkened(0.2)
	if not nb.up:
		draw_rect(Rect2(x0, yt, T, 6), hi)
	if not nb.left:
		draw_rect(Rect2(x0, yt, 5, T), hi.lerp(top, 0.4))
	if not nb.right:
		draw_rect(Rect2(x0 + T - 5, yt, 5, T), lo)
	if not nb.down:
		draw_rect(Rect2(x0, yt + T - 6, T, 6), lo)
	# accent trim (neon strip in the city, sun-glint in the desert)
	if not nb.up:
		var lc := ln
		lc.a = 0.95
		draw_line(Vector2(x0 + 3, yt + 3), Vector2(x0 + T - 3, yt + 3), lc, 2.5)
	# ---- ink outline on exposed edges
	var w := 3.0
	if not nb.up:
		draw_line(Vector2(x0, yt), Vector2(x0 + T, yt), ink, w)
	if not nb.left:
		draw_line(Vector2(x0, yt), Vector2(x0, 0.0 if not nb.down else yt + T), ink, w)
	if not nb.right:
		draw_line(Vector2(x0 + T, yt), Vector2(x0 + T, 0.0 if not nb.down else yt + T), ink, w)
	if not nb.down:
		draw_line(Vector2(x0, -LIFT), Vector2(x0 + T, -LIFT), ink, 2.5)
		draw_line(Vector2(x0, 0), Vector2(x0 + T, 0), ink, w)
