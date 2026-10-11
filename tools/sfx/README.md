# Synthesized sounds

`make_sfx.py` builds Verdigris Protocol's own sound effects and the fallback music from oscillators, noise, filters and envelopes, with no samples. Every sound has a fixed random seed taken from its name, so running it again gives the same files. It needs Python 3 with numpy, and ffmpeg with libvorbis.

```sh
python3 tools/sfx/make_sfx.py assets/audio/sfx                          # everything
python3 tools/sfx/make_sfx.py assets/audio/sfx --only sever,taken_idle  # some (a voice without its number makes every take)
python3 tools/sfx/make_sfx.py /tmp/sfx --wav /tmp/wav --music /tmp/music  # try changes outside the game, keeping the WAVs
```

Sounds go to the folder you give it; the music goes to `music` beside it (`assets/audio/music`), or to `--music`. After adding or renaming files, run `godot --headless --path . --import` so Godot picks them up.

## What it makes

All 44.1 kHz Ogg Vorbis peaking at about -3 dBFS, so how loud each one plays is set in the game. Names ending in `_loop` loop seamlessly.

- **Creatures:** `watcher_scream`, `vent_crawl`, `taken_rise`, `taken_die`, `stalker_die`, `spit`, `skitter_leap`, `feeder_grab`, `pod_hatch`, `heart_die`, `robot_drop`.
- **Gore and the player:** `sever`, `shove`, `heal`, `stim`.
- **Voices:** `<kind>_<what>_1` to `_3` for each of `taken`, `skitter`, `stalker`, `feeder` and `watcher`, and each of `alert`, `idle`, `attack` and `hurt`. `Sfx` picks one of an id's numbered takes at random.
- **Robots:** `robot_alert`, `robot_idle`.
- **Loops:** `heart_beat_loop` (3 s), `bloom_loop` (8 s), `hum_loop` (8 s).
- **Music** (stereo, quiet): `drone` (48 s, the calm decks), `hunted` (24 s), `title` (48 s). They play until real music exists.

The robots' tones and the watchers' whines are dense, so at the same volume they sound louder than the other voices.

## Other sounds

Ids with no file of their own play Kenney's sounds, listed in `Sfx.KENNEY` and copied to `assets/audio/kenney/` from Kenney's CC0 packs (`pickup1` to `pickup3` from the Foley pack's helmet pick-ups). `tools/lemonade/` asks Ken's Lemonade machine for generated versions; `generate.py` skips files that exist, so give it `--force` and the names of the sounds to replace, and make synthesized ones again by name rather than all at once.
