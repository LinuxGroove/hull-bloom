#!/usr/bin/env python3
"""Synthesizes Verdigris Protocol's procedural sound effects and fallback music.

    python3 tools/sfx/make_sfx.py <out_dir> [--wav <dir>] [--only name,name] [--music <dir>]

Every sound is built here from oscillators, noise, filters and envelopes (no
samples), with fixed random seeds from each sound's name, so the files can be
made again exactly. The building blocks come from Tiptoe's synthesizer, with
wet ones added for the Bloom: bubbles and gurgles, squelches, tearing
crackle, cracking bone, and rough voices made the way a throat makes them
(a train of glottal pulses through moving formants), for the Taken groaning
through the growth in their throats.

Each sound is rendered at 44.1 kHz mono, peak-normalised to about -3 dBFS,
written as a WAV in a temporary folder (or --wav) and encoded to Ogg Vorbis
with ffmpeg (-q:a 5). Names ending in _loop are built to loop seamlessly:
every oscillator runs a whole number of cycles, noise is filtered circularly
and events wrap around the end; they are encoded at -q:a 7, which keeps the
encoder's noise from leaving a tick at the seam.

Creature voices come in numbered takes (taken_idle_1, taken_idle_2, ...),
which Sfx picks among at random so a voice doesn't repeat itself; --only
taken_idle builds every take of it.

The music fallbacks (drone, hunted, title) play until real music exists. They
go to --music (default: a music folder beside out_dir, so assets/audio/sfx
puts them in assets/audio/music): stereo, seamless loops of slow drones and
pulses rather than tunes, turned down to a quiet loudness (LUFS) instead of
to a peak.

Needs numpy and ffmpeg (with libvorbis).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave
import zlib
from functools import lru_cache

import numpy as np

SR = 44100
TAU = 2 * np.pi
PEAK = 10 ** (-3 / 20)


# ---------------------------------------------------------------------------
# Building blocks (from Tiptoe)

def secs(seconds):
    return int(round(seconds * SR))


def timeline(seconds):
    return np.arange(secs(seconds)) / SR


def rng_for(name):
    """A random generator seeded from the sound's name, so every sound is repeatable."""
    return np.random.default_rng(zlib.crc32(name.encode()))


def env_ar(t, attack, tau, start=0.0):
    """Linear attack then exponential decay, silent before start."""
    u = t - start
    rise = np.clip(u / attack, 0, 1) if attack > 0 else 1.0
    return rise * np.exp(-np.maximum(u - attack, 0) / tau) * (u >= 0)


def bump(t, start, length, power=1.0):
    """A raised-sine swell from start to start + length, zero outside it."""
    p = np.clip((t - start) / length, 0, 1)
    return np.sin(np.pi * p) ** power


def curve(t, times, values):
    """Piecewise-linear breakpoint curve."""
    return np.interp(t, times, values)


def phase_of(freq):
    """Running phase of an oscillator whose frequency (Hz) changes per sample."""
    return TAU * (np.cumsum(freq) - freq[0]) / SR


def modes(t, freqs, amps, taus, start=0.0):
    """Struck resonances: decaying sines that start at zero phase (no click)."""
    u = np.maximum(t - start, 0)
    out = np.zeros_like(t)
    for f, a, tau in zip(freqs, amps, taus):
        out += a * np.sin(TAU * f * u) * np.exp(-u / tau)
    return out * (t >= start)


def place(buf, x, at, wrap=False):
    """Mixes x into buf at time `at`; with wrap, anything past the end comes round to the start."""
    i = secs(at)
    if wrap:
        np.add.at(buf, (i + np.arange(len(x))) % len(buf), x)
    else:
        j = min(len(buf), i + len(x))
        if j > i:
            buf[i:j] += x[:j - i]
    return buf


def convolve(x, ir, circular=False):
    """FFT convolution. Circular convolution keeps a loop seamless."""
    if circular:
        n = len(x)
        folded = np.zeros(n)
        np.add.at(folded, np.arange(len(ir)) % n, ir)
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(folded), n)
    n = len(x) + len(ir) - 1
    nfft = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:len(x)]


@lru_cache(maxsize=None)
def _biquad_ir(kind, f, q):
    """Impulse response of an RBJ-cookbook biquad (lowpass, highpass or 0 dB-peak bandpass)."""
    w = TAU * f / SR
    cw, alpha = np.cos(w), np.sin(w) / (2 * q)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    else:
        b = [alpha, 0.0, -alpha]
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2 = (v / a0 for v in b)
    a1, a2 = a1 / a0, a2 / a0
    n = min(2 * SR, int(12 * q * SR / (np.pi * max(f, 20))) + 1024)
    y = [0.0] * n
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        x0 = 1.0 if i == 0 else 0.0
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = y0
        x2, x1, y2, y1 = x1, x0, y1, y0
    return np.array(y)


def lowpass(x, f, q=0.707, circular=False):
    return convolve(x, _biquad_ir("lp", float(f), float(q)), circular)


def highpass(x, f, q=0.707, circular=False):
    return convolve(x, _biquad_ir("hp", float(f), float(q)), circular)


def bandpass(x, f, q=1.0, circular=False):
    return convolve(x, _biquad_ir("bp", float(f), float(q)), circular)


def svf(x, fc, q, mode="bp"):
    """State-variable filter whose cutoff can move every sample (for sweeps and moving formants)."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    g = np.tan(np.pi * np.clip(fc, 20, SR * 0.45) / SR)
    k = 1 / q
    a1 = 1 / (1 + g * (g + k))
    a2, a3 = g * a1, g * g * a1
    ic1 = ic2 = 0.0
    out = [0.0] * len(x)
    want_bp = mode == "bp"
    for i, (v0, c1, c2, c3) in enumerate(zip(x.tolist(), a1.tolist(), a2.tolist(), a3.tolist())):
        v3 = v0 - ic2
        v1 = c1 * ic1 + c2 * v3
        v2 = ic2 + c2 * ic1 + c3 * v3
        ic1, ic2 = 2 * v1 - ic1, 2 * v2 - ic2
        out[i] = k * v1 if want_bp else v2
    return np.array(out)


def smooth(x, seconds):
    """Hann-window moving average (centred), for gliding pitch, formant and level targets."""
    n = max(3, int(seconds * SR) | 1)
    kernel = np.hanning(n)
    kernel /= kernel.sum()
    padded = np.pad(x, n, mode="edge")
    return convolve(padded, kernel)[n + n // 2:n + n // 2 + len(x)]


def wobble(rng, n, seconds):
    """Slow random wander with unit spread, for jitter and drift."""
    w = smooth(rng.standard_normal(n), seconds)
    return w / (w.std() + 1e-12)


def loop_noise(rng, n, shape):
    """Noise of length n shaped in the frequency domain by shape(freqs); periodic, so it loops."""
    spectrum = np.fft.rfft(rng.standard_normal(n)) * shape(np.fft.rfftfreq(n, 1 / SR))
    y = np.fft.irfft(spectrum, n)
    return y / (y.std() + 1e-12)


def lp_mag(f, fc, order=2):
    return 1 / np.sqrt(1 + (f / fc) ** (2 * order))


def hp_mag(f, fc, order=2):
    return 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def bp_mag(f, fc, q):
    """A resonant peak's magnitude at f: 1 at fc, falling away with the bandwidth fc / q."""
    return 1 / np.sqrt(1 + (q * (f / fc - fc / np.maximum(f, 1e-3))) ** 2)


def click(rng, t, start, decay=0.001, hp=3000):
    """A tiny bright noise tick (the contact of metal or plastic)."""
    return highpass(rng.standard_normal(len(t)) * env_ar(t, 0.0002, decay, start), hp)


def formant_voice(f0, formants, bandwidths, amp, weights=(1.0, 0.5, 0.25),
                  tilt=1.0, fmax=5000.0, sub=0.0):
    """Additive voiced sound: harmonics of a gliding f0 shaped by moving formant peaks.

    formants is a list of per-sample formant frequency tracks; sub adds the
    harmonics of f0/2 at that level for a rough, period-doubled growl. The
    result is scaled by the harmonics' total gain, so the loudness follows amp
    instead of jumping when a harmonic lands on a formant.
    """
    phase = phase_of(f0)
    step = 0.5 if sub else 1.0
    out = np.zeros_like(f0)
    power = np.zeros_like(f0)
    for k in range(1, int(fmax / (f0.min() * step)) + 1):
        h = k * step
        fk = h * f0
        gain = 0.02 + sum(w / (1 + ((fk - F) / (0.5 * B)) ** 2)
                          for F, B, w in zip(formants, bandwidths, weights))
        gain = gain * h ** -tilt * np.clip((fmax - fk) / 600, 0, 1)
        if sub and k % 2:
            gain = gain * sub
        out += gain * np.sin(h * phase)
        power += gain * gain
    return out / np.sqrt(power) * amp


def creak(rng, t, start, length, rate0, rate1, freqs, q=20.0):
    """A hinge creak: a speeding-up stick-slip pulse train ringing a few resonances."""
    pulses = np.zeros_like(t)
    at = start
    while at < start + length:
        p = (at - start) / length
        i = secs(at)
        if i < len(t):
            pulses[i] += np.sin(np.pi * p) ** 0.7 * rng.uniform(0.55, 1.0)
        at += 1 / (rate0 + (rate1 - rate0) * p) * (1 + rng.uniform(-0.18, 0.18))
    ir_t = timeline(0.12)
    ir = modes(ir_t, freqs, rng.uniform(0.5, 1.0, len(freqs)), [q / (np.pi * f) for f in freqs])
    return convolve(pulses, ir)


# ---------------------------------------------------------------------------
# Wet things: bubbles, drips, squelches, tearing, bone

def bubble(f0, tau, xi=0.1, amp=1.0):
    """One bubble in liquid: a sine whose pitch rises as it dies away (Van den Doel's model).

    xi is how far it rises; small for gurgles, large for the "plink" of a drip.
    """
    t = timeline(min(6 * tau, 1.0))
    ph = TAU * f0 * (t + 0.5 * (xi / tau) * t * t)
    return amp * np.sin(ph) * np.exp(-t / tau) * np.clip(t / 0.0005, 0, 1)


def gurgle(rng, buf, start, length, rate, f_lo, f_hi, tau=(0.004, 0.015), xi=(0.05, 0.3),
           level=1.0, shape=None, wrap=False):
    """Bubbles at random times (rate per second) with pitches between f_lo and f_hi.

    shape (0..1 over the length, a callable of p) thins them out and quietens
    them where it is low.
    """
    for _ in range(rng.poisson(rate * length)):
        p = rng.uniform(0, 1)
        s = 1.0 if shape is None else float(shape(p))
        if rng.uniform() > s:
            continue
        f0 = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        b = bubble(f0, rng.uniform(*tau), rng.uniform(*xi), level * s * rng.uniform(0.3, 1.0))
        place(buf, b, start + p * length, wrap)
    return buf


def drip(rng, f0=None, amp=1.0):
    """A drop landing in a puddle: a soft tap and a rising "plink"."""
    f0 = f0 or rng.uniform(900, 2400)
    b = bubble(f0, rng.uniform(0.012, 0.035), rng.uniform(0.4, 1.2))
    t = timeline(len(b) / SR)
    tap = 0.15 * highpass(rng.standard_normal(len(t)) * env_ar(t, 0.0002, 0.0015), 1500)
    return amp * (b + tap)


def squelch(rng, length, f0, f1, q=4.0, power=1.0, flutter=0.6):
    """A wet squelch: noise through a resonant band that sweeps from f0 to f1, in a swell,
    fluttering as the flesh sticks and lets go."""
    t = timeline(length)
    p = t / length
    fc = f0 * (f1 / f0) ** p
    noise = rng.standard_normal(len(t))
    x = svf(noise, fc, q) * np.sin(np.pi * p) ** power
    x *= np.clip(1 + flutter * wobble(rng, len(t), 0.004), 0, None)
    return x / (np.abs(x).max() + 1e-12)


