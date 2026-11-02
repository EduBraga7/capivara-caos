"""Procedural audio for Capivara Caos.

Run with Blender's bundled Python (it ships numpy):
    blender -b --factory-startup --python tools/gen_audio.py -- <project_dir>

Writes mono 16-bit WAVs to audio/sfx/*.wav and audio/music/*.wav.
"""
import os
import sys
import wave
import numpy as np

SR = 44100
rng = np.random.default_rng(2026)

argv = sys.argv
out_root = argv[argv.index("--") + 1] if "--" in argv else "."
sfx_dir = os.path.join(out_root, "audio", "sfx")
mus_dir = os.path.join(out_root, "audio", "music")
os.makedirs(sfx_dir, exist_ok=True)
os.makedirs(mus_dir, exist_ok=True)


# ------------------------------------------------------------------ basics
def tt(dur):
    return np.arange(int(SR * dur)) / SR


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def sine(f, dur, ph=0.0):
    return np.sin(2 * np.pi * f * tt(dur) + ph)


def sweep(f0, f1, dur):
    t = tt(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def saw(f, dur):
    t = tt(dur)
    return 2.0 * ((f * t) % 1.0) - 1.0


def square(f, dur, duty=0.5):
    t = tt(dur)
    return np.where(((f * t) % 1.0) < duty, 1.0, -1.0)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def expenv(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def attack(x, ms=2.0):
    n = min(len(x), max(1, int(SR * ms / 1000.0)))
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    return x


def release(x, ms=6.0):
    n = min(len(x), max(1, int(SR * ms / 1000.0)))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def fft_filter(x, lo=None, hi=None):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    m = np.ones_like(f)
    if lo:
        m[f < lo] = 0.0
    if hi:
        m[f > hi] = 0.0
    return np.fft.irfft(X * m, len(x))


def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a) * x[i] + a * prev
        y[i] = prev
    return y


def tanh_norm(x, drive=1.0, peak=0.85):
    y = np.tanh(x * drive)
    m = np.max(np.abs(y)) + 1e-9
    return y / m * peak


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(x, secs):
    return np.concatenate([np.zeros(int(SR * secs)), x])


def write(path, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    x = release(attack(x, 1.0), 4.0)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", os.path.relpath(path, out_root), "%.2fs" % (len(x) / SR))


def write_loop(path, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    x = tanh_norm(x, 1.25, peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", os.path.relpath(path, out_root), "%.2fs (loop)" % (len(x) / SR))


# ------------------------------------------------------------ instruments
def pluck(f, dur, bright=0.75, decay=3.0, harmonics=9):
    t = tt(dur)
    y = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        if f * k > 14000:
            break
        amp = (1.0 / (k ** 1.15)) * (bright ** (k - 1))
        y += amp * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (decay + 1.1 * k))
    return attack(y, 3.0)


def marimba(f, dur):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 7.0)
    y += 0.45 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t * 22.0)
    y += 0.18 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 40.0)
    return attack(y, 1.5)


def bass(f, dur, drive=1.0):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t) + 0.38 * np.sin(2 * np.pi * 2 * f * t) + 0.12 * np.sin(2 * np.pi * 3 * f * t)
    y *= np.exp(-t * 3.2) * 0.75 + 0.25
    return release(attack(np.tanh(y * drive), 4.0), 20.0)


def saw_bass(f, dur):
    y = saw(f, dur) * 0.6 + saw(f * 1.006, dur) * 0.4
    y = lowpass(y, 900.0)
    y *= np.exp(-tt(dur) * 2.2) * 0.8 + 0.2
    return release(attack(y, 4.0), 25.0)


def pad(f, dur, vol=1.0):
    y = (saw(f, dur) + saw(f * 1.004, dur) + saw(f * 0.996, dur)) / 3.0
    y = fft_filter(y, hi=1800.0)
    n = len(y)
    env = np.minimum(1.0, np.arange(n) / (SR * 0.25)) * np.minimum(1.0, (n - np.arange(n)) / (SR * 0.25))
    return y * env * vol


def stab(f, dur):
    y = saw(f, dur) + 0.7 * saw(f * 1.5, dur)
    y = fft_filter(y, hi=3200.0)
    return release(attack(y * np.exp(-tt(dur) * 7.0), 2.0), 8.0)


def kick(dur=0.28):
    t = tt(dur)
    f = 48 + 120 * np.exp(-t * 32)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    y += 0.35 * noise(dur) * np.exp(-t * 90)
    return y


