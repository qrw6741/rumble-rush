class_name Progression
extends RefCounted
## Long-term progression content: Rush Pass (season pass), Trophy Road and
## per-brawler Ranks, plus the skins they can award. All numbers live here.

# ------------------------------------------------------------------ Rush Pass
const PASS_NAME := "RUSH PASS"
const PASS_SEASON := "SEASON 1: NEON DESERT"
const PASS_TIERS := 30
const TOKENS_PER_TIER := 100
const GOLD_PASS_COST := 600 # credits (no real money)

## Tokens earned per match.
static func match_tokens(result: String, kos: int) -> int:
	return {"win": 40, "loss": 20, "draw": 28}[result] + mini(kos, 8) * 3

## Brawler challenges on the gold track: reach the tier AND finish the challenge.
const PASS_CHALLENGES := {
	7: {"brawler": "rio", "kos": 12},
	14: {"brawler": "vex", "kos": 15},
	21: {"brawler": "rio", "kos": 20},
	27: {"brawler": "bront", "kos": 25},
}

static func challenge_text(c: Dictionary) -> String:
	return "Defeat %d enemies with %s" % [int(c.kos), Config.BRAWLERS[c.brawler].name]

## Reward for a tier on a track ("free" or "gold"). Tier is 1-based.
static func pass_reward(tier: int, track: String) -> Dictionary:
	if track == "gold" and PASS_CHALLENGES.has(tier):
		return {"type": "credits", "amount": 350, "challenge": PASS_CHALLENGES[tier]}
	if track == "gold":
		var skin_tiers := {6: "bront", 12: "vex", 18: "nova", 24: "rio", 30: "sprig"}
		if skin_tiers.has(tier):
			return {"type": "skin", "brawler": skin_tiers[tier], "skin": "gold"}
		if tier % 5 == 0:
			return {"type": "credits", "amount": 150}
		if tier % 4 == 0:
			return {"type": "gems", "amount": 15}
		if tier % 3 == 0:
			return {"type": "drop", "tier": 1}
		return {"type": "credits", "amount": 40 + tier * 2}
	# free track
	if tier == PASS_TIERS:
		return {"type": "brawler", "brawler": "ember"}
	if tier % 10 == 0:
		return {"type": "skin", "brawler": ["nova", "bront", "rio"][tier / 10 - 1], "skin": "shadow"}
	if tier % 4 == 0:
		return {"type": "gems", "amount": 5}
	if tier % 3 == 0:
		return {"type": "drop", "tier": 0}
	return {"type": "credits", "amount": 20 + tier}

## Season end: the last day of the current month.
static func season_time_left() -> String:
	var now := Time.get_datetime_dict_from_system()
	var mdays := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var y := int(now.year)
	var m := int(now.month)
	var dim: int = mdays[m - 1] + (1 if m == 2 and y % 4 == 0 else 0)
	var days := dim - int(now.day)
	var hours := 23 - int(now.hour)
	return "%dd %dh" % [days, hours]

# ------------------------------------------------------------------ daily quests
## Three quests a day (same for the whole day). Finishing one pays pass tokens.
static func daily_quests(day_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day_key + "quests")
	var ids: Array = Save.data.get("unlocked", Config.STARTER_BRAWLERS)
	var modes: Array = Config.MODES.keys()
	var bid: String = ids[rng.randi() % ids.size()]
	var mid: String = modes[rng.randi() % modes.size()]
	return [
		{"id": "q_win", "kind": "win", "goal": 2 + rng.randi() % 2, "tokens": 150, "text": "Win %d matches"},
		{"id": "q_kos", "kind": "kos", "brawler": bid, "goal": 6 + rng.randi() % 5, "tokens": 200, "text": "Defeat %d enemies with " + Config.BRAWLERS[bid].name},
		{"id": "q_mode", "kind": "mode", "mode": mid, "goal": 2 + rng.randi() % 2, "tokens": 120, "text": "Play %d matches of " + Config.MODES[mid].name},
	]

