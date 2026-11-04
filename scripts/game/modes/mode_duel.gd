class_name ModeDuel
extends GameMode
## DUEL RUSH: 1v1, best of 3 rounds. A round ends on the first knockout (no
## respawns). After 60 s in a round the arena starts closing in from the edges.

const ROUND_CLOSE := 60.0     # seconds into a round before the walls close in
const CLOSE_RATE := 0.35      # tiles per second the safe area shrinks
const MIN_SAFE := 2.0
const POISON_DPS := 1100.0
const ROUNDS_TO_WIN := 2

var score := [0, 0]
var round_no := 1
var safe_half := 999.0
var _full_half := 8.0
var _round_t := 0.0
var _intermission := 0.0
var _poison_tick := 0.0
var _warned := false

func on_start() -> void:
	_full_half = float(maxi(game.map.w, game.map.h)) * 0.5
	safe_half = _full_half
	game.announce("ROUND 1", Color.WHITE, 1.4)

func update(delta: float) -> void:
	if _intermission > 0.0:
		_intermission -= delta
		if _intermission <= 0.0:
			_next_round()
		return
	_round_t += delta
	if _round_t > ROUND_CLOSE:
		if not _warned:
			_warned = true
			game.announce("THE ARENA IS CLOSING IN!", Color("9dff8a"), 1.8)
		safe_half = maxf(MIN_SAFE, _full_half - (_round_t - ROUND_CLOSE) * CLOSE_RATE)
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick = 0.5
		var dps: float = POISON_DPS * (1.0 + maxf(0.0, _round_t - ROUND_CLOSE) / 30.0)
		for b: Brawler in game.brawlers:
			if b.alive and in_poison(b.global_position):
				b.protect_t = 0.0
				b.take_damage(dps * 0.5, null)

func in_poison(p: Vector2) -> bool:
	var c: Vector2 = game.map.size_px * 0.5
	var t := Config.TILE
	return absf(p.x - c.x) > safe_half * t or absf(p.y - c.y) > safe_half * t

func on_ko(victim: Brawler, _killer: Brawler) -> void:
	if _intermission > 0.0 or winner != -2:
		return
	var t := 1 - victim.team
	score[t] += 1
	if score[t] >= ROUNDS_TO_WIN:
		declare(t)
		return
	var ours: bool = t == game.view_team
	game.announce("ROUND WON!" if ours else "ROUND LOST", Config.tc(t), 1.8)
	_intermission = 2.6

func _next_round() -> void:
	round_no += 1
	_round_t = 0.0
	_warned = false
	safe_half = _full_half
	for b: Brawler in game.brawlers:
		b.respawn(b.spawn_pos)
		b.reset_physics_interpolation()
		b.super_charge = 0.0
	var final: bool = score[0] == 1 and score[1] == 1
	game.announce("FINAL ROUND!" if final else "ROUND %d" % round_no, Color("ffd23a") if final else Color.WHITE, 1.5)
	Sfx.play("go", 0.0, 0.0)

## No respawns inside a round: rounds reset everyone instead.
func respawn_delay(_b: Brawler) -> float:
	return INF

func on_time_up() -> bool:
	if score[0] != score[1]:
		declare(0 if score[0] > score[1] else 1)
	else:
		# still tied: whoever has more health right now takes it
		var hp := [0.0, 0.0]
		for b: Brawler in game.brawlers:
			if b.alive:
				hp[b.team] += b.hp / b.max_hp
		declare(0 if hp[0] > hp[1] else (1 if hp[1] > hp[0] else -1))
	return true

func hud() -> Dictionary:
	return {"kind": "knockout", "blue": score[0], "red": score[1], "target": ROUNDS_TO_WIN, "overtime": false, "safe": safe_half}

func bot_goal(b: Brawler):
	var mid: Vector2 = game.map.size_px * 0.5
	return mid.lerp(b.spawn_pos, 0.15)