def snare(dur=0.22):
    t = tt(dur)
    n = fft_filter(noise(dur), lo=1500, hi=9000) * np.exp(-t * 20)
    b = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28)
    return 0.8 * n + 0.45 * b


def clap(dur=0.2):
    t = tt(dur)
    y = np.zeros_like(t)
    for off in (0.0, 0.011, 0.023):
        i = int(off * SR)
        seg = fft_filter(noise(dur), lo=900, hi=7000) * np.exp(-t * 28)
        y[i:] += seg[: len(y) - i]
    return y


def hat(dur=0.05, open_=False):
    d = 0.22 if open_ else dur
    t = tt(d)
    return fft_filter(noise(d), lo=6500) * np.exp(-t * (14 if open_ else 70))


def shaker(dur=0.07):
    t = tt(dur)
    return fft_filter(noise(dur), lo=4500, hi=11000) * np.exp(-t * 45) * np.minimum(1, t / 0.006)


def tom(f=110, dur=0.35):
    t = tt(dur)
    fr = f * (1 + 0.5 * np.exp(-t * 18))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 9)


def agogo(f=820, dur=0.18):
    t = tt(dur)
    return (np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.51 * t)) * np.exp(-t * 26)


def rim(dur=0.06):
    t = tt(dur)
    return (np.sin(2 * np.pi * 1700 * t) + 0.5 * noise(dur)) * np.exp(-t * 60)


class Track:
    def __init__(self, bars, bpm):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bar = self.beat * 4.0
        self.bars = bars
        self.length = int(round(self.bar * bars * SR))
        self.tail = int(SR * 2.5)
        self.buf = np.zeros(self.length + self.tail)

    def at(self, bar, step16, x, gain=1.0):
        start = int(round((bar * self.bar + step16 * self.beat / 4.0) * SR))
        end = min(len(self.buf), start + len(x))
        if end > start:
            self.buf[start:end] += x[: end - start] * gain

    def result(self):
        out = self.buf[: self.length].copy()
        wrap = self.buf[self.length:]
        out[: len(wrap)] += wrap
        return out


def chord(root, kind):
    ints = {
        "maj": [0, 4, 7], "min": [0, 3, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10],
        "dom7": [0, 4, 7, 10], "sus": [0, 5, 7, 10], "power": [0, 7, 12],
    }[kind]
    return [root + i for i in ints]


