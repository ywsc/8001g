#!/usr/bin/env python3
"""AI-generated art for the face-to-face (first person) scenes.

Images come from pollinations.ai (free, no key). The raw download is cached in
assets/ai_src/ so runs are reproducible; each image is then cropped (removing
the service watermark), graded dim and pixelated to the game's 480x270
resolution with a limited palette.

Usage:
  python3 tools/ai_art.py                 # fetch missing + rebuild all
  python3 tools/ai_art.py --only vincent  # one entry
  python3 tools/ai_art.py --refetch red   # ignore the cache for an entry
  python3 tools/ai_art.py --try vincent --seeds 1,2,3   # candidates to compare
"""
import argparse
import os
import sys
import time
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'ai_src')
OUT = os.path.join(ROOT, 'assets', 'gfx', 'faces')

STYLE = ('cinematic still, dark horror film, night, 35mm, film grain, muted desaturated colors, '
         'realistic proportions, deep shadows, single harsh light source')

# name -> prompt, seed, grade options
ENTRIES = {
    'vincent': dict(
        prompt=('first person view across a convenience store counter at 2am, a tired 28 year old bald man '
                'with grey eyes, pale skin, light stubble, wearing a cheap dark green store uniform polo shirt, '
                'standing behind the cash register looking at the viewer, flickering fluorescent tube light above, '
                'cigarette rack and shelves behind him, ' + STYLE),
        seed=202, colors=56, gamma=1.15),
    'vincent_low': dict(
        prompt=('first person view across a convenience store counter at 2am, a tired 28 year old bald man '
                'with grey eyes, pale skin, light stubble, dark green store polo shirt, looking down at the counter, '
                'eyes wet, shoulders slumped, fluorescent tube light above, shelves behind him, ' + STYLE),
        seed=202, colors=56, gamma=1.2),
    'red': dict(
        prompt=('crime scene photo at night: an unconscious woman lying prone on her stomach on wet asphalt in an '
                'empty parking lot, seen from behind her feet, the back of her head with long red hair spread on the '
                'ground, face turned into the asphalt and not visible, dark wool coat, one arm stretched out, bright '
                'car headlight beam falling across her body from the left, long shadows, ' + STYLE),
        seed=12, colors=48, gamma=1.2),
}

W, H = 480, 270
REQ_W, REQ_H = 960, 600     # extra height so the watermark can be cropped away


def fetch(prompt, seed, path, tries=4):
    q = urllib.parse.quote(prompt)
    url = f'https://image.pollinations.ai/prompt/{q}?width={REQ_W}&height={REQ_H}&seed={seed}&nologo=true'
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=180) as r:
                data = r.read()
            if len(data) < 5000:
                raise RuntimeError('response too small')
            with open(path, 'wb') as f:
                f.write(data)
            return
        except Exception as e:  # network hiccups, rate limits
            print(f'  fetch failed ({e}), retry {i + 1}/{tries}')
            time.sleep(4 * (i + 1))
    raise SystemExit('could not fetch ' + path)


def pixelate(src, dst, colors=56, gamma=1.15):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    im = im.crop((0, 0, w, int(h * 0.9)))                 # watermark lives in the bottom strip
    im = im.resize((W, H), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(0.8)
    a = np.asarray(im).astype(np.float32) / 255.0
    a = a ** gamma                                          # dimmer mid-tones
    a = np.clip(a * 1.04, 0, 1)
    im = Image.fromarray((a * 255 + 0.5).astype(np.uint8))
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    im = im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).convert('RGB')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)


def build(names, refetch=False):
    os.makedirs(SRC, exist_ok=True)
    for name in names:
        e = ENTRIES[name]
        raw = os.path.join(SRC, name + '.jpg')
        if refetch or not os.path.exists(raw):
            print('fetching', name)
            fetch(e['prompt'], e['seed'], raw)
        pixelate(raw, os.path.join(OUT, name + '.png'), e['colors'], e['gamma'])
        print('built', name)


def try_seeds(name, seeds):
    e = ENTRIES[name]
    d = os.path.join('/tmp', 'ai_try')
    os.makedirs(d, exist_ok=True)
    tiles = []
    for s in seeds:
        p = os.path.join(d, f'{name}_{s}.jpg')
        fetch(e['prompt'], s, p)
        tiles.append(Image.open(p).convert('RGB').resize((480, 300)))
    sheet = Image.new('RGB', (480 * len(tiles), 300))
    for i, t in enumerate(tiles):
        sheet.paste(t, (480 * i, 0))
    out = os.path.join(d, f'{name}_candidates.jpg')
    sheet.save(out)
    print(out)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--only')
    ap.add_argument('--refetch')
    ap.add_argument('--try', dest='trial')
    ap.add_argument('--seeds', default='1,2,3')
    a = ap.parse_args()
    if a.trial:
        try_seeds(a.trial, [int(s) for s in a.seeds.split(',')])
        sys.exit()
    if a.refetch:
        build(a.refetch.split(','), refetch=True)
    else:
        build(a.only.split(',') if a.only else list(ENTRIES))
