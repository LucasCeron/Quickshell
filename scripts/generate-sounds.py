#!/usr/bin/env python3
"""Synthesises the interface sounds into common/assets/sounds/.

drop.wav   a water drop: a mid tone rising in pitch over a little low body,
           with a soft muffled transient (power menu).

Run again after tweaking the parameters below; the output is deterministic.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
OUT = Path(__file__).resolve().parent.parent / "common/assets/sounds"


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def noise(length, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(length)]


def write(name, samples, peak):
    top = max(abs(s) for s in samples) or 1
    # Short fades so the edges never click.
    fade = int(0.002 * RATE)
    data = bytearray()
    for i, s in enumerate(samples):
        edge = min(1, i / fade, (len(samples) - 1 - i) / fade)
        data += struct.pack("<h", int(32767 * peak * edge * s / top))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(bytes(data))


def drop():
    length = int(0.2 * RATE)
    tone, phase = [], 0.0
    for i in range(length):
        t = i / RATE
        # A water drop: the pitch rises as the bubble closes.
        freq = 165 + 255 * (1 - math.exp(-t / 0.026))
        phase += 2 * math.pi * freq / RATE
        attack = min(1, t / 0.003)
        tone.append(math.sin(phase) * attack * math.exp(-t / 0.055))

    # A little weight underneath so it still lands like a tap.
    body = [0.4 * math.sin(2 * math.pi * 95 * i / RATE) * math.exp(-(i / RATE) / 0.04) for i in range(length)]
    hit = lowpass(noise(length, 7), 700)
    hit = [h * math.exp(-(i / RATE) / 0.003) * 0.7 for i, h in enumerate(hit)]

    # Gentle saturation and a low cutoff keep it round rather than sharp.
    mixed = [math.tanh(1.1 * (a + b + c)) for a, b, c in zip(tone, body, hit)]
    write("drop.wav", lowpass(lowpass(mixed, 1800), 1800), 0.75)


if __name__ == "__main__":
    drop()
    print("wrote", ", ".join(p.name for p in sorted(OUT.glob("*.wav"))))