def crackle(rng, length, rate0, rate1, f_lo, f_hi, tau=(0.0008, 0.003), shape=None):
    """Tearing: a run of tiny ringing ticks whose density goes from rate0 to rate1 per second."""
    out = np.zeros(secs(length) + secs(0.03))
    tick_t = timeline(0.025)
    at = 0.0
    while True:
        p = at / length
        at += rng.exponential(1 / max(rate0 + (rate1 - rate0) * p, 1.0))
        if at >= length:
            break
        f = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        d = rng.uniform(*tau)
        a = rng.uniform(0.2, 1.0) * (1.0 if shape is None else float(shape(at / length)))
        place(out, a * modes(tick_t, [f, f * 1.63], [1.0, 0.4], [d, d * 0.6]), at)
    return out / (np.abs(out).max() + 1e-12)


def crack(rng, t, start, pitch=1.0):
    """A bone (or a shell) snapping: a hard click, a split-second splinter and a woody knock."""
    snap = click(rng, t, start, 0.0012, 1200)
    splinter = bandpass(rng.standard_normal(len(t)) * env_ar(t, 0.0003, 0.01, start), 2600 * pitch, 0.9)
    freqs = np.array([380, 720, 1150, 1900]) * pitch * rng.uniform(0.92, 1.08, 4)
    knock = modes(t, freqs, [1.0, 0.7, 0.45, 0.3], [0.03, 0.02, 0.012, 0.008], start)
    return 1.4 * snap + 1.2 * splinter + 0.8 * knock


def thump(rng, t, start, f_hi=110.0, f_lo=45.0, tau=0.12, slap=0.5):
    """A body or a heavy thing hitting the deck: a falling low thud and a dull slap."""
    u = np.maximum(t - start, 0)
    body = np.sin(phase_of(f_lo + (f_hi - f_lo) * np.exp(-u / 0.03))) * env_ar(t, 0.002, tau, start)
    hit = lowpass(rng.standard_normal(len(t)) * env_ar(t, 0.0005, 0.015, start), 1800)
    return body + slap * hit / (np.abs(hit).max() + 1e-12)


def splat(rng, t, start, size=1.0):
    """Something wet hitting the floor: a slap, a short squelch and droplets."""
    out = 0.8 * lowpass(rng.standard_normal(len(t)) * env_ar(t, 0.0004, 0.018 * size, start), 2600)
    out = out / (np.abs(out).max() + 1e-12)
    place(out, 0.5 * squelch(rng, 0.12 * size, 900, 350, 3.0), start + 0.004)
    for _ in range(int(5 * size)):
        place(out, drip(rng, rng.uniform(1400, 3200), rng.uniform(0.08, 0.25)), start + rng.uniform(0.02, 0.2 * size))
    return out


def deck_ring(t, start, level=1.0):
    """The deck plate under a body ringing faintly."""
    return level * modes(t, [178, 403, 761, 1210], [1.0, 0.6, 0.35, 0.2], [0.18, 0.12, 0.07, 0.04], start)


def reverb_ir(rng, seconds, bright=4500.0, metal=0.0, predelay=0.006):
    """A room's impulse response: decaying noise whose highs die first, plus ringing metal
    modes for the station's steel corridors when metal > 0. Normalised to unit energy."""
    t = timeline(seconds)
    tau = seconds / 6.9
    lo = lowpass(rng.standard_normal(len(t)), bright) * np.exp(-t / tau)
    hi = highpass(rng.standard_normal(len(t)), bright) * np.exp(-t / (tau / 3))
    ir = lo + 0.4 * hi
    if metal:
        freqs = rng.uniform(300, 3200, 12)
        ring = modes(t, freqs, rng.uniform(0.3, 1.0, 12), rng.uniform(0.05, 0.25, 12) * seconds)
        ir += metal * ring / (np.abs(ring).max() + 1e-12) * np.abs(lo).max()
    ir *= np.clip((t - predelay) / 0.004, 0, 1)
    return ir / np.sqrt(np.sum(ir ** 2))


def room(rng, x, seconds=0.5, wet=0.2, bright=4500.0, metal=0.0, circular=False):
    """Puts x in a room: the dry sound plus `wet` of its reverb."""
    return x + wet * convolve(x, reverb_ir(rng, seconds, bright, metal), circular)


# ---------------------------------------------------------------------------
# Voices: a pulse train through moving formants

VOWEL = {  # formants of a man's vowels (Hz)
    "a": (730, 1090, 2440),    # father
    "ae": (660, 1720, 2410),   # cat
    "uh": (640, 1190, 2390),   # cut
    "o": (570, 840, 2410),     # thought
    "u": (300, 870, 2240),     # boot
    "e": (530, 1840, 2480),    # bed
    "i": (270, 2290, 3010),    # beet
    "er": (490, 1350, 1690),   # bird
    "m": (270, 1050, 2350),    # a hum through the nose
    "h": (600, 1500, 2600),    # a rasp at the back of the throat
}


def vowels(t, marks, names, glide=0.05, scale=1.0):
    """Formant tracks that hold names[i] from marks[i] and glide between them."""
    F = np.zeros((3, len(t)))
    for at, name in zip(marks, names):
        F[:, t >= at] = np.array(VOWEL[name], dtype=float)[:, None] * scale
    return [smooth(F[k], glide) for k in range(3)]


def throat(rng, f0, formants, level, air=0.25, bws=(110, 140, 220), weights=(1.0, 0.55, 0.3),
           jitter=0.03, shimmer=0.15, sub=0.0, tilt=300.0, wet=0.0, bubbles=0.0, lp=3500.0):
    """A rough voice built the way a throat makes one: a pulse per glottal period, with
    jitter (wavering period), shimmer (wavering strength) and sub (every other pulse
    weaker: a growl an octave down), plus breath, through moving formant resonances.

    level shapes the voiced part; air is the breath's own level (a curve, or a number
    times level). wet gargles the sound (a fast, uneven flutter) and bubbles puts liquid
    in the throat, both for things with growth where their voice should be.
    """
    n = len(f0)
    level = np.asarray(level, dtype=float)
    fj = f0 * (1 + np.asarray(jitter) * wobble(rng, n, 0.002))
    ph = np.cumsum(fj) / SR
    idx = np.nonzero(np.diff(np.floor(ph)))[0] + 1
    amp = level[idx] * np.clip(1 + shimmer * rng.standard_normal(len(idx)), 0.05, 2.5)
    sub = np.broadcast_to(np.asarray(sub, dtype=float), (n,))
    amp[1::2] *= 1 - sub[idx[1::2]]
    # Each pulse lands between two samples: share it between them, so high voices
    # keep a clean pitch instead of jittering to the nearest sample.
    late = np.clip((ph[idx] - np.floor(ph[idx])) * SR / fj[idx], 0, 1)
    src = np.zeros(n)
    np.add.at(src, idx, amp * (1 - late))
    np.add.at(src, idx - 1, amp * late)
    # The glottis rounds each pulse off: a gentle slope down above `tilt`.
    k = SR / (TAU * tilt)
    src = highpass(convolve(src, np.exp(-np.arange(int(8 * k) + 1) / k)), 50)
    on = level > 0.1 * max(level.max(), 1e-9)
    if on.any():
        src /= np.sqrt(np.mean(src[on] ** 2)) + 1e-12
    breath = air * level if np.isscalar(air) else np.asarray(air, dtype=float)
    pulse = 0.35 + 0.65 * (0.5 + 0.5 * np.cos(TAU * ph)) ** 2
    src = src + 0.8 * rng.standard_normal(n) * breath * pulse
    if bubbles:
        liquid = gurgle(rng, np.zeros(n), 0.0, n / SR, 70 * bubbles, 140, 700, level=2.0)
        src += liquid * np.maximum(level, breath)
    if np.any(wet):
        gargle = 0.5 + 0.5 * np.tanh(3 * wobble(rng, n, 0.009))
        src *= 1 - wet * gargle
    out = sum(w * svf(src, F, float(np.mean(F)) / B) for F, B, w in zip(formants, bws, weights))
    return lowpass(out, lp)


def norm(x):
    return x / (np.abs(x).max() + 1e-12)


def grit(x, drive):
    """Soft clipping: the strain of a voice pushed too hard."""
    return np.tanh(drive * norm(x)) / np.tanh(drive)


# ---------------------------------------------------------------------------
# Clicks, chitters, squeals and whines for the Bloom's spawn

def tick(rng, f, tau, bright=1.0):
    """One chitinous click: a few ringing modes and a spit of noise."""
    t = timeline(max(0.012, 8 * tau))
    ring = modes(t, [f, f * 1.47, f * 2.09], [1.0, 0.6 * bright, 0.35 * bright], [tau, tau * 0.7, tau * 0.5])
    return ring + 0.4 * click(rng, t, 0.0, tau * 0.3, 1500)


def chitter(rng, buf, start, length, rate0, rate1, f_lo, f_hi, tau=(0.0015, 0.004), level=1.0,
            shape=None, wrap=False):
    """A run of clicks (mandibles, legs, feelers) whose rate goes from rate0 to rate1."""
    at = start
    while True:
        p = (at - start) / length
        at += rng.exponential(0.35 / max(rate0 + (rate1 - rate0) * p, 1.0)) + 0.65 / max(rate0 + (rate1 - rate0) * p, 1.0)
        if at >= start + length:
            break
        s = 1.0 if shape is None else float(shape((at - start) / length))
        f = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        place(buf, level * s * rng.uniform(0.4, 1.0) * tick(rng, f, rng.uniform(*tau)), at, wrap)
    return buf


def rattle_gate(rng, t, hz, depth, jitter=0.12):
    """A rattling flutter: the level chopped at about `hz`, unevenly."""
    ph = phase_of(hz * (1 + jitter * wobble(rng, len(t), 0.02)))
    gate = smooth((np.sin(ph) > 0).astype(float), 0.25 / hz / 2)
    return 1 - depth * (1 - gate)


def squeal(rng, t, f, level, partials=(1.0, 0.45, 0.25, 0.12), vibrato=0.01, vib_hz=7.0):
    """A thin tonal squeal or whine on a pitch track."""
    fj = f * (1 + vibrato * np.sin(phase_of(np.full(len(t), vib_hz))) + 0.006 * wobble(rng, len(t), 0.01))
    ph = phase_of(fj)
    return level * sum(a * np.sin((k + 1) * ph) for k, a in enumerate(partials))


def hiss(rng, n, lo, hi, level=1.0):
    """Band-limited noise between lo and hi Hz."""
    return level * lowpass(highpass(rng.standard_normal(n), lo), hi)


def whoosh(rng, length, f0, f1, q=1.2, power=1.5):
    """Air rushing past: noise through a band that sweeps from f0 to f1."""
    t = timeline(length)
    p = t / length
    return norm(svf(rng.standard_normal(len(t)), f0 * (f1 / f0) ** p, q) * np.sin(np.pi * p) ** power)


# ---------------------------------------------------------------------------
# The Taken: crew with the Bloom in their throats

def taken_idle(rng, take):
    """A low wet moan; a rattling breath; and a slurred try at a word ("Mah... ree...")."""
    if take == 0:
        t = timeline(2.4)
        n = len(t)
        f0 = curve(t, [0, 0.4, 1.2, 2.0, 2.4], [70, 82, 76, 63, 56]) * (1 + 0.02 * wobble(rng, n, 0.15))
        level = curve(t, [0, 0.35, 0.65, 1.5, 2.1, 2.4], [0, 0.6, 1.0, 0.8, 0.25, 0])
        F = vowels(t, [0, 0.5, 1.3], ["u", "uh", "o"], 0.25, 0.9)
        v = throat(rng, f0, F, level, air=0.45, jitter=curve(t, [0, 1.5, 2.4], [0.03, 0.05, 0.12]),
                   shimmer=0.3, sub=curve(t, [0, 1.4, 2.4], [0.1, 0.2, 0.6]), tilt=220, wet=0.5,
                   bubbles=0.8, lp=2200)
        return room(rng, norm(v), 0.5, 0.15, metal=0.3)
    if take == 1:
        t = timeline(2.2)
        n = len(t)
        breath_in = bump(t, 0.05, 0.85, 0.8)
        breath_out = bump(t, 1.0, 1.1, 1.2)
        f0 = curve(t, [0, 0.9, 1.0, 2.2], [42, 48, 78, 64])
        level = 0.25 * breath_in + 0.7 * breath_out
        F = vowels(t, [0, 1.0], ["h", "uh"], 0.08, 0.85)
        v = throat(rng, f0, F, level, air=0.9 * breath_in + 0.7 * breath_out, jitter=0.12, shimmer=0.45,
                   sub=0.4, tilt=200, wet=0.75, bubbles=1.5, lp=2600)
        return room(rng, norm(v), 0.5, 0.15, metal=0.3)
    t = timeline(2.3)
    n = len(t)
    f0 = curve(t, [0, 0.1, 0.3, 0.7, 1.0, 1.1, 1.45, 2.3], [88, 90, 100, 86, 84, 92, 80, 60])
    f0 *= 1 + 0.015 * wobble(rng, n, 0.08)
    level = curve(t, [0, 0.1, 0.2, 0.3, 0.7, 0.85, 0.95, 1.08, 1.4, 1.9, 2.3],
                  [0, 0.45, 0.5, 1.0, 0.85, 0.15, 0.2, 0.75, 0.7, 0.2, 0])
    F = vowels(t, [0, 0.22, 0.8, 1.0, 1.08, 1.5], ["m", "a", "uh", "er", "i", "uh"], 0.04, 0.9)
    v = throat(rng, f0, F, level, air=0.35, jitter=0.035, shimmer=0.2, sub=curve(t, [0, 1.3, 2.3], [0.1, 0.15, 0.5]),
               tilt=260, wet=curve(t, [0, 0.75, 0.9, 1.0, 1.5, 2.3], [0.2, 0.2, 0.9, 0.3, 0.3, 0.8]),
               bubbles=0.6, lp=2400)
    return room(rng, norm(v), 0.5, 0.15, metal=0.3)


