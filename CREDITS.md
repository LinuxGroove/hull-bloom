# Credits

Made by Drew, Kaden, and Ken VanDine, the LinuxGroove team.

## Art

- The station, props, aliens, guns and robots are by
  [Quaternius](https://quaternius.com): the Modular Sci-Fi MegaKit and the
  Sci-Fi Essentials Kit, released under CC0 (public domain), in
  `addons/quaternius/` with their license files.
- The crew are Quaternius' Universal Base Characters, animated with the
  Universal Animation Library 1 and 2 (CC0), in `assets/quaternius/crew/`.

Made for Verdigris Protocol, all CC0 like the rest:

- `assets/models/sprayer/`: the cryo sprayer, and `assets/models/rivet_gun/`:
  the rivet gun and its rivets, modelled by scripts (`tools/blender/sprayer.py`
  and `tools/blender/rivet_gun.py`) on the MegaKit's trim sheets.
- `assets/gore/`: the blood splats, pools and drag marks, drawn by a script
  (`tools/gore/make_gore.py`).
- The Bloom's growth, flesh and the space sky are shaders in `game/bloom/`
  and `game/world/`.

## Fonts

In `assets/fonts/`, each under the SIL Open Font License 1.1 (its license
file is beside it):

- [Saira Stencil](https://github.com/Omnibus-Type/Saira) and
  [Saira](https://github.com/Omnibus-Type/Saira) by Omnibus-Type, for
  titles and running text.
- [Chakra Petch](https://github.com/m4rc1e/Chakra-Petch) by Cadson Demak,
  for headings, buttons and the HUD.

## Audio

- `assets/audio/sfx/` and `assets/audio/music/`: sounds and fallback music
  synthesized by a script (`tools/sfx/make_sfx.py`); see the README there.
- `assets/audio/kenney/`: sounds from [Kenney](https://kenney.nl)'s Sci-Fi
  Sounds, Impact Sounds, Interface Sounds and Foley Sounds, CC0.
- `tools/lemonade/` has the prompts for making music and sounds with
  [Lemonade](https://lemonade-server.ai); what it makes is listed in
  `assets/audio/GENERATED.md`.

## Code

- [Godot Engine](https://godotengine.org), MIT.
- [COGITO](https://codeberg.org/Phazorknight/Cogito) by Phazorknight and
  contributors, MIT, vendored in `addons/cogito` (see `VENDORED.md` there),
  with Nathan Hoad's [InputHelper](https://github.com/nathanhoad/godot_input_helper)
  (MIT) and Bryce Dixon's [QuickAudio](https://github.com/BtheDestroyer/Godot_QuickAudio)
  (MIT). Cogito's assets are by Kenney, Quaternius (CC0) and Philip Drobar
  (MIT); the freesound.org sounds kept are CC0. Its Montserrat fonts, used for the
  symbols the game's fonts lack, are by Julieta Ulanovsky and others under
  the SIL Open Font License 1.1.
- [Nakama Godot client](https://github.com/heroiclabs/nakama-godot),
  Apache-2.0, vendored in `addons/com.heroiclabs.nakama` (see `VENDORED.md`).
- The shared LinuxGroove add-on in `addons/linuxgroove`, MIT.
