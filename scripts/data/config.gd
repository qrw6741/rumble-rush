extends Node
## Central balance + content configuration. Every gameplay number lives here so
## the game can be tuned without touching the systems code.

const TILE := 48.0
const GAME_TITLE := "RUMBLE RUSH"

const TEAM_BLUE := 0
const TEAM_RED := 1
const TEAM_COLORS := [Color("3ea2ff"), Color("ff4d5e")]
const TEAM_DARK := [Color("123a78"), Color("7a1525")]
const TEAM_NAMES := ["BLUE", "RED"]

# ------------------------------------------------------------------ combat rules
const REGEN_DELAY := 3.0            # seconds without damage/attacking before regen
const REGEN_PERCENT_PER_SEC := 0.13 # of max health
const RESPAWN_TIME := 3.0
const SPAWN_PROTECTION := 2.0
const SUPER_CHARGE_ON_DAMAGE_TAKEN := 0.0001 # super fraction per point of damage taken
const BUSH_REVEAL_DISTANCE := 1.9 * TILE
const ATTACK_REVEAL_TIME := 1.0
const UPGRADE_BONUS_PER_LEVEL := 0.06
const MAX_LEVEL := 7
const UPGRADE_COSTS := [0, 60, 120, 200, 300, 420, 560] # cost to go from level i to i+1

# ------------------------------------------------------------------ modes
const MODES := {
	"gem_grab": {
		"name": "GEM RUSH",
		"short": "Collect 10 crystals and hold them for 15 seconds.",
		"rules": "Crystals spawn from the central mine. If your team carries 10 or more AND more than the enemy, a 15 s countdown starts. Lose crystals and it stops. KO'd brawlers drop everything they carry. If time runs out, the team carrying more wins.",
		"time_limit": 150.0,
		"color": Color("b25bff"),
		"maps": ["crystal_canyon", "neon_district", "sunset_ruins", "night_harbor"],
		"icon": "mode_gem",
	},
	"showdown": {
		"name": "SHOWDOWN",
		"short": "Solo survival: 10 brawlers, last one standing wins.",
		"rules": "Every brawler for themselves. Smash power boxes to grab POWER CELLS (+health and +damage). Poison clouds close in from the edges, so keep moving toward the centre. No respawns: survive to the end! Top 4 gain trophies.",
		"time_limit": 240.0,
		"color": Color("43c463"),
		"maps": ["bone_desert", "toxic_marsh"],
		"icon": "mode_showdown",
	},
	"knockout": {
		"name": "KNOCKOUT RUSH",
		"short": "First team to 10 KOs wins.",
		"rules": "Every KO scores a point. Respawns are on. First to 10 wins. If time runs out the leading team wins; a tie goes to a 30 s sudden-death overtime where the next KO wins.",
		"time_limit": 150.0,
		"target": 10,
		"color": Color("ff7a2b"),
		"maps": ["neon_district", "crystal_canyon", "frost_yard", "night_harbor"],
		"icon": "mode_knockout",
	},
	"duel": {
		"name": "DUEL RUSH",
		"short": "1v1, best of 3 rounds.",
		"rules": "One on one. The first knockout wins the round, and the first to 2 rounds wins the duel. There are no respawns inside a round. After 60 seconds the arena starts closing in, so nobody can hide for long.",
		"time_limit": 240.0,
		"target": 2,
		"color": Color("e8262c"),
		"maps": ["duel_den", "twin_bridges"],
		"icon": "mode_knockout",
		"team_size": 1,
	},
}