def taken_alert(rng, take):
    """It has seen you: a wet gasp into a rising snarl; a choke into "GHAA"; a long rising groan."""
    if take == 0:
        t = timeline(1.35)
        n = len(t)
        gasp = bump(t, 0.0, 0.24, 0.7)
        f0 = curve(t, [0, 0.25, 0.55, 0.9, 1.25], [100, 115, 170, 150, 118]) * (1 + 0.02 * wobble(rng, n, 0.03))
        level = curve(t, [0, 0.24, 0.36, 0.9, 1.25, 1.35], [0, 0, 1.0, 0.9, 0, 0])
        F = vowels(t, [0, 0.25, 0.5, 0.9], ["h", "uh", "a", "ae"], 0.06, 0.92)
        v = throat(rng, f0, F, level, air=0.8 * gasp + 0.5 * level, jitter=0.06, shimmer=0.25, sub=0.45,
                   tilt=500, wet=0.4, bubbles=0.6, lp=3400)
        return room(rng, grit(v, 2.2), 0.5, 0.15, metal=0.3)
    if take == 1:
        t = timeline(1.15)
        n = len(t)
        cough = env_ar(t, 0.004, 0.05, 0.02)
        f0 = curve(t, [0, 0.12, 0.35, 0.8, 1.1], [130, 135, 190, 165, 125]) * (1 + 0.025 * wobble(rng, n, 0.02))
        level = curve(t, [0, 0.1, 0.18, 0.75, 1.05, 1.15], [0, 0, 1.0, 0.85, 0, 0])
        F = vowels(t, [0, 0.12, 0.6], ["h", "a", "ae"], 0.05, 0.92)
        v = throat(rng, f0, F, level, air=1.5 * cough + 0.45 * level, jitter=0.07, shimmer=0.3, sub=0.5,
                   tilt=550, wet=0.5, bubbles=0.8, lp=3400)
        return room(rng, grit(v, 2.5), 0.5, 0.15, metal=0.3)
    t = timeline(1.5)
    n = len(t)
    f0 = curve(t, [0, 0.3, 0.9, 1.4], [82, 100, 140, 122]) * (1 + 0.03 * wobble(rng, n, 0.05))
    level = curve(t, [0, 0.15, 0.9, 1.2, 1.5], [0, 0.6, 1.0, 0.7, 0])
    F = vowels(t, [0, 0.45, 0.95], ["u", "uh", "er"], 0.15, 0.9)
    v = throat(rng, f0, F, level, air=0.45, jitter=0.06, shimmer=0.3, sub=curve(t, [0, 0.8, 1.5], [0.2, 0.45, 0.35]),
               tilt=380, wet=0.6, bubbles=1.0, lp=2800)
    return room(rng, grit(v, 1.8), 0.5, 0.15, metal=0.3)


def taken_attack(rng, take):
    """A lunge: "RRAAGH!" ending on a snap of teeth; a spraying "HHAAH!"; a snarl."""
    if take == 0:
        t = timeline(0.85)
        n = len(t)
        f0 = curve(t, [0, 0.15, 0.6], [150, 190, 135]) * (1 + 0.03 * wobble(rng, n, 0.015))
        level = curve(t, [0, 0.04, 0.5, 0.62, 0.85], [0, 1.0, 0.9, 0, 0])
        F = vowels(t, [0, 0.08], ["uh", "a"], 0.04, 0.95)
        v = grit(throat(rng, f0, F, level, air=0.6, jitter=0.07, shimmer=0.3, sub=0.5, tilt=700, wet=0.3,
                        bubbles=0.4, lp=3800), 3.0)
        teeth = modes(t, [1900, 2900, 4300], [1.0, 0.6, 0.3], [0.008, 0.006, 0.004], 0.63) + click(rng, t, 0.63, 0.001, 1500)
        return room(rng, v + 0.5 * norm(teeth), 0.5, 0.15, metal=0.3)
    if take == 1:
        t = timeline(0.7)
        n = len(t)
        f0 = curve(t, [0, 0.1, 0.5], [175, 168, 138])
        level = curve(t, [0, 0.03, 0.35, 0.5, 0.7], [0, 0.7, 0.6, 0, 0])
        air = curve(t, [0, 0.02, 0.2, 0.55, 0.7], [0, 1.4, 0.9, 0, 0])
        F = vowels(t, [0], ["a"], 0.04, 0.95)
        v = grit(throat(rng, f0, F, level, air=air, jitter=0.08, shimmer=0.3, sub=0.4, tilt=600, wet=0.5,
                        bubbles=1.0, lp=4000), 2.5)
        spray = np.zeros(n)
        for _ in range(9):
            place(spray, drip(rng, rng.uniform(1800, 3600), rng.uniform(0.1, 0.3)), rng.uniform(0.05, 0.4))
        return room(rng, v + 0.4 * spray, 0.5, 0.15, metal=0.3)
    t = timeline(0.95)
    n = len(t)
    f0 = curve(t, [0, 0.3, 0.8], [118, 128, 110]) * rattle_gate(rng, t, 28, 0.05)
    level = curve(t, [0, 0.05, 0.3, 0.75, 0.95], [0, 0.8, 1.0, 0.3, 0]) * rattle_gate(rng, t, 26, 0.4)
    F = vowels(t, [0, 0.25], ["er", "a"], 0.08, 0.9)
    v = grit(throat(rng, f0, F, level, air=0.5, jitter=0.1, shimmer=0.35, sub=0.6, tilt=500, wet=0.45,
                    bubbles=0.6, lp=3200), 2.8)
    return room(rng, v, 0.5, 0.15, metal=0.3)


def taken_hurt(rng, take):
    """Shot: "UGH" and a wet cough; a yelp choked off by fluid; a strained "HNNGH" and a splutter."""
    if take == 0:
        t = timeline(0.7)
        n = len(t)
        f0 = curve(t, [0, 0.25, 0.7], [165, 105, 95])
        level = curve(t, [0, 0.02, 0.18, 0.28, 0.7], [0, 1.0, 0.7, 0, 0])
        cough = env_ar(t, 0.004, 0.06, 0.34)
        F = vowels(t, [0, 0.3], ["uh", "h"], 0.04, 0.92)
        v = throat(rng, f0, F, level + 0.3 * cough, air=0.4 * level + 1.2 * cough, jitter=0.05, sub=0.25,
                   tilt=450, wet=curve(t, [0, 0.3, 0.7], [0.3, 0.8, 0.8]), bubbles=1.0, lp=3200)
        return room(rng, grit(v, 2.0), 0.4, 0.12, metal=0.3)
    if take == 1:
        t = timeline(0.6)
        n = len(t)
        f0 = curve(t, [0, 0.08, 0.4], [215, 230, 150])
        level = curve(t, [0, 0.02, 0.3, 0.42, 0.6], [0, 1.0, 0.8, 0, 0])
        F = vowels(t, [0, 0.3], ["a", "uh"], 0.05, 0.95)
        v = throat(rng, f0, F, level, air=0.45, jitter=0.06, sub=curve(t, [0, 0.25, 0.4], [0.2, 0.2, 0.7]),
                   tilt=600, wet=curve(t, [0, 0.22, 0.4], [0.2, 0.3, 0.95]), bubbles=1.5, lp=3600)
        return room(rng, grit(v, 2.2), 0.4, 0.12, metal=0.3)
    t = timeline(0.7)
    n = len(t)
    f0 = curve(t, [0, 0.2, 0.45], [140, 128, 108])
    level = curve(t, [0, 0.03, 0.19, 0.24, 0.38, 0.5, 0.7], [0, 0.6, 0.7, 1.0, 0.8, 0, 0])
    splutter = bump(t, 0.4, 0.25, 0.5) * rattle_gate(rng, t, 18, 0.8)
    F = vowels(t, [0, 0.21], ["m", "uh"], 0.03, 0.92)
    v = throat(rng, f0, F, level, air=0.35 * level + 0.9 * splutter, jitter=0.08, sub=0.3, tilt=450,
               wet=0.5, bubbles=1.2, lp=3200)
    return room(rng, grit(v, 2.0), 0.4, 0.12, metal=0.3)


def taken_rise(rng):
    """A body peeling up off a wet floor: sticky tearing and squelches, coveralls rustling,
    a long groan, and a foot slapping down in the wet."""
    t = timeline(2.5)
    n = len(t)
    peel = np.zeros(n)
    place(peel, crackle(rng, 1.0, 120, 450, 280, 1500, (0.002, 0.006), shape=lambda p: np.sin(np.pi * p) ** 0.5), 0.02)
    place(peel, 0.8 * squelch(rng, 0.5, 380, 900, 5.0), 0.1)
    place(peel, 0.7 * squelch(rng, 0.45, 700, 300, 4.0), 0.55)
    place(peel, 0.9 * bubble(170, 0.03, 1.2), 1.0)
    for _ in range(7):
        place(peel, drip(rng, amp=rng.uniform(0.2, 0.5)), rng.uniform(1.05, 1.7))
    cloth = hiss(rng, n, 900, 5000) * np.abs(wobble(rng, n, 0.006)) * bump(t, 0.2, 1.1, 0.7)
    f0 = curve(t, [0.35, 0.8, 1.3, 2.0, 2.5], [66, 84, 80, 68, 60]) * (1 + 0.02 * wobble(rng, n, 0.1))
    level = curve(t, [0, 0.4, 0.8, 1.3, 2.0, 2.45, 2.5], [0, 0, 0.7, 1.0, 0.6, 0, 0])
    F = vowels(t, [0, 0.9, 1.6], ["uh", "o", "u"], 0.2, 0.9)
    groan = throat(rng, f0, F, level, air=0.45, jitter=0.06, shimmer=0.3, sub=0.25, tilt=240, wet=0.5,
                   bubbles=0.8, lp=2200)
    step = thump(rng, t, 1.6, 120, 55, 0.08, 0.6) + 0.6 * splat(rng, t, 1.6, 0.8)
    out = 0.65 * norm(peel) + 0.18 * norm(cloth) + 0.9 * norm(groan) + 0.5 * norm(step)
    return room(rng, out, 0.6, 0.18, metal=0.3)


