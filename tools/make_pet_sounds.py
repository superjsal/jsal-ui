"""Builds the companion's sounds, and the two pictures of its mute button.

    python -I tools/make_pet_sounds.py [folder for .wav copies to listen to]

Nothing is recorded or generated: each sound is arithmetic, square and
triangle waves and noise in the manner of an old handheld, written as a WAV
and packed by ffmpeg (which must be installed) into
jsalUI/Media/Pet/Sounds/<name>.ogg, 44100 Hz, one channel. The names are the
ones in SOUNDS in jsalUI/Pet/Pet.lua. Three are timed to the animation they
go with: the bath (splash, bubbles, and its sparkle as the suds clear), the
medicine (a rising hum, then a sparkle as the hearts come) and hatching
(two cracks as the egg rocks, then it breaks open with a cheer).

Also writes sound_on.png and sound_off.png, 16 pixels square: a small
speaker with waves, and the same with a cross, for the button in the pen's
corner.
"""
import math
import random
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

from PIL import Image

RATE = 44100
MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
rng = random.Random(7)


def square(phase):
    return 1.0 if phase % 1 < 0.5 else -1.0


def triangle(phase):
    return 4 * abs(phase % 1 - 0.5) - 1


def tone(shape, f0, f1, secs, vol=0.5, attack=0.005):
    """A note sliding from f0 to f1, fading out."""
    out, phase, n = [], 0.0, int(RATE * secs)
    for i in range(n):
        t = i / n
        phase += (f0 + (f1 - f0) * t) / RATE
        out.append(shape(phase) * min(1, i / (RATE * attack)) * (1 - t) ** 1.5 * vol)
    return out


def swell(shape, f0, f1, secs, vol=0.3):
    """A note sliding from f0 to f1 that rises and falls away again."""
    out, phase, n = [], 0.0, int(RATE * secs)
    for i in range(n):
        t = i / n
        phase += (f0 + (f1 - f0) * t) / RATE
        out.append(shape(phase) * math.sin(math.pi * t) * vol)
    return out


def noise(secs, vol=0.5, hold=1, fade=2.0):
    """Hiss; `hold` repeats each value, which makes it lower and crunchier."""
    out, n, v = [], int(RATE * secs), 0.0
    for i in range(n):
        if i % hold == 0:
            v = rng.uniform(-1, 1)
        out.append(v * vol * (1 - i / n) ** fade)
    return out


def quiet(secs):
    return [0.0] * int(RATE * secs)


def mix(*parts):
    out = [0.0] * max(len(p) for p in parts)
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def at(secs, part):
    """`part`, starting `secs` in."""
    return quiet(secs) + part


def sparkle(vol=0.4):
    return seq(*[tone(triangle, f, f, 0.09, vol) for f in (1047, 1319, 1568, 2093)], tone(triangle, 2637, 2637, 0.3, vol))


def crack(vol=0.6):
    return noise(0.045, vol, 6)


def cheer():
    return seq(tone(square, 523, 523, 0.09, 0.3), tone(square, 659, 659, 0.09, 0.3), tone(square, 784, 1047, 0.25, 0.3))


def sounds():
    bubbles = seq(*[seq(tone(triangle, f, f * 1.6, 0.06, 0.4), quiet(0.04)) for f in (420, 520, 640, 800)])
    return {
        # Eating: three small crunches.
        "eat": seq(*[seq(noise(0.07, 0.45, 12), quiet(0.09)) for _ in range(3)]),
        # Play: a ball's boing, up and back.
        "play": seq(tone(triangle, 260, 620, 0.12, 0.6), tone(triangle, 620, 330, 0.22, 0.55)),
        # A pat: two bright chirps.
        "pat": seq(tone(square, 700, 980, 0.07, 0.28), quiet(0.03), tone(square, 880, 1250, 0.09, 0.28)),
        # Scooping: a quick swish.
        "scoop": noise(0.16, 0.35, 2, 0.6),
        # Bath, over the 2.1 seconds it plays: a splash, bubbles twice, and a sparkle as it comes out clean.
        "bath": mix(seq(noise(0.22, 0.4, 4, 1.2), bubbles), at(0.75, bubbles), at(1.35, sparkle())),
        # Medicine, over the same: a hum rising with the ring of light, then a sparkle with the hearts.
        "well": mix(swell(triangle, 330, 660, 1.0, 0.35), at(1.1, sparkle())),
        # Lights out: two soft falling notes, like a music box winding down. Waking: the same, rising.
        "sleep": seq(tone(triangle, 784, 784, 0.22, 0.4), tone(triangle, 523, 523, 0.4, 0.4)),
        "wake": seq(tone(triangle, 523, 523, 0.18, 0.4), tone(triangle, 784, 784, 0.36, 0.4)),
        # Hatching, over its ten frames of a fifth of a second: the egg rocks and cracks
        # (frames 2 and 3), breaks open (frame 5), and the hatchling stands (frame 7 on).
        "hatch": mix(at(0.4, crack()), at(0.7, crack()), at(1.0, seq(crack(0.7), noise(0.12, 0.4, 10))), at(1.4, cheer())),
        # Poorly: a small sad slide down.
        "poorly": seq(tone(triangle, 440, 330, 0.2, 0.5), tone(triangle, 330, 220, 0.34, 0.5)),
        # A wish granted: a sparkle.
        "sparkle": sparkle(),
        # Grown up, or an egg found: a little fanfare.
        "fanfare": seq(tone(square, 523, 523, 0.1, 0.3), tone(square, 659, 659, 0.1, 0.3), tone(square, 784, 784, 0.1, 0.3),
                       mix(tone(square, 1047, 1047, 0.45, 0.25), tone(triangle, 523, 523, 0.45, 0.35))),
    }


def write_wav(path, samples):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 30000)) for v in samples))


# The mute button's speaker, 16 square: # its body, o a wave, x the cross.
SPEAKER = (
    "................",
    "................",
    ".......#........",
    "......##........",
    ".....###........",
    ".#######........",
    ".#######........",
    ".#######........",
    ".#######........",
    ".#######........",
    ".#######........",
    ".....###........",
    "......##........",
    ".......#........",
    "................",
    "................",
)
WAVES = {(10, 6), (11, 7), (11, 8), (10, 9), (12, 4), (13, 5), (14, 6), (14, 7), (14, 8), (14, 9), (13, 10), (12, 11)}
CROSS = {(10 + i, 5 + i) for i in range(6)} | {(15 - i, 5 + i) for i in range(6)}
INK, FAINT, RED = (236, 230, 214, 255), (236, 230, 214, 150), (226, 96, 86, 255)


def icon(on):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(SPEAKER):
        for x, c in enumerate(row):
            if c == "#":
                im.putpixel((x, y), INK if on else FAINT)
    for x, y in (WAVES if on else CROSS):
        im.putpixel((x, y), INK if on else RED)
    return im


def main():
    out = MEDIA / "Sounds"
    out.mkdir(exist_ok=True)
    keep = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    with tempfile.TemporaryDirectory() as tmp:
        for name, samples in sounds().items():
            wav = (keep or Path(tmp)) / (name + ".wav")
            write_wav(wav, samples)
            # bitexact: the same bytes every run, with no encoder name or random stream number in the file.
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                            "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", str(out / (name + ".ogg"))], check=True)
            print(name, "%.2fs" % (len(samples) / RATE), (out / (name + ".ogg")).stat().st_size)
    icon(True).save(MEDIA / "sound_on.png", optimize=True)
    icon(False).save(MEDIA / "sound_off.png", optimize=True)
    print("sound_on.png, sound_off.png")


if __name__ == "__main__":
    main()
