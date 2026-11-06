#!/usr/bin/env python3
"""Synthétise les sons de démarrage (WAV 16 bits mono 22050 Hz), 100 % originaux."""
import os, wave
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sound", "computerweb")
os.makedirs(OUT, exist_ok=True)
SR = 22050


def note(f, dur, vol=1.0, kind="sine", attack=0.01, decay=None):
    t = np.arange(int(SR * dur)) / SR
    if kind == "sine":
        w = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    elif kind == "soft":
        w = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(6 * np.pi * f * t) / 3
    elif kind == "square":
        w = np.sign(np.sin(2 * np.pi * f * t)) * 0.35
    else:
        w = np.sin(2 * np.pi * f * t)
    env = np.minimum(t / attack, 1.0) * np.exp(-t * (decay if decay else 3.0 / dur))
    return w * env * vol


def mix(parts, total):
    out = np.zeros(int(SR * total))
    for start, sig in parts:
        i = int(SR * start)
        out[i:i + len(sig)] += sig[: max(0, len(out) - i)]
    return out


def save(name, sig):
    sig = sig / max(1e-9, np.max(np.abs(sig))) * 0.7
    n = int(SR * 0.04)
    sig[-n:] *= np.linspace(1, 0, n)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((sig * 32767).astype(np.int16).tobytes())


# Nova : accord majeur ascendant, doux
save("boot_nova.wav", mix([(0.0, note(392.0, 1.6, .7, "soft")), (0.18, note(523.25, 1.5, .7, "soft")),
                           (0.36, note(659.25, 1.4, .7, "soft")), (0.54, note(783.99, 1.5, .8, "soft"))], 2.2))
# Terra : deux notes rondes et chaleureuses
save("boot_terra.wav", mix([(0.0, note(293.66, 1.4, .8, "sine")), (0.30, note(440.0, 1.6, .8, "sine")),
                            (0.30, note(587.33, 1.6, .4, "sine"))], 2.0))
# Cipher : bips carrés rapides + grave
save("boot_cipher.wav", mix([(0.00, note(880, 0.08, .5, "square", decay=6)), (0.12, note(660, 0.08, .5, "square", decay=6)),
                             (0.24, note(990, 0.08, .5, "square", decay=6)), (0.40, note(110, 0.9, .9, "sine", decay=3)),
                             (0.40, note(220, 0.9, .4, "square", decay=4))], 1.5))
# Sandbox : petit jingle ludique
save("boot_sandbox.wav", mix([(0.00, note(523.25, 0.25, .7, "soft", decay=6)), (0.15, note(659.25, 0.25, .7, "soft", decay=6)),
                              (0.30, note(523.25, 0.25, .7, "soft", decay=6)), (0.45, note(783.99, 0.9, .8, "soft", decay=3))], 1.5))
# Retro : petite fanfare ascendante façon années 90 (originale)
save("boot_retro.wav", mix([(0.00, note(329.63, 0.5, .7, "soft", decay=4)), (0.00, note(493.88, 0.5, .5, "soft", decay=4)),
                            (0.35, note(392.00, 0.5, .7, "soft", decay=4)), (0.35, note(587.33, 0.5, .5, "soft", decay=4)),
                            (0.70, note(523.25, 0.5, .7, "soft", decay=4)), (0.70, note(783.99, 0.5, .5, "soft", decay=4)),
                            (1.05, note(659.25, 1.6, .8, "soft", decay=2)), (1.05, note(987.77, 1.6, .5, "soft", decay=2)),
                            (1.05, note(523.25, 1.6, .5, "soft", decay=2))], 2.8))
print("sons ok")
