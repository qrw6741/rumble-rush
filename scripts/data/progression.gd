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

## Reward for a tier on a track ("free" or "gold"). Tier is 1-based.
static func pass_reward(tier: int, track: String) -> Dictionary:
	if track == "gold":
		var skin_tiers := {6: "bront", 12: "vex", 18: "nova", 24: "mira", 30: "sprig"}
		if skin_tiers.has(tier):
			return {"type": "skin", "brawler": skin_tiers[tier], "skin": "gold"}
		if tier % 5 == 0:
			return {"type": "credits", "amount": 150}
		return {"type": "credits", "amount": 40 + tier * 2}
	# free track
	if tier % 10 == 0:
		return {"type": "skin", "brawler": ["nova", "bront", "mira"][tier / 10 - 1], "skin": "shadow"}
	if tier % 3 == 0:
		return {"type": "xp", "amount": 60}
	return {"type": "credits", "amount": 20 + tier}

# ------------------------------------------------------------------ Trophy Road
const ROAD := [
	{"trophies": 10, "reward": {"type": "credits", "amount": 50}},
	{"trophies": 25, "reward": {"type": "tokens", "amount": 100}},
	{"trophies": 50, "reward": {"type": "credits", "amount": 100}},
	{"trophies": 80, "reward": {"type": "skin", "brawler": "sprig", "skin": "shadow"}},
	{"trophies": 120, "reward": {"type": "credits", "amount": 150}},
	{"trophies": 160, "reward": {"type": "tokens", "amount": 200}},
	{"trophies": 200, "reward": {"type": "credits", "amount": 200}},
	{"trophies": 250, "reward": {"type": "skin", "brawler": "vex", "skin": "shadow"}},
	{"trophies": 300, "reward": {"type": "credits", "amount": 250}},
	{"trophies": 375, "reward": {"type": "tokens", "amount": 300}},
	{"trophies": 450, "reward": {"type": "credits", "amount": 300}},
	{"trophies": 550, "reward": {"type": "skin", "brawler": "bront", "skin": "gold"}},
	{"trophies": 650, "reward": {"type": "credits", "amount": 400}},
	{"trophies": 800, "reward": {"type": "tokens", "amount": 500}},
	{"trophies": 1000, "reward": {"type": "credits", "amount": 600}},
]

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

## Badge colours by rank band: wood, bronze, silver, gold, crystal, master.
static func rank_color(rank: int) -> Color:
	if rank >= 30:
		return Color("ff4d5e")
	if rank >= 25:
		return Color("4fe3d0")
	if rank >= 20:
		return Color("c25bff")
	if rank >= 15:
		return Color("ffc93a")
	if rank >= 10:
		return Color("c9d0de")
	if rank >= 5:
		return Color("d98a4a")
	return Color("8a6a5a")

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
	return ""