# ------------------------------------------------------------------ Trophy Road
const ROAD := [
	{"trophies": 10, "reward": {"type": "credits", "amount": 50}},
	{"trophies": 25, "reward": {"type": "gems", "amount": 20}},
	{"trophies": 50, "reward": {"type": "credits", "amount": 100}},
	{"trophies": 80, "reward": {"type": "skin", "brawler": "sprig", "skin": "shadow"}},
	{"trophies": 100, "reward": {"type": "brawler", "brawler": "bruno"}},
	{"trophies": 120, "reward": {"type": "credits", "amount": 150}},
	{"trophies": 160, "reward": {"type": "drop", "tier": 2}},
	{"trophies": 200, "reward": {"type": "credits", "amount": 200}},
	{"trophies": 250, "reward": {"type": "skin", "brawler": "vex", "skin": "shadow"}},
	{"trophies": 300, "reward": {"type": "brawler", "brawler": "dusty"}},
	{"trophies": 375, "reward": {"type": "gems", "amount": 40}},
	{"trophies": 450, "reward": {"type": "credits", "amount": 300}},
	{"trophies": 550, "reward": {"type": "skin", "brawler": "bront", "skin": "gold"}},
	{"trophies": 600, "reward": {"type": "brawler", "brawler": "kora"}},
	{"trophies": 650, "reward": {"type": "credits", "amount": 400}},
	{"trophies": 800, "reward": {"type": "drop", "tier": 2}},
	{"trophies": 900, "reward": {"type": "brawler", "brawler": "patch"}},
	{"trophies": 1000, "reward": {"type": "credits", "amount": 600}},
]
## Trophy values of the old road (claims used to be stored by index).
const OLD_ROAD_TROPHIES := [10, 25, 50, 80, 120, 160, 200, 250, 300, 375, 450, 550, 650, 800, 1000]

# ------------------------------------------------------------------ trophy changes
## Trophy bands: the more trophies a brawler has, the less a win gives and the
## more a loss costs. Team modes use [win, loss]; Showdown uses a placement table.
const TROPHY_BANDS := [
	# max trophies, win, loss, showdown 1st..10th
	[49, 8, 0, [10, 8, 7, 6, 4, 2, 2, 1, 0, 0]],
	[99, 8, -1, [10, 8, 7, 6, 3, 2, 1, 0, -1, -2]],
	[199, 8, -2, [10, 8, 6, 5, 3, 1, 0, -1, -2, -2]],
	[299, 8, -3, [10, 8, 6, 5, 3, 1, 0, -2, -2, -3]],
	[399, 7, -4, [9, 7, 6, 4, 2, 0, -1, -2, -3, -4]],
	[499, 7, -5, [8, 7, 5, 4, 2, 0, -2, -3, -4, -5]],
	[599, 6, -6, [7, 6, 5, 3, 1, -1, -2, -3, -5, -6]],
	[799, 5, -7, [6, 5, 4, 2, 0, -2, -3, -5, -6, -7]],
	[999999, 4, -8, [5, 4, 3, 1, -1, -3, -4, -6, -7, -8]],
]

static func trophy_change(trophies: int, result: String, placement := 0) -> int:
	var band: Array = TROPHY_BANDS[TROPHY_BANDS.size() - 1]
	for b in TROPHY_BANDS:
		if trophies <= int(b[0]):
			band = b
			break
	if placement > 0:
		return int(band[3][clampi(placement - 1, 0, 9)])
	match result:
		"win": return int(band[1])
		"loss": return int(band[2])
	return 0

# ------------------------------------------------------------------ Win streak
## Streak bonus starts at 2 wins in a row and grows with every extra win.
const STREAK_MAX_BONUS := 10

static func streak_bonus(streak: int) -> Dictionary:
	if streak < 2:
		return {"trophies": 0, "credits": 0}
	var step := mini(streak - 1, STREAK_MAX_BONUS)
	return {"trophies": mini(step, 6), "credits": 10 * step + (5 * maxi(0, streak - 5))}

static func streak_color(streak: int) -> Color:
	if streak >= 10: return Color("c45cff")
	if streak >= 6: return Color("ff4a2a")
	if streak >= 4: return Color("ff8a1f")
	return Color("ffc12e")

# ------------------------------------------------------------------ Brawler ranks
## Trophies needed to reach rank i+1 (index 0 = rank 1).
const RANK_TROPHIES := [0, 10, 20, 30, 40, 60, 80, 100, 120, 140,
	160, 180, 220, 260, 300, 340, 380, 420, 460, 500,
	550, 600, 650, 700, 750, 800, 850, 900, 950, 1000,
	1050, 1100, 1150, 1200, 1250]
