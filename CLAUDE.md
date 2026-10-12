# Verdigris Protocol

A first person horror shooter against an alien growth on a space station, in Godot 4.7 with GDScript on top of the COGITO immersive sim template, built from Quaternius' sci-fi kits. The concept is idea 21 in [game-ideas](https://github.com/LinuxGroove/game-ideas/blob/main/ideas/21-verdigris-protocol.md). It shares the LinuxGroove add-on with the other games; **read game-ideas' [online-addon.md](https://github.com/LinuxGroove/game-ideas/blob/main/online-addon.md) before touching online features or the shared add-on.**

## Commands

```sh
godot --headless --path . --import && godot --headless --path . --import   # twice: Cogito's fonts fail the first time
godot --headless --path . tools/check_scripts.tscn                  # every script compiles
godot --headless --path . tests/run_tests.tscn                      # everything: the core tests and every deck's
godot --headless --path . tests/run_tests.tscn -- --core            # the Bloom, power, weapons, creatures, menus, Shift mode
godot --headless --path . tests/run_tests.tscn -- --deck=labs       # one deck's tests (CI runs each deck side by side)
godot --headless --path . tests/run_tests.tscn -- --only=_test_combat   # one test of run_tests.gd
godot --headless --path . tools/function_sweep.tscn [-- --only=pause,saves]   # clicks and keys through the title, settings, pause menu, saves, ring map, workbench, Shift and offline play (set XDG_DATA_HOME to a scratch folder: it writes real settings and progress)
godot --path . -- --deck=hydroponics [--campaign]                   # straight onto a deck
godot --path . -- --shift[=seed]                                    # straight into a Shift night
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 tools/screenshot.tscn -- --all=docs/screenshots [group=labs|menus]
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 tools/screenshot.tscn -- --out=/tmp/shots --deck=labs [--view=name] [--hud] [--overgrown] [--frozen]
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 tools/function_shots.tscn -- --out=/tmp/shots [--scale3d=0.5] [--settle=10]   # the title, ring map, HUD, weapon wheel, pause menu and deck map at a window size
python3 tools/sfx/make_sfx.py assets/audio/sfx                      # the synthesized sounds
godot --headless --path . -s tools/story_script.gd -- --out=/tmp/story.md   # every player-facing line, in the order a player meets it
godot --headless --path . tools/autopilot.tscn -- --deck=hydroponics --skill=average --seed=1 --runs=3 --minutes=20 --out=/tmp/ap.json   # the autopilot plays a deck
godot --headless --path . tools/autopilot.tscn -- --campaign --skill=expert --seed=1 --out=/tmp/campaign.json   # Hydroponics, the ring, then the Core
xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 --resolution 1280x800 tools/autopilot.tscn -- --deck=labs --shots=/tmp/ap_shots --every=5   # what it sees, as JPEGs
```

The autopilot plays through the Tech's own controls at `novice`, `average` or `expert` (`tools/autopilot/skill.gd`), in fixed 1/60 s steps as fast as the machine runs them (up to a hundred times real time; about eight on four CPUs), and writes each run's deaths, damage, kills, ammo, the Bloom and Godot's monitors as JSON. A seed sets up a run but doesn't replay it exactly (runs drift apart after the first fight), so judge a deck by several seeds. `AUTOPILOT_DEBUG=1` prints what it's thinking. Keep it fair: on a deck it plays only through input actions and the view (turned as the mouse turns it), never by touching creatures, Hearts or the Tech's health; between campaign decks it makes the ring's and the workbench's choices through `Progress`. For `--shots`, OpenGL is far faster than software Vulkan, which spends a fraction of a second on every step even with drawing off.

Run the script check and the tests before every commit. A new `class_name` needs an `--import` before the script check finds it. Headless runs reimport assets and rewrite `*.import` files and `icon.png.import`; revert those (`git checkout -- '*.import'`, `rm icon.png.import`) unless you meant to change them. `docs/screenshots/` holds a picture of every deck and menu (software Vulkan from `mesa-vulkan-drivers`, so they look like the game's Forward+ renderer); shoot them again after changing how something looks.

## Layout

| Path | What |
|---|---|
| `game/game_config.gd` | `GAME_ID`, setting defaults (comfort, gore, difficulty), input map (Cogito's action names) |
| `game/decks/` | `DeckDef`, `Decks` (the eight decks in `ORDER`), and one folder per deck: its data (`<id>_deck.gd`), its level (`<id>_level.gd`) and its tests (`<id>_tests.gd`) |
| `game/station/` | `Kit` (Quaternius pieces by name, layers, the grid), `DeckLevel` (decks in code), doors (`Bulkhead`), the lift, vents, turrets, pick-ups, logs, survivors, bodies |
| `game/bloom/` | `Bloom` (the growth on the deck's tile graph, no nodes), `BloomView` (draws it), the flesh and growth shaders |
| `game/deck/` | `DeckScene` (one visit to a deck), `DeckRun` (its clock, kills and survivors), `Director` (hatching), `Power` |
| `game/creatures/` | `Creature` and its kinds (the Taken, skitters, stalkers, feeders, watchers, robots), the `Heart`, pods |
| `game/arsenal/` | The weapons, flares, grenades and mines, and the view model |
| `game/gore/` | `Gore` (blood, gibs, decals, the Gore setting), `LimbHider` (dismemberment) |
| `game/crew/` | The crew: Universal Base Characters in job colours, and the Taken's look |
| `game/player/` | `Tech` (extends `CogitoPlayer`), footstep noise |
| `game/shift/` | Shift mode: `ShiftLevel` (a deck from a seed), `ShiftNight` (three decks, the score, the boards) |
| `game/ui/` | Title, ring map, endings, HUD and map, pause menu, workbench, results, settings, how to play |
| `game/progress.gd` | `Progress` autoload: the campaign (hours, deck states, gifts, salvage, survivors, endings) and Shift bests (user://progress.cfg) |
| `game/net/online_server.gd` | Default game server; `SERVER_KEY` stays `defaultkey` in git |
| `addons/cogito/` | Vendored COGITO 1.1.5 with local changes (see its `VENDORED.md`) |
| `addons/quaternius/` | Quaternius' Modular Sci-Fi MegaKit and Sci-Fi Essentials Kit (CC0), from LinuxGroove/quaternius-assets by `tools/vendor_quaternius.py` |
| `addons/linuxgroove/`, `addons/com.heroiclabs.nakama/` | Shared LinuxGroove add-on and the vendored Nakama client |
| `assets/` | The crew models and animation libraries, Blender-made models (`models/`), gore decals, sounds (`audio/`) |
| `tests/run_tests.gd` | Headless test runner; add checks with `check(ok, "what")` |
| `tools/autopilot/` | The autopilot (`tools/autopilot.tscn` runs it): `pilot.gd` plays a deck through the Tech's controls, `skill.gd` its presets, `nav_grid.gd` where the Tech can walk, `telemetry.gd` what each run records |
| `tools/` | Script checker, screenshots, the story script (`story_script.gd`), Blender scripts, gore decals, the sound synthesizer, the icon (`make_icon.py` writes `icon.svg` and the snap's copy), Lemonade prompts, `version.sh`, `release.sh` |

## How the game is built

- **The campaign.** Hydroponics first, then six decks round the ring in any order, then the Core. Every deck you're not on loses hours (`DeckDef.hours`); when they run out it's lost to the Bloom, and a lost deck can be taken back. Saving a deck gives a gift (`gives`) the rest of the run uses. The ending depends on Cargo and how many decks are held (`EndingScreen.which()`).
- **Levels are code.** A deck's level extends `DeckLevel` and lays out tiles in `build()`: `room()`, `corridor()`, `door()` (sealed, open or jammed), `arch()`, `window()`, `vent()`, `cable()`, `lift()`, `root()` (the Heart), `grow()` and `grow_room()`, then things, props, pick-ups, logs, survivors, bodies and spawns, and `view()`s for screenshots. Tiles are 4 m, storeys 5 m; X runs east and Z south. `finish()` builds the kit pieces, lights, collision and the Bloom's grid.
- **The Bloom** is a number per tile on a graph of links (open, door, vent, cable). Each `TICK` it feeds out from living roots, spreads through open links and dark rooms, slows in light and behind sealed doors, and decays where nothing feeds it. A deck is held when its roots are dead and the growth has died back (`is_held()`). `_test_deck_balance` checks each deck's spread at five minutes.
- **Layers**: 1 station, 2 interactables, 4 creatures, 8 player, 16 doors, 32 gibs, 64 glass, 128 hitboxes. `Kit.LAYER_SOLID` is what blocks sight and shots.
- **Gore** respects the Gore setting (`Full`, `Less`, `Off`) everywhere through `Gore.shown()` and `Gore.full()`; the setting can be locked with a code. With gore off there's no blood, no gibs and no dismemberment.
- **Comfort.** Head bob and view roll are off by default, with physics interpolation; Calm walls slows or stops the growth's breathing and Spore blur can be turned off. Never add camera shake that can't be turned off.
- **Shift mode** opens after the first ending. A night is three decks built by `ShiftLevel` from a seed; tonight's station (the date as its seed) submits its score to the `shift_daily` and `shift_best` boards with `core.score_submit`, which the game server declares in `modules/src/games/verdigris-protocol.ts`.
- **Play tests.** The shared add-on's `LGPlaytest` records a play test when the Play test recording setting is on (or with `-- --playtest`): a picture every few seconds, game events, frame times and controls, the player's notes (F8, or Note this moment in the pause menu) and a survey when they quit, all in one zip in `user://playtest/`. Game events go through `LGPlaytest.event()` and `moment()`; the round's own survey questions are `GameConfig.PLAYTEST`. Quit through `LGScenes.quit()` so the survey comes first.
- **Everything works offline.** No server or network is needed; the boards are only tried when online play is on.
- **Launch ping.** `game/main.gd` calls `LGLaunchPing.send(GameConfig.GAME_ID)` at startup: one anonymous request to the game server's `/launch` (game, random install id, version, OS, CPU) so the server counts every player. It's skipped headless, from source and with `DO_NOT_TRACK` set, and never blocks or retries.

## The shared add-on

`addons/linuxgroove/` and `addons/com.heroiclabs.nakama/` are copies shared with [Foam Frenzy](https://github.com/LinuxGroove/foam-frenzy), [Graveyard Hollow](https://github.com/LinuxGroove/LampLighters), [Tiptoe](https://github.com/LinuxGroove/tiptoe), [Joyride Junction](https://github.com/LinuxGroove/joyride-junction), [Block Party: Skyway](https://github.com/LinuxGroove/block-party-skyway) and [Race Day](https://github.com/LinuxGroove/race-day). Fix shared behaviour in the add-on, not with a workaround here, keep it game-agnostic, and port the change to the other games in the same piece of work. When the change affects how games should use the add-on, update online-addon.md in game-ideas too. Keep the `_disconnect_peer` and `_close` patch in `NakamaMultiplayerPeer.gd` when updating nakama-godot.

## Style

- Match the surrounding code: `##` doc comments on classes and non-obvious functions, short comments only where the reason isn't obvious.
- Connect signals with methods (or `bind`), not lambdas.
- Build pieces so tests can drive them without a scene change: `Bloom` needs no nodes, levels build without a player, and menus expose `button_texts()`.
- Controller first: everything works with a pad, and the mouse and keyboard always work too.
- Player-facing text is plain and short, in the game's words (decks, the Bloom, the Heart, the Taken, the night shift, MARI).

## Releases

Pushing to `main` builds the snap and publishes it to the `edge` channel; a GitHub release publishes to `candidate`. The **Windows and macOS** workflow (`desktop.yml`) exports both from Linux. CI injects the server key from the `GAME_SERVER_KEY` secret, so never commit the real key; `SERVER_KEY` stays `defaultkey` in git.

Versions are `vYYYY.WW.MINOR`, derived from git by `tools/version.sh`; make releases with the **Release** workflow. Commit subjects become the release notes, so write them for players.
