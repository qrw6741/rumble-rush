# RUMBLE RUSH

A fast, top-down 3v3 arena brawler made in **Godot 4.3**. All characters, art, sounds and music are original.

This is **Stage 1**: five fully playable brawlers, two game modes, two arenas, smart bots, PC and mobile controls, and saved progress. You play offline against bots.

---

## ⬇️ Download & play (Windows)

**[Download RumbleRush-Windows.zip](https://github.com/qrw6741/rumble-rush/raw/main/dist/RumbleRush-Windows.zip)**: unzip it and double-click `RumbleRush.exe`. It's one file, with nothing to install.
If Windows SmartScreen appears, click *More info → Run anyway*. This happens because the game isn't code-signed.

## How to run the project in Godot

1. Install **Godot 4.3** (standard build, not .NET) from https://godotengine.org/download. Any 4.3.x or newer 4.x build should work.
2. Unzip this folder.
3. Open Godot, click **Import**, and select `project.godot` in the folder.
4. Press **F5** (or the ▶ Play button).

The first time you open the project, Godot imports the sounds and fonts. This takes a few seconds.

### Exporting (Windows / Mac / Linux / Android / Web)
In Godot: **Editor → Manage Export Templates → Download**, then **Project → Export**, add a preset, and export.
- The renderer is already set to **Compatibility**, so it runs on phones, older PCs and the web.
- Android also needs the Android SDK and a debug keystore. Godot's "Exporting for Android" doc page walks you through it.

---

## Controls

| | PC | Mobile |
|---|---|---|
| Move | WASD / arrow keys (gamepad stick works too) | Left side: floating joystick |
| Aim | Mouse | Drag the orange attack stick |
| Attack | Left click (hold to keep firing) | Release the attack stick (quick tap = auto-aim) |
| Gadget | Right click or Q | Green **G** button |
| Super | Hold **SPACE** to preview, release to fire | Drag the yellow stick and release (tap = auto-aim) |
| Pause | ESC | **II** button |

Touch controls switch on automatically on touch devices. In **Settings → Touch Controls** you can force them ON to try them with a mouse.

---

## What's in Stage 1

### Five brawlers (each plays differently)
| Brawler | Role | Attack | Gadget | Super |
|---|---|---|---|---|
| **BRONT** | Tank | Hammer Swing: wide melee cone | Iron Skin: 50% damage reduction for 3 s | Quake Leap: jumps over walls, AoE slam + stun |
| **VEX** | Assassin | Twin Slash: two quick short-range crescents | Shadow Step: invisible for 2.5 s | Phantom Rush: dash through enemies, untouchable |
| **NOVA** | Marksman | Arc Rifle: long range, up to +50% damage at max range | Overclock: instant full reload | Lance Beam: charged, piercing beam |
| **MIRA** | Support | Spirit Orb: damages enemies OR heals the ally it touches | Mend: burst heal around her | Sanctuary: heal/burn field for 5 s |
| **SPRIG** | Controller | Seed Bomb: lobbed over walls, AoE | Vine Snare: hidden trap that roots | Bramble Patch: slow + damage field |

### Combat rules
Ammo with automatic reload, super charge from hits, health regen after 3 s out of combat, bushes (hidden unless enemies get close or you attack), walls that block shots (lobs fly over), destructible crates, water that blocks walking but not shots, spawn protection, knockback, stun, root and slow. Damage is calculated centrally: no friendly fire, the dead can't act, ammo can't go negative, supers need 100%, and nothing happens after the match ends.

### Modes
- **GEM RUSH**: collect 10 crystals from the central mine and hold them for 15 s. KO'd brawlers drop their crystals. When time runs out, the team carrying more crystals wins.
- **KNOCKOUT RUSH**: first team to 10 KOs. A tie at time-up goes to 30 s of sudden death (next KO wins); if nobody scores, it's a draw.

### Arenas
**Crystal Canyon** (desert) and **Neon District** (city). Each map is mirrored with 180° symmetry, so both teams get the same layout.

### AI bots (Easy / Normal / Hard / Expert)
Bots find paths with A\*, only see what a player on their team could see (no seeing into bushes), react with a human-like delay, aim with error and lead, strafe, dodge shots and lobs, retreat to heal, chase gems, protect a lead, heal allies (Mira), and pick sensible moments for gadgets and supers. Every bot's name ends in **(BOT)**.

### Progression (saved between sessions)
Trophies per brawler and in total, credits, XP and account level, power-level upgrades (1–7, +6% health and damage per level, with a confirmation step), lifetime stats, Star Player, the last 25 matches, and settings. Each match's rewards can only be granted once.

### Polish
Vector-drawn cartoon characters with walk, idle, blink, recoil and hit-flash animation. Particles, shockwaves, dash after-images, damage numbers, screen shake, aim previews for every attack and super, slow-motion victory, synthesized sound effects plus menu and battle music loops, physics interpolation for smooth motion on high-refresh screens, and menus with animated backgrounds.

---

## Project layout
```
scenes/main.tscn              entry scene
scripts/main.gd               boot + QA entry points
scripts/autoload/             Save (persistence), Sfx (audio), Router (screen transitions)
scripts/data/config.gd        ALL balance numbers: brawlers, modes, difficulty, rewards
scripts/data/maps.gd          map layouts (ASCII, auto-mirrored)
scripts/game/                 match, brawler, abilities, projectiles, bots, controls, map pieces
scripts/game/modes/           GameMode base + Gem Rush + Knockout Rush
scripts/fx/                   particles, beams, swings, floating text
scripts/ui/                   menus, HUD, touch controls, UI kit
tests/qa_runner.gd            automated QA
assets/audio, assets/fonts    generated SFX/music, Poppins font (OFL)
```
**Balancing:** change numbers in `scripts/data/config.gd`. **New map:** add 17 rows of 21 characters to `scripts/data/maps.gd`.

---

## Testing (run from the project folder)
```
godot --headless --path . -- --check                     # compile every script
godot --path . -- --qa                                   # 41 automated gameplay/input/menu checks
godot --headless --fixed-fps 60 --path . -- --autotest   # full bot-vs-bot match (add --knockout)
```
The QA run uses its own save file, so your real progress is never touched.

---

## Not built yet (later stages)
The full design brief is much larger than this stage. These parts are **not** built yet:
- **Online multiplayer**: accounts, matchmaking, private rooms, friends, an authoritative server, reconnection. Damage already goes through one central routine, and inputs are separate from brawlers, so a server can take over later. Real online play still needs a hosted server: Godot's high-level multiplayer or a Node.js/Socket.IO server, plus a database.
- 7 more brawlers (to reach 12), 3 more modes (Survival, Vault Raid, Zone Control), 6 more maps.
- Shop, cosmetics/skins, a second currency, missions, Trophy Road rewards, friends, and language selection.