const MAX_RANK := 35

static func rank_for(trophies: int) -> int:
	var r := 1
	for i in RANK_TROPHIES.size():
		if trophies >= RANK_TROPHIES[i]:
			r = i + 1
	return r

## Progress within the current rank: Vector2i(current_into_rank, needed_for_next) (needed 0 at max).
static func rank_progress(trophies: int) -> Vector2i:
	var r := rank_for(trophies)
	if r >= MAX_RANK:
		return Vector2i(0, 0)
	var lo: int = RANK_TROPHIES[r - 1]
	var hi: int = RANK_TROPHIES[r]
	return Vector2i(trophies - lo, hi - lo)

## Badge colours by rank band (every 5 ranks a new colour; 35 is the final one).
const RANK_TIER_COLORS := [
	Color("e8873a"), # 1-4   copper
	Color("9aa6e0"), # 5-9   steel
	Color("f5b82e"), # 10-14 gold
	Color("2fb8ec"), # 15-19 sky
	Color("c44fe0"), # 20-24 orchid
	Color("2fcf86"), # 25-29 jade
	Color("e8404f"), # 30-34 ruby
	Color("5b46c8"), # 35    royal
]

static func rank_tier(rank: int) -> int:
	if rank >= 35:
		return 7
	return clampi(rank / 5, 0, 6)

static func rank_color(rank: int) -> Color:
	return RANK_TIER_COLORS[rank_tier(rank)]

## Reward for reaching a rank (rank 1 has none).
static func rank_reward(rank: int) -> Dictionary:
	if rank <= 1:
		return {}
	if rank % 5 == 0:
		return {"type": "credits", "amount": 30 + rank * 6}
	if rank % 2 == 0:
		return {"type": "tokens", "amount": 20 + rank * 2}
	return {"type": "credits", "amount": 10 + rank * 2}

# ------------------------------------------------------------------ skins
## Colour variants applied on top of a brawler's base palette.
const SKINS := {
	"gold": {"name": "GOLD", "primary": Color("ffcc33"), "secondary": Color("8a5a10"), "accent": Color("fff2b0")},
	"shadow": {"name": "SHADOW", "primary": Color("3a3f5a"), "secondary": Color("15172a"), "accent": Color("ff3d6e")},
}

## Unique skins made for one brawler. "fx" adds an animated effect in 2D.
const SPECIAL_SKINS := {
	"inferno": {"name": "INFERNO OUTLAW", "only": "dusty", "price": 149, "fx": "fire",
		"primary": Color("3a1a14"), "secondary": Color("1a0e0a"), "accent": Color("ff9a2a"), "skin": Color("a8603a")},
	"frost": {"name": "FROST WRAITH", "only": "graves", "price": 149, "fx": "frost",
		"primary": Color("cfe8ff"), "secondary": Color("4a7ab0"), "accent": Color("8ae4ff"), "skin": Color("f4fbff")},
	"neon": {"name": "NEON TAGGER", "only": "rio", "price": 99, "fx": "neon",
		"primary": Color("1a1a2e"), "secondary": Color("ff3df0"), "accent": Color("3dfff0"), "skin": Color("b98563")},
	"polar": {"name": "POLAR CHAMP", "only": "bruno", "price": 99,
		"primary": Color("2a8cff"), "secondary": Color("1a3a7a"), "accent": Color("dff4ff"), "skin": Color("f2f2f6")},
	"magma": {"name": "MAGMA MINER", "only": "bront", "price": 99, "fx": "fire",
		"primary": Color("3a2a2a"), "secondary": Color("1a1010"), "accent": Color("ff6a1a"), "skin": Color("c98b62")},
}

static func skin_info(skin: String) -> Dictionary:
	if SKINS.has(skin):
		return SKINS[skin]
	return SPECIAL_SKINS.get(skin, {})

## Every skin a brawler can wear (not counting the default).
static func skins_for(brawler_id: String) -> Array:
	var out: Array = ["gold", "shadow"]
	for k in SPECIAL_SKINS.keys():
		if SPECIAL_SKINS[k].only == brawler_id:
			out.append(k)
	return out

