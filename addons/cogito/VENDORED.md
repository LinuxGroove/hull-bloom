# Vendored: COGITO

- Upstream: https://codeberg.org/Phazorknight/Cogito (moved from GitHub, Phazorknight/Cogito)
- Version: 1.1.5, commit 95b84369 (Phazorknight's last commit on GitHub)
- License: MIT (see LICENSE). Asset licenses: see CREDITS.md at the repository root.

Copied from `addons/cogito`, `addons/input_helper` and `addons/quick_audio`
(InputHelper and QuickAudio are Cogito's own dependencies and keep their own
LICENSE files). To update, copy the same folders from a newer upstream
version, update the version above and re-apply the changes below.

## Local changes

- Removed `DemoScenes/`, `DynamicFootstepSystem/DynamicFootstepDemoScene.tscn`
  and `EasyMenus/Scenes/main_menu.tscn` (Verdigris Protocol has its own menus and levels).
- Removed audio that isn't CC0 or MIT (and some unused): alarm siren (CC BY),
  running water (CC BY), fire burn (CC BY-NC), underwater loop (CC BY), the
  Pixabay spray, energy drink and soda sounds, and the sliding door sounds.
  Their users now point at Kenney sounds instead:
  - `PackedScenes/cogito_security_camera.tscn`, `CogitoNPC/cogito_npc.tscn`:
    `Kenney/error_004.ogg` for the alarm.
  - `Components/Properties/CogitoProperties.tscn`: the match strike
    (`524306_bertsz_flame_ignite.ogg`, CC0) for burning.
  - `InventoryPD/Items/Cogito_EnergyDrink.tres`: `Kenney/phaserUp5.ogg`;
    `Cogito_EmergencyInjector.tres`: `Kenney/woosh1.ogg`.
- `CogitoSettings.tres`: dropped the references to the demo scenes.
- `EasyMenus/Scenes/PauseMenu.tscn`: `main_menu_scene` is `res://game/main.tscn`.
- `Components/DynamicInputIcon.gd`: `_is_steam_deck` works its answer out
  once for every icon, and no longer prints a line for each icon when the
  renderer has no rendering device (OpenGL, or headless).
- `Components/LootComponent.gd`: `_get_configuration_warnings` returns `[]` on
  every path (Godot 4.7 rejects the missing return).
- `LICENSE` copied in from the upstream repository root.
- The `*.import` files are Godot 4.7's.

## How Verdigris Protocol uses it

- The player (`game/player/tech.gd`, `Tech`) extends `CogitoPlayer` and frees
  the parts Verdigris Protocol doesn't use (stamina, sanity, currency, Cogito's pause
  menu and inventory screen). Health, the weapons and the kit are Hull
  Bloom's own (`game/arsenal/`). Settings come from LGSettings, not Cogito's
  options file; head bob and view roll start off.
- Doors, panels and pick-ups are Verdigris Protocol's own, driven by Cogito's
  interaction raycast and prompts as they are.
- Footsteps use Cogito's `FootstepSurface`; `game/player/step_noise.gd`
  makes each step a noise creatures can hear.
- The Cogito editor plugin is left disabled: its autoloads are listed in
  `project.godot`, and enabling it breaks headless imports.
- Cogito's NPCs, light meter, quests, save slots and translations aren't used.
- The menus use Cogito's Montserrat fonts (SIL Open Font License).
