class_name Abilities
extends RefCounted
## All attack, super and gadget behaviour. Each brawler's config decides which
## routine runs; numbers come from Config so balance can be tuned in one place.

const T := 48.0

# ------------------------------------------------------------------ primary
static func primary(b: Brawler, dir: Vector2, dist: float) -> void:
	var a: Dictionary = b.d.attack
	var dmg: float = a.damage * b.dmg_mult
	Sfx.play_at(a.sfx, b.global_position, -3.0)
	match a.kind:
		"melee_cone":
			_melee(b, dir, a, dmg)
		"twin_slash":
			var sp := deg_to_rad(a.spread)
			_shoot(b, dir.rotated(-sp * 0.5), a, dmg, "paint" if b.d.get("paint", false) else "slash")
			var tree := b.get_tree()
			tree.create_timer(0.09, false).timeout.connect(func():
				if is_instance_valid(b) and b.alive and not b.game.ended:
					_shoot(b, dir.rotated(sp * 0.5), a, dmg, "paint" if b.d.get("paint", false) else "slash")
					Sfx.play_at(a.sfx, b.global_position, -6.0))
		"rifle":
			_shoot(b, dir, a, dmg, "bolt", {"bonus": a.max_bonus})
			b.apply_knockback(-dir * 60.0)
		"orb":
			_shoot(b, dir, a, dmg, "orb", {"heal": a.heal * b.dmg_mult})
		"lob":
			var target := _lob_target(b, dir, dist, a.range * T)
			var radius: float = a.radius * T
			var gain: float = a.super_per_hit
			LobShot.spawn(b.game, b, target, a.flight, "seed", radius, func(pos: Vector2):
				_explode(b, pos, radius, dmg, gain, b.d.accent))

static func _lob_target(b: Brawler, dir: Vector2, dist: float, max_range: float) -> Vector2:
	var dd := max_range if dist < 0.0 else clampf(dist, T * 1.2, max_range)
	var target := b.global_position + dir * dd
	var size: Vector2 = b.game.map.size_px
	return Vector2(clampf(target.x, 20, size.x - 20), clampf(target.y, 20, size.y - 20))

static func _shoot(b: Brawler, dir: Vector2, a: Dictionary, dmg: float, style: String, extra := {}) -> void:
	var p := Projectile.new()
	p.owner_b = b
	p.team = b.team
	p.dir = dir.normalized()
	p.speed = a.speed
	p.max_dist = a.range * T
	p.damage = dmg
	p.style = style
	p.super_gain = a.super_per_hit
	p.heal = extra.get("heal", 0.0)
	p.bonus = extra.get("bonus", 0.0)
	p.position = b.global_position
	b.game.projectile_layer.add_child(p)
	FX.burst(b.game.fx_layer, b.body_center() + dir * 30.0, b.d.accent if style != "bolt" else b.d.primary, 5, 160.0, 0.18, 3.0, 25.0, dir)

static func _melee(b: Brawler, dir: Vector2, a: Dictionary, dmg: float) -> void:
	var g := b.game
	var reach: float = a.range * T + 8.0
	var half := deg_to_rad(a.arc) * 0.5
	var hit_any := false
	for e: Brawler in g.brawlers:
		if not e.alive or e.team == b.team:
			continue
		var to := e.global_position - b.global_position
		var dl := to.length()
		if dl > reach + e.radius:
			continue
		var slack := atan2(e.radius, max(dl, 1.0))
		if dl > 12.0 and absf(dir.angle_to(to)) > half + slack:
			continue
		if not g.has_los(b.global_position, e.global_position):
			continue
		if g.deal_damage(b, e, dmg, a.super_per_hit) > 0.0:
			hit_any = true
			e.apply_knockback(to.normalized() * 280.0)
	for c: Crate in g.get_tree().get_nodes_in_group("crates"):
		var cto := (c.global_position - Vector2(0, 24)) - b.global_position
		if cto.length() <= reach + 20.0 and absf(dir.angle_to(cto)) <= half + 0.3:
			c.take_damage(dmg)
	SwingFX.spawn(g.fx_layer, b, dir, reach, half, b.d.accent)
	if hit_any:
		g.shake(4.0)