static func skin_price(skin: String) -> int:
	if SKIN_PRICE.has(skin):
		return int(SKIN_PRICE[skin])
	return int(SPECIAL_SKINS.get(skin, {}).get("price", 99))

static func palette(brawler_id: String, skin: String) -> Dictionary:
	var d: Dictionary = Config.BRAWLERS[brawler_id].duplicate()
	var s := skin_info(skin)
	if not s.is_empty():
		d.primary = s.primary
		d.secondary = s.secondary
		d.accent = s.accent
		if s.has("skin"):
			d.skin = s.skin
		d.fx = s.get("fx", "")
	return d

static func reward_text(r: Dictionary) -> String:
	match r.get("type", ""):
		"credits": return "%d COINS" % r.amount
		"tokens": return "%d PASS TOKENS" % r.amount
		"champs_tokens": return "%d CHAMPS TOKENS" % r.amount
		"xp": return "%d XP" % r.amount
		"skin": return "%s %s" % [skin_info(r.skin).name, Config.BRAWLERS[r.brawler].name]
		"gems": return "%d GEMS" % r.amount
		"bundle": return "BUNDLE"
		"brawler": return "NEW BRAWLER: " + Config.BRAWLERS[r.brawler].name
		"drop": return "%s DROP" % DROP_TIERS[int(r.get("tier", 0))].name
	return ""

# ------------------------------------------------------------------ Rush Drops
## Reward pods. Opening one rolls a rarity, then a prize from that rarity.
const DROP_TIERS := [
	{"name": "RUSH", "color": Color("8e4dff")},
	{"name": "SUPER", "color": Color("2a8cff")},
	{"name": "MEGA", "color": Color("ff4d5e")},
]
const RARITIES := [
	{"name": "COMMON", "color": Color("8fd3ff")},
	{"name": "RARE", "color": Color("4fd36a")},
	{"name": "EPIC", "color": Color("c25bff")},
	{"name": "MYTHIC", "color": Color("ff4d5e")},
	{"name": "LEGENDARY", "color": Color("ffd23a")},
]
## Chance weights per drop tier for COMMON..LEGENDARY.
const DROP_WEIGHTS := [
	[50, 28, 14, 6, 2],
	[0, 45, 32, 16, 7],
	[0, 0, 45, 35, 20],
]

static func roll_drop(tier: int, rng: RandomNumberGenerator, owned_skins: Array) -> Dictionary:
	var w: Array = DROP_WEIGHTS[clampi(tier, 0, 2)]
	var total := 0
	for x in w:
		total += int(x)
	var pick := rng.randi_range(1, total)
	var rarity := 0
	for i in w.size():
		pick -= int(w[i])
		if pick <= 0:
			rarity = i
			break
	var prize := {}
	match rarity:
		0: prize = [{"type": "credits", "amount": 40}, {"type": "tokens", "amount": 40}][rng.randi() % 2]
		1: prize = [{"type": "credits", "amount": 90}, {"type": "tokens", "amount": 90}, {"type": "gems", "amount": 3}][rng.randi() % 3]
		2: prize = [{"type": "credits", "amount": 200}, {"type": "gems", "amount": 8}][rng.randi() % 2]
		3: prize = [{"type": "credits", "amount": 450}, {"type": "gems", "amount": 20}][rng.randi() % 2]
		4:
			var free_skins: Array = []
			for id in Config.BRAWLER_ORDER:
				for sk in skins_for(id):
					if not ("%s:%s" % [id, sk]) in owned_skins:
						free_skins.append({"type": "skin", "brawler": id, "skin": sk})
			prize = free_skins[rng.randi() % free_skins.size()] if not free_skins.is_empty() else {"type": "gems", "amount": 60}
	prize["rarity"] = rarity
	return prize

# ------------------------------------------------------------------ Shop
## One-time starter bundle (in-game currency only).
const STARTER_PACK := {"id": "starter_pack", "title": "STARTER PACK",
	"reward": {"type": "bundle", "items": [{"type": "gems", "amount": 30}, {"type": "credits", "amount": 600}, {"type": "drop", "tier": 2}]},
	"currency": "credits", "cost": 349, "tag": "4x VALUE"}

