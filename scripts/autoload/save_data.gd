extends Node
## Persistent player profile: trophies, credits, upgrades, stats, settings, history.
## Stored as JSON in user:// so it survives closing the game.

signal changed

var save_path := "user://rumble_rush_save.json"
const VERSION := 1

var data: Dictionary = {}
var _granted_matches: Dictionary = {} # match ids already rewarded (prevents double rewards)

const WEB_KEY := "rumble_rush_save_v1"

func _ready() -> void:
	load_game()
	apply_settings()

## Phones close web apps without warning: write the save whenever the game is backgrounded.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not data.is_empty():
			save_game()

func _web_store() -> bool:
	return OS.has_feature("web") and save_path == "user://rumble_rush_save.json"

## Browser localStorage is written instantly (the virtual file system syncs late and
## loses progress when iOS kills the app), so the web build keeps its save there too.
func _web_write(text: String) -> void:
	if _web_store():
		JavaScriptBridge.eval("try{localStorage.setItem('%s', %s)}catch(e){}" % [WEB_KEY, JSON.stringify(text)], true)

func _web_read() -> String:
	if not _web_store():
		return ""
	var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % WEB_KEY, true)
	return v if v is String else ""

func _default() -> Dictionary:
	var trophies := {}
	var levels := {}
	var ranks := {}
	var skins := {}
	for id in Config.BRAWLER_ORDER:
		trophies[id] = 0
		levels[id] = 1
		ranks[id] = []
		skins[id] = ""
	return {
		"version": VERSION,
		"username": "Player",
		"credits": 150,
		"xp": 0,
		"brawler_trophies": trophies,
		"brawler_levels": levels,
		"selected_brawler": "bront",
		"selected_mode": "gem_grab",
		"selected_map": "",
		"highest_trophies": 0,
		"stats": {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "kos": 0, "deaths": 0, "damage": 0, "mvp": 0},
		"history": [],
		"granted": [],
		"pass_tokens": 0,
		"gold_pass": false,
		"pass_claimed": {"free": [], "gold": []},
		"road_claimed": [],
		"rank_claimed": ranks,
		"skins_owned": [],
		"gems": 30,
		"drops": [],
		"shop": {"day": "", "bought": []},
		"skin_selected": skins,
		"settings": {
			"music_volume": 0.6, "sfx_volume": 0.85, "difficulty": "auto",
			"touch_controls": "auto", "screen_shake": true, "damage_numbers": true,
			"aim_assist": true, "fullscreen": false, "show_fps": false, "graphics": "auto", "fps_cap": 60,
		},
	}

func load_game() -> void:
	data = _default()
	var text := _web_read()
	if text == "" and FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			text = f.get_as_text()
	if text != "":
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			_merge(data, parsed)
	# sanitize: numbers from JSON come back as floats
	for id in Config.BRAWLER_ORDER:
		data.brawler_trophies[id] = int(data.brawler_trophies.get(id, 0))
		data.brawler_levels[id] = clampi(int(data.brawler_levels.get(id, 1)), 1, Config.MAX_LEVEL)
	# bots now scale with brawler rank: move older saves onto AUTO once
	if not data.get("diff_auto_v2", false):
		data.settings.difficulty = "auto"
		data["diff_auto_v2"] = true
	if data.settings.difficulty == "expert":
		data.settings.difficulty = "extreme"
	data.credits = int(data.credits)
	data.gems = int(data.get("gems", 0))
	var dr: Array = []
	for x in data.get("drops", []):
		dr.append(int(x))
	data.drops = dr
	data.xp = int(data.xp)
	for k in data.stats.keys():
		data.stats[k] = int(data.stats[k])
	data.pass_tokens = int(data.pass_tokens)
	for track in ["free", "gold"]:
		data.pass_claimed[track] = data.pass_claimed.get(track, []).map(func(x): return int(x))
	data.road_claimed = data.road_claimed.map(func(x): return int(x))
	for id in Config.BRAWLER_ORDER:
		data.rank_claimed[id] = data.rank_claimed.get(id, []).map(func(x): return int(x))
		if not data.skin_selected.has(id):
			data.skin_selected[id] = ""
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
	var text := JSON.stringify(data)
	_web_write(text)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
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
	apply_fps()
	if is_instance_valid(Sfx) and Sfx.is_node_ready():
		Sfx.apply_volumes()

