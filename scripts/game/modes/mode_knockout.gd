class_name ModeKnockout
extends GameMode
## KNOCKOUT RUSH: first team to 10 KOs. Tie at time-up -> 30 s sudden death.

const OVERTIME := 30.0

var score := [0, 0]
var target := 10

func on_start() -> void:
	target = cfg.get("target", 10)

func on_ko(victim: Brawler, _killer: Brawler) -> void:
	var t := 1 - victim.team
	score[t] += 1
	if overtime:
		declare(t)
		return
	if score[t] >= target:
		declare(t)
	elif score[t] == target - 2:
		var ours: bool = t == game.view_team
		game.announce("2 KOs TO VICTORY!" if ours else "ENEMY NEEDS 2 MORE KOs!", Config.TEAM_COLORS[t], 1.5)

func respawn_delay(_b: Brawler) -> float:
	return Config.RESPAWN_TIME + 2.0

func on_time_up() -> bool:
	if score[0] != score[1]:
		declare(0 if score[0] > score[1] else 1)
		return true
	if overtime:
		declare(-1)
		return true
	overtime = true
	game.time_left = OVERTIME
	game.announce("SUDDEN DEATH!\nNext KO wins", Color("ffd23a"), 2.2)
	Sfx.play("go", 0.0, 0.0)
	return false

func hud() -> Dictionary:
	return {"kind": "knockout", "blue": score[0], "red": score[1], "target": target, "overtime": overtime}

func bot_goal(b: Brawler):
	# push toward the middle, slightly favouring our own half
	var mid: Vector2 = game.map.size_px * 0.5
	return mid.lerp(b.spawn_pos, 0.2)
