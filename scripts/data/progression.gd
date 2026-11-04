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
	21: {"brawler": "mira", "kos": 20},
	27: {"brawler": "bront", "kos": 25},
}

static func challenge_text(c: Dictionary) -> String:
	return "Defeat %d enemies with %s" % [int(c.kos), Config.BRAWLERS[c.brawler].name]

## Reward for a tier on a track ("free" or "gold"). Tier is 1-based.
static func pass_reward(tier: int, track: String) -> Dictionary:
	if track == "gold" and PASS_CHALLENGES.has(tier):
		return {"type": "credits", "amount": 350, "challenge": PASS_CHALLENGES[tier]}
	if track == "gold":
		var skin_tiers := {6: "bront", 12: "vex", 18: "nova", 24: "mira", 30: "sprig"}
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
	if tier % 10 == 0:
		return {"type": "skin", "brawler": ["nova", "bront", "mira"][tier / 10 - 1], "skin": "shadow"}
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
	var ids: Array = Config.BRAWLER_ORDER
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
	{"trophies": 120, "reward": {"type": "credits", "amount": 150}},
	{"trophies": 160, "reward": {"type": "drop", "tier": 2}},
	{"trophies": 200, "reward": {"type": "credits", "amount": 200}},
	{"trophies": 250, "reward": {"type": "skin", "brawler": "vex", "skin": "shadow"}},
	{"trophies": 300, "reward": {"type": "credits", "amount": 250}},
	{"trophies": 375, "reward": {"type": "gems", "amount": 40}},
	{"trophies": 450, "reward": {"type": "credits", "amount": 300}},
	{"trophies": 550, "reward": {"type": "skin", "brawler": "bront", "skin": "gold"}},
	{"trophies": 650, "reward": {"type": "credits", "amount": 400}},
	{"trophies": 800, "reward": {"type": "drop", "tier": 2}},
	{"trophies": 1000, "reward": {"type": "credits", "amount": 600}},
]

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

static func palette(brawler_id: String, skin: String) -> Dictionary:
	var d: Dictionary = Config.BRAWLERS[brawler_id].duplicate()
	if SKINS.has(skin):
		var s: Dictionary = SKINS[skin]
		d.primary = s.primary
		d.secondary = s.secondary
		d.accent = s.accent
	return d

static func reward_text(r: Dictionary) -> String:
	match r.get("type", ""):
		"credits": return "%d CREDITS" % r.amount
		"tokens": return "%d PASS TOKENS" % r.amount
		"xp": return "%d XP" % r.amount
		"skin": return "%s %s" % [SKINS[r.skin].name, Config.BRAWLERS[r.brawler].name]
		"gems": return "%d GEMS" % r.amount
		"bundle": return "BUNDLE"
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
				for sk in SKINS.keys():
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
	var ids: Array = Config.BRAWLER_ORDER.duplicate()
	var sk_id: String = ids[rng.randi() % ids.size()]
	var sk: String = ["gold", "shadow"][rng.randi() % 2]
	offers.append({"id": "deal_skin_%s_%s" % [sk_id, sk], "title": "FEATURED SKIN", "reward": {"type": "skin", "brawler": sk_id, "skin": sk}, "currency": "gems", "cost": int(SKIN_PRICE[sk] * 0.7), "tag": "-30%"})
	return offers
