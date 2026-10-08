"""Scene 1: the apartment. Background (floors + walls) from maps/apartment.txt
plus every prop sprite placed by src/scenes/apartment.lua."""
import numpy as np
from scipy import ndimage

from . import palette as P
from .core import (Sprite, Ramp, UP, SOUTH, EAST, WEST, fbm, value_noise, white, hexc, mix, strip, rng)

T = 16
FACE = 32
CAP_H = 40


def load_grid(path):
    with open(path) as f:
        return [line.rstrip('\n') for line in f if line.strip()]


# ---------------------------------------------------------------------------
# materials (operate on a whole canvas, painted through a mask)
# ---------------------------------------------------------------------------
def mat_wood(s, mask, seed=1):
    W, H = s.w, s.h
    xx, yy = s.xx, s.yy
    ph = 5
    row = yy // ph
    r = rng(seed)
    nrows = H // ph + 2
    off = r.integers(0, 64, nrows)
    L = r.integers(22, 46, nrows)
    tone = r.random((nrows, 64)).astype(np.float32)
    rx = xx + off[row]
    seg = (rx // L[row]) % 64
    seam_end = (rx % L[row]) == 0
    seam_row = (yy % ph) == 0
    grain = value_noise(W, H, 1, seed + 3, sx=14, sy=1.2)
    grain2 = value_noise(W, H, 1, seed + 4, sx=5, sy=0.7)
    wear = fbm(W, H, 60, seed + 5, 3)
    stain = fbm(W, H, 18, seed + 6, 4)
    v = 0.30 + tone[row, seg] * 0.28 + (grain - 0.5) * 0.22 + (grain2 - 0.5) * 0.10 + (wear - 0.5) * 0.25
    v = np.where(stain > 0.68, v * 0.45, v)
    v = np.where(seam_row, 0.02, v)
    v = np.where(seam_end & ~seam_row, 0.08, v)
    # nail heads
    nails = ((rx % L[row]) == 2) & ((yy % ph) == 2)
    v = np.where(nails, 0.05, v)
    s.paint(mask, ramp=P.WOOD, value=v, normal=UP, height=0)
    bumpm = np.where(seam_row | seam_end, -1.0, 0.0) + (grain - 0.5) * 0.3
    s.bump(mask, bumpm, 0.6)


def mat_carpet(s, mask, seed=2):
    W, H = s.w, s.h
    fib = white(W, H, seed)
    fib = ndimage.uniform_filter(fib, 2)
    low = fbm(W, H, 24, seed + 1, 4)
    stains = fbm(W, H, 14, seed + 2, 4)
    worn = fbm(W, H, 40, seed + 3, 2)
    v = 0.45 + (fib - 0.5) * 0.55 + (low - 0.5) * 0.3 + (worn - 0.5) * 0.2
    v = np.where(stains > 0.66, v * 0.5, v)
    s.paint(mask, ramp=P.CARPET, value=v, normal=UP, height=0)
    yel = (stains < 0.22) & mask
    s.tint(yel, hexc('#4a3f1e'), 0.35)
    s.bump(mask, fib, 0.9)


def mat_bath_tiles(s, mask, seed=3, size=8):
    W, H = s.w, s.h
    xx, yy = s.xx, s.yy
    tx, ty = xx // size, yy // size
    px, py = xx % size, yy % size
    r = rng(seed)
    tv = r.random((H // size + 2, W // size + 2)).astype(np.float32)
    grime = fbm(W, H, 20, seed + 1, 4)
    v = 0.62 + tv[ty, tx] * 0.16 - grime * 0.35
    v = np.where((px == 1) | (py == 1), v + 0.08, v)
    v = np.where((px == size - 1) | (py == size - 1), v - 0.08, v)
    # cracked / broken tiles
    broken = tv[ty, tx] > 0.93
    v = np.where(broken & ((px + py) % 5 == 0), 0.08, v)
    grout = (px == 0) | (py == 0)
    s.paint(mask & ~grout, ramp=P.BATH_TILE, value=v, normal=UP, height=0)
    gv = 0.5 - grime * 0.4
    s.paint(mask & grout, ramp=P.GROUT, value=gv, normal=UP, height=0)
    mold = (fbm(W, H, 10, seed + 7, 3) > 0.64) & mask
    s.tint(mold & grout, hexc('#0c1408'), 0.75)
    s.tint(mold & ~grout, hexc('#28301a'), 0.25)
    b = np.where(grout, -1.0, 0.0)
    s.bump(mask, b, 0.5)


def mat_linoleum(s, mask, seed=4, size=8):
    W, H = s.w, s.h
    xx, yy = s.xx, s.yy
    chk = ((xx // size + yy // size) % 2) == 0
    dirt = fbm(W, H, 16, seed, 4)
    sticky = fbm(W, H, 8, seed + 1, 3)
    va = 0.75 - dirt * 0.55
    vb = 0.65 - dirt * 0.5
    s.paint(mask & chk, ramp=P.LINO_A, value=va, normal=UP, height=0)
    s.paint(mask & ~chk, ramp=P.LINO_B, value=vb, normal=UP, height=0)
    st = (sticky > 0.7) & mask
    s.tint(st, hexc('#2a1a0c'), 0.45)
    peel = (fbm(W, H, 22, seed + 2, 3) > 0.74) & mask
    s.paint(peel, ramp=P.SUBFLOOR, value=white(W, H, seed + 3) * 0.6 + 0.2, normal=UP, height=0)
    edge = peel & ~ndimage.binary_erosion(peel)
    s.paint(edge, ramp=P.LINO_A, value=0.95, normal=(0, -0.3, 1), height=1)
    s.bump(mask, peel.astype(np.float32) * -1, 0.6)


def mat_cap(s, mask, seed=5):
    W, H = s.w, s.h
    v = 0.4 + (fbm(W, H, 8, seed, 3) - 0.5) * 0.5
    s.paint(mask, ramp=P.CAP, value=v, normal=UP, height=CAP_H)


def mat_wallpaper(s, mask, top, ramp, seed=6, pattern='stripe'):
    """mask = face pixels. `top` = per-pixel y of the face top (array)."""
    W, H = s.w, s.h
    xx, yy = s.xx, s.yy
    rel = (yy - top).astype(np.float32)            # 0 at face top
    base = 0.55 + (fbm(W, H, 12, seed, 3) - 0.5) * 0.25
    if pattern == 'stripe':
        stripe = (xx % 7 == 0) | (xx % 7 == 1)
        base = np.where(stripe, base - 0.12, base)
        dots = ((xx % 7) == 4) & ((yy % 6) == 3)
        base = np.where(dots, base + 0.18, base)
    else:  # faded floral diamonds
        d = (np.abs((xx % 10) - 5) + np.abs((yy % 10) - 5))
        base = np.where(d == 3, base + 0.16, base)
        base = np.where(d == 0, base - 0.2, base)
    # ceiling shadow, floor grime
    base = base - np.clip(1 - rel / 6, 0, 1) * 0.3
    base = base - np.clip((rel - 22) / 10, 0, 1) * 0.15
    s.paint(mask, ramp=ramp, value=base, normal=SOUTH)
    # water stains run down from the top
    streak = value_noise(W, H, 1, seed + 3, sx=5, sy=26)
    stain = (streak > 0.72) & (rel < 6 + (streak - 0.72) * 90) & mask
    s.tint(stain, hexc('#3a2a12'), 0.45)
    ring = stain & ~ndimage.binary_erosion(stain)
    s.tint(ring, hexc('#24170a'), 0.5)
    # peeling paper exposes plaster
    peel = (fbm(W, H, 9, seed + 4, 3) > 0.71) & mask & (rel > 3) & (rel < 28)
    s.paint(peel, ramp=P.PLASTER, value=0.45 + white(W, H, seed + 5) * 0.2)
    curl = ndimage.binary_dilation(peel) & ~peel & mask
    s.paint(curl, ramp=ramp, value=0.95)
    s.bump(mask, peel.astype(np.float32) * -1 + curl * 0.6, 0.5)
    # black mold near the floor
    mold = (fbm(W, H, 6, seed + 6, 3) > 0.62) & mask & (rel > 20)
    s.tint(mold, hexc('#070906'), 0.7)


def mat_baseboard(s, mask, seed=7):
    v = 0.5 + (white(s.w, s.h, seed) - 0.5) * 0.3
    v = np.where((s.yy % 16) == 13, 0.95, v)
    s.paint(mask, ramp=P.BASEBOARD, value=v, normal=SOUTH)


# ---------------------------------------------------------------------------
# background
# ---------------------------------------------------------------------------
def build_background(grid, floor_fns=None, face_fns=None):
    """floor_fns / face_fns: {char: fn(sprite, mask[, top])} for extra room types."""
    H, W = len(grid), len(grid[0])
    g = np.array([list(r) for r in grid])
    wall = g == '#'
    s = Sprite(W * T, H * T)
    s.a[:] = True
    tile = np.repeat(np.repeat(g, T, 0), T, 1)
    xx, yy = s.xx, s.yy

    # classify wall cells
    face_lower = np.zeros_like(wall)
    face_upper = np.zeros_like(wall)
    room_of_face = np.full(g.shape, ' ')
    for y in range(H):
        for x in range(W):
            if not wall[y, x]:
                continue
            if y + 1 < H and not wall[y + 1, x] and g[y + 1, x] != 'D':
                face_lower[y, x] = True
                room_of_face[y, x] = g[y + 1, x]
            elif y + 2 < H and wall[y + 1, x] and not wall[y + 2, x] and g[y + 2, x] != 'D':
                face_upper[y, x] = True
                room_of_face[y, x] = g[y + 2, x]
    up = lambda m: np.repeat(np.repeat(m, T, 0), T, 1)
    fl, fu = up(face_lower), up(face_upper)
    face = fl | fu
    froom = np.repeat(np.repeat(room_of_face, T, 0), T, 1)
    cap = up(wall) & ~face
    floor = ~up(wall)

    # floors
    mat_wood(s, floor & (tile == 'l'), 11)
    mat_carpet(s, floor & (tile == 'b'), 12)
    mat_bath_tiles(s, floor & (tile == 't'), 13)
    mat_linoleum(s, floor & (tile == 'k'), 14)
    door = tile == 'D'

    # face heights: 0 at bottom of the lower cell, FACE at the top of the upper cell
    py = (yy % T).astype(np.float32)
    s.hgt[fl] = (T - 1 - py)[fl] * (FACE / 32.0)
    s.hgt[fu] = (T + T - 1 - py)[fu] * (FACE / 32.0)
    top = np.where(fu, yy - (yy % T), yy - (yy % T) - T)

    for room, ramp, pat, seed in (('b', P.WALLPAPER_BED, 'stripe', 21), ('l', P.WALLPAPER_LIV, 'floral', 22)):
        m = face & (froom == room)
        mat_wallpaper(s, m, top, ramp, seed, pat)
    # bathroom: tiles below, paint above
    m = face & (froom == 't')
    rel = yy - top
    mat_bath_tiles(s, m & (rel >= 14), 31, size=6)
    s.n[m & (rel >= 14)] = np.array(SOUTH) / np.linalg.norm(SOUTH)
    s.paint(m & (rel < 14), ramp=P.BATH_PAINT, value=0.5 + (fbm(s.w, s.h, 8, 32, 3) - 0.5) * 0.5, normal=SOUTH)
    s.paint(m & (rel == 13), ramp=P.PORCELAIN, value=0.8, normal=SOUTH)
    s.paint(m & (rel < 3), ramp=P.BATH_PAINT, value=0.1, normal=SOUTH)
    mold = (fbm(s.w, s.h, 5, 33, 3) > 0.6) & m & (rel < 12)
    s.tint(mold, hexc('#0a0d07'), 0.75)
    # kitchen: dingy paint + backsplash
    m = face & (froom == 'k')
    s.paint(m, ramp=P.KITCHEN_PAINT, value=0.5 + (fbm(s.w, s.h, 10, 41, 3) - 0.5) * 0.4, normal=SOUTH)
    grease = (fbm(s.w, s.h, 7, 42, 3) > 0.58) & m
    s.tint(grease, hexc('#20160a'), 0.5)
    s.paint(m & (rel < 3), ramp=P.KITCHEN_PAINT, value=0.05, normal=SOUTH)
    bs = m & (rel >= 18) & (rel < 28)
    mat_bath_tiles(s, bs, 43, size=5)
    s.n[bs] = np.array(SOUTH) / np.linalg.norm(SOUTH)
    s.tint(bs, hexc('#5a4a20'), 0.3)

    for c, fn in (floor_fns or {}).items():
        fn(s, floor & (tile == c))
    for c, fn in (face_fns or {}).items():
        fn(s, face & (froom == c), top)

    # baseboards on wallpapered faces
    bb = face & ((froom == 'b') | (froom == 'l')) & (rel >= 29)
    mat_baseboard(s, bb)

    # caps
    mat_cap(s, cap)
    # cap edge highlight where it meets floor or a face
    capc = cap.copy()
    near = ndimage.binary_dilation(~cap, structure=np.ones((3, 3))) & cap
    s.paint(near, ramp=P.CAP_EDGE, value=0.6, normal=UP, height=CAP_H)

    # doorway trims (dark vertical lines where the face meets a doorway)
    trim = face & (ndimage.binary_dilation(floor, structure=np.array([[0, 0, 0], [1, 1, 1], [0, 0, 0]])) & face)
    s.paint(trim, ramp=P.DARKWOOD, value=0.35, normal=SOUTH)

    # floor ambient occlusion
    solid = up(wall)
    s.ao_floor(solid, radius=10, strength=0.55)
    # contact shadow right under faces
    below = floor & ndimage.binary_dilation(face, structure=np.array([[0, 1, 0], [0, 1, 0], [0, 0, 0]]), iterations=3)
    s.shade(below, 0.6)

    # front door (south wall, cells marked D)
    if door.any():
        paint_front_door(s, door)
    return s


def paint_front_door(s, door):
    ys, xs = np.where(door)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    m = s.rect_mask(x0, y0, x1 - x0, y1 - y0)
    v = 0.45 + (s.xx % 6 == 0) * -0.2 + (fbm(s.w, s.h, 4, 51, 2) - 0.5) * 0.3
    s.paint(m, ramp=P.DARKWOOD, value=v, normal=UP, height=6)
    frame = m & ~s.rect_mask(x0 + 2, y0, x1 - x0 - 4, y1 - y0)
    s.paint(frame, ramp=P.DARKWOOD, value=0.2, normal=UP, height=CAP_H)
    knob = s.rect_mask(x1 - 6, y0 + 7, 2, 2)
    s.paint(knob, ramp=P.BRASS, value=0.8, normal=UP, height=8)


# ---------------------------------------------------------------------------
# wall decor baked into background
# ---------------------------------------------------------------------------
def decor_window(s, x, y, w=28, h=22):
    """Window with bent blinds; moonlight leaks between slats (emissive)."""
    frame = s.rect_mask(x, y, w, h)
    s.paint(frame, ramp=P.DARKWOOD, value=0.45, normal=SOUTH)
    glass = s.rect_mask(x + 2, y + 2, w - 4, h - 5)
    sky = mix(hexc('#1b2a44'), hexc('#2c3b55'), (s.yy - y) / h)
    s.paint(glass, color=sky, normal=SOUTH)
    s.em[glass] = (hexc('#2a3a5a') * 0.85)
    # distant city glow at the bottom of the pane
    low = glass & (s.yy > y + h - 9)
    s.em[low] = hexc('#4a3a2a') * 0.7
    # blinds
    slats = glass & (((s.yy - y) % 3) != 0)
    bent = s.rect_mask(x + 9, y + 6, 7, 5)
    slats &= ~bent
    s.paint(slats, ramp=P.PAPER, value=0.35 + (s.xx - x) / w * 0.2, normal=SOUTH)
    s.em[slats] *= 0.12
    # mullion
    mul = s.rect_mask(x + w // 2 - 1, y + 2, 1, h - 5)
    s.paint(mul, ramp=P.DARKWOOD, value=0.3, normal=SOUTH)
    s.em[mul] = 0
    sill = s.rect_mask(x - 1, y + h - 3, w + 2, 3)
    s.paint(sill, ramp=P.DARKWOOD, value=0.6, normal=UP)
    s.em[sill] = 0


def decor_poster(s, x, y, w, h, seed, hue='#5a1a1a'):
    m = s.rect_mask(x, y, w, h)
    # torn corner
    torn = s.poly_mask([(x + w - 5, y), (x + w, y), (x + w, y + 6)])
    m &= ~torn
    v = 0.3 + fbm(s.w, s.h, 3, seed, 2) * 0.4
    s.paint(m, ramp=Ramp.from_base(hue, 4), value=v, normal=SOUTH)
    # a pale figure in the middle
    fig = s.ellipse_mask(x + w / 2, y + h * 0.38, 2.5, 3) | s.rect_mask(x + w // 2 - 3, y + int(h * 0.5), 6, h // 3)
    s.paint(fig & m, ramp=P.PAPER, value=0.55, normal=SOUTH)
    eyes = (s.rect_mask(x + w // 2 - 2, y + int(h * 0.36), 1, 1) | s.rect_mask(x + w // 2 + 1, y + int(h * 0.36), 1, 1)) & m
    s.paint(eyes, color=hexc('#000000'), normal=SOUTH)
    txt = s.rect_mask(x + 2, y + h - 4, w - 4, 1) & m
    s.paint(txt, ramp=P.PAPER, value=0.9, normal=SOUTH)
    tape = s.rect_mask(x - 1, y - 1, 3, 2) | s.rect_mask(x + w - 2, y + h - 1, 3, 2)
    s.paint(tape, ramp=P.PAPER, value=0.95, normal=SOUTH)


def decor_mirror(s, x, y, w=16, h=14):
    m = s.rect_mask(x, y, w, h)
    s.paint(m, ramp=P.METAL, value=0.35, normal=SOUTH)
    g = s.rect_mask(x + 1, y + 1, w - 2, h - 2)
    v = 0.35 + (s.xx - x) / w * 0.25 - (s.yy - y) / h * 0.1
    s.paint(g, ramp=P.GLASS_DARK, value=v + 0.3, normal=SOUTH)
    crack = s.line_mask([(x + 3, y + 1), (x + 7, y + 6), (x + 6, y + 9), (x + 10, y + 12)]) | \
        s.line_mask([(x + 7, y + 6), (x + 13, y + 4)]) | s.line_mask([(x + 7, y + 6), (x + 4, y + 11)])
    s.paint(crack & g, ramp=P.PORCELAIN, value=0.85, normal=SOUTH)
    grime = (fbm(s.w, s.h, 3, 61, 2) > 0.6) & g
    s.tint(grime, hexc('#1a1a10'), 0.5)


def decor_cabinets(s, x, y, w, h=11, seed=71):
    m = s.rect_mask(x, y, w, h)
    s.paint(m, ramp=P.LAMINATE, value=0.45 + (fbm(s.w, s.h, 4, seed, 2) - 0.5) * 0.3, normal=SOUTH)
    for dx in range(0, w, 12):
        door = s.rect_mask(x + dx + 1, y + 1, 10, h - 2)
        s.paint(door & ~s.rect_mask(x + dx + 2, y + 2, 8, h - 4), ramp=P.LAMINATE, value=0.2, normal=SOUTH)
        s.paint(s.rect_mask(x + dx + 8, y + h - 4, 1, 2), ramp=P.METAL, value=0.8, normal=SOUTH)
    s.paint(s.rect_mask(x, y + h - 1, w, 1), ramp=P.LAMINATE, value=0.05, normal=SOUTH)
    # one door hangs open: black interior
    od = s.rect_mask(x + 25, y + 1, 10, h - 2)
    s.paint(od, color=hexc('#050505'), normal=SOUTH)
    s.paint(s.rect_mask(x + 35, y, 3, h + 1), ramp=P.LAMINATE, value=0.6, normal=EAST)


def decor_clock_face(s, cx, cy, r=5):
    m = s.ellipse_mask(cx, cy, r + 1, r + 1)
    s.paint(m, ramp=P.PLASTIC_BLK, value=0.3, normal=SOUTH)
    f = s.ellipse_mask(cx, cy, r, r)
    s.paint(f, ramp=P.PAPER, value=0.75, normal=SOUTH)
    for a in range(12):
        ang = a / 12 * np.pi * 2
        px, py = cx + np.cos(ang) * (r - 1), cy + np.sin(ang) * (r - 1)
        s.paint(s.rect_mask(int(px), int(py), 1, 1) & f, ramp=P.PAPER, value=0.2, normal=SOUTH)


def decor_switch(s, x, y):
    s.paint(s.rect_mask(x, y, 3, 5), ramp=P.PORCELAIN, value=0.5, normal=SOUTH)
    s.paint(s.rect_mask(x + 1, y + 2, 1, 1), ramp=P.PORCELAIN, value=0.1, normal=SOUTH)


def decor_crack(s, pts):
    m = s.line_mask(pts)
    s.shade(m, 0.45)


# ---------------------------------------------------------------------------
# flat litter baked into the floor
# ---------------------------------------------------------------------------
def litter(s, rect, count, seed, kinds=('paper', 'can', 'stain', 'crumb', 'butt')):
    r = rng(seed)
    x0, y0, w, h = rect
    for i in range(count):
        k = kinds[r.integers(0, len(kinds))]
        x = int(x0 + r.random() * w)
        y = int(y0 + r.random() * h)
        if k == 'paper':
            m = s.poly_mask([(x, y), (x + 4 + r.integers(0, 3), y + r.integers(-1, 2)), (x + 5, y + 4), (x + 1, y + 3)])
            s.paint(m, ramp=P.PAPER, value=0.4 + r.random() * 0.4, normal=(0.1, 0.2, 1), height=1)
            s.paint(s.rect_mask(x + 1, y + 1, 3, 1) & m, ramp=P.PAPER, value=0.15, height=1)
        elif k == 'can':
            horiz = r.random() < 0.5
            cw, ch = (5, 3) if horiz else (3, 4)
            ramp = [P.COKE_RED, P.METAL, Ramp.from_base('#2e4a2a', 5)][r.integers(0, 3)]
            m = s.rect_mask(x, y, cw, ch)
            s.paint(m, ramp=ramp, value=0.5, normal=UP, height=3)
            s.paint(s.rect_mask(x, y, cw, 1), ramp=ramp, value=0.9, height=3)
            s.paint(s.rect_mask(x + (cw - 1 if horiz else 0), y, 1, ch), ramp=P.METAL, value=0.7, height=3)
        elif k == 'stain':
            m = s.ellipse_mask(x, y, 2 + r.random() * 5, 1.5 + r.random() * 3)
            s.tint(m, hexc('#140c06'), 0.5)
        elif k == 'crumb':
            for _ in range(4):
                s.paint(s.rect_mask(x + r.integers(-3, 4), y + r.integers(-2, 3), 1, 1), ramp=P.CARDBOARD, value=0.7, height=1)
        elif k == 'butt':
            s.paint(s.rect_mask(x, y, 3, 1), ramp=P.PAPER, value=0.85, height=1)
            s.paint(s.rect_mask(x + 2, y, 1, 1), ramp=P.CARDBOARD, value=0.6, height=1)
            s.tint(s.ellipse_mask(x + 1, y + 1, 3, 2), hexc('#202020'), 0.2)


# ---------------------------------------------------------------------------
# props
# ---------------------------------------------------------------------------
def prop_bed():
    s = Sprite(36, 58)
    # frame
    s.box(0, 2, 36, 48, 8, P.DARKWOOD, P.DARKWOOD, 0.4, 0.3)
    # headboard (north, tall)
    s.box(0, 0, 36, 4, 18, P.DARKWOOD, P.DARKWOOD, 0.55, 0.45)
    s.hgt[s.rect_mask(0, 0, 36, 22)] = np.maximum(s.hgt[s.rect_mask(0, 0, 36, 22)], 18)
    # mattress
    mt = s.rect_mask(2, 4, 32, 44)
    st = fbm(36, 58, 5, 81, 3)
    s.paint(mt, ramp=P.MATTRESS, value=0.55 + (st - 0.5) * 0.4, normal=UP, height=12)
    s.tint(mt & (st > 0.66), hexc('#3a2a10'), 0.45)
    # sheet half pulled
    sheet = s.poly_mask([(2, 14), (34, 10), (34, 40), (14, 46), (2, 44)])
    wr = value_noise(36, 58, 1, 82, sx=3, sy=6)
    s.paint(sheet, ramp=P.FABRIC_SHEET, value=0.35 + wr * 0.45, normal=UP, height=13)
    s.bump(sheet, wr, 2.5)
    # crumpled blanket lump
    bl = s.ellipse_mask(22, 30, 13, 9) | s.ellipse_mask(12, 38, 9, 6)
    bn = fbm(36, 58, 4, 83, 3)
    s.paint(bl, ramp=P.FABRIC_BLANKET, value=0.25 + bn * 0.6, normal=UP, height=16)
    s.pillow_normals(bl, 1.2)
    s.bump(bl, bn, 3.0)
    # pillow, stained
    pl = s.ellipse_mask(13, 9, 8, 4)
    s.paint(pl, ramp=P.FABRIC_SHEET, value=0.6, normal=UP, height=15)
    s.pillow_normals(pl, 1.0)
    s.tint(pl & s.ellipse_mask(14, 10, 3, 2), hexc('#4a3a1a'), 0.5)
    # front face shading
    s.outline(0.6)
    return s


def prop_nightstand():
    s = Sprite(16, 34)
    s.box(0, 14, 16, 10, 10, P.DARKWOOD, P.DARKWOOD, 0.5, 0.35)
    s.paint(s.rect_mask(2, 27, 12, 1), ramp=P.DARKWOOD, value=0.1)      # drawer gap
    s.paint(s.rect_mask(7, 29, 2, 1), ramp=P.BRASS, value=0.7)
    # lamp: base + shade
    s.cylinder(5, 12, 1.5, 2, 6, P.BRASS, P.BRASS, base=10)
    shade = s.poly_mask([(1, 3), (9, 3), (11, 11), (-1, 11)])
    s.paint(shade, ramp=Ramp.from_base('#6b5a3a', 5), value=0.55 + (s.xx - 5) * -0.04, normal=SOUTH,
            height=24)
    s.em[shade] = hexc('#6a4a20') * 0.55
    s.em[s.rect_mask(2, 10, 7, 1)] = hexc('#ffd28a')
    s.outline(0.6)
    return s


def prop_wardrobe():
    s = Sprite(30, 58)
    s.box(0, 0, 30, 12, 46, P.DARKWOOD, P.DARKWOOD, 0.45,
          0.42 + value_noise(30, 58, 1, 91, sx=2, sy=12) * 0.15)
    # doors: left closed, right ajar (black gap)
    s.paint(s.rect_mask(14, 13, 1, 44), ramp=P.DARKWOOD, value=0.05)
    s.paint(s.rect_mask(15, 13, 4, 44), color=hexc('#020202'), normal=SOUTH)
    s.paint(s.rect_mask(19, 13, 11, 44), ramp=P.DARKWOOD, value=0.55, normal=(0.4, 0.8, 0.3))
    s.paint(s.rect_mask(11, 32, 1, 4), ramp=P.BRASS, value=0.7)
    s.paint(s.rect_mask(21, 32, 1, 4), ramp=P.BRASS, value=0.7)
    # a sleeve hangs out of the gap
    s.paint(s.rect_mask(16, 38, 2, 9), ramp=P.HOODIE, value=0.4, normal=SOUTH)
    s.outline(0.55)
    return s


def prop_desk():
    s = Sprite(36, 40)
    s.box(0, 14, 36, 12, 14, P.LAMINATE, P.LAMINATE, 0.55, 0.35)
    s.paint(s.rect_mask(3, 27, 30, 12) & ~s.rect_mask(3, 27, 30, 1), color=hexc('#060505'), normal=SOUTH,
            height=0)   # knee space
    s.paint(s.rect_mask(0, 26, 3, 14), ramp=P.LAMINATE, value=0.35, normal=SOUTH)
    s.paint(s.rect_mask(33, 26, 3, 14), ramp=P.LAMINATE, value=0.35, normal=SOUTH)
    # CRT monitor (dead)
    s.box(6, 4, 18, 10, 12, P.CRT, P.CRT, 0.5, 0.45, base=14)
    scr = s.rect_mask(8, 15, 14, 9)
    s.paint(scr, ramp=P.SCREEN_OFF, value=0.4 + (s.xx - 8) * 0.03, normal=SOUTH)
    s.paint(s.rect_mask(9, 16, 4, 1), ramp=P.SCREEN_OFF, value=1.0)
    # keyboard, mug, ash
    s.paint(s.rect_mask(8, 24, 14, 2), ramp=P.PLASTIC_BLK, value=0.5, normal=UP, height=15)
    s.cylinder(29, 18, 2, 2, 3, P.PORCELAIN, P.PORCELAIN, base=14)
    s.paint(s.ellipse_mask(29, 19, 1.4, 0.8), color=hexc('#120a04'), height=17)
    s.outline(0.6)
    return s


def prop_chair():
    s = Sprite(14, 26)
    s.box(1, 0, 12, 3, 12, P.DARKWOOD, P.DARKWOOD, 0.5, 0.45, base=8)
    s.box(0, 12, 14, 8, 6, Ramp.from_base('#3a2e2a', 5), P.DARKWOOD, 0.5, 0.35)
    s.paint(s.rect_mask(1, 26 - 6, 2, 6), ramp=P.DARKWOOD, value=0.3, normal=SOUTH)
    s.paint(s.rect_mask(11, 26 - 6, 2, 6), ramp=P.DARKWOOD, value=0.3, normal=SOUTH)
    s.outline(0.6)
    return s


def prop_clothes_pile(seed):
    s = Sprite(20, 12)
    r = rng(seed)
    ramps = [P.HOODIE, P.JEANS, P.FABRIC_SHEET, Ramp.from_base('#4a2a2a', 5)]
    for i in range(7):
        cx, cy = 4 + r.random() * 12, 4 + r.random() * 5
        m = s.ellipse_mask(cx, cy, 2 + r.random() * 4, 1.5 + r.random() * 2.5)
        s.paint(m, ramp=ramps[i % 4], value=0.3 + r.random() * 0.5, normal=UP, height=3 + i * 0.5)
    s.pillow_normals(None, 1.5)
    s.bump(s.a, fbm(20, 12, 2, seed, 2), 2)
    s.outline(0.65)
    return s


def prop_pizza_boxes():
    s = Sprite(20, 14)
    s.box(0, 4, 18, 8, 2, P.CARDBOARD, P.CARDBOARD, 0.55, 0.3)
    s.box(2, 1, 18, 8, 2, P.CARDBOARD, P.CARDBOARD, 0.65, 0.3, base=2)
    s.tint(s.ellipse_mask(10, 4, 4, 2) & s.a, hexc('#3a1a08'), 0.5)
    s.outline(0.6)
    return s


def prop_backpack():
    s = Sprite(14, 16)
    body = s.ellipse_mask(7, 9, 6, 6.5) & ~s.rect_mask(0, 15, 14, 1)
    v = 0.45 + fbm(14, 16, 3, 101, 2) * 0.3 - (s.xx - 7) * 0.03
    s.paint(body, ramp=P.BACKPACK, value=v, normal=UP)
    s.pillow_normals(body, 1.5)
    s.billboard_height(body, base=0, bottom=15)
    flap = s.ellipse_mask(7, 6, 5, 3.5)
    s.paint(flap, ramp=P.BACKPACK, value=0.7)
    pocket = s.rect_mask(4, 10, 6, 4)
    s.paint(pocket, ramp=P.BACKPACK, value=0.35)
    s.paint(s.rect_mask(4, 10, 6, 1), ramp=P.METAL, value=0.6)
    # newspapers sticking out the top
    np_ = s.poly_mask([(4, 0), (9, 1), (10, 5), (3, 5)])
    s.paint(np_, ramp=P.NEWSPAPER, value=0.6 + ((s.yy % 2) == 0) * -0.2, normal=SOUTH, height=14)
    s.outline(0.6)
    return s


def prop_toilet():
    s = Sprite(14, 26)
    # tank against the wall
    s.box(1, 0, 12, 5, 10, P.PORCELAIN, P.PORCELAIN, 0.6, 0.45, base=6)
    # bowl
    bowl = s.ellipse_mask(7, 15, 6, 5)
    s.paint(bowl, ramp=P.PORCELAIN, value=0.65 - (s.xx - 7) * 0.03, normal=UP, height=10)
    s.pillow_normals(bowl, 0.8)
    inner = s.ellipse_mask(7, 15, 4, 3.2)
    s.paint(inner, color=hexc('#2a2a14'), normal=UP, height=8)
    s.tint(s.ellipse_mask(7, 16, 3, 2), hexc('#3a3010'), 0.5)
    s.paint(s.rect_mask(4, 19, 6, 6), ramp=P.PORCELAIN, value=0.4, normal=SOUTH, height=4)
    s.tint(s.rect_mask(0, 18, 14, 8) & s.a, hexc('#3a3010'), 0.25)
    s.outline(0.6)
    return s


def prop_sink():
    s = Sprite(18, 26)
    s.box(0, 0, 18, 10, 4, P.PORCELAIN, P.PORCELAIN, 0.6, 0.45, base=12)
    basin = s.ellipse_mask(9, 5, 6, 3)
    s.paint(basin, ramp=P.PORCELAIN, value=0.25, normal=(0, -0.3, 1), height=13)
    s.paint(s.rect_mask(8, 1, 2, 2), ramp=P.METAL, value=0.8, height=18)
    s.tint(s.ellipse_mask(10, 6, 2, 1), hexc('#4a3010'), 0.5)
    s.paint(s.rect_mask(6, 14, 6, 12), ramp=P.PORCELAIN, value=0.45 - (s.xx - 9) * 0.04, normal=SOUTH)
    s.billboard_height(s.rect_mask(6, 14, 6, 12), bottom=25)
    s.outline(0.6)
    return s


def prop_bathtub():
    s = Sprite(30, 66)
    s.box(0, 0, 30, 56, 10, P.PORCELAIN, P.PORCELAIN, 0.6, 0.4)
    inner = s.rect_mask(3, 3, 24, 50)
    water = fbm(30, 66, 4, 111, 3)
    s.paint(inner, color=mix(hexc('#1c1a10'), hexc('#3a3518'), water), normal=UP, height=6)
    s.em[inner & (water > 0.75)] = hexc('#0a0a04')
    ring = s.rect_mask(3, 3, 24, 50) & ~s.rect_mask(4, 4, 22, 48)
    s.paint(ring, ramp=P.PORCELAIN, value=0.3, height=8)
    # shower curtain on the west edge, tall, moldy, drawn half closed
    cur = s.rect_mask(0, 0, 3, 40)
    folds = (s.yy % 4)
    s.paint(cur, ramp=Ramp.from_base('#5a6a6a', 5), value=0.3 + folds * 0.12, normal=WEST, height=44)
    mold = (fbm(30, 66, 3, 112, 2) > 0.55) & cur
    s.tint(mold, hexc('#101808'), 0.6)
    s.outline(0.6)
    return s


def prop_curtain():
    """Separate tall curtain sprite standing at the tub's west edge."""
    s = Sprite(6, 70)
    m = s.rect_mask(0, 0, 6, 70)
    folds = (s.xx % 3)
    v = 0.3 + folds * 0.18 + value_noise(6, 70, 1, 113, sx=2, sy=10) * 0.2
    s.paint(m, ramp=Ramp.from_base('#56645f', 5), value=v, normal=(0.2, 0.9, 0.3))
    s.billboard_height(m, bottom=69)
    s.hgt[m] = np.minimum(s.hgt[m], 46)
    mold = (fbm(6, 70, 3, 114, 2) > 0.55) & m & (s.yy > 40)
    s.tint(mold, hexc('#0d1407'), 0.65)
    # rod rings
    s.paint(s.rect_mask(0, 0, 6, 2), ramp=P.METAL, value=0.6)
    s.outline(0.6)
    return s


def prop_counter(w=96):
    s = Sprite(w, 34)
    s.box(0, 0, w, 14, 18, Ramp.from_base('#5a5446', 5), P.LAMINATE, 0.5, 0.42)
    s.tint(s.rect_mask(0, 0, w, 14) & (fbm(w, 34, 5, 121, 3) > 0.6), hexc('#2a1a0a'), 0.4)
    for dx in range(2, w - 4, 16):
        s.paint(s.rect_mask(dx, 16, 14, 16) & ~s.rect_mask(dx + 1, 17, 12, 14), ramp=P.LAMINATE, value=0.2)
        s.paint(s.rect_mask(dx + 11, 19, 1, 3), ramp=P.METAL, value=0.7)
    # sink with dish mountain at x 8..30
    s.paint(s.rect_mask(8, 2, 22, 10), ramp=P.METAL, value=0.3, normal=UP, height=16)
    s.paint(s.rect_mask(10, 3, 18, 8), color=hexc('#14130e'), normal=UP, height=14)
    r = rng(122)
    for i in range(9):
        cx, cy = 12 + r.random() * 14, 4 + r.random() * 6
        m = s.ellipse_mask(cx, cy, 2.5 + r.random(), 1.5)
        s.paint(m, ramp=P.PORCELAIN, value=0.4 + r.random() * 0.4, normal=UP, height=17 + i)
        s.tint(m & (white(w, 34, 123 + i) > 0.6), hexc('#3a2a10'), 0.5)
    s.paint(s.rect_mask(18, 0, 2, 3), ramp=P.METAL, value=0.8, height=24)
    # stove at x 40..64
    s.box(40, 0, 24, 14, 18, P.CRT, WHITE_STOVE, 0.4, 0.4)
    for bx, by in ((45, 4), (57, 4), (45, 10), (57, 10)):
        s.paint(s.ellipse_mask(bx, by, 3, 2), ramp=P.METAL, value=0.2, normal=UP, height=18)
    # pot with something old in it
    s.cylinder(57, 2, 4, 4, 5, P.METAL, P.METAL, base=18)
    s.paint(s.ellipse_mask(57, 4, 3, 1.4), color=hexc('#1f2a10'), height=23)
    s.paint(s.rect_mask(42, 17, 20, 9) & ~s.rect_mask(43, 18, 18, 7), ramp=P.METAL, value=0.4)
    s.paint(s.rect_mask(43, 18, 18, 7), color=hexc('#060606'), normal=SOUTH)
    for kx in range(42, 62, 5):
        s.paint(s.rect_mask(kx, 15, 2, 1), ramp=P.PLASTIC_BLK, value=0.6)
    # microwave at x 72..92 on the counter (clock glow drawn separately)
    s.box(70, -2, 22, 10, 10, P.WHITE_APPL, P.WHITE_APPL, 0.4, 0.35, base=18)
    s.paint(s.rect_mask(72, 9, 13, 7), ramp=P.GLASS_DARK, value=0.3, normal=SOUTH)
    s.paint(s.rect_mask(86, 9, 5, 7), ramp=P.PLASTIC_BLK, value=0.4, normal=SOUTH)
    clock = s.rect_mask(87, 10, 3, 1)
    s.em[clock] = hexc('#30ff70') * 0.9
    s.col[clock] = hexc('#1a6a30')
    s.outline(0.6)
    return s


WHITE_STOVE = P.WHITE_APPL.darker(0.85)


def prop_fridge(open_=False):
    w = 24 if not open_ else 38
    s = Sprite(w, 54)
    v = 0.5 + (fbm(w, 54, 4, 131, 3) - 0.5) * 0.25
    s.box(0, 0, 24, 14, 40, P.WHITE_APPL, P.WHITE_APPL, 0.55, v)
    if not open_:
        s.paint(s.rect_mask(0, 27, 24, 1), ramp=P.WHITE_APPL, value=0.1)
        s.paint(s.rect_mask(20, 17, 2, 7), ramp=P.METAL, value=0.75)
        s.paint(s.rect_mask(20, 30, 2, 12), ramp=P.METAL, value=0.75)
        # magnets, a note, grime
        s.paint(s.rect_mask(4, 18, 5, 6), ramp=P.PAPER, value=0.75)
        s.paint(s.rect_mask(5, 20, 3, 1), ramp=P.PAPER, value=0.2)
        s.paint(s.rect_mask(5, 22, 2, 1), ramp=P.PAPER, value=0.2)
        s.paint(s.rect_mask(5, 17, 2, 2), ramp=P.COKE_RED, value=0.6)
        s.paint(s.rect_mask(11, 33, 3, 3), ramp=Ramp.from_base('#2a6a4a', 4), value=0.6)
        s.tint(s.rect_mask(0, 44, 24, 10), hexc('#2a2010'), 0.3)
    else:
        inside = s.rect_mask(1, 15, 22, 38)
        s.paint(inside, ramp=Ramp.from_base('#9aa49a', 5), value=0.5 + (s.yy - 15) * -0.008, normal=SOUTH)
        s.em[inside] = hexc('#7a8a7e') * 0.55
        for sy in (24, 33, 42):
            sh = s.rect_mask(1, sy, 22, 1)
            s.paint(sh, ramp=P.PORCELAIN, value=0.9)
            s.em[sh] = hexc('#a0b0a0') * 0.7
        # leftovers: a moldy container, a jar, a stain
        mc = s.rect_mask(3, 37, 8, 5)
        s.paint(mc, ramp=Ramp.from_base('#4a5a3a', 4), value=0.5)
        s.em[mc] *= 0.2
        jar = s.rect_mask(15, 28, 4, 5)
        s.paint(jar, ramp=Ramp.from_base('#5a3a1a', 4), value=0.5)
        s.em[jar] *= 0.3
        s.tint(s.rect_mask(2, 47, 18, 4) & inside, hexc('#3a1010'), 0.4)
        bulb = s.rect_mask(9, 16, 6, 2)
        s.em[bulb] = hexc('#e8f8ea')
        # the door, swung open to the east
        door = s.rect_mask(24, 13, 13, 41)
        s.paint(door, ramp=P.WHITE_APPL, value=0.35 + (s.xx - 24) * 0.02, normal=EAST)
        s.billboard_height(door, bottom=53)
        s.hgt[door] = np.minimum(s.hgt[door], 40)
        s.paint(s.rect_mask(25, 22, 11, 1), ramp=P.WHITE_APPL, value=0.7)
        s.paint(s.rect_mask(25, 35, 11, 1), ramp=P.WHITE_APPL, value=0.7)
    s.outline(0.6)
    return s


def prop_trashcan():
    s = Sprite(14, 24)
    s.cylinder(7, 6, 6, 5, 13, P.METAL, P.METAL)
    # overflowing garbage on top
    r = rng(141)
    for i in range(8):
        m = s.ellipse_mask(3 + r.random() * 8, 3 + r.random() * 5, 2 + r.random() * 2, 1.5 + r.random())
        rp = [P.TRASHBAG, P.CARDBOARD, P.PAPER, P.COKE_RED][i % 4]
        s.paint(m, ramp=rp, value=0.3 + r.random() * 0.5, normal=UP, height=14 + i * 0.5)
    s.outline(0.6)
    return s


def prop_trashbag(seed):
    s = Sprite(18, 16)
    r = rng(seed)
    body = s.ellipse_mask(9, 9, 8, 6.5) | s.ellipse_mask(9 + r.integers(-2, 3), 4, 4, 3)
    n = fbm(18, 16, 3, seed, 3)
    s.paint(body, ramp=P.TRASHBAG, value=0.25 + n * 0.5 - (s.xx - 9) * 0.03, normal=UP)
    s.pillow_normals(body, 1.6)
    s.bump(body, n, 3)
    s.billboard_height(body, bottom=15)
    # plastic shine
    sh = s.rect_mask(5, 6, 2, 1) | s.rect_mask(11, 9, 1, 2)
    s.paint(sh & body, ramp=P.TRASHBAG, value=1.0)
    s.paint(s.rect_mask(8, 0, 3, 2) & ~body, ramp=P.TRASHBAG, value=0.5, height=14)
    s.outline(0.6)
    return s


def prop_table():
    s = Sprite(36, 28)
    s.box(0, 2, 36, 18, 2, P.LAMINATE, P.LAMINATE, 0.5, 0.3, base=10)
    s.tint(s.rect_mask(0, 2, 36, 18) & (fbm(36, 28, 5, 151, 2) > 0.6), hexc('#20140a'), 0.45)
    for lx in (1, 33):
        s.paint(s.rect_mask(lx, 22, 2, 6), ramp=P.LAMINATE, value=0.25, normal=SOUTH)
        s.billboard_height(s.rect_mask(lx, 22, 2, 6), bottom=27)
    # takeout boxes, cans, ashtray
    s.box(4, 5, 8, 6, 4, Ramp.from_base('#8a8a80', 4), Ramp.from_base('#8a8a80', 4), 0.7, 0.4, base=12)
    s.cylinder(18, 6, 2, 2, 4, P.COKE_RED, P.COKE_RED, base=12)
    s.cylinder(23, 10, 2, 2, 4, P.METAL, P.METAL, base=12)
    s.paint(s.ellipse_mask(30, 12, 3, 2), ramp=P.METAL, value=0.3, height=13)
    s.paint(s.rect_mask(29, 11, 2, 1), ramp=P.PAPER, value=0.8, height=14)
    s.outline(0.6)
    return s


def prop_couch():
    s = Sprite(64, 32)
    # seen from behind-ish: seat faces north toward the TV, backrest at the south
    s.box(0, 0, 64, 16, 8, P.COUCH, P.COUCH, 0.55, 0.35)
    s.box(0, 14, 64, 6, 12, P.COUCH, P.COUCH, 0.6, 0.4)           # backrest at south edge
    s.box(0, 0, 6, 16, 12, P.COUCH, P.COUCH, 0.65, 0.4)           # arms
    s.box(58, 0, 6, 16, 12, P.COUCH, P.COUCH, 0.6, 0.4)
    cush = fbm(64, 32, 4, 161, 3)
    s.bump(s.rect_mask(6, 0, 52, 16), cush, 2.5)
    s.paint(s.rect_mask(31, 1, 1, 13), ramp=P.COUCH, value=0.1, height=8)
    s.tint(s.rect_mask(0, 0, 64, 32) & (cush > 0.65) & s.a, hexc('#20180a'), 0.4)
    # torn spot with stuffing
    s.paint(s.ellipse_mask(48, 22, 3, 2), ramp=P.PAPER, value=0.75, height=10)
    # a blanket thrown over the left side
    bl = s.poly_mask([(4, 0), (22, 0), (24, 26), (8, 28)])
    s.paint(bl & s.a, ramp=P.FABRIC_BLANKET, value=0.35 + cush * 0.4)
    s.outline(0.6)
    return s


def prop_tv():
    s = Sprite(32, 40)
    # stand
    s.box(0, 14, 32, 10, 14, P.DARKWOOD, P.DARKWOOD, 0.45, 0.35)
    s.paint(s.rect_mask(3, 26, 26, 11) & ~s.rect_mask(4, 27, 24, 9), ramp=P.DARKWOOD, value=0.2)
    s.paint(s.rect_mask(5, 29, 9, 3), ramp=P.PLASTIC_BLK, value=0.5)          # VCR
    s.em[s.rect_mask(11, 30, 2, 1)] = hexc('#ff3010') * 0.8
    # CRT body
    s.box(4, 0, 24, 8, 16, P.CRT, P.CRT, 0.45, 0.4, base=14)
    screen = s.rect_mask(7, 10, 18, 11)
    s.paint(screen, ramp=P.SCREEN_OFF, value=0.5, normal=SOUTH)
    s.paint(s.rect_mask(25, 10, 2, 11), ramp=P.CRT, value=0.25)
    # antenna
    s.paint(s.line_mask([(16, 0), (10, -8)]), ramp=P.METAL, value=0.6)
    s.outline(0.6)
    return s


def tv_static_frames(n=4):
    """Emissive-only overlays for the TV screen (18x11)."""
    frames = []
    for i in range(n):
        s = Sprite(18, 11)
        m = s.rect_mask(0, 0, 18, 11)
        nz = white(18, 11, 170 + i)
        rows = value_noise(18, 11, 1, 190 + i, sx=40, sy=2)
        v = nz * 0.7 + rows * 0.3
        c = mix(hexc('#20262c'), hexc('#c8d6e0'), v[..., None])
        s.paint(m, color=c, normal=SOUTH, height=24)
        s.em[m] = c[m] * 0.9
        # curvature / vignette of the tube
        edge = ~s.ellipse_mask(9, 5.5, 10.5, 7.5) & m
        s.em[edge] *= 0.35
        s.col[edge] *= 0.35
        frames.append(s)
    return strip(frames)


def prop_coffee_table():
    s = Sprite(40, 22)
    s.box(0, 0, 40, 14, 6, P.LAMINATE, P.LAMINATE, 0.45, 0.35)
    s.tint(s.rect_mask(0, 0, 40, 14) & (fbm(40, 22, 4, 201, 2) > 0.58), hexc('#1a1006'), 0.5)
    # bottles, pill bottle, ashtray overflowing
    for i, bx in enumerate((5, 9, 30)):
        s.cylinder(bx, 1 + i, 1.5, 2, 7, Ramp.from_base('#3a5a2a', 5), Ramp.from_base('#2a4a1a', 5), base=6)
    s.cylinder(19, 5, 1.5, 2, 3, Ramp.from_base('#b0602a', 4), Ramp.from_base('#b0602a', 4), base=6)
    s.paint(s.rect_mask(18, 5, 3, 1), ramp=P.PORCELAIN, value=0.9, height=10)
    s.paint(s.ellipse_mask(25, 9, 4, 2), ramp=P.METAL, value=0.3, height=7)
    for k in range(4):
        s.paint(s.rect_mask(23 + k, 8 + (k % 2), 2, 1), ramp=P.PAPER, value=0.8, height=8)
    s.tint(s.ellipse_mask(25, 10, 6, 3) & s.a & ~s.ellipse_mask(25, 9, 4, 2), hexc('#202020'), 0.35)
    s.paint(s.rect_mask(12, 9, 6, 3), ramp=P.PAPER, value=0.55, height=7)   # receipts
    s.outline(0.6)
    return s


def prop_bookshelf():
    s = Sprite(32, 50)
    s.box(0, 0, 32, 10, 38, P.DARKWOOD, P.DARKWOOD, 0.45, 0.3)
    r = rng(211)
    for sy in (12, 22, 32, 42):
        s.paint(s.rect_mask(1, sy + 8, 30, 1), ramp=P.DARKWOOD, value=0.6)
        x = 2
        while x < 29:
            bw = int(r.integers(1, 4))
            bh = int(r.integers(4, 8))
            if r.random() < 0.2:
                x += bw + 1
                continue
            rp = Ramp.from_base(['#4a2020', '#203a4a', '#3a3a20', '#2a2a2a', '#4a3a2a'][r.integers(0, 5)], 4)
            s.paint(s.rect_mask(x, sy + 8 - bh, bw, bh), ramp=rp, value=0.35 + r.random() * 0.4)
            x += bw
    s.outline(0.6)
    return s


def prop_shoe_pile():
    s = Sprite(18, 10)
    r = rng(221)
    for i in range(5):
        cx, cy = 3 + r.random() * 12, 3 + r.random() * 4
        m = s.ellipse_mask(cx, cy, 3, 1.6)
        s.paint(m, ramp=[P.SHOE, P.PLASTIC_BLK][i % 2], value=0.35 + r.random() * 0.4, normal=UP, height=3)
    s.pillow_normals(None, 1.0)
    s.outline(0.65)
    return s


def prop_coat_rack():
    s = Sprite(14, 50)
    s.paint(s.rect_mask(6, 4, 2, 44), ramp=P.DARKWOOD, value=0.5, normal=SOUTH)
    s.paint(s.ellipse_mask(7, 47, 5, 2), ramp=P.DARKWOOD, value=0.4, normal=UP)
    coat = s.poly_mask([(3, 6), (11, 6), (13, 30), (1, 30)])
    s.paint(coat, ramp=Ramp.from_base('#2c2a26', 5), value=0.4 + (s.yy % 5 == 0) * 0.1 - (s.xx - 7) * 0.03,
            normal=SOUTH)
    s.pillow_normals(coat, 0.8)
    s.billboard_height(None, bottom=48)
    s.outline(0.55)
    return s


def prop_doormat():
    s = Sprite(30, 10)
    m = s.rect_mask(0, 0, 30, 10)
    s.paint(m, ramp=Ramp.from_base('#3a2a1e', 4), value=0.3 + white(30, 10, 231) * 0.4, normal=UP, height=1)
    s.paint(m & ~s.rect_mask(1, 1, 28, 8), ramp=Ramp.from_base('#3a2a1e', 4), value=0.1, height=1)
    return s


def prop_bathmat():
    s = Sprite(20, 12)
    m = s.rect_mask(0, 0, 20, 12)
    s.paint(m, ramp=Ramp.from_base('#4a5a5a', 4), value=0.4 + white(20, 12, 232) * 0.3, normal=UP, height=1)
    s.tint(m & (fbm(20, 12, 3, 233, 2) > 0.55), hexc('#2a2410'), 0.5)
    return s


def prop_puddle():
    s = Sprite(22, 10)
    m = s.ellipse_mask(11, 5, 10, 4) | s.ellipse_mask(6, 6, 5, 3)
    s.paint(m, color=hexc('#14181a'), normal=UP, height=0)
    s.paint(s.rect_mask(6, 3, 6, 1) & m, color=hexc('#4a5a62'), height=0)
    return s


def prop_coin():
    s = Sprite(5, 5)
    m = s.ellipse_mask(2.5, 2.5, 2.4, 1.8)
    s.paint(m, ramp=P.GOLD, value=0.55 - (s.xx - 2) * 0.12 - (s.yy - 2) * 0.1, normal=UP, height=1)
    s.paint(s.rect_mask(1, 1, 1, 1), ramp=P.GOLD, value=1.0)
    s.em[m] = hexc('#3a2a08') * 0.6
    return s


def prop_key():
    s = Sprite(9, 5)
    ring = s.ellipse_mask(2, 2.5, 2, 2) & ~s.ellipse_mask(2, 2.5, 0.8, 0.8)
    s.paint(ring, ramp=P.BRASS, value=0.6, normal=UP, height=1)
    blade = s.rect_mask(4, 2, 5, 1) | s.rect_mask(6, 3, 1, 1) | s.rect_mask(8, 3, 1, 1)
    s.paint(blade, ramp=P.BRASS, value=0.75, normal=UP, height=1)
    s.em[ring | blade] = hexc('#2a2008') * 0.5
    return s


def prop_phone():
    s = Sprite(5, 8)
    m = s.rect_mask(0, 0, 5, 8)
    s.paint(m, ramp=P.PHONE, value=0.5, normal=UP, height=1)
    scr = s.rect_mask(1, 1, 3, 6)
    s.paint(scr, color=hexc('#1a2a40'), height=1)
    s.em[scr] = hexc('#4a7ac0') * 0.8
    return s


def prop_roach():
    frames = []
    for i in range(2):
        s = Sprite(5, 4)
        body = s.ellipse_mask(2.5, 2, 1.8, 1.2)
        s.paint(body, ramp=Ramp.from_base('#3a1a0a', 4), value=0.6, normal=UP, height=1)
        legs = s.rect_mask(0, (0 if i == 0 else 3), 1, 1) | s.rect_mask(4, (3 if i == 0 else 0), 1, 1) | \
            s.rect_mask(2, (0 if i else 3), 1, 1)
        s.paint(legs, color=hexc('#120804'), height=1)
        s.paint(s.rect_mask(2, 1, 1, 1), ramp=Ramp.from_base('#3a1a0a', 4), value=1.0)
        frames.append(s)
    return strip(frames)


def prop_light_fixture():
    """Bathroom fluorescent tube mounted on the wall face (emissive flicker in engine)."""
    s = Sprite(20, 5)
    s.paint(s.rect_mask(0, 0, 20, 5), ramp=P.METAL, value=0.4, normal=SOUTH, height=34)
    tube = s.rect_mask(1, 2, 18, 2)
    s.paint(tube, ramp=P.PORCELAIN, value=0.9, normal=SOUTH, height=33)
    s.em[tube] = hexc('#d8f0e0')
    s.paint(s.rect_mask(14, 2, 4, 2), ramp=P.METAL, value=0.2)   # dead end of the tube
    s.em[s.rect_mask(14, 2, 4, 2)] = hexc('#3a2a20')
    return s


def prop_door_light():
    """Strip of corridor light under the front door (emissive, animated in engine)."""
    s = Sprite(26, 2)
    m = s.rect_mask(0, 0, 26, 2)
    s.paint(m, color=hexc('#a08a50'), normal=UP, height=1)
    s.em[m] = hexc('#e0b060')
    s.em[s.rect_mask(0, 1, 26, 1)] *= 0.5
    return s


def build_props():
    out = {
        'bed': prop_bed(),
        'nightstand': prop_nightstand(),
        'wardrobe': prop_wardrobe(),
        'desk': prop_desk(),
        'chair': prop_chair(),
        'clothes_a': prop_clothes_pile(301),
        'clothes_b': prop_clothes_pile(302),
        'clothes_c': prop_clothes_pile(303),
        'pizza_boxes': prop_pizza_boxes(),
        'backpack': prop_backpack(),
        'toilet': prop_toilet(),
        'sink': prop_sink(),
        'bathtub': prop_bathtub(),
        'curtain': prop_curtain(),
        'counter': prop_counter(),
        'fridge': prop_fridge(False),
        'fridge_open': prop_fridge(True),
        'trashcan': prop_trashcan(),
        'trashbag_a': prop_trashbag(311),
        'trashbag_b': prop_trashbag(312),
        'trashbag_c': prop_trashbag(313),
        'table': prop_table(),
        'chair_k': prop_chair(),
        'couch': prop_couch(),
        'tv': prop_tv(),
        'tv_static': tv_static_frames(),
        'coffee_table': prop_coffee_table(),
        'bookshelf': prop_bookshelf(),
        'shoe_pile': prop_shoe_pile(),
        'coat_rack': prop_coat_rack(),
        'doormat': prop_doormat(),
        'bathmat': prop_bathmat(),
        'puddle': prop_puddle(),
        'coin': prop_coin(),
        'key': prop_key(),
        'phone': prop_phone(),
        'roach': prop_roach(),
        'tube_light': prop_light_fixture(),
        'door_light': prop_door_light(),
    }
    return out


def build(grid_path):
    grid = load_grid(grid_path)
    bg = build_background(grid)
    # wall decor (pixel coords; faces of the north wall span y 16..48,
    # faces of the living-room wall span y 192..224)
    decor_window(bg, 70, 19)
    decor_poster(bg, 150, 21, 14, 18, 401, '#4a1414')
    decor_poster(bg, 172, 24, 10, 13, 402, '#14243a')
    decor_switch(bg, 26, 34)
    decor_crack(bg, [(120, 17), (124, 24), (122, 30), (127, 38)])
    decor_mirror(bg, 289, 18)
    decor_cabinets(bg, 370, 18, 84)
    decor_cabinets(bg, 506, 18, 48)
    decor_clock_face(bg, 150, 202)
    decor_poster(bg, 60, 197, 12, 16, 403, '#2a2a14')   # faded "MISSING" flyer
    decor_switch(bg, 300, 208)
    decor_crack(bg, [(420, 194), (418, 202), (423, 210)])
    # litter
    litter(bg, (24, 110, 190, 60), 26, 501)
    litter(bg, (250, 120, 80, 50), 6, 502, ('stain', 'crumb', 'paper'))
    litter(bg, (372, 100, 180, 70), 30, 503)
    litter(bg, (24, 232, 520, 110), 46, 504)
    return bg, build_props()
