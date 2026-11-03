class_name ModeShowdown
extends GameMode
## SHOWDOWN: 10-brawler solo free-for-all. No respawns. Power boxes drop power
## cells (+health, +damage). Poison clouds close in from the edges. Your
## placement decides your trophies.

const POISON_START := 25.0     # seconds before the clouds start moving
const POISON_RATE := 0.11      # tiles per second the safe area shrinks
const MIN_SAFE := 3.0          # final safe half-size in tiles
const POISON_DPS := 900.0      # base poison damage per second (grows over time)

var safe_half := 999.0         # half-size of the safe square, in tiles
var _full_half := 17.5
var _poison_tick := 0.0
var _poison_warned := false
var placement: Dictionary = {} # Brawler -> final place (1 = winner)

func on_start() -> void:
	_full_half = float(game.map.w) * 0.5
	safe_half = _full_half

func alive_count() -> int:
	var n := 0
	for b: Brawler in game.brawlers:
		if b.alive:
			n += 1
	return n

func update(delta: float) -> void:
	var elapsed: float = cfg.time_limit - game.time_left
	if elapsed > POISON_START:
		if not _poison_warned:
			_poison_warned = true
			game.announce("POISON CLOUDS ARE CLOSING IN!", Color("9dff8a"), 2.0)
		safe_half = max(MIN_SAFE, _full_half - (elapsed - POISON_START) * POISON_RATE)
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick = 0.5
		var dps: float = POISON_DPS * (1.0 + maxf(0.0, elapsed - POISON_START) / 60.0)
		for b: Brawler in game.brawlers:
			if b.alive and in_poison(b.global_position):
				var before := b.alive
				b.protect_t = 0.0
				b.take_damage(dps * 0.5, null)
				if before and not b.alive:
					pass

## True if a world position is inside the poison clouds.
func in_poison(p: Vector2) -> bool:
	var c: Vector2 = game.map.size_px * 0.5
	var t := Config.TILE
	return absf(p.x - c.x) > safe_half * t or absf(p.y - c.y) > safe_half * t

func on_ko(victim: Brawler, _killer: Brawler) -> void:
	var left := alive_count()
	placement[victim] = left + 1
	# drop every power cell they carried
	for k in victim.power_cells:
		var a: float = TAU * k / maxi(1, victim.power_cells) + randf() * 0.5
		var target := victim.global_position + Vector2(cos(a), sin(a)) * randf_range(28.0, 60.0)
		var map: ArenaMap = game.map
		if not map.is_walkable_cell(map.world_to_cell(target)):
			target = map.cell_center(map.nearest_walkable(target))
		PowerCell.spawn(game, victim.global_position, target)
	if victim == game.player:
		game.finish_showdown(left + 1)
		return
	if left <= 1:
		var winner: Brawler = null
		for b: Brawler in game.brawlers:
			if b.alive:
				winner = b
		if winner:
			placement[winner] = 1
		game.finish_showdown(1 if winner == game.player else placement.get(game.player, left + 1))
	elif left <= 3:
		game.announce("%d BRAWLERS LEFT!" % left, Color("ffd23a"), 1.2)

func respawn_delay(_b: Brawler) -> float:
	return INF # no respawns in Showdown

func on_crate_broken(pos: Vector2) -> void:
	PowerCell.spawn(game, pos, pos + Vector2(randf_range(-10, 10), randf_range(4, 14)))

func on_time_up() -> bool:
	# rank the survivors by remaining health
	var p: Brawler = game.player
	var better := 0
	for b: Brawler in game.brawlers:
		if b.alive and b != p and b.hp > p.hp:
			better += 1
	game.finish_showdown(better + 1)
	return true

func hud() -> Dictionary:
	return {"kind": "showdown", "left": alive_count(), "target": 1, "blue": 0, "red": 0, "safe": safe_half}

func bot_goal(b: Brawler):
	var c: Vector2 = game.map.size_px * 0.5
	var t := Config.TILE
	# get out of (or away from the edge of) the poison first
	var margin := 2.5
	var d := b.global_position - c
	if absf(d.x) > (safe_half - margin) * t or absf(d.y) > (safe_half - margin) * t:
		return c + d.normalized() * max(0.0, (safe_half - margin - 2.0)) * t * 0.5
	# grab nearby power cells
	var best = null
	var best_d := t * 9.0
	for pc: PowerCell in game.get_tree().get_nodes_in_group("power_cells"):
		if pc.collected or in_poison(pc.to):
			continue
		var dd := b.global_position.distance_to(pc.to)
		if dd < best_d:
			best_d = dd
			best = pc.to
	if best != null:
		return best
	# otherwise hunt for boxes, then drift toward the middle
	var box = null
	var box_d := t * 10.0
	for cr: Crate in game.get_tree().get_nodes_in_group("crates"):
		var cp := cr.global_position + Vector2(0, -24)
		if in_poison(cp):
			continue
		var dd2 := b.global_position.distance_to(cp)
		if dd2 < box_d:
			box_d = dd2
			box = cp
	if box != null:
		return box
	return c.lerp(b.global_position, 0.6)

func retreat_point(b: Brawler) -> Vector2:
	var c: Vector2 = game.map.size_px * 0.5
	return c.lerp(b.global_position, 0.5)