def taken_die(rng):
    """A gurgling collapse: a choked groan going down, knees, the body, an arm, and a last
    bubbling breath."""
    t = timeline(2.5)
    n = len(t)
    f0 = curve(t, [0, 0.3, 0.9, 1.1], [112, 95, 62, 50]) * (1 + 0.03 * wobble(rng, n, 0.03))
    level = curve(t, [0, 0.03, 0.5, 1.0, 1.15, 1.6, 1.75, 2.2, 2.5], [0, 1.0, 0.75, 0.3, 0, 0, 0.15, 0, 0])
    air = curve(t, [0, 0.03, 0.9, 1.1, 1.6, 1.8, 2.4, 2.5], [0, 0.5, 0.3, 0, 0, 0.6, 0, 0])
    F = vowels(t, [0, 0.45, 1.6], ["uh", "u", "h"], 0.15, 0.88)
    groan = throat(rng, f0, F, level, air=air, jitter=curve(t, [0, 1.0], [0.05, 0.15]), shimmer=0.4, sub=0.45,
                   tilt=300, wet=0.75, bubbles=2.0, lp=2400)
    liquid = gurgle(rng, np.zeros(n), 0.1, 1.1, 55, 150, 600, level=1.0)
    gurgle(rng, liquid, 1.4, 0.8, 22, 140, 500, level=0.6, shape=lambda p: 1 - p)
    fall = thump(rng, t, 0.85, 100, 60, 0.07, 0.5)
    fall += 1.4 * thump(rng, t, 1.15, 90, 42, 0.16, 0.7) + 0.7 * splat(rng, t, 1.15, 1.2)
    fall += 0.5 * thump(rng, t, 1.42, 140, 70, 0.05, 0.6) + 0.35 * splat(rng, t, 1.42, 0.6)
    fall += deck_ring(t, 1.15, 0.35)
    out = 0.9 * norm(groan) + 0.35 * norm(liquid) + 0.8 * norm(fall)
    return room(rng, out, 0.6, 0.18, metal=0.3)


def sever(rng):
    """A limb coming off: a bone cracks, flesh tears, a gush, and the limb hits the deck."""
    t = timeline(1.1)
    n = len(t)
    bone = crack(rng, t, 0.0) + 0.5 * crack(rng, t, 0.045, 1.3)
    tear = np.zeros(n)
    place(tear, crackle(rng, 0.38, 900, 2600, 900, 4200, shape=lambda p: 1 - 0.7 * p), 0.015)
    place(tear, 0.9 * squelch(rng, 0.42, 600, 1400, 4.0), 0.02)
    place(tear, 0.7 * squelch(rng, 0.3, 1000, 380, 3.0), 0.2)
    gush = norm(lowpass(rng.standard_normal(n), 900) * (env_ar(t, 0.01, 0.08, 0.05) + 0.6 * env_ar(t, 0.01, 0.07, 0.22)))
    gush += 0.6 * norm(gurgle(rng, np.zeros(n), 0.06, 0.45, 90, 220, 900))
    land = thump(rng, t, 0.64, 130, 70, 0.07, 0.6) + 0.8 * splat(rng, t, 0.64, 0.9)
    land += 0.4 * thump(rng, t, 0.8, 160, 85, 0.04, 0.5) + deck_ring(t, 0.64, 0.25)
    out = 1.0 * norm(bone) + 0.7 * norm(tear) + 0.45 * norm(gush) + 0.6 * norm(land)
    return room(rng, out, 0.45, 0.14, metal=0.3)


def shove(rng):
    """A heavy shove: a pressed "hngh", the suit's cloth, hands slamming into something soft,
    and the buckles rattling."""
    t = timeline(0.7)
    n = len(t)
    f0 = curve(t, [0, 0.12, 0.32], [125, 142, 108])
    level = curve(t, [0, 0.03, 0.08, 0.26, 0.34, 0.7], [0, 0.5, 1.0, 0.7, 0, 0])
    F = vowels(t, [0, 0.07], ["m", "uh"], 0.03)
    grunt = throat(rng, f0, F, level, air=curve(t, [0, 0.02, 0.1, 0.4], [0, 1.2, 0.4, 0]), jitter=0.04,
                   shimmer=0.15, sub=0.2, tilt=380, lp=3800)
    cloth = svf(rng.standard_normal(n), curve(t, [0, 0.12, 0.4], [700, 2600, 1500]), 1.4)
    cloth *= bump(t, 0.0, 0.38, 0.8) * (0.4 + np.abs(wobble(rng, n, 0.004)))
    hit = thump(rng, t, 0.09, 140, 80, 0.05, 0.9)
    place(hit, 0.4 * squelch(rng, 0.1, 700, 300, 3.0), 0.095)
    gear = np.zeros(n)
    for at in (0.1, 0.13, 0.18, 0.21):
        place(gear, rng.uniform(0.3, 0.7) * tick(rng, rng.uniform(3200, 5600), 0.006, 0.6), at)
    out = 0.8 * norm(grunt) + 0.4 * norm(cloth) + 0.8 * norm(hit) + 0.2 * norm(gear)
    return room(rng, out, 0.35, 0.1, metal=0.2)


def heal(rng):
    """A medkit: the nozzle clicks, a hiss of spray, and a soft, low tone."""
    t = timeline(1.25)
    n = len(t)
    nozzle = modes(t, [3100, 4650], [1.0, 0.5], [0.006, 0.004], 0.0) + 0.5 * click(rng, t, 0.0, 0.001)
    spray = hiss(rng, n, 2500, 10000) * curve(t, [0, 0.015, 0.3, 0.6], [0, 1.0, 0.6, 0])
    spray *= 1 + 0.15 * wobble(rng, n, 0.01)
    tone = (np.sin(TAU * 523.25 * t) + 0.5 * np.sin(TAU * 784.0 * t) + 0.3 * np.sin(TAU * 261.63 * t))
    tone *= np.clip((t - 0.08) / 0.12, 0, 1) * np.exp(-np.maximum(t - 0.2, 0) / 0.4) * (1 + 0.12 * np.sin(TAU * 5 * t))
    out = 0.4 * norm(nozzle) + 0.5 * norm(spray) + 0.45 * lowpass(tone, 3000) / 1.8
    return out


def stim(rng):
    """A stim: the injector's spring clicks home, a pneumatic hiss, then the rush (a rising
    swell and a quickening heartbeat)."""
    t = timeline(1.05)
    n = len(t)
    inject = modes(t, [1900, 3300, 5600], [1.0, 0.7, 0.4], [0.012, 0.008, 0.005], 0.0)
    inject += modes(t, [420], [0.6], [0.01], 0.0) + click(rng, t, 0.0, 0.001, 1500)
    inject += 0.6 * (modes(t, [2600, 4400], [1.0, 0.5], [0.006, 0.004], 0.035) + click(rng, t, 0.035, 0.001))
    pshh = hiss(rng, n, 2000, 9000) * env_ar(t, 0.003, 0.035, 0.02)
    rush = svf(rng.standard_normal(n), curve(t, [0.1, 0.6, 1.0], [300, 3500, 1500]), 0.9, "lp")
    rush *= bump(t, 0.1, 0.9, 1.3)
    rise = np.sin(phase_of(curve(t, [0, 0.1, 0.7, 1.05], [90, 90, 260, 220]))) * bump(t, 0.1, 0.9, 1.5)
    beats = sum(a * thump(rng, t, at, 90, 48, 0.07, 0.2) for at, a in ((0.38, 0.8), (0.5, 0.5), (0.66, 0.9), (0.76, 0.55)))
    ring = 0.04 * np.sin(TAU * 5200 * t) * bump(t, 0.3, 0.6)
    return 0.7 * norm(inject) + 0.5 * norm(pshh) + 0.45 * norm(rush) + 0.25 * rise + 0.4 * norm(beats) + ring


# ---------------------------------------------------------------------------
# Skitters: small, fast, never alone

def skitter_alert(rng, take):
    """It heard you: a rising chitter into a shrill squeak; clack-clack and a hiss; a trill."""
    if take == 0:
        t = timeline(0.75)
        n = len(t)
        out = chitter(rng, np.zeros(n), 0.0, 0.42, 25, 70, 2400, 5200)
        f = curve(t, [0.3, 0.6], [1800, 2700])
        out += 0.9 * squeal(rng, t, f, bump(t, 0.32, 0.38, 0.6)) * rattle_gate(rng, t, 45, 0.7)
        out += 0.4 * hiss(rng, n, 3000, 9000) * bump(t, 0.45, 0.3)
        return room(rng, out, 0.35, 0.1, metal=0.3)
    if take == 1:
        t = timeline(0.65)
        n = len(t)
        out = np.zeros(n)
        for at in (0.0, 0.07):
            place(out, tick(rng, rng.uniform(1900, 2500), 0.007, 1.2), at)
        out += 0.6 * hiss(rng, n, 2500, 8000) * curve(t, [0.08, 0.14, 0.4, 0.6], [0, 1, 0.5, 0]) * rattle_gate(rng, t, 55, 0.5)
        chitter(rng, out, 0.15, 0.4, 40, 30, 3000, 6000, level=0.5)
        return room(rng, out, 0.35, 0.1, metal=0.3)
    t = timeline(0.7)
    n = len(t)
    f = curve(t, [0, 0.4, 0.55], [2600, 3200, 3000])
    out = squeal(rng, t, f, bump(t, 0.0, 0.5, 0.5), (1.0, 0.3, 0.15)) * rattle_gate(rng, t, 70, 0.9)
    for at in (0.52, 0.58):
        place(out, 0.8 * tick(rng, rng.uniform(2000, 2600), 0.006, 1.2), at)
    return room(rng, out, 0.35, 0.1, metal=0.3)


def skitter_idle(rng, take):
    """Lurking: soft, uneven clicking of mouth parts and feet, now and then a wet smack."""
    t = timeline([1.0, 1.2, 0.9][take])
    n = len(t)
    out = np.zeros(n)
    bursts = [((0.05, 0.25), (0.5, 0.2), (0.82, 0.12)), ((0.1, 0.4), (0.7, 0.35)), ((0.0, 0.15), (0.3, 0.15), (0.6, 0.2))][take]
    for at, length in bursts:
        chitter(rng, out, at, length, 30, 18, 1800, 4800, (0.001, 0.003), rng.uniform(0.5, 1.0))
    place(out, 0.3 * squelch(rng, 0.08, 1500, 700, 3.0), rng.uniform(0.2, 0.6))
    return room(rng, out, 0.35, 0.1, metal=0.3)


def skitter_attack(rng, take):
    """The lunge: a clack and a hissing shriek."""
    t = timeline([0.45, 0.5, 0.4][take])
    n = len(t)
    out = np.zeros(n)
    place(out, tick(rng, rng.uniform(1800, 2600), 0.008, 1.3), 0.0)
    sweep = curve(t, [0.02, 0.3], [[2500, 3000, 2200][take], [5200, 4500, 6000][take]])
    shriek = svf(rng.standard_normal(n), sweep, 3.0) * bump(t, 0.02, t[-1] - 0.04, 0.6)
    f = curve(t, [0.02, 0.2, 0.4], [2200, 3100, 2600]) * [1.0, 0.9, 1.12][take]
    out += 0.8 * norm(shriek) + 0.5 * squeal(rng, t, f, bump(t, 0.03, 0.3, 0.7), (1.0, 0.35)) * rattle_gate(rng, t, 60, 0.6)
    return room(rng, out, 0.35, 0.1, metal=0.3)


def skitter_hurt(rng, take):
    """Hit: a high falling squeal that sputters, and a wet pop."""
    t = timeline([0.4, 0.35, 0.45][take])
    n = len(t)
    top = [2900, 3300, 2500][take]
    f = curve(t, [0, 0.05, 0.3], [top * 0.9, top, top * 0.6])
    out = squeal(rng, t, f, curve(t, [0, 0.01, 0.2, 0.3], [0, 1, 0.6, 0]), (1.0, 0.5, 0.2)) * rattle_gate(rng, t, 38, 0.6)
    chitter(rng, out, 0.15, 0.2, 45, 20, 2000, 4500, level=0.5)
    place(out, 0.5 * bubble(rng.uniform(400, 700), 0.02, 0.8), 0.02)
    return room(rng, out, 0.35, 0.1, metal=0.3)


def skitter_leap(rng):
    """A skitter leaping: a burst of chitters, feet scraping off the deck, a hiss and a squeak."""
    t = timeline(0.6)
    n = len(t)
    out = chitter(rng, np.zeros(n), 0.0, 0.22, 60, 90, 2500, 5500)
    feet = np.zeros(n)
    place(feet, crackle(rng, 0.07, 500, 200, 3000, 6500), 0.08)
    out += 0.5 * feet + 0.3 * thump(rng, t, 0.09, 220, 120, 0.02, 0.3)
    out += 0.6 * hiss(rng, n, 3000, 8500) * curve(t, [0.05, 0.1, 0.45], [0, 1, 0])
    place(out, 0.5 * whoosh(rng, 0.35, 500, 2000), 0.14)
    f = curve(t, [0.25, 0.45], [2200, 3000])
    out += 0.5 * squeal(rng, t, f, bump(t, 0.26, 0.2), (1.0, 0.3)) * rattle_gate(rng, t, 50, 0.6)
    return room(rng, out, 0.35, 0.1, metal=0.3)


