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

var _low := false
var _last_key := ""
var _acc := 0.0

func _ready() -> void:
	_low = Save.low_graphics() or map.flat or (map.w * map.h > 900 and Save.setting("graphics") != "high")

func _process(delta: float) -> void:
	if not _low:
		# gentle sway at ~12 fps: looks the same, costs a fraction of per-frame redraws
		_t += delta
		_acc += delta
		if _acc >= 0.083:
			_acc = 0.0
			queue_redraw()
		return
	# static bushes: only redraw when the local player's hiding spot changes
	var key := ""
	if focus and is_instance_valid(focus) and focus.get("alive") and map.is_bush(focus.global_position):
		key = str(map.world_to_cell(focus.global_position))
	if key != _last_key or _t == 0.0:
		_last_key = key
		_t = 0.001
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

func _blob_raised(c: Vector2i, dy: float, col: Color) -> void:
	var p := map.cell_center(c) + Vector2(0, -6 + dy)
	var s := _sway(c)
	draw_circle(p + s, 23.0, col)
	if map.bush_cells.has(c + Vector2i(1, 0)):
		draw_rect(Rect2(p + s + Vector2(0, -18), Vector2(T, 36)), col)
	if map.bush_cells.has(c + Vector2i(0, 1)):
		draw_rect(Rect2(p + s + Vector2(-20, 0), Vector2(40, T)), col)
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
	# side band (the bush's lower "wall"), then the raised top
	for c in _cells:
		var side := dark.darkened(0.3)
		side.a = _alpha_for(map.cell_center(c))
		_blob(c, 0.0, side)
	for c in _cells:
		var col := dark
		col.a = _alpha_for(map.cell_center(c))
		_blob_raised(c, -8.0, col)
	if map.theme.get("grass", false):
		_draw_grass(light, dark)
		return
	# leafy clusters on top
	for c in _cells:
		var p := map.cell_center(c) + Vector2(0, -14)
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


## Tall dry grass: tufts of swaying blades instead of round leaves.
func _draw_grass(light: Color, dark: Color) -> void:
	var ink := Color("1a1028")
	for c in _cells:
		var base := map.cell_center(c) + Vector2(0, 8)
		var a := _alpha_for(base)
		var rng := RandomNumberGenerator.new()
		rng.seed = c.x * 913 + c.y * 271
		for k in 7:
			var bx := base.x + rng.randf_range(-22, 22)
			var by := base.y + rng.randf_range(-20, 14)
			var hgt := rng.randf_range(30, 44)
			var sway := sin(_t * 1.8 + c.x * 0.6 + c.y * 0.3 + k) * 4.0
			var tip := Vector2(bx + sway, by - hgt)
			var blade := PackedVector2Array([Vector2(bx - 6, by), tip, Vector2(bx + 6, by)])
			var oc := ink
			oc.a = a
			draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2]]), oc, 4.0, true)
			var col := light.lerp(dark, rng.randf_range(0.0, 0.45))
			col.a = a
			draw_colored_polygon(blade, col)
			var hl := light.lightened(0.35)
			hl.a = a * 0.8
			draw_line(Vector2(bx - 1, by - 4), tip.lerp(Vector2(bx, by), 0.25), hl, 1.5, true)