const DROP_PRICES := [{"currency": "credits", "cost": 120}, {"currency": "gems", "cost": 12}, {"currency": "gems", "cost": 35}]
const SKIN_PRICE := {"gold": 79, "shadow": 49} # gems
const GEM_TO_CREDITS := [
	{"id": "cr_s", "credits": 250, "gems": 20},
	{"id": "cr_m", "credits": 700, "gems": 50},
	{"id": "cr_l", "credits": 1600, "gems": 100},
]

## Today's rotating offers (same for the whole day). Every offer has an id, an
## item reward, a currency and a cost (cost 0 = free gift).
static func daily_offers(day_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day_key)
	var offers: Array = [{"id": "daily_gift", "title": "DAILY GIFT", "reward": [{"type": "drop", "tier": 0}, {"type": "credits", "amount": 60}, {"type": "gems", "amount": 3}][rng.randi() % 3], "currency": "free", "cost": 0}]
	offers.append({"id": "deal_drop", "title": "SUPER DEAL", "reward": {"type": "drop", "tier": 1}, "currency": "credits", "cost": 220 + rng.randi_range(0, 4) * 20, "tag": "-30%"})
	offers.append({"id": "deal_tokens", "title": "PASS BOOST", "reward": {"type": "tokens", "amount": 200}, "currency": "credits", "cost": 150})
	return offers

# ------------------------------------------------------------------ skin rotation
## The shop sells only 3 skins at a time; the set changes every 2 hours.
const SKIN_ROTATION_SECS := 7200
const SKINS_PER_ROTATION := 3

static func rotation_slot() -> int:
	return int(Time.get_unix_time_from_system()) / SKIN_ROTATION_SECS

static func rotation_time_left() -> String:
	var left := SKIN_ROTATION_SECS - int(Time.get_unix_time_from_system()) % SKIN_ROTATION_SECS
	return "%dh %dm" % [left / 3600, (left % 3600) / 60]

## This rotation's skins as shop offers. The first one is featured at 30% off.
static func skin_rotation() -> Array:
	var pool: Array = []
	for id in Config.BRAWLER_ORDER:
		for sk in skins_for(id):
			pool.append([id, sk])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("skins%d" % rotation_slot())
	# shuffle with the seeded rng so every player sees the same set for 2 hours
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for k in mini(SKINS_PER_ROTATION, pool.size()):
		var id: String = pool[k][0]
		var sk: String = pool[k][1]
		var price := skin_price(sk)
		var o := {"id": "skin_%s_%s" % [id, sk], "title": Config.BRAWLERS[id].name, "reward": {"type": "skin", "brawler": id, "skin": sk},
			"currency": "gems", "cost": price, "repeat": true}
		if k == 0:
			o.cost = int(price * 0.7)
			o["old_cost"] = price
			o["tag"] = "-30%"
			o["flag"] = "FEATURED"
		out.append(o)
	return out