# ---------------------------------------------------------------------------
# Stalkers: three metres of skitter that hunt by sound

def hollow_clicks(rng, buf, times, f=1100.0, level=1.0):
    """Loud hollow clicks from a big chitin chamber (it hunts by sound)."""
    for at in times:
        fr = f * rng.uniform(0.9, 1.1)
        a = level * rng.uniform(0.7, 1.0)
        place(buf, a * tick(rng, fr, 0.012, 0.8), at)
        place(buf, 0.6 * a * tick(rng, fr * 0.45, 0.02, 0.4), at)
    return buf


def stalker_hiss(rng, t, level, f1=1300.0, f2=2600.0):
    """A big creature's hiss: noise through its throat's two resonances."""
    noise = rng.standard_normal(len(t))
    x = bandpass(noise, f1, 2.5) + 0.7 * bandpass(noise, f2, 3.0) + 0.12 * lowpass(highpass(noise, 3500), 7000)
    return norm(x) * level


def stalker_alert(rng, take):
    """It heard you: hollow clicks quickening into a rattle, then a long hiss over a growl."""
    t = timeline([1.3, 1.2, 1.4][take])
    n = len(t)
    out = np.zeros(n)
    times, at, gap = [], 0.02, [0.11, 0.09, 0.13][take]
    while at < 0.55:
        times.append(at)
        at += gap
        gap = max(gap * 0.8, 0.025)
    hollow_clicks(rng, out, times, [1100, 950, 1250][take])
    hs = curve(t, [0.4, 0.55, 1.0, t[-1]], [0, 1, 0.6, 0])
    out += 0.9 * stalker_hiss(rng, t, hs, [1300, 1150, 1450][take], [2600, 2300, 2900][take]) * rattle_gate(rng, t, 32, 0.45)
    f0 = curve(t, [0.4, t[-1]], [58, 48])
    growl = throat(rng, f0, vowels(t, [0], ["er"], 0.05, 0.7), hs, air=0.2, jitter=0.1, shimmer=0.3, sub=0.5,
                   tilt=300, lp=1800)
    return room(rng, lowpass(out, 7000) + 0.5 * norm(growl), 0.6, 0.15, metal=0.3)


def stalker_idle(rng, take):
    """Listening: slow hollow clicks, spaced out, and a breath."""
    t = timeline([1.6, 1.4, 1.7][take])
    n = len(t)
    times = [(0.05, 0.3, 0.42, 0.9), (0.1, 0.25, 0.7, 0.85, 0.95), (0.05, 0.6, 0.75, 1.3)][take]
    out = hollow_clicks(rng, np.zeros(n), times, [1000, 1150, 900][take], 0.8)
    out += 0.35 * stalker_hiss(rng, t, bump(t, t[-1] * 0.45, t[-1] * 0.5, 1.2), 900, 2000)
    return room(rng, lowpass(out, 7000), 0.6, 0.15, metal=0.3)


def stalker_attack(rng, take):
    """The lunge: a burst of clicks and a screeching hiss."""
    t = timeline([0.75, 0.7, 0.8][take])
    n = len(t)
    out = hollow_clicks(rng, np.zeros(n), [0.0, 0.03, 0.055, 0.075], 1200, 0.8)
    sweep = curve(t, [0.06, 0.35, t[-1]], [1200, 2600, 1800]) * [1.0, 1.15, 0.9][take]
    screech = svf(rng.standard_normal(n), sweep, 4.0) * curve(t, [0.06, 0.12, 0.5, t[-1]], [0, 1, 0.7, 0])
    f0 = curve(t, [0.06, 0.3, t[-1]], [620, 880, 640]) * [1.0, 1.1, 0.9][take]
    voice = throat(rng, f0, [np.full(n, 1100.0), np.full(n, 2300.0), np.full(n, 3400.0)],
                   curve(t, [0.06, 0.12, 0.55, t[-1]], [0, 1, 0.6, 0]), air=0.6, bws=(250, 300, 400),
                   jitter=0.06, sub=0.5, tilt=900, lp=6000)
    out += 0.8 * norm(screech) + 0.6 * grit(voice, 2.0)
    return room(rng, out, 0.6, 0.15, metal=0.3)


def stalker_hurt(rng, take):
    """Hit: a rattling screech."""
    t = timeline([0.55, 0.5, 0.6][take])
    n = len(t)
    f = curve(t, [0, 0.1, t[-1]], [900, 1300, 700]) * [1.0, 1.15, 0.88][take]
    level = curve(t, [0, 0.01, 0.3, t[-1]], [0, 1, 0.6, 0])
    out = squeal(rng, t, f, level, (1.0, 0.6, 0.4, 0.25)) * rattle_gate(rng, t, 34, 0.7)
    out = norm(out) + 0.5 * stalker_hiss(rng, t, level, 1600, 3200) * rattle_gate(rng, t, 34, 0.7)
    return room(rng, grit(out, 1.5), 0.6, 0.15, metal=0.3)


def stalker_die(rng):
    """A high rattling squeal, cut off with a crunch; the long body hits the deck."""
    t = timeline(1.8)
    n = len(t)
    f = curve(t, [0, 0.4, 0.87], [1300, 1900, 2100])
    cut = np.clip((0.88 - t) / 0.004, 0, 1)
    level = np.clip(t / 0.02, 0, 1) * cut
    sq = squeal(rng, t, f, level, (1.0, 0.55, 0.3, 0.15), 0.02, 9) * rattle_gate(rng, t, 38, 0.75)
    sq += 0.45 * squeal(rng, t, f / 2.1, level, (1.0, 0.5)) * rattle_gate(rng, t, 38, 0.75)
    rasp = stalker_hiss(rng, t, level, 2200, 4200) * rattle_gate(rng, t, 38, 0.75)
    squeal_part = room(rng, norm(sq) + 0.4 * rasp, 0.8, 0.25, metal=0.4)
    crunch = crack(rng, t, 0.885, 0.8)
    place(crunch, 0.6 * squelch(rng, 0.15, 800, 300, 3.0), 0.89)
    body = 1.2 * thump(rng, t, 1.25, 80, 40, 0.18, 0.6) + deck_ring(t, 1.25, 0.6)
    chitin = np.zeros(n)
    place(chitin, crackle(rng, 0.15, 300, 80, 800, 2500, (0.003, 0.01)), 1.26)
    rest = 0.7 * norm(crunch) + 0.7 * norm(body) + 0.3 * chitin
    return squeal_part + room(rng, rest, 0.6, 0.15, metal=0.3)


# ---------------------------------------------------------------------------
# Feeders: they hang from the ceiling and croak

def croak(rng, t, f0, level, F=(320, 820, 1900), wet=0.6, sub=0.5):
    """A wet croak: slow, uneven pulses through a fluid-filled sac."""
    n = len(t)
    formants = [np.full(n, float(F[0])), np.full(n, float(F[1])), np.full(n, float(F[2]))]
    return throat(rng, f0, formants, level, air=0.3, bws=(90, 160, 260), weights=(1.0, 0.5, 0.2),
                  jitter=0.12, shimmer=0.4, sub=sub, tilt=200, wet=wet, bubbles=1.2, lp=2000)


def feeder_alert(rng, take):
    """It has felt you: a rising croak that ends in a wet gulp."""
    t = timeline([1.0, 0.9, 1.1][take])
    n = len(t)
    f0 = curve(t, [0, 0.7], [[34, 30, 38][take], [72, 64, 80][take]])
    level = curve(t, [0, 0.1, 0.7, 0.85, t[-1]], [0, 0.6, 1.0, 0, 0])
    F = ([300, 800, 1900], [280, 720, 1800], [340, 900, 2000])[take]
    out = norm(croak(rng, t, f0, level, F))
    place(out, 0.6 * bubble(rng.uniform(160, 230), 0.035, 1.5), 0.82)
    return room(rng, out, 0.5, 0.15, metal=0.3)


def feeder_idle(rng, take):
    """Hanging there: slow wet croaks, a gulp and something dripping."""
    t = timeline([1.6, 1.4, 1.8][take])
    n = len(t)
    groups = [((0.05, 0.35), (0.6, 0.3)), ((0.1, 0.5),), ((0.0, 0.25), (0.4, 0.25), (0.95, 0.4))][take]
    level = sum(bump(t, at, length, 0.6) for at, length in groups)
    f0 = 28 + 6 * wobble(rng, n, 0.2)
    out = norm(croak(rng, t, np.maximum(f0, 20), level, (300, 760, 1800), 0.7, 0.6))
    for _ in range(3):
        place(out, drip(rng, amp=rng.uniform(0.15, 0.35)), rng.uniform(0.2, t[-1] - 0.2))
    return room(rng, out, 0.5, 0.15, metal=0.3)


def feeder_attack(rng, take):
    """Going for you: a hungry croaking snarl and a sucking slurp."""
    t = timeline([0.8, 0.75, 0.85][take])
    n = len(t)
    f0 = curve(t, [0, 0.3, t[-1]], [60, 85, 50]) * [1.0, 1.1, 0.9][take]
    level = curve(t, [0, 0.04, 0.4, 0.55, t[-1]], [0, 1, 0.8, 0.2, 0])
    out = norm(grit(croak(rng, t, f0, level, (420, 1000, 2200), 0.5, 0.6), 2.0))
    place(out, 0.6 * squelch(rng, 0.3, 400, 1400, 4.0), 0.4)
    return room(rng, out, 0.5, 0.15, metal=0.3)


def feeder_hurt(rng, take):
    """Hit: a squealing croak and a gurgling cough."""
    t = timeline([0.55, 0.5, 0.6][take])
    n = len(t)
    top = [180, 150, 210][take]
    f0 = curve(t, [0, 0.05, 0.3, t[-1]], [top * 0.7, top, top * 0.5, top * 0.4])
    level = curve(t, [0, 0.02, 0.25, 0.4, t[-1]], [0, 1, 0.7, 0.3, 0])
    out = norm(croak(rng, t, f0, level, (500, 1300, 2400), 0.6, 0.3))
    gurgle(rng, out, 0.25, 0.25, 60, 160, 500, level=0.5)
    return room(rng, out, 0.5, 0.15, metal=0.3)


def feeder_grab(rng):
    """A tongue lashing out, a wet slap as it catches, then the stretch as it pulls."""
    t = timeline(0.9)
    n = len(t)
    lash = np.zeros(n)
    place(lash, whoosh(rng, 0.13, 300, 3000, 2.0, 0.8), 0.0)
    lash += 0.2 * np.sin(phase_of(curve(t, [0, 0.12], [500, 1500]))) * bump(t, 0.0, 0.12)
    slap = lowpass(rng.standard_normal(n) * env_ar(t, 0.0003, 0.009, 0.12), 4500)
    slap = norm(slap) + 0.6 * thump(rng, t, 0.12, 160, 110, 0.03, 0.2)
    place(slap, 0.7 * squelch(rng, 0.24, 1500, 500, 3.0), 0.125)
    place(slap, 0.5 * crackle(rng, 0.25, 400, 50, 500, 2000, (0.002, 0.005)), 0.13)
    stretch = creak(rng, t, 0.3, 0.55, 40, 15, [150, 380, 700], 8.0)
    stretch = norm(stretch) * curve(t, [0.3, 0.4, 0.85], [0, 1, 0])
    drips = np.zeros(n)
    for _ in range(4):
        place(drips, drip(rng, amp=rng.uniform(0.2, 0.4)), rng.uniform(0.2, 0.8))
    out = 0.6 * norm(lash) + 1.0 * norm(slap) + 0.35 * stretch + 0.3 * drips
    return room(rng, out, 0.5, 0.15, metal=0.3)


# ---------------------------------------------------------------------------
# Watchers: one great eye on a stalk, and a whine

def whine(rng, t, f, level, F=(1500, 2900, 4100), vib=0.015, vib_hz=5.5, detune=1.012):
    """An eerie whine: a thin voice-like tone with a slightly detuned twin beating against it."""
    n = len(t)
    fv = f * (1 + vib * np.sin(phase_of(np.full(n, vib_hz))) + 0.008 * wobble(rng, n, 0.03))
    formants = [np.full(n, float(F[0])), np.full(n, float(F[1])), np.full(n, float(F[2]))]
    a = formant_voice(fv, formants, (300, 400, 500), level, tilt=1.2, fmax=7000.0)
    b = formant_voice(fv * detune, formants, (300, 400, 500), level, tilt=1.4, fmax=7000.0)
    air = bandpass(rng.standard_normal(n), float(np.mean(f)) * 2, 3.0) * level
    return a + 0.6 * b + 0.15 * norm(air) * level


