"""24x24 inventory icons (colour only, shading baked in, light from top-left)."""
import numpy as np

from . import palette as P
from .core import Sprite, Ramp, hexc, save_icon, fbm

S = 24


def lit(s, mask, ramp, base=0.55, k=0.35, cx=12, cy=12, r=10, dither=True):
    v = base - k * ((s.xx - cx) + (s.yy - cy)) / (2 * r)
    s.paint(mask, ramp=ramp, value=v, dither=dither)


def finish(s):
    s.outline(0.45)
    # 1px dark drop shadow to the lower right for readability
    sh = np.roll(np.roll(s.a, 1, 0), 1, 1) & ~s.a
    s.paint(sh, color=hexc('#000000'))
    return s


def coin():
    s = Sprite(S, S)
    m = s.ellipse_mask(12, 12, 8, 8)
    lit(s, m, P.GOLD, 0.6, 0.5)
    inner = s.ellipse_mask(12, 12, 6, 6)
    lit(s, inner & ~s.ellipse_mask(12, 12, 5, 5), P.GOLD, 0.35, 0.3)
    s.paint(s.rect_mask(10, 8, 4, 8) & ~s.rect_mask(11, 9, 2, 6), ramp=P.GOLD, value=0.85)
    s.paint(s.rect_mask(8, 7, 2, 1) | s.rect_mask(7, 8, 1, 2), ramp=P.GOLD, value=1.0)
    s.tint(m & (fbm(S, S, 3, 7, 2) > 0.62), hexc('#2a1a08'), 0.4)
    return finish(s)


def water():
    s = Sprite(S, S)
    body = s.rect_mask(8, 7, 8, 15) | s.ellipse_mask(12, 7, 4, 2)
    s.paint(body, ramp=P.WATER_BLUE, value=0.45 + (11 - s.xx) * 0.04)
    s.paint(s.rect_mask(8, 7, 8, 6) & body, ramp=P.WATER_BLUE, value=0.75 + (11 - s.xx) * 0.03)   # air (half empty)
    s.paint(s.rect_mask(8, 13, 8, 1), ramp=P.WATER_BLUE, value=0.95)
    s.paint(s.rect_mask(10, 2, 4, 4), ramp=Ramp.from_base('#2a4a8a', 4), value=0.6)
    s.paint(s.rect_mask(8, 15, 8, 4), ramp=P.PAPER, value=0.6)
    s.paint(s.rect_mask(9, 16, 6, 1), ramp=Ramp.from_base('#2a4a8a', 4), value=0.5)
    s.paint(s.rect_mask(9, 8, 1, 12), ramp=P.WATER_BLUE, value=1.0)
    return finish(s)


def coke():
    s = Sprite(S, S)
    body = s.rect_mask(7, 5, 10, 16)
    lit(s, body, P.COKE_RED, 0.6, 0.6, cx=12, r=6)
    s.paint(s.ellipse_mask(12, 5, 5, 1.6), ramp=P.METAL, value=0.75)
    s.paint(s.rect_mask(7, 20, 10, 2), ramp=P.METAL, value=0.5)
    s.paint(s.rect_mask(11, 4, 3, 1), ramp=P.METAL, value=0.3)
    wave = (np.abs(s.yy - (12 + 2 * np.sin(s.xx * 0.8))) < 1) & body
    s.paint(wave, ramp=P.PORCELAIN, value=0.85)
    s.paint(s.rect_mask(8, 6, 1, 14), ramp=P.COKE_RED, value=1.0)
    return finish(s)


def meat():
    s = Sprite(S, S)
    tray = s.rect_mask(3, 8, 18, 11)
    s.paint(tray, ramp=Ramp.from_base('#7a7a72', 5), value=0.5)
    m = s.ellipse_mask(12, 13, 7, 4.5)
    n = fbm(S, S, 3, 11, 3)
    s.paint(m, ramp=P.RAWMEAT, value=0.35 + n * 0.5)
    fat = (n > 0.62) & m
    s.paint(fat, ramp=P.PORCELAIN, value=0.6)
    grey = s.ellipse_mask(17, 15, 3, 2) & m
    s.tint(grey, hexc('#4a4a3a'), 0.6)
    s.paint(s.rect_mask(4, 9, 16, 1), ramp=P.PORCELAIN, value=0.95)   # plastic glare
    s.paint(s.rect_mask(14, 16, 5, 2), ramp=P.PAPER, value=0.8)       # price sticker
    return finish(s)