# =============================================================== MUSIC
def make_battle():
    tr = Track(8, 138)
    # (root midi, kind) per bar : Am F C G | Am F C E
    prog = [(57, "min"), (53, "maj"), (48, "maj"), (55, "maj"), (57, "min"), (53, "maj"), (48, "maj"), (52, "maj")]
    kk, sn, cl = kick(), snare(), clap()
    for b in range(8):
        root, kind = prog[b]
        notes = chord(root + 12, kind)
        # drums
        for beat in range(4):
            tr.at(b, beat * 4, kk, 0.95)
        for s in (4, 12):
            tr.at(b, s, sn, 0.7)
            tr.at(b, s, cl, 0.32)
        for s in range(0, 16, 2):
            tr.at(b, s, hat(), 0.35 if s % 4 == 0 else 0.22)
        tr.at(b, 14, hat(open_=True), 0.25)
        for s in range(1, 16, 2):
            tr.at(b, s, shaker(), 0.16)
        for s in (4, 12):
            tr.at(b, s + 2, tom(105), 0.5)
        if b == 7:
            for i, s in enumerate((12, 13, 14, 15)):
                tr.at(b, s, snare(0.12), 0.35 + 0.15 * i)
        # bass: syncopated 8ths
        pat = [(0, 0), (3, 0), (4, 12), (6, 0), (7, 7), (10, 0), (11, 7), (14, 0)]
        for s, iv in pat:
            tr.at(b, s, bass(mtof(root - 12 + iv), tr.beat * 0.45), 0.8)
        # pad
        for n in notes:
            tr.at(b, 0, pad(mtof(n), tr.bar * 0.98), 0.07)
        # arpeggio (marimba), 16ths up-down
        arp = [notes[0], notes[1], notes[2], notes[1] + 0, notes[0] + 12, notes[2], notes[1], notes[0]]
        for i in range(16):
            n = arp[i % 8] + (12 if (i // 8) % 2 == 1 and b % 2 == 1 else 0)
            tr.at(b, i, marimba(mtof(n), 0.22), 0.34 if i % 4 == 0 else 0.22)
        # melody every 2 bars (pentatonic, A minor)
        mel = {0: [(0, 81), (3, 84), (6, 88), (8, 86), (11, 84), (14, 81)], 1: [(0, 79), (3, 81), (6, 84), (8, 81), (12, 79)]}
        if b % 4 in (0, 2):
            for s, n in mel[(b // 2) % 2]:
                tr.at(b, s, pluck(mtof(n), 0.42, 0.85, 2.2), 0.34)
        if b % 2 == 0:
            tr.at(b, 0, agogo(900), 0.25)
            tr.at(b, 6, agogo(1200), 0.2)
            tr.at(b, 10, agogo(900), 0.2)
    return tr.result()


def make_menu():
    tr = Track(8, 84)
    prog = [(48, "maj7"), (45, "min7"), (50, "min7"), (43, "dom7"), (48, "maj7"), (45, "min7"), (41, "maj7"), (43, "sus")]
    for b in range(8):
        root, kind = prog[b]
        notes = chord(root + 12, kind)
        # bossa comp pattern (16th steps)
        for s in (0, 6, 8, 14):
            for i, n in enumerate(notes):
                tr.at(b, s + i * 0.12, pluck(mtof(n), 0.9, 0.7, 3.2), 0.19)
        # bossa bass
        tr.at(b, 0, bass(mtof(root - 12), tr.beat * 1.6), 0.85)
        tr.at(b, 6, bass(mtof(root - 12 + 7), tr.beat * 1.2), 0.65)
        tr.at(b, 8, bass(mtof(root - 12), tr.beat * 1.6), 0.8)
        tr.at(b, 14, bass(mtof(root - 12 + 7), tr.beat * 1.0), 0.6)
        # rim + shaker
        for s in (6, 12, 14):
            tr.at(b, s, rim(), 0.22)
        for s in range(0, 16, 2):
            tr.at(b, s, shaker(), 0.2 if s % 4 else 0.28)
        tr.at(b, 0, kick(0.25), 0.4)
        tr.at(b, 8, kick(0.25), 0.3)
        # soft vibes melody (C major pentatonic)
        mel = [
            [(0, 76), (4, 79), (8, 81), (12, 79)],
            [(0, 76), (6, 72), (10, 74), (14, 76)],
            [(0, 77), (4, 81), (8, 79), (12, 77)],
            [(0, 74), (8, 71), (12, 74)],
        ][b % 4]
        for s, n in mel:
            tr.at(b, s, marimba(mtof(n), 1.0), 0.3)
    return tr.result()


def make_boss():
    tr = Track(8, 156)
    # Dm Bb C A | Dm Bb C A
    prog = [(50, "min"), (46, "maj"), (48, "maj"), (45, "maj"), (50, "min"), (46, "maj"), (48, "maj"), (45, "maj")]
    kk, sn = kick(0.3), snare(0.25)
    for b in range(8):
        root, kind = prog[b]
        for s in (0, 3, 6, 8, 10, 14):
            tr.at(b, s, kk, 0.95 if s in (0, 8) else 0.6)
        for s in (4, 12):
            tr.at(b, s, sn, 0.85)
            tr.at(b, s, clap(), 0.35)
        for s in range(16):
            tr.at(b, s, hat(), 0.3 if s % 2 == 0 else 0.18)
        for s in (2, 10):
            tr.at(b, s, tom(90), 0.55)
        if b in (3, 7):
            for i in range(8):
                tr.at(b, 8 + i, tom(140 - i * 6, 0.2), 0.3 + 0.07 * i)
        for s in range(0, 16, 2):
            iv = 0 if s not in (6, 14) else 7
            tr.at(b, s, saw_bass(mtof(root - 12 + iv), tr.beat * 0.45), 0.55)
        notes = chord(root, "power")
        for s in (0, 6, 10):
            for n in notes:
                tr.at(b, s, stab(mtof(n + 12), 0.3), 0.18)
        # menacing riff
        third = 3 if kind == "min" else 4
        riff = [(0, 0), (2, third), (3, 0), (6, -2), (8, 0), (10, third), (12, 5), (14, third)]
        if b % 2 == 0:
            for s, iv in riff:
                tr.at(b, s, pluck(mtof(root + 24 + iv + (0 if b < 4 else 12)), 0.3, 0.9, 3.5), 0.28)
        for n in chord(root + 12, kind):
            tr.at(b, 0, pad(mtof(n), tr.bar * 0.98), 0.07)
    return tr.result()


# ================================================================== SFX
def sfx_all():
    S = {}
    # shot: soft whoosh-pop
    t = tt(0.14)
    S["shoot"] = sweep(620, 250, 0.14) * expenv(len(t), 0.05) + 0.25 * fft_filter(noise(0.14), lo=1200, hi=5000) * expenv(len(t), 0.03)
    S["hit"] = mix(sweep(210, 90, 0.1) * expenv(int(SR * 0.1), 0.04), 0.5 * lowpass(noise(0.06), 2500) * expenv(int(SR * 0.06), 0.02))
    S["kill"] = mix(sweep(780, 220, 0.1) * expenv(int(SR * 0.1), 0.035), 0.45 * sweep(520, 1040, 0.08) * expenv(int(SR * 0.08), 0.03), 0.3 * fft_filter(noise(0.05), lo=900, hi=6000) * expenv(int(SR * 0.05), 0.015))
    big = lowpass(noise(1.0), 700) * expenv(int(SR * 1.0), 0.28) * 1.5
    S["kill_big"] = mix(big, sweep(95, 32, 0.9) * expenv(int(SR * 0.9), 0.3), 0.4 * fft_filter(noise(0.4), lo=800, hi=6000) * expenv(int(SR * 0.4), 0.08))
    g = mix(sine(880, 0.22) * expenv(int(SR * 0.22), 0.07), 0.55 * sine(1320, 0.22) * expenv(int(SR * 0.22), 0.05), 0.25 * sine(1760, 0.22) * expenv(int(SR * 0.22), 0.03))
    S["gem"] = attack(g, 1.0)
    c1 = square(988, 0.08, 0.5) * 0.5
    c2 = square(1319, 0.28, 0.5) * expenv(int(SR * 0.28), 0.09) * 0.5
    S["coin"] = lowpass(mix(c1, delay(c2, 0.08)), 6000)
    # level up arpeggio
    notes = [72, 76, 79, 84, 88]
    lv = np.zeros(int(SR * 1.1))
    for i, n in enumerate(notes):
        seg = (sine(mtof(n), 0.5) + 0.3 * sine(mtof(n) * 2, 0.5)) * expenv(int(SR * 0.5), 0.14)
        s = int(SR * 0.075 * i)
        lv[s:s + len(seg)] += seg
    S["levelup"] = lv
    # chest: creak + chime
    cr = lowpass(noise(0.45), 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * tt(0.45))) * 0.7
    ch = np.zeros(int(SR * 1.4))
    for i, n in enumerate((67, 72, 76, 79)):
        seg = sine(mtof(n), 0.5) * expenv(int(SR * 0.5), 0.16)
        s = int(SR * (0.35 + 0.07 * i))
        ch[s:s + len(seg)] += seg * 0.7
    S["chest"] = mix(cr * 0.8, ch)
    # evolve: rising shimmer + big chord
    ev = np.zeros(int(SR * 2.4))
    sw = sweep(220, 1760, 0.9) * np.linspace(0.2, 1, int(SR * 0.9)) * 0.5
    ev[: len(sw)] += sw
    for n in (60, 64, 67, 72, 76, 79, 84):
        seg = (sine(mtof(n), 1.2) + 0.25 * sine(mtof(n) * 2, 1.2)) * expenv(int(SR * 1.2), 0.45)
        s = int(SR * 0.85)
        ev[s:s + len(seg)] += seg * 0.3
    ev = mix(ev, 0.3 * fft_filter(noise(2.0), lo=5000) * np.concatenate([np.zeros(int(SR * 0.8)), expenv(int(SR * 1.2), 0.3)]))
    S["evolve"] = ev
    ds = fft_filter(noise(0.22), lo=500, hi=6000)
    env = np.sin(np.pi * np.linspace(0, 1, len(ds))) ** 1.5
    S["dash"] = ds * env
    S["hurt"] = mix(sweep(260, 95, 0.22) * expenv(int(SR * 0.22), 0.09), 0.6 * lowpass(noise(0.18), 1800) * expenv(int(SR * 0.18), 0.05), 0.4 * sine(55, 0.25) * expenv(int(SR * 0.25), 0.1))
    # boss roar
    rt = tt(1.3)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * rt)
    roar = (saw(68, 1.3) + saw(71, 1.3) * 0.8) * trem
    roar = lowpass(roar, 520) * np.minimum(1, rt / 0.12) * np.exp(-np.maximum(0, rt - 0.7) * 4)
    S["boss_roar"] = mix(roar * 1.6, 0.35 * lowpass(noise(1.3), 900) * np.exp(-rt * 1.6))
    ex = lowpass(noise(0.8), 1400) * expenv(int(SR * 0.8), 0.22) * 1.4
    S["explosion"] = mix(ex, sweep(110, 35, 0.7) * expenv(int(SR * 0.7), 0.25), 0.3 * fft_filter(noise(0.3), lo=1500) * expenv(int(SR * 0.3), 0.05))
    zt = tt(0.32)
    zap = saw(1 / 1.0 * 1, 0.32)
    zf = 1500 * (180 / 1500) ** (zt / 0.32)
    zap = np.sign(np.sin(2 * np.pi * np.cumsum(zf) / SR)) * 0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(zf * 1.01) / SR)
    zap = zap * expenv(len(zt), 0.12) + 0.4 * fft_filter(noise(0.32), lo=2000) * expenv(len(zt), 0.06)
    S["zap"] = lowpass(zap, 9000)
    sw2 = fft_filter(noise(0.22), lo=1000, hi=7000)
    S["swish"] = sw2 * (np.sin(np.pi * np.linspace(0, 1, len(sw2))) ** 2) * 0.8
    # vuvuzela: Bb3 ~233Hz, harmonic rich, vibrato
    vt = tt(0.6)
    vf = 233 * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * vt))
    ph = 2 * np.pi * np.cumsum(vf) / SR
    vv = sum(np.sin(ph * k) / (k ** 0.8) for k in range(1, 14))
    venv = np.minimum(1, vt / 0.03) * np.minimum(1, (0.6 - vt) / 0.12)
    S["vuvu"] = vv * venv * (0.8 + 0.2 * np.sin(2 * np.pi * 40 * vt))
    mt = tt(0.35)
    mud = sweep(330, 110, 0.35) * expenv(len(mt), 0.12)
    for off, f in ((0.05, 500), (0.14, 380), (0.22, 600)):
        seg = sweep(f, f * 0.5, 0.08) * expenv(int(SR * 0.08), 0.03) * 0.6
        s = int(SR * off)
        mud[s:s + len(seg)] += seg
    S["mud"] = mud
    tw = np.zeros(int(SR * 0.22))
    for off, f0, f1 in ((0.0, 2200, 3300), (0.09, 2600, 3600)):
        seg = sweep(f0, f1, 0.07) * np.sin(np.pi * np.linspace(0, 1, int(SR * 0.07)))
        s = int(SR * off)
        tw[s:s + len(seg)] += seg
    S["tweet"] = tw * 0.7
    S["ui_click"] = mix(sine(900, 0.07) * expenv(int(SR * 0.07), 0.02), 0.6 * sine(1350, 0.07) * expenv(int(SR * 0.07), 0.015))
    S["ui_hover"] = sine(620, 0.05) * expenv(int(SR * 0.05), 0.014)
    # game over: sad descending "wah" trombone
    go = np.zeros(int(SR * 2.5))
    for i, (n, d) in enumerate(((67, 0.35), (65, 0.35), (64, 0.35), (60, 1.0))):
        gt = tt(d)
        f = mtof(n) * (1 + 0.015 * np.sin(2 * np.pi * 5 * gt)) * (1.0 - 0.04 * (gt / d))
        seg = saw(1, d) * 0
        seg = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(f) / SR) + 0.25 * np.sin(6 * np.pi * np.cumsum(f) / SR)
        seg = lowpass(seg, 1500) * np.minimum(1, gt / 0.04) * np.exp(-gt * 1.2)
        s = int(SR * (0.4 * i if i < 3 else 1.2))
        go[s:s + len(seg)] += seg
    S["gameover"] = go
    # win fanfare
    wn = np.zeros(int(SR * 2.8))
    for i, n in enumerate((72, 72, 72, 76, 79, 84)):
        d = 0.14 if i < 3 else (0.3 if i < 5 else 1.4)
        seg = (square(mtof(n), d, 0.4) * 0.5 + 0.5 * np.sin(2 * np.pi * mtof(n) * tt(d)))
        seg = lowpass(seg, 5000) * np.minimum(1, tt(d) / 0.01) * np.exp(-tt(d) * (3 if i == 5 else 5))
        s = int(SR * (0.13 * i if i < 3 else (0.4 + 0.3 * (i - 3))))
        wn[s:s + len(seg)] += seg
    for n in (60, 64, 67, 72):
        seg = np.sin(2 * np.pi * mtof(n) * tt(1.6)) * expenv(int(SR * 1.6), 0.7) * 0.4
        s = int(SR * 1.0)
        wn[s:s + len(seg)] += seg
    S["win"] = wn
    hl = np.zeros(int(SR * 0.7))
    for i, n in enumerate((72, 76, 79)):
        seg = (sine(mtof(n), 0.4) + 0.2 * sine(mtof(n) * 2, 0.4)) * expenv(int(SR * 0.4), 0.15) * np.minimum(1, tt(0.4) / 0.03)
        s = int(SR * 0.09 * i)
        hl[s:s + len(seg)] += seg
    S["heal"] = hl
    dd = tt(0.4)
    dg = sweep(400, 1700, 0.4) * np.sin(np.pi * np.linspace(0, 1, len(dd))) * 0.6
    dn = fft_filter(noise(0.4), lo=2500, hi=9000) * np.sin(np.pi * np.linspace(0, 1, len(dd))) ** 2 * 0.5
    S["dodge"] = dg + dn
    mg = tt(0.55)
    mgf = 200 * (950 / 200) ** (mg / 0.55) * (1 + 0.03 * np.sin(2 * np.pi * 14 * mg))
    S["magnet"] = np.sin(2 * np.pi * np.cumsum(mgf) / SR) * np.sin(np.pi * np.linspace(0, 1, len(mg))) ** 0.6
    wr = np.zeros(int(SR * 0.55))
    for i in range(3):
        seg = (square(520 if i % 2 == 0 else 390, 0.14, 0.5) * 0.5)
        seg = lowpass(seg, 3000) * np.minimum(1, tt(0.14) / 0.01) * np.exp(-tt(0.14) * 8)
        s = int(SR * 0.16 * i)
        wr[s:s + len(seg)] += seg
    S["warning"] = wr
    S["pop"] = sweep(500, 1300, 0.07) * expenv(int(SR * 0.07), 0.025)
    st = tt(0.38)
    sk = (sweep(190, 120, 0.38) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * st))) * np.exp(-st * 5)
    sk += 0.5 * fft_filter(noise(0.38), lo=400, hi=3500) * np.exp(-st * 6)
    S["stink"] = sk
    S["thud"] = mix(sweep(120, 50, 0.16) * expenv(int(SR * 0.16), 0.06), 0.3 * lowpass(noise(0.1), 800) * expenv(int(SR * 0.1), 0.03))
    rr = np.zeros(int(SR * 0.45))
    for i in range(7):
        seg = rim(0.05) * (0.5 + 0.5 * rng.random())
        s = int(SR * (0.05 * i + 0.01 * rng.random()))
        rr[s:s + len(seg)] += seg
    S["reroll"] = rr
    sl = np.zeros(int(SR * 0.9))
    for i, n in enumerate((84, 88, 91, 96)):
        seg = (sine(mtof(n), 0.5) + 0.3 * sine(mtof(n) * 2, 0.5)) * expenv(int(SR * 0.5), 0.14)
        s = int(SR * 0.06 * i)
        sl[s:s + len(seg)] += seg * 0.8
    sl += 0.25 * fft_filter(noise(0.9), lo=6000) * expenv(int(SR * 0.9), 0.3)
    S["slot"] = sl
    ms = np.zeros(int(SR * 0.7))
    for i, n in enumerate((76, 79, 83, 88)):
        seg = (square(mtof(n), 0.18, 0.4) * 0.45 + 0.5 * sine(mtof(n), 0.18))
        seg = lowpass(seg, 4500) * expenv(int(SR * 0.18), 0.1)
        s = int(SR * 0.09 * i)
        ms[s:s + len(seg)] += seg
    S["milestone"] = ms
    return S


gains = {"hit": 0.8, "kill": 0.85, "gem": 0.75, "ui_hover": 0.6, "swish": 0.7, "shoot": 0.8, "tweet": 0.7, "stink": 0.85, "thud": 0.9, "warning": 0.7}
for name, data in sfx_all().items():
    data = np.asarray(data, dtype=np.float64)
    data = fft_filter(data, hi=14000) if len(data) > 64 else data
    write(os.path.join(sfx_dir, name + ".wav"), data, gains.get(name, 0.9))

write_loop(os.path.join(mus_dir, "battle.wav"), make_battle(), 0.8)
write_loop(os.path.join(mus_dir, "menu.wav"), make_menu(), 0.8)
write_loop(os.path.join(mus_dir, "boss.wav"), make_boss(), 0.82)
print("AUDIO DONE")
