#!/usr/bin/env python3
"""Copies the Quaternius packs Hull Bloom uses out of a quaternius-assets
checkout (https://github.com/LinuxGroove/quaternius-assets) into the game.

    python3 tools/vendor_quaternius.py /path/to/quaternius-assets

- addons/quaternius/: the Modular Sci-Fi MegaKit's Godot setup as it ships
  (materials, shaders, the import script and every model), plus the Sci-Fi
  Essentials Kit's guns, enemies and props and the materials only they use.
  Both kits keep the paths their own Godot projects use, so the import
  script swaps in the kits' materials. The two kits share their trim sheets;
  the Essentials Kit's copies of those are left out and its materials point
  at the MegaKit's.
- assets/quaternius/crew/: the two Universal Base Characters and the
  Universal Animation Library 1 and 2 clips (same rig).

Textures bigger than 2048 pixels are scaled down to 2048. The crew are
drawn in Hull Bloom's own shaders, so their textures are left out. Planets and the
planet hologram are left out (the station has no use for them).
"""
import os
import re
import shutil
import sys

from PIL import Image

MAX_TEX = 2048
SKIP_PROPS = re.compile(r"Prop_(Planet|PlanetRings|HologramHexagonPlanet|SatelliteDish)")
SKIP_MATERIALS = re.compile(r"^(MI_Planet|MI_PlanetRings|M_Planet|MI_HologramPlanet|M_HologramPlanet)")


def main(src: str, dst: str) -> None:
    mk = os.path.join(src, "Modular SciFi MegaKit[Source]/Engine Projects/Godot/modular-sci-fi-megakit/addons/quaternius")
    ess = os.path.join(src, "Sci-Fi Essentials Kit[Source]/Engine Projects/Godot/sci-fi-essentials/addons/quaternius")
    out = os.path.join(dst, "addons/quaternius")
    if os.path.isdir(out):
        shutil.rmtree(out)
    # The MegaKit, as it ships (its stray .bin files in materials/ are kept:
    # some of its glTF files look for them there).
    shutil.copytree(mk, out, ignore=shutil.ignore_patterns("L_Example.tscn"))
    mk_mats = set(os.listdir(os.path.join(out, "materials")))
    # The Essentials Kit's models.
    for kind in ["Guns", "Enemies", "Props"]:
        sdir = os.path.join(ess, "Sci-FiEssentials", kind)
        ddir = os.path.join(out, "Sci-FiEssentials", kind)
        os.makedirs(ddir, exist_ok=True)
        for f in sorted(os.listdir(sdir)):
            if SKIP_PROPS.match(f):
                continue
            shutil.copy2(os.path.join(sdir, f), ddir)
            if f.endswith(".import"):
                # The kit's project marks these as never imported; Godot would
                # then refuse to load them until they're imported again.
                p = os.path.join(ddir, f)
                text = open(p).read().replace("valid=false\n", "")
                open(p, "w").write(text)
    # Its own materials, pointed at the MegaKit's copies of shared textures.
    tex_needed = set()
    for f in sorted(os.listdir(os.path.join(ess, "materials"))):
        if not f.endswith(".tres") or f in mk_mats or SKIP_MATERIALS.match(f):
            continue
        text = open(os.path.join(ess, "materials", f)).read()

        def shared(m: re.Match) -> str:
            name = m.group(2)
            if name in mk_mats:
                uid = _uid(os.path.join(out, "materials", name + ".import"))
                return '[ext_resource type="Texture2D" uid="%s" path="res://addons/quaternius/materials/%s"' % (uid, name)
            tex_needed.add(name)
            return m.group(0)

        text = re.sub(r'\[ext_resource type="Texture2D" uid="[^"]*" path="res://addons/quaternius/materials/(Textures)/([^"]+)"', shared, text)
        open(os.path.join(out, "materials", f), "w").write(text)
    tdir = os.path.join(out, "materials", "Textures")
    os.makedirs(tdir, exist_ok=True)
    for name in sorted(tex_needed):
        s = os.path.join(ess, "materials", "Textures", name)
        d = os.path.join(tdir, name)
        _copy_texture(s, d)
        shutil.copy2(s + ".import", d + ".import")
    # The crew: two base bodies and the animation libraries.
    crew = os.path.join(dst, "assets/quaternius/crew")
    if os.path.isdir(crew):
        shutil.rmtree(crew)
    os.makedirs(crew)
    ubc = os.path.join(src, "Universal Base Characters[Standard]/Base Characters/Godot - UE")
    for f in sorted(os.listdir(ubc)):
        if f.endswith(".gltf") or f.endswith(".bin"):
            shutil.copy2(os.path.join(ubc, f), crew)
        if f.endswith(".gltf"):
            _write_import(os.path.join(crew, f + ".import"), "scene", "PackedScene", ["gltf/embedded_image_handling=0"])
    for lib, name in [("Universal Animation Library[Standard]", "UAL1_Standard.glb"),
                      ("Universal Animation Library 2[Standard]", "UAL2_Standard.glb")]:
        shutil.copy2(os.path.join(src, lib, "Unreal-Godot", name), crew)
        _write_import(os.path.join(crew, name + ".import"), "animation_library", "AnimationLibrary", ["gltf/embedded_image_handling=0"])
    # The MegaKit's platforms look for their textures beside them; the import
    # script swaps in the kit's materials, so the images aren't needed.
    pdir = os.path.join(out, "modularscifimegakit")
    for d, _, files in os.walk(pdir):
        for f in files:
            if f.endswith(".gltf.import"):
                p = os.path.join(d, f)
                text = open(p).read().replace("gltf/embedded_image_handling=1", "gltf/embedded_image_handling=0")
                open(p, "w").write(text)
    _drop_stray_bins(out)
    # Visual shaders saved by an older Godot carry an editor-only setting
    # that Godot 4.7 warns about on every load.
    mdir = os.path.join(out, "materials")
    for f in os.listdir(mdir):
        if f.endswith(".tres"):
            p = os.path.join(mdir, f)
            text = open(p).read()
            if "graph_offset" in text:
                open(p, "w").write(re.sub(r"^graph_offset = .*\n", "", text, flags=re.M))
    for lic in ["Modular SciFi MegaKit[Source]/License_Source.txt", "Sci-Fi Essentials Kit[Source]/License_Source.txt"]:
        shutil.copy2(os.path.join(src, lic), os.path.join(out, lic.split("/")[0].split("[")[0].replace(" ", "_") + "_License.txt"))
    shutil.copy2(os.path.join(src, "Universal Base Characters[Standard]/License_Standard.txt"), os.path.join(crew, "Universal_Base_Characters_License.txt"))
    shutil.copy2(os.path.join(src, "Universal Animation Library[Standard]/License.txt"), os.path.join(crew, "Universal_Animation_Library_License.txt"))
    print("Vendored into", out, "and", crew)


