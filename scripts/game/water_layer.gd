class_name WaterLayer
extends Node2D
## Animated water / energy-pool tiles. Blocks walking but not shooting.

const T := 48.0

var map: ArenaMap
var _cells: Array[Vector2i] = []
var _t := 0.0

func setup(m: ArenaMap) -> void:
	map = m
	for r in map.h:
		for c in map.w:
			if m.grid[r][c] == "W":
				_cells.append(Vector2i(c, r))

var _acc := 0.0

func _process(delta: float) -> void:
	if _cells.is_empty():
		return
	_t += delta
	_acc += delta
	if _acc >= 0.066:
		_acc = 0.0
		queue_redraw()

func _is_water(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map.w and c.y < map.h and map.grid[c.y][c.x] == "W"

func _draw() -> void:
	var wcol: Color = map.theme.water
	var light: Color = map.theme.water_light
	var outline := Color("1a1028")
	for c in _cells:
		var r := Rect2(c.x * T, c.y * T, T, T)
		draw_rect(r, wcol)
		if not _is_water(c + Vector2i(0, -1)):
			# visible inner pool wall + rim
			draw_rect(Rect2(r.position, Vector2(T, 14)), wcol.darkened(0.45))
			draw_rect(Rect2(r.position + Vector2(0, 14), Vector2(T, 4)), wcol.darkened(0.2))
		if not _is_water(c + Vector2i(-1, 0)):
			draw_rect(Rect2(r.position, Vector2(6, T)), wcol.darkened(0.25))
		if not _is_water(c + Vector2i(0, 1)):
			draw_rect(Rect2(r.position + Vector2(0, T - 5), Vector2(T, 5)), light)
		for i in 2:
			var y := r.position.y + 14 + i * 18 + sin(_t * 2.0 + c.x + i) * 3.0
			var x := r.position.x + 8 + fmod(_t * 10.0 + c.y * 7 + i * 13, 20.0)
			var lc := light
			lc.a = 0.7
			draw_line(Vector2(x, y), Vector2(x + 12, y), lc, 2.0, true)
		if not _is_water(c + Vector2i(0, -1)):
			draw_line(r.position, r.position + Vector2(T, 0), outline, 3.0)
		if not _is_water(c + Vector2i(0, 1)):
			draw_line(r.position + Vector2(0, T), r.end, outline, 3.0)
		if not _is_water(c + Vector2i(-1, 0)):
			draw_line(r.position, r.position + Vector2(0, T), outline, 3.0)
		if not _is_water(c + Vector2i(1, 0)):
			draw_line(r.position + Vector2(T, 0), r.end, outline, 3.0)
