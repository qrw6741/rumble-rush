class_name PowerCell
extends Node2D
## Showdown pickup: +health and +damage for the brawler who grabs it.

const HP_BONUS := 450.0
const DMG_BONUS := 0.08

var game: Node
var from := Vector2.ZERO
var to := Vector2.ZERO
var _fly := 0.0
var _fly_total := 0.45
var _t := 0.0
var collected := false

static func spawn(g: Node, start: Vector2, target: Vector2) -> PowerCell:
	var p := PowerCell.new()
	p.game = g
	p.from = start
	p.to = target
	p.position = start
	g.entity_layer.add_child(p)
	p.add_to_group("power_cells")
	return p

func _physics_process(delta: float) -> void:
	_t += delta
	if _fly < _fly_total:
		_fly += delta
		position = from.lerp(to, clampf(_fly / _fly_total, 0.0, 1.0))
	elif not collected and not game.ended:
		for b: Brawler in game.brawlers:
			if b.alive and b.global_position.distance_to(global_position) < 34.0 + b.radius * 0.5:
				collected = true
				b.add_power_cell(HP_BONUS, DMG_BONUS)
				Sfx.play_at("gem_pickup", global_position, -2.0)
				FX.burst(game.fx_layer, global_position + Vector2(0, -20), Color("9dff8a"), 12, 200.0, 0.4, 5.0)
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_fly / _fly_total, 0.0, 1.0)
	var h := sin(k * PI) * 50.0 if _fly < _fly_total else 0.0
	var bob := sin(_t * 3.0) * 3.0
	draw_circle(Vector2(0, 2), 11.0, Color(0, 0, 0, 0.28))
	var glow := Color("9dff8a")
	glow.a = 0.25 + 0.1 * sin(_t * 5.0)
	draw_circle(Vector2(0, -18 - h + bob), 22.0, glow)
	UIKit.draw_icon(self, "power_cell", Vector2(0, -18 - h + bob), 40.0)
