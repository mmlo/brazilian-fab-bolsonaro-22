#!/usr/bin/env python3
"""Deterministic chiptune-style SFX synthesizer for Starveil Barrage.

Every cue is synthesized from scratch (square / triangle / noise voices with
pitch and volume envelopes), so the sound set is fully original and easy to
re-tune: edit a recipe below and re-run

    python3 tools/sfx/generate_sfx.py

Output: assets/audio/sfx/<name>.ogg (Vorbis, mono, 44.1 kHz).
"""
from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "sfx"
rng = np.random.default_rng(20260927)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def sweep_phase(f0: float, f1: float, dur: float, curve: float = 1.0) -> np.ndarray:
    t = t_axis(dur)
    k = (t / dur) ** curve
    freq = f0 + (f1 - f0) * k
    return np.cumsum(freq) / SR


def square(phase: np.ndarray, duty: float = 0.5) -> np.ndarray:
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def triangle(phase: np.ndarray) -> np.ndarray:
    return 4.0 * np.abs((phase % 1.0) - 0.5) - 1.0


def noise(dur: float, hold: int = 1) -> np.ndarray:
    n = int(dur * SR)
    raw = rng.uniform(-1, 1, n // hold + 2)
    return np.repeat(raw, hold)[:n]


def env(dur: float, attack: float = 0.004, decay_pow: float = 1.6) -> np.ndarray:
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = (1.0 - t / dur) ** decay_pow
    return a * d


def lowpass(x: np.ndarray, alpha: float) -> np.ndarray:
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def pad(x: np.ndarray, dur: float) -> np.ndarray:
    n = int(dur * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(x: np.ndarray, sec: float) -> np.ndarray:
    return np.concatenate([np.zeros(int(sec * SR)), x])


def note(freq: float, dur: float, duty: float = 0.5, vol: float = 1.0, wave_fn: str = "sq") -> np.ndarray:
    ph = sweep_phase(freq, freq, dur)
    osc = square(ph, duty) if wave_fn == "sq" else triangle(ph)
    return osc * env(dur, 0.002, 1.2) * vol


# ---------------------------------------------------------------- recipes

def shoot() -> np.ndarray:
    d = 0.07
    s = square(sweep_phase(1650, 700, d, 0.6), 0.25) * env(d, 0.001, 2.2) * 0.35
    return lowpass(s, 0.35)


def enemy_hit() -> np.ndarray:
    d = 0.045
    s = mix(noise(d, 3) * env(d, 0.001, 3) * 0.5, square(sweep_phase(900, 380, d), 0.5) * env(d, 0.001, 3) * 0.25)
    return lowpass(s, 0.5)


def explode_small() -> np.ndarray:
    d = 0.34
    n = noise(d, 6) * env(d, 0.002, 2.0)
    body = square(sweep_phase(320, 60, d, 0.5), 0.5) * env(d, 0.002, 2.6) * 0.45
    return lowpass(mix(n * 0.8, body), 0.28)


def explode_big() -> np.ndarray:
    d = 1.25
    n1 = lowpass(noise(d, 10) * env(d, 0.003, 1.5), 0.18) * 1.1
    boom = triangle(sweep_phase(120, 28, d, 0.4)) * env(d, 0.002, 1.4) * 0.9
    crack = noise(0.12, 2) * env(0.12, 0.001, 2) * 0.6
    tail = delay(lowpass(noise(0.8, 14) * env(0.8, 0.05, 2.0), 0.12) * 0.5, 0.35)
    return mix(n1, boom, crack, tail)


def graze() -> np.ndarray:
    d = 0.06
    s = square(sweep_phase(2600, 3400, d), 0.125) * env(d, 0.001, 2.0) * 0.22
    sh = noise(d, 1) * env(d, 0.001, 3) * 0.12
    return mix(s, sh)


def pickup() -> np.ndarray:
    a = note(1318.5, 0.05, 0.25, 0.3)
    b = note(1975.5, 0.09, 0.25, 0.3)
    return mix(a, delay(b, 0.04))


def energy_full() -> np.ndarray:
    freqs = [659.3, 830.6, 987.8, 1318.5, 1661.2]
    out = np.zeros(1)
    for i, f in enumerate(freqs):
        out = mix(out, delay(note(f, 0.16, 0.25, 0.28), i * 0.055))
    return out


def bomb() -> np.ndarray:
    rise = square(sweep_phase(180, 1400, 0.45, 1.4), 0.5) * np.linspace(0.05, 0.4, int(0.45 * SR))
    rise = lowpass(rise, 0.3)
    blast = explode_big() * 0.95
    shimmer = np.zeros(1)
    for i, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0, 2637.0, 3136.0]):
        shimmer = mix(shimmer, delay(note(f, 0.22, 0.125, 0.14), i * 0.06))
    return mix(rise, delay(blast, 0.42), delay(shimmer, 0.48))