const DIFFICULTY := {
	"easy":   {"name": "EASY",   "reaction": 0.55, "aim_error": 0.30, "dodge": 0.10, "lead": 0.0, "super_smart": 0.3, "think": 0.45},
	"normal": {"name": "MEDIUM", "reaction": 0.35, "aim_error": 0.17, "dodge": 0.35, "lead": 0.5, "super_smart": 0.7, "think": 0.30},
	"hard":   {"name": "HARD",   "reaction": 0.22, "aim_error": 0.09, "dodge": 0.60, "lead": 0.8, "super_smart": 0.9, "think": 0.22},
	"expert": {"name": "EXTREME", "reaction": 0.10, "aim_error": 0.03, "dodge": 0.90, "lead": 1.0, "super_smart": 1.0, "think": 0.11},
	"extreme": {"name": "EXTREME", "reaction": 0.10, "aim_error": 0.03, "dodge": 0.90, "lead": 1.0, "super_smart": 1.0, "think": 0.11},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard", "extreme"]

## Bots scale with the rank of the brawler you play:
## rank 1-5 easy, 6-10 medium, 11-25 hard, 26+ extreme.
static func difficulty_for_rank(rank: int) -> String:
	if rank <= 5:
		return "easy"
	if rank <= 10:
		return "normal"
	if rank <= 25:
		return "hard"
	return "extreme"

## The difficulty actually used for a match with this brawler ("auto" = by rank).
static func match_difficulty(brawler_id: String) -> String:
	var d: String = Save.setting("difficulty")
	if d == "auto" or not DIFFICULTY.has(d):
		return difficulty_for_rank(Progression.rank_for(Save.brawler_trophies(brawler_id)))
	return d

# ------------------------------------------------------------------ bot player names
const _NAME_A := ["Shadow", "Blaze", "Frost", "Nova", "Viper", "Pixel", "Turbo", "Lucky", "Ghost", "Storm",
	"Crimson", "Rocket", "Neon", "Ace", "Cosmic", "Savage", "Silent", "Golden", "Hyper", "Lil",
	"Mega", "Dark", "Iron", "Wild", "Sneaky", "Royal", "Toxic", "Mighty", "Fuzzy", "Sonic"]
const _NAME_B := ["Wolf", "King", "Ninja", "Hunter", "Sniper", "Tiger", "Dragon", "Fox", "Panda", "Falcon",
	"Rider", "Legend", "Slayer", "Gamer", "Boss", "Hero", "Knight", "Shark", "Phoenix", "Bandit",
	"Wizard", "Rex", "Blade", "Spark", "Monk", "Raven", "Cobra", "Bear", "Storm", "Dash"]
const _NAME_SOLO := ["Zayed", "Omar", "Layla", "Sara", "Mo", "Alex", "Sami", "Noah", "Maya", "Rami",
	"Jay", "Kai", "Leo", "Nora", "Yousef", "Hamad", "Rashid", "Mira", "Lina", "Adam", "Ziggy", "Bubbles",
	"Potato", "Noodle", "Pickle", "Waffle", "Mango", "Biscuit"]

## A believable random player name, e.g. "ShadowWolf27", "xX_Kai_Xx", "lil.mango".
static func random_player_name(rng: RandomNumberGenerator) -> String:
	var a: String = _NAME_A[rng.randi() % _NAME_A.size()]
	var b: String = _NAME_B[rng.randi() % _NAME_B.size()]
	var solo: String = _NAME_SOLO[rng.randi() % _NAME_SOLO.size()]
	var num := str(rng.randi_range(1, 999))
	var yr := str(rng.randi_range(2005, 2014))
	match rng.randi() % 12:
		0: return a + b
		1: return a + b + num
		2: return "xX_%s_Xx" % solo
		3: return solo + num
		4: return "%s.%s" % [a.to_lower(), b.to_lower()]
		5: return solo.to_upper()
		6: return "%s_%s" % [solo, yr]
		7: return "The%s" % b
		8: return "%s%s" % [solo, b]
		9: return "%s %s" % [a, b]
		10: return "ii%sii" % solo.to_lower()
	return "%s%s" % [b, yr.substr(2)]

static func random_player_names(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out: Array = []
	while out.size() < count:
		var n := random_player_name(rng)
		if n.length() <= 16 and not n in out:
			out.append(n)
	return out

# ------------------------------------------------------------------ brawlers
# attack.kind: melee_cone | twin_slash | rifle | orb | lob
# super.kind : leap_slam | phantom_dash | lance_beam | sanctuary | bramble
# gadget.kind: iron_skin | shadow_step | overclock | mend | snare
const BRAWLERS := {
	"bront": {
		"name": "BRONT", "role": "TANK", "rarity": "RARE",
		"tagline": "A walking landslide with a hammer to match.",
		"bio": "Bront used to build bridges. Now he breaks everything that isn't one. Loud, loyal, and allergic to retreating.",
		"health": 5300, "speed": 165.0, "radius": 25.0,
		"ammo": 3, "reload": 1.75,
		"primary": Color("e9893a"), "secondary": Color("7a4a2a"), "accent": Color("ffd166"), "skin": Color("c98b62"),
		"attack": {"kind": "melee_cone", "name": "Hammer Swing", "desc": "A wide, crushing swing that hits everyone in front of him.",
			"damage": 1000, "range": 2.1, "arc": 70.0, "windup": 0.10, "super_per_hit": 0.2, "sfx": "shoot_hammer"},
		"super": {"kind": "leap_slam", "name": "Quake Leap", "desc": "Leaps over walls and slams down, stunning and damaging everyone nearby.",
			"damage": 1500, "range": 6.5, "radius": 2.2, "stun": 0.6, "air_time": 0.7},
		"gadget": {"kind": "iron_skin", "name": "Iron Skin", "desc": "Takes 50% less damage for 3 seconds.", "cooldown": 14.0, "duration": 3.0, "reduction": 0.5},
	},
	"vex": {
		"name": "VEX", "role": "ASSASSIN", "rarity": "EPIC",
		"tagline": "Gone before you see the blades.",
		"bio": "A rooftop runner from the neon slums. Vex never fights fair and never fights long.",
		"health": 4100, "speed": 205.0, "radius": 22.0,
		"ammo": 3, "reload": 1.05,
		"primary": Color("8e4dff"), "secondary": Color("2b1a4d"), "accent": Color("49f2d2"), "skin": Color("e8b48f"),
		"attack": {"kind": "twin_slash", "name": "Twin Slash", "desc": "Throws two short-range energy crescents in quick succession.",
			"damage": 640, "range": 3.7, "speed": 640.0, "spread": 7.0, "super_per_hit": 0.13, "sfx": "shoot_blade"},
		"super": {"kind": "phantom_dash", "name": "Phantom Rush", "desc": "Dashes straight through enemies, cutting everyone in the path. Untouchable while dashing.",
			"damage": 1500, "range": 5.5, "duration": 0.3},
		"gadget": {"kind": "shadow_step", "name": "Shadow Step", "desc": "Turns invisible to enemies for 2.5 seconds.", "cooldown": 16.0, "duration": 2.5},
	},
	"nova": {
		"name": "NOVA", "role": "MARKSMAN", "rarity": "RARE",
		"tagline": "One shot. Long distance. No mercy.",
		"bio": "Nova calibrated her arc-rifle out of salvaged satellite parts. She hits harder the farther away you are.",
		"health": 3200, "speed": 170.0, "radius": 21.0,
		"ammo": 3, "reload": 1.6,
		"primary": Color("20c4e8"), "secondary": Color("1c2c4a"), "accent": Color("f5f7ff"), "skin": Color("8d5a3b"),
		"attack": {"kind": "rifle", "name": "Arc Rifle", "desc": "A fast, long-range bolt. Deals up to 50% bonus damage at max range.",
			"damage": 1080, "max_bonus": 0.5, "range": 9.5, "speed": 920.0, "super_per_hit": 0.34, "sfx": "shoot_rifle"},
		"super": {"kind": "lance_beam", "name": "Lance Beam", "desc": "Charges, then fires a huge beam that pierces every enemy in a line.",
			"damage": 2200, "range": 13.0, "width": 0.9, "charge": 0.35},
		"gadget": {"kind": "overclock", "name": "Overclock", "desc": "Instantly refills all ammo.", "cooldown": 15.0},
	},
	"sprig": {
		"name": "SPRIG", "role": "CONTROLLER", "rarity": "SUPER RARE",
		"tagline": "Plants trouble. Watches it grow.",
		"bio": "A gremlin gardener with a backpack full of explosive seeds. Walls are merely suggestions.",
		"health": 3500, "speed": 170.0, "radius": 21.0,
		"ammo": 3, "reload": 1.7,
		"primary": Color("5fd35a"), "secondary": Color("2f4a1f"), "accent": Color("ffb84d"), "skin": Color("a6e07a"),
		"attack": {"kind": "lob", "name": "Seed Bomb", "desc": "Lobs a seed over walls that bursts on landing.",
			"damage": 1120, "range": 7.0, "radius": 1.4, "flight": 0.78, "super_per_hit": 0.3, "sfx": "shoot_lob"},
		"super": {"kind": "bramble", "name": "Bramble Patch", "desc": "Grows a thorn field that slows and shreds enemies for 4 seconds.",
			"damage": 300, "range": 7.5, "radius": 2.5, "duration": 4.0, "tick": 0.5, "slow": 0.45, "flight": 0.72},
		"gadget": {"kind": "snare", "name": "Vine Snare", "desc": "Plants a hidden trap that roots the first enemy to step on it.", "cooldown": 12.0, "root": 1.6, "life": 12.0},
	},
	"rio": {
		"name": "RIO", "role": "SKIRMISHER", "rarity": "SUPER RARE",
		"tagline": "Tags the whole map. Tags you too.",
		"bio": "Rio skates the rooftops at night with a backpack full of spray cans. Every wall is a canvas, every rival is a target.",
		"health": 3800, "speed": 198.0, "radius": 21.0,
		"ammo": 3, "reload": 1.15,
		"primary": Color("ffcf3a"), "secondary": Color("1e7f8c"), "accent": Color("ff4fa3"), "skin": Color("b98563"),
		"paint": true,
		"attack": {"kind": "twin_slash", "name": "Paint Blast", "desc": "Fires two quick blobs of paint at short-medium range.",
			"damage": 700, "range": 4.6, "speed": 620.0, "spread": 9.0, "super_per_hit": 0.14, "sfx": "shoot_blade"},
		"super": {"kind": "phantom_dash", "name": "Grind Rush", "desc": "Kicks off on the skateboard and grinds straight through enemies, splashing everyone in the path. Can't be hit while grinding.",
			"damage": 1400, "range": 6.0, "duration": 0.32},
		"gadget": {"kind": "overclock", "name": "Fresh Cans", "desc": "Grabs fresh cans from the backpack: instantly refills all ammo.", "cooldown": 14.0},
	},
	"graves": {
		"name": "GRAVES", "role": "ASSASSIN", "rarity": "EPIC", "unlock": {"currency": "gems", "cost": 89},
		"tagline": "Every match ends. He just helps.",
		"bio": "A quiet reaper in a tattered robe who drifts between the shadows. His scythe never misses a harvest.",
		"health": 4300, "speed": 200.0, "radius": 22.0,
		"ammo": 3, "reload": 1.2,
		"primary": Color("2a2438"), "secondary": Color("15121e"), "accent": Color("7dffb0"), "skin": Color("e8e4d6"),
		"attack": {"kind": "melee_cone", "name": "Scythe Sweep", "desc": "A huge sweeping slash with his scythe that hits everyone in a wide arc.",
			"damage": 1080, "range": 2.6, "arc": 110.0, "windup": 0.12, "super_per_hit": 0.22, "sfx": "shoot_blade"},
		"super": {"kind": "phantom_dash", "name": "Soul Rush", "desc": "Turns to mist and glides through enemies, reaping everyone in his path.",
			"damage": 1500, "range": 6.0, "duration": 0.32},
		"gadget": {"kind": "shadow_step", "name": "Fade", "desc": "Vanishes from enemy sight for 2.5 seconds.", "cooldown": 15.0, "duration": 2.5},
	},
	"cyber": {
		"name": "CYBER NINJA", "role": "ASSASSIN", "rarity": "EPIC", "unlock": {"currency": "gems", "cost": 99},
		"tagline": "You won't see the second blade.",
		"bio": "A silent ninja in glowing armour who strikes from the shadows with twin blades and razor stars.",
		"health": 2800, "speed": 215.0, "radius": 20.0,
		"ammo": 3, "reload": 1.0, "shuriken": true,
		"primary": Color("1c2140"), "secondary": Color("0d0f1e"), "accent": Color("3fd8ff"), "skin": Color("c9c3e6"),
		"attack": {"kind": "twin_slash", "name": "Star Volley", "desc": "Flings two glowing throwing stars that slice through the air.",
			"damage": 780, "range": 6.8, "speed": 1050.0, "spread": 6.0, "super_per_hit": 0.16, "sfx": "shoot_blade"},
		"super": {"kind": "phantom_dash", "name": "Shadow Dash", "desc": "Dashes through enemies as a streak of shadow, cutting everyone in his path.",
			"damage": 1400, "range": 6.5, "duration": 0.26},
		"gadget": {"kind": "shadow_step", "name": "Smoke Bomb", "desc": "Vanishes in a puff of smoke for 2 seconds.", "cooldown": 14.0, "duration": 2.0},
	},
	"king": {
		"name": "SPECTRAL KING", "role": "TANK", "rarity": "LEGENDARY", "unlock": {"currency": "gems", "cost": 179},
		"tagline": "Kneel. Or be made to.",
		"bio": "A ghostly king in gold-trimmed armour, crowned in blue spirit fire. His greatsword has never lost a duel.",
		"health": 4800, "speed": 165.0, "radius": 26.0,
		"ammo": 3, "reload": 1.4,
		"primary": Color("1d2a5a"), "secondary": Color("0e1430"), "accent": Color("4fb8ff"), "skin": Color("d8c48a"),
		"attack": {"kind": "melee_cone", "name": "Royal Cleave", "desc": "A wide sweep of his spectral greatsword that hits everyone in front of him.",
			"damage": 620, "range": 2.6, "arc": 120.0, "windup": 0.1, "super_per_hit": 0.18, "sfx": "shoot_hammer"},
		"super": {"kind": "leap_slam", "name": "Royal Guard", "desc": "Leaps into battle and drives his sword into the ground, stunning every enemy nearby.",
			"damage": 1300, "range": 6.0, "radius": 2.4, "stun": 0.8, "air_time": 0.6},
		"gadget": {"kind": "iron_skin", "name": "Spirit Aegis", "desc": "A spectral shield blocks 50% of damage for 3 seconds.", "cooldown": 14.0, "duration": 3.0, "reduction": 0.5},
	},
	"templar": {
		"name": "VOID TEMPLAR", "role": "CONTROLLER", "rarity": "MYTHIC", "unlock": {"currency": "gems", "cost": 249},
		"tagline": "Order is a cage. I hold the key.",
		"bio": "A guardian of the void who reads from a book of black stars. Where he points, the chaos goes.",
		"health": 3400, "speed": 175.0, "radius": 23.0,
		"ammo": 3, "reload": 1.5,
		"primary": Color("3a1f6a"), "secondary": Color("140a26"), "accent": Color("c060ff"), "skin": Color("e6dcf2"),
		"attack": {"kind": "lob", "name": "Void Sphere", "desc": "Hurls a sphere of void energy over walls that bursts on landing.",
			"damage": 880, "range": 7.0, "radius": 1.5, "flight": 0.7, "super_per_hit": 0.3, "sfx": "shoot_lob"},
		"super": {"kind": "bramble", "name": "Chaos Rift", "desc": "Tears open a rift of void flame that slows and burns enemies for 4 seconds.",
			"damage": 320, "range": 7.5, "radius": 2.7, "duration": 4.0, "tick": 0.5, "slow": 0.5, "flight": 0.7},
		"gadget": {"kind": "snare", "name": "Void Chains", "desc": "Sets a hidden void sigil that chains the first enemy to step on it.", "cooldown": 12.0, "root": 1.8, "life": 12.0},
	},
	"monk": {
		"name": "CELESTIAL MONK", "role": "SUPPORT", "rarity": "LEGENDARY", "unlock": {"currency": "gems", "cost": 179},
		"tagline": "The heavens are on my side.",
		"bio": "A wandering monk who bends the light of the heavens into orbs that mend allies and scatter foes.",
		"health": 3600, "speed": 200.0, "radius": 22.0,
		"ammo": 3, "reload": 1.4,
		"primary": Color("1f2f6e"), "secondary": Color("0d1230"), "accent": Color("5fc4ff"), "skin": Color("e8e8f5"),
		"attack": {"kind": "orb", "name": "Heaven Orb", "desc": "A glowing orb that damages the first enemy it hits, or heals the first ally it touches.",
			"damage": 720, "heal": 760, "range": 7.2, "speed": 560.0, "super_per_hit": 0.26, "sfx": "shoot_heal"},
		"super": {"kind": "sanctuary", "name": "Heavenly Seal", "desc": "Lays down sacred talismans that heal allies and burn enemies for 5 seconds.",
			"heal": 320, "damage": 220, "range": 7.0, "radius": 2.7, "duration": 5.0, "tick": 0.5},
		"gadget": {"kind": "mend", "name": "Blessing", "desc": "Instantly heals himself and nearby allies.", "cooldown": 15.0, "heal": 1000, "radius": 3.2},
	},
	"gunslinger": {
		"name": "DEMON GUNSLINGER", "role": "MARKSMAN", "rarity": "LEGENDARY", "unlock": {"currency": "gems", "cost": 179},
		"tagline": "A deal's a deal.",
		"bio": "A cursed gunslinger with a hand cannon and a debt to settle. His bullets burn with hellfire.",
		"health": 3000, "speed": 205.0, "radius": 21.0,
		"ammo": 3, "reload": 1.35,
		"primary": Color("3a1418"), "secondary": Color("140608"), "accent": Color("ff3b3b"), "skin": Color("d9c8c8"),
		"attack": {"kind": "rifle", "name": "Hellfire Shot", "desc": "A long-range hellfire bullet that hits harder the farther it flies.",
			"damage": 960, "max_bonus": 0.4, "range": 9.5, "speed": 980.0, "super_per_hit": 0.32, "sfx": "shoot_rifle"},
		"super": {"kind": "lance_beam", "name": "Devil's Due", "desc": "Takes aim and fires a cursed round that pierces every enemy in a line.",
			"damage": 2100, "range": 13.0, "width": 0.8, "charge": 0.3},
		"gadget": {"kind": "overclock", "name": "Quick Reload", "desc": "Instantly reloads every shot.", "cooldown": 14.0},
	},
	"dusty": {
		"name": "DUSTY", "role": "SHARPSHOOTER", "rarity": "RARE", "unlock": {"currency": "credits", "cost": 600},
		"tagline": "Fastest draw this side of the arena.",
		"bio": "An old desert drifter with a dusty poncho, a big hat and two trusty revolvers. Talks slow, shoots fast.",
		"health": 3500, "speed": 175.0, "radius": 21.0,
		"ammo": 3, "reload": 1.3, "bullets": true,
		"primary": Color("c97a3a"), "secondary": Color("6b4426"), "accent": Color("e0c27a"), "skin": Color("d9a07a"),
		"attack": {"kind": "twin_slash", "name": "Twin Six-Shooters", "desc": "Fires both revolvers in a quick double shot.",
			"damage": 560, "range": 7.2, "speed": 900.0, "spread": 5.0, "super_per_hit": 0.12, "sfx": "shoot_rifle"},
		"super": {"kind": "lance_beam", "name": "Dead-Eye", "desc": "Takes careful aim, then fires a piercing shot through every enemy in a line.",
			"damage": 2000, "range": 12.0, "width": 0.7, "charge": 0.3},
		"gadget": {"kind": "overclock", "name": "Fan the Hammer", "desc": "Reloads both revolvers instantly.", "cooldown": 14.0},
	},
	"kora": {
		"name": "KORA", "role": "CONTROLLER", "rarity": "SUPER RARE", "unlock": {"currency": "credits", "cost": 900},
		"tagline": "Chill out. Permanently.",
		"bio": "A mountain frost mage who carries winter in a crystal staff. Her blizzards turn any lane into a slow crawl.",
		"health": 3400, "speed": 170.0, "radius": 21.0,
		"ammo": 3, "reload": 1.6,
		"primary": Color("6ad0ff"), "secondary": Color("2a4c8a"), "accent": Color("e6fbff"), "skin": Color("f0d2be"),
		"attack": {"kind": "lob", "name": "Frost Shard", "desc": "Lobs an ice shard over walls that shatters on landing.",
			"damage": 1060, "range": 7.0, "radius": 1.4, "flight": 0.75, "super_per_hit": 0.3, "sfx": "shoot_lob"},
		"super": {"kind": "bramble", "name": "Blizzard", "desc": "Summons a freezing storm that slows and chills enemies for 4 seconds.",
			"damage": 280, "range": 7.5, "radius": 2.6, "duration": 4.0, "tick": 0.5, "slow": 0.5, "flight": 0.7},
		"gadget": {"kind": "snare", "name": "Ice Trap", "desc": "Hides a frost rune that freezes the first enemy who steps on it.", "cooldown": 12.0, "root": 1.6, "life": 12.0},
	},
	"patch": {
		"name": "PATCH", "role": "SUPPORT", "rarity": "SUPER RARE", "unlock": {"currency": "credits", "cost": 900},
		"tagline": "Beep boop. You're fixed.",
		"bio": "A tiny repair robot with one big eye and a wrench arm. It patches up friends and zaps everyone else.",
		"health": 3500, "speed": 172.0, "radius": 21.0,
		"ammo": 3, "reload": 1.4,
		"primary": Color("f2f4f8"), "secondary": Color("3a4766"), "accent": Color("ffb23a"), "skin": Color("8fd0ff"),
		"attack": {"kind": "orb", "name": "Fix-It Bolt", "desc": "Zaps the first enemy it hits, or repairs the first ally it touches.",
			"damage": 940, "heal": 820, "range": 7.0, "speed": 540.0, "super_per_hit": 0.25, "sfx": "shoot_heal"},
		"super": {"kind": "sanctuary", "name": "Repair Field", "desc": "Drops a field of repair drones that heal allies and zap enemies for 5 seconds.",
			"heal": 320, "damage": 220, "range": 7.0, "radius": 2.6, "duration": 5.0, "tick": 0.5},
		"gadget": {"kind": "mend", "name": "Spare Parts", "desc": "Instantly repairs itself and nearby allies.", "cooldown": 15.0, "heal": 1000, "radius": 3.2},
	},
	"bruno": {
		"name": "BRUNO", "role": "TANK", "rarity": "RARE", "unlock": {"currency": "credits", "cost": 600},
		"tagline": "Float like a boulder. Sting like a boulder.",
		"bio": "A champion boxing bear with gloves the size of barrels. He hits hard, takes hits harder, and never leaves the ring.",
		"health": 5600, "speed": 162.0, "radius": 26.0,
		"ammo": 3, "reload": 1.7,
		"primary": Color("e8443c"), "secondary": Color("7a4a2a"), "accent": Color("ffd166"), "skin": Color("9a6a42"),
		"attack": {"kind": "melee_cone", "name": "One-Two", "desc": "A heavy double punch that knocks into everyone in front of him.",
			"damage": 1050, "range": 2.0, "arc": 65.0, "windup": 0.08, "super_per_hit": 0.2, "sfx": "shoot_hammer"},
		"super": {"kind": "leap_slam", "name": "Belly Flop", "desc": "Jumps high over walls and lands with a ground-shaking slam that stuns.",
			"damage": 1450, "range": 6.5, "radius": 2.2, "stun": 0.6, "air_time": 0.7},
		"gadget": {"kind": "iron_skin", "name": "Guard Up", "desc": "Raises his gloves: takes 50% less damage for 3 seconds.", "cooldown": 14.0, "duration": 3.0, "reduction": 0.5},
	},
	"skye": {
		"name": "SKYE", "role": "THROWER", "rarity": "EPIC", "unlock": {"currency": "gems", "cost": 79},
		"tagline": "Incoming from above!",
		"bio": "A daredevil pilot with a homemade jetpack and a satchel full of sky bombs. Walls don't stop what falls from the sky.",
		"health": 3300, "speed": 178.0, "radius": 21.0,
		"ammo": 3, "reload": 1.65,
		"primary": Color("ff8a2a"), "secondary": Color("3a5a8a"), "accent": Color("ffe14d"), "skin": Color("e0a882"),
		"attack": {"kind": "lob", "name": "Sky Bomb", "desc": "Tosses a bomb in a high arc over walls that bursts on landing.",
			"damage": 1150, "range": 7.2, "radius": 1.5, "flight": 0.8, "super_per_hit": 0.3, "sfx": "shoot_lob"},
		"super": {"kind": "leap_slam", "name": "Rocket Drop", "desc": "Blasts off with her jetpack and crash-lands on enemies, stunning them.",
			"damage": 1400, "range": 7.5, "radius": 2.2, "stun": 0.5, "air_time": 0.75},
		"gadget": {"kind": "overclock", "name": "Bomb Bag", "desc": "Refills all ammo instantly.", "cooldown": 15.0},
	},
	"ember": {
		"name": "EMBER", "role": "DAMAGE", "rarity": "MYTHIC", "unlock": {"currency": "pass", "cost": 30},
		"tagline": "Dance with fire. Win.",
		"bio": "A fire dancer who spins blazing ribbons. Reach the top of the Rush Pass to unlock her.",
		"health": 3700, "speed": 190.0, "radius": 21.0,
		"ammo": 3, "reload": 1.1, "flames": true,
		"primary": Color("ff5a2a"), "secondary": Color("5a1a3a"), "accent": Color("ffd23a"), "skin": Color("c98a62"),
		"attack": {"kind": "twin_slash", "name": "Flame Ribbons", "desc": "Whips two blazing ribbons of fire forward.",
			"damage": 680, "range": 4.4, "speed": 640.0, "spread": 10.0, "super_per_hit": 0.14, "sfx": "shoot_blade"},
		"super": {"kind": "lance_beam", "name": "Inferno", "desc": "Spins up a roaring pillar of fire that burns through every enemy in a line.",
			"damage": 2100, "range": 11.0, "width": 1.0, "charge": 0.3},
		"gadget": {"kind": "shadow_step", "name": "Smoke Veil", "desc": "Disappears in a puff of smoke for 2.5 seconds.", "cooldown": 16.0, "duration": 2.5},
	},
}
const BRAWLER_ORDER := ["bront", "vex", "nova", "sprig", "rio", "graves", "dusty", "kora", "patch", "bruno", "skye", "ember", "cyber", "king", "templar", "monk", "gunslinger"]
const STARTER_BRAWLERS := ["bront", "vex", "nova", "sprig", "rio"]

const BOT_NAMES := ["Pixel", "Zapper", "Moxie", "Rook", "Tango", "Bolt", "Juno", "Kiwi", "Rumble", "Echo", "Sparx", "Blitz", "Nimbus", "Fuse"]

const RARITY_COLORS := {
	"RARE": Color("4fd36a"), "SUPER RARE": Color("3ea2ff"), "EPIC": Color("c25bff"), "MYTHIC": Color("ff4d5e"), "LEGENDARY": Color("ffd23a"),
}

## Team colour; in solo modes every opponent (team >= 1) shows as red.
func tc(team: int) -> Color:
	return TEAM_COLORS[0] if team == 0 else TEAM_COLORS[1]

func brawler(id: String) -> Dictionary:
	return BRAWLERS[id]

func level_mult(level: int) -> float:
	return 1.0 + UPGRADE_BONUS_PER_LEVEL * float(level - 1)


## 4K rendering is offered on computers only (phones run out of memory).
static func can_4k() -> bool:
	if OS.has_feature("mobile"):
		return false
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return false
	return true

## True when the game is set to render at 4K.
static func is_4k() -> bool:
	return can_4k() and str(Save.setting("resolution")) == "4k"

## Real rendered pixels per canvas unit (before camera zoom); set by main.gd.
static var render_px := 1.0

static func render_scale(_ci: CanvasItem) -> float:
	return render_px
