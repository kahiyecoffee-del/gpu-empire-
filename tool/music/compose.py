"""Synthesizes the background music loop for GPU Empire.

A gentle, cheerful 16-bar loop in C major (music box melody, kalimba
arpeggios, soft pad, bass and light percussion). Everything is generated
here, so the track has no licensing strings attached.

    python3 tool/music/compose.py out.wav
"""
import sys
import wave

import numpy as np

SR = 44100
BPM = 92
BEAT = 60 / BPM
EIGHTH = BEAT / 2
BAR = BEAT * 4

NOTE_INDEX = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6,
              'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}


def freq(name):
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


CHORDS = {
    'C': ['C3', 'E3', 'G3'], 'Am': ['A2', 'C3', 'E3'], 'F': ['F2', 'A2', 'C3'],
    'G': ['G2', 'B2', 'D3'], 'Em': ['E2', 'G2', 'B2'],
}
PROGRESSION = ['C', 'Am', 'F', 'G', 'C', 'Am', 'F', 'G',
               'F', 'G', 'Em', 'Am', 'F', 'G', 'C', 'C']
_ = None
MELODY = [
    ['E5', _, 'G5', _, 'A5', 'G5', 'E5', _],
    ['C5', _, 'E5', _, 'D5', 'C5', 'A4', _],
    ['A4', _, 'C5', _, 'D5', _, 'C5', 'A4'],
    ['B4', _, 'D5', _, 'G5', _, _, _],
    ['E5', _, 'G5', _, 'C6', _, 'B5', 'G5'],
    ['A5', _, 'G5', 'E5', _, 'D5', 'E5', _],
    ['F5', _, 'E5', _, 'D5', _, 'C5', _],
    ['D5', _, _, _, 'G4', _, _, _],
    ['A5', _, 'G5', _, 'F5', _, 'E5', _],
    ['D5', _, 'E5', _, 'G5', _, _, _],
    ['E5', _, 'G5', _, 'B5', _, 'A5', 'G5'],
    ['A5', _, _, _, 'E5', _, _, _],
    ['F5', _, 'A5', _, 'C6', _, 'A5', _],
    ['G5', _, 'B5', _, 'D6', _, 'B5', _],
    ['C6', _, 'G5', _, 'E5', _, 'D5', _],
    ['C5', _, _, _, _, _, _, _],
]

LOOP_SECONDS = BAR * len(PROGRESSION)
TAIL_SECONDS = 3.0
N = int((LOOP_SECONDS + TAIL_SECONDS) * SR)
left = np.zeros(N)
right = np.zeros(N)


def add(signal, start, pan=0.0, gain=1.0):
    """Mixes [signal] in at [start] seconds; pan -1 (left) .. 1 (right)."""
    i = int(start * SR)
    end = min(N, i + len(signal))
    s = signal[: end - i] * gain
    left[i:end] += s * np.sqrt((1 - pan) / 2)
    right[i:end] += s * np.sqrt((1 + pan) / 2)


def env_t(duration):
    return np.arange(int(duration * SR)) / SR


def music_box(f, duration=1.6):
    t = env_t(duration)
    tone = (np.sin(2 * np.pi * f * t)
            + 0.35 * np.sin(2 * np.pi * 2 * f * t)
            + 0.12 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t * 6))
    attack = np.minimum(1, t / 0.004)
    return tone * attack * np.exp(-t * 3.2)


def kalimba(f, duration=0.9):
    t = env_t(duration)
    tone = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 4.1 * f * t) * np.exp(-t * 18)
    return tone * np.minimum(1, t / 0.003) * np.exp(-t * 5.5)


def pad(freqs, duration):
    t = env_t(duration)
    tone = np.zeros_like(t)
    for f in freqs:
        for detune in (0.997, 1.0, 1.003):
            tone += np.sin(2 * np.pi * f * 2 * detune * t)
    attack = np.minimum(1, t / 0.6)
    release = np.minimum(1, (duration - t) / 0.6)
    return tone * attack * np.clip(release, 0, 1) / (3 * len(freqs))


def bass(f, duration=0.7):
    t = env_t(duration)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    return tone * np.minimum(1, t / 0.01) * np.exp(-t * 4)


def kick():
    t = env_t(0.35)
    pitch = 50 + 90 * np.exp(-t * 30)
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    return np.sin(phase) * np.exp(-t * 9)


rng = np.random.default_rng(7)


def shaker(duration=0.08):
    t = env_t(duration)
    noise = rng.standard_normal(len(t))
    noise = np.diff(noise, prepend=0)  # crude high-pass
    return noise * np.exp(-t * 60)


def snap():
    t = env_t(0.18)
    noise = rng.standard_normal(len(t))
    tone = np.sin(2 * np.pi * 1800 * t)
    return (0.6 * noise + 0.4 * tone) * np.exp(-t * 35)


for bar, chord in enumerate(PROGRESSION):
    t0 = bar * BAR
    notes = CHORDS[chord]
    add(pad([freq(n) for n in notes], BAR + 0.5), t0, gain=0.10)
    root = freq(notes[0]) / 2 if freq(notes[0]) > 110 else freq(notes[0])
    # Root on beats 1 and 3, the fifth as a pickup into the next bar.
    for beat, ratio in ((0, 1), (2, 1), (3.5, 1.5)):
        add(bass(root * ratio), t0 + beat * BEAT, gain=0.22)
    # Kalimba arpeggio on eighths, an octave up.
    pattern = [0, 1, 2, 1, 0, 2, 1, 2]
    for k, idx in enumerate(pattern):
        add(kalimba(freq(notes[idx]) * 2), t0 + k * EIGHTH, pan=-0.35, gain=0.09)
    # Music box melody.
    for k, note in enumerate(MELODY[bar]):
        if note:
            add(music_box(freq(note)), t0 + k * EIGHTH, pan=0.25, gain=0.20)
    # Percussion.
    for beat in range(4):
        if beat in (0, 2):
            add(kick(), t0 + beat * BEAT, gain=0.16)
        if beat in (1, 3):
            add(snap(), t0 + beat * BEAT, pan=0.1, gain=0.06)
    for k in range(8):
        add(shaker(), t0 + k * EIGHTH + (0.012 if k % 2 else 0), pan=0.45,
            gain=0.035 if k % 2 else 0.02)


def reverb(x):
    out = x.copy()
    for delay, g in ((0.031, 0.35), (0.047, 0.3), (0.071, 0.25), (0.113, 0.2), (0.173, 0.15)):
        d = int(delay * SR)
        y = np.zeros_like(x)
        y[d:] = x[:-d] * g
        out += y
    return out


left = reverb(left)
right = reverb(right)

# Fold the tail onto the start so the loop has no seam.
loop_n = int(LOOP_SECONDS * SR)
for ch in (left, right):
    ch[: N - loop_n] += ch[loop_n:]
left, right = left[:loop_n], right[:loop_n]

stereo = np.stack([left, right], axis=1)
peak = np.max(np.abs(stereo))
stereo = stereo / peak * 0.85
rms = np.sqrt(np.mean(stereo ** 2))
print(f'length {LOOP_SECONDS:.1f}s, peak {np.max(np.abs(stereo)):.2f}, rms {rms:.3f}')

pcm = (stereo * 32767).astype('<i2')
out = sys.argv[1] if len(sys.argv) > 1 else 'music_loop.wav'
with wave.open(out, 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
