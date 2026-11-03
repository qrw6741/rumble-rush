class_name BushLayer
extends Node2D
## Draws all bushes as merged leafy hedges above the brawlers. Bushes near the
## local player turn see-through while they are hiding, so you can still see yourself.

const T := 48.0

var map: ArenaMap
var focus: Node2D = null # local player
var _t := 0.0
var _cells: Array[Vector2i] = []
var _leaves: Dictionary = {}

func setup(m: ArenaMap) -> void:
	map = m
	for c in m.bush_cells.keys():
		_cells.append(c)
		var rng := RandomNumberGenerator.new()
		rng.seed = c.x * 977 + c.y * 131
		var leaves: Array = []
		for i in 6:
			leaves.append([Vector2(rng.randf_range(-15, 15), rng.randf_range(-17, 11)), rng.randf_range(8.0, 12.0), rng.randf() * TAU])
		_leaves[c] = leaves

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _alpha_for(center: Vector2) -> float:
	if focus and is_instance_valid(focus) and focus.get("alive") and map.is_bush(focus.global_position):
		var d := center.distance_to(focus.global_position)
		if d < T * 2.2:
			return lerpf(0.35, 1.0, clampf((d - T * 1.2) / T, 0.0, 1.0))
	return 1.0

func _sway(c: Vector2i, amp := 1.5) -> Vector2:
	return Vector2(sin(_t * 1.6 + c.x * 0.7 + c.y * 0.4) * amp, 0)

func _blob(c: Vector2i, grow: float, col: Color) -> void:
	var p := map.cell_center(c) + Vector2(0, -6)
	var s := _sway(c)
	draw_circle(p + s, 25.0 + grow, col)
	# bridge to right / down neighbours so hedges read as one mass
	if map.bush_cells.has(c + Vector2i(1, 0)):
		draw_rect(Rect2(p + s + Vector2(0, -20 - grow), Vector2(T, 40 + grow * 2)), col)
	if map.bush_cells.has(c + Vector2i(0, 1)):
		draw_rect(Rect2(p + s + Vector2(-22 - grow, 0), Vector2(44 + grow * 2, T)), col)
	if map.bush_cells.has(c + Vector2i(1, 1)) and map.bush_cells.has(c + Vector2i(1, 0)) and map.bush_cells.has(c + Vector2i(0, 1)):
		draw_rect(Rect2(p + s, Vector2(T, T)), col)

func _draw() -> void:
	var dark: Color = map.theme.bush_dark
	var light: Color = map.theme.bush
	var outline := Color("1a1028")
	for c in _cells:
		var o := outline
		o.a = _alpha_for(map.cell_center(c))
		_blob(c, 4.0, o)
	for c in _cells:
		var col := dark
		col.a = _alpha_for(map.cell_center(c))
		_blob(c, 0.0, col)
	# leafy clusters on top
	for c in _cells:
		var p := map.cell_center(c) + Vector2(0, -6)
		var a := _alpha_for(p)
		var s := _sway(c, 2.2)
		for lf in _leaves[c]:
			var lp: Vector2 = p + s + lf[0]
			var r: float = lf[1]
			var col := light
			col.a = a
			draw_circle(lp, r, col)
			var hl := light.lightened(0.28)
			hl.a = a
			draw_circle(lp + Vector2(-r * 0.3, -r * 0.35), r * 0.42, hl)
		var shade := dark.darkened(0.25)
		shade.a = a * 0.8
		draw_circle(p + s + Vector2(6, 12), 5, shade)
