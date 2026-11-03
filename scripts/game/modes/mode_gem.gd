class_name ModeGem
extends GameMode
## GEM RUSH: collect crystals from the central mine, hold 10+ (and more than the
## enemy) for 15 seconds to win.

const TARGET := 10
const COUNTDOWN := 15.0
const SPAWN_INTERVAL := 7.0

var spawn_t := 4.0
var countdown_team := -1
var countdown := COUNTDOWN
var _last_beep := 99
var _announced_lead := -1

func team_gems(team: int) -> int:
	var n := 0
	for b: Brawler in game.brawlers:
		if b.team == team:
			n += b.gems
	return n

func update(delta: float) -> void:
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = SPAWN_INTERVAL
		_spawn_from_mine()
	var blue := team_gems(0)
	var red := team_gems(1)
	var leader := -1
	if blue >= TARGET and blue > red:
		leader = 0
	elif red >= TARGET and red > blue:
		leader = 1
	if leader != countdown_team:
		countdown_team = leader
		countdown = COUNTDOWN
		_last_beep = 99
		if leader != -1:
			var ours: bool = leader == game.view_team
			game.announce("YOUR TEAM IS WINNING!" if ours else "ENEMY TEAM IS WINNING!", Config.TEAM_COLORS[leader], 1.8)
			Sfx.play("super_ready" if ours else "ui_error", -2.0, 0.0)
		elif _announced_lead != -1:
			game.announce("COUNTDOWN STOPPED!", Color.WHITE, 1.4)
		_announced_lead = leader
	if countdown_team != -1:
		countdown -= delta
		var sec := int(ceil(countdown))
		if sec != _last_beep and sec <= 10:
			_last_beep = sec
			Sfx.play("beep" if sec > 3 else "tick", -4.0 if sec > 3 else 0.0, 0.0, 1.0 if sec > 3 else 1.6)
		if countdown <= 0.0:
			declare(countdown_team)

func _spawn_from_mine() -> void:
	var mine: Vector2 = game.map.gem_mine
	var map: ArenaMap = game.map
	for _try in 12:
		var off := Vector2(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6)) * Config.TILE
		var p := mine + off
		if map.is_walkable_cell(map.world_to_cell(p)):
			Gem.spawn(game, mine, p, 0.6)
			Sfx.play_at("gem_drop", mine, -10.0)
			FX.burst(game.fx_layer, mine + Vector2(0, -20), Color("b25bff"), 10, 200.0, 0.4, 4.0)
			return

func on_gem_collected(b: Brawler, _gem: Gem) -> void:
	b.gems += 1
	b.stats.gems += 1
	Sfx.play_at("gem_pickup", b.global_position, -2.0)
	FX.burst(game.fx_layer, b.body_center() + Vector2(0, -20), Color("e8c8ff"), 8, 140.0, 0.35, 3.0)

func on_ko(victim: Brawler, _killer: Brawler) -> void:
	if victim.gems <= 0:
		return
	var n := victim.gems
	victim.gems = 0
	Sfx.play_at("gem_drop", victim.global_position, 0.0)
	var map: ArenaMap = game.map
	for i in n:
		var a := TAU * float(i) / float(n) + randf() * 0.4
		var target := victim.global_position + Vector2(cos(a), sin(a)) * randf_range(30.0, 70.0)
		if not map.is_walkable_cell(map.world_to_cell(target)):
			target = map.cell_center(map.nearest_walkable(target))
		Gem.spawn(game, victim.global_position, target, 0.45)

func respawn_delay(_b: Brawler) -> float:
	return Config.RESPAWN_TIME + 1.0

func on_time_up() -> bool:
	var blue := team_gems(0)
	var red := team_gems(1)
	if blue == red:
		declare(-1)
	else:
		declare(0 if blue > red else 1)
	return true

func hud() -> Dictionary:
	return {
		"kind": "gem",
		"blue": team_gems(0), "red": team_gems(1), "target": TARGET,
		"countdown_team": countdown_team, "countdown": countdown,
	}

func bot_goal(b: Brawler):
	var my_team := team_gems(b.team)
	var their := team_gems(1 - b.team)
	# carrying a lot while our countdown runs -> play safe near our own side
	if countdown_team == b.team and b.gems >= 3:
		return b.spawn_pos.lerp(game.map.gem_mine, 0.25)
	if b.gems >= 5 and my_team >= TARGET and b.hp < b.max_hp * 0.6:
		return b.spawn_pos
	# go collect the nearest free gem
	var best = null
	var best_d := INF
	for g: Gem in game.get_tree().get_nodes_in_group("gems"):
		if g.collected or not is_instance_valid(g):
			continue
		var dd := b.global_position.distance_to(g.to)
		if dd < best_d:
			best_d = dd
			best = g.to
	if best != null and best_d < Config.TILE * 12.0:
		return best
	if their > my_team or my_team < TARGET:
		return game.map.gem_mine
	return null