def player_hit() -> np.ndarray:
    d = 0.7
    zap = square(sweep_phase(1400, 90, d, 0.5), 0.5) * env(d, 0.001, 1.8) * 0.5
    n = lowpass(noise(d, 5) * env(d, 0.002, 1.4), 0.25) * 0.8
    return mix(zap, n)


def boss_break() -> np.ndarray:
    d = 1.6
    crunch = mix(explode_big() * 0.9, delay(explode_small() * 0.7, 0.18), delay(explode_small() * 0.6, 0.36))
    fall = square(sweep_phase(700, 70, d, 0.7), 0.5) * env(d, 0.01, 1.3) * 0.3
    return mix(crunch, lowpass(fall, 0.25))


def warning() -> np.ndarray:
    out = np.zeros(1)
    for i in range(3):
        hi = note(880, 0.16, 0.5, 0.32)
        lo = note(660, 0.16, 0.5, 0.32)
        out = mix(out, delay(hi, i * 0.4), delay(lo, i * 0.4 + 0.18))
    return lowpass(out, 0.45)


def enemy_fire() -> np.ndarray:
    d = 0.08
    return lowpass(square(sweep_phase(520, 900, d), 0.5) * env(d, 0.001, 2.4) * 0.22, 0.3)


def combo_up() -> np.ndarray:
    freqs = [1046.5, 1318.5, 1568.0]
    out = np.zeros(1)
    for i, f in enumerate(freqs):
        out = mix(out, delay(note(f, 0.1, 0.25, 0.26), i * 0.045))
    return out


def ui_move() -> np.ndarray:
    return note(1760, 0.035, 0.25, 0.22)


def ui_confirm() -> np.ndarray:
    return mix(note(1046.5, 0.06, 0.5, 0.24), delay(note(1568.0, 0.12, 0.5, 0.24), 0.055))


def ui_back() -> np.ndarray:
    return mix(note(987.8, 0.06, 0.5, 0.22), delay(note(659.3, 0.1, 0.5, 0.22), 0.05))


def charge() -> np.ndarray:
    d = 0.9
    s = square(sweep_phase(200, 1200, d, 1.8), 0.25) * np.linspace(0.02, 0.3, int(d * SR))
    return lowpass(s, 0.3)


def victory() -> np.ndarray:
    seq = [(523.3, 0.12), (659.3, 0.12), (784.0, 0.12), (1046.5, 0.5)]
    out = np.zeros(1)
    at = 0.0
    for f, d in seq:
        out = mix(out, delay(mix(note(f, d, 0.5, 0.26), note(f / 2, d, 0.5, 0.0, "tri") * 0 + note(f / 2, d, 0.5, 0.3, "tri")), at))
        at += d * 0.95
    return out


def defeat() -> np.ndarray:
    seq = [(392.0, 0.18), (349.2, 0.18), (311.1, 0.18), (261.6, 0.6)]
    out = np.zeros(1)
    at = 0.0
    for f, d in seq:
        out = mix(out, delay(note(f, d, 0.5, 0.26, "tri"), at))
        at += d
    return out


RECIPES = {
    "shoot": shoot,
    "enemy_hit": enemy_hit,
    "explode_small": explode_small,
    "explode_big": explode_big,
    "graze": graze,
    "pickup": pickup,
    "energy_full": energy_full,
    "bomb": bomb,
    "player_hit": player_hit,
    "boss_break": boss_break,
    "warning": warning,
    "enemy_fire": enemy_fire,
    "combo_up": combo_up,
    "ui_move": ui_move,
    "ui_confirm": ui_confirm,
    "ui_back": ui_back,
    "charge": charge,
    "victory": victory,
    "defeat": defeat,
}


def write_ogg(name: str, samples: np.ndarray) -> None:
    peak = float(np.max(np.abs(samples))) or 1.0
    samples = samples / peak * 0.89
    fade = min(len(samples), int(0.004 * SR))
    samples[-fade:] *= np.linspace(1, 0, fade)
    pcm = (samples * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / f"{name}.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(OUT / f"{name}.ogg")], check=True)


if __name__ == "__main__":
    for key, fn in RECIPES.items():
        write_ogg(key, fn())
        print("wrote", key)
