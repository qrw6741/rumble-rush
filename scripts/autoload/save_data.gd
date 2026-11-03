extends Node
## Persistent player profile: trophies, credits, upgrades, stats, settings, history.
## Stored as JSON in user:// so it survives closing the game.

signal changed

var save_path := "user://rumble_rush_save.json"
const VERSION := 1

var data: Dictionary = {}
var _granted_matches: Dictionary = {} # match ids already rewarded (prevents double rewards)

func _ready() -> void:
	load_game()
	apply_settings()

func _default() -> Dictionary:
	var trophies := {}
	var levels := {}
	for id in Config.BRAWLER_ORDER:
		trophies[id] = 0
		levels[id] = 1
	return {
		"version": VERSION,
		"username": "Player",
		"credits": 150,
		"xp": 0,
		"brawler_trophies": trophies,
		"brawler_levels": levels,
		"selected_brawler": "bront",
		"selected_mode": "gem_grab",
		"highest_trophies": 0,
		"stats": {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "kos": 0, "deaths": 0, "damage": 0, "mvp": 0},
		"history": [],
		"granted": [],
		"settings": {
			"music_volume": 0.6, "sfx_volume": 0.85, "difficulty": "normal",
			"touch_controls": "auto", "screen_shake": true, "damage_numbers": true,
			"aim_assist": true, "fullscreen": false, "show_fps": false,
		},
	}

func load_game() -> void:
	data = _default()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_merge(data, parsed)
	# sanitize: numbers from JSON come back as floats
	for id in Config.BRAWLER_ORDER:
		data.brawler_trophies[id] = int(data.brawler_trophies.get(id, 0))
		data.brawler_levels[id] = clampi(int(data.brawler_levels.get(id, 1)), 1, Config.MAX_LEVEL)
	data.credits = int(data.credits)
	data.xp = int(data.xp)
	for k in data.stats.keys():
		data.stats[k] = int(data.stats[k])
	if not Config.BRAWLERS.has(data.selected_brawler):
		data.selected_brawler = "bront"
	if not Config.MODES.has(data.selected_mode):
		data.selected_mode = "gem_grab"
	for g in data.granted:
		_granted_matches[str(g)] = true

func _merge(base: Dictionary, incoming: Dictionary) -> void:
	for k in incoming.keys():
		if base.has(k) and base[k] is Dictionary and incoming[k] is Dictionary:
			_merge(base[k], incoming[k])
		else:
			base[k] = incoming[k]

func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
	changed.emit()

# ------------------------------------------------------------------ accessors
func setting(key: String):
	return data.settings.get(key)

func set_setting(key: String, value) -> void:
	data.settings[key] = value
	apply_settings()
	save_game()

func apply_settings() -> void:
	if not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		var want_fs: bool = data.settings.fullscreen
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if want_fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	if is_instance_valid(Sfx) and Sfx.is_node_ready():
		Sfx.apply_volumes()

func total_trophies() -> int:
	var t := 0
	for id in Config.BRAWLER_ORDER:
		t += int(data.brawler_trophies[id])
	return t

func account_level() -> int:
	# 100 xp for level 2, grows by 25 each level
	var lvl := 1
	var need := 100
	var xp: int = data.xp
	while xp >= need:
		xp -= need
		lvl += 1
		need += 25
	return lvl

func level_progress() -> Vector2i:
	var need := 100
	var xp: int = data.xp
	while xp >= need:
		xp -= need
		need += 25
	return Vector2i(xp, need)

func brawler_level(id: String) -> int:
	return int(data.brawler_levels[id])

func brawler_trophies(id: String) -> int:
	return int(data.brawler_trophies[id])

func upgrade_cost(id: String) -> int:
	var lvl := brawler_level(id)
	if lvl >= Config.MAX_LEVEL:
		return -1
	return Config.UPGRADE_COSTS[lvl]

func try_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or data.credits < cost:
		return false
	data.credits -= cost
	data.brawler_levels[id] = brawler_level(id) + 1
	save_game()
	return true

# ------------------------------------------------------------------ match rewards
## result: "win" | "loss" | "draw". Returns the reward breakdown. Rewards are
## granted exactly once per match id.
func grant_match_rewards(match_id: String, brawler_id: String, mode: String, result: String, kos: int, deaths: int, damage: int, mvp: bool) -> Dictionary:
	if _granted_matches.has(match_id):
		return {"duplicate": true, "trophies": 0, "credits": 0, "xp": 0}
	_granted_matches[match_id] = true
	data.granted.append(match_id)
	if data.granted.size() > 60:
		data.granted = data.granted.slice(data.granted.size() - 60)

	var bt := brawler_trophies(brawler_id)
	var trophy_delta := 0
	match result:
		"win":
			trophy_delta = 8 if bt < 200 else (7 if bt < 400 else 6)
		"loss":
			trophy_delta = 0 if bt < 20 else -(3 if bt < 200 else 4)
		_:
			trophy_delta = 0
	trophy_delta = max(trophy_delta, -bt)
	var credits: int = {"win": 30, "loss": 12, "draw": 18}[result] + mini(kos, 10) * 2 + (10 if mvp else 0)
	var xp: int = {"win": 40, "loss": 20, "draw": 28}[result] + kos * 3

	var old_level := account_level()
	data.brawler_trophies[brawler_id] = bt + trophy_delta
	data.credits += credits
	data.xp += xp
	data.highest_trophies = max(int(data.highest_trophies), total_trophies())
	var s: Dictionary = data.stats
	s.matches += 1
	s[{"win": "wins", "loss": "losses", "draw": "draws"}[result]] += 1
	s.kos += kos
	s.deaths += deaths
	s.damage += damage
	if mvp:
		s.mvp += 1
	data.history.push_front({
		"time": Time.get_datetime_string_from_system(false, true),
		"brawler": brawler_id, "mode": mode, "result": result,
		"kos": kos, "deaths": deaths, "damage": damage, "trophies": trophy_delta, "mvp": mvp,
	})
	if data.history.size() > 25:
		data.history.resize(25)
	save_game()
	return {"duplicate": false, "trophies": trophy_delta, "credits": credits, "xp": xp,
		"level_up": account_level() > old_level, "new_level": account_level()}

func reset_progress() -> void:
	var keep_settings: Dictionary = data.settings.duplicate(true)
	var keep_name: String = data.username
	data = _default()
	data.settings = keep_settings
	data.username = keep_name
	_granted_matches.clear()
	save_game()
