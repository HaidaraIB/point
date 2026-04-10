#!/usr/bin/env python3
"""Generate short synthetic chat UI WAVs (royalty-free). Run from repo root:
   python tools/generate_chat_ui_sounds.py
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
SOUNDS_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def smoothstep(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def tone_samples(
    freq_hz: float,
    duration_s: float,
    peak: float = 0.22,
    attack_s: float = 0.008,
    release_s: float = 0.04,
) -> list[int]:
    n = max(1, int(SAMPLE_RATE * duration_s))
    out: list[int] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = 1.0
        if t < attack_s:
            env = smoothstep(t / attack_s)
        elif t > duration_s - release_s:
            env = smoothstep((duration_s - t) / release_s)
        sample = peak * env * math.sin(2.0 * math.pi * freq_hz * t)
        s = int(round(sample * 32767.0))
        out.append(max(-32768, min(32767, s)))
    return out


def silence_samples(duration_s: float) -> list[int]:
    return [0] * int(SAMPLE_RATE * duration_s)


def write_mono_wav(path: Path, samples: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))


def main() -> None:
    # Incoming: soft two-note "message arrived" (not harsh, not same as generic notify)
    incoming = (
        tone_samples(784.0, 0.085, peak=0.2)  # G5
        + silence_samples(0.018)
        + tone_samples(1046.5, 0.11, peak=0.17)  # C6
    )

    # Outgoing: quick single "sent" blip — lower, shorter than incoming
    outgoing = tone_samples(523.25, 0.055, peak=0.28, release_s=0.028)  # C5

    write_mono_wav(SOUNDS_DIR / "chat_message_in.wav", incoming)
    write_mono_wav(SOUNDS_DIR / "chat_message_out.wav", outgoing)
    print(f"Wrote {SOUNDS_DIR / 'chat_message_in.wav'}")
    print(f"Wrote {SOUNDS_DIR / 'chat_message_out.wav'}")


if __name__ == "__main__":
    main()
