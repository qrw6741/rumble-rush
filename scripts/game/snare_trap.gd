class_name SnareTrap
extends Node2D
## Sprig's Vine Snare: invisible to enemies, roots the first one that steps on it.

var owner_b: Brawler
var cfg: Dictionary
var _t := 0.0
var _armed_after := 0.4

static func spawn(g: Node, b: Brawler, pos: Vector2, gd: Dictionary) -> void:
	var s := SnareTrap.new()
	s.owner_b = b
	s.cfg = gd
	s.position = pos
	g.zone_layer.add_child(s)

func _physics_process(delta: float) -> void:
	var g := owner_b.game
	_t += delta
	if g.ended or _t >= cfg.life:
		queue_free()
		return
	if _t >= _armed_after:
		for e: Brawler in g.brawlers:
			if e.alive and e.team != owner_b.team and e.global_position.distance_to(global_position) < 30.0 + e.radius * 0.5 and not e.is_invulnerable():
				e.root_t = cfg.root
				g.deal_damage(owner_b, e, 300.0 * owner_b.dmg_mult, 0.1)
				Sfx.play_at("root", global_position, 0.0)
				FX.burst(g.fx_layer, global_position, Color("5fd35a"), 18, 240.0, 0.5, 5.0)
				FX.shockwave(g.fx_layer, global_position, 50.0, Color("5fd35a"), 0.3)
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	var g := owner_b.game
	if owner_b.team != g.view_team:
		return # enemies can't see it
	var a := 0.55 + 0.2 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 22, Color(0.18, 0.48, 0.21, 0.35 * a))
	for i in 6:
		var ang := i * TAU / 6.0 + _t * 0.5
		var p := Vector2(cos(ang), sin(ang) * 0.6) * 16
		draw_line(Vector2.ZERO, p, Color(0.37, 0.83, 0.35, a), 3.0, true)
		draw_circle(p, 3, Color(1, 0.72, 0.3, a))
