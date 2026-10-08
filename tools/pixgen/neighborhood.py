"""Scene 2: Alder Street at 2AM. Ground from maps/neighborhood.txt plus all
outdoor props (buildings, school gate, store, dealership, lamps, cars...)."""
import numpy as np
from scipy import ndimage

from . import palette as P
from .core import (Sprite, Ramp, UP, SOUTH, EAST, WEST, fbm, value_noise, white, hexc, mix, rng, strip)

T = 16


def load_grid(path):
    with open(path) as f:
        return [line.rstrip('\n') for line in f if line.strip()]


# ===========================================================================
# ground
# ===========================================================================
def build_ground(grid, markings=True):
    H, W = len(grid), len(grid[0])
    g = np.array([list(r) for r in grid])
    s = Sprite(W * T, H * T)
    s.a[:] = True
    tile = np.repeat(np.repeat(g, T, 0), T, 1)
    xx, yy = s.xx, s.yy
    w, h = s.w, s.h
    big = fbm(w, h, 90, 1, 3)

    # --- asphalt (roads + parking) -----------------------------------------
    road = (tile == 'r') | (tile == 'p')
    grain = white(w, h, 2)
    grain = ndimage.uniform_filter(grain, 2)
    mid = fbm(w, h, 20, 3, 4)
    v = 0.42 + (grain - 0.5) * 0.45 + (mid - 0.5) * 0.35 + (big - 0.5) * 0.2
    # patched repairs
    patch = (fbm(w, h, 26, 4, 2) > 0.7)
    v = np.where(patch, v - 0.12, v)
    s.paint(road, ramp=P.ASPHALT, value=v, normal=UP, height=0)
    s.bump(road, grain, 0.9)
    # cracks: thin random-walk lines
    r = rng(5)
    cracks = np.zeros((h, w), bool)
    for _ in range(140):
        x, y = r.integers(0, w), r.integers(0, h)
        if not road[y, x]:
            continue
        ang = r.random() * np.pi * 2
        for _ in range(r.integers(10, 50)):
            ang += (r.random() - 0.5) * 0.9
            x = int(np.clip(x + np.cos(ang) * 1.4, 0, w - 1))
            y = int(np.clip(y + np.sin(ang) * 1.4, 0, h - 1))
            cracks[y, x] = True
    cracks &= road
    s.shade(cracks, 0.45)
    oil = (fbm(w, h, 9, 6, 3) > 0.72) & road
    s.tint(oil, hexc('#06070a'), 0.45)

    wear = fbm(w, h, 6, 7, 3)
    if markings:
        # --- lane markings --------------------------------------------------------
        # horizontal road y 480..560 (center 520), vertical road x 608..688 (center 648)
        inter = (xx >= 576) & (xx < 720) & (yy >= 448) & (yy < 592)
        dash_h = (yy >= 519) & (yy <= 520) & ((xx % 24) < 13) & ~inter & (tile == 'r')
        dash_v = (xx >= 647) & (xx <= 648) & ((yy % 24) < 13) & ~inter & (tile == 'r')
        paint_mask = (dash_h | dash_v) & (wear > 0.32)
        s.paint(paint_mask, ramp=P.YELLOW_PAINT, value=0.3 + wear * 0.6, normal=UP, height=0)
        # stop lines + zebra crosswalks on each arm of the intersection
        zebra = np.zeros((h, w), bool)
        zebra |= (xx >= 608) & (xx < 688) & (yy >= 452) & (yy < 476) & (((xx - 608) % 10) < 5)   # north arm
        zebra |= (xx >= 608) & (xx < 688) & (yy >= 564) & (yy < 588) & (((xx - 608) % 10) < 5)   # south arm
        zebra |= (yy >= 480) & (yy < 560) & (xx >= 580) & (xx < 604) & (((yy - 480) % 10) < 5)   # west arm
        zebra |= (yy >= 480) & (yy < 560) & (xx >= 692) & (xx < 716) & (((yy - 480) % 10) < 5)   # east arm
        zebra &= road & (wear > 0.28)
        s.paint(zebra, ramp=P.LINE_PAINT, value=0.25 + wear * 0.55, normal=UP, height=0)
        # parking stalls
        stall = (tile == 'p') & (((xx - 384) % 40) == 0) & ((yy % 192) > 40) & ((yy % 192) < 120) & (yy > 780)
        stall |= (tile == 'p') & (yy == 796) & (xx % 40 < 41)
        s.paint(stall & (wear > 0.3), ramp=P.LINE_PAINT, value=0.45, normal=UP, height=0)

    # --- sidewalks -----------------------------------------------------------
    side = tile == 's'
    slab = 16
    sv = 0.5 + (white(w, h, 8) - 0.5) * 0.25 + (fbm(w, h, 10, 9, 3) - 0.5) * 0.3
    tv = rng(10).random((h // slab + 2, w // slab + 2)).astype(np.float32)
    sv = sv + (tv[yy // slab, xx // slab] - 0.5) * 0.18
    joint = ((xx % slab) == 0) | ((yy % slab) == 0)
    sv = np.where(joint, 0.12, sv)
    s.paint(side, ramp=P.CONCRETE, value=sv, normal=UP, height=2)
    s.bump(side, joint.astype(np.float32) * -1, 0.6)
    gum = (white(w, h, 11) > 0.996) & side
    s.paint(gum, ramp=P.CONCRETE, value=0.1, height=2)
    weeds = (white(w, h, 12) > 0.985) & side & joint
    s.paint(weeds, ramp=P.DEAD_GRASS, value=0.7, height=3)

    # --- plaza / aprons (larger slabs) ------------------------------------------
    plaza = tile == 'c'
    pv = 0.55 + (fbm(w, h, 12, 13, 3) - 0.5) * 0.4
    pj = ((xx % 32) == 0) | ((yy % 32) == 0)
    pv = np.where(pj, 0.15, pv)
    s.paint(plaza, ramp=P.CONCRETE, value=pv, normal=UP, height=2)

    # --- grass / dirt ----------------------------------------------------------
    grass = tile == 'g'
    gn = white(w, h, 14)
    gv = 0.35 + (fbm(w, h, 14, 15, 4) - 0.5) * 0.5 + (gn - 0.5) * 0.35
    s.paint(grass, ramp=P.DEAD_GRASS, value=gv, normal=UP, height=0)
    tufts = grass & (gn > 0.93)
    s.paint(tufts, ramp=P.DEAD_GRASS, value=0.95, height=2)
    dirtp = grass & (fbm(w, h, 24, 16, 3) > 0.66)
    s.paint(dirtp, ramp=P.DIRT, value=0.45 + (gn - 0.5) * 0.4, height=0)
    s.bump(grass, gn, 1.2)

    yard = (tile == 'd') | ((tile == '#') & (yy < 9 * T + 1))
    dv = 0.45 + (fbm(w, h, 10, 17, 4) - 0.5) * 0.4 + (white(w, h, 18) - 0.5) * 0.25
    s.paint(yard, ramp=P.DIRT, value=dv, normal=UP, height=0)
    gravel = yard & (white(w, h, 19) > 0.95)
    s.paint(gravel, ramp=P.CONCRETE, value=0.5, height=1)

    # --- hedges on the map border ---------------------------------------------
    hedge = (tile == '#') & ~yard
    hn = fbm(w, h, 5, 20, 4)
    s.paint(hedge, ramp=P.HEDGE, value=0.2 + hn * 0.7, normal=UP, height=26)
    s.bump(hedge, hn, 4.0)

    # --- curbs: sidewalk edges against road/grass ----------------------------
    raised = side | plaza
    edge = raised & ndimage.binary_dilation(road, structure=np.ones((3, 3)))
    s.paint(edge, ramp=P.CURB, value=0.75, normal=UP, height=3)
    gutter = road & ndimage.binary_dilation(raised, iterations=2)
    s.shade(gutter, 0.7)
    # contact shading where ground meets hedges
    s.ao_floor(hedge, radius=8, strength=0.5)

    # --- manholes, drains, puddles, litter ----------------------------------
    if markings:
        for cx, cy in ((560, 506), (760, 534), (648, 300), (648, 700), (1010, 520), (220, 500)):
            m = s.ellipse_mask(cx, cy, 7, 5)
            s.paint(m, ramp=P.IRON, value=0.45 + ((s.xx + s.yy) % 3 == 0) * 0.25, normal=UP, height=0)
            s.paint(m & ~s.ellipse_mask(cx, cy, 6, 4), ramp=P.IRON, value=0.1)
        for dx in range(40, 1280, 160):
            for dy in (482, 554):
                s.paint(s.rect_mask(dx, dy, 10, 3), ramp=P.IRON, value=0.2, normal=UP)
                s.paint(s.rect_mask(dx + 1, dy + 1, 8, 1) & ((s.xx % 2) == 0), color=hexc('#020203'))
    rp = rng(21)
    for _ in range(26):
        x, y = rp.integers(0, w), rp.integers(144, h)
        if road[y, x] or side[y, x]:
            m = s.ellipse_mask(x, y, 4 + rp.random() * 10, 2 + rp.random() * 4)
            m &= (fbm(w, h, 4, 22, 2) > 0.4)
            s.paint(m & (road | side), color=hexc('#0b0d10'), normal=(0, 0, 1), height=0)
            # wet edge catches light
            s.n[m] = np.array([0, 0.25, 1]) / np.linalg.norm([0, 0.25, 1])
    for _ in range(140):
        x, y = rp.integers(0, w), rp.integers(144, h)
        if grass[y, x] or side[y, x] or road[y, x]:
            k = rp.integers(0, 3)
            if k == 0:
                s.paint(s.rect_mask(x, y, 3, 2), ramp=P.PAPER, value=0.3 + rp.random() * 0.4, height=1)
            elif k == 1:
                s.paint(s.rect_mask(x, y, 2, 2), ramp=Ramp.from_base('#5a3a1a', 4), value=0.5, height=1)   # leaves
            else:
                s.paint(s.rect_mask(x, y, 3, 1), ramp=P.METAL, value=0.5, height=1)

    if markings:
        # --- schoolyard hopscotch -------------------------------------------------
        hx, hy = 520, 96
        for i, (ox, oy) in enumerate([(0, 0), (0, -8), (-5, -16), (5, -16), (0, -24), (-5, -32), (5, -32)]):
            m = s.rect_mask(hx + ox, hy + oy, 8, 7) & ~s.rect_mask(hx + ox + 1, hy + oy + 1, 6, 5)
            s.paint(m & (wear > 0.35), ramp=P.LINE_PAINT, value=0.35, height=0)
    return s


FONT = {
    '2': ["111", "001", "111", "100", "111"], '4': ["101", "101", "111", "001", "001"],
    '/': ["001", "001", "010", "100", "100"], '7': ["111", "001", "001", "010", "010"],
    'M': ["10001", "11011", "10101", "10001", "10001"], 'A': ["010", "101", "111", "101", "101"],
    'R': ["110", "101", "110", "101", "101"], 'T': ["111", "010", "010", "010", "010"],
    'U': ["101", "101", "101", "101", "111"], 'O': ["111", "101", "101", "101", "111"],
    'S': ["111", "100", "111", "001", "111"], 'L': ["100", "100", "100", "100", "111"],
    'E': ["111", "100", "110", "100", "111"], 'F': ["111", "100", "110", "100", "100"],
    ' ': ["0", "0", "0", "0", "0"],
}


def text_masks(s, text, x, y, scale=1):
    """One mask per character of `text`, drawn with the 3x5 pixel font."""
    masks = []
    cx = x
    for ch in text:
        glyph = FONT[ch]
        m = np.zeros((s.h, s.w), bool)
        for gy, rowbits in enumerate(glyph):
            for gx, b in enumerate(rowbits):
                if b == '1':
                    m |= s.rect_mask(cx + gx * scale, y + gy * scale, scale, scale)
        masks.append(m)
        cx += (len(glyph[0]) + 1) * scale
    return masks


def text_width(text, scale=1):
    return sum((len(FONT[c][0]) + 1) * scale for c in text) - scale


# ===========================================================================
# building parts
# ===========================================================================
def brick_face(s, mask, top, ramp=P.BRICK, seed=1, bw=8, bh=4):
    xx, yy = s.xx, s.yy
    rel = yy - top
    row = rel // bh
    off = (row % 2) * (bw // 2)
    bx = (xx + off) // bw
    rv = rng(seed).random((400, 400)).astype(np.float32)
    v = 0.45 + (rv[row % 400, bx % 400] - 0.5) * 0.35 + (fbm(s.w, s.h, 6, seed + 1, 3) - 0.5) * 0.3
    mortar = ((rel % bh) == 0) | (((xx + off) % bw) == 0)
    s.paint(mask & ~mortar, ramp=ramp, value=v, normal=SOUTH)
    s.paint(mask & mortar, ramp=P.MORTAR, value=0.4, normal=SOUTH)
    # rain streaks + grime at the base
    streak = value_noise(s.w, s.h, 1, seed + 2, sx=3, sy=40)
    s.tint(mask & (streak > 0.7), hexc('#0a0806'), 0.35)
    s.bump(mask, mortar.astype(np.float32) * -1, 0.5)


def panel_face(s, mask, top, seed=2):
    xx, yy = s.xx, s.yy
    rel = yy - top
    v = 0.5 + (fbm(s.w, s.h, 8, seed, 3) - 0.5) * 0.35
    seams = ((xx % 32) == 0) | ((rel % 30) == 0)
    v = np.where(seams, 0.15, v)
    s.paint(mask, ramp=P.PANEL_CONC, value=v, normal=SOUTH)
    streak = value_noise(s.w, s.h, 1, seed + 2, sx=4, sy=30)
    s.tint(mask & (streak > 0.68), hexc('#0c0c0c'), 0.4)
    s.bump(mask, seams.astype(np.float32) * -1, 0.5)


def roof_top(s, x, y, w, d, height, seed=3, parapet=3):
    m = s.rect_mask(x, y, w, d)
    n = fbm(s.w, s.h, 8, seed, 3)
    s.paint(m, ramp=P.ROOF, value=0.35 + n * 0.35, normal=UP, height=height)
    s.bump(m, n, 1.5)
    inner = s.rect_mask(x + parapet, y + parapet, w - 2 * parapet, d - 2 * parapet)
    par = m & ~inner
    s.paint(par, ramp=P.CONCRETE, value=0.55, normal=UP, height=height + 3)
    s.paint(par & s.rect_mask(x, y + d - 1, w, 1), ramp=P.CONCRETE, value=0.8, height=height + 3)
    s.ao_floor(par | ~m, radius=4, strength=0.4)
    s.a[:] = s.a | m
    r = rng(seed + 1)
    # AC units, vents, a hatch
    for _ in range(max(1, w // 60)):
        ax = int(x + 10 + r.random() * (w - 40))
        ay = int(y + 10 + r.random() * (d - 30))
        s.box(ax, ay, 16, 10, 8, P.METAL, P.METAL, 0.6, 0.45, base=height)
        s.paint(s.ellipse_mask(ax + 8, ay + 5, 4, 3), ramp=P.METAL, value=0.15, height=height + 8)
    for _ in range(max(1, w // 50)):
        vx = int(x + 8 + r.random() * (w - 20))
        vy = int(y + 8 + r.random() * (d - 20))
        s.cylinder(vx, vy, 2, 2, 5, P.METAL, P.METAL, base=height)


def window(s, x, y, w, h, lit=None, curtain=False, seed=0, figure=False):
    frame = s.rect_mask(x - 1, y - 1, w + 2, h + 2)
    s.paint(frame, ramp=P.CONCRETE, value=0.3, normal=SOUTH)
    g = s.rect_mask(x, y, w, h)
    if lit is None:
        v = 0.25 + (s.xx - x) / max(w, 1) * 0.3 - (s.yy - y) / max(h, 1) * 0.15
        s.paint(g, ramp=P.GLASS_DARK, value=v, normal=SOUTH)
        refl = g & (((s.xx - x) + (s.yy - y)) % 9 == 0)
        s.paint(refl, ramp=P.GLASS_DARK, value=1.0)
    else:
        col = hexc(lit)
        s.paint(g, color=col * 0.6, normal=SOUTH)
        grad = 0.75 + 0.25 * (1 - (s.yy - y) / max(h, 1))
        s.em[g] = (col[None, :] * grad[g][:, None])
        if curtain:
            cm = g & ((s.xx - x) < w // 3)
            s.paint(cm, color=col * 0.35)
            s.em[cm] *= 0.35
        if figure:
            f = s.ellipse_mask(x + w * 0.6, y + h * 0.35, 2, 2.4) | s.rect_mask(int(x + w * 0.6) - 3, int(y + h * 0.5), 6, h)
            f &= g
            s.paint(f, color=hexc('#050505'))
            s.em[f] = 0
    sill = s.rect_mask(x - 2, y + h + 1, w + 4, 2)
    s.paint(sill, ramp=P.CONCRETE, value=0.6, normal=UP)


def door(s, x, y, w, h, ramp=P.DARKWOOD, glass=False):
    s.paint(s.rect_mask(x - 2, y - 2, w + 4, h + 2), ramp=P.CONCRETE, value=0.35, normal=SOUTH)
    d = s.rect_mask(x, y, w, h)
    s.paint(d, ramp=ramp, value=0.35 + (s.xx - x) * 0.01, normal=SOUTH)
    s.paint(s.rect_mask(x + w // 2, y, 1, h), ramp=ramp, value=0.1)
    if glass:
        s.paint(s.rect_mask(x + 2, y + 3, w // 2 - 3, h // 2), ramp=P.GLASS_DARK, value=0.5)
        s.paint(s.rect_mask(x + w // 2 + 2, y + 3, w // 2 - 3, h // 2), ramp=P.GLASS_DARK, value=0.5)
    s.paint(s.rect_mask(x + w // 2 - 3, y + h // 2, 1, 3) | s.rect_mask(x + w // 2 + 2, y + h // 2, 1, 3), ramp=P.BRASS, value=0.7)


def facade_heights(s, top, height, mask):
    s.hgt[mask] = (height - (s.yy - top)).astype(np.float32)[mask]


def bld_apartment_a():
    """My building: 4 storeys of brick, entrance with a bulb, fire escape."""
    W, D, H = 208, 160, 112
    s = Sprite(W, D + H)
    roof_top(s, 0, 0, W, D, H, seed=31)
    s.cylinder(170, 30, 10, 8, 18, P.RUST, P.RUST, base=H)          # water tank
    s.box(20, 20, 26, 18, 14, P.CONCRETE, P.CONCRETE, 0.5, 0.35, base=H)   # stair hut
    face = s.rect_mask(0, D, W, H)
    brick_face(s, face, D, seed=32)
    facade_heights(s, D, H, face)
    lit = {(0, 4): '#c8a060', (1, 1): '#7a90c0', (2, 4): '#d0b070', (3, 0): '#c09050'}
    for fl in range(4):
        wy = D + 8 + fl * 26
        s.paint(s.rect_mask(0, wy + 20, W, 2), ramp=P.CONCRETE, value=0.5, normal=UP)    # ledges
        for i in range(6):
            wx = 10 + i * 33
            if fl == 3 and i in (2, 3):
                continue   # entrance
            key = (fl, i)
            window(s, wx, wy, 14, 16, lit=lit.get(key), curtain=(key == (1, 1)), figure=(key == (0, 4)))
    # entrance
    door(s, 92, D + H - 30, 24, 30, glass=True)
    s.box(84, D + H - 38, 40, 6, 3, P.METAL, P.METAL, 0.55, 0.4, base=30, edge=True)   # awning
    s.hgt[s.rect_mask(84, D + H - 38, 40, 9)] = 34
    bulb = s.rect_mask(102, D + H - 30, 4, 2)
    s.paint(bulb, color=hexc('#e8d090'))
    s.em[bulb] = hexc('#ffe0a0')
    s.paint(s.rect_mask(96, D + H - 22, 16, 1), ramp=P.BRASS, value=0.6)
    # fire escape on the right side
    fe = np.zeros((s.h, s.w), bool)
    for fl in range(3):
        y0 = D + 6 + fl * 26 + 22
        fe |= s.rect_mask(160, y0, 40, 1)
        fe |= s.line_mask([(162, y0), (196, y0 + 26)])
        fe |= (s.rect_mask(160, y0 - 6, 40, 1) & ((s.xx % 3) == 0))
    s.paint(fe & face, ramp=P.IRON, value=0.6, normal=SOUTH)
    s.outline(0.6, mask=None)
    return s


def bld_apartment_b():
    """West block: concrete panels, balconies, mostly dark."""
    W, D, H = 256, 176, 128
    s = Sprite(W, D + H)
    roof_top(s, 0, 0, W, D, H, seed=41)
    face = s.rect_mask(0, D, W, H)
    panel_face(s, face, D, seed=42)
    facade_heights(s, D, H, face)
    lit = {(1, 6): '#3a5ab0', (3, 1): '#b08850'}
    for fl in range(4):
        wy = D + 8 + fl * 30
        for i in range(8):
            wx = 8 + i * 31
            if fl == 3 and i == 3:
                continue
            window(s, wx, wy, 16, 14, lit=lit.get((fl, i)))
            if fl < 3 and i % 2 == 1:
                s.paint(s.rect_mask(wx - 3, wy + 16, 22, 5), ramp=P.IRON, value=0.4, normal=SOUTH)
                s.paint(s.rect_mask(wx - 3, wy + 16, 22, 1), ramp=P.IRON, value=0.8, normal=UP)
    door(s, 104, D + H - 28, 24, 28, ramp=P.METAL)
    s.paint(s.rect_mask(110, D + H - 34, 12, 3), ramp=P.PAPER, value=0.6)
    s.outline(0.6)
    return s


def house(seed, lit_win=False):
    """Small detached house with a gable roof seen in 3/4."""
    W, D, H = 96, 72, 34
    s = Sprite(W, D + H + 20)
    oy = 20
    # walls
    face = s.rect_mask(0, oy + D, W, H)
    sid = Ramp.from_base(['#4a4538', '#3a4048', '#4a3a34'][seed % 3], 5)
    v = 0.45 + ((s.yy % 4) == 0) * -0.15 + (fbm(s.w, s.h, 6, seed, 2) - 0.5) * 0.2
    s.paint(face, ramp=sid, value=v, normal=SOUTH)
    facade_heights(s, oy + D, H, face)
    # gable roof: ridge along x; north slope then south slope
    roofc = Ramp.from_base(['#2a2422', '#262a2e', '#2e2620'][seed % 3], 5)
    north = s.rect_mask(0, oy - 20, W, D // 2 + 20)
    south = s.rect_mask(0, oy + D // 2, W, D // 2)
    shingle = ((s.yy % 4) == 0) | (((s.xx + (s.yy // 4) * 3) % 7) == 0)
    s.paint(north, ramp=roofc, value=0.3 + shingle * -0.12, normal=(0, -0.5, 0.86))
    s.paint(south, ramp=roofc, value=0.55 + shingle * -0.15, normal=(0, 0.6, 0.8))
    ridge_h = H + 26
    s.hgt[north] = (H + (s.yy - (oy - 20)) * 26.0 / (D // 2 + 20))[north]
    s.hgt[south] = (ridge_h - (s.yy - (oy + D // 2)) * 26.0 / (D // 2))[south]
    s.paint(s.rect_mask(0, oy + D // 2 - 1, W, 2), ramp=roofc, value=0.8)
    s.paint(s.rect_mask(0, oy + D - 2, W, 2), ramp=roofc, value=0.15)
    s.box(64, oy - 6, 8, 6, 14, P.BRICK, P.BRICK, 0.5, 0.4, base=H + 10)   # chimney
    window(s, 12, oy + D + 8, 14, 14, lit='#c09858' if lit_win else None)
    window(s, 70, oy + D + 8, 14, 14)
    door(s, 40, oy + D + H - 24, 16, 24)
    s.outline(0.6)
    return s


def store():
    """24/7 MART: bright glass front, neon sign band, posters."""
    W, D, H = 272, 112, 56
    s = Sprite(W, D + H)
    roof_top(s, 0, 0, W, D, H, seed=51, parapet=2)
    face = s.rect_mask(0, D, W, H)
    s.paint(face, ramp=Ramp.from_base('#4a4a46', 5), value=0.45 + (fbm(s.w, s.h, 5, 52, 2) - 0.5) * 0.3, normal=SOUTH)
    facade_heights(s, D, H, face)
    # sign band
    band = s.rect_mask(0, D, W, 14)
    s.paint(band, ramp=Ramp.from_base('#2a1414', 4), value=0.4, normal=SOUTH)
    # neon letters
    text = "24/7 MART"
    letters = text_masks(s, text, (W - text_width(text, 2)) // 2, D + 2, 2)
    for i, m in enumerate(letters):
        col = hexc('#ff4a3a') if i < 4 else hexc('#f0f0e0')
        s.paint(m, color=col * 0.8)
        s.em[m] = col
    # glass storefront with shelves inside
    gl = s.rect_mask(6, D + 18, W - 12, H - 22)
    inside = mix(hexc('#c8d8c8'), hexc('#9ab0a0'), (s.yy - (D + 18)) / (H - 22))
    s.paint(gl, color=inside * 0.75, normal=SOUTH)
    s.em[gl] = inside[gl] * 0.85
    for sx in range(14, W - 20, 26):
        shelf = s.rect_mask(sx, D + 26, 16, H - 32)
        s.paint(shelf & gl, ramp=Ramp.from_base('#5a5a50', 4), value=0.4)
        s.em[shelf & gl] *= 0.25
        for k in range(3):
            prod = s.rect_mask(sx + 1, D + 28 + k * 8, 14, 3) & ((s.xx % 3) != 0)
            colr = hexc(['#a03a2a', '#d0b040', '#3a70a0', '#40a060'][(sx // 26 + k) % 4])
            s.paint(prod & gl, color=colr * 0.6)
            s.em[prod & gl] = colr * 0.3
    # mullions + door
    for mx in range(6, W - 6, 44):
        m = s.rect_mask(mx, D + 18, 2, H - 22)
        s.paint(m, ramp=P.METAL, value=0.4)
        s.em[m] = 0
    dm = s.rect_mask(W // 2 - 14, D + 20, 28, H - 20)
    s.paint(dm & ~s.rect_mask(W // 2 - 12, D + 22, 24, H - 22), ramp=P.METAL, value=0.5)
    s.em[dm & ~s.rect_mask(W // 2 - 12, D + 22, 24, H - 22)] = 0
    s.paint(s.rect_mask(W // 2, D + 22, 1, H - 22), ramp=P.METAL, value=0.3)
    # posters taped to the glass + OPEN sign
    for px, colr in ((20, '#d8c070'), (70, '#c05040'), (196, '#5080b0'), (232, '#d8c070')):
        pm = s.rect_mask(px, D + 34, 12, 14)
        s.paint(pm, color=hexc(colr) * 0.7)
        s.em[pm] = hexc(colr) * 0.25
        s.paint(s.rect_mask(px + 2, D + 37, 8, 2), color=hexc('#202020'))
        s.em[s.rect_mask(px + 2, D + 37, 8, 2)] = 0
    om = s.rect_mask(W // 2 + 18, D + 24, 14, 6)
    s.paint(om, color=hexc('#30a050'))
    s.em[om] = hexc('#40ff70')
    # missing-child poster next to the door (paper, not lit)
    mp = s.rect_mask(W // 2 - 26, D + 30, 9, 12)
    s.paint(mp, ramp=P.PAPER, value=0.75)
    s.em[mp] = hexc('#404038')
    s.paint(s.ellipse_mask(W // 2 - 21.5, D + 35, 2, 2), color=hexc('#202020'))
    s.paint(s.rect_mask(0, D + H - 2, W, 2), ramp=P.CONCRETE, value=0.25)
    s.outline(0.6)
    return s


def school():
    W, D, H = 448, 64, 76
    s = Sprite(W, D + H)
    roof_top(s, 0, 0, W, D, H, seed=61)
    face = s.rect_mask(0, D, W, H)
    brick_face(s, face, D, ramp=Ramp.from_base('#4a2a20', 6), seed=62)
    facade_heights(s, D, H, face)
    for fl in range(2):
        for i in range(12):
            wx = 10 + i * 37
            if fl == 1 and 5 <= i <= 6:
                continue
            window(s, wx, D + 8 + fl * 34, 18, 22)
            s.paint(s.rect_mask(wx + 8, D + 8 + fl * 34, 1, 22) | s.rect_mask(wx, D + 18 + fl * 34, 18, 1), ramp=P.CONCRETE, value=0.35)
    door(s, 200, D + H - 30, 48, 30, ramp=Ramp.from_base('#2a3a4a', 5), glass=True)
    # stopped clock above the door
    s.paint(s.ellipse_mask(224, D + 30, 8, 8), ramp=P.CONCRETE, value=0.4)
    f = s.ellipse_mask(224, D + 30, 6.5, 6.5)
    s.paint(f, ramp=P.PAPER, value=0.6)
    s.paint(s.line_mask([(224, D + 30), (224, D + 25)]) | s.line_mask([(224, D + 30), (227, D + 32)]), color=hexc('#101010'))
    # sign
    sg = s.rect_mask(160, D + 2, 128, 8)
    s.paint(sg, ramp=P.CONCRETE, value=0.65)
    s.paint(sg & ((s.xx % 4) != 0) & s.rect_mask(166, D + 4, 116, 4), ramp=P.CONCRETE, value=0.2)
    s.outline(0.6)
    return s


def fence_iron(w=16):
    s = Sprite(w, 34)
    for bx in range(1, w, 4):
        bar = s.rect_mask(bx, 4, 1, 28)
        s.paint(bar, ramp=P.IRON, value=0.65, normal=SOUTH)
        tip = s.rect_mask(bx, 2, 1, 2) | s.rect_mask(bx - 1, 3, 3, 1)
        s.paint(tip, ramp=P.IRON, value=0.8, normal=SOUTH)
    s.paint(s.rect_mask(0, 8, w, 2) | s.rect_mask(0, 26, w, 2), ramp=P.IRON, value=0.5, normal=SOUTH)
    s.tint(s.a & (white(w, 34, 71) > 0.8), hexc('#4a2a14'), 0.5)
    s.billboard_height(None, bottom=33)
    return s


def school_gate():
    """Two iron leaves chained shut between brick pillars (total 144 wide)."""
    W = 144
    s = Sprite(W, 52)
    # pillars
    for px in (0, W - 16):
        s.box(px, 0, 16, 8, 42, Ramp.from_base('#5a3428', 5), P.BRICK, 0.6, 0.45)
        brick_face(s, s.rect_mask(px, 8, 16, 42), 8, seed=73)
        s.box(px - 1, -1, 18, 4, 3, P.CONCRETE, P.CONCRETE, 0.7, 0.5, base=42)
        s.hgt[s.rect_mask(px, 0, 16, 52)] = np.maximum(s.hgt[s.rect_mask(px, 0, 16, 52)], 0)
    for px in (0, W - 16):
        m = s.rect_mask(px, 8, 16, 42)
        s.hgt[m] = (42 - (s.yy - 8)).astype(np.float32)[m]
    # leaves
    for bx in range(18, W - 18, 4):
        bar = s.rect_mask(bx, 10, 1, 40)
        s.paint(bar, ramp=P.IRON, value=0.7, normal=SOUTH)
        s.paint(s.rect_mask(bx - 1, 8, 3, 2), ramp=P.IRON, value=0.85, normal=SOUTH)
    s.paint(s.rect_mask(16, 14, W - 32, 2) | s.rect_mask(16, 44, W - 32, 2), ramp=P.IRON, value=0.55, normal=SOUTH)
    # scrollwork arches
    for cx in (44, 100):
        arc = s.ellipse_mask(cx, 22, 14, 6) & ~s.ellipse_mask(cx, 22, 13, 5) & (s.yy < 22)
        s.paint(arc, ramp=P.IRON, value=0.6, normal=SOUTH)
    s.paint(s.rect_mask(W // 2, 10, 1, 40), ramp=P.IRON, value=0.2)
    # chain + new padlock
    chain = np.zeros((s.h, s.w), bool)
    for i in range(10):
        chain |= s.ellipse_mask(W // 2 - 10 + i * 2, 30 + (i % 2), 1.4, 1)
    s.paint(chain, ramp=P.METAL, value=0.85, normal=SOUTH)
    s.paint(s.rect_mask(W // 2 - 2, 31, 5, 6), ramp=P.BRASS, value=0.8, normal=SOUTH)
    s.tint(s.a & (white(W, 52, 74) > 0.82) & ~chain, hexc('#4a2a14'), 0.45)
    # plaque on the left pillar
    s.paint(s.rect_mask(3, 20, 10, 7), ramp=P.BRASS, value=0.45)
    s.billboard_height(s.a & ~s.rect_mask(0, 0, 16, 52) & ~s.rect_mask(W - 16, 0, 16, 52), bottom=51)
    return s


def streetlight():
    """Pole with an arm reaching right; lamp head at (13, 2)."""
    s = Sprite(20, 70)
    pole = s.rect_mask(3, 6, 3, 62)
    s.paint(pole, ramp=P.IRON, value=0.55 - (s.xx - 4) * 0.15, normal=SOUTH)
    s.paint(s.rect_mask(2, 62, 5, 7), ramp=P.IRON, value=0.4, normal=SOUTH)
    arm = s.line_mask([(4, 7), (8, 3), (15, 3)])
    s.paint(arm, ramp=P.IRON, value=0.6, normal=SOUTH)
    head = s.rect_mask(11, 2, 8, 3)
    s.paint(head, ramp=P.METAL, value=0.4, normal=UP)
    bulb = s.rect_mask(12, 5, 6, 1)
    s.paint(bulb, color=hexc('#f0d8a0'))
    s.em[bulb] = hexc('#ffe2a8')
    s.billboard_height(None, bottom=69)
    return s


def traffic_light():
    s = Sprite(12, 60)
    s.paint(s.rect_mask(5, 14, 2, 46), ramp=P.IRON, value=0.6, normal=SOUTH)
    box = s.rect_mask(2, 0, 8, 18)
    s.paint(box, ramp=Ramp.from_base('#3a3a1a', 4), value=0.4, normal=SOUTH)
    for i, c in enumerate(('#3a1010', '#d09020', '#103a10')):
        m = s.ellipse_mask(6, 3.5 + i * 5.5, 2.2, 2.2)
        s.paint(m, color=hexc(c) * 0.6)
        if i == 1:
            s.em[m] = hexc('#ffb030')
    s.billboard_height(None, bottom=59)
    return s


def tree(seed, w=56, h=80):
    """Leafless tree by recursive branching."""
    s = Sprite(w, h)
    r = rng(seed)
    m = np.zeros((h, w), bool)
    thick = np.zeros((h, w), np.float32)

    def branch(x, y, ang, length, width, depth):
        nonlocal m
        x2 = x + np.cos(ang) * length
        y2 = y + np.sin(ang) * length
        lm = s.line_mask([(x, y), (x2, y2)], width=max(1, int(width)))
        m |= lm
        thick[lm] = np.maximum(thick[lm], width)
        if depth > 0 and length > 3:
            for _ in range(2 + (r.random() < 0.3)):
                branch(x2, y2, ang + (r.random() - 0.5) * 1.3, length * (0.62 + r.random() * 0.15), width * 0.65, depth - 1)

    branch(w / 2, h - 2, -np.pi / 2 + (r.random() - 0.5) * 0.2, h * 0.32, 4, 6)
    v = 0.35 + (thick / 4) * 0.3 - (s.xx - w / 2) * 0.006
    s.paint(m, ramp=P.BARK, value=v, normal=SOUTH)
    s.billboard_height(m, bottom=h - 1)
    s.outline(0.7)
    return s


def bush(seed):
    s = Sprite(28, 20)
    r = rng(seed)
    m = np.zeros((20, 28), bool)
    for _ in range(6):
        m |= s.ellipse_mask(6 + r.random() * 16, 8 + r.random() * 6, 5 + r.random() * 3, 4 + r.random() * 2)
    n = fbm(28, 20, 3, seed, 3)
    s.paint(m, ramp=P.HEDGE, value=0.3 + n * 0.6 - (s.xx - 14) * 0.01, normal=UP)
    s.pillow_normals(m, 1.3)
    s.bump(m, n, 3)
    s.billboard_height(m, bottom=19)
    s.hgt[m] = np.minimum(s.hgt[m], 14)
    s.outline(0.6)
    return s


def car_h(ramp, seed, tag=False):
    """Sedan seen from the side-top, facing east. Footprint 48x18, height 14."""
    s = Sprite(50, 34)
    # lower body
    s.box(1, 10, 48, 14, 9, ramp, ramp, 0.55, 0.45)
    # cabin
    s.box(12, 4, 24, 12, 7, ramp, WINDSHIELD_RAMP, 0.6, 0.5, base=9)
    s.paint(s.rect_mask(14, 17, 9, 5), ramp=P.WINDSHIELD, value=0.6, normal=SOUTH, height=14)
    s.paint(s.rect_mask(25, 17, 9, 5), ramp=P.WINDSHIELD, value=0.4, normal=SOUTH, height=14)
    s.paint(s.rect_mask(23, 17, 2, 5), ramp=ramp, value=0.4, normal=SOUTH, height=14)
    s.paint(s.rect_mask(12, 4, 24, 12), ramp=ramp, value=0.62, normal=UP, height=16)
    s.paint(s.rect_mask(9, 6, 3, 10) | s.rect_mask(36, 6, 4, 10), ramp=P.WINDSHIELD, value=0.5, normal=UP, height=13)
    # wheels
    for wx in (8, 36):
        s.paint(s.ellipse_mask(wx + 3, 31, 4, 3), ramp=P.TIRE, value=0.5, normal=SOUTH, height=4)
        s.paint(s.ellipse_mask(wx + 3, 31, 1.5, 1.2), ramp=P.METAL, value=0.6, height=4)
    # lights (off), handle, rust
    s.paint(s.rect_mask(46, 25, 3, 2), ramp=Ramp.from_base('#8a8a70', 4), value=0.6)
    s.paint(s.rect_mask(1, 25, 2, 2), ramp=Ramp.from_base('#6a1a1a', 4), value=0.6)
    s.paint(s.rect_mask(24, 27, 3, 1), ramp=P.METAL, value=0.8)
    s.tint(s.a & (fbm(50, 34, 4, seed, 2) > 0.65) & (s.yy > 20), hexc('#3a2010'), 0.4)
    if tag:
        s.paint(s.rect_mask(15, 18, 5, 3), color=hexc('#d8d4c0'))
        s.paint(s.rect_mask(16, 19, 3, 1), color=hexc('#a02020'))
    # dirt + dew sparkle on the roof
    s.paint(s.a & (white(50, 34, seed + 3) > 0.985), ramp=ramp, value=1.0)
    s.outline(0.55)
    return s


WINDSHIELD_RAMP = P.WINDSHIELD


def car_v(ramp, seed, tag=False):
    """Car parked nose-north (seen from above-south). Footprint 26x46."""
    s = Sprite(28, 58)
    s.box(1, 2, 26, 44, 10, ramp, ramp, 0.55, 0.42)
    # windshield (north) + rear window (south)
    s.paint(s.rect_mask(4, 10, 20, 8), ramp=P.WINDSHIELD, value=0.55, normal=(0, -0.4, 0.9), height=14)
    s.paint(s.rect_mask(4, 32, 20, 6), ramp=P.WINDSHIELD, value=0.35, normal=(0, 0.5, 0.85), height=14)
    s.paint(s.rect_mask(4, 18, 20, 14), ramp=ramp, value=0.66, normal=UP, height=16)
    s.paint(s.rect_mask(3, 18, 1, 14) | s.rect_mask(24, 18, 1, 14), ramp=P.WINDSHIELD, value=0.4, height=14)
    # rear lights on the front face
    s.paint(s.rect_mask(2, 48, 5, 2) | s.rect_mask(21, 48, 5, 2), ramp=Ramp.from_base('#7a1a1a', 4), value=0.6)
    s.paint(s.rect_mask(10, 49, 8, 4), ramp=Ramp.from_base('#c0c0a0', 4), value=0.5)     # plate
    for wx in (0, 24):
        s.paint(s.rect_mask(wx, 50, 4, 6), ramp=P.TIRE, value=0.5, normal=SOUTH, height=4)
    if tag:
        s.paint(s.rect_mask(9, 12, 7, 4), color=hexc('#d8d4c0'), height=15)
        s.paint(s.rect_mask(10, 13, 5, 1), color=hexc('#a02020'), height=15)
    s.tint(s.a & (fbm(28, 58, 4, seed, 2) > 0.66), hexc('#2a1a10'), 0.35)
    s.outline(0.55)
    return s


def dumpster():
    s = Sprite(36, 30)
    s.box(0, 2, 36, 12, 16, Ramp.from_base('#2a3a2a', 5), Ramp.from_base('#2a3a2a', 5), 0.5, 0.4)
    s.paint(s.rect_mask(0, 2, 36, 12) & ((s.xx % 6) == 0), ramp=Ramp.from_base('#2a3a2a', 5), value=0.2, height=16)
    s.tint(s.a & (fbm(36, 30, 3, 81, 2) > 0.58), hexc('#3a2010'), 0.5)
    s.paint(s.rect_mask(4, 16, 28, 3), ramp=P.PAPER, value=0.5, height=10)
    s.box(-0, 0, 14, 4, 3, P.TRASHBAG, P.TRASHBAG, 0.5, 0.4, base=16)
    s.outline(0.6)
    return s


def trash_can():
    s = Sprite(12, 20)
    s.cylinder(6, 4, 5, 4, 13, P.METAL, P.METAL)
    s.paint(s.rect_mask(1, 8, 10, 1) | s.rect_mask(1, 13, 10, 1), ramp=P.METAL, value=0.25)
    s.outline(0.6)
    return s


def hydrant():
    s = Sprite(8, 14)
    s.cylinder(4, 2, 2.5, 2, 9, Ramp.from_base('#7a2018', 5), Ramp.from_base('#7a2018', 5))
    s.paint(s.rect_mask(0, 6, 8, 2), ramp=Ramp.from_base('#7a2018', 5), value=0.5, normal=SOUTH)
    s.outline(0.6)
    return s


def bench():
    s = Sprite(32, 18)
    s.box(0, 6, 32, 6, 5, P.DARKWOOD, P.DARKWOOD, 0.55, 0.4)
    s.box(0, 0, 32, 2, 6, P.DARKWOOD, P.DARKWOOD, 0.6, 0.4, base=5)
    s.paint(s.rect_mask(2, 15, 2, 3) | s.rect_mask(28, 15, 2, 3), ramp=P.IRON, value=0.4)
    s.outline(0.6)
    return s


def vending():
    s = Sprite(18, 36)
    s.box(0, 0, 18, 6, 30, Ramp.from_base('#3a1a1a', 5), Ramp.from_base('#7a1a1a', 5), 0.5, 0.45)
    pan = s.rect_mask(2, 8, 10, 20)
    s.paint(pan, color=hexc('#b0c0c8') * 0.6, normal=SOUTH)
    s.em[pan] = hexc('#a0c0d0') * 0.9
    for k in range(4):
        row = s.rect_mask(3, 10 + k * 5, 8, 2) & ((s.xx % 2) == 0)
        s.paint(row, color=hexc(['#c03030', '#3070c0', '#d0c040', '#40a050'][k]) * 0.6)
        s.em[row] = hexc(['#c03030', '#3070c0', '#d0c040', '#40a050'][k]) * 0.5
    s.paint(s.rect_mask(13, 12, 3, 6), ramp=P.METAL, value=0.6)
    s.paint(s.rect_mask(3, 30, 10, 3), color=hexc('#050505'))
    s.outline(0.6)
    return s


def payphone():
    s = Sprite(14, 40)
    s.paint(s.rect_mask(6, 14, 2, 26), ramp=P.METAL, value=0.5, normal=SOUTH)
    s.box(1, 0, 12, 4, 16, P.METAL, Ramp.from_base('#2a3a5a', 5), 0.6, 0.45, base=20)
    s.paint(s.rect_mask(3, 8, 5, 8), ramp=P.PLASTIC_BLK, value=0.5)
    s.paint(s.rect_mask(9, 8, 3, 9), ramp=P.PLASTIC_BLK, value=0.7)
    lamp = s.rect_mask(2, 4, 10, 1)
    s.em[lamp] = hexc('#a0b0d0') * 0.8
    s.billboard_height(None, bottom=39)
    s.outline(0.6)
    return s


def power_pole():
    s = Sprite(26, 100)
    s.paint(s.rect_mask(11, 8, 4, 92), ramp=P.BARK, value=0.55 - (s.xx - 12) * 0.12, normal=SOUTH)
    s.paint(s.rect_mask(0, 10, 26, 3), ramp=P.BARK, value=0.5, normal=SOUTH)
    for ix in (1, 12, 23):
        s.paint(s.rect_mask(ix, 7, 2, 3), ramp=P.PORCELAIN, value=0.5)
    s.box(15, 30, 8, 6, 10, P.METAL, P.METAL, 0.5, 0.4, base=60)   # transformer
    s.billboard_height(None, bottom=99)
    s.outline(0.6)
    return s


def billboard():
    s = Sprite(96, 92)
    s.paint(s.rect_mask(20, 50, 4, 42) | s.rect_mask(72, 50, 4, 42), ramp=P.IRON, value=0.5, normal=SOUTH)
    board = s.rect_mask(0, 0, 96, 52)
    s.paint(board, ramp=P.IRON, value=0.3, normal=SOUTH)
    ad = s.rect_mask(3, 3, 90, 44)
    sky = mix(hexc('#6a7a8a'), hexc('#b0a080'), (s.yy / 44.0))
    s.paint(ad, color=sky * 0.6, normal=SOUTH)
    # a smiling family, faded, one face torn away
    for i, fx in enumerate((24, 40, 58)):
        f = s.ellipse_mask(fx, 20 + (i == 2) * 4, 5, 6)
        s.paint(f & ad, ramp=P.SKIN, value=0.7)
        s.paint(s.rect_mask(fx - 6, 27 + (i == 2) * 4, 12, 20) & ad, ramp=Ramp.from_base(['#3a5a8a', '#8a3a3a', '#5a8a3a'][i], 5), value=0.5)
    torn = s.ellipse_mask(58, 22, 7, 8) | s.rect_mask(54, 22, 20, 12)
    s.paint(torn & ad & (fbm(96, 92, 3, 91, 2) > 0.35), ramp=P.PAPER, value=0.35)
    s.paint(s.rect_mask(8, 38, 80, 5) & ((s.xx % 3) != 0), color=hexc('#202020'))
    peel = (fbm(96, 92, 4, 92, 3) > 0.68) & ad
    s.paint(peel, ramp=P.PAPER, value=0.3)
    s.billboard_height(None, bottom=91)
    s.outline(0.6)
    return s


def deal_sign():
    """Tall dealership sign: AUTO SALES with a dying neon tube."""
    s = Sprite(48, 96)
    s.paint(s.rect_mask(22, 30, 4, 66), ramp=P.IRON, value=0.5, normal=SOUTH)
    board = s.rect_mask(0, 0, 48, 30)
    s.paint(board, ramp=Ramp.from_base('#1a2a4a', 5), value=0.4, normal=SOUTH)
    s.paint(board & ~s.rect_mask(2, 2, 44, 26), ramp=P.METAL, value=0.5)
    # AUTO lit (the T has died), SALES dead
    on, off = hexc('#60c0ff'), hexc('#1c2630')
    for i, m in enumerate(text_masks(s, "AUTO", (48 - text_width("AUTO", 2)) // 2, 4, 2)):
        lit = i != 2
        s.paint(m, color=(on if lit else off) * 0.7)
        if lit:
            s.em[m] = on
    for m in text_masks(s, "SALES", (48 - text_width("SALES", 1)) // 2, 19, 1):
        s.paint(m, color=off)
    s.billboard_height(None, bottom=95)
    return s


def office():
    """Dealership office: low, glass-fronted, dark."""
    W, D, H = 208, 96, 46
    s = Sprite(W, D + H)
    roof_top(s, 0, 0, W, D, H, seed=101, parapet=2)
    face = s.rect_mask(0, D, W, H)
    s.paint(face, ramp=Ramp.from_base('#3a3e44', 5), value=0.45, normal=SOUTH)
    facade_heights(s, D, H, face)
    gl = s.rect_mask(6, D + 12, W - 12, H - 14)
    v = 0.3 + (s.xx - 6) / W * 0.4 - (s.yy - D) / H * 0.2
    s.paint(gl, ramp=P.GLASS_DARK, value=v, normal=SOUTH)
    for mx in range(6, W - 6, 32):
        s.paint(s.rect_mask(mx, D + 12, 2, H - 14), ramp=P.METAL, value=0.45)
    # sign band (unlit)
    s.paint(s.rect_mask(10, D + 2, W - 20, 7), ramp=Ramp.from_base('#6a6a60', 4), value=0.5)
    s.paint(s.rect_mask(16, D + 4, W - 32, 3) & ((s.xx % 5) != 0), ramp=Ramp.from_base('#2a2a28', 4), value=0.4)
    # a desk lamp left on inside
    dl = s.rect_mask(150, D + 30, 3, 2)
    s.em[dl] = hexc('#d0b070')
    s.paint(s.rect_mask(140, D + 32, 20, 4), ramp=P.DARKWOOD, value=0.3)
    s.outline(0.6)
    return s


def chainlink(w=32):
    s = Sprite(w, 30)
    mesh = (((s.xx + s.yy) % 4) == 0) | (((s.xx - s.yy) % 4) == 0)
    m = mesh & s.rect_mask(0, 4, w, 24)
    s.paint(m, ramp=P.METAL, value=0.45, normal=SOUTH)
    s.paint(s.rect_mask(0, 3, w, 1), ramp=P.METAL, value=0.6, normal=SOUTH)
    s.paint(s.rect_mask(0, 3, 2, 27) | s.rect_mask(w - 2, 3, 2, 27), ramp=P.METAL, value=0.55, normal=SOUTH)
    s.billboard_height(None, bottom=29)
    return s


def lock_world():
    s = Sprite(7, 6)
    m = s.rect_mask(1, 2, 5, 4)
    s.paint(m, ramp=P.RUST, value=0.6, normal=UP, height=1)
    sh = s.rect_mask(1, 0, 1, 2) | s.rect_mask(2, 0, 2, 1)
    s.paint(sh, ramp=P.METAL, value=0.7, normal=UP, height=1)
    s.em[m | sh] = hexc('#201008') * 0.5
    return s


def ball():
    s = Sprite(7, 6)
    m = s.ellipse_mask(3.5, 3, 3, 2.6)
    s.paint(m, ramp=Ramp.from_base('#7a2a2a', 5), value=0.6 - (s.xx - 3) * 0.08 - (s.yy - 3) * 0.08, normal=UP, height=5)
    s.pillow_normals(m, 1.0)
    s.outline(0.6)
    return s


def swing():
    s = Sprite(40, 44)
    frame = s.line_mask([(2, 43), (8, 2)]) | s.line_mask([(38, 43), (32, 2)]) | s.rect_mask(6, 1, 28, 2)
    s.paint(frame, ramp=P.RUST, value=0.55, normal=SOUTH)
    for sx in (14, 26):
        s.paint(s.rect_mask(sx, 3, 1, 28) | s.rect_mask(sx + 5, 3, 1, 28), ramp=P.METAL, value=0.4)
        s.paint(s.rect_mask(sx - 1, 31, 8, 2), ramp=P.DARKWOOD, value=0.5)
    s.billboard_height(None, bottom=43)
    return s


def build_props():
    return {
        'bld_apt_a': bld_apartment_a(),
        'bld_apt_b': bld_apartment_b(),
        'house_a': house(1, True),
        'house_b': house(2),
        'house_c': house(3),
        'store': store(),
        'school': school(),
        'fence_iron': fence_iron(),
        'school_gate': school_gate(),
        'streetlight': streetlight(),
        'traffic_light': traffic_light(),
        'tree_a': tree(201),
        'tree_b': tree(202, 64, 90),
        'tree_c': tree(203, 48, 70),
        'bush_a': bush(211),
        'bush_b': bush(212),
        'car_red': car_h(P.CAR_RED, 221),
        'car_gray': car_h(P.CAR_GRAY, 222),
        'car_blue_v': car_v(P.CAR_BLUE, 223, True),
        'car_white_v': car_v(P.CAR_WHITE, 224, True),
        'car_green_v': car_v(P.CAR_GREEN, 225, True),
        'car_red_v': car_v(P.CAR_RED, 226, True),
        'car_gray_v': car_v(P.CAR_GRAY, 227, True),
        'dumpster': dumpster(),
        'trash_can': trash_can(),
        'hydrant': hydrant(),
        'bench': bench(),
        'vending': vending(),
        'payphone': payphone(),
        'power_pole': power_pole(),
        'billboard': billboard(),
        'deal_sign': deal_sign(),
        'office': office(),
        'chainlink': chainlink(),
        'lock': lock_world(),
        'ball': ball(),
        'swing': swing(),
    }


def build(grid_path):
    grid = load_grid(grid_path)
    return build_ground(grid), build_props()