# ------------------------------------------------------------------ CHAMPS (competitive)
## Qualifier: reach CHAMPS_Q_WINS wins before CHAMPS_Q_LOSSES losses.
## Finals: CHAMPS_F_MATCHES matches; final win count decides the Champs rank.
const CHAMPS_Q_WINS := 5
const CHAMPS_Q_LOSSES := 3
const CHAMPS_F_MATCHES := 15
const CHAMPS_MODES := ["duel"]
## min wins -> rank and rewards (best first)
const CHAMPS_TIERS := [
	{"wins": 14, "rank": "RANK I", "color": Color("ffd23a"), "rewards": [{"type": "champs_tokens", "amount": 120}, {"type": "gems", "amount": 60}, {"type": "credits", "amount": 1500}, {"type": "drop", "tier": 2}, {"type": "drop", "tier": 2}]},
	{"wins": 12, "rank": "RANK II", "color": Color("ff9d2e"), "rewards": [{"type": "champs_tokens", "amount": 90}, {"type": "gems", "amount": 40}, {"type": "credits", "amount": 1100}, {"type": "drop", "tier": 2}]},
	{"wins": 10, "rank": "RANK III", "color": Color("c25bff"), "rewards": [{"type": "champs_tokens", "amount": 70}, {"type": "gems", "amount": 30}, {"type": "credits", "amount": 800}, {"type": "drop", "tier": 1}]},
	{"wins": 8, "rank": "RANK IV", "color": Color("4fe3d0"), "rewards": [{"type": "champs_tokens", "amount": 55}, {"type": "gems", "amount": 20}, {"type": "credits", "amount": 600}, {"type": "drop", "tier": 1}]},
	{"wins": 7, "rank": "RANK V", "color": Color("3ea2ff"), "rewards": [{"type": "champs_tokens", "amount": 40}, {"type": "gems", "amount": 15}, {"type": "credits", "amount": 450}]},
	{"wins": 6, "rank": "RANK VI", "color": Color("4fd36a"), "rewards": [{"type": "champs_tokens", "amount": 30}, {"type": "gems", "amount": 10}, {"type": "credits", "amount": 350}]},
	{"wins": 5, "rank": "RANK VII", "color": Color("c9d0de"), "rewards": [{"type": "champs_tokens", "amount": 22}, {"type": "credits", "amount": 300}, {"type": "drop", "tier": 0}]},
	{"wins": 4, "rank": "RANK VIII", "color": Color("d98a4a"), "rewards": [{"type": "champs_tokens", "amount": 15}, {"type": "credits", "amount": 220}]},
	{"wins": 2, "rank": "RANK IX", "color": Color("8a6a5a"), "rewards": [{"type": "champs_tokens", "amount": 10}, {"type": "credits", "amount": 150}]},
	{"wins": 0, "rank": "RANK X", "color": Color("6b5f86"), "rewards": [{"type": "champs_tokens", "amount": 5}, {"type": "credits", "amount": 80}]},
]

## Champs Tokens per match (qualifier / finals, win / loss).
const CHAMPS_TOKEN_MATCH := {"qualifier": [3, 1], "finals": [6, 2]}
## Spend Champs Tokens here (Champs screen).
const CHAMPS_STORE := [
	{"id": "mega", "name": "MEGA DROP", "cost": 60, "reward": {"type": "drop", "tier": 2}},
	{"id": "gems", "name": "30 GEMS", "cost": 45, "reward": {"type": "gems", "amount": 30}},
	{"id": "coins", "name": "800 COINS", "cost": 30, "reward": {"type": "credits", "amount": 800}},
	{"id": "pass", "name": "150 PASS TOKENS", "cost": 25, "reward": {"type": "tokens", "amount": 150}},
	{"id": "elite", "name": "TITLE: CHAMPS ELITE", "cost": 150, "once": true, "reward": {"type": "title", "id": "elite"}},
]

static func champs_tier(wins: int) -> Dictionary:
	for t in CHAMPS_TIERS:
		if wins >= int(t.wins):
			return t
	return CHAMPS_TIERS[CHAMPS_TIERS.size() - 1]


# ------------------------------------------------------------------ brawler mastery
const MASTERY_POINTS := [0, 100, 250, 500, 900, 1400, 2100, 3000, 4200, 6000]
const MASTERY_NAMES := ["UNRANKED", "BRONZE I", "BRONZE II", "BRONZE III", "SILVER I", "SILVER II", "SILVER III", "GOLD I", "GOLD II", "GOLD III"]
const MASTERY_COLORS := [Color("6b5f86"), Color("d98a4a"), Color("d98a4a"), Color("d98a4a"), Color("c9d0de"), Color("c9d0de"), Color("c9d0de"), Color("ffd23a"), Color("ffd23a"), Color("ffd23a")]

static func mastery_level(points: int) -> int:
	var lv := 0
	for i in MASTERY_POINTS.size():
		if points >= int(MASTERY_POINTS[i]):
			lv = i
	return lv

## Points earned for one match.
static func mastery_gain(result: String, kos: int, mvp: bool) -> int:
	return int({"win": 30, "loss": 10, "draw": 15}.get(result, 10)) + mini(kos, 10) * 5 + (10 if mvp else 0)

## Reward for reaching a mastery level (level 9 also gives a title).
static func mastery_reward(level: int) -> Dictionary:
	if level >= 9:
		return {"type": "gems", "amount": 30}
	if level % 3 == 0:
		return {"type": "gems", "amount": 5 + level}
	return {"type": "credits", "amount": 40 * level}

# ------------------------------------------------------------------ map rotation
## Each mode shows one active map; the map changes every 3 hours.
const MAP_ROTATION_SECS := 10800

