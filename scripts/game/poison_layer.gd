class_name PoisonLayer
extends Node2D
## Rolling green poison clouds covering every tile outside the safe square.

const T := 48.0

var mode: ModeShowdown
var map: ArenaMap
var _t := 0.0

func _ready() -> void:
	z_index = 8
	_low = Save.low_graphics()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

var _low := false
var _acc := 0.0

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= (0.05 if _low else 0.033):
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	if mode.safe_half > 900.0:
		return
	var c := map.size_px * 0.5
	var sh := mode.safe_half * T
	var safe := Rect2(c - Vector2(sh, sh), Vector2(sh, sh) * 2.0)
	# soft tint over the whole poisoned area
	var tint := Color(0.25, 0.75, 0.2, 0.22)
	var outer := Rect2(-T * 4, -T * 4, map.size_px.x + T * 8, map.size_px.y + T * 8)
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, safe.position.y - outer.position.y)), tint)
	draw_rect(Rect2(Vector2(outer.position.x, safe.end.y), Vector2(outer.size.x, outer.end.y - safe.end.y)), tint)
	draw_rect(Rect2(Vector2(outer.position.x, safe.position.y), Vector2(safe.position.x - outer.position.x, safe.size.y)), tint)
	draw_rect(Rect2(Vector2(safe.end.x, safe.position.y), Vector2(outer.end.x - safe.end.x, safe.size.y)), tint)
	# puffy clouds on each poisoned tile — only the ones the camera can see
	var vis := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	vis = vis.grow(T)
	var c0 := maxi(-2, int(floor(vis.position.x / T)))
	var c1 := mini(map.w + 2, int(ceil(vis.end.x / T)))
	var r0 := maxi(-2, int(floor(vis.position.y / T)))
	var r1 := mini(map.h + 2, int(ceil(vis.end.y / T)))
	for r in range(r0, r1):
		for col in range(c0, c1):
			var p := Vector2((col + 0.5) * T, (r + 0.5) * T)
			if safe.has_point(p):
				continue
			var seed := float(col * 13 + r * 7)
			var drift := Vector2(sin(_t * 0.8 + seed) * 6.0, cos(_t * 0.6 + seed) * 4.0)
			var edge := minf(absf(p.x - c.x) - sh, absf(p.y - c.y) - sh)
			var a := clampf(0.35 + edge / (T * 6.0), 0.35, 0.65)
			if _low and (col + r) % 2 == 1:
				continue
			draw_circle(p + drift, 30.0 if not _low else 40.0, Color(0.35, 0.82, 0.3, a * 0.7))
			if not _low:
				draw_circle(p + drift + Vector2(-10, -8), 18.0, Color(0.55, 0.95, 0.45, a * 0.6))
	# glowing border line
	draw_rect(safe, Color(0.6, 1.0, 0.5, 0.55 + 0.2 * sin(_t * 4.0)), false, 4.0)
