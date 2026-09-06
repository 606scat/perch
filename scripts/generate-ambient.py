#!/usr/bin/env python3
"""Original procedural ambient loops. No recordings or third-party samples.
Deterministic, 16-bit mono PCM at 44.1 kHz. Run from any directory.
"""
import array
import math
from pathlib import Path
import random
import wave

RATE = 44100
SECONDS = 16
FADE = RATE
out = Path(__file__).resolve().parent.parent / 'Resources' / 'Ambient'
out.mkdir(parents=True, exist_ok=True)

for name, seed in [('rain', 17), ('ocean', 23), ('tones', 31), ('brown', 43)]:
    rng = random.Random(seed)
    samples = array.array('d')
    slow = medium = 0.0
    for i in range(RATE * SECONDS + FADE):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        slow = slow * 0.998 + noise * 0.002
        medium = medium * 0.88 + noise * 0.12
        if name == 'rain':
            value = (noise * 0.12 + medium * 0.8 + slow) * (0.86 + 0.14 * math.sin(2 * math.pi * t / 8))
        elif name == 'ocean':
            value = (medium * 0.6 + slow * 2.4) * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 8)) ** 1.4)
        elif name == 'brown':
            value = slow
        else:
            value = sum(math.sin(2 * math.pi * f * t + j * 0.7) * (0.75 + 0.25 * math.sin(2 * math.pi * t / (8 if j % 2 else 16) + j)) / (j + 2) for j, f in enumerate([110, 165, 220, 277.1875, 330])) * 0.17
        samples.append(value)
    # Crossfade the head into the tail, then start the loop after its head.
    # This keeps both the loop boundary and the transition continuous.
    for i in range(FADE):
        mix = 0.5 - 0.5 * math.cos(math.pi * i / (FADE - 1))
        samples[RATE * SECONDS + i] = samples[RATE * SECONDS + i] * (1 - mix) + samples[i] * mix
    samples = samples[FADE:]
    peak = max(abs(v) for v in samples)
    gain = 0.45 / peak
    pcm = array.array('h', (round(v * gain * 32767) for v in samples))
    if __import__('sys').byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(out / f'{name}.wav'), 'wb') as wav:
        wav.setparams((1, 2, RATE, len(pcm), 'NONE', 'not compressed'))
        wav.writeframes(pcm.tobytes())
    rms = math.sqrt(sum((v * gain) ** 2 for v in samples) / len(samples))
    print(f'{name}: {len(samples) / RATE:.0f}s, peak -6.9 dBFS, RMS {20 * math.log10(rms):.1f} dBFS, seam {abs(samples[-1]-samples[0])*gain:.5f}')
