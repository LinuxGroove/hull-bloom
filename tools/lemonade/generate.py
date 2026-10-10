#!/usr/bin/env python3
"""Makes Hull Bloom's music, voice lines and sound effects with Lemonade.

    python3 tools/lemonade/generate.py [--only music|voices|sfx] [--force] [name ...]

Reads tools/lemonade/audio.json and asks the Lemonade server named there (or
--server) for every entry: ACE-Step for music, Kokoro for voice lines and
ThinkSound for sound effects. Each file is written as 44.1 kHz Ogg Vorbis
(music stereo, the rest mono) with its leading and trailing silence trimmed
and its peak at about -3 dBFS. Loops (music with "loop": true, sounds named
*_loop) are cut where their end sounds most like their start, then the tail
past that point is crossfaded into the head, so they repeat without a seam.

Music and sound effects are made in several takes with different seeds, and
the take kept is the one whose length, loudness, ending and (for loops) seam
fit best, and for sounds how many separate sounds it has and how quiet its
background is. Nobody listens, so these are the judges unless an entry picks
a take by its seed. When ThinkSound makes several barks for one, the cleanest
is cut out of the take ("events"). Lemonade's raw takes
are cached in --takes-dir, outside the repository, so running again only
redoes the processing. Files that exist are skipped unless --force; names
given on the command line (file stems like "doorbell" or "night") limit the
run to those files. An entry with "skip" set is never made (the reason says
why, e.g. the synthesized sound was better).

Every file made is recorded in tools/lemonade/generated.json, and
assets/audio/GENERATED.md is written from that record.

Optional fields an entry can carry besides those the game needs:
  seconds    length to ask for (music: the loop length; sfx: the take)
  takes      how many takes to make (default 3 for music, 6 for sfx)
  seed       first seed (default: from the file name, so runs repeat)
  steps, cfg passed to the model as they are
  events     sfx one-shots: how many separate sounds to keep from a take
  fade_out   sfx one-shots: seconds to fade at the end, for sounds still going
             when the take stops (machines, a kettle)
  wind_down  sfx one-shots: seconds over which the take slows to a stop
  steady     sfx loops: keep the take whose level varies least
  crossfade  loops: crossfade length in seconds
  lufs       music: the loudness to aim for after peak normalisation
  say        voice lines: what Kokoro reads, when the text needs help
  speed      voices (per voice): Kokoro speaking speed
  pick, why  the seed of the take to keep instead of the best scoring one, and why
  skip       why this sound is not made (the file is left as it is)

Needs Python 3 and ffmpeg (with libvorbis); nothing else.
"""
import argparse
import array
import datetime
import hashlib
import json
import math
import operator
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/lemonade/audio.json"
RECORD = ROOT / "tools/lemonade/generated.json"
REPORT = ROOT / "assets/audio/GENERATED.md"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "hull-bloom-lemonade"

SR = 44100
PEAK_DB = -3.0
FRAME = 441  # 10 ms
KINDS = ("music", "voices", "sfx")
QUALITY = {"music": 5, "voices": 5, "sfx": 5, "sfx_loop": 7}


# ---------------------------------------------------------------------------
# Lemonade

