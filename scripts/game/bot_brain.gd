class_name BotBrain
extends Node
## AI controller. Bots only "see" what a human on their team could see (no
## peeking into bushes), react with a human-like delay, aim with error, dodge,
## retreat to heal, play the objective and use gadgets/supers sensibly.

const T := 48.0

var b: Brawler
var game: Node
var diff: Dictionary

var target: Brawler
var target_seen_t := 0.0
var last_seen_pos := Vector2.ZERO
var last_seen_t := 99.0
var heal_target: Brawler
var think_t := 0.0
var path := PackedVector2Array()
var path_i := 0
var goal := Vector2.ZERO
var strafe_sign := 1.0
var strafe_t := 0.0
var dodge_vec := Vector2.ZERO
var dodge_t := 0.0
var _dodge_decided: Dictionary = {}
var fire_t := 0.0
var ability_t := 0.0
var retreating := false
var stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _nudge := Vector2.ZERO
var _nudge_t := 0.0

func setup(brawler: Brawler, g: Node, difficulty: String) -> void:
	b = brawler
	game = g
	diff = Config.DIFFICULTY[difficulty]
	think_t = randf() * 0.3
	fire_t = randf_range(0.2, 0.6)

func tick(delta: float) -> void:
	if not b.alive or not game.is_playing():
		b.move_input = Vector2.ZERO
		return
	think_t -= delta
	last_seen_t += delta
	if think_t <= 0.0:
		think_t = diff.think * randf_range(0.8, 1.25)
		_think()
	_update_dodge(delta)
	_move(delta)
	_combat(delta)

# ------------------------------------------------------------------ perception
func _visible_enemies() -> Array:
	var out: Array = []
	for e: Brawler in game.brawlers:
		if e.alive and e.team != b.team and not e.hidden_from(b.team):
			out.append(e)
	return out

func _think() -> void:
	var enemies := _visible_enemies()
	var best: Brawler = null
	var best_score := INF
	for e: Brawler in enemies:
		var dd := b.global_position.distance_to(e.global_position)
		var score := dd - (1.0 - e.hp / e.max_hp) * 260.0 - (120.0 if e.gems > 0 else 0.0)
		if e == target:
			score -= 140.0 # stick with the current target
		if score < best_score:
			best_score = score
			best = e
	if best != target:
		target = best
		target_seen_t = 0.0
	if target:
		last_seen_pos = target.global_position
		last_seen_t = 0.0

	var hp_frac := b.hp / b.max_hp
	var threat := target != null and b.global_position.distance_to(target.global_position) < T * 7.5
	if not retreating and hp_frac < 0.32 and threat:
		retreating = true
	elif retreating and (hp_frac > 0.82 or (not threat and hp_frac > 0.6)):
		retreating = false

	heal_target = null
	if b.d.attack.kind == "orb":
		var worst := 0.85
		for a: Brawler in game.brawlers:
			if a.alive and a.team == b.team and a != b and a.global_position.distance_to(b.global_position) < T * 9.0:
				var f := a.hp / a.max_hp
				if f < worst:
					worst = f
					heal_target = a

	# choose where to go
	var mode_goal = game.mode.bot_goal(b)
	var atk_range := b.attack_range_px()
	var melee: bool = b.d.attack.kind in ["melee_cone", "twin_slash"]
	if retreating:
		goal = b.spawn_pos
	elif target and b.global_position.distance_to(target.global_position) < atk_range + T * 3.5:
		var pref := atk_range * (0.45 if melee else 0.78)
		var away := (b.global_position - target.global_position).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		goal = target.global_position + away * pref
		# grab a nearby gem if the fight allows it
		if mode_goal != null and b.global_position.distance_to(mode_goal) < T * 2.5 and not melee:
			goal = mode_goal
	elif heal_target:
		goal = heal_target.global_position + (b.spawn_pos - heal_target.global_position).normalized() * T * 2.0
	elif mode_goal != null:
		goal = mode_goal
	elif last_seen_t < 3.0:
		goal = last_seen_pos
	else:
		goal = game.map.size_px * 0.5
	path = game.map.find_path(b.global_position, goal)
	path_i = 1 if path.size() > 1 else 0

