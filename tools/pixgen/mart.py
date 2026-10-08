"""Scene 3: the 24/7 MART - store floor, staff room and parking lot cells.
Reuses the apartment room builder and the outdoor ground builder."""
import numpy as np

from . import palette as P
from . import apartment as AP
from . import neighborhood as NB
from . import characters as CH
from .core import Sprite, Ramp, UP, SOUTH, EAST, WEST, fbm, white, hexc, rng, strip, value_noise

VINYL = Ramp(['#3a3c38', '#5c5e58', '#7c7d74', '#96968a', '#acab9c', '#bdbaa8'])
STORE_WALL = Ramp(['#2e3430', '#46504a', '#5e6a62', '#74827a', '#88968c'])
CINDER = Ramp(['#2e2a24', '#443e34', '#5a5244', '#6c6352', '#7c7260'])
POLO = Ramp(['#0e1a12', '#16261b', '#1f3426', '#2a4432', '#36543e'])
COAT = Ramp(['#0a0a0c', '#121216', '#1a1a20', '#24242a'])
RED_HAIR = Ramp(['#3a0806', '#5e1008', '#86200e', '#a83418', '#c44a22'])


# ---------------------------------------------------------------- materials
def floor_vinyl(s, mask):
    xx, yy = s.xx, s.yy
    size = 16
    tv = rng(601).random((s.h // size + 2, s.w // size + 2)).astype(np.float32)
    scuff = fbm(s.w, s.h, 10, 602, 4)
    v = 0.72 + (tv[yy // size, xx // size] - 0.5) * 0.08 - scuff * 0.3
    seam = ((xx % size) == 0) | ((yy % size) == 0)
    v = np.where(seam, v - 0.2, v)
    # a worn path from the door to the counter
    path = np.exp(-(((xx - 400) / 60.0) ** 2)) * np.clip((yy - 150) / 120.0, 0, 1)
    v = v - path * 0.12
    s.paint(mask, ramp=VINYL, value=v, normal=UP, height=0)
    s.bump(mask, seam.astype(np.float32) * -1, 0.4)
    marks = (white(s.w, s.h, 603) > 0.997) & mask
    s.paint(marks, ramp=VINYL, value=0.1, height=0)


def face_store(s, mask, top):
    rel = s.yy - top
    v = 0.55 + (fbm(s.w, s.h, 14, 604, 3) - 0.5) * 0.2
    s.paint(mask, ramp=STORE_WALL, value=v, normal=SOUTH)
    s.paint(mask & (rel >= 26), ramp=P.PLASTIC_BLK, value=0.45, normal=SOUTH)          # kick plate
    s.paint(mask & (rel == 25), ramp=P.METAL, value=0.7, normal=SOUTH)
    s.paint(mask & (rel < 3), ramp=STORE_WALL, value=0.1, normal=SOUTH)


def floor_concrete(s, mask):
    v = 0.45 + (fbm(s.w, s.h, 12, 611, 4) - 0.5) * 0.4 + (white(s.w, s.h, 612) - 0.5) * 0.15
    s.paint(mask, ramp=P.CONCRETE, value=v, normal=UP, height=0)
    stain = (fbm(s.w, s.h, 8, 613, 3) > 0.68) & mask
    s.tint(stain, hexc('#1a1208'), 0.4)


def face_cinder(s, mask, top):
    xx, yy = s.xx, s.yy
    rel = yy - top
    row = rel // 6
    off = (row % 2) * 6
    joint = ((rel % 6) == 0) | (((xx + off) % 12) == 0)
    v = 0.55 + (fbm(s.w, s.h, 6, 614, 3) - 0.5) * 0.25
    s.paint(mask, ramp=CINDER, value=np.where(joint, v - 0.25, v), normal=SOUTH)
    s.bump(mask, joint.astype(np.float32) * -1, 0.5)
    s.paint(mask & (rel < 3), ramp=CINDER, value=0.1, normal=SOUTH)
    damp = (value_noise(s.w, s.h, 1, 615, sx=5, sy=20) > 0.7) & mask & (rel > 12)
    s.tint(damp, hexc('#14100a'), 0.45)


def floor_glass_door(s, mask):
    s.paint(mask, ramp=P.GLASS_DARK, value=0.35 + (s.xx % 16 == 0) * -0.3, normal=UP, height=2)
    edge = mask & ((s.yy % 16) < 2)
    s.paint(edge, ramp=P.METAL, value=0.6, normal=UP, height=4)


# ---------------------------------------------------------------- store props
def cooler(seed):
    """Glass-door drinks cooler against the back wall (48 wide)."""
    s = Sprite(48, 52)
    s.box(0, 0, 48, 10, 42, P.METAL, P.METAL, 0.5, 0.45)
    r = rng(seed)
    for d in range(3):
        dx = 2 + d * 15
        glass = s.rect_mask(dx, 12, 14, 36)
        s.paint(glass, color=hexc('#a8c0b8') * 0.55, normal=SOUTH)
        s.em[glass] = hexc('#a0c4bc') * 0.55
        for sh in range(4):
            sy = 14 + sh * 9
            for bx in range(dx + 1, dx + 13, 3):
                col = hexc(['#b03028', '#2860a8', '#d0c040', '#309050', '#e08030', '#d8d8d8'][r.integers(0, 6)])
                b = s.rect_mask(bx, sy, 2, 6) & glass
                s.paint(b, color=col * 0.7)
                s.em[b] = col * 0.45
            s.paint(s.rect_mask(dx, sy + 7, 14, 1) & glass, ramp=P.METAL, value=0.8)
        s.paint(s.rect_mask(dx + 12, 26, 1, 8), ramp=P.METAL, value=0.9)        # handle
        s.paint(s.rect_mask(dx - 1, 12, 1, 36), ramp=P.METAL, value=0.3)
    s.paint(s.rect_mask(0, 48, 48, 4), ramp=P.PLASTIC_BLK, value=0.5)
    s.outline(0.6)
    return s


def shelf(seed, w=96):
    """Gondola shelf running east-west, products on the visible front."""
    s = Sprite(w, 46)
    s.box(0, 0, w, 14, 30, P.METAL, P.METAL, 0.55, 0.4)
    r = rng(seed)
    cols = ['#a83a28', '#c8a038', '#3a6aa0', '#3a8a50', '#d0d0c0', '#8a3a7a', '#c86a28']
    for row in range(3):
        sy = 16 + row * 10
        s.paint(s.rect_mask(0, sy + 8, w, 1), ramp=P.METAL, value=0.75, normal=UP)
        x = 1
        while x < w - 2:
            pw = int(r.integers(2, 6))
            ph = int(r.integers(4, 8))
            if r.random() < 0.12:
                x += pw + 1          # gaps where stock ran out
                continue
            c = hexc(cols[r.integers(0, len(cols))])
            m = s.rect_mask(x, sy + 8 - ph, pw, ph)
            s.paint(m, color=c * (0.55 + r.random() * 0.25), normal=SOUTH)
            s.paint(s.rect_mask(x, sy + 8 - ph, pw, 1), color=np.minimum(1, c * 0.95))
            x += pw
        tags = s.rect_mask(2, sy + 9, w - 4, 1) & ((s.xx % 12) < 3)
        s.paint(tags, color=hexc('#d8d0a0'))
    # stock boxes on top
    for i in range(int(w // 30)):
        bx = 4 + i * 30 + int(r.integers(0, 10))
        s.box(bx, 2, 14, 8, 4, P.CARDBOARD, P.CARDBOARD, 0.6, 0.4, base=30)
    s.outline(0.6)
    return s


def counter():
    """Checkout counter: register, lottery stand, gum racks on the front."""
    s = Sprite(112, 44)
    s.box(0, 14, 112, 16, 18, Ramp.from_base('#4a4840', 5), P.LAMINATE, 0.55, 0.42)
    # front racks of candy
    r = rng(621)
    for x in range(4, 108, 4):
        for row in range(2):
            c = hexc(['#c03a2a', '#d8b030', '#3a7ac0', '#40a060', '#e0e0d0'][r.integers(0, 5)])
            s.paint(s.rect_mask(x, 33 + row * 5, 3, 3), color=c * 0.6, normal=SOUTH)
    # register
    s.box(70, 8, 22, 12, 10, P.PLASTIC_BLK, P.PLASTIC_BLK, 0.5, 0.4, base=18)
    disp = s.rect_mask(73, 20, 10, 4)
    s.paint(disp, color=hexc('#1a4a2a'))
    s.em[disp] = hexc('#40ff80') * 0.6
    s.paint(s.rect_mask(84, 20, 6, 6) & ((s.xx + s.yy) % 2 == 0), ramp=P.METAL, value=0.6)
    # lottery stand + card reader
    s.box(20, 4, 18, 8, 14, Ramp.from_base('#6a2a2a', 5), Ramp.from_base('#6a2a2a', 5), 0.5, 0.45, base=18)
    s.paint(s.rect_mask(22, 14, 14, 8) & ((s.yy % 3) != 0), color=hexc('#d8c070') * 0.6)
    s.box(50, 18, 8, 6, 4, P.PLASTIC_BLK, P.PLASTIC_BLK, 0.5, 0.5, base=18)
    s.em[s.rect_mask(52, 27, 3, 1)] = hexc('#40ff60') * 0.8
    s.outline(0.6)
    return s


def side_counter():
    """Coffee machine and hot dog roller on a counter along the east wall."""
    s = Sprite(24, 100)
    s.box(0, 6, 24, 76, 18, Ramp.from_base('#4a4840', 5), P.LAMINATE, 0.55, 0.42)
    # coffee machine
    s.box(3, 6, 18, 14, 16, P.PLASTIC_BLK, P.PLASTIC_BLK, 0.4, 0.4, base=18)
    s.em[s.rect_mask(6, 8, 2, 1) | s.rect_mask(14, 8, 2, 1)] = hexc('#ff3020')
    s.cylinder(8, 22, 3, 3, 5, P.GLASS_DARK, Ramp.from_base('#3a2010', 4), base=18)
    # hot dog roller (warm glow)
    roll = s.rect_mask(3, 40, 18, 20)
    s.paint(roll, ramp=P.METAL, value=0.6, normal=UP, height=21)
    for k in range(6):
        hd = s.rect_mask(5, 42 + k * 3, 14, 2)
        s.paint(hd, ramp=Ramp.from_base('#9a4a2a', 5), value=0.55 + (k % 2) * 0.2, height=22)
        s.em[hd] = hexc('#4a2010') * 0.8
    s.em[roll & ~s.rect_mask(5, 42, 14, 18)] = hexc('#603018') * 0.6
    # napkins, cups
    s.box(4, 64, 8, 6, 6, P.PAPER, P.PAPER, 0.8, 0.6, base=18)
    s.cylinder(17, 66, 3, 3, 7, P.PORCELAIN, P.PORCELAIN, base=18)
    s.outline(0.6)
    return s


def magazine_rack():
    s = Sprite(40, 28)
    s.box(0, 4, 40, 6, 18, P.METAL, P.METAL, 0.5, 0.35)
    r = rng(631)
    for row in range(3):
        for k in range(5):
            c = hexc(['#c04a3a', '#3a5a9a', '#d0c060', '#e0e0e0', '#5a3a6a'][r.integers(0, 5)])
            s.paint(s.rect_mask(2 + k * 8, 11 + row * 6, 6, 5), color=c * 0.6, normal=SOUTH)
    s.outline(0.6)
    return s


def atm():
    s = Sprite(18, 38)
    s.box(0, 0, 18, 8, 30, P.METAL, Ramp.from_base('#2a3a5a', 5), 0.5, 0.45)
    scr = s.rect_mask(4, 11, 10, 7)
    s.paint(scr, color=hexc('#2a5a8a'))
    s.em[scr] = hexc('#5aa0e0') * 0.8
    s.paint(s.rect_mask(4, 21, 10, 5) & ((s.xx + s.yy) % 2 == 0), ramp=P.METAL, value=0.7)
    s.paint(s.rect_mask(5, 28, 8, 1), color=hexc('#050505'))
    s.outline(0.6)
    return s


def staff_door():
    """Grey metal door set into the back wall, STAFF ONLY sign."""
    s = Sprite(28, 34)
    s.paint(s.rect_mask(0, 0, 28, 34), ramp=P.METAL, value=0.3, normal=SOUTH)
    d = s.rect_mask(2, 2, 24, 32)
    s.paint(d, ramp=P.METAL, value=0.5 + (s.xx - 2) * -0.006, normal=SOUTH)
    s.paint(s.rect_mask(20, 18, 3, 2), ramp=P.METAL, value=0.9)
    sign = s.rect_mask(3, 6, 22, 9)
    s.paint(sign, color=hexc('#c8c0a0'))
    for m in NB.text_masks(s, "STAFF", 4, 7, 1):
        s.paint(m, color=hexc('#8a1a1a'))
    s.paint(s.rect_mask(5, 13, 18, 1), color=hexc('#3a3a3a'))
    s.billboard_height(None, base=0, bottom=33)
    return s


def wet_floor_sign():
    s = Sprite(10, 14)
    m = s.poly_mask([(5, 0), (9, 13), (1, 13)])
    s.paint(m, ramp=Ramp.from_base('#c8a020', 5), value=0.6 - (s.xx - 5) * 0.05, normal=SOUTH)
    s.paint(s.rect_mask(4, 6, 2, 4), color=hexc('#202020'))
    s.billboard_height(None, bottom=13)
    s.outline(0.6)
    return s


def mop_bucket():
    s = Sprite(16, 30)
    s.box(1, 16, 14, 8, 6, Ramp.from_base('#c8a020', 5), Ramp.from_base('#c8a020', 5), 0.6, 0.45)
    s.paint(s.rect_mask(3, 17, 10, 6), color=hexc('#3a3a28'), height=5)
    s.paint(s.line_mask([(8, 18), (11, 0)]), ramp=P.DARKWOOD, value=0.5, normal=SOUTH)
    s.billboard_height(s.line_mask([(8, 18), (11, 0)]), bottom=29)
    s.outline(0.6)
    return s


def flyer():
    s = Sprite(9, 11)
    m = s.rect_mask(0, 0, 9, 11)
    s.paint(m, ramp=P.PAPER, value=0.75, normal=SOUTH, height=12)
    s.paint(s.ellipse_mask(4.5, 4, 2, 2.2), color=hexc('#2a2a2a'), height=12)
    s.paint(s.rect_mask(1, 8, 7, 1), color=hexc('#3a1a1a'), height=12)
    s.em[m] = hexc('#20201c')
    return s


# ---------------------------------------------------------------- staff room props
def desk_laptop():
    s = Sprite(40, 38)
    s.box(0, 12, 40, 12, 14, P.LAMINATE, P.LAMINATE, 0.5, 0.35)
    s.paint(s.rect_mask(3, 25, 34, 12) & ~s.rect_mask(3, 25, 34, 1), color=hexc('#060505'), normal=SOUTH, height=0)
    s.paint(s.rect_mask(0, 24, 3, 14) | s.rect_mask(37, 24, 3, 14), ramp=P.LAMINATE, value=0.35, normal=SOUTH)
    # laptop: open lid with a glowing screen
    s.paint(s.rect_mask(12, 12, 16, 5), ramp=P.PLASTIC_BLK, value=0.5, normal=UP, height=15)          # base
    lid = s.rect_mask(12, 2, 16, 10)
    s.paint(lid, ramp=P.PLASTIC_BLK, value=0.4, normal=SOUTH, height=24)
    scr = s.rect_mask(13, 3, 14, 8)
    s.paint(scr, color=hexc('#4a6a9a'))
    s.em[scr] = hexc('#7a9ad0')
    s.em[s.rect_mask(14, 4, 6, 1) | s.rect_mask(14, 6, 9, 1) | s.rect_mask(14, 8, 4, 1)] = hexc('#e0e8f0')
    s.hgt[scr] = 24
    # energy drink cans, crumpled receipts
    s.cylinder(34, 13, 1.5, 2, 4, P.METAL, Ramp.from_base('#2a6a3a', 5), base=14)
    s.cylinder(5, 15, 1.5, 2, 4, P.METAL, Ramp.from_base('#2a6a3a', 5), base=14)
    s.paint(s.rect_mask(2, 19, 5, 2), ramp=P.PAPER, value=0.7, height=15)
    s.outline(0.6)
    return s


def pasta():
    s = Sprite(9, 7)
    s.box(0, 1, 9, 4, 2, P.PORCELAIN, P.PORCELAIN, 0.7, 0.5)
    sauce = s.rect_mask(1, 1, 7, 3)
    s.paint(sauce, ramp=Ramp.from_base('#a8582a', 5), value=0.5 + (white(9, 7, 641) - 0.5) * 0.5, height=3)
    s.paint(s.rect_mask(6, 0, 1, 3), ramp=P.METAL, value=0.8, height=4)          # fork
    s.outline(0.7)
    return s


def lockers():
    s = Sprite(40, 52)
    s.box(0, 0, 40, 10, 42, P.METAL, Ramp.from_base('#4a5a5a', 5), 0.55, 0.45)
    for k in range(3):
        x = 1 + k * 13
        s.paint(s.rect_mask(x + 12, 11, 1, 41), color=hexc('#101010'))
        for v in range(4):
            s.paint(s.rect_mask(x + 3, 14 + v * 2, 7, 1), color=hexc('#1a2020'))
        s.paint(s.rect_mask(x + 9, 30, 2, 3), ramp=P.METAL, value=0.85)
        s.paint(s.rect_mask(x + 3, 24, 6, 3), ramp=P.PAPER, value=0.75)               # name strip
    s.outline(0.6)
    return s


def cot():
    """A camping cot with a sleeping bag. He sleeps here sometimes."""
    s = Sprite(56, 26)
    s.box(0, 4, 56, 16, 6, Ramp.from_base('#3a4a3a', 5), P.METAL, 0.5, 0.4)
    bag = s.rect_mask(4, 5, 44, 13)
    n = fbm(56, 26, 3, 651, 3)
    s.paint(bag, ramp=Ramp.from_base('#3a3a6a', 5), value=0.35 + n * 0.45, normal=UP, height=9)
    s.bump(bag, n, 2.5)
    s.paint(s.ellipse_mask(50, 11, 5, 4), ramp=P.FABRIC_SHEET, value=0.6, height=10)     # pillow
    s.pillow_normals(bag | s.ellipse_mask(50, 11, 5, 4), 1.0)
    s.outline(0.6)
    return s


def mini_fridge():
    s = Sprite(18, 28)
    s.box(0, 0, 18, 8, 20, P.WHITE_APPL, P.WHITE_APPL, 0.55, 0.45)
    s.paint(s.rect_mask(14, 12, 2, 5), ramp=P.METAL, value=0.8)
    s.cylinder(6, -1, 2, 2, 5, P.METAL, P.COKE_RED, base=20)
    s.outline(0.6)
    return s


def boxes():
    s = Sprite(34, 40)
    s.box(0, 18, 20, 12, 10, P.CARDBOARD, P.CARDBOARD, 0.6, 0.45)
    s.box(14, 16, 20, 12, 12, P.CARDBOARD, P.CARDBOARD, 0.55, 0.4)
    s.box(3, 6, 18, 12, 10, P.CARDBOARD, P.CARDBOARD, 0.7, 0.5, base=10)
    s.paint(s.rect_mask(5, 22, 10, 1) | s.rect_mask(18, 30, 10, 1), ramp=P.PAPER, value=0.2)
    s.outline(0.6)
    return s


def note():
    s = Sprite(7, 6)
    m = s.poly_mask([(0, 1), (6, 0), (6, 5), (1, 5)])
    s.paint(m, ramp=P.PAPER, value=0.9, normal=SOUTH, height=14)
    s.paint(s.rect_mask(1, 2, 4, 1), color=hexc('#202020'), height=14)
    s.em[m] = hexc('#24221c')
    return s


def poster_pinup(s, x, y, w=16, h=22):
    """Old pin-up poster on the staff room wall (baked into the background)."""
    m = s.rect_mask(x, y, w, h) & ~s.poly_mask([(x + w - 4, y), (x + w, y), (x + w, y + 5)])
    s.paint(m, color=hexc('#4a6a8a') * 0.7, normal=SOUTH)
    s.paint(s.rect_mask(x, y + h - 7, w, 7) & m, color=hexc('#c8b070') * 0.6, normal=SOUTH)       # sand
    body = s.ellipse_mask(x + w * 0.5, y + 5, 2, 2.3) | s.poly_mask([(x + 6, y + 7), (x + 10, y + 7), (x + 11, y + 17), (x + 5, y + 17)])
    s.paint(body & m, ramp=P.SKIN, value=0.75, normal=SOUTH)
    s.paint(s.rect_mask(x + 6, y + 9, 4, 2) & m | s.rect_mask(x + 6, y + 13, 4, 2) & m, color=hexc('#a02020'))
    s.paint(s.ellipse_mask(x + w * 0.5, y + 4, 3, 2) & m, color=hexc('#d0a040'))        # hair
    s.paint(s.rect_mask(x - 1, y - 1, 3, 2) | s.rect_mask(x + w - 2, y + h - 1, 3, 2), ramp=P.PAPER, value=0.95, normal=SOUTH)


# ---------------------------------------------------------------- lot props
def car_running():
    """The car with its engine running, headlights on, facing east."""
    s = NB.car_h(P.CAR_GRAY, 661)
    head = s.rect_mask(45, 24, 5, 3)
    s.paint(head, color=hexc('#f0f0d8'))
    s.em[head] = hexc('#ffffe8')
    tail = s.rect_mask(0, 24, 3, 3)
    s.paint(tail, color=hexc('#a01010'))
    s.em[tail] = hexc('#ff2010') * 0.8
    # driver's door hanging open
    door = s.rect_mask(22, 26, 10, 7)
    s.paint(door, ramp=P.CAR_GRAY, value=0.3, normal=(0.3, 0.8, 0.4))
    s.em[s.rect_mask(23, 21, 6, 3)] = hexc('#d0c090') * 0.35       # dome light inside
    return s


def woman_down():
    """Face down on the asphalt, head to the east, one arm reaching forward."""
    s = Sprite(38, 16)
    R = s.rect_mask
    legs = R(1, 7, 12, 3) | R(1, 10, 11, 3)
    s.paint(legs, ramp=COAT, value=0.5, normal=UP, height=3)
    s.paint(R(0, 7, 2, 3) | R(0, 10, 2, 3), ramp=P.SHOE, value=0.3, height=3)
    coat = s.ellipse_mask(19, 9, 9, 5)
    s.paint(coat, ramp=COAT, value=0.45 + (white(38, 16, 671) - 0.5) * 0.3, normal=UP, height=5)
    arm = R(24, 2, 9, 2)
    s.paint(arm, ramp=COAT, value=0.55, height=3)
    s.paint(R(33, 2, 2, 2), ramp=P.SKIN, value=0.7, height=3)
    s.paint(R(25, 12, 6, 2), ramp=COAT, value=0.5, height=3)
    hair = s.ellipse_mask(31, 9, 4.5, 4) | s.ellipse_mask(34, 7, 3, 2.5) | s.ellipse_mask(35, 11, 3, 2.5)
    s.paint(hair, ramp=RED_HAIR, value=0.45 + (white(38, 16, 672) - 0.5) * 0.6, normal=UP, height=5)
    s.pillow_normals(None, 1.0)
    s.outline(0.55)
    return s


def cart():
    s = Sprite(24, 22)
    basket = s.rect_mask(2, 2, 20, 12)
    grid_ = basket & ((((s.xx) % 3) == 0) | (((s.yy) % 3) == 0))
    s.paint(grid_, ramp=P.METAL, value=0.6, normal=UP, height=12)
    s.paint(s.rect_mask(2, 14, 20, 1) | s.rect_mask(0, 2, 2, 12), ramp=P.METAL, value=0.75, height=12)
    s.paint(s.rect_mask(3, 19, 2, 2) | s.rect_mask(19, 19, 2, 2), ramp=P.TIRE, value=0.5, height=2)
    s.paint(s.line_mask([(4, 15), (4, 19)]) | s.line_mask([(20, 15), (20, 19)]), ramp=P.METAL, value=0.5, height=6)
    return s


def vincent_sheet():
    frames = [CH.front(0, shirt=POLO, bald=True, polo=True), CH.front(0, breathe=1, shirt=POLO, bald=True, polo=True)]
    return strip(frames)


# ---------------------------------------------------------------- build
def build_store(grid_path):
    grid = AP.load_grid(grid_path)
    bg = AP.build_background(grid, floor_fns={'m': floor_vinyl, 'G': floor_glass_door}, face_fns={'m': face_store})
    # price banner along the back wall
    for x in range(40, 470, 70):
        b = bg.rect_mask(x, 20, 40, 6)
        bg.paint(b, color=hexc('#8a2a20') * 0.8, normal=SOUTH)
        bg.paint(b & ((bg.xx % 4) == 1) & (bg.yy == 22), color=hexc('#e0d0b0'))
    return bg


def build_staff(grid_path):
    grid = AP.load_grid(grid_path)
    bg = AP.build_background(grid, floor_fns={'f': floor_concrete}, face_fns={'f': face_cinder})
    poster_pinup(bg, 160, 20)
    AP.decor_switch(bg, 40, 32)
    AP.litter(bg, (30, 120, 180, 40), 14, 681, ('paper', 'can', 'stain', 'crumb'))
    return bg


def build_lot(grid_path):
    grid = NB.load_grid(grid_path)
    bg = NB.build_ground(grid, markings=False)
    # parking stalls
    xx, yy = bg.xx, bg.yy
    for row_y in (150, 330):
        lines = ((xx - 40) % 48 == 0) & (yy >= row_y) & (yy < row_y + 56) & (xx > 30) & (xx < 770)
        bg.paint(lines & (fbm(bg.w, bg.h, 6, 691, 3) > 0.3), ramp=P.LINE_PAINT, value=0.4, normal=UP, height=0)
    return bg


def build(map_dir):
    import os
    store = build_store(os.path.join(map_dir, 'mart_store.txt'))
    staff = build_staff(os.path.join(map_dir, 'mart_staff.txt'))
    lot = build_lot(os.path.join(map_dir, 'mart_lot.txt'))
    props = {
        'cooler_a': cooler(701), 'cooler_b': cooler(702), 'cooler_c': cooler(703),
        'shelf_a': shelf(711), 'shelf_b': shelf(712), 'shelf_c': shelf(713), 'shelf_d': shelf(714),
        'counter': counter(), 'side_counter': side_counter(), 'magazine_rack': magazine_rack(),
        'atm': atm(), 'staff_door': staff_door(), 'wet_floor': wet_floor_sign(), 'mop_bucket': mop_bucket(),
        'flyer': flyer(),
        'desk_laptop': desk_laptop(), 'pasta': pasta(), 'lockers': lockers(), 'cot': cot(),
        'mini_fridge': mini_fridge(), 'boxes': boxes(), 'note': note(),
        'car_running': car_running(), 'woman_down': woman_down(), 'cart': cart(),
        'vincent': vincent_sheet(),
    }
    return {'store_bg': store, 'staff_bg': staff, 'lot_bg': lot}, props
