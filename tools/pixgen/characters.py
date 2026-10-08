"""Player character sheet (20x32 frames) and the night figure.

Sheet layout: rows = down, left, right, up; columns = idle0, idle1, walk0..walk3.
Light is baked softly from the upper-left; the engine relights with normals.
"""
import numpy as np

from . import palette as P
from .core import Sprite, Ramp, sheet, hexc

FW, FH = 20, 32


def shade_part(s, mask, ramp, base, cx, half, top=None, vgrad=0.0):
    """Paint a body part with left-lit horizontal shading."""
    v = base - 0.28 * (s.xx + 0.5 - cx) / max(half, 1)
    if top is not None:
        v = v - vgrad * (s.yy - top) / 10.0
    s.paint(mask, ramp=ramp, value=v, dither=False)


def finish(s, bottom=31):
    # normals: upright body facing the viewer, rounded at the silhouette
    s.pillow_normals(None, 1.0)
    n = s.n.copy()
    n[..., 1] = 0.55 + n[..., 1] * 0.4
    n[..., 2] = 0.55
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    s.n[s.a] = n[s.a]
    s.billboard_height(None, bottom=bottom)
    s.outline(0.5)
    return s


def front(walk=0, back=False, breathe=0):
    """walk: 0 idle, 1..4 walk frames."""
    s = Sprite(FW, FH)
    R = s.rect_mask
    legL = legR = 0          # how much each foot is lifted
    armL = armR = 0          # vertical arm swing
    bob = 0
    if walk == 1:
        legR, armL, armR = 2, 1, -1
    elif walk == 2:
        bob = -1
    elif walk == 3:
        legL, armL, armR = 2, -1, 1
    elif walk == 4:
        bob = -1
    by = bob + breathe
    # shoes
    s.paint(R(5, 29 - legL, 4, 3) & ~R(5, 31 - legL + 1, 4, 3), ramp=P.SHOE, value=0.6, dither=False)
    s.paint(R(11, 29 - legR, 4, 3) & ~R(11, 31 - legR + 1, 4, 3), ramp=P.SHOE, value=0.5, dither=False)
    s.paint(R(5, 31 - legL, 4, 1), ramp=P.SHOE, value=0.15, dither=False)
    s.paint(R(11, 31 - legR, 4, 1), ramp=P.SHOE, value=0.15, dither=False)
    # legs
    shade_part(s, R(6, 22 + by, 3, 7 - legL - by), P.JEANS, 0.55, 7.5, 2)
    shade_part(s, R(11, 22 + by, 3, 7 - legR - by), P.JEANS, 0.45, 12.5, 2)
    shade_part(s, R(6, 21 + by, 8, 2), P.JEANS, 0.5, 10, 4)
    # torso (hoodie)
    torso = R(6, 12 + by, 8, 10) | R(5, 13 + by, 10, 3)
    shade_part(s, torso, P.HOODIE, 0.62, 10, 5, top=12 + by, vgrad=0.15)
    s.paint(R(6, 21 + by, 8, 1), ramp=P.HOODIE, value=0.2, dither=False)       # hem
    if not back:
        s.paint(R(7, 17 + by, 6, 1), ramp=P.HOODIE, value=0.25, dither=False)   # pocket line
        s.paint(R(7, 18 + by, 1, 2) | R(12, 18 + by, 1, 2), ramp=P.HOODIE, value=0.3, dither=False)
        s.paint(R(8, 12 + by, 1, 3) | R(11, 12 + by, 1, 3), ramp=P.PAPER, value=0.55, dither=False)
        s.paint(R(9, 15 + by, 2, 1), ramp=Ramp.from_base('#3a2a18', 4), value=0.5, dither=False)  # stain
        s.paint(R(7, 11 + by, 6, 1), ramp=P.HOODIE, value=0.3, dither=False)   # collar
    else:
        hood = R(7, 11 + by, 6, 4)
        shade_part(s, hood, P.HOODIE, 0.5, 10, 3)
        s.paint(R(7, 14 + by, 6, 1), ramp=P.HOODIE, value=0.25, dither=False)
    # arms + hands
    for ax, sw, base in ((4, armL, 0.65), (14, armR, 0.4)):
        shade_part(s, R(ax, 13 + by + sw, 2, 7), P.HOODIE, base, ax + 1, 1)
        s.paint(R(ax, 20 + by + sw, 2, 2), ramp=P.SKIN, value=base * 0.9 + 0.1, dither=False)
    # neck + head
    s.paint(R(9, 11 + by, 2, 1), ramp=P.SKIN, value=0.3, dither=False)
    head = R(7, 4 + by, 6, 7) | R(6, 5 + by, 8, 5)
    if back:
        shade_part(s, head, P.HAIR, 0.7, 10, 4)
        s.paint(R(7, 10 + by, 6, 1), ramp=P.HAIR, value=0.35, dither=False)
        s.paint(R(6, 7 + by, 1, 2) | R(13, 7 + by, 1, 2), ramp=P.SKIN, value=0.3, dither=False)
    else:
        shade_part(s, head, P.SKIN, 0.72, 10, 4)
        # stubble jaw
        jaw = R(7, 9 + by, 6, 2)
        s.paint(jaw & ((s.xx + s.yy) % 2 == 0), ramp=P.SKIN, value=0.35, dither=False)
        s.paint(R(6, 7 + by, 1, 2), ramp=P.SKIN, value=0.4, dither=False)
        s.paint(R(13, 7 + by, 1, 2), ramp=P.SKIN, value=0.25, dither=False)
        # eyes with bags, brows, nose, mouth
        s.paint(R(8, 7 + by, 1, 1) | R(11, 7 + by, 1, 1), color=hexc('#0b0808'), dither=False)
        s.paint(R(8, 8 + by, 1, 1) | R(11, 8 + by, 1, 1), ramp=P.SKIN, value=0.3, dither=False)
        s.paint(R(8, 6 + by, 1, 1) | R(11, 6 + by, 1, 1), ramp=P.HAIR, value=0.5, dither=False)
        s.paint(R(10, 8 + by, 1, 1), ramp=P.SKIN, value=0.45, dither=False)
        s.paint(R(9, 10 + by, 2, 1), ramp=P.SKIN, value=0.2, dither=False)
    # messy hair on top
    hair = R(6, 3 + by, 8, 3) | R(7, 2 + by, 2, 1) | R(10, 2 + by, 1, 1) | R(12, 2 + by, 1, 2) | R(6, 5 + by, 1, 2) | R(13, 5 + by, 1, 3)
    if not back:
        hair |= R(7, 5 + by, 2, 1)
    shade_part(s, hair, P.HAIR, 0.75, 9, 4)
    s.paint(R(8, 3 + by, 1, 1) | R(11, 3 + by, 1, 1), ramp=P.HAIR, value=1.0, dither=False)
    return finish(s)


