#!/usr/bin/env python3
"""Synthesise every sound of the game into assets/sfx/*.ogg (numpy + scipy,
encoded with ffmpeg/libvorbis). Deterministic: same seed, same sounds.

Usage: python3 tools/gen_audio.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sfx')
rng = np.random.default_rng(1234)


# ---------------------------------------------------------------- building blocks
def t_(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.standard_normal(int(SR * dur))


def brown(dur):
    w = noise(dur)
    b = np.cumsum(w)
    b = signal.lfilter([1], [1, -0.995], w)
    return b / (np.abs(b).max() + 1e-9)


def lp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), 'low')
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), 'high')
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band')
    return signal.lfilter(b, a, x)


def env(n, a=0.005, d=0.1, s=0.0, r=0.0, sl=0.0):
    """attack, decay to sustain level s over d, hold sl, release r (seconds)."""
    A = int(a * SR)
    D = int(d * SR)
    S = int(sl * SR)
    Rr = int(r * SR)
    e = np.concatenate([np.linspace(0, 1, max(A, 1)), np.linspace(1, s, max(D, 1)), np.full(S, s), np.linspace(s, 0, max(Rr, 1))])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def expdecay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def sine(f, dur, phase=0):
    """dur in seconds, or an int sample count."""
    t = np.arange(dur) / SR if isinstance(dur, (int, np.integer)) else t_(dur)
    return np.sin(2 * np.pi * f * t + phase)


def fit(x, dur):
    n = int(SR * dur)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def norm(x, peak=0.9):
    m = np.abs(x).max()
    return x * (peak / m) if m > 0 else x


def loopify(x, fade=0.5):
    """Crossfade the tail into the head so the loop is seamless."""
    n = int(fade * SR)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    x = x.copy()
    x[:n] = head * w + tail * (1 - w)
    return x[:-n]


def reverb(x, decay=1.2, mix=0.25):
    ir_n = int(decay * SR)
    ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / (decay * SR / 5))
    ir = lp(ir, 3000)
    wet = signal.fftconvolve(x, ir)[:len(x) + ir_n]
    wet = norm(wet, np.abs(x).max() + 1e-9)
    dry = np.concatenate([x, np.zeros(ir_n)])
    m = min(len(dry), len(wet))
    return dry[:m] * (1 - mix) + wet[:m] * mix


def save(name, x, peak=0.85):
    os.makedirs(OUT, exist_ok=True)
    x = norm(np.asarray(x, np.float64), peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, 'a.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3',
                        os.path.join(OUT, name + '.ogg')], check=True)


# ---------------------------------------------------------------- loops
def amb_apartment():
    d = 14.5
    hum = sine(60, d) * 0.12 + sine(120, d) * 0.06 + sine(180, d) * 0.02
    room = lp(brown(d), 300) * 0.5
    # distant traffic swells
    sw = lp(noise(d), 500) * (0.5 + 0.5 * np.sin(2 * np.pi * t_(d) / 7.3)) ** 3 * 0.25
    # pipes knocking now and then
    knock = np.zeros(len(room))
    for at in (3.1, 3.4, 9.8):
        i = int(at * SR)
        k = lp(noise(0.08), 400) * expdecay(int(0.08 * SR), 0.02)
        knock[i:i + len(k)] += k * 0.6
    return loopify(hum + room + sw + knock)


def amb_outdoor():
    d = 20.5
    wind = bp(noise(d), 200, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * t_(d) / 9.1 + 1)) * 0.3
    wind += lp(brown(d), 200) * 0.5
    city = lp(noise(d), 180) * 0.4
    x = wind + city
    # far dog barks
    for at in (6.0, 6.45, 15.2):
        i = int(at * SR)
        b = bp(noise(0.18), 500, 1400) * env(int(0.18 * SR), 0.01, 0.17) * 0.15
        b = lp(b, 900)
        x[i:i + len(b)] += b
    # electrical hum of the street lamps
    x += sine(120, d) * 0.015
    return loopify(x, 1.0)


def drone():
    d = 24.5
    t = t_(d)
    x = np.zeros(len(t))
    for f, a in ((55, 0.3), (82.4, 0.18), (110.3, 0.12), (164.1, 0.05), (58.3, 0.15)):
        lfo = 1 + 0.004 * np.sin(2 * np.pi * t / (7 + f % 5))
        x += np.sin(2 * np.pi * f * t * lfo) * a
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * t / 12.25) ** 2
    x += lp(noise(d), 400) * 0.08
    return loopify(reverb(x, 2.0, 0.35)[:len(t)], 1.5)


def fridge_hum():
    d = 6.5
    t = t_(d)
    x = sine(50, d) * 0.3 + sine(100, d) * 0.2 + sine(150, d) * 0.08
    x *= 1 + 0.1 * np.sin(2 * np.pi * 3 * t)
    x += bp(noise(d), 80, 300) * 0.2
    return loopify(x)


def buzz():
    d = 4.5
    t = t_(d)
    saw = signal.sawtooth(2 * np.pi * 120 * t) * 0.3 + signal.square(2 * np.pi * 60 * t) * 0.05
    saw = lp(saw, 2500)
    crackle = (rng.random(len(t)) > 0.9985) * rng.standard_normal(len(t)) * 2
    return loopify(saw + lp(crackle, 4000))


def tv_static():
    d = 5.5
    x = hp(noise(d), 1500) * 0.5 + bp(noise(d), 300, 3000) * 0.2
    x *= 0.85 + 0.15 * np.sin(2 * np.pi * 15.7 * t_(d))
    return loopify(x)


def heartbeat():
    d = 1.6  # ~75 bpm, felt rather than heard
    x = np.zeros(int(SR * d))
    for at, amp in ((0.0, 1.0), (0.28, 0.7)):
        i = int(at * SR)
        n = int(0.2 * SR)
        thump = np.sin(2 * np.pi * 50 * t_(0.2) * np.exp(-t_(0.2) * 6)) * expdecay(n, 0.05)
        x[i:i + n] += thump * amp
    return lp(x, 160)


def tinnitus():
    d = 6.5
    t = t_(d)
    x = sine(3800, d) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.37 * t)) * 0.3 + sine(3810, d) * 0.15
    return loopify(x)


# ---------------------------------------------------------------- one shots
def step(kind, variant):
    n = int(0.16 * SR)
    base = noise(0.16)
    if kind == 'wood':
        x = bp(base, 90, 900) * expdecay(n, 0.025) + sine(110 + variant * 7, 0.16) * expdecay(n, 0.02) * 0.6
        x += bp(noise(0.16), 1500, 3000) * expdecay(n, 0.01) * 0.2 * (variant == 1)  # creak tick
    elif kind == 'carpet':
        x = lp(base, 600) * expdecay(n, 0.03)
    elif kind == 'tile':
        x = bp(base, 800, 5000) * expdecay(n, 0.012) + sine(900 + variant * 40, 0.16) * expdecay(n, 0.008) * 0.3
    elif kind == 'concrete':
        x = bp(base, 300, 3500) * expdecay(n, 0.018) + lp(noise(0.16), 200) * expdecay(n, 0.03) * 0.6
    else:  # grass / dirt
        x = hp(base, 1500) * expdecay(n, 0.04) * (0.5 + rng.random(n) * 0.5)
        x += lp(noise(0.16), 300) * expdecay(n, 0.03) * 0.4
    return x


def coin():
    d = 0.7
    n = int(d * SR)
    x = (sine(2093, d) + sine(2637, d) * 0.6 + sine(3520, d) * 0.3) * expdecay(n, 0.12)
    x[: int(0.06 * SR)] *= 0.4
    tink2 = np.zeros(n)
    i = int(0.07 * SR)
    tink2[i:] = (sine(2793, n - i) * expdecay(n - i, 0.15))
    return reverb(x + tink2 * 0.8, 0.6, 0.2)


def pickup():
    d = 0.35
    n = int(d * SR)
    rustle = bp(noise(d), 1000, 6000) * env(n, 0.01, 0.25) * 0.5
    thud = lp(noise(d), 300) * expdecay(n, 0.04)
    return rustle + thud


def blip():
    d = 0.04
    return sine(520, d) * env(int(d * SR), 0.002, 0.035) * 0.5 + lp(noise(d), 2000) * 0.05


def ui_move():
    d = 0.06
    return sine(330, d) * env(int(d * SR), 0.002, 0.05)


def ui_select():
    d = 0.18
    n = int(d * SR)
    return (sine(440, d) * 0.6 + sine(660, d) * 0.4) * expdecay(n, 0.05)


def ui_open():
    d = 0.25
    n = int(d * SR)
    return bp(noise(d), 600, 3000) * env(n, 0.02, 0.2) * 0.5 + lp(noise(d), 300) * expdecay(n, 0.05)


def ui_close():
    return ui_open()[::-1]


def objective():
    d = 2.2
    n = int(d * SR)
    x = np.zeros(n)
    for i, f in enumerate((220, 277.2, 329.6)):
        st = int(i * 0.12 * SR)
        x[st:] += sine(f, n - st) * expdecay(n - st, 0.6) * 0.4
    return reverb(lp(x, 2500), 1.5, 0.35)


def paper():
    d = 0.4
    n = int(d * SR)
    return bp(noise(d), 1500, 8000) * (rng.random(n) > 0.6) * env(n, 0.02, 0.35) + hp(noise(d), 3000) * env(n, 0.01, 0.3) * 0.3


def click():
    d = 0.05
    n = int(d * SR)
    return bp(noise(d), 1500, 6000) * expdecay(n, 0.004) + sine(1800, d) * expdecay(n, 0.003) * 0.4


def can_open():
    d = 0.8
    n = int(d * SR)
    snap = bp(noise(d), 2000, 9000) * expdecay(n, 0.01)
    fizz = hp(noise(d), 4000) * (rng.random(n) > 0.7) * env(n, 0.02, 0.7) * 0.4
    return snap + fizz


def sting():
    d = 2.6
    t = t_(d)
    n = len(t)
    cluster = sum(np.sin(2 * np.pi * f * t) for f in (311, 329.6, 349.2, 466.2)) * 0.25
    scrape = bp(noise(d), 800, 2600) * 0.5
    x = (cluster + scrape) * env(n, 0.005, 0.25, 0.35, 1.8, 0.3)
    low = sine(41, d) * expdecay(n, 0.8) * 0.8
    return reverb(x + low, 2.0, 0.4)


def growl():
    d = 1.6
    t = t_(d)
    n = len(t)
    f = 70 + 30 * np.sin(2 * np.pi * 1.7 * t) + 20 * np.sin(2 * np.pi * 5.3 * t)
    ph = np.cumsum(2 * np.pi * f / SR)
    x = signal.sawtooth(ph) * (0.6 + 0.4 * (rng.random(n) > 0.5))
    x = lp(x, 350) + lp(noise(d), 200) * 0.6
    gurgle = np.zeros(n)
    for at in (0.3, 0.55, 0.9, 1.2):
        i = int(at * SR)
        m = int(0.08 * SR)
        gurgle[i:i + m] += sine(180 + rng.random() * 120, 0.08) * expdecay(m, 0.02)
    return (x + gurgle * 0.7) * env(n, 0.15, 0.4, 0.7, 0.9, 0.2)


def bed_creak():
    d = 0.9
    t = t_(d)
    n = len(t)
    f = 300 + 120 * np.sin(2 * np.pi * 1.1 * t)
    ph = np.cumsum(2 * np.pi * f / SR)
    x = signal.sawtooth(ph) * (rng.random(n) > 0.55)
    return bp(x, 250, 1800) * env(n, 0.1, 0.4, 0.5, 0.4, 0.1) + lp(noise(d), 200) * expdecay(n, 0.2) * 0.4


def fridge_open():
    d = 0.6
    n = int(d * SR)
    suck = bp(noise(d), 200, 1200) * env(n, 0.005, 0.3) * 0.7
    clink = (sine(1700, d) + sine(2300, d) * 0.5) * expdecay(n, 0.05) * 0.3
    return suck + np.roll(clink, int(0.15 * SR))


def fridge_close():
    d = 0.5
    n = int(d * SR)
    return lp(noise(d), 250) * expdecay(n, 0.06) + bp(noise(d), 500, 2000) * expdecay(n, 0.02) * 0.4


def door_locked():
    d = 0.5
    n = int(d * SR)
    x = np.zeros(n)
    for at in (0.0, 0.12, 0.22):
        i = int(at * SR)
        m = int(0.08 * SR)
        x[i:i + m] += bp(noise(0.08), 600, 4000) * expdecay(m, 0.012) + lp(noise(0.08), 300) * expdecay(m, 0.02)
    return x


def door_unlock():
    d = 0.6
    n = int(d * SR)
    x = np.zeros(n)
    for at, f in ((0.0, 1200), (0.25, 900)):
        i = int(at * SR)
        m = int(0.15 * SR)
        x[i:i + m] += bp(noise(0.15), f, f * 3) * expdecay(m, 0.02) + sine(f / 2, 0.15) * expdecay(m, 0.015) * 0.5
    return x


def door_open():
    d = 1.6
    t = t_(d)
    n = len(t)
    f = 180 + 260 * t / d + 40 * np.sin(2 * np.pi * 3 * t)
    ph = np.cumsum(2 * np.pi * f / SR)
    creak = bp(signal.sawtooth(ph) * (rng.random(n) > 0.5), 300, 2500) * env(n, 0.1, 0.5, 0.6, 0.8, 0.3) * 0.6
    return reverb(creak + lp(noise(d), 200) * expdecay(n, 0.3) * 0.5, 0.8, 0.25)


def door_close():
    d = 0.9
    n = int(d * SR)
    return reverb(lp(noise(d), 180) * expdecay(n, 0.08) + bp(noise(d), 300, 1500) * expdecay(n, 0.02) * 0.5, 1.2, 0.35)


def gate_rattle():
    d = 1.2
    n = int(d * SR)
    x = np.zeros(n)
    for k in range(9):
        i = int((k * 0.09 + rng.random() * 0.03) * SR)
        m = int(0.12 * SR)
        f = 800 + rng.random() * 1500
        x[i:i + m] += (sine(f, 0.12) + sine(f * 1.47, 0.12) * 0.5) * expdecay(m, 0.03) * (1 - k / 12)
    x += bp(noise(d), 2000, 6000) * env(n, 0.01, 1.0) * 0.2
    return reverb(x, 1.0, 0.3)


def phone_ring():
    d = 4.0
    t = t_(d)
    tone = (np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 480 * t)) * 0.5
    trill = (np.sin(2 * np.pi * 20 * t) > 0) * 0.6 + 0.4
    gate = ((t % 3.0) < 1.6).astype(float)
    x = tone * trill * gate
    return reverb(bp(x, 300, 2500), 1.5, 0.35)


def thud():
    d = 0.6
    n = int(d * SR)
    return lp(noise(d), 150) * expdecay(n, 0.08) + sine(55, d) * expdecay(n, 0.1)


def door_chime():
    d = 2.5
    n = int(d * SR)
    x = np.zeros(n)
    for i, f in enumerate((659.3, 523.3)):
        st = int(i * 0.45 * SR)
        x[st:] += (sine(f, n - st) + sine(f * 2.01, n - st) * 0.3) * expdecay(n - st, 0.5)
    return reverb(x, 1.5, 0.3)


def build():
    jobs = {
        'amb_apartment': amb_apartment, 'amb_outdoor': amb_outdoor, 'drone': drone,
        'fridge_hum': fridge_hum, 'buzz': buzz, 'tv_static': tv_static, 'heartbeat': heartbeat,
        'tinnitus': tinnitus, 'coin': coin, 'pickup': pickup, 'blip': blip, 'ui_move': ui_move,
        'ui_select': ui_select, 'ui_open': ui_open, 'ui_close': ui_close, 'objective': objective,
        'paper': paper, 'click': click, 'can_open': can_open, 'sting': sting, 'growl': growl,
        'bed_creak': bed_creak, 'fridge_open': fridge_open, 'fridge_close': fridge_close,
        'door_locked': door_locked, 'door_unlock': door_unlock, 'door_open': door_open,
        'door_close': door_close, 'gate_rattle': gate_rattle, 'phone_ring': phone_ring,
        'thud': thud, 'door_chime': door_chime,
    }
    for name, fn in jobs.items():
        peak = 0.5 if name.startswith('amb') or name in ('drone', 'tinnitus', 'buzz', 'tv_static', 'fridge_hum') else 0.85
        save(name, fn(), peak)
    # footsteps: a few variants mixed into one file each (the engine pitch-shifts)
    for kind in ('wood', 'carpet', 'tile', 'concrete', 'grass'):
        save('step_' + kind, step(kind, 0), 0.7)
    print('audio done:', len(os.listdir(OUT)), 'files')


if __name__ == '__main__':
    build()
