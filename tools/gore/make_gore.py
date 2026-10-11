"""Makes Verdigris Protocol's blood decals: splats, a pool and drag marks.

Run: python3 tools/gore/make_gore.py assets/gore
Each splat is a white-to-grey mask with alpha (the game tints it red for
blood, near black for ichor), plus an _orm.png that makes it wet.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/gore"
os.makedirs(OUT, exist_ok=True)
N = 256


def value_noise(size, cells, rng):
    g = rng.random((cells + 1, cells + 1))
    y, x = np.mgrid[0:size, 0:size] / size * cells
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def fbm(size, rng, octaves=5, base=4):
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(size, base * 2 ** o, rng) * amp
        total += amp
        amp *= 0.5
    return out / total


def save(name, field, shade):
    a = np.clip(field, 0, 1)
    rgb = np.clip(shade, 0, 1)
    img = np.dstack([rgb, rgb, rgb, a]) * 255
    Image.fromarray(img.astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    # Occlusion, roughness, metal: wet and glossy where it's thick.
    orm = np.dstack([np.ones_like(a), 0.15 + 0.4 * (1 - a), np.zeros_like(a), a]) * 255
    Image.fromarray(orm.astype(np.uint8), "RGBA").save(os.path.join(OUT, name + "_orm.png"))


y, x = (np.mgrid[0:N, 0:N] - N / 2) / (N / 2)
for k in range(4):
    rng = np.random.default_rng(11 + k)
    field = np.zeros((N, N))
    # A heavy middle and droplets thrown out from it.
    cx, cy = rng.normal(0, 0.06, 2)
    r = np.hypot(x - cx, y - cy)
    field += np.clip(1.4 - r / 0.42, 0, 1) ** 0.6
    for _ in range(26 + 6 * k):
        ang = rng.random() * math.tau
        d = rng.random() ** 0.7 * 0.85
        s = rng.random() ** 2 * 0.09 + 0.012
        px, py = cx + math.cos(ang) * d, cy + math.sin(ang) * d
        field += np.clip(1.5 - np.hypot(x - px, y - py) / s, 0, 1)
    n = fbm(N, rng)
    field = np.clip((field * 0.75 + n * 0.5 - 0.55) * 6, 0, 1)
    edge = np.clip(1 - np.hypot(x, y), 0, 1)
    field *= np.clip(edge * 4, 0, 1)
    shade = 0.55 + 0.45 * fbm(N, rng, 4, 8)
    save("splat_%d" % k, field, shade)

# A pool under a body: smooth, with a lumpy rim.
rng = np.random.default_rng(5)
n = fbm(N, rng, 4, 3)
r = np.hypot(x * 1.1, y)
field = np.clip((0.78 - r + (n - 0.5) * 0.35) * 14, 0, 1)
save("pool", field, 0.6 + 0.4 * fbm(N, rng, 3, 6))

# A drag mark: two smeared streaks down the texture.
rng = np.random.default_rng(9)
n = fbm(N, rng, 5, 6)
streak = np.exp(-((x * 3.5 + 0.3 * np.sin(y * 3)) ** 2) * 2.5)
field = np.clip((streak * (0.6 + 0.6 * n) - 0.35) * 3, 0, 1) * np.clip((1 - abs(y)) * 3, 0, 1)
save("drag", field, 0.5 + 0.5 * n)
print("wrote gore decals to", OUT)
