class_name WallBlock
extends Node2D
## A single raised wall tile. Lives in the y-sorted entity layer so brawlers walk
## convincingly in front of / behind it.

const T := 48.0
const LIFT := 16.0

var cell := Vector2i.ZERO
var theme: Dictionary
var nb: Dictionary

func setup(c: Vector2i, th: Dictionary, neighbors: Dictionary) -> void:
	cell = c
	theme = th
	nb = neighbors
	position = Vector2((c.x + 0.5) * T, (c.y + 1) * T)

func _draw() -> void:
	var top: Color = theme.wall_top
	var side: Color = theme.wall_side
	var ln: Color = theme.wall_line
	var outline := Color("1a1028")
	var x0 := -T * 0.5
	# front face (only where nothing sits below)
	if not nb.down:
		draw_rect(Rect2(x0, -LIFT, T, LIFT), side)
		draw_line(Vector2(x0, -LIFT * 0.45), Vector2(x0 + T, -LIFT * 0.45), side.darkened(0.25), 2.0)
		draw_line(Vector2(x0, 0), Vector2(x0 + T, 0), outline, 3.0)
	# top face
	var top_rect := Rect2(x0, -T - LIFT, T, T)
	draw_rect(top_rect, top)
	# bevel highlights
	var hl := top.lightened(0.18)
	if not nb.up:
		draw_rect(Rect2(x0, -T - LIFT, T, 6), hl)
	# brick / panel detail
	var detail := top.darkened(0.12)
	var yy := -T - LIFT
	draw_line(Vector2(x0 + 4, yy + T * 0.5), Vector2(x0 + T - 4, yy + T * 0.5), detail, 2.0)
	var off := 0.0 if cell.y % 2 == 0 else T * 0.25
	draw_line(Vector2(x0 + T * 0.5 - off, yy + 6), Vector2(x0 + T * 0.5 - off, yy + T * 0.5), detail, 2.0)
	draw_line(Vector2(x0 + T * 0.25 + off, yy + T * 0.5), Vector2(x0 + T * 0.25 + off, yy + T - 4), detail, 2.0)
	# neon/accent edge strip
	var lc := ln
	lc.a = 0.9
	if not nb.up:
		draw_line(Vector2(x0 + 2, yy + 3), Vector2(x0 + T - 2, yy + 3), lc, 2.0)
	# outlines on exposed edges
	var w := 3.0
	if not nb.up:
		draw_line(Vector2(x0, yy), Vector2(x0 + T, yy), outline, w)
	if not nb.left:
		draw_line(Vector2(x0, yy), Vector2(x0, 0 if not nb.down else yy + T), outline, w)
	if not nb.right:
		draw_line(Vector2(x0 + T, yy), Vector2(x0 + T, 0 if not nb.down else yy + T), outline, w)
	if not nb.down:
		draw_line(Vector2(x0, -LIFT), Vector2(x0 + T, -LIFT), outline, 2.0)
