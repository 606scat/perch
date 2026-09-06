"""Original Perch sound set. Deterministic synthesis; no samples or dependencies.

48 kHz / 24-bit stereo PCM. Rounded plucks, short attacks, softened harmonic
partials, very quiet diffuse reflections, and tapered tails. Re-run to rebuild.
"""
from pathlib import Path
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
# onset, frequency, amplitude, decay, harmonic brightness
CUES = {
    "complete": (.60, [(0, 180, .50, .020, .08), (.014, 739.99, .55, .06, .13), (.066, 1108.73, .42, .095, .07), (.118, 1479.98, .22, .13, .025)]),
    "copy": (.19, [(0, 1380, .45, .022, .07)]),
    "drop": (.38, [(0, 210, .65, .055, .26), (.012, 525, .2, .06, .08)]),
    "start": (.5, [(0, 440, .4, .075, .10), (.085, 660, .45, .11, .08)]),
    "pause": (.43, [(0, 660, .33, .06, .10), (.075, 440, .4, .085, .06)]),
    "finish": (1.65, [(0, 523.25, .38, .22, .1), (.15, 659.25, .33, .23, .08), (.31, 783.99, .3, .32, .06)]),
    "reminder": (1.15, [(0, 698.46, .4, .19, .08), (.18, 880, .33, .23, .07)]),
}

out = ROOT / "Resources" / "Sounds"
out.mkdir(parents=True, exist_ok=True)
for name, (duration, notes) in CUES.items():
    rng = random.Random(1729)
    mono = [0.0] * int(RATE * duration)
    for onset, frequency, gain, decay, brightness in notes:
        offset = int(onset * RATE)
        for i in range(offset, len(mono)):
            t = (i - offset) / RATE
            attack = 1 - math.exp(-t / .0028)
            envelope = attack * math.exp(-t / decay)
            # A tiny downward pitch settle adds a physical, rounded onset.
            phase = 2 * math.pi * (frequency * t + .8 * (1 - math.exp(-t * 90)))
            tone = math.sin(phase) + brightness * math.sin(phase * 2.01) + brightness * .25 * math.sin(phase * 3.98)
            air = (rng.random() * 2 - 1) * .012 * math.exp(-t / .008)
            mono[i] += gain * (tone * envelope + air)
    channels = []
    for channel in range(2):
        signal = mono[:]
        for delay, gain in [(0.019 + channel * .002, .10), (.037 - channel * .002, .055), (.061, .025)]:
            shift = int(delay * RATE)
            for i in range(shift, len(signal)):
                signal[i] += mono[i - shift] * gain
        for i in range(len(signal)):
            tail = min(1.0, (len(signal) - 1 - i) / (RATE * .025))
            signal[i] *= max(0.0, tail)
        channels.append(signal)
    peak = max(abs(x) for channel in channels for x in channel)
    gain = .56 / max(peak, .001)
    pcm = bytearray()
    for pair in zip(*channels):
        for value in pair:
            sample = round(max(-1, min(1, value * gain)) * 8388607)
            pcm += sample.to_bytes(3, "little", signed=True)
    with wave.open(str(out / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(2); wav.setsampwidth(3); wav.setframerate(RATE); wav.writeframes(pcm)
    print(f"{name}: {duration:.2f}s, peak -5.0 dBFS, 48kHz/24-bit stereo")
