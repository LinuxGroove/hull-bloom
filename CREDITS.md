# Credits

Made by the LinuxGroove team.

## Art

- The station, props, aliens, guns and robots are by
  [Quaternius](https://quaternius.com): the Modular Sci-Fi MegaKit and the
  Sci-Fi Essentials Kit, released under CC0 (public domain), in
  `addons/quaternius/` with their license files.
- The crew are Quaternius' Universal Base Characters, animated with the
  Universal Animation Library 1 and 2 (CC0), in `assets/quaternius/crew/`.

Made for Hull Bloom, all CC0 like the rest:

- `assets/models/cutter/`: the plasma cutter, modelled by a script
  (`tools/blender/cutter.py`).
- `assets/gore/`: the blood splats, pools and drag marks, drawn by a script
  (`tools/gore/make_gore.py`).
- The Bloom's growth, flesh and the space sky are shaders in `game/bloom/`
  and `game/world/`.

## Audio

- `assets/audio/sfx/` and `assets/audio/music/`: sounds and fallback music
  synthesized by a script (`tools/sfx/make_sfx.py`); see the README there.
- `assets/audio/kenney/`: sounds from [Kenney](https://kenney.nl)'s Sci-Fi
  Sounds, Impact Sounds and Interface Sounds, CC0.
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
  (MIT); the freesound.org sounds kept are CC0. Its Montserrat fonts, used in
  the menus, are by Julieta Ulanovsky and others under the SIL Open Font
  License 1.1.
- [Nakama Godot client](https://github.com/heroiclabs/nakama-godot),
  Apache-2.0, vendored in `addons/com.heroiclabs.nakama` (see `VENDORED.md`).
- The shared LinuxGroove add-on in `addons/linuxgroove`, MIT.
