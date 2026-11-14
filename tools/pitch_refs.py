"""Pitch lines of the app's own voice clips, for the dotted guide line on the
Say it pitch graph.

    python -m tools.pitch_refs           # only clips that are new or changed
    python -m tools.pitch_refs --all     # every clip again

Needs numpy and ffmpeg (both in tools/environment.yml).

Each clip is decoded to 16 kHz mono and tracked with the same YIN method and
clean-up as the app (app/lib/speech/pitch.dart and tone_shape.dart), so the
dotted line is made the same way as the learner's own line.

Output: app/assets/audio/pitch_refs.json, {"clips": {"<id>_f": {"bytes": N,
"line": "..."}}}. The line has one character per 20 ms, from the first voiced
moment to the last: "." where there is no voice, otherwise half-semitones
from the clip's middle pitch, as chr(0x30 + 18 + round(semitones * 2)),
clamped to +-9 semitones.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "app" / "assets" / "audio"
OUT = AUDIO / "pitch_refs.json"

RATE = 16000
MIN_HZ, MAX_HZ, THRESHOLD = 70.0, 450.0, 0.35
WINDOW, HOP = 400, 160  # 25 ms, 10 ms
STEP = 2  # frames per character: 20 ms


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "quiet", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def track(x: np.ndarray) -> list[float | None]:
    """YIN pitch every 10 ms, as in pitch.dart's trackPitch."""
    tau_min = int(np.floor(RATE / MAX_HZ))
    tau_max = int(np.ceil(RATE / MIN_HZ))
    if len(x) < WINDOW + tau_max:
        return []
    frames = (len(x) - WINDOW - tau_max) // HOP + 1
    span = WINDOW + tau_max
    idx = np.arange(frames)[:, None] * HOP + np.arange(span)[None, :]
    seg = x[idx]  # frames x span
    win = seg[:, :WINDOW]
    rms = np.sqrt((win ** 2).mean(axis=1))
    loudest = rms.max() if frames else 0.0

    # d(tau) = E(0) + E(tau) - 2 r(tau), with r from an FFT correlation.
    n = 1 << int(np.ceil(np.log2(span + WINDOW)))
    a = np.fft.rfft(win, n)
    b = np.fft.rfft(seg, n)
    r = np.fft.irfft(np.conj(a) * b, n)[:, : tau_max + 1]
    sq = np.concatenate([np.zeros((frames, 1)), np.cumsum(seg ** 2, axis=1)], axis=1)
    taus = np.arange(tau_max + 1)
    e_tau = sq[:, taus + WINDOW] - sq[:, taus]
    d = np.maximum(sq[:, [WINDOW]] + e_tau - 2 * r, 0.0)

    out: list[float | None] = [None] * frames
    for i in range(frames):
        if rms[i] < loudest * 0.03 or rms[i] < 0.002:
            continue
        di = d[i].copy()
        running = np.cumsum(di[1:])
        cm = np.ones_like(di)
        with np.errstate(divide="ignore", invalid="ignore"):
            cm[1:] = np.where(running == 0, 1.0, di[1:] * taus[1:] / running)
        below = np.nonzero(cm[tau_min:tau_max] < THRESHOLD)[0]
        if len(below) == 0:
            continue
        tau = tau_min + int(below[0])
        while tau + 1 < tau_max and cm[tau + 1] < cm[tau]:
            tau += 1
        p, q, s = cm[tau - 1], cm[tau], cm[tau + 1]
        den = p - 2 * q + s
        shift = 0.0 if den == 0 else 0.5 * (p - s) / den
        out[i] = RATE / (tau + max(-1.0, min(1.0, shift)))
    return clean(out)


def clean(raw: list[float | None]) -> list[float | None]:
    """Octave slips, lone blips and a median of five, as in pitch.dart's _clean."""
    n = len(raw)
    out = list(raw)
    for i, f in enumerate(raw):
        if f is None:
            continue
        near = sorted(raw[j] for j in range(max(0, i - 3), min(n - 1, i + 3) + 1) if j != i and raw[j] is not None)
        if len(near) < 2:
            out[i] = None
            continue
        ratio = f / near[len(near) // 2]
        if 1.7 < ratio < 2.3:
            out[i] = f / 2
        elif 0.43 < ratio < 0.59:
            out[i] = f * 2
        elif ratio > 1.7 or ratio < 0.59:
            out[i] = None
    # Octave slips longer than the window above: keep each frame within an
    # octave of the voiced frame before it (up to 50 ms back).
    prev, prev_at = None, -100
    for i in range(n):
        f = out[i]
        if f is None:
            continue
        if prev is not None and i - prev_at <= 5:
            ratio = f / prev
            if 1.7 < ratio < 2.3:
                f = f / 2
            elif 0.43 < ratio < 0.59:
                f = f * 2
            out[i] = f
        prev, prev_at = f, i
    smooth: list[float | None] = [None] * n
    for i in range(n):
        if out[i] is None:
            continue
        w = sorted(out[j] for j in range(max(0, i - 2), min(n - 1, i + 2) + 1) if out[j] is not None)
        smooth[i] = w[len(w) // 2]
    return smooth


def voiced_runs(hz: list[float | None]) -> list[tuple[int, int]]:
    """As tone_shape.dart's voicedRuns: breaks up to 40 ms allowed, runs under 50 ms dropped."""
    runs, start, last = [], None, -100
    for i, f in enumerate(hz):
        if f is None:
            continue
        if start is not None and i - last > 4:
            runs.append((start, last + 1))
            start = None
        if start is None:
            start = i
        last = i
    if start is not None:
        runs.append((start, last + 1))
    return [r for r in runs if r[1] - r[0] >= 5]


def line_of(path: Path) -> str:
    hz = track(decode(path))
    runs = voiced_runs(hz)
    if not runs:
        return ""
    voiced = [f for f in hz if f is not None]
    median = sorted(voiced)[len(voiced) // 2]
    keep = [False] * len(hz)
    for a, b in runs:
        for i in range(a, b):
            keep[i] = hz[i] is not None
    chars = []
    for i in range(runs[0][0], runs[-1][1], STEP):
        f = hz[i] if keep[i] else None
        if f is None:
            chars.append(".")
        else:
            st = 12 * np.log2(f / median)
            v = int(round(max(-9.0, min(9.0, st)) * 2)) + 18
            chars.append(chr(0x30 + v))
    return "".join(chars)


def _job(name: str) -> tuple[str, str]:
    return name, line_of(AUDIO / name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--all", action="store_true", help="redo every clip")
    args = ap.parse_args()
    manifest = json.loads((AUDIO / "manifest.json").read_text(encoding="utf-8"))
    clips = manifest.get("clips", {})
    old = {} if args.all or not OUT.exists() else json.loads(OUT.read_text(encoding="utf-8")).get("clips", {})
    out, todo = {}, []
    for key, clip in clips.items():
        path = AUDIO / clip["file"]
        if not path.exists():
            continue
        size = path.stat().st_size
        if key in old and old[key].get("bytes") == size:
            out[key] = old[key]
        else:
            todo.append((key, clip["file"], size))
    print(f"{len(out)} clips already done, {len(todo)} to do")
    with ProcessPoolExecutor() as pool:
        for (key, _, size), (_, line) in zip(todo, pool.map(_job, [f for _, f, _ in todo], chunksize=32)):
            out[key] = {"bytes": size, "line": line}
    doc = {
        "about": "Made by tools/pitch_refs.py: the pitch line of each voice clip, for the Say it graph.",
        "clips": dict(sorted(out.items())),
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