static func _explode(b: Brawler, pos: Vector2, radius: float, dmg: float, gain: float, col: Color) -> void:
	var g := b.game
	if g.ended:
		return
	for e: Brawler in g.brawlers:
		if e.alive and e.team != b.team and e.global_position.distance_to(pos) <= radius + e.radius:
			g.deal_damage(b, e, dmg, gain)
	_damage_crates(g, pos, radius, dmg)
	Sfx.play_at("explosion", pos, -6.0)
	FX.shockwave(g.fx_layer, pos, radius, col, 0.3)
	FX.burst(g.fx_layer, pos, col, 16, 260.0, 0.45, 6.0)
	FX.burst(g.fx_layer, pos, Color("5fd35a"), 8, 200.0, 0.5, 4.0)

static func _damage_crates(g: Node, pos: Vector2, radius: float, dmg: float) -> void:
	for c: Crate in g.get_tree().get_nodes_in_group("crates"):
		if (c.global_position - Vector2(0, 24)).distance_to(pos) <= radius + 22.0:
			c.take_damage(dmg)

# ------------------------------------------------------------------ supers
static func cast_super(b: Brawler, dir: Vector2, dist: float) -> void:
	var s: Dictionary = b.d.super
	var g := b.game
	g.on_super_used(b)
	match s.kind:
		"leap_slam":
			var target := _lob_target(b, dir, dist, s.range * T)
			b.start_leap(target, s.air_time)
			Sfx.play_at("super_cast", b.global_position, -4.0)
			FX.burst(g.fx_layer, b.global_position, Color("d9c3a0"), 14, 220.0, 0.5, 6.0)
		"phantom_dash":
			b.start_dash(dir, s.range * T, s.duration)
			Sfx.play_at("dash", b.global_position, 0.0)
		"lance_beam":
			b.beam_charge_t = s.charge
			b.beam_dir = dir
			b.busy_t = s.charge + 0.15
			Sfx.play_at("beam", b.global_position, -2.0)
		"sanctuary":
			var target := _lob_target(b, dir, dist, s.range * T)
			Sfx.play_at("super_cast", b.global_position, -6.0)
			LobShot.spawn(g, b, target, 0.5, "lantern", s.radius * T, func(pos: Vector2):
				FieldZone.spawn(g, b, pos, "sanctuary", s))
		"bramble":
			var target := _lob_target(b, dir, dist, s.range * T)
			Sfx.play_at("super_cast", b.global_position, -6.0)
			LobShot.spawn(g, b, target, s.flight, "seed", s.radius * T, func(pos: Vector2):
				FieldZone.spawn(g, b, pos, "bramble", s))

static func leap_land(b: Brawler) -> void:
	var s: Dictionary = b.d.super
	var g := b.game
	var r: float = s.radius * T
	var dmg: float = s.damage * b.dmg_mult
	for e: Brawler in g.brawlers:
		if e.alive and e.team != b.team:
			var to := e.global_position - b.global_position
			if to.length() <= r + e.radius:
				if g.deal_damage(b, e, dmg, 0.0) > 0.0:
					e.stun_t = max(e.stun_t, s.stun)
					e.apply_knockback(to.normalized() * 520.0)
	_damage_crates(g, b.global_position, r, dmg * 2.0)
	Sfx.play_at("slam", b.global_position, 2.0)
	FX.shockwave(g.fx_layer, b.global_position, r, Color("ffd166"), 0.45, 10.0)
	FX.shockwave(g.fx_layer, b.global_position, r * 0.6, Color.WHITE, 0.3, 6.0)
	FX.burst(g.fx_layer, b.global_position, Color("d9c3a0"), 30, 420.0, 0.7, 8.0)
	FX.burst(g.fx_layer, b.global_position, Color("e9893a"), 12, 300.0, 0.5, 5.0)
	g.shake(16.0, b.global_position)