def _drop_stray_bins(root: str) -> None:
    """The kits' Godot projects carry copies of their .bin buffers in folders
    where no glTF file looks for them; only the ones beside a glTF are kept."""
    used = set()
    for d, _, files in os.walk(root):
        for f in files:
            if f.endswith(".gltf"):
                for uri in re.findall(r'"uri"\s*:\s*"([^"]+\.bin)"', open(os.path.join(d, f)).read()):
                    used.add(os.path.normpath(os.path.join(d, uri)))
    for d, _, files in os.walk(root):
        for f in files:
            p = os.path.normpath(os.path.join(d, f))
            if f.endswith(".bin") and p not in used:
                os.remove(p)


def _write_import(path: str, importer: str, kind: str, params: list) -> None:
    """A minimal .import file; Godot fills in the rest on the next import."""
    with open(path, "w") as f:
        f.write('[remap]\n\nimporter="%s"\nimporter_version=1\ntype="%s"\n\n[params]\n\n' % (importer, kind))
        for p in params:
            f.write(p + "\n")


def _uid(import_path: str) -> str:
    for line in open(import_path):
        if line.startswith("uid="):
            return line.split('"')[1]
    raise SystemExit("no uid in " + import_path)


def _copy_texture(s: str, d: str, limit: int = MAX_TEX) -> None:
    im = Image.open(s)
    if max(im.size) > limit:
        f = limit / max(im.size)
        im = im.resize((round(im.size[0] * f), round(im.size[1] * f)), Image.LANCZOS)
        im.save(d, optimize=True)
    else:
        shutil.copy2(s, d)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1], os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
