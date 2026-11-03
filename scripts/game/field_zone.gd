class_name FieldZone
extends Node2D
## Persistent area effect on the ground: Mira's Sanctuary (heal allies / burn
## enemies) or Sprig's Bramble Patch (slow + shred enemies).

var owner_b: Brawler
var kind := "sanctuary"
var cfg: Dictionary
var radius := 100.0
var life := 4.0
var _t := 0.0
var _tick_t := 0.0

static func spawn(g: Node, b: Brawler, pos: Vector2, k: String, s: Dictionary) -> void:
	if g.ended:
		return
	var z := FieldZone.new()
	z.owner_b = b
	z.kind = k
	z.cfg = s
	z.radius = s.radius * Config.TILE
	z.life = s.duration
	z.position = pos
	g.zone_layer.add_child(z)
	Sfx.play_at("heal_field" if k == "sanctuary" else "root", pos, -2.0)
	FX.shockwave(g.fx_layer, pos, z.radius, b.d.accent if k == "sanctuary" else Color("5fd35a"), 0.4, 8.0)

func _physics_process(delta: float) -> void:
	var g := owner_b.game
	if g.ended:
		queue_free()
		return
	_t += delta
	if _t >= life:
		queue_free()
		return
	_tick_t -= delta
	for e: Brawler in g.brawlers:
		if not e.alive or e.global_position.distance_to(global_position) > radius + e.radius * 0.5:
			continue
		if kind == "bramble" and e.team != owner_b.team:
			e.slow_t = 0.25
			e.slow_amt = cfg.slow
	if _tick_t <= 0.0:
		_tick_t = cfg.tick
		for e: Brawler in g.brawlers:
			if not e.alive or e.global_position.distance_to(global_position) > radius + e.radius * 0.5:
				continue
			if e.team == owner_b.team:
				if kind == "sanctuary":
					g.heal(owner_b, e, cfg.heal * owner_b.dmg_mult, 0.0)
			else:
				g.deal_damage(owner_b, e, cfg.damage * owner_b.dmg_mult, 0.0)
	queue_redraw()

func _draw() -> void:
	var fade := clampf((life - _t) / 0.4, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
	if kind == "sanctuary":
		var c: Color = owner_b.d.accent
		var fill := c
		fill.a = 0.18 * fade
		draw_circle(Vector2.ZERO, radius, fill)
		var edge := c
		edge.a = (0.6 + 0.3 * sin(_t * 6.0)) * fade
		draw_arc(Vector2.ZERO, radius, 0, TAU, 56, edge, 4.0, true)
		draw_arc(Vector2.ZERO, radius * (0.55 + 0.1 * sin(_t * 3.0)), 0, TAU, 40, Color(1, 1, 1, 0.25 * fade), 2.0, true)
		for i in 10:
			var a := i * TAU / 10.0 + _t * 0.6
			var rr := radius * (0.25 + fmod(i * 0.37 + _t * 0.3, 0.7))
			var p := Vector2(cos(a), sin(a)) * rr + Vector2(0, -fmod(_t * 40.0 + i * 13, 40.0))
			draw_circle(p, 3.0, Color(1, 1, 1, 0.6 * fade))
	else:
		var c := Color("2f7a35")
		c.a = 0.35 * fade
		draw_circle(Vector2.ZERO, radius, c)
		var edge := Color("5fd35a")
		edge.a = 0.8 * fade
		draw_arc(Vector2.ZERO, radius, 0, TAU, 56, edge, 3.0, true)
		for i in 18:
			var a := i * TAU / 18.0
			var rr := radius * (0.3 + 0.65 * fmod(i * 0.618, 1.0))
			var p := Vector2(cos(a), sin(a)) * rr
			var grow := clampf(_t * 4.0 - fmod(i * 0.3, 1.0), 0.0, 1.0)
			var spike := PackedVector2Array([p + Vector2(-6, 2), p + Vector2(0, -4.0 - 12.0 * grow - 2.0 * sin(_t * 5 + i)), p + Vector2(6, 2)])
			var sc := Color("1d4a22")
			sc.a = fade
			draw_colored_polygon(spike, sc)
			draw_circle(p + Vector2(0, -14 * grow), 2.0, Color(1, 0.72, 0.3, fade))
