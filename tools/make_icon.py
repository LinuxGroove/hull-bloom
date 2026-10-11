#!/usr/bin/env python3
"""Draws the game's icon: the Bloom opening out of a verdigris hatch, its
fleshy petals veined and glowing round the hot Heart, the outer ones
reaching over the frame. Writes icon.svg and the snap's copy:

    python3 tools/make_icon.py [--out=file.svg]

The veins are a jittered hexagonal cell network (the Bloom's look in game),
wobbled and clipped to the flesh. Glows are layered strokes and gradients
rather than SVG filters, so Godot's SVG importer draws it as a browser does.
The seed is fixed, so the output only changes when this script does.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUTS = [ROOT / "icon.svg", ROOT / "snap/gui/verdigris-protocol.svg"]

CX, CY = 256.0, 240.0
# The hatch: an octagon with a flat top.
R_OUT, R_IN = 214.0, 166.0

# The Heart: a hot core with fleshy petals opening round it, the outer
# ones reaching over the hatch frame and its bottom edge. Petals are
# (angle, length, width, bend), drawn back to front.
CORE = (256.0, 250.0, 62.0)
PETALS = [
    (-132, 204, 98, 30), (-54, 228, 104, -34), (-174, 186, 86, 24), (-10, 214, 98, -26),
    (-96, 168, 80, 14), (150, 190, 100, -30), (34, 226, 116, 34), (98, 248, 134, -16),
    (-150, 116, 72, 6), (-34, 122, 76, -6),
]


def octagon(r: float) -> list:
    return [(CX + r * math.cos(math.radians(22.5 + 45 * k)), CY + r * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]


def poly(pts: list) -> str:
    return "M " + " L ".join("%.1f %.1f" % p for p in pts) + " Z"


def petal(angle: float, length: float, width: float, bend: float, phase: float) -> list:
    """A fleshy petal from the core out along angle, bowed by bend, its
    edge rippled a little. Every petal winds the same way."""
    ux, uy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    nx, ny = -uy, ux
    left, right = [], []
    for k in range(41):
        t = k / 40
        half = width / 2 * math.sin(math.pi * (0.16 + 0.84 * t)) ** 1.05
        half *= 1 + 0.08 * math.sin(5 * math.pi * t + phase)
        off = bend * (0.6 * math.sin(math.pi * t) + 0.7 * t ** 3)
        sx, sy = CORE[0] + ux * length * t + nx * off, CORE[1] + uy * length * t + ny * off
        left.append((sx + nx * half, sy + ny * half))
        right.append((sx - nx * half, sy - ny * half))
    return left + list(reversed(right))


def spine(angle: float, length: float, bend: float) -> str:
    ux, uy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    nx, ny = -uy, ux
    pts = []
    for k in range(6):
        t = 0.3 + 0.55 * k / 5
        off = bend * (0.6 * math.sin(math.pi * t) + 0.7 * t ** 3)
        pts.append((CORE[0] + ux * length * t + nx * off, CORE[1] + uy * length * t + ny * off))
    return smooth(pts)


def veins(rng: random.Random, box: tuple, step: float, wobble: float) -> list:
    """Edges of a jittered hexagonal cell network inside box: (points, weight)."""
    x0, y0, x1, y1 = box
    h = step * math.sqrt(3) / 2
    cols = int((x1 - x0) / step) + 3
    rows = int((y1 - y0) / h) + 3
    pts = {}
    for j in range(rows):
        for i in range(cols):
            x = x0 - step + i * step + (step / 2 if j % 2 else 0)
            y = y0 - h + j * h
            pts[(i, j)] = (x + rng.uniform(-0.32, 0.32) * step, y + rng.uniform(-0.32, 0.32) * h)
    # Each lattice triangle's centroid is a cell corner; the corners of two
    # triangles that share an edge are joined.
    corners = {}
    for j in range(rows):
        o = 1 if j % 2 else 0
        for i in range(cols):
            for t in (((i, j), (i + 1, j), (i + o, j + 1)), ((i + o, j + 1), (i + o + 1, j + 1), (i + 1, j))):
                if all(p in pts for p in t):
                    corners[frozenset(t)] = tuple(sum(pts[p][k] for p in t) / 3 for k in (0, 1))
    by_edge = {}
    for t in corners:
        ps = list(t)
        for a in range(3):
            for b in range(a + 1, 3):
                by_edge.setdefault(frozenset((ps[a], ps[b])), []).append(t)
    lines = []
    for ts in by_edge.values():
        if len(ts) != 2 or rng.random() < 0.18:
            continue
        a, b = corners[ts[0]], corners[ts[1]]
        lines.append((_wobble(rng, a, b, wobble), rng.uniform(0.6, 1.3)))
    return lines


def _wobble(rng: random.Random, a: tuple, b: tuple, amount: float) -> list:
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    n = (-dy / ln, dx / ln)
    bump = rng.uniform(-amount, amount)
    out = []
    for k in range(5):
        t = k / 4
        s = math.sin(t * math.pi) * bump
        out.append((a[0] + dx * t + n[0] * s, a[1] + dy * t + n[1] * s))
    return out


def smooth(pts: list) -> str:
    """A Catmull-Rom curve through pts, as cubic Beziers."""
    d = "M %.1f %.1f" % pts[0]
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += " C %.1f %.1f, %.1f %.1f, %.1f %.1f" % (c1 + c2 + p2)
    return d


def strokes(d: str, layers: list) -> str:
    return "".join('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-opacity="%.2f" stroke-linecap="round" stroke-linejoin="round"/>' % (d, c, w, o) for w, c, o in layers)


def vein_layers(lines: list) -> str:
    """Thin and thick veins as two paths, each drawn three times for its
    glow."""
    paths, uses = [], []
    for i, (lo, hi, k) in enumerate(((0.0, 0.9, 0.8), (0.9, 2.0, 1.25))):
        paths.append('<path id="vein%d" d="%s"/>' % (i, " ".join(smooth(p) for p, w in lines if lo <= w < hi)))
        for w, c, o in ((10 * k, "#ff2a12", 0.16), (5 * k, "#ff3a18", 0.45), (2.0 * k, "#ffa070", 0.95)):
            uses.append('<use xlink:href="#vein%d" href="#vein%d" fill="none" stroke="%s" stroke-width="%.1f" stroke-opacity="%.2f" stroke-linecap="round" stroke-linejoin="round"/>' % (i, i, c, w, o))
    return "".join(paths) + '<g id="veins">%s</g>' % "".join(uses)


def build() -> str:
    rng = random.Random(21)
    outer, inner = octagon(R_OUT), octagon(R_IN)
    petals = []
    for angle, length, width, bend in PETALS:
        petals.append((petal(angle, length, width, bend, rng.uniform(0, math.tau)), spine(angle, length, bend)))
    flesh_veins = vein_layers(veins(rng, (20, 20, 492, 500), 44.0, 6.0))
    core_veins = " ".join(smooth(p) for p, _ in veins(rng, (180, 170, 330, 330), 26.0, 4.0))
    # Verdigris: green-blue streaks running down from the bolts, and blooms
    # of it on the steel.
    patina = []
    for x, y in octagon((R_IN + R_OUT) / 2):
        for _ in range(3):
            patina.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="url(#drip)" opacity="%.2f"/>' % (x + rng.uniform(-16, 12), y - 4, rng.uniform(4, 9), rng.uniform(26, 60), rng.uniform(0.5, 0.9)))
    for _ in range(18):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(R_IN + 6, R_OUT - 6)
        patina.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="url(#patina)" opacity="%.2f"/>' % (CX + r * math.cos(a), CY + r * math.sin(a), rng.uniform(16, 30), rng.uniform(8, 14), rng.uniform(0.35, 0.7)))
    bolts = "".join('<circle cx="%.1f" cy="%.1f" r="7.5" fill="#11181b"/><circle cx="%.1f" cy="%.1f" r="5.5" fill="url(#bolt)"/>' % (x, y, x, y) for x, y in octagon((R_IN + R_OUT) / 2))

    svg = []
    add = svg.append
    add('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512" viewBox="0 0 512 512">')
    add("  <!-- Made by tools/make_icon.py: edit that and run it again. -->")
    add("  <defs>")
    add('    <clipPath id="tile"><rect x="16" y="16" width="480" height="480" rx="92"/></clipPath>')
    add('    <clipPath id="ring"><path d="%s %s" clip-rule="evenodd"/></clipPath>' % (poly(outer), poly(list(reversed(inner)))))
    for i, (pts, _) in enumerate(petals):
        add('    <clipPath id="petal%d"><path d="%s"/></clipPath>' % (i, poly(pts)))
    add('    <clipPath id="core"><circle cx="%.1f" cy="%.1f" r="%.1f"/></clipPath>' % CORE)
    add("    " + flesh_veins)
    add("""    <radialGradient id="bg" cx="0.5" cy="0.45" r="0.7">
      <stop offset="0" stop-color="#1d0c10"/>
      <stop offset="0.6" stop-color="#0a0d12"/>
      <stop offset="1" stop-color="#04060a"/>
    </radialGradient>
    <radialGradient id="chamber" gradientUnits="userSpaceOnUse" cx="256" cy="250" r="190">
      <stop offset="0" stop-color="#ff3b1c" stop-opacity="0.8"/>
      <stop offset="0.45" stop-color="#8a0f12" stop-opacity="0.5"/>
      <stop offset="1" stop-color="#05070a" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="steel" x1="0.1" y1="0" x2="0.9" y2="1">
      <stop offset="0" stop-color="#8a9aa0"/>
      <stop offset="0.4" stop-color="#4d5d62"/>
      <stop offset="1" stop-color="#1b2428"/>
    </linearGradient>
    <linearGradient id="drip" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7fe0c4"/>
      <stop offset="0.5" stop-color="#3fa58e" stop-opacity="0.7"/>
      <stop offset="1" stop-color="#2c7d6e" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="patina" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#5cc2a6"/>
      <stop offset="1" stop-color="#2c7d6e" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="bolt" cx="0.35" cy="0.35" r="0.7">
      <stop offset="0" stop-color="#e2f6ef"/>
      <stop offset="1" stop-color="#4a9384"/>
    </radialGradient>
    <radialGradient id="meat" gradientUnits="userSpaceOnUse" cx="256" cy="250" r="250">
      <stop offset="0" stop-color="#a01c2e"/>
      <stop offset="0.3" stop-color="#5a0b18"/>
      <stop offset="0.7" stop-color="#22040a"/>
      <stop offset="1" stop-color="#120205"/>
    </radialGradient>
    <radialGradient id="hot" gradientUnits="userSpaceOnUse" cx="246" cy="238" r="76">
      <stop offset="0" stop-color="#fff0cc"/>
      <stop offset="0.3" stop-color="#ff8a48"/>
      <stop offset="0.66" stop-color="#d02420"/>
      <stop offset="1" stop-color="#4a060e"/>
    </radialGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#ffb070" stop-opacity="0.85"/>
      <stop offset="0.4" stop-color="#ff4a22" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#ff2a10" stop-opacity="0"/>
    </radialGradient>
  </defs>""")
    add('  <g clip-path="url(#tile)">')
    add('  <rect x="16" y="16" width="480" height="480" fill="url(#bg)"/>')
    # The chamber behind the hatch, lit by the Heart.
    add('  <path d="%s" fill="#06080b"/>' % poly(inner))
    add('  <path d="%s" fill="url(#chamber)"/>' % poly(inner))
    # The hatch frame: steel gone green.
    add('  <g clip-path="url(#ring)">')
    add('    <rect x="0" y="0" width="512" height="512" fill="url(#steel)"/>')
    add("    " + "\n    ".join(patina))
    add("  </g>")
    add('  <path d="%s" fill="none" stroke="#c4e0d8" stroke-opacity="0.5" stroke-width="2.5"/>' % poly(octagon(R_OUT - 1.5)))
    add('  <path d="%s" fill="none" stroke="#090d10" stroke-width="5"/>' % poly(octagon(R_IN + 2.5)))
    add("  " + bolts)
    # The teal rim light round the inside of the hatch.
    add("  " + strokes(poly(octagon(R_IN - 3)), [(20, "#4fd6cf", 0.10), (10, "#5fe0d8", 0.24), (3.5, "#b0fff6", 0.95)]))
    # The petals, back to front: veined meat, a groove down the middle and a
    # wet rim.
    for i, (pts, groove) in enumerate(petals):
        d = poly(pts)
        add('  <path d="%s" fill="none" stroke="#070102" stroke-opacity="0.85" stroke-width="5" stroke-linejoin="round"/>' % d)
        add('  <g clip-path="url(#petal%d)">' % i)
        add('    <path d="%s" fill="url(#meat)"/>' % d)
        add('    <path d="%s" fill="none" stroke="#12020a" stroke-opacity="0.55" stroke-width="7" stroke-linecap="round"/>' % groove)
        add('    <path d="%s" fill="none" stroke="#0a0103" stroke-opacity="0.55" stroke-width="22" stroke-linejoin="round"/>' % d)
        add('    <use xlink:href="#veins" href="#veins"/>')
        add("  </g>")
        add('  <path d="%s" fill="none" stroke="#ff7a5a" stroke-opacity="0.35" stroke-width="1.6" stroke-linejoin="round"/>' % d)
    # The Heart itself, hot at the middle of them.
    add('  <circle cx="%.1f" cy="%.1f" r="150" fill="url(#glow)" opacity="0.7"/>' % CORE[:2])
    add('  <circle cx="%.1f" cy="%.1f" r="%.1f" fill="#2a0308"/>' % (CORE[0], CORE[1], CORE[2] + 4))
    add('  <g clip-path="url(#core)">')
    add('    <circle cx="%.1f" cy="%.1f" r="%.1f" fill="url(#hot)"/>' % CORE)
    add("    " + strokes(core_veins, [(4, "#7a0812", 0.35), (1.8, "#5a0610", 0.7)]))
    add('    <ellipse cx="236" cy="226" rx="20" ry="10" transform="rotate(-30 236 226)" fill="#ffffff" opacity="0.45"/>')
    add("  </g>")
    add("  </g>")
    add("</svg>")
    return "\n".join(svg) + "\n"


def main() -> None:
    svg = build()
    outs = [Path(a[6:]).resolve() for a in sys.argv if a.startswith("--out=")] or OUTPUTS
    for path in outs:
        path.write_text(svg)
        print("wrote", path)


if __name__ == "__main__":
    main()