def blink(rng):
    """The great eye blinking: a small, slick squelch."""
    return 0.6 * squelch(rng, 0.09, 1200, 500, 4.0, flutter=0.3)


def watcher_alert(rng, take):
    """It sees you: a rising whine that swells and stops short."""
    t = timeline([1.1, 1.0, 1.2][take])
    n = len(t)
    f = curve(t, [0, t[-1] - 0.15], [[600, 700, 520][take], [1400, 1550, 1250][take]])
    level = curve(t, [0, 0.2, t[-1] - 0.12, t[-1] - 0.06, t[-1]], [0, 0.6, 1.0, 0, 0])
    out = whine(rng, t, f, level, vib=curve(t, [0, t[-1]], [0.01, 0.03]), vib_hz=6.5)
    place(out, blink(rng), 0.0)
    return room(rng, out, 0.6, 0.18, metal=0.3)


def watcher_idle(rng, take):
    """Floating: a low whine that wavers in two or three swells, and a blink."""
    t = timeline([1.6, 1.4, 1.8][take])
    n = len(t)
    f = [480, 540, 430][take] * (1 + 0.06 * np.sin(phase_of(np.full(n, 0.8))) + 0.03 * wobble(rng, n, 0.2))
    swells = [((0.0, 0.7, 1.0), (0.8, 0.8, 0.7)), ((0.0, 0.5, 0.8), (0.55, 0.85, 1.0)),
              ((0.0, 0.5, 1.0), (0.6, 0.5, 0.6), (1.15, 0.65, 0.8))][take]
    level = sum(a * bump(t, at, length, 1.5) for at, length, a in swells)
    out = whine(rng, t, f, level, (1200, 2600, 3800), 0.02, 4.0, 1.02)
    place(out, blink(rng), rng.uniform(0.3, t[-1] - 0.3))
    return room(rng, out, 0.6, 0.18, metal=0.3)


def watcher_attack(rng, take):
    """About to spit: a sharp whine swooping up, and a wet click."""
    t = timeline([0.6, 0.55, 0.65][take])
    n = len(t)
    f = curve(t, [0, 0.3, t[-1]], [800, 1900, 1600]) * [1.0, 1.1, 0.9][take]
    level = curve(t, [0, 0.03, 0.4, t[-1]], [0, 1, 0.8, 0])
    out = whine(rng, t, f, level, (1800, 3300, 4500), 0.02, 9.0, 1.03)
    place(out, 0.5 * bubble(300, 0.02, 1.5), t[-1] - 0.12)
    return room(rng, out, 0.6, 0.18, metal=0.3)


def watcher_hurt(rng, take):
    """Hit: a warbling whine falling away, and the eye squelching."""
    t = timeline([0.55, 0.5, 0.6][take])
    n = len(t)
    f = curve(t, [0, 0.04, t[-1]], [1300, 1500, 600]) * [1.0, 1.15, 0.9][take]
    level = curve(t, [0, 0.015, 0.3, t[-1]], [0, 1, 0.6, 0])
    out = whine(rng, t, f, level, (1500, 3000, 4200), 0.06, 12.0, 1.04)
    place(out, 1.4 * blink(rng), 0.0)
    return room(rng, out, 0.6, 0.18, metal=0.3)


def watcher_scream(rng):
    """A watcher's scream, which wakes everything near it: a long, ragged shriek of several
    throats at once that cracks upward and rattles out."""
    t = timeline(2.3)
    n = len(t)
    f0 = curve(t, [0, 0.12, 0.3, 0.9, 1.0, 1.15, 1.6, 2.0, 2.3], [380, 640, 900, 980, 1250, 1180, 900, 620, 500])
    f0 = smooth(f0, 0.03) * (1 + 0.025 * np.sin(phase_of(6.5 + 3 * t)) + 0.02 * wobble(rng, n, 0.01))
    level = curve(t, [0, 0.06, 0.2, 1.4, 1.9, 2.25, 2.3], [0, 0.6, 1.0, 0.95, 0.4, 0, 0])
    level *= rattle_gate(rng, t, 27, curve(t, [0, 1.5, 2.2], [0.0, 0.1, 0.8]))
    F = [curve(t, [0, 0.3, 1.0, 1.6, 2.2], [700, 1000, 1100, 950, 800]),
         curve(t, [0, 0.3, 1.0, 1.6, 2.2], [1300, 1700, 1900, 1600, 1400]),
         curve(t, [0, 1.0, 2.2], [2900, 3200, 3000])]
    main = throat(rng, f0, F, level, air=0.35, bws=(200, 260, 350), jitter=0.025, shimmer=0.2,
                  sub=curve(t, [0, 0.9, 1.0, 1.2, 2.3], [0.05, 0.1, 0.45, 0.4, 0.6]), tilt=1500, lp=7000)
    twin = throat(rng, f0 * 1.065, F, level, air=0.3, bws=(200, 260, 350), jitter=0.05, shimmer=0.25,
                  sub=0.3, tilt=1500, lp=7000)
    low = throat(rng, f0 * 0.5, [x * 0.75 for x in F], level, air=0.2, bws=(150, 200, 300), jitter=0.05,
                 shimmer=0.3, tilt=600, lp=4000)
    shriek = stalker_hiss(rng, t, level, 1800, 3400)
    out = grit(norm(main) + 0.5 * norm(twin) + 0.25 * norm(low) + 0.2 * shriek, 2.0)
    return room(rng, out, 0.9, 0.22, metal=0.4)


def spit(rng):
    """A wet hawk in the throat, then the glob launched: a pop, a splutter and a whoosh."""
    t = timeline(0.95)
    n = len(t)
    hawk_level = curve(t, [0, 0.3, 0.38, 0.42], [0.1, 1.0, 0.8, 0])
    F = [np.full(n, 500.0), np.full(n, 1500.0), np.full(n, 2600.0)]
    hawk = throat(rng, np.full(n, 52.0), F, 0.3 * hawk_level, air=hawk_level, jitter=0.15, shimmer=0.5,
                  sub=0.5, tilt=300, wet=0.85, bubbles=1.5, lp=4000)
    pop = thump(rng, t, 0.42, 200, 110, 0.015, 0.4) + click(rng, t, 0.42, 0.001, 800)
    burst = lowpass(rng.standard_normal(n) * env_ar(t, 0.001, 0.04, 0.42), 3000)
    glob = np.zeros(n)
    place(glob, squelch(rng, 0.25, 1800, 600, 3.0), 0.43)
    for _ in range(7):
        place(glob, drip(rng, rng.uniform(1500, 3200), rng.uniform(0.2, 0.5)), rng.uniform(0.43, 0.55))
    air = np.zeros(n)
    place(air, whoosh(rng, 0.4, 900, 350, 1.0), 0.44)
    out = 0.7 * norm(hawk) + 0.6 * norm(pop) + 0.6 * norm(burst) + 0.6 * norm(glob) + 0.3 * air
    return room(rng, out, 0.5, 0.15, metal=0.3)


# ---------------------------------------------------------------------------
# The heart, the pods and the growth

def heartbeat(rng, t, start, strength=1.0, f=40.0, wet=1.0):
    """One beat of a huge heart: a deep "lub", a wet squelch of blood, and a "dub"."""
    lub = thump(rng, t, start, f * 1.6, f, 0.15, 0.25)
    dub = 0.7 * thump(rng, t, start + 0.32, f * 1.7, f * 1.18, 0.1, 0.2)
    wet_part = np.zeros(len(t))
    place(wet_part, squelch(rng, 0.28, 350, 120, 2.5, 1.5, 0.5), start + 0.01)
    place(wet_part, 0.6 * squelch(rng, 0.2, 300, 110, 2.5, 1.5, 0.5), start + 0.33)
    return strength * (norm(lub + dub) + 0.35 * wet * wet_part)


def heart_die(rng):
    """The heart dying: one last hard beat, a long wet deflating sigh with two weaker
    beats in it, and a final low collapse."""
    t = timeline(2.9)
    n = len(t)
    beats = heartbeat(rng, t, 0.04, 1.0, 38) + heartbeat(rng, t, 1.45, 0.45, 34) + 0.2 * thump(rng, t, 2.38, 50, 30, 0.14, 0.2)
    rate = curve(t, [0.55, 2.2], [28, 7])
    flap = (0.5 + 0.5 * np.cos(phase_of(rate))) ** 3
    noise = svf(rng.standard_normal(n), curve(t, [0.55, 2.2], [700, 150]), 4.0)
    deflate = norm(noise) * flap * curve(t, [0.5, 0.65, 1.6, 2.3], [0, 1, 0.5, 0])
    f0 = curve(t, [0.55, 2.2], [85, 38])
    level = curve(t, [0.5, 0.7, 1.5, 2.3, 2.9], [0, 0.8, 0.5, 0, 0])
    groan = throat(rng, f0, [np.full(n, 350.0), np.full(n, 800.0), np.full(n, 1800.0)], level, air=0.5,
                   jitter=0.1, shimmer=0.4, sub=0.5, tilt=200, wet=0.6, bubbles=1.0, lp=1800)
    liquid = gurgle(rng, np.zeros(n), 0.3, 2.3, 40, 120, 500, level=1.0, shape=lambda p: 1 - 0.8 * p)
    collapse = np.zeros(n)
    place(collapse, squelch(rng, 0.45, 250, 90, 2.0, 1.0, 0.5), 2.25)
    out = 1.0 * beats + 0.55 * deflate + 0.5 * norm(groan) + 0.3 * norm(liquid) + 0.5 * norm(collapse)
    return room(rng, out, 1.2, 0.25, 3000, metal=0.2)


def pod_hatch(rng):
    """A pod splitting open: a pulse, the membrane straining, the wet tear, a gush, drips."""
    t = timeline(1.75)
    n = len(t)
    pulse = thump(rng, t, 0.0, 80, 48, 0.1, 0.2)
    place(pulse, 0.5 * squelch(rng, 0.2, 400, 150, 2.5), 0.01)
    strain = creak(rng, t, 0.08, 0.5, 30, 90, [180, 420, 760], 6.0)
    strain = norm(strain) * curve(t, [0.08, 0.5, 0.58], [0.2, 1, 0])
    tear = np.zeros(n)
    place(tear, crackle(rng, 0.35, 1500, 300, 600, 3000, shape=lambda p: 1 - 0.6 * p), 0.55)
    place(tear, squelch(rng, 0.4, 1200, 300, 3.0), 0.55)
    place(tear, 0.6 * squelch(rng, 0.4, 500, 900, 3.5), 0.72)
    gush = norm(lowpass(rng.standard_normal(n), 600) * env_ar(t, 0.02, 0.18, 0.6))
    gush += 0.6 * norm(gurgle(rng, np.zeros(n), 0.6, 0.6, 70, 150, 700, shape=lambda p: 1 - p))
    drips = np.zeros(n)
    for _ in range(7):
        place(drips, drip(rng, amp=rng.uniform(0.3, 0.7)), rng.uniform(1.0, 1.6))
    out = 0.5 * norm(pulse) + 0.35 * strain + 0.9 * norm(tear) + 0.45 * norm(gush) + 0.3 * drips
    return room(rng, out, 0.5, 0.15, metal=0.3)


