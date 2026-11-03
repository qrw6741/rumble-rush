class_name Projectile
extends Node2D
## Straight-flying shot. Movement is swept every physics frame (ray vs walls and
## segment-vs-circle vs brawlers) so fast bolts never tunnel through anything.

var owner_b: Brawler
var team := 0
var dir := Vector2.RIGHT
var speed := 900.0
var max_dist := 400.0
var damage := 500.0
var heal := 0.0
var bonus := 0.0
var super_gain := 0.0
var style := "bolt"
var hit_radius := 14.0
var traveled := 0.0
var _t := 0.0
var _dead := false

func _ready() -> void:
	z_index = 6

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var g := owner_b.game
	if g.ended:
		_finish(false)
		return
	_t += delta
	var step: float = min(speed * delta, max_dist - traveled)
	var from := global_position
	var to := from + dir * step
	# walls / crates
	var hit: Dictionary = g.ray(from, to)
	var wall_point := to
	if not hit.is_empty():
		wall_point = hit.position
	# brawlers along the (possibly shortened) segment
	var best: Brawler = null
	var best_d := INF
	for e: Brawler in g.brawlers:
		if not e.alive or e == owner_b:
			continue
		if e.team == team and heal <= 0.0:
			continue
		var cp := Geometry2D.get_closest_point_to_segment(e.global_position, from, wall_point)
		if cp.distance_to(e.global_position) <= e.radius + hit_radius:
			var dd := from.distance_to(cp)
			if dd < best_d:
				best_d = dd
				best = e
	if best:
		global_position = from + dir * best_d
		if best.team == team:
			g.heal(owner_b, best, heal, super_gain)
			Sfx.play_at("heal_hit", global_position, -6.0)
			FX.burst(g.fx_layer, best.body_center(), Color("6dff8a"), 12, 200.0, 0.45, 4.0)
		else:
			var dmg := damage
			if bonus > 0.0:
				dmg *= 1.0 + bonus * clampf((traveled + best_d) / max_dist, 0.0, 1.0)
			g.deal_damage(owner_b, best, dmg, super_gain)
			if heal > 0.0:
				# Mira's orb also splashes a little healing onto allies near the impact
				for ally: Brawler in g.brawlers:
					if ally.alive and ally.team == team and ally.global_position.distance_to(global_position) < 70.0:
						g.heal(owner_b, ally, heal * 0.35, 0.0)
		_finish(true)
		return
	if not hit.is_empty():
		global_position = wall_point
		if hit.collider is Crate:
			hit.collider.take_damage(damage)
		_finish(true)
		return
	global_position = to
	traveled += step
	if traveled >= max_dist - 0.5:
		_finish(false)
		return
	queue_redraw()

func _finish(impact: bool) -> void:
	_dead = true
	var g := owner_b.game
	var col: Color = owner_b.d.accent if style != "bolt" else owner_b.d.primary
	if impact:
		FX.burst(g.fx_layer, global_position + Brawler.BODY_OFFSET, col, 10, 220.0, 0.3, 4.0)
		FX.shockwave(g.fx_layer, global_position + Brawler.BODY_OFFSET, 22.0, col, 0.18, 3.0)
	else:
		FX.burst(g.fx_layer, global_position + Brawler.BODY_OFFSET, col, 5, 90.0, 0.25, 3.0)
	queue_free()

func _draw() -> void:
	var tc: Color = Config.tc(team)
	BrawlerArt.draw_projectile(self, style, Brawler.BODY_OFFSET, dir, _t, tc, owner_b.d)