def post(server, path, body, timeout):
    """POSTs JSON and returns the response bytes, retrying a few times."""
    data = json.dumps(body).encode()
    for attempt in range(4):
        req = urllib.request.Request(server.rstrip("/") + path, data=data,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = r.read()
                if not out.startswith(b"RIFF"):
                    raise RuntimeError("not a WAV: %r" % out[:200])
                return out
        except (urllib.error.URLError, RuntimeError, TimeoutError) as e:
            detail = e.read()[:300] if isinstance(e, urllib.error.HTTPError) else e
            if attempt == 3:
                raise RuntimeError("Lemonade %s failed: %s" % (path, detail))
            print("    retrying after: %s" % detail, flush=True)
            time.sleep(2 ** (attempt + 1))


def fetch(server, path, body, timeout, cache, use_cache):
    """A take from Lemonade (the path of its WAV), from the cache when the same
    request was made before."""
    key = hashlib.sha256(json.dumps([path, body], sort_keys=True).encode()).hexdigest()[:16]
    cached = cache / (key + ".wav")
    if use_cache and cached.exists():
        return cached
    t = time.time()
    out = post(server, path, body, timeout)
    print("    %s%s: %.1f s" % (body["model"], " seed %d" % body["seed"] if "seed" in body else "",
                                time.time() - t), flush=True)
    cache.mkdir(parents=True, exist_ok=True)
    cached.write_bytes(out)
    (cache / (key + ".json")).write_text(json.dumps(body, indent=1))
    return cached


def models(server):
    try:
        with urllib.request.urlopen(server.rstrip("/") + "/api/v1/models", timeout=30) as r:
            return {m["id"]: m for m in json.load(r)["data"]}
    except Exception as e:
        sys.exit("Can't reach Lemonade at %s: %s" % (server, e))


def server_version(server):
    try:
        with urllib.request.urlopen(server.rstrip("/") + "/api/v1/health", timeout=30) as r:
            return json.load(r).get("version", "")
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Audio in and out (interleaved float arrays at 44.1 kHz)

def ffmpeg(args, data=None, level="error"):
    p = subprocess.run(["ffmpeg", "-v", level, "-nostdin"] + args, input=data,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError("ffmpeg failed: " + p.stderr.decode()[-500:])
    return p.stdout, p.stderr.decode()


def decode(path, channels, rate=SR):
    raw, _ = ffmpeg(["-i", str(path), "-af", "aresample=resampler=soxr",
                     "-ac", str(channels), "-ar", str(rate), "-f", "f32le", "-"])
    x = array.array("f")
    x.frombytes(raw)
    return x


def encode(x, channels, path, quality, gain):
    path.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg(["-y", "-f", "f32le", "-ar", str(SR), "-ac", str(channels), "-i", "-",
            "-af", "volume=%.6f:precision=float" % gain, "-map_metadata", "-1",
            "-fflags", "+bitexact", "-flags:a", "+bitexact",
            "-c:a", "libvorbis", "-q:a", str(quality), str(path)], x.tobytes())


def clipped_runs(path):
    """How many times the raw take sits flat at full scale for 3 samples or
    more: clipping, rather than a take that was merely normalised to 0 dBFS."""
    raw, _ = ffmpeg(["-i", str(path), "-f", "f32le", "-"])
    x = array.array("f")
    x.frombytes(raw)
    if peak(x) < 0.999:
        return 0
    runs = run = 0
    for v in map(abs, x):
        if v >= 0.999:
            run += 1
        else:
            runs += run >= 3
            run = 0
    return runs


def loudness(x, channels):
    """Integrated loudness (LUFS) of x as it will be written."""
    _, err = ffmpeg(["-f", "f32le", "-ar", str(SR), "-ac", str(channels), "-i", "-",
                     "-af", "ebur128", "-f", "null", "-"], x.tobytes(), level="info")
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", err)
    return float(m[-1]) if m else -70.0


def db(v):
    return 20 * math.log10(max(v, 1e-9))


def peak(x):
    return max(max(x, default=0.0), -min(x, default=0.0))


def frame_levels(x, channels, frame=FRAME):
    """Peak level in dBFS of each 10 ms frame."""
    step = frame * channels
    return [db(peak(x[i:i + step])) for i in range(0, len(x), step)]


def frame_rms(x, channels, frame=FRAME):
    step = frame * channels
    out = []
    for i in range(0, len(x), step):
        s = x[i:i + step]
        out.append(10 * math.log10(sum(map(operator.mul, s, s)) / max(len(s), 1) + 1e-12))
    return out


def mono(x, channels, start, length):
    """Frames start..start+length of x as one channel."""
    s = x[start * channels:(start + length) * channels]
    if channels == 1:
        return s
    return array.array("f", map(operator.add, s[0::2], s[1::2]))


def dot(a, b):
    return sum(map(operator.mul, a, b))


def correlation(a, b):
    """Pearson correlation of two equal-length sequences."""
    ma, mb = sum(a) / len(a), sum(b) / len(b)
    a = [v - ma for v in a]
    b = [v - mb for v in b]
    return dot(a, b) / math.sqrt(dot(a, a) * dot(b, b) + 1e-12)


def fade(x, channels, start, length, rising):
    """Fades frames start..start+length in place, raised-cosine."""
    for i in range(length):
        g = 0.5 - 0.5 * math.cos(math.pi * (i + 0.5) / length)
        if not rising:
            g = 1.0 - g
        for c in range(channels):
            x[(start + i) * channels + c] *= g


def trim(x, channels, below_db, head_ms, tail_ms):
    """Cuts what is more than below_db under the peak off both ends, keeping a
    little lead-in and a faded tail. Returns x and how much of the raw end was
    still sounding (dB under the peak) when the take stopped."""
    lv = frame_levels(x, channels)
    top = max(lv)
    loud = [i for i, v in enumerate(lv) if v > top - below_db]
    first = max(loud[0] * FRAME - int(head_ms * SR / 1000), 0)
    last = min((loud[-1] + 1) * FRAME + int(tail_ms * SR / 1000), len(x) // channels)
    end_db = max(lv[-5:]) - top
    y = x[first * channels:last * channels]
    n = len(y) // channels
    fade(y, channels, 0, min(int(0.002 * SR), n), True)
    if tail_ms:
        f = min(int(tail_ms * SR / 1000), n)
        fade(y, channels, n - f, f, False)
    return y, end_db


def wind_down(x, channels, seconds, lead=0.6):
    """Plays x at full speed for `lead` seconds, then slows it to a stop over
    `seconds` (pitch and level falling together, like a machine coasting to a
    halt): for machines ThinkSound only ever makes running."""
    n = len(x) // channels
    out = array.array("f")
    pos = 0.0
    total = int((lead + seconds) * SR)
    start = int(lead * SR)
    for i in range(total):
        rate = 1.0 if i < start else (1.0 - (i - start) / (total - start)) ** 1.5
        j = int(pos)
        if j + 1 >= n or rate < 0.005:
            break
        f = pos - j
        level = 1.0 if i < start else rate ** 0.5
        for c in range(channels):
            out.append((x[j * channels + c] * (1 - f) + x[(j + 1) * channels + c] * f) * level)
        pos += rate
    fade(out, channels, len(out) // channels - 441, 441, False)
    return out


def segments(lv, below_db=18, gap_ms=60):
    """The separate sounds in a list of frame levels, as [first, last] frame
    pairs: runs of frames within below_db of the peak, joined across gaps
    shorter than gap_ms."""
    top = max(lv)
    segs = []
    for i, v in enumerate(lv):
        if v > top - below_db:
            if segs and (i - segs[-1][1] - 1) * 10 < gap_ms:
                segs[-1][1] = i
            else:
                segs.append([i, i])
    return segs


def pick_events(x, channels, n):
    """When a take has more than n separate sounds (ThinkSound often barks three
    times when asked for one), keeps the n in a row that are loudest and have
    died away best before the next one starts."""
    lv = frame_levels(x, channels)
    segs = segments(lv)
    if len(segs) <= n:
        return x
    top = max(lv)
    best = None
    for i in range(len(segs) - n + 1):
        first = max(segs[i][0] - 3, segs[i - 1][1] + 1 if i else 0)
        last = segs[i + n][0] - 2 if i + n < len(segs) else len(lv)
        peak_db = max(lv[first:last])
        end_db = max(lv[max(last - 3, first):last]) - peak_db
        cost = max(0.0, end_db + 35) / 10 + (top - peak_db) / 12
        if best is None or cost < best[0]:
            best = (cost, first, last)
    _, first, last = best
    return x[first * FRAME * channels:last * FRAME * channels]


def floor_db(x, channels):
    """The noise floor: the 10th percentile frame level under the peak."""
    lv = sorted(frame_rms(x, channels))
    return lv[len(lv) // 10] - db(peak(x))


# ---------------------------------------------------------------------------
# Loops

def band_envelope(x, channels):
    """Log energy per 10 ms frame in four bands (low, low mid, high mid, high),
    which is enough to tell where the music is doing the same thing."""
    pan = "pan=mono|c0=0.5*c0+0.5*c1," if channels == 2 else ""
    graph = (pan + "asplit=4[a][b][c][d];[a]lowpass=f=250[a1];"
             "[b]bandpass=f=700:width_type=o:w=1.5[b1];[c]bandpass=f=2200:width_type=o:w=1.5[c1];"
             "[d]highpass=f=5000[d1];[a1][b1][c1][d1]amerge=inputs=4")
    raw, _ = ffmpeg(["-f", "f32le", "-ar", str(SR), "-ac", str(channels), "-i", "-",
                     "-filter_complex", graph, "-f", "f32le", "-"], x.tobytes())
    b = array.array("f")
    b.frombytes(raw)
    n = len(b) // 4
    bands = []
    for k in range(4):
        ch = b[k::4]
        e = []
        for i in range(0, n - FRAME + 1, FRAME):
            s = ch[i:i + FRAME]
            e.append(10 * math.log10(dot(s, s) / FRAME + 1e-10))
        top = max(e)
        bands.append([max(v, top - 60.0) for v in e])
    # onsets: how much the level rises from one frame to the next
    onset = [0.0] + [sum(max(bands[k][i] - bands[k][i - 1], 0.0) for k in range(4))
                     for i in range(1, len(bands[0]))]
    return bands + [onset]


def window_cost(feats, a, b, w, step=1):
    """How different the frames after a are from those after b (mean squared dB)."""
    total = 0.0
    for f in feats:
        d = list(map(operator.sub, f[a:a + w:step], f[b:b + w:step]))
        total += dot(d, d)
    return total / (len(feats) * len(range(0, w, step)))


def make_loop(x, channels, target_s, xfade_s, window_s, max_start_s):
    """Picks a loop start S and end E where the music around E (a little before
    and after) is most like the music around S, then crossfades x[E:E+L] into
    x[S:S+L]. The result plays x[S:E] and wraps from x[E-1] straight into what
    follows x[E], which turns into what follows x[S]. S can be some way in, so
    a sparse intro the model added is left out of the loop."""
    n = len(x) // channels
    feats = band_envelope(x, channels)
    frames = len(feats[0])
    L = int(xfade_s * SR)
    w = max(int(window_s * 100), 2 * (L // FRAME + 1))
    h = w // 2  # frames of the window before the loop point
    last_e = min(frames - (w - h), (n - L) // FRAME - 1)
    starts = range(h, max(h, min(int(max_start_s * 100), frames // 4)) + 1)
    shortest = int(target_s * 100 * 0.85) if target_s else frames // 2

    def length_cost(s, e):
        if target_s:
            return 2.0 * abs((e - s) / 100 - target_s) / target_s
        return 0.5 * (1 - (e - s) / last_e)

    # coarse search every 50 ms, then every 10 ms around the best
    coarse = [(window_cost(feats, s - h, e - h, w, 5), s, e)
              for s in starts[::5] for e in range(s + shortest, last_e + 1, 5)]
    if not coarse:
        raise RuntimeError("take too short to loop (%d frames)" % frames)
    typical = sorted(c for c, _, _ in coarse)[len(coarse) // 2] or 1.0
    _, s0, e0 = min(coarse, key=lambda t: t[0] / typical + length_cost(t[1], t[2]))
    fine = [(window_cost(feats, s - h, e - h, w), s, e)
            for s in range(max(s0 - 5, starts[0]), min(s0 + 6, starts[-1] + 1))
            for e in range(max(e0 - 5, s + shortest), min(e0 + 6, last_e + 1))]
    cost, s, e = min(fine, key=lambda t: t[0] / typical + length_cost(t[1], t[2]))

    # line the beats up: move E (up to 300 ms) so the onsets after it fall
    # where they do after S, or the crossfade doubles every hit
    onset = [sum(feats[-1][max(i - 1, 0):i + 2]) for i in range(frames)]
    m = min(6 * w // 4, frames - e - 31)
    a = onset[s:s + m]
    shifts = [(correlation(a, onset[e + d:e + d + m]), d)
              for d in range(-30, 31) if s + shortest <= e + d <= last_e]
    beat_match, d = max(shifts)
    e += d
    S, E = s * FRAME, e * FRAME

    # line the waveforms up to the sample (keeps hums and bass notes in phase)
    k = min(L, 4096)
    a = mono(x, channels, S, k)
    best_d, best_c = 0, -2.0
    for d in range(-min(441, E - S - L), min(441, n - L - E) + 1):
        b = mono(x, channels, E + d, k)
        c = dot(a, b) / math.sqrt(dot(a, a) * dot(b, b) + 1e-12)
        if c > best_c:
            best_c, best_d = c, d
    E += best_d

    # the fade law follows how alike the two crossfaded stretches are:
    # linear when they match, equal power when they don't
    a, b = mono(x, channels, S, L), mono(x, channels, E, L)
    r = min(max(dot(a, b) / math.sqrt(dot(a, a) * dot(b, b) + 1e-12), 0.0), 1.0)
    y = x[S * channels:E * channels]
    for i in range(L):
        t = (i + 0.5) / L
        gi, go = t, 1 - t
        g = 1 / math.sqrt(gi * gi + go * go + 2 * r * gi * go)
        gi, go = gi * g, go * g
        for c in range(channels):
            j = i * channels + c
            y[j] = y[j] * gi + x[(E + i) * channels + c] * go
    seam = cost / typical
    return y, {"start_s": round(S / SR, 3), "end_s": round(E / SR, 3), "crossfade_s": round(xfade_s, 2),
               "match": round(r, 2), "beat_match": round(beat_match, 2), "seam_cost": round(seam, 3)}


def steadiness(x, channels):
    """Spread (dB) of the 1 s levels: how even a loop is."""
    lv = frame_rms(x, channels, SR)
    if len(lv) < 3:
        return 0.0
    mean = sum(lv) / len(lv)
    return math.sqrt(sum((v - mean) ** 2 for v in lv) / len(lv))


# ---------------------------------------------------------------------------
# Jobs

def stem(file):
    return Path(file).stem


def seed_for(entry):
    return int(entry.get("seed", zlib.crc32(entry["file"].encode()) % 100000))


def jobs(manifest):
    out = []
    m = manifest["music"]
    for t in m["tracks"]:
        loop = t.get("loop", False)
        out.append(dict(t, kind="music", model=m["model"], channels=2, loop=loop,
                        takes=t.get("takes", 3),
                        ask=t["seconds"] + (max(10, 0.2 * t["seconds"]) if loop else 0)))
    v = manifest["voices"]
    for name, voice in v["voices"].items():
        for line in voice["lines"]:
            out.append(dict(line, kind="voices", model=v["model"], channels=1, loop=False, takes=1,
                            voice=voice["kokoro_voice"], who=name, speed=voice.get("speed", 1.0)))
    s = manifest["sfx"]
    for snd in s["sounds"]:
        loop = stem(snd["file"]).endswith("_loop")
        out.append(dict(snd, kind="sfx", model=s["model"], channels=1, loop=loop,
                        takes=snd.get("takes", 6), ask=snd.get("seconds", 10 if loop else 3)))
    return out


def request(job, seed):
    if job["kind"] == "voices":
        return "/api/v1/audio/speech", {"model": job["model"], "input": job.get("say", job["text"]),
                                        "voice": job["voice"], "speed": job["speed"],
                                        "response_format": "wav"}
    body = {"model": job["model"], "prompt": job["prompt"], "duration": round(job["ask"], 1), "seed": seed}
    for k in ("steps", "cfg"):
        if k in job:
            body[k] = job[k]
    return "/api/v1/audio/generations", body


def process(job, raw_path):
    """Turns one raw take into the finished samples, with the numbers the takes are judged by."""
    ch = job["channels"]
    x = decode(raw_path, ch)
    info = {"raw_s": round(len(x) / ch / SR, 2), "clipped_runs": clipped_runs(raw_path)}
    if job["loop"]:
        x, _ = trim(x, ch, 60, 0, 0)
        if job["kind"] == "music":
            y, loop = make_loop(x, ch, job["seconds"], job.get("crossfade", 1.5), 4.0, 0.15 * job["seconds"])
        else:
            n = len(x) / ch / SR
            y, loop = make_loop(x, ch, None, job.get("crossfade", min(0.5, n / 8)), min(1.5, n / 4), n / 10)
        info["loop"] = loop
        info["spread_db"] = round(steadiness(y, ch), 1)
    elif job["kind"] == "voices":
        y, info["end_db"] = trim(x, ch, 40, 10, 60)
    elif job["kind"] == "music":
        y, info["end_db"] = trim(x, ch, 50, 0, 300)
        if info["end_db"] > -30:  # the take stops mid-note: fade its last second and a half
            n = len(y) // ch
            f = min(int(1.5 * SR), n // 3)
            fade(y, ch, n - f, f, False)
            info["faded_end"] = True
    else:
        if "events" in job:
            x = pick_events(x, ch, job["events"])
        y, info["end_db"] = trim(x, ch, 45, 5, 80)
        if "wind_down" in job:
            y = wind_down(y, ch, job["wind_down"])
        if "fade_out" in job:  # a sound that runs on past the take, faded rather than cut
            n = len(y) // ch
            f = min(int(job["fade_out"] * SR), n // 2)
            fade(y, ch, n - f, f, False)
        info["events"] = len(segments(frame_levels(y, ch)))
        info["floor_db"] = round(floor_db(y, ch), 1)
    p = peak(y)
    gain = 10 ** (PEAK_DB / 20) / max(p, 1e-9)
    info["seconds"] = round(len(y) / ch / SR, 2)
    info["gain_db"] = round(db(gain), 1)
    info["lufs"] = round(loudness(array.array("f", map(gain.__mul__, y)), ch), 1) if job["kind"] == "music" else None
    if "end_db" in info:
        info["end_db"] = round(info["end_db"], 1)
    return y, gain, info


def score(job, info):
    """Lower is better. Each part is about 1 when it is clearly wrong."""
    parts = {}
    if info["clipped_runs"]:
        parts["clipped"] = min(1.0, info["clipped_runs"] / 50)
    if job["kind"] == "music":
        if job["loop"]:
            parts["length"] = abs(info["loop"]["end_s"] - info["loop"]["start_s"] - job["seconds"]) / job["seconds"] * 2
            parts["seam"] = info["loop"]["seam_cost"]
            parts["spread"] = max(0.0, info["spread_db"] - 4.0) / 4.0
        else:
            parts["length"] = max(0.0, info["seconds"] - job["seconds"]) / job["seconds"] * 2 \
                + max(0.0, job["seconds"] * 0.4 - info["seconds"]) / job["seconds"] * 2
            parts["ending"] = 0.5 if info.get("faded_end") else 0.0
        parts["loudness"] = abs(info["lufs"] - job.get("lufs", -16.0)) / 4.0
    elif job["kind"] == "sfx":
        if job["loop"]:
            parts["seam"] = info["loop"]["seam_cost"]
            if job.get("steady"):
                parts["spread"] = max(0.0, info["spread_db"] - 2.0) / 3.0
        else:
            if "events" in job:
                parts["events"] = 2.0 * abs(info["events"] - job["events"]) / max(job["events"], 1)
            parts["cut_off"] = max(0.0, info["end_db"] + 30.0) / 10.0
            parts["noise"] = max(0.0, info["floor_db"] + 45.0) / 10.0
            # small, so they only settle ties: a cleaner ending and a quieter floor
            parts["tail"] = max(0.0, info["end_db"] + 60.0) / 300.0
            parts["floor"] = max(0.0, info["floor_db"] + 70.0) / 300.0
    return round(sum(parts.values()), 3), {k: round(v, 2) for k, v in parts.items()}


def verify(path, channels, kind):
    """Problems with a written file, as a list of strings (empty when fine)."""
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels,sample_rate,codec_name",
                          "-show_entries", "format=duration", "-of", "json", str(path)],
                         capture_output=True, text=True)
    meta = json.loads(out.stdout)
    st = meta["streams"][0]
    dur = float(meta["format"]["duration"])
    bad = []
    if st["codec_name"] != "vorbis" or int(st["channels"]) != channels or int(st["sample_rate"]) != SR:
        bad.append("format %s/%s ch/%s Hz" % (st["codec_name"], st["channels"], st["sample_rate"]))
    x = decode(path, channels)
    p = db(peak(x))
    rms = 10 * math.log10(dot(x, x) / max(len(x), 1) + 1e-12)
    if p > -0.5:
        bad.append("peak %.1f dBFS (clips)" % p)
    if p < -6 or rms < -50:
        bad.append("too quiet (peak %.1f, rms %.1f dBFS)" % (p, rms))
    if kind == "voices" and dur > 4.0:
        bad.append("line is %.1f s long" % dur)
    return {"seconds": round(dur, 2), "peak_db": round(p, 1), "rms_db": round(rms, 1)}, bad


# ---------------------------------------------------------------------------
# The record and the report

def render(record, manifest, version):
    r = record["files"]
    lines = ["# Generated audio", "",
             "Made with [Lemonade](https://lemonade-server.ai)%s by `tools/lemonade/generate.py` from "
             "`tools/lemonade/audio.json`; `tools/lemonade/generated.json` has the full record, including "
             "every take's numbers. Released as CC0, like the rest of Hull Bloom's own audio. Make them again with"
             % (" " + version if version else ""), "",
             "```sh", "python3 tools/lemonade/generate.py --force [--only music|voices|sfx] [name ...]", "```", "",
             "Every file is 44.1 kHz Ogg Vorbis (music stereo, the rest mono), trimmed of silence and "
             "peaking at about -3 dBFS. Loops were cut where their end matches their start and "
             "crossfaded there. Music and sounds were made in several takes (seeds counting up from "
             "the first); the take kept is the one whose length, loudness, ending and loop seam fit "
             "best (for sounds, also how many separate sounds it has and how quiet its background "
             "is) unless the table says it was picked by hand. The other takes were not kept.", ""]
    ckpt = record.get("checkpoints", {})

    def model_line(model):
        return "Model `%s`%s." % (model, " (`%s`)" % ckpt[model] if model in ckpt else "")

    lines += ["## Music", "", model_line(manifest["music"]["model"]) + " Instrumental (no lyrics), the "
              "server's default steps.", "",
              "| File | Prompt | Seed | Takes | Length | Settings |", "|---|---|---|---|---|---|"]
    for t in manifest["music"]["tracks"]:
        e = r.get(t["file"])
        if not e:
            continue
        set_ = "asked for %g s" % e["ask"]
        if e.get("loop"):
            lp = e["loop"]
            set_ += "; loop %.2f to %.2f s of the take, %.1f s crossfade" % (lp["start_s"], lp["end_s"], lp["crossfade_s"])
        if e.get("faded_end"):
            set_ += "; last 1.5 s faded"
        set_ += "; %.1f LUFS" % e["lufs"]
        lines.append("| `%s` | %s | %d | %d | %.1f s | %s |" % (
            t["file"], t["prompt"], e["seed"], e["takes"], e["seconds"], set_))
    v = manifest["voices"]
    lines += ["", "## Voices", "", model_line(v["model"]) + " One take each (Kokoro has no seed; the same "
              "text, voice and speed always give the same line).", ""]
    for name, voice in v["voices"].items():
        lines.append("- `%s`: %s. Kokoro voice `%s`, speed %s." % (
            name, voice["who"], voice["kokoro_voice"], voice.get("speed", 1.0)))
    lines += ["", "| File | Text | Voice | Length |", "|---|---|---|---|"]
    for name, voice in v["voices"].items():
        for line in voice["lines"]:
            e = r.get(line["file"])
            if not e:
                continue
            text = line["text"] + (" (read as \"%s\")" % line["say"] if "say" in line else "")
            lines.append("| `%s` | %s | `%s` | %.1f s |" % (line["file"], text, e["voice"], e["seconds"]))
    s = manifest["sfx"]
    lines += ["", "## Sound effects", "", model_line(s["model"]) + " The server's default steps and "
              "guidance. These replace synthesized sounds of the same names (see `sfx/README.md`).", "",
              "| File | Prompt | Seed | Takes | Length | Settings |", "|---|---|---|---|---|---|"]
    kept = []
    for snd in s["sounds"]:
        if "skip" in snd:
            kept.append(snd)
            continue
        e = r.get(snd["file"])
        if not e:
            continue
        set_ = "asked for %g s" % e["ask"]
        if e.get("loop"):
            lp = e["loop"]
            set_ += "; loop %.2f to %.2f s of the take, %.2f s crossfade" % (lp["start_s"], lp["end_s"], lp["crossfade_s"])
        if snd.get("events"):
            set_ += "; kept %d sound%s of the take" % (snd["events"], "s" if snd["events"] > 1 else "")
        if snd.get("fade_out"):
            set_ += "; last %g s faded out" % snd["fade_out"]
        if snd.get("wind_down"):
            set_ += "; slowed to a stop over %g s by the script (ThinkSound's takes kept running)" % snd["wind_down"]
        if e.get("picked"):
            set_ += "; take picked by hand: %s" % e["picked"]
        lines.append("| `%s` | %s | %d | %d | %.2f s | %s |" % (
            snd["file"], snd["prompt"], e["seed"], e["takes"], e["seconds"], set_))
    if kept:
        lines += ["", "Kept synthesized (ThinkSound's takes were worse):", ""]
        for snd in kept:
            lines.append("- `%s`: %s." % (snd["file"], snd["skip"]))
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("names", nargs="*", help="only these files (stems, e.g. doorbell night)")
    ap.add_argument("--only", choices=KINDS)
    ap.add_argument("--force", action="store_true", help="make files that exist again")
    ap.add_argument("--server", help="Lemonade's address (default: the manifest's)")
    ap.add_argument("--takes", type=int, help="takes per music track and sound (default: the manifest's, or 3)")
    ap.add_argument("--takes-dir", type=Path, default=CACHE, help="where raw takes are cached (default %(default)s)")
    ap.add_argument("--no-cache", action="store_true", help="ask Lemonade again even for cached takes")
    args = ap.parse_args()

    manifest = json.loads(MANIFEST.read_text())
    server = args.server or manifest["server"]
    have = models(server)
    record = json.loads(RECORD.read_text()) if RECORD.exists() else {"files": {}}
    record.setdefault("checkpoints", {})
    todo = [j for j in jobs(manifest)
            if (not args.only or j["kind"] == args.only)
            and (not args.names or stem(j["file"]) in args.names
                 or "%s/%s" % (j.get("who", ""), stem(j["file"])) in args.names)]
    problems = []
    for job in todo:
        out = ROOT / job["file"]
        if "skip" in job:
            print("%s: skipped (%s)" % (job["file"], job["skip"]))
            record["files"].pop(job["file"], None)
            continue
        if out.exists() and not args.force:
            print("%s: exists" % job["file"])
            continue
        if job["model"] not in have:
            sys.exit("Lemonade has no %s model" % job["model"])
        record["checkpoints"][job["model"]] = have[job["model"]].get("checkpoint", "")
        print("%s:" % job["file"], flush=True)
        base = seed_for(job)
        takes = []
        for k in range(args.takes or job["takes"]):
            path, body = request(job, base + k)
            cached = fetch(server, path, body, 1800, args.takes_dir / job["kind"] / stem(job["file"]),
                                not args.no_cache)
            try:
                y, gain, info = process(job, cached)
            except RuntimeError as e:
                print("    take %d (seed %d) unusable: %s" % (k + 1, base + k, e))
                continue
            sc, parts = score(job, info)
            info.update(seed=base + k, score=sc, parts=parts)
            takes.append((sc, k, y, gain, info))
            print("    take %d%s: score %.2f %s  %s" % (k + 1, "" if job["kind"] == "voices" else " seed %d" % (base + k), sc, parts,
                  {kk: info[kk] for kk in ("seconds", "lufs", "events", "end_db", "spread_db") if info.get(kk) is not None}),
                  flush=True)
        if not takes:
            problems.append("%s: no usable take" % job["file"])
            continue
        sc, k, y, gain, info = min(takes, key=lambda t: (t[0], t[1]))
        if "pick" in job:
            picked = [t for t in takes if t[4]["seed"] == job["pick"]]
            if not picked:
                sys.exit("%s: no take has the picked seed %s" % (job["file"], job["pick"]))
            sc, k, y, gain, info = picked[0]
        q = QUALITY["sfx_loop" if job["kind"] == "sfx" and job["loop"] else job["kind"]]
        encode(y, job["channels"], out, q, gain)
        measured, bad = verify(out, job["channels"], job["kind"])
        entry = {"kind": job["kind"], "model": job["model"], "seed": info["seed"],
                 "takes": len(takes), "ask": job.get("ask"), "quality": q,
                 "made": datetime.date.today().isoformat(), "all_takes": [t[4] for t in sorted(takes, key=lambda t: t[1])]}
        if job["kind"] == "voices":
            entry.update(text=job["text"], voice=job["voice"], speed=job["speed"], seed=None, ask=None)
            if "say" in job:
                entry["say"] = job["say"]
        else:
            entry["prompt"] = job["prompt"]
        if "pick" in job:
            entry["picked"] = job.get("why", "picked by hand")
        for kk in ("loop", "lufs", "faded_end"):
            if info.get(kk) is not None:
                entry[kk] = info[kk]
        entry.update(measured)
        record["files"][job["file"]] = entry
        print("    kept take %d: %s%s" % (k + 1, measured, ("  PROBLEM: " + "; ".join(bad)) if bad else ""), flush=True)
        problems += ["%s: %s" % (job["file"], b) for b in bad]
        RECORD.write_text(json.dumps(record, indent="\t") + "\n")

    RECORD.write_text(json.dumps(record, indent="\t") + "\n")
    REPORT.write_text(render(record, manifest, server_version(server)))
    if problems:
        print("\nProblems:\n  " + "\n  ".join(problems))
        sys.exit(1)


if __name__ == "__main__":
    main()