# ------------------------------------------------------------------ movement
func _move(delta: float) -> void:
	var dir := Vector2.ZERO
	if path_i < path.size():
		var nxt: Vector2 = path[path_i]
		if b.global_position.distance_to(nxt) < 20.0:
			path_i += 1
		dir = (nxt - b.global_position).normalized()
	elif b.global_position.distance_to(goal) > 14.0:
		dir = (goal - b.global_position).normalized()

	# combat strafing makes bots harder to hit
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.5, 1.4)
		strafe_sign = -strafe_sign
	if target and target.alive and not retreating:
		var to_t := target.global_position - b.global_position
		if to_t.length() < b.attack_range_px() * 1.15:
			var perp := to_t.normalized().orthogonal() * strafe_sign
			dir = (dir * 0.6 + perp * 0.75).normalized()

	if dodge_t > 0.0:
		dodge_t -= delta
		dir = dodge_vec

	# unstick
	_nudge_t -= delta
	if _nudge_t > 0.0:
		dir = _nudge
	if dir.length() > 0.1:
		if b.global_position.distance_to(_last_pos) < 1.2:
			stuck_t += delta
			if stuck_t > 0.45:
				stuck_t = 0.0
				_nudge = Vector2.RIGHT.rotated(randf() * TAU)
				_nudge_t = 0.3
				think_t = 0.0
		else:
			stuck_t = 0.0
	_last_pos = b.global_position
	b.move_input = dir
	if target == null or not target.alive:
		if dir.length() > 0.1:
			b.aim_dir = b.aim_dir.lerp(dir, 0.15).normalized()

func _update_dodge(_delta: float) -> void:
	if dodge_t > 0.0:
		return
	for p in game.projectile_layer.get_children():
		if p is Projectile and p.team != b.team:
			var key: int = p.get_instance_id()
			if not _dodge_decided.has(key):
				_dodge_decided[key] = randf() < diff.dodge
			if not _dodge_decided[key]:
				continue
			var rel: Vector2 = b.global_position - p.global_position
			var along: float = rel.dot(p.dir)
			if along > 0.0 and along < p.speed * 0.4:
				var side: Vector2 = rel - p.dir * along
				if side.length() < b.radius + 26.0:
					var s := 1.0 if side.dot(p.dir.orthogonal()) >= 0.0 else -1.0
					dodge_vec = p.dir.orthogonal() * s
					dodge_t = 0.22
					return
		elif p is LobShot and p.owner_b.team != b.team:
			var key2: int = p.get_instance_id()
			if not _dodge_decided.has(key2):
				_dodge_decided[key2] = randf() < diff.dodge
			if _dodge_decided[key2] and b.global_position.distance_to(p.to) < p.radius + b.radius:
				dodge_vec = (b.global_position - p.to).normalized()
				if dodge_vec == Vector2.ZERO:
					dodge_vec = Vector2.RIGHT
				dodge_t = 0.3
				return
	if _dodge_decided.size() > 200:
		_dodge_decided.clear()

# ------------------------------------------------------------------ combat
func _predict(e: Brawler, travel_time: float) -> Vector2:
	return e.global_position + e.velocity * travel_time * float(diff.lead)

func _aim_at(pos: Vector2) -> Vector2:
	var v := pos - b.global_position
	var err: float = diff.aim_error
	return v.rotated(randf_range(-err, err))

func _travel_time(dist: float) -> float:
	var a: Dictionary = b.d.attack
	match a.kind:
		"lob":
			return a.flight
		"melee_cone":
			return 0.0
		_:
			return dist / float(a.speed)

func _combat(delta: float) -> void:
	fire_t -= delta
	ability_t -= delta
	var a: Dictionary = b.d.attack
	var lobber: bool = a.kind == "lob"
	var has_target := target != null and target.alive and not target.hidden_from(b.team)
	if has_target:
		target_seen_t += delta
		b.aim_dir = b.aim_dir.lerp((target.global_position - b.global_position).normalized(), 0.3).normalized()
	else:
		target_seen_t = 0.0

	if ability_t <= 0.0:
		ability_t = 0.4
		_maybe_gadget(has_target)
		if b.super_charge >= 1.0 and randf() < float(diff.super_smart) + 0.15:
			_maybe_super(has_target)

	if fire_t > 0.0 or b.ammo < 1.0:
		return
	# Support: heal hurt teammates when nobody is threatening us
	if heal_target and heal_target.alive and (not has_target or b.global_position.distance_to(target.global_position) > b.attack_range_px()):
		var hd := b.global_position.distance_to(heal_target.global_position)
		if hd < b.attack_range_px() * 0.9 and game.has_los(b.global_position, heal_target.global_position):
			var aimv := _aim_at(_predict(heal_target, _travel_time(hd)))
			if b.try_attack(aimv.normalized(), aimv.length()):
				fire_t = randf_range(0.4, 0.7)
			return
	if not has_target:
		# "bush check": shoot where we just saw someone disappear
		if last_seen_t < 1.5 and b.ammo >= 2.5 and randf() < 0.02:
			var dd := b.global_position.distance_to(last_seen_pos)
			if dd < b.attack_range_px() and (lobber or game.has_los(b.global_position, last_seen_pos)):
				var v := _aim_at(last_seen_pos)
				b.try_attack(v.normalized(), v.length())
				fire_t = 0.8
		return
	if target_seen_t < float(diff.reaction):
		return
	var dist := b.global_position.distance_to(target.global_position)
	var reach := b.attack_range_px() + (target.radius if a.kind == "melee_cone" else 0.0)
	if dist > reach * 0.96:
		return
	if not lobber and not game.has_los(b.global_position, target.global_position):
		return
	var pred := _predict(target, _travel_time(dist))
	var aim := _aim_at(pred)
	var lob_dist := aim.length() * (1.0 + randf_range(-diff.aim_error, diff.aim_error))
	if b.try_attack(aim.normalized(), lob_dist):
		# keep some ammo in reserve at long range, unload when close
		fire_t = randf_range(0.25, 0.45) if dist < T * 3.0 else randf_range(0.45, 0.85)

