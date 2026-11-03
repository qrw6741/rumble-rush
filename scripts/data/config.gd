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
		"maps": ["crystal_canyon", "neon_district"],
		"icon": "mode_gem",
	},
	"showdown": {
		"name": "SHOWDOWN",
		"short": "Solo survival: 10 brawlers, last one standing wins.",
		"rules": "Every brawler for themselves. Smash power boxes to grab POWER CELLS (+health and +damage). Poison clouds close in from the edges, so keep moving toward the centre. No respawns: survive to the end! Top 4 gain trophies.",
		"time_limit": 240.0,
		"color": Color("43c463"),
		"maps": ["bone_desert"],
		"icon": "mode_showdown",
	},
	"knockout": {
		"name": "KNOCKOUT RUSH",
		"short": "First team to 10 KOs wins.",
		"rules": "Every KO scores a point. Respawns are on. First to 10 wins. If time runs out the leading team wins; a tie goes to a 30 s sudden-death overtime where the next KO wins.",
		"time_limit": 150.0,
		"target": 10,
		"color": Color("ff7a2b"),
		"maps": ["neon_district", "crystal_canyon"],
		"icon": "mode_knockout",
	},
}

const DIFFICULTY := {
	"easy":   {"name": "EASY",   "reaction": 0.55, "aim_error": 0.30, "dodge": 0.10, "lead": 0.0, "super_smart": 0.3, "think": 0.45},
	"normal": {"name": "NORMAL", "reaction": 0.35, "aim_error": 0.17, "dodge": 0.35, "lead": 0.5, "super_smart": 0.7, "think": 0.30},
	"hard":   {"name": "HARD",   "reaction": 0.22, "aim_error": 0.09, "dodge": 0.60, "lead": 0.8, "super_smart": 0.9, "think": 0.22},
	"expert": {"name": "EXPERT", "reaction": 0.14, "aim_error": 0.05, "dodge": 0.80, "lead": 1.0, "super_smart": 1.0, "think": 0.15},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard", "expert"]

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
	"mira": {
		"name": "MIRA", "role": "SUPPORT", "rarity": "EPIC",
		"tagline": "Heals friends. Haunts enemies.",
		"bio": "A lantern-keeper whose spirit orbs know exactly who deserves a hug and who deserves a hit.",
		"health": 3600, "speed": 172.0, "radius": 22.0,
		"ammo": 3, "reload": 1.45,
		"primary": Color("ff7bc2"), "secondary": Color("3b2350"), "accent": Color("9dff9a"), "skin": Color("f2c6a0"),
		"attack": {"kind": "orb", "name": "Spirit Orb", "desc": "Damages the first enemy it hits — or heals the first ally it touches.",
			"damage": 980, "heal": 810, "range": 7.2, "speed": 520.0, "super_per_hit": 0.25, "sfx": "shoot_heal"},
		"super": {"kind": "sanctuary", "name": "Sanctuary", "desc": "Throws a glowing field that heals allies and burns enemies for 5 seconds.",
			"heal": 300, "damage": 230, "range": 7.0, "radius": 2.6, "duration": 5.0, "tick": 0.5},
		"gadget": {"kind": "mend", "name": "Mend", "desc": "Instantly heals herself and nearby allies.", "cooldown": 15.0, "heal": 1000, "radius": 3.2},
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
}
const BRAWLER_ORDER := ["bront", "vex", "nova", "mira", "sprig"]

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