static func _map_slot(mode_id: String) -> int:
	return int(Time.get_unix_time_from_system()) / MAP_ROTATION_SECS + (abs(hash(mode_id)) % 7)

static func active_map(mode_id: String) -> String:
	var maps: Array = Config.MODES[mode_id].maps
	return maps[_map_slot(mode_id) % maps.size()]

static func next_map(mode_id: String) -> String:
	var maps: Array = Config.MODES[mode_id].maps
	return maps[(_map_slot(mode_id) + 1) % maps.size()]

static func map_time_left() -> String:
	var left := MAP_ROTATION_SECS - int(Time.get_unix_time_from_system()) % MAP_ROTATION_SECS
	return "%dh %dm" % [left / 3600, (left % 3600) / 60]

# ------------------------------------------------------------------ profile titles
## Every title: id -> [label, how to unlock]. Unlock checks live in Save.titles_unlocked().
static func title_list() -> Array:
	var out: Array = [
		{"id": "rookie", "name": "ROOKIE", "how": "Everyone starts here"},
		{"id": "brawler", "name": "SEASONED BRAWLER", "how": "Reach account level 5"},
		{"id": "hunter", "name": "TROPHY HUNTER", "how": "Reach 500 total trophies"},
		{"id": "collector", "name": "COLLECTOR", "how": "Unlock 10 brawlers"},
		{"id": "qualifier", "name": "CHAMPS QUALIFIER", "how": "Finish a Champs Finals run"},
		{"id": "champ1", "name": "CHAMPS LEGEND", "how": "Finish Champs at RANK I"},
		{"id": "elite", "name": "CHAMPS ELITE", "how": "Buy it in the Champs Store"},
		{"id": "ranked_diamond", "name": "DIAMOND VETERAN", "how": "Finish a Ranked season in Diamond or higher"},
		{"id": "ranked_legend", "name": "RANKED LEGEND", "how": "Finish a Ranked season in Legendary"},
	]
	for id in Config.BRAWLER_ORDER:
		out.append({"id": "master_" + id, "name": Config.BRAWLERS[id].name + " MASTER", "how": "Reach GOLD III mastery with " + Config.BRAWLERS[id].name})
	return out

# ------------------------------------------------------------------ RANKED
## Seven ranks, each split into I, II and III (I lowest). 100 rank points per division.
const RANKED_NAMES := ["BRONZE", "SILVER", "GOLD", "PLATINUM", "DIAMOND", "NETHERITE", "LEGENDARY"]
const RANKED_IDS := ["bronze", "silver", "gold", "platinum", "diamond", "netherite", "legendary"]
const RANKED_COLORS := [Color("e07a2a"), Color("aeb8d8"), Color("ffc21a"), Color("4fd8f0"), Color("3a9cff"), Color("a44cff"), Color("ff7a1a")]
const RANKED_DIVS := ["I", "II", "III"]
## Bronze I needs 150 RP; every division after that needs 50 RP more than the last.
const RANKED_DIV_BASE := 150
const RANKED_DIV_GROW := 50

static func ranked_div_need(step: int) -> int:
	return RANKED_DIV_BASE + RANKED_DIV_GROW * step

## Total RP at which division `step` starts.
static func ranked_step_start(step: int) -> int:
	return RANKED_DIV_BASE * step + RANKED_DIV_GROW * step * (step - 1) / 2
const RANKED_MODES := ["gem_grab", "knockout", "showdown", "duel"]
## Harder climb: wins are worth less and losses cost more the higher you go.
static func ranked_win_pts(rank: int) -> int:
	return maxi(10, 22 - rank * 2)

static func ranked_loss_pts(rank: int) -> int:
	return 15 + rank * 2

