class_name Gem
extends Node2D
## A collectible crystal for Gem Rush. Pops out of the mine (or out of a KO'd
## brawler) in a little arc, then waits to be picked up.

var game: Node
var from := Vector2.ZERO
var to := Vector2.ZERO
var _fly := 0.0
var _fly_total := 0.5
var _t := 0.0
var collected := false

static func spawn(g: Node, start: Vector2, target: Vector2, fly_time := 0.5) -> Gem:
	var gem := Gem.new()
	gem.game = g
	gem.from = start
	gem.to = target
	gem._fly_total = fly_time
	gem.position = start
	g.entity_layer.add_child(gem)
	gem.add_to_group("gems")
	return gem

func _ready() -> void:
	_t = randf() * 5.0

func can_pickup() -> bool:
	return not collected and _fly >= _fly_total

func _physics_process(delta: float) -> void:
	_t += delta
	if _fly < _fly_total:
		_fly += delta
		var k := clampf(_fly / _fly_total, 0.0, 1.0)
		position = from.lerp(to, k)
	elif not collected and not game.ended:
		for b: Brawler in game.brawlers:
			if b.alive and b.global_position.distance_to(global_position) < 34.0 + b.radius * 0.5:
				collected = true
				game.mode.on_gem_collected(b, self)
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_fly / _fly_total, 0.0, 1.0)
	var h := sin(k * PI) * 60.0 if _fly < _fly_total else 0.0
	var bob := sin(_t * 3.0) * 3.0
	draw_circle(Vector2(0, 2), 10.0, Color(0, 0, 0, 0.28))
	var c := Color("c25bff")
	c.a = 0.25
	draw_circle(Vector2(0, -16 - h + bob), 18 + sin(_t * 5.0) * 2.0, c)
	draw_gem_icon(self, Vector2(0, -16 - h + bob), 12.0, _t)

static func draw_gem_icon(ci: CanvasItem, p: Vector2, s: float, t: float) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.8, -s * 0.25), p + Vector2(0, s), p + Vector2(-s * 0.8, -s * 0.25)])
	ci.draw_colored_polygon(pts, Color("b25bff"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.8, -s * 0.25), p + Vector2(0, -s * 0.1)]), Color("e8c8ff"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.8, -s * 0.25), p + Vector2(0, -s * 0.1), p + Vector2(0, s)]), Color("7a2ccc"))
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, Color("1a1028"), 2.5, true)
	var sp := 0.5 + 0.5 * sin(t * 4.0)
	ci.draw_circle(p + Vector2(-s * 0.25, -s * 0.45), 1.5 + sp, Color(1, 1, 1, 0.9))
