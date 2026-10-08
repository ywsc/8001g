#!/usr/bin/env python3
"""AI-generated art for the face-to-face (first person) scenes.

Default: drawn natively as pixel art by the "Pixel Illustrious" model on
AI Horde (tools/horde.py, free community GPUs, slow anonymous queue). The
raw outputs are cached in assets/ai_src/<name>_px.png and only cleaned up
(16:9 crop, 2x2 pixel grid, palette tidy).

Legacy (--photo): photographic images from pollinations.ai, pixelated.

Images come from pollinations.ai (free, no key). The raw download is cached in
assets/ai_src/ so runs are reproducible; each image is then cropped (removing
the service watermark), graded dim and pixelated to the game's 480x270
resolution as pixel art: shapes flattened, a small k-means palette, the same
4x4 ordered dither as the sprites, dark selective outlines, and 2x2 art
pixels (240x135 upscaled with nearest neighbour).

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
HORDE_NEG = ('lowres, worst quality, text, watermark, signature, photo, realistic, 3d, blurry, smooth gradient, '
             'bright colors, cheerful, extra fingers, bad anatomy')
PIXEL_STYLE = 'muted colors, dim lighting, limited palette'

# Pixel-art faces drawn natively by a pixel-art model on AI Horde.
HORDE = {
    'vincent': dict(
        prompt=('pixel art, dark horror adventure game, 1boy, solo, young man, 20s, youthful face, smooth skin, clean shaven '
                'bald head, shaved head, grey eyes, faint stubble, tired expression, dark circles under eyes, pale skin, '
                'dark green polo shirt, name tag, '
                'standing behind convenience store counter, cash register, looking at viewer, upper body, night, '
                'fluorescent ceiling light, shelves in background, ' + PIXEL_STYLE),
        seed=11),
    'vincent_low': dict(
        prompt=('pixel art, dark horror adventure game, 1boy, solo, young man, 28 years old, bald, shaved head, grey eyes, '
                'light stubble, sad, looking down, arms crossed, dark green polo shirt, name tag, behind convenience store '
                'counter, upper body, night, fluorescent ceiling light, shelves in background, ' + PIXEL_STYLE),
        seed=11),
    'red': dict(
        prompt=('pixel art, dark horror adventure game, 1girl, solo, lying on stomach, face down, face not visible, long red '
                'hair spread on the ground, dark coat, arm outstretched, wet asphalt, empty parking lot, night, car headlights '
                'shining on her from the side, from above, long shadows, ' + PIXEL_STYLE),
        seed=11, anchor='bottom'),
}
HORDE_MODEL = 'Pixel Illustrious'

# Earlier photographic versions (pollinations.ai), kept for reference only.
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


BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) + 0.5) / 16.0 - 0.5


def kmeans_palette(px, k, iters=12, seed=0):
    """Small k-means in RGB (no sklearn needed)."""
    rng = np.random.default_rng(seed)
    pts = px[rng.choice(len(px), min(len(px), 20000), replace=False)]
    # init: spread over luminance so darks and lights both get colours
    lum = pts @ np.array([0.299, 0.587, 0.114], np.float32)
    order = np.argsort(lum)
    cent = pts[order[np.linspace(0, len(pts) - 1, k).astype(int)]].copy()
    for _ in range(iters):
        d = ((pts[:, None, :] - cent[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        for i in range(k):
            m = lab == i
            if m.any():
                cent[i] = pts[m].mean(0)
    return cent


def pixelate(src, dst, colors=28, gamma=1.15, scale=2, spread=0.035):
    """Photo -> pixel art: flatten shapes, small palette, ordered dither, outlines."""
    im = Image.open(src).convert('RGB')
    w, h = im.size
    im = im.crop((0, 0, w, int(h * 0.9)))                 # watermark lives in the bottom strip
    pw, ph = W // scale, H // scale
    # flatten photographic texture into shapes before shrinking
    im = im.filter(ImageFilter.MedianFilter(5))
    im = im.resize((pw, ph), Image.BOX)
    im = ImageEnhance.Color(im).enhance(0.85)
    im = ImageEnhance.Contrast(im).enhance(1.12)
    a = np.asarray(im).astype(np.float32) / 255.0
    a = np.clip(a ** gamma, 0, 1)
    pal = kmeans_palette(a.reshape(-1, 3), colors)
    # ordered (Bayer) dither against the palette, same pattern the sprites use
    yy, xx = np.mgrid[0:ph, 0:pw]
    t = BAYER4[yy % 4, xx % 4][..., None] * spread
    d = (((a + t)[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
    idx = d.argmin(-1)
    out = pal[idx]
    # selective outline: darken pixels on strong luminance edges
    lum = out @ np.array([0.299, 0.587, 0.114], np.float32)
    gy, gx = np.gradient(lum)
    edge = np.hypot(gx, gy) > 0.13
    darker = lum < np.maximum(np.roll(lum, 1, 0), np.roll(lum, 1, 1))
    darkest = pal[np.argmin(pal @ np.array([0.299, 0.587, 0.114], np.float32))]
    out[edge & darker] = out[edge & darker] * 0.45 + darkest * 0.55
    im = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8))
    im = im.resize((W, H), Image.NEAREST)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)


def clean_pixel_art(src, dst, colors=40, gamma=1.05, anchor='top'):
    """The source is already pixel art: crop to 16:9, snap to a 240x135 grid of
    2x2 blocks, tidy the palette (no dithering), keep it dim."""
    im = Image.open(src).convert('RGB')
    w, h = im.size
    ch = int(w * 9 / 16)
    top = {'top': 0, 'center': (h - ch) // 2, 'bottom': h - ch}[anchor]
    im = im.crop((0, top, w, top + ch))
    pw, ph = W // 2, H // 2
    im = im.resize((pw, ph), Image.BOX)
    a = np.asarray(im).astype(np.float32) / 255.0
    a = np.clip(a ** gamma * 0.92, 0, 1)
    pal = kmeans_palette(a.reshape(-1, 3), colors)
    idx = (((a[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)).argmin(-1)
    im = Image.fromarray((pal[idx] * 255 + 0.5).astype(np.uint8)).resize((W, H), Image.NEAREST)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)


def build_horde(names, refetch=False):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import horde
    os.makedirs(SRC, exist_ok=True)
    for name in names:
        e = HORDE[name]
        raw = os.path.join(SRC, name + '_px.png')
        if refetch or not os.path.exists(raw):
            print('generating', name, 'on AI Horde (' + HORDE_MODEL + ')')
            horde.generate(e['prompt'], raw, HORDE_MODEL, 576, 384, e['seed'], negative=HORDE_NEG)
        clean_pixel_art(raw, os.path.join(OUT, name + '.png'), anchor=e.get('anchor', 'top'))
        print('built', name)


def build(names, refetch=False):
    os.makedirs(SRC, exist_ok=True)
    for name in names:
        e = ENTRIES[name]
        raw = os.path.join(SRC, name + '.jpg')
        if refetch or not os.path.exists(raw):
            print('fetching', name)
            fetch(e['prompt'], e['seed'], raw)
        pixelate(raw, os.path.join(OUT, name + '.png'), e.get('palette', 28), e['gamma'])
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
    ap.add_argument('--photo', action='store_true', help='use the old photographic pollinations pipeline')
    a = ap.parse_args()
    if a.trial:
        try_seeds(a.trial, [int(s) for s in a.seeds.split(',')])
        sys.exit()
    if a.photo:   # the old photographic pipeline
        build(a.only.split(',') if a.only else list(ENTRIES), refetch=bool(a.refetch))
    elif a.refetch:
        build_horde(a.refetch.split(','), refetch=True)
    else:
        build_horde(a.only.split(',') if a.only else list(HORDE))