def robot_drop(rng):
    """A robot dropping from its ceiling mount: the clamp lets go, it falls, lands hard on
    the deck, its legs clatter, and a servo whines it upright (with a glitch: it's infected)."""
    t = timeline(1.5)
    n = len(t)
    release = modes(t, [2200, 3400, 5100], [1.0, 0.6, 0.3], [0.02, 0.012, 0.008], 0.0) + click(rng, t, 0.0, 0.001, 1500)
    release += 0.3 * np.sin(TAU * 900 * t) * bump(t, 0.0, 0.03)
    fall = np.zeros(n)
    place(fall, 0.4 * whoosh(rng, 0.22, 400, 1200, 1.0), 0.03)
    land = thump(rng, t, 0.25, 110, 52, 0.12, 0.6)
    land += modes(t, [160, 290, 455, 690, 1020, 1530], [1.0, 0.8, 0.6, 0.45, 0.3, 0.2],
                  [0.35, 0.28, 0.2, 0.14, 0.09, 0.06], 0.25)
    land += 0.4 * modes(t, [2400, 3700], [1.0, 0.6], [0.04, 0.03], 0.25)
    land += 0.4 * norm(lowpass(rng.standard_normal(n) * env_ar(t, 0.0005, 0.02, 0.25), 3000))
    for at in (0.3, 0.36, 0.44):
        land += 0.3 * modes(t, rng.uniform(600, 1800, 3), [1.0, 0.6, 0.4], [0.03, 0.02, 0.015], at)
    f = curve(t, [0.55, 0.95, 1.1, 1.4], [260, 720, 640, 640])
    ph = phase_of(f)
    servo = sum(a * np.sin((k + 1) * ph) for k, a in enumerate((1.0, 0.5, 0.35, 0.2, 0.12, 0.08)))
    servo *= curve(t, [0.55, 0.65, 1.25, 1.4], [0, 1, 0.8, 0])
    gears = bandpass(rng.standard_normal(n), 1500, 2.0) * (0.5 + 0.5 * np.sin(TAU * 90 * t)) * curve(t, [0.55, 0.65, 1.25, 1.4], [0, 1, 0.8, 0])
    glitch = np.sign(np.sin(TAU * 120 * t)) * (rng.standard_normal(n) > 0.6) * bump(t, 1.0, 0.07)
    hydraulic = hiss(rng, n, 2500, 9000) * env_ar(t, 0.01, 0.08, 1.15)
    out = 0.5 * norm(release) + 0.3 * fall + 1.0 * norm(land) + 0.3 * norm(servo) + 0.12 * norm(gears)
    out += 0.12 * lowpass(glitch, 5000) + 0.2 * norm(hydraulic)
    return room(rng, out, 0.6, 0.15, metal=0.5)


def robot_alert(rng):
    """Station security has spotted you: a two-tone electronic chirp, its edges torn up
    by whatever is in its wiring."""
    t = timeline(0.5)
    n = len(t)
    out = np.zeros(n)
    for start, length, f in ((0.0, 0.09, 1400), (0.11, 0.13, 2100)):
        u = t - start
        gate = np.clip(u / 0.002, 0, 1) * np.clip((length - u) / 0.004, 0, 1) * (u >= 0) * (u <= length)
        out += sum(np.sin(TAU * k * f * np.maximum(u, 0)) / k for k in (1, 3, 5)) * gate
    hold = 6  # sample-and-hold: a crushed, cheap-speaker edge
    crushed = np.repeat(out[::hold], hold)[:n]
    out = lowpass(0.75 * out + 0.25 * crushed, 6000)
    stutter = np.zeros(n)
    for i in range(3):
        place(stutter, 0.4 * np.sin(TAU * 2100 * timeline(0.015)) * np.hanning(secs(0.015)), 0.26 + i * 0.035)
    return out + stutter


def robot_idle(rng):
    """A robot standing guard: a servo humming as it turns, then a scan beep."""
    t = timeline(1.4)
    n = len(t)
    f = curve(t, [0, 0.3, 0.8, 1.0], [180, 240, 200, 200])
    ph = phase_of(f)
    hum = sum(a * np.sin((k + 1) * ph) for k, a in enumerate((1.0, 0.6, 0.3, 0.2, 0.1)))
    hum *= curve(t, [0, 0.08, 0.8, 0.95], [0, 1, 0.8, 0])
    gears = bandpass(rng.standard_normal(n), 1200, 2.0) * curve(t, [0, 0.08, 0.8, 0.95], [0, 0.4, 0.3, 0])
    sweep = curve(t, [1.0, 1.15], [1800, 2600])
    beep = np.sin(phase_of(sweep)) * curve(t, [0.99, 1.0, 1.14, 1.16], [0, 1, 1, 0])
    beep += 0.6 * np.sin(TAU * 2600 * t) * curve(t, [1.22, 1.23, 1.28, 1.3], [0, 1, 1, 0])
    return 0.25 * norm(hum) + 0.08 * norm(gears) + 0.4 * beep


def vent_crawl(rng):
    """Something scrabbling through a metal duct: claws ticking on thin sheet, a scrape, and
    its body knocking the duct, which booms hollowly round it."""
    t = timeline(2.3)
    n = len(t)
    taps = np.zeros(n)
    for start, length in ((0.05, 0.35), (0.55, 0.3), (1.0, 0.4), (1.55, 0.3)):
        at = start
        while at < start + length:
            place(taps, rng.uniform(0.3, 1.0) * click(rng, timeline(0.01), 0.0, 0.0012, 800), at)
            at += rng.uniform(0.012, 0.035)
    scrape = hiss(rng, n, 900, 3500) * np.abs(wobble(rng, n, 0.003)) * (bump(t, 0.4, 0.3) + bump(t, 1.35, 0.35))
    bumps = np.zeros(n)
    for at in (0.3, 0.8, 1.3, 1.8):
        place(bumps, rng.uniform(0.6, 1.0) * lowpass(rng.standard_normal(secs(0.01)) * np.hanning(secs(0.01)), 300), at)
    ir_t = timeline(0.5)
    tube = [118 * k for k in range(1, 6)]
    sheet = [730, 1130, 1610, 2270, 3100]
    duct = modes(ir_t, tube + sheet + [70], [1.0, 0.8, 0.6, 0.45, 0.3, 0.5, 0.45, 0.4, 0.3, 0.2, 0.8],
                 [0.25, 0.2, 0.16, 0.12, 0.1, 0.06, 0.05, 0.04, 0.03, 0.02, 0.12])
    excite = norm(taps) + 0.5 * norm(scrape) + norm(bumps)
    out = convolve(excite, duct) * 0.02 + 0.4 * excite
    out = lowpass(out, 4500) * curve(t, [0, 0.8, 1.6, 2.3], [0.6, 1.0, 0.9, 0.5])
    return out


# ---------------------------------------------------------------------------
# Loops

def heart_beat_loop(rng):
    """The heart in its nest: a slow, deep, wet double beat (3 s loop, two beats)."""
    L = 3.0
    t = timeline(L)
    n = len(t)
    out = np.zeros(n)
    for at, strength in ((0.3, 1.0), (1.8, 0.88)):
        seg = timeline(1.4)
        place(out, heartbeat(rng, seg, 0.004, strength, 38), at, wrap=True)
        slosh = lowpass(rng.standard_normal(len(seg)), 220) * bump(seg, 0.35, 0.7, 1.5)
        place(out, 0.25 * norm(slosh), at, wrap=True)
    gurgle(rng, out, 0.0, L, 6, 120, 400, level=0.15, wrap=True)
    return room(rng, out, 0.8, 0.2, 2500, circular=True)


def bloom_loop(rng):
    """The growth in an overgrown room: quiet squelches as it shifts, drips, a gurgle now
    and then, and a faint fizz of living tissue (8 s loop)."""
    L = 8.0
    t = timeline(L)
    n = len(t)
    breathe = loop_noise(rng, n, lambda f: hp_mag(f, 30) * lp_mag(f, 180, 3))
    breathe *= 0.6 + 0.4 * np.sin(TAU * 2 * t / L + 1.0)
    fizz = np.zeros(n)
    chitter(rng, fizz, 0.0, L, 40, 40, 900, 3200, (0.0008, 0.002), 1.0, wrap=True)
    squelches = np.zeros(n)
    for _ in range(9):
        f0, f1 = rng.uniform(200, 1100), rng.uniform(200, 1100)
        place(squelches, rng.uniform(0.4, 1.0) * squelch(rng, rng.uniform(0.2, 0.6), f0, f1, rng.uniform(2, 6)),
              rng.uniform(0, L), wrap=True)
    drips = np.zeros(n)
    for _ in range(18):
        place(drips, drip(rng, amp=rng.uniform(0.3, 1.0)), rng.uniform(0, L), wrap=True)
    liquid = np.zeros(n)
    for _ in range(3):
        gurgle(rng, liquid, rng.uniform(0, L), rng.uniform(0.3, 0.6), 45, 150, 500, level=1.0, wrap=True)
    out = 0.1 * breathe + 0.06 * norm(fizz) + 0.7 * norm(squelches) + 0.5 * norm(drips) + 0.4 * norm(liquid)
    return room(rng, out, 1.0, 0.25, 3500, circular=True)


def hum_loop(rng):
    """Marigold's ventilation: a low mains hum, the fan's blade tone and air in the ducts
    (8 s loop; every frequency is a whole number of cycles in 8 s)."""
    L = 8.0
    t = timeline(L)
    n = len(t)
    weights = {50: 0.5, 100: 1.0, 150: 0.4, 200: 0.35, 250: 0.15, 300: 0.2, 400: 0.06}
    mains = sum(w * np.sin(TAU * f * t + rng.uniform(0, TAU)) for f, w in weights.items())
    mains = np.tanh(1.5 * mains / np.abs(mains).max())
    mains *= 1 + 0.08 * np.sin(TAU * t / L) + 0.05 * np.sin(TAU * 2 * t / L + 1.0)
    blade = np.sin(TAU * 151.25 * t) + 0.3 * np.sin(TAU * 302.5 * t)
    blade *= 1 + 0.2 * np.sin(TAU * 3 * t / L)
    air = loop_noise(rng, n, lambda f: hp_mag(f, 40) * lp_mag(f, 450, 2) / np.sqrt(np.maximum(f, 20)))
    duct = loop_noise(rng, n, lambda f: bp_mag(f, 95, 6) + 0.6 * bp_mag(f, 230, 8))
    hissing = loop_noise(rng, n, lambda f: hp_mag(f, 2000, 2) * lp_mag(f, 6000, 2))
    return 0.35 * mains + 0.12 * blade + 0.45 * air + 0.2 * duct + 0.02 * hissing


# ---------------------------------------------------------------------------
# Music fallbacks: stereo loops, every tone a whole number of cycles per loop

def cyc(f, length):
    """f rounded to a whole number of cycles in `length` seconds."""
    return round(f * length) / length


def pad(t, length, f, harmonics, rng, bright=1.0):
    """A soft organ-like tone: harmonics falling off by `bright`; with a length, every
    harmonic runs a whole number of cycles in it, so it loops."""
    return sum(bright ** k / (k + 1) * np.sin(TAU * (cyc(f * (k + 1), length) if length else f * (k + 1)) * t
                                              + rng.uniform(0, TAU))
               for k in range(harmonics))


def lfo(t, length, rng, *parts):
    """Slow swells: (cycles per loop, depth) pairs."""
    return sum(a * np.sin(TAU * k * t / length + rng.uniform(0, TAU)) for k, a in parts)


def hull_groan(rng, length, f=1.0):
    """The station's hull flexing: a long, slow metal groan."""
    t = timeline(length)
    x = creak(rng, t, 0.0, length, 9, 22, list(np.array([85, 190, 310, 470, 720]) * f), 30.0)
    return norm(lowpass(x, 1200)) * bump(t, 0.0, length, 0.8)


def struck_metal(rng, length, f, tau):
    """A distant struck girder: inharmonic modes with a long ring."""
    t = timeline(length)
    ratios = [1.0, 2.32, 4.25, 6.63, 9.38]
    amps = [1.0, 0.6, 0.4, 0.25, 0.12]
    taus = [tau, tau * 0.7, tau * 0.45, tau * 0.3, tau * 0.2]
    beat = modes(t, [f * 1.003], [0.5], [tau])
    return (modes(t, [f * r for r in ratios], amps, taus) + beat) * np.clip(t / 0.004, 0, 1)


def stereo_room(rng, x, seconds, wet, bright, circular=True):
    """Two decorrelated reverbs of a mono or stereo signal."""
    xs = x if x.ndim == 2 else np.stack([x, x])
    return np.stack([xs[c] + wet * convolve(xs[c], reverb_ir(rng, seconds, bright), circular) for c in range(2)])


def pump_cycle(rng, length):
    """A far-off pump working: a muffled thump, then its valve knocking shut."""
    t = timeline(length)
    beat = thump(rng, t, 0.0, 70, 38, 0.18, 0.15)
    valve = modes(t, [310, 520, 870], [1.0, 0.5, 0.3], [0.05, 0.04, 0.03], 0.55)
    valve += 0.15 * click(rng, t, 0.55, 0.004, 400)
    return lowpass(beat + 0.4 * valve, 900)