def side(walk=0, breathe=0):
    """Facing left."""
    s = Sprite(FW, FH)
    R = s.rect_mask
    bob = -1 if walk in (2, 4) else 0
    by = bob + breathe
    # leg placement: (front leg x, back leg x)
    if walk == 1:
        fl, bl, lift = 6, 11, (0, 1)
    elif walk == 3:
        fl, bl, lift = 11, 6, (1, 0)
    else:
        fl, bl, lift = 8, 9, (0, 0)
    if walk == 0:
        fl, bl = 8, 10
    # back leg (darker) then front leg
    for lx, base, lf in ((bl, 0.3, lift[1]), (fl, 0.55, lift[0])):
        shade_part(s, R(lx, 22 + by, 3, 7 - lf - by), P.JEANS, base, lx + 1.5, 2)
        s.paint(R(lx - 1, 29 - lf, 4, 2), ramp=P.SHOE, value=base + 0.1, dither=False)
        s.paint(R(lx - 1, 31 - lf, 4, 1), ramp=P.SHOE, value=0.15, dither=False)
    shade_part(s, R(7, 21 + by, 6, 2), P.JEANS, 0.5, 10, 3)
    # torso
    torso = R(7, 12 + by, 6, 10)
    shade_part(s, torso, P.HOODIE, 0.6, 9.5, 3, top=12 + by, vgrad=0.15)
    s.paint(R(12, 11 + by, 2, 4), ramp=P.HOODIE, value=0.35, dither=False)  # hood on the back
    s.paint(R(7, 21 + by, 6, 1), ramp=P.HOODIE, value=0.2, dither=False)
    # arm swing
    sw = {0: 0, 1: -2, 2: 0, 3: 2, 4: 0}[walk]
    arm = R(9 + sw // 2, 13 + by, 2, 7)
    shade_part(s, arm, P.HOODIE, 0.45, 10, 1)
    s.paint(R(9 + sw, 20 + by, 2, 2), ramp=P.SKIN, value=0.55, dither=False)
    s.paint(R(9 + sw // 2, 19 + by, 2, 1), ramp=P.HOODIE, value=0.3, dither=False)
    # head
    s.paint(R(9, 11 + by, 2, 1), ramp=P.SKIN, value=0.3, dither=False)
    head = R(7, 4 + by, 6, 7)
    shade_part(s, head, P.SKIN, 0.7, 9, 3)
    s.paint(R(6, 7 + by, 1, 2), ramp=P.SKIN, value=0.6, dither=False)            # nose
    s.paint(R(8, 7 + by, 1, 1), color=hexc('#0b0808'), dither=False)              # eye
    s.paint(R(8, 8 + by, 1, 1), ramp=P.SKIN, value=0.3, dither=False)
    s.paint(R(7, 10 + by, 2, 1), ramp=P.SKIN, value=0.25, dither=False)           # mouth/stubble
    s.paint(R(7, 9 + by, 3, 2) & ((s.xx + s.yy) % 2 == 0), ramp=P.SKIN, value=0.35, dither=False)
    s.paint(R(10, 7 + by, 1, 2), ramp=P.SKIN, value=0.35, dither=False)           # ear
    hair = R(7, 3 + by, 7, 3) | R(11, 5 + by, 3, 4) | R(8, 2 + by, 2, 1) | R(12, 2 + by, 1, 1) | R(13, 8 + by, 1, 2) | R(7, 5 + by, 2, 1)
    shade_part(s, hair, P.HAIR, 0.72, 9, 4)
    s.paint(R(9, 3 + by, 1, 1), ramp=P.HAIR, value=1.0, dither=False)
    return finish(s)


def player_sheet():
    rows = []
    rows.append([front(0), front(0, breathe=1)] + [front(i) for i in range(1, 5)])
    left = [side(0), side(0, breathe=1)] + [side(i) for i in range(1, 5)]
    rows.append(left)
    rows.append([f.flipped() for f in left])
    rows.append([front(0, back=True), front(0, back=True, breathe=1)] + [front(i, back=True) for i in range(1, 5)])
    return sheet(rows)


def lying():
    """Asleep on his back under the blanket, seen from above."""
    s = front(0)
    R = s.rect_mask
    # close the eyes
    s.paint(R(8, 7, 1, 1) | R(11, 7, 1, 1), ramp=P.SKIN, value=0.35, dither=False)
    blanket = R(3, 15, 14, 17)
    v = 0.45 + 0.25 * np.sin(s.xx * 0.9 + s.yy * 0.4) - (s.xx - 10) * 0.02
    s.paint(blanket, ramp=P.FABRIC_BLANKET, value=v)
    s.paint(R(3, 15, 14, 1), ramp=P.FABRIC_SHEET, value=0.7)
    s.hgt[s.a] = 3.0
    s.n[s.a] = np.array([0, 0.15, 1.0]) / np.linalg.norm([0, 0.15, 1.0])
    s.pillow_normals(None, 0.6)
    s.hgt[s.a] = 3.0
    return s


def kneel():
    """On one knee, one hand on the ground, head hanging."""
    st = front(0)
    s = Sprite(FW, FH)
    # take the upper body and lower it
    s.blit(st.crop(0, 0, FW, 22), 0, 8)
    R = s.rect_mask
    # clear the arm on the right; it reaches down to the ground
    s.a[R(14, 8, 3, 30)] = False
    shade_part(s, R(14, 21, 2, 8), P.HOODIE, 0.4, 15, 1)
    s.paint(R(14, 29, 3, 2), ramp=P.SKIN, value=0.5, dither=False)
    # knee and shin
    shade_part(s, R(6, 28, 8, 3), P.JEANS, 0.5, 10, 4)
    s.paint(R(4, 30, 5, 2), ramp=P.SHOE, value=0.5, dither=False)
    s.paint(R(12, 31, 4, 1), ramp=P.JEANS, value=0.3, dither=False)
    # head hangs: hide the face by shifting the hair down
    s.paint(R(7, 12, 6, 3), ramp=P.HAIR, value=0.6, dither=False)
    return finish(s)


def figure():
    s = Sprite(14, 46)
    R = s.rect_mask
    body = s.ellipse_mask(7, 6, 3.2, 4) | R(4, 9, 6, 22) | R(3, 11, 8, 6)
    arms = R(2, 12, 2, 20) | R(10, 12, 2, 21)
    legs = R(4, 30, 2, 15) | R(8, 30, 2, 15)
    m = body | arms | legs
    s.paint(m, color=hexc('#050506'))
    rim = m & ~np.roll(m, -1, axis=1)
    s.paint(rim & (s.yy < 32), color=hexc('#1a1c22'))
    eyes = R(5, 6, 1, 1) | R(8, 6, 1, 1)
    s.em[eyes] = hexc('#8a8a80') * 0.6
    s.col[eyes] = hexc('#3a3a36')
    s.n[m] = np.array([0, 0.7, 0.7])
    s.billboard_height(m, bottom=45)
    return s


def build():
    return {
        'player': player_sheet(),
        'player_lying': lying(),
        'player_kneel': kneel(),
        'figure': figure(),
    }