func _maybe_super(has_target: bool) -> void:
	var s: Dictionary = b.d.super
	var srange := b.super_range_px()
	match s.kind:
		"leap_slam":
			if has_target:
				var dd := b.global_position.distance_to(target.global_position)
				if dd < srange and dd > T * 1.5 and (target.hp < target.max_hp * 0.6 or _enemies_near(target.global_position, s.radius * T) >= 2):
					var p := _predict(target, s.air_time)
					b.try_super((p - b.global_position).normalized(), b.global_position.distance_to(p))
			elif retreating:
				b.try_super((b.spawn_pos - b.global_position).normalized(), srange)
		"phantom_dash":
			if has_target:
				var dd := b.global_position.distance_to(target.global_position)
				if dd < srange * 0.8 and game.has_los(b.global_position, target.global_position):
					b.try_super((target.global_position - b.global_position).normalized(), dd)
			elif retreating:
				b.try_super((b.spawn_pos - b.global_position).normalized(), srange)
		"lance_beam":
			if has_target and b.global_position.distance_to(target.global_position) < srange * 0.85 and game.has_los(b.global_position, target.global_position):
				var p := _predict(target, s.charge)
				b.try_super((p - b.global_position).normalized(), 0.0)
		"sanctuary":
			for ally: Brawler in game.brawlers:
				if ally.alive and ally.team == b.team and ally.hp < ally.max_hp * 0.5 and ally.global_position.distance_to(b.global_position) < srange:
					b.try_super((ally.global_position - b.global_position).normalized(), b.global_position.distance_to(ally.global_position))
					return
			if has_target and _enemies_near(target.global_position, s.radius * T) >= 2:
				b.try_super((target.global_position - b.global_position).normalized(), b.global_position.distance_to(target.global_position))
		"bramble":
			if has_target and b.global_position.distance_to(target.global_position) < srange:
				var p := _predict(target, s.flight)
				b.try_super((p - b.global_position).normalized(), b.global_position.distance_to(p))

func _maybe_gadget(has_target: bool) -> void:
	if b.gadget_cd > 0.0:
		return
	var gd: Dictionary = b.d.gadget
	var hp_frac := b.hp / b.max_hp
	var near := has_target and b.global_position.distance_to(target.global_position) < T * 4.0
	match gd.kind:
		"iron_skin":
			if near and hp_frac < 0.7:
				b.try_gadget(b.aim_dir)
		"shadow_step":
			if (retreating and hp_frac < 0.4) or (has_target and b.global_position.distance_to(target.global_position) < T * 6.0 and randf() < 0.15):
				b.try_gadget(b.aim_dir)
		"overclock":
			if has_target and b.ammo < 1.0 and b.global_position.distance_to(target.global_position) < b.attack_range_px():
				b.try_gadget(b.aim_dir)
		"mend":
			for ally: Brawler in game.brawlers:
				if ally.alive and ally.team == b.team and ally.hp < ally.max_hp * 0.6 and ally.global_position.distance_to(b.global_position) < gd.radius * T:
					b.try_gadget(b.aim_dir)
					return
		"snare":
			if near or retreating or (b.gems >= 3 and randf() < 0.2):
				b.try_gadget(b.aim_dir)

func _enemies_near(p: Vector2, r: float) -> int:
	var n := 0
	for e: Brawler in game.brawlers:
		if e.alive and e.team != b.team and e.global_position.distance_to(p) <= r + e.radius:
			n += 1
	return n