const RANKED_STREAK_STEP := 3
const RANKED_STREAK_MAX := 9
## Paid automatically every 6 hours, based on your rank at that moment.
const RANKED_PAYOUT_SECS := 21600
const RANKED_PAYOUTS := [
	[{"type": "credits", "amount": 100}],
	[{"type": "credits", "amount": 175}],
	[{"type": "credits", "amount": 250}, {"type": "gems", "amount": 3}],
	[{"type": "credits", "amount": 350}, {"type": "gems", "amount": 6}],
	[{"type": "credits", "amount": 425}, {"type": "gems", "amount": 10}],
	[{"type": "credits", "amount": 500}, {"type": "gems", "amount": 16}],
	[{"type": "credits", "amount": 750}, {"type": "gems", "amount": 25}],
]
## First time reaching each rank (index = rank).
const RANKED_REWARDS := [
	[],
	[{"type": "credits", "amount": 300}],
	[{"type": "gems", "amount": 30}],
	[{"type": "credits", "amount": 600}, {"type": "drop", "tier": 1}],
	[{"type": "gems", "amount": 60}, {"type": "drop", "tier": 1}],
	[{"type": "gems", "amount": 100}, {"type": "drop", "tier": 2}],
	[{"type": "gems", "amount": 200}, {"type": "drop", "tier": 2}],
]

static func ranked_max_points() -> int:
	return ranked_step_start(RANKED_NAMES.size() * 3 - 1)

## {rank, div, into, need, step, name, color, id, top}; Legendary III keeps counting past its bar.
static func ranked_info(points: int) -> Dictionary:
	var p := maxi(0, points)
	var last := RANKED_NAMES.size() * 3 - 1
	var step := 0
	while step < last and p >= ranked_step_start(step + 1):
		step += 1
	var rank := step / 3
	var div := step % 3
	var into := p - ranked_step_start(step)
	return {"rank": rank, "div": div, "into": into, "need": ranked_div_need(step), "step": step,
		"name": "%s %s" % [RANKED_NAMES[rank], RANKED_DIVS[div]],
		"color": RANKED_COLORS[rank], "id": RANKED_IDS[rank],
		"top": step == last}

## Bot strength follows your rank.
const RANKED_MODE_ICONS := {"gem_grab": "mode_gem", "knockout": "mode_knockout", "showdown": "mode_showdown", "duel": "ko"}

static func ranked_difficulty(points: int) -> String:
	var r: int = ranked_info(points).rank
	if r == 0: return "easy"
	if r <= 2: return "normal"
	if r <= 4: return "hard"
	return "extreme"


# ------------------------------------------------------------------ RANKED SEASONS
## Seasons last one week and reset every Thursday 00:00 Dubai time (Wed 20:00 UTC),
## counted from a fixed Thursday so every device agrees.
const RANKED_SEASON_EPOCH := 1793822400  # Thu 2026-11-05 00:00 UTC+4
const RANKED_SEASON_SECS := 7 * 86400
## End-of-season rewards by the best rank reached that season.
const RANKED_SEASON_REWARDS := [
	[{"type": "credits", "amount": 300}],
	[{"type": "credits", "amount": 600}, {"type": "gems", "amount": 10}],
	[{"type": "credits", "amount": 1000}, {"type": "gems", "amount": 25}, {"type": "drop", "tier": 0}],
	[{"type": "credits", "amount": 1500}, {"type": "gems", "amount": 40}, {"type": "drop", "tier": 1}],
	[{"type": "credits", "amount": 2000}, {"type": "gems", "amount": 60}, {"type": "drop", "tier": 1}],
	[{"type": "credits", "amount": 3000}, {"type": "gems", "amount": 100}, {"type": "drop", "tier": 2}],
	[{"type": "credits", "amount": 5000}, {"type": "gems", "amount": 150}, {"type": "drop", "tier": 2}],
]
## How many ranks you drop when a new season starts.
const RANKED_SEASON_DROP := 2

static var season_debug_offset := 0  # testing only

static func ranked_season_now() -> int:
	return int((int(Time.get_unix_time_from_system()) - RANKED_SEASON_EPOCH) / RANKED_SEASON_SECS) + 1 + season_debug_offset

static func ranked_season_left() -> String:
	var now := int(Time.get_unix_time_from_system())
	var end := RANKED_SEASON_EPOCH + ranked_season_now() * RANKED_SEASON_SECS
	var left := maxi(0, end - now)
	return "%dd %dh" % [left / 86400, (left % 86400) / 3600]

## Points you restart at after a season where you finished at `points`.
static func ranked_reset_points(points: int) -> int:
	var rank: int = int(ranked_info(points).rank)
	return ranked_step_start(maxi(0, rank - RANKED_SEASON_DROP) * 3)