## FPS limit: 30 / 60 / 90 / 120, or 0 = MAX (no cap, V-Sync off on desktop).
func apply_fps() -> void:
	var cap := int(data.settings.get("fps_cap", 60))
	if OS.has_feature("web"):
		# Browsers already pace frames to the screen. Godot's own limiter on top of that
		# drops every other frame (60 -> 30), so only use it for the 30 FPS battery saver.
		Engine.max_fps = 30 if cap == 30 else 0
		return
	Engine.max_fps = cap
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if cap == 0 or cap > 60 else DisplayServer.VSYNC_ENABLED)

## Phones and browsers default to lighter rendering.
func low_graphics() -> bool:
	var g: String = data.settings.get("graphics", "auto")
	if g == "low":
		return true
	if g == "high":
		return false
	return OS.has_feature("web") or OS.has_feature("mobile")

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
func grant_match_rewards(match_id: String, brawler_id: String, mode: String, result: String, kos: int, deaths: int, damage: int, mvp: bool, placement := 0) -> Dictionary:
	if _granted_matches.has(match_id):
		return {"duplicate": true, "trophies": 0, "credits": 0, "xp": 0}
	_granted_matches[match_id] = true
	data.granted.append(match_id)
	if data.granted.size() > 60:
		data.granted = data.granted.slice(data.granted.size() - 60)

	var bt := brawler_trophies(brawler_id)
	var trophy_delta := 0
	trophy_delta = Progression.trophy_change(bt, result, placement)
	trophy_delta = max(trophy_delta, -bt)
	var credits: int = {"win": 30, "loss": 12, "draw": 18}[result] + mini(kos, 10) * 2 + (10 if mvp else 0)
	var xp: int = {"win": 40, "loss": 20, "draw": 28}[result] + kos * 3

	var tokens := Progression.match_tokens(result, kos)
	data.pass_tokens += tokens
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
		"kos": kos, "deaths": deaths, "damage": damage, "trophies": trophy_delta, "mvp": mvp, "placement": placement,
	})
	if data.history.size() > 25:
		data.history.resize(25)
	save_game()
	return {"duplicate": false, "trophies": trophy_delta, "credits": credits, "xp": xp, "tokens": tokens,
		"rank_up": Progression.rank_for(bt + trophy_delta) > Progression.rank_for(bt), "new_rank": Progression.rank_for(bt + trophy_delta),
		"level_up": account_level() > old_level, "new_level": account_level()}

func reset_progress() -> void:
	var keep_settings: Dictionary = data.settings.duplicate(true)
	var keep_name: String = data.username
	data = _default()
	data.settings = keep_settings
	data.username = keep_name
	_granted_matches.clear()
	save_game()

# ------------------------------------------------------------------ rewards / pass / road / ranks
func grant_reward(r: Dictionary) -> void:
	match r.get("type", ""):
		"credits":
			data.credits += int(r.amount)
		"tokens":
			data.pass_tokens += int(r.amount)
		"xp":
			data.xp += int(r.amount)
		"skin":
			var key := "%s:%s" % [r.brawler, r.skin]
			if not key in data.skins_owned:
				data.skins_owned.append(key)
			else:
				data.gems += 25 # duplicate skins turn into gems
		"gems":
			data.gems += int(r.amount)
		"bundle":
			for it in r.items:
				grant_reward(it)
		"drop":
			data.drops.append(int(r.get("tier", 0)))

## Opens the next unopened drop (from the pass, road or shop). Returns {} if none.
func open_next_drop() -> Dictionary:
	if data.drops.is_empty():
		return {}
	var tier: int = data.drops.pop_front()
	var prize := open_drop(tier)
	prize["drop_tier"] = tier
	return prize