static func dash_hits(b: Brawler, from: Vector2, to: Vector2) -> void:
	var s: Dictionary = b.d.super
	var g := b.game
	for e: Brawler in g.brawlers:
		if not e.alive or e.team == b.team or b.dash_hit.has(e):
			continue
		var p := Geometry2D.get_closest_point_to_segment(e.global_position, from, to)
		if p.distance_to(e.global_position) <= e.radius + 30.0:
			b.dash_hit[e] = true
			g.deal_damage(b, e, s.damage * b.dmg_mult, 0.0)
			FX.burst(g.fx_layer, e.body_center(), b.d.accent, 14, 300.0, 0.4, 5.0)
			FX.shockwave(g.fx_layer, e.body_center(), 40.0, b.d.accent, 0.25)
			g.shake(6.0, e.global_position)

static func fire_beam(b: Brawler, dir: Vector2) -> void:
	if not b.alive or b.game.ended:
		return
	var s: Dictionary = b.d.super
	var g := b.game
	var start := b.global_position
	var end: Vector2 = start + dir * float(s.range) * T
	var hit: Dictionary = g.ray(start, end)
	var dmg: float = s.damage * b.dmg_mult
	if not hit.is_empty():
		end = hit.position
		if hit.collider is Crate:
			hit.collider.take_damage(dmg)
	var half_w: float = s.width * T * 0.5
	for e: Brawler in g.brawlers:
		if not e.alive or e.team == b.team:
			continue
		var p := Geometry2D.get_closest_point_to_segment(e.global_position, start, end)
		if p.distance_to(e.global_position) <= half_w + e.radius:
			g.deal_damage(b, e, dmg, 0.0)
			e.apply_knockback(dir * 300.0)
			FX.burst(g.fx_layer, e.body_center(), b.d.primary, 14, 320.0, 0.4, 5.0)
	BeamFX.spawn(g.fx_layer, start + Brawler.BODY_OFFSET, end + Brawler.BODY_OFFSET, b.d.primary, half_w * 2.0)
	b.apply_knockback(-dir * 260.0)
	b.recoil = 1.0
	g.shake(9.0, b.global_position)

# ------------------------------------------------------------------ gadgets
static func gadget(b: Brawler, dir: Vector2) -> void:
	var gd: Dictionary = b.d.gadget
	var g := b.game
	Sfx.play_at("gadget", b.global_position, -3.0)
	match gd.kind:
		"iron_skin":
			b.shield_t = gd.duration
			Sfx.play_at("shield", b.global_position, -2.0)
			FX.shockwave(g.fx_layer, b.body_center(), 50.0, Color("c9d0de"), 0.3)
		"shadow_step":
			b.invis_t = gd.duration
			FX.burst(g.fx_layer, b.body_center(), Color("2b1a4d"), 22, 260.0, 0.5, 7.0)
			FX.burst(g.fx_layer, b.body_center(), b.d.accent, 10, 200.0, 0.4, 4.0)
		"overclock":
			b.ammo = b.max_ammo
			FX.burst(g.fx_layer, b.body_center(), b.d.primary, 18, 240.0, 0.45, 5.0)
			FX.shockwave(g.fx_layer, b.body_center(), 46.0, b.d.primary, 0.3)
		"mend":
			var r: float = gd.radius * T
			for ally: Brawler in g.brawlers:
				if ally.alive and ally.team == b.team and ally.global_position.distance_to(b.global_position) <= r:
					g.heal(b, ally, gd.heal * b.dmg_mult, 0.0)
			Sfx.play_at("heal_hit", b.global_position, -2.0)
			FX.shockwave(g.fx_layer, b.global_position, r, b.d.accent, 0.5, 8.0)
			FX.burst(g.fx_layer, b.body_center(), b.d.accent, 18, 200.0, 0.6, 5.0)
		"snare":
			SnareTrap.spawn(g, b, b.global_position, gd)
			Sfx.play_at("root", b.global_position, -8.0)
