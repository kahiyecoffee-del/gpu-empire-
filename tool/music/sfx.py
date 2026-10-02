"""Synthesizes GPU Empire's sound effects (license free, like the music).

    python3 tool/music/sfx.py assets/audio

Writes one short .mp3 per effect (ffmpeg must be installed).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100


def t(duration):
    return np.arange(int(SR * duration)) / SR


def tone(f, duration, decay=8.0, harmonics=((1, 1.0),), attack=0.004):
    x = t(duration)
    sig = sum(g * np.sin(2 * np.pi * f * h * x) for h, g in harmonics)
    env = np.exp(-decay * x) * np.clip(x / attack, 0, 1)
    return sig * env


def at(total, parts):
    """Mixes (start_seconds, signal) parts into one buffer."""
    out = np.zeros(int(SR * total))
    for start, sig in parts:
        i = int(SR * start)
        n = min(len(sig), len(out) - i)
        out[i:i + n] += sig[:n]
    return out


BELL = ((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.08))
SOFT = ((1, 1.0), (2, 0.2))


def tap():
    # A soft, short wooden "tock".
    x = t(0.09)
    f = 900 * np.exp(-30 * x) + 300
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-45 * x) * 0.6


def buy():
    # Two-note coin "ching".
    return at(0.35, [(0, tone(1568, 0.3, 14, BELL)),
                     (0.06, tone(2093, 0.3, 12, BELL))]) * 0.45


def milestone():
    # Rising major arpeggio with a sparkle on top.
    notes = [523, 659, 784, 1047]
    parts = [(i * 0.07, tone(f, 0.5, 6, BELL)) for i, f in enumerate(notes)]
    parts.append((0.3, tone(2093, 0.4, 9, BELL) * 0.5))
    return at(0.8, parts) * 0.4


def reward():
    # Glittery cascade (quests, wheel prizes, ad rewards).
    notes = [1319, 1568, 1976, 2349, 2637]
    parts = [(i * 0.045, tone(f, 0.35, 10, BELL) * (0.9 - i * 0.1))
             for i, f in enumerate(notes)]
    return at(0.6, parts) * 0.4


def fanfare():
    # IPO and moving: a short brass-like fanfare.
    brass = ((1, 1.0), (2, 0.6), (3, 0.4), (4, 0.25), (5, 0.12))
    seq = [(0.0, 392, 0.14), (0.15, 523, 0.14), (0.3, 659, 0.14),
           (0.45, 784, 0.6)]
    parts = [(s, tone(f, d + 0.25, 3.5, brass, attack=0.02))
             for s, f, d in seq]
    parts += [(0.45, tone(523, 0.85, 3, brass, attack=0.02) * 0.5),
              (0.45, tone(659, 0.85, 3, brass, attack=0.02) * 0.4)]
    return at(1.3, parts) * 0.25


def spin():
    # Wheel ticks that slow down.
    parts, s, gap = [], 0.0, 0.035
    while s < 1.6:
        parts.append((s, tone(2400, 0.03, 120, SOFT) * 0.5))
        s += gap
        gap *= 1.12
    return at(1.8, parts) * 0.5


def whoosh():
    # Opening sheets / boosts: filtered noise sweep.
    x = t(0.35)
    rng = np.random.default_rng(7)
    noise = rng.standard_normal(len(x))
    kernel = np.ones(24) / 24
    smooth = np.convolve(noise, kernel, mode='same')
    env = np.sin(np.pi * x / x[-1]) ** 2
    return smooth * env * 1.2


EFFECTS = {
    'sfx_tap': tap, 'sfx_buy': buy, 'sfx_milestone': milestone,
    'sfx_reward': reward, 'sfx_fanfare': fanfare, 'sfx_spin': spin,
    'sfx_whoosh': whoosh,
}


def write_mp3(path, signal):
    peak = np.max(np.abs(signal))
    if peak > 0.95:
        signal = signal * 0.95 / peak
    pcm = (signal * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        tmp = f.name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp,
                    '-codec:a', 'libmp3lame', '-b:a', '96k', path], check=True)
    os.remove(tmp)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/audio'
    for name, fn in EFFECTS.items():
        write_mp3(os.path.join(out, name + '.mp3'), fn())
        print('wrote', name)