def music_drone(rng):
    """The calm decks' drone: a dark root and fifth that breathe (with a sub an octave
    down for weight), a faint minor-second shimmer, the steady air and electric buzz of
    the station, a pump working somewhere far off, a ghostly whistle in the vents, and
    now and then the hull groaning or a girder knocking (48 s loop). The air stays level
    rather than swelling, so it reads as machinery, not surf."""
    L = 48.0
    t = timeline(L)
    n = len(t)
    chans = []
    for c in range(2):
        sub = pad(t, L, 36.71, 3, rng, 0.5) * (0.7 + lfo(t, L, rng, (1, 0.2)))
        root = pad(t, L, 73.42 * (1 + 0.0004 * c), 10, rng, 0.85) * (0.7 + lfo(t, L, rng, (1, 0.18), (3, 0.1)))
        fifth = pad(t, L, 110.0 * (1 - 0.0004 * c), 7, rng, 0.75)
        fifth *= np.clip(0.35 + lfo(t, L, rng, (1, 0.3), (2, 0.12)), 0, None)
        shimmer = sum(np.sin(TAU * cyc(f, L) * t + rng.uniform(0, TAU)) for f in (293.66 + 0.1 * c, 311.13 - 0.08 * c))
        shimmer *= np.clip(0.3 + lfo(t, L, rng, (2, 0.5)), 0, None) ** 2
        air = loop_noise(rng, n, lambda f: hp_mag(f, 150) * lp_mag(f, 900, 2) / np.sqrt(np.maximum(f, 20)))
        buzz = np.tanh(2.0 * sum(w * np.sin(TAU * f * t + rng.uniform(0, TAU))
                                 for f, w in ((100, 1.0), (200, 0.5), (300, 0.35), (400, 0.2))))
        whistle = loop_noise(rng, n, lambda f: bp_mag(f, 420, 12) + 0.7 * bp_mag(f, 935, 15))
        whistle *= np.clip(lfo(t, L, rng, (3, 1.0)), 0, None) ** 2
        chans.append(0.3 * norm(sub) + 0.6 * norm(root) + 0.3 * norm(fifth) + 0.05 * shimmer
                     + 0.07 * air + 0.025 * norm(buzz) + 0.04 * whistle)
    x = np.stack(chans)
    events = np.zeros(n)
    for at, f in ((11.0, 1.0), (33.5, 0.85)):
        place(events, 0.4 * hull_groan(rng, 3.5, f), at, wrap=True)
    place(events, 0.3 * lowpass(struck_metal(rng, 8.0, 116.0, 2.5), 1500), 24.0, wrap=True)
    pump = pump_cycle(rng, 1.5)
    for i in range(8):
        place(events, 0.22 * rng.uniform(0.8, 1.0) * pump, 2.0 + i * 6.0, wrap=True)
    x += np.stack([events, np.roll(events, secs(0.013))])
    return stereo_room(rng, x, 5.0, 0.4, 2500)


def music_hunted(rng):
    """Being hunted: a heartbeat at 80 beats a minute, a low eighth-note throb that steps
    up a semitone every fourth bar, a thin high cluster, ticking, and a steady rush of
    air (24 s loop; the beats sit a little after the seam)."""
    L = 24.0
    beat = 0.75
    off = 0.1
    t = timeline(L)
    n = len(t)
    heart = np.zeros(n)
    seg = timeline(0.7)
    lub = thump(rng, seg, 0.0, 75, 48, 0.12, 0.2) + 0.4 * modes(seg, [110, 175], [1.0, 0.5], [0.05, 0.03])
    dub = thump(rng, seg, 0.0, 85, 55, 0.09, 0.2) + 0.3 * modes(seg, [125, 200], [1.0, 0.5], [0.04, 0.025])
    duck = np.zeros(n)
    for i in range(32):
        place(heart, lub, off + i * beat, wrap=True)
        place(heart, 0.6 * dub, off + i * beat + 0.24, wrap=True)
        place(duck, np.exp(-seg / 0.18), off + i * beat, wrap=True)
    chans = []
    for c in range(2):
        throb = np.zeros(n)
        note = timeline(0.37)
        for i in range(64):
            f = 82.41 if (i // 8) % 4 < 3 else 87.31
            tone = pad(note, None, f, 16, rng, 0.85) * np.exp(-note / 0.14) * np.clip(note / 0.004, 0, 1)
            place(throb, (1.0 if i % 2 == 0 else 0.6) * tone, off + i * beat / 2, wrap=True)
        throb = lowpass(throb, 1000, circular=True)
        drone = (0.5 * pad(t, L, 41.2, 3, rng, 0.5) + pad(t, L, 82.41, 8, rng, 0.75)) * (1 - 0.4 * duck)
        cluster = sum(np.sin(TAU * cyc(f, L) * t + rng.uniform(0, TAU)) for f in (659.25 + 0.2 * c, 698.46 - 0.15 * c))
        cluster *= (0.5 + 0.5 * np.sin(TAU * t / L + c)) ** 2
        air = loop_noise(rng, n, lambda f: hp_mag(f, 300) * lp_mag(f, 2500, 2) / np.sqrt(np.maximum(f, 20)))
        chans.append(0.6 * norm(throb) + 0.3 * norm(drone) + 0.05 * cluster + 0.05 * air)
    ticks = np.zeros(n)
    tick_t = timeline(0.03)
    for i in range(64):
        place(ticks, modes(tick_t, [3400, 5100], [1.0, 0.5], [0.006, 0.004]), off + i * beat / 2 + beat / 4, wrap=True)
    x = np.stack(chans) + 0.8 * norm(heart) + 0.05 * np.stack([ticks, 0.7 * ticks])
    return stereo_room(rng, x, 2.5, 0.3, 3000)


def music_title(rng):
    """The title: almost nothing. A low tritone that swells and fades, air singing faintly in
    the hull, and far off, twice a loop, a struck girder ringing out (48 s loop)."""
    L = 48.0
    t = timeline(L)
    n = len(t)
    chans = []
    for c in range(2):
        sub = pad(t, L, 55.0, 2, rng, 0.4)
        low = pad(t, L, 110.0, 6, rng, 0.7) * np.clip(0.3 + lfo(t, L, rng, (1, 0.4)), 0, None)
        tri = pad(t, L, 155.56 * (1 + 0.0004 * c), 5, rng, 0.6)
        tri *= np.clip(0.2 + lfo(t, L, rng, (1, 0.35), (2, 0.15)), 0, None)
        sing = loop_noise(rng, n, lambda f: bp_mag(f, 220, 40) + bp_mag(f, 311.1, 40) + 0.7 * bp_mag(f, 466.2, 40)
                          + 0.5 * bp_mag(f, 659.3, 50))
        sing *= np.clip(0.3 + lfo(t, L, rng, (1, 0.4), (3, 0.2)), 0, None)
        air = loop_noise(rng, n, lambda f: hp_mag(f, 100) * lp_mag(f, 1500, 2) / np.sqrt(np.maximum(f, 20)))
        chans.append(0.15 * norm(sub) + 0.4 * norm(low) + 0.25 * norm(tri) + 0.12 * sing + 0.12 * air)
    x = np.stack(chans)
    metal = np.zeros(n)
    place(metal, struck_metal(rng, 12.0, 233.0, 3.5), 3.0, wrap=True)
    place(metal, 0.8 * struck_metal(rng, 12.0, 220.0, 3.5), 27.0, wrap=True)
    metal = lowpass(metal, 2200, circular=True)
    groan = np.zeros(n)
    place(groan, 0.3 * hull_groan(rng, 4.0, 0.9), 16.0, wrap=True)
    place(groan, 0.25 * hull_groan(rng, 4.0, 1.1), 40.0, wrap=True)
    x += np.stack([0.5 * metal + groan, 0.5 * np.roll(metal, secs(0.017)) + groan])
    return stereo_room(rng, x, 6.0, 0.55, 2200)


# ---------------------------------------------------------------------------
# The catalogue: name -> (builder, kind); kind is "sfx", "loop" or "music"

VOICES = {
    "taken": (taken_alert, taken_idle, taken_attack, taken_hurt),
    "skitter": (skitter_alert, skitter_idle, skitter_attack, skitter_hurt),
    "stalker": (stalker_alert, stalker_idle, stalker_attack, stalker_hurt),
    "feeder": (feeder_alert, feeder_idle, feeder_attack, feeder_hurt),
    "watcher": (watcher_alert, watcher_idle, watcher_attack, watcher_hurt),
}
TAKES = 3
MUSIC_LUFS = {"drone": -20.0, "hunted": -18.0, "title": -20.0}


def catalogue():
    sounds = {}
    for build in (watcher_scream, vent_crawl, taken_rise, taken_die, stalker_die, spit, skitter_leap, shove,
                  sever, robot_drop, pod_hatch, heart_die, heal, stim, feeder_grab, robot_alert, robot_idle):
        sounds[build.__name__] = (build, "sfx")
    for build in (heart_beat_loop, bloom_loop, hum_loop):
        sounds[build.__name__] = (build, "loop")
    for kind, builders in VOICES.items():
        for what, build in zip(("alert", "idle", "attack", "hurt"), builders):
            for i in range(TAKES):
                sounds[f"{kind}_{what}_{i + 1}"] = (lambda rng, b=build, i=i: b(rng, i), "sfx")
    for name, build in (("drone", music_drone), ("hunted", music_hunted), ("title", music_title)):
        sounds[name] = (build, "music")
    return dict(sorted(sounds.items()))


def finish(x, loop):
    """Removes rumble and DC, fades one-shots in and out, and normalises the peak to -3 dBFS."""
    if x.ndim == 2:
        x = np.stack([highpass(c, 25, circular=loop) for c in x])
    else:
        x = highpass(x, 25, circular=loop)
    if not loop:
        n_in, n_out = secs(0.0015), min(secs(0.015), x.shape[-1] // 8)
        x[..., :n_in] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n_in))
        x[..., -n_out:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n_out))
    return x * (PEAK / np.abs(x).max())


def write_wav(path, x):
    frames = x.T if x.ndim == 2 else x
    pcm = np.clip(np.round(frames * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[0] if x.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def lufs(ffmpeg, path):
    """Integrated loudness of a file, from ffmpeg's ebur128 filter."""
    out = subprocess.run([ffmpeg, "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", out)
    return float(m[-1]) if m else -70.0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("out_dir", help="where the sound effects (.ogg) go")
    parser.add_argument("--wav", help="also keep the WAVs in this folder")
    parser.add_argument("--only", help="comma-separated names to build (a voice without its number builds every take)")
    parser.add_argument("--music", help="where the music goes (default: music beside out_dir)")
    args = parser.parse_args()
    ffmpeg = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"
    sounds = catalogue()
    names = list(sounds)
    if args.only:
        names = []
        for name in args.only.split(","):
            takes = [k for k in sounds if re.fullmatch(re.escape(name) + r"_\d+", k)]
            if name in sounds:
                names.append(name)
            elif takes:
                names += takes
            else:
                sys.exit(f"unknown sound: {name}")
    music_dir = args.music or os.path.join(os.path.dirname(os.path.abspath(args.out_dir)), "music")
    with tempfile.TemporaryDirectory() as tmp:
        wav_dir = args.wav or tmp
        os.makedirs(wav_dir, exist_ok=True)
        for name in names:
            build, kind = sounds[name]
            loop = kind != "sfx"
            x = finish(np.asarray(build(rng_for(name)), dtype=float), loop)
            wav = os.path.join(wav_dir, name + ".wav")
            write_wav(wav, x)
            note = "  loop" if loop else ""
            if kind == "music":
                level = lufs(ffmpeg, wav)
                if level > MUSIC_LUFS[name]:
                    x *= 10 ** ((MUSIC_LUFS[name] - level) / 20)
                    write_wav(wav, x)
                note = f"  loop, stereo, {lufs(ffmpeg, wav):.1f} LUFS"
            out_dir = music_dir if kind == "music" else args.out_dir
            os.makedirs(out_dir, exist_ok=True)
            subprocess.run([ffmpeg, "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "7" if loop else "5",
                            "-fflags", "+bitexact", "-flags:a", "+bitexact",
                            os.path.join(out_dir, name + ".ogg")], check=True)
            print(f"{name:24s} {x.shape[-1] / SR:5.2f} s{note}", flush=True)


if __name__ == "__main__":
    main()
