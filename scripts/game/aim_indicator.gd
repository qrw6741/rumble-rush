class_name AimIndicator
extends Node2D
## Ground-projected aim preview showing exactly what the attack/super will cover.

const T := 48.0

var pc: PlayerController
var _t := 0.0

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if pc == null or pc.preview_mode == "" or not pc.b.alive or not pc.game.is_playing():
		return
	var b := pc.b
	var is_super := pc.preview_mode == "super"
	var cfg: Dictionary = b.d.super if is_super else b.d.attack
	var kind: String = cfg.kind
	var dir := pc.preview_dir
	var origin := b.global_position
	var base := Color("ffd23a") if is_super else Color.WHITE
	var fill := base
	fill.a = (0.22 if is_super else 0.14) * (0.5 + 0.5 * pc.preview_strength)
	var edge := base
	edge.a = (0.75 if is_super else 0.45) * (0.5 + 0.5 * pc.preview_strength)
	var rng: float = cfg.range * T
	match kind:
		"melee_cone":
			var half := deg_to_rad(cfg.arc) * 0.5
			_sector(origin, dir, rng, half, fill, edge)
		"twin_slash":
			var sp := deg_to_rad(cfg.spread)
			_lane(origin, dir.rotated(-sp * 0.5), rng, 22.0, fill, edge)
			_lane(origin, dir.rotated(sp * 0.5), rng, 22.0, fill, edge)
		"rifle", "orb":
			_lane(origin, dir, rng, 26.0, fill, edge)
		"lance_beam":
			_lane(origin, dir, rng, cfg.width * T, fill, edge)
		"phantom_dash":
			_lane(origin, dir, rng, 50.0, fill, edge)
		"lob", "leap_slam", "sanctuary", "bramble":
			var dist := rng if pc.preview_dist < 0.0 else clampf(pc.preview_dist, T * 1.2, rng)
			var target := origin + dir * dist
			var r: float = cfg.radius * T
			# dotted arc path
			var steps := 14
			for i in steps:
				var k := float(i) / steps
				var p := origin.lerp(target, k) + Vector2(0, -sin(k * PI) * dist * 0.25)
				draw_circle(p, 3.0, edge)
			draw_circle(target, r, fill)
			draw_arc(target, r, 0, TAU, 40, edge, 3.0, true)
			draw_arc(origin, rng, 0, TAU, 64, Color(edge.r, edge.g, edge.b, edge.a * 0.35), 2.0, true)

func _lane(origin: Vector2, dir: Vector2, length: float, width: float, fill: Color, edge: Color) -> void:
	var n := dir.orthogonal() * width * 0.5
	var start := origin + dir * 18.0
	var end := origin + dir * length
	var pts := PackedVector2Array([start + n, end + n, end - n, start - n])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, 2.0, true)
	# moving chevrons
	var step := 46.0
	var off := fmod(_t * 120.0, step)
	var dd := 30.0 + off
	while dd < length - 10.0:
		var c := origin + dir * dd
		var w := n * 0.6
		draw_polyline(PackedVector2Array([c + w - dir * 7.0, c, c - w - dir * 7.0]), edge, 2.0, true)
		dd += step

func _sector(origin: Vector2, dir: Vector2, r: float, half: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array([origin])
	var a0 := dir.angle() - half
	for i in 21:
		var a := a0 + half * 2.0 * i / 20.0
		pts.append(origin + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, fill)
	pts.append(origin)
	draw_polyline(pts, edge, 2.0, true)