func open_drop(tier: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var prize := Progression.roll_drop(tier, rng, data.skins_owned)
	grant_reward(prize)
	save_game()
	return prize

# ------------------------------------------------------------------ shop
func today_key() -> String:
	return Time.get_date_string_from_system()

func _shop_roll() -> void:
	if data.shop.get("day", "") != today_key():
		data.shop = {"day": today_key(), "bought": []}

func shop_offers() -> Array:
	_shop_roll()
	return Progression.daily_offers(today_key())

func shop_bought(id: String) -> bool:
	_shop_roll()
	return id in data.shop.bought

func can_afford(currency: String, cost: int) -> bool:
	match currency:
		"free": return true
		"credits": return int(data.credits) >= cost
		"gems": return int(data.gems) >= cost
	return false

func spend(currency: String, cost: int) -> bool:
	if not can_afford(currency, cost):
		return false
	if currency == "credits":
		data.credits -= cost
	elif currency == "gems":
		data.gems -= cost
	return true

## Buys an offer. once=true offers can only be bought once per day.
func buy(id: String, reward: Dictionary, currency: String, cost: int, once := true) -> bool:
	_shop_roll()
	if once and id in data.shop.bought:
		return false
	if not spend(currency, cost):
		return false
	if once:
		data.shop.bought.append(id)
	grant_reward(reward)
	save_game()
	return true

func pass_tier() -> int:
	return mini(Progression.PASS_TIERS, int(data.pass_tokens) / Progression.TOKENS_PER_TIER)

func pass_claimable(tier: int, track: String) -> bool:
	if tier < 1 or tier > pass_tier():
		return false
	if track == "gold" and not data.gold_pass:
		return false
	return not tier in data.pass_claimed[track]

func claim_pass(tier: int, track: String) -> bool:
	if not pass_claimable(tier, track):
		return false
	data.pass_claimed[track].append(tier)
	grant_reward(Progression.pass_reward(tier, track))
	save_game()
	return true

func pass_unclaimed() -> int:
	var n := 0
	for t in range(1, pass_tier() + 1):
		if pass_claimable(t, "free"):
			n += 1
		if pass_claimable(t, "gold"):
			n += 1
	return n

func buy_gold_pass() -> bool:
	if data.gold_pass or data.credits < Progression.GOLD_PASS_COST:
		return false
	data.credits -= Progression.GOLD_PASS_COST
	data.gold_pass = true
	save_game()
	return true

func road_claimable(i: int) -> bool:
	return i >= 0 and i < Progression.ROAD.size() and total_trophies() >= int(Progression.ROAD[i].trophies) and not i in data.road_claimed

func claim_road(i: int) -> bool:
	if not road_claimable(i):
		return false
	data.road_claimed.append(i)
	grant_reward(Progression.ROAD[i].reward)
	save_game()
	return true

func road_unclaimed() -> int:
	var n := 0
	for i in Progression.ROAD.size():
		if road_claimable(i):
			n += 1
	return n

func brawler_rank(id: String) -> int:
	return Progression.rank_for(brawler_trophies(id))

func rank_claimable(id: String, rank: int) -> bool:
	return rank >= 2 and rank <= brawler_rank(id) and not rank in data.rank_claimed[id]

func claim_rank(id: String, rank: int) -> bool:
	if not rank_claimable(id, rank):
		return false
	data.rank_claimed[id].append(rank)
	grant_reward(Progression.rank_reward(rank))
	save_game()
	return true

func rank_unclaimed(id: String) -> int:
	var n := 0
	for r in range(2, brawler_rank(id) + 1):
		if rank_claimable(id, r):
			n += 1
	return n

func ranks_unclaimed_total() -> int:
	var n := 0
	for id in Config.BRAWLER_ORDER:
		n += rank_unclaimed(id)
	return n

func owns_skin(id: String, skin: String) -> bool:
	return skin == "" or ("%s:%s" % [id, skin]) in data.skins_owned

func selected_skin(id: String) -> String:
	var s: String = data.skin_selected.get(id, "")
	return s if owns_skin(id, s) else ""

func select_skin(id: String, skin: String) -> bool:
	if not owns_skin(id, skin):
		return false
	data.skin_selected[id] = skin
	save_game()
	return true