def knife():
    s = Sprite(S, S)
    blade = s.poly_mask([(3, 20), (14, 9), (16, 11), (6, 21)])
    s.paint(blade, ramp=P.METAL, value=0.72 + (s.xx - s.yy) * 0.015)
    s.paint(s.line_mask([(4, 20), (14, 10)]), ramp=P.METAL, value=0.95)
    handle = s.poly_mask([(15, 8), (20, 3), (22, 5), (17, 10)])
    s.paint(handle, ramp=P.DARKWOOD, value=0.55)
    s.paint(s.rect_mask(18, 5, 1, 1) | s.rect_mask(20, 4, 1, 1), ramp=P.METAL, value=0.8)
    s.tint(s.rect_mask(5, 16, 5, 4) & blade, hexc('#3a1a10'), 0.45)
    return finish(s)


def backpack():
    s = Sprite(S, S)
    body = s.ellipse_mask(12, 14, 8, 8.5) & ~s.rect_mask(0, 22, 24, 2)
    lit(s, body, P.BACKPACK, 0.55, 0.4)
    flap = s.ellipse_mask(12, 9, 7, 4)
    lit(s, flap, P.BACKPACK, 0.75, 0.35)
    s.paint(s.rect_mask(7, 15, 10, 6) & ~s.rect_mask(8, 16, 8, 4), ramp=P.BACKPACK, value=0.2)
    s.paint(s.rect_mask(11, 12, 2, 3), ramp=P.METAL, value=0.7)
    papers = s.poly_mask([(6, 3), (12, 1), (17, 3), (16, 7), (7, 7)])
    s.paint(papers, ramp=P.NEWSPAPER, value=0.55 + ((s.yy % 2) == 0) * 0.25)
    s.paint(s.rect_mask(8, 4, 6, 1), ramp=P.NEWSPAPER, value=0.15)
    return finish(s)


def key():
    s = Sprite(S, S)
    ring = s.ellipse_mask(7, 9, 5, 5) & ~s.ellipse_mask(7, 9, 2.5, 2.5)
    lit(s, ring, P.BRASS, 0.65, 0.5, cx=7, cy=9, r=5)
    blade = s.rect_mask(11, 8, 10, 3)
    lit(s, blade, P.BRASS, 0.65, 0.3)
    teeth = s.rect_mask(15, 11, 2, 2) | s.rect_mask(18, 11, 1, 3) | s.rect_mask(20, 11, 1, 2)
    s.paint(teeth, ramp=P.BRASS, value=0.45)
    tag = s.poly_mask([(3, 13), (8, 14), (7, 21), (2, 20)])
    s.paint(tag, ramp=P.PAPER, value=0.7)
    s.paint(s.rect_mask(4, 16, 3, 1) | s.rect_mask(4, 18, 2, 1), ramp=P.PAPER, value=0.15)
    return finish(s)


def phone():
    s = Sprite(S, S)
    body = s.rect_mask(7, 2, 10, 20)
    s.paint(body, ramp=P.PHONE, value=0.6)
    scr = s.rect_mask(8, 4, 8, 15)
    s.paint(scr, color=hexc('#1c3456'))
    s.paint(s.rect_mask(9, 5, 6, 2), color=hexc('#4a7ac0'))
    s.paint(s.rect_mask(9, 9, 6, 3), color=hexc('#2c4c7a'))
    s.paint(s.rect_mask(14, 9, 1, 1), color=hexc('#d04040'))     # unread badge
    crack = s.line_mask([(9, 18), (12, 13), (11, 11), (15, 6)])
    s.paint(crack & scr, color=hexc('#9ab0c8'))
    s.paint(s.rect_mask(11, 20, 2, 1), ramp=P.PHONE, value=1.0)
    return finish(s)


def lock():
    s = Sprite(S, S)
    shackle = s.ellipse_mask(12, 9, 6, 6) & ~s.ellipse_mask(12, 9, 3.6, 3.6) & (s.yy < 11)
    shackle &= ~s.rect_mask(14, 2, 6, 4)          # snapped
    lit(s, shackle, P.METAL, 0.6, 0.4)
    s.paint(s.rect_mask(17, 6, 2, 1), ramp=P.METAL, value=0.9)
    s.paint(s.rect_mask(16, 2, 2, 2), ramp=P.METAL, value=0.4)
    body = s.rect_mask(5, 10, 14, 11)
    lit(s, body, P.RUST, 0.6, 0.45)
    s.tint(body & (fbm(S, S, 2, 5, 2) > 0.55), hexc('#6a5040'), 0.4)
    s.paint(s.ellipse_mask(12, 14.5, 1.5, 1.5) | s.rect_mask(11, 15, 2, 3), color=hexc('#0a0604'))
    return finish(s)


def build(outdir):
    for name, fn in (('coin', coin), ('water', water), ('coke', coke), ('meat', meat), ('knife', knife),
                     ('backpack', backpack), ('key', key), ('phone', phone), ('lock', lock)):
        save_icon(fn(), outdir, name)
