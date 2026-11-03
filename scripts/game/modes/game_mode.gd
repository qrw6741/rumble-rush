class_name GameMode
extends RefCounted
## Base class for game-mode rules. The Match owns combat; the mode owns scoring,
## objectives, respawn rules, time-up resolution and what bots should go after.

var game: Node
var mode_id := ""
var cfg: Dictionary
var winner := -2 # -2 undecided, -1 draw, 0 blue, 1 red
var overtime := false

func setup(g: Node, id: String) -> void:
	game = g
	mode_id = id
	cfg = Config.MODES[id]

func on_start() -> void:
	pass

func update(_delta: float) -> void:
	pass

func on_ko(_victim: Brawler, _killer: Brawler) -> void:
	pass

func on_gem_collected(_b: Brawler, _gem: Gem) -> void:
	pass

func respawn_delay(_b: Brawler) -> float:
	return Config.RESPAWN_TIME

## Called when the clock hits zero. Return true if the match is resolved.
func on_time_up() -> bool:
	return true

## Mode-specific scoreboard data for the HUD.
func hud() -> Dictionary:
	return {}

## Where an idle bot should head (null = just fight).
func bot_goal(_b: Brawler):
	return null

func declare(team: int) -> void:
	if winner == -2:
		winner = team
		game.finish_match(team)
