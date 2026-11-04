# Rumble Rush — Project Handoff

Creative director: Mahra Almarzooqi
Last updated: 4 November 2026

Rumble Rush is an original arena brawler inspired by Brawl Stars, made in **Godot 4.3**.
It has the same kind of modes and menus as Brawl Stars, but its own characters, art and names.

## Where everything lives
| What | Where |
|---|---|
| Code (GitHub repo) | https://github.com/qrw6741/rumble-rush, `main` branch |
| iPhone / browser version | https://qrw6741.github.io/rumble-rush/ (the `gh-pages` branch) |
| PC download | https://github.com/qrw6741/rumble-rush/raw/main/dist/RumbleRush-Windows.zip |
| Restore point (older version) | Branches `backup-v1` (code) and `backup-v1-web` (iPhone build) |

**Standing rule:** if Mahra says "go back", restore the older version from the backup branches.

## Brawlers (15)
- **Unlocked from the start:** Bront, Vex, Nova, Mira, Sprig, Rio.
- **Locked:**
  - Graves (grim reaper, scythe)
  - Dusty (cowboy, dual revolvers)
  - Kora
  - Patch
  - Bruno
  - Skye
  - Ember (Mythic, free tier 30 of the Rush Pass)
  - **Cyber Ninja** (Epic, 99 gems)
  - **Spectral King** (Legendary, 179 gems)
- **Graves, Cyber Ninja and Spectral King use Mahra's own art.** The character sheets are cut into sprites in `assets/brawlers/<id>/`, and the code animates them by bending the drawings: breathing, walking, a 3-stage swing, hit flinch, super, victory and defeat.
  - Graves has the most frames: main, idle, walk, run, attack, hurt, super, front and back.
  - Cyber Ninja and Spectral King only have main, front, side and back. Higher-resolution walk, attack and hurt poses would make them look better.
- The other brawlers are drawn in code (vector art) in 2D mode and use 3D models in 3D mode.
- **Special skins:**
  - Inferno Outlaw (Dusty)
  - Frost Wraith (Graves)
  - Neon Tagger (Rio)
  - Polar Champ (Bruno)
  - Starlight (Mira)
  - Magma Miner (Bront)

## Modes and maps
- **Gem Rush (3v3):** Crystal Canyon, Neon District, Sunset Ruins.
- **Knockout Rush (3v3):** Neon District, Crystal Canyon, Frost Yard.
- **Showdown (solo, 10 players):** Bone Desert, Toxic Marsh.
- **Duel Rush (1v1, best of 3; the arena closes in after 60 seconds):** Duel Den, Twin Bridges.
- The active map changes every 3 hours.
- **CHAMPS** (works like FIFA's FUT Champions):
  - Qualifier: win 5 before losing 3.
  - Finals: 15 Duel Rush matches, ranked X to I with rewards.
  - Your brawler is locked in for the Finals.

## Progression and menus
- **Trophies:** per brawler, in Brawl Stars-style bands. Ranks 1–35, with bot difficulty rising by rank.
- **Win streak:**
  - Bonuses start at 2 wins in a row and grow up to +6 trophies, with coins that keep rising.
  - It shows as a fire with the number on the PLAY button.
  - Profile shows your current and best streak.
- **Trophy Road:** Brawl Stars layout. Unlocks Bruno at 100, Dusty at 300, Kora at 600 and Patch at 900 trophies.
- **Rush Pass:** free and paid tracks, quests and brawler challenges.
- **Shop:**
  - Offers and daily deals.
  - 3 skins every 2 hours, with the featured one 30% off.
  - Gems and Rush Drops.
- **Brawler mastery:** Bronze I to Gold III. Profile icons and titles can be changed.
- **Results screens:**
  - 3v3: blue/red split screen with stat cards, Star Player and awards.
  - Showdown: "You are #N!" layout with the win-streak bonus pill.
- **Settings:**
  - Brawler view and map view (3D or 2D).
  - Resolution: 720p, 1080p, 4K (PC only) or native.
  - FPS limit.
  - Graphics level.
- **Debug menu (Settings → DEBUG):** play any brawler, locked ones included, in test matches that save nothing.

## Technical notes (for whoever continues the work)
- **Project folder** (on the cloud machine used so far, which can reset between sessions): `/home/claude/rumble-rush`. Godot binary: `/home/claude/tools/godot`.
- **Builds:**
  - Windows: "Windows Desktop" export to `../build/RumbleRush.exe` plus a separate `.pck`. The exe is kept separate on purpose because a single combined exe triggered antivirus false positives. These files plus README.txt are zipped into `dist/`.
  - Web: "Web" export to `../web/`, then copied onto the `gh-pages` branch.
- **Saves:**
  - Stored in `user://` and mirrored to the browser's localStorage under `rumble_rush_save_v1`.
  - The iPhone home-screen app updates itself to new versions, but never mid-match.
- **Testing commands:**
  - `godot --headless --path . -- --check` checks the scripts for errors.
  - `-- --screen=<name> --shots=t --out=...` takes screenshots. Useful flags: `--view2d`, `--graves`, `--res4k`, `--debugmenu`.
  - `-- --autotest [--showdown|--duel|--knockout]` runs a bot-only test match.
- **Ground rule:** keep the art, characters, names and logos original. No copied Brawl Stars characters or logos.

## Ideas not done yet
- Sound and hit-feedback pass.
- A new team mode.
- Star Powers.
- A tutorial.
- A controls editor.
- A battery-saver preset.
- More poses for Cyber Ninja and Spectral King. Give the remaining brawlers the same hand-drawn sprite treatment.
