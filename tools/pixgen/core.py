"""Core of the procedural pixel-art generator.

Every sprite is built as four aligned maps:
  * albedo   - RGBA colour, alpha is binary (pixel art)
  * normal   - surface normal, x = east, y = south (screen down), z = up
  * height   - height of the visible surface above the ground, in pixels
  * emissive - self illumination (screens, bulbs, neon)

Drawing helpers work with numpy boolean masks so shapes compose freely.
Colour comes from hue-shifted ramps sampled with ordered dithering, which
keeps surfaces looking hand-pixelled instead of noisy.
"""
import colorsys
import os

import numpy as np
from PIL import Image
from scipy import ndimage

BAYER4 = (np.array([[0, 8, 2, 10],
                    [12, 4, 14, 6],
                    [3, 11, 1, 9],
                    [15, 7, 13, 5]], dtype=np.float32) + 0.5) / 16.0

UP = (0.0, 0.0, 1.0)
SOUTH = (0.0, 0.92, 0.38)    # front faces lean a little toward the viewer
EAST = (0.92, 0.0, 0.38)
WEST = (-0.92, 0.0, 0.38)
NORTH = (0.0, -0.92, 0.38)


# --------------------------------------------------------------------------
# colour
# --------------------------------------------------------------------------
def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    if t.ndim >= 2 and t.shape[-1] != 1 and a.ndim == 1:
        t = t[..., None]
    return a * (1 - t) + b * t


class Ramp:
    """Ordered list of colours from darkest to lightest."""

    def __init__(self, colors):
        self.c = np.array([hexc(c) if isinstance(c, str) else c for c in colors], dtype=np.float32)

    @classmethod
    def from_base(cls, base, n=5, spread=0.62, hue_shift=0.06, sat_shift=0.1):
        """Pixel-artist ramp: darker steps drift cool, lighter drift warm."""
        r, g, b = hexc(base) if isinstance(base, str) else base
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        out = []
        for i in range(n):
            t = i / (n - 1) - 0.5           # -0.5 .. 0.5
            hh = (h - t * hue_shift * 2) % 1.0
            if h > 0.5:                      # cool hues shift the other way to stay coherent
                hh = (h + t * hue_shift * 1.2) % 1.0
            ll = min(0.95, max(0.02, l * (1 + t * spread * 2)))
            ss = min(1.0, max(0.0, s * (1 - abs(t) * sat_shift * 2) + (0.04 if t < 0 else 0)))
            out.append(colorsys.hls_to_rgb(hh, ll, ss))
        return cls(out)

    def __len__(self):
        return len(self.c)

    def sample(self, v, xx, yy, dither=True):
        n = len(self.c)
        t = np.clip(v, 0, 1) * (n - 1)
        base = np.floor(t)
        frac = t - base
        if dither:
            thr = BAYER4[yy % 4, xx % 4]
            idx = base + (frac > thr)
        else:
            idx = np.round(t)
        idx = np.clip(idx, 0, n - 1).astype(np.int32)
        return self.c[idx]

    def darker(self, k=0.7):
        return Ramp(self.c * k)


# --------------------------------------------------------------------------
# noise
# --------------------------------------------------------------------------
_rng_cache = {}


def rng(seed):
    return np.random.default_rng(seed)


def value_noise(w, h, scale, seed, sx=None, sy=None):
    """Smooth value noise in [0,1]; scale = feature size in pixels."""
    sx = sx or scale
    sy = sy or scale
    gw = int(np.ceil(w / sx)) + 3
    gh = int(np.ceil(h / sy)) + 3
    g = rng(seed).random((gh, gw)).astype(np.float32)
    z = ndimage.zoom(g, (sy, sx), order=3, mode='wrap')
    z = z[:h, :w]
    lo, hi = z.min(), z.max()
    return (z - lo) / max(1e-6, hi - lo)


def fbm(w, h, scale, seed, octaves=4, gain=0.5, sx=None, sy=None):
    acc = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        f = 2 ** o
        acc += amp * value_noise(w, h, max(1, scale / f), seed + o * 101,
                                 sx=(sx / f if sx else None), sy=(sy / f if sy else None))
        tot += amp
        amp *= gain
    return acc / tot


def white(w, h, seed):
    return rng(seed).random((h, w)).astype(np.float32)


def grid(w, h):
    yy, xx = np.mgrid[0:h, 0:w]
    return xx, yy


# --------------------------------------------------------------------------
# sprite
# --------------------------------------------------------------------------
class Sprite:
    def __init__(self, w, h):
        self.w, self.h = int(w), int(h)
        self.col = np.zeros((self.h, self.w, 3), np.float32)
        self.a = np.zeros((self.h, self.w), bool)
        self.n = np.zeros((self.h, self.w, 3), np.float32)
        self.n[..., 2] = 1.0
        self.hgt = np.zeros((self.h, self.w), np.float32)
        self.em = np.zeros((self.h, self.w, 3), np.float32)
        self.xx, self.yy = grid(self.w, self.h)

    # -- masks ---------------------------------------------------------------
    def rect_mask(self, x, y, w, h):
        m = np.zeros((self.h, self.w), bool)
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            m[y0:y1, x0:x1] = True
        return m

    def ellipse_mask(self, cx, cy, rx, ry):
        return ((self.xx + 0.5 - cx) / max(rx, 0.01)) ** 2 + ((self.yy + 0.5 - cy) / max(ry, 0.01)) ** 2 <= 1.0

    def poly_mask(self, pts):
        from PIL import ImageDraw
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
        return np.array(im) > 127

    def line_mask(self, pts, width=1):
        from PIL import ImageDraw
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).line([tuple(p) for p in pts], fill=255, width=width)
        return np.array(im) > 127

    # -- painting ------------------------------------------------------------
    def paint(self, mask, color=None, ramp=None, value=None, normal=None, height=None,
              emit=None, dither=True, alpha=True):
        """Write into all maps where mask is set.

        color : rgb (3,) or (h,w,3) array
        ramp+value : ramp sampled with value map (scalar or (h,w))
        normal : (3,) or (h,w,3)
        height : scalar or (h,w)
        emit   : rgb (3,) or (h,w,3)
        """
        if mask is None or not mask.any():
            return
        if ramp is not None:
            v = value if value is not None else 0.5
            if np.isscalar(v):
                v = np.full((self.h, self.w), v, np.float32)
            c = ramp.sample(v, self.xx, self.yy, dither)
            self.col[mask] = c[mask]
        elif color is not None:
            c = np.asarray(color, np.float32)
            self.col[mask] = c[mask] if c.ndim == 3 else c
        if alpha:
            self.a[mask] = True
        if normal is not None:
            nn = np.asarray(normal, np.float32)
            if nn.ndim == 1:
                nn = nn / np.linalg.norm(nn)
                self.n[mask] = nn
            else:
                self.n[mask] = nn[mask]
        if height is not None:
            hh = np.asarray(height, np.float32)
            self.hgt[mask] = hh[mask] if hh.ndim == 2 else hh
        if emit is not None:
            e = np.asarray(emit, np.float32)
            self.em[mask] = e[mask] if e.ndim == 3 else e

    def shade(self, mask, k):
        """Multiply colour (k scalar or map)."""
        if np.isscalar(k):
            self.col[mask] *= k
        else:
            self.col[mask] *= k[mask][:, None]

    def tint(self, mask, color, t):
        c = np.asarray(color, np.float32)
        if np.isscalar(t):
            self.col[mask] = self.col[mask] * (1 - t) + c * t
        else:
            tt = t[mask][:, None]
            self.col[mask] = self.col[mask] * (1 - tt) + c * tt

    def bump(self, mask, bmap, strength=1.0):
        """Perturb normals with the gradient of a bump map (relative to current normal)."""
        gy, gx = np.gradient(bmap.astype(np.float32))
        n = self.n.copy()
        n[..., 0] -= gx * strength
        n[..., 1] -= gy * strength
        ln = np.linalg.norm(n, axis=-1, keepdims=True)
        n = n / np.maximum(ln, 1e-6)
        self.n[mask] = n[mask]

    # -- 3/4 primitives -------------------------------------------------------
    def box(self, x, y, w, d, h, top, front, top_v=None, front_v=None, base=0.0,
            side=None, top_mask_extra=None, edge=True):
        """3/4 box. (x,y) = top-left of the *top face* in sprite pixels,
        w = width, d = depth (top face height on screen), h = vertical height (front face).
        `base` = height of the ground the box stands on (for stacking).
        Returns (top_mask, front_mask)."""
        tm = self.rect_mask(x, y, w, d)
        fm = self.rect_mask(x, y + d, w, h)
        tv = top_v if top_v is not None else 0.6
        fv = front_v if front_v is not None else 0.4
        self.paint(tm, ramp=top, value=tv, normal=UP, height=base + h)
        if h > 0:
            # front face height decreases toward the bottom
            hmap = base + h - (self.yy - (y + d)).astype(np.float32)
            self.paint(fm, ramp=front, value=fv, normal=SOUTH, height=hmap)
        if edge:
            # crisp top edge highlight + bottom contact darkening
            em = self.rect_mask(x, y + d - 1, w, 1) & tm
            self.col[em] = np.minimum(1, self.col[em] * 1.18 + 0.02)
            if h > 1:
                bm = self.rect_mask(x, y + d + h - 1, w, 1)
                self.col[bm] *= 0.6
        return tm, fm

    def cylinder(self, cx, y, r, d, h, top, front, base=0.0):
        """Upright cylinder: ellipse top (rx=r, ry=d/2) + rounded front."""
        top_cy = y + d / 2
        tm = self.ellipse_mask(cx, top_cy, r, d / 2)
        body = (self.rect_mask(cx - r, top_cy, 2 * r, h) | self.ellipse_mask(cx, top_cy + h, r, d / 2)) & ~tm
        # roundness: shade by x
        rel = np.clip((self.xx + 0.5 - cx) / max(r, 0.5), -1, 1)
        fv = 0.62 - 0.45 * rel - 0.15 * np.abs(rel) ** 2
        nx = rel
        nz = np.sqrt(np.clip(1 - rel ** 2, 0, 1))
        nmap = np.stack([nx * 0.95, nz * 0.85, nz * 0.35], -1)
        hmap = base + h - np.clip(self.yy - top_cy, 0, h).astype(np.float32)
        self.paint(body, ramp=front, value=fv, normal=nmap, height=hmap)
        self.paint(tm, ramp=top, value=0.65 - 0.2 * rel, normal=UP, height=base + h)
        return tm, body

    # -- finishing -----------------------------------------------------------
    def outline(self, k=0.55, mask=None):
        """Darken the outermost opaque pixels (selective outline)."""
        a = self.a
        er = ndimage.binary_erosion(a, structure=np.ones((3, 3)), border_value=0)
        edge = a & ~er
        if mask is not None:
            edge &= mask
        self.col[edge] *= k

    def ao_floor(self, solid_mask, radius=6, strength=0.5):
        """Darken non-solid pixels near solid ones (ambient occlusion)."""
        dist = ndimage.distance_transform_edt(~solid_mask)
        k = 1 - strength * np.clip(1 - dist / radius, 0, 1) ** 1.6
        m = ~solid_mask & self.a
        self.col[m] *= k[m][:, None]

    def pillow_normals(self, mask=None, strength=1.0, flat=0.35):
        """Rounded normals from silhouette distance (for organic shapes)."""
        m = self.a if mask is None else mask
        dist = ndimage.distance_transform_edt(m)
        hgt = np.sqrt(np.clip(dist, 0, 4) / 4.0)
        hgt = ndimage.gaussian_filter(hgt, 0.7)
        gy, gx = np.gradient(hgt)
        n = np.stack([-gx * 2.5 * strength, -gy * 2.5 * strength, np.full_like(gx, flat + 0.4)], -1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        self.n[m] = n[m]

    def billboard_height(self, mask=None, base=0.0, bottom=None):
        """Upright object: height grows from its bottom row upwards."""
        m = self.a if mask is None else mask
        bottom = self.h - 1 if bottom is None else bottom
        self.hgt[m] = (base + (bottom - self.yy).clip(0)).astype(np.float32)[m]

    def blit(self, other, ox, oy, height_add=0.0):
        """Composite another sprite (opaque pixels win)."""
        ox, oy = int(ox), int(oy)
        sx0, sy0 = max(0, -ox), max(0, -oy)
        dx0, dy0 = max(0, ox), max(0, oy)
        w = min(other.w - sx0, self.w - dx0)
        h = min(other.h - sy0, self.h - dy0)
        if w <= 0 or h <= 0:
            return
        sa = other.a[sy0:sy0 + h, sx0:sx0 + w]
        ds = (slice(dy0, dy0 + h), slice(dx0, dx0 + w))
        ss = (slice(sy0, sy0 + h), slice(sx0, sx0 + w))
        self.col[ds][sa] = other.col[ss][sa]
        self.n[ds][sa] = other.n[ss][sa]
        self.hgt[ds][sa] = other.hgt[ss][sa] + height_add
        self.em[ds][sa] = other.em[ss][sa]
        self.a[ds][sa] = True

    def crop(self, x, y, w, h):
        s = Sprite(w, h)
        s.col = self.col[y:y + h, x:x + w].copy()
        s.a = self.a[y:y + h, x:x + w].copy()
        s.n = self.n[y:y + h, x:x + w].copy()
        s.hgt = self.hgt[y:y + h, x:x + w].copy()
        s.em = self.em[y:y + h, x:x + w].copy()
        return s

    def flipped(self):
        s = Sprite(self.w, self.h)
        s.col = self.col[:, ::-1].copy()
        s.a = self.a[:, ::-1].copy()
        s.n = self.n[:, ::-1].copy()
        s.n[..., 0] *= -1
        s.hgt = self.hgt[:, ::-1].copy()
        s.em = self.em[:, ::-1].copy()
        return s

    # -- output --------------------------------------------------------------
    def save(self, outdir, name, maps=('a', 'n', 'h', 'e')):
        os.makedirs(outdir, exist_ok=True)
        alpha = (self.a * 255).astype(np.uint8)
        if 'a' in maps:
            rgb = (np.clip(self.col, 0, 1) * 255 + 0.5).astype(np.uint8)
            Image.fromarray(np.dstack([rgb, alpha]), 'RGBA').save(os.path.join(outdir, name + '.png'), optimize=True)
        if 'n' in maps:
            n = self.n / np.maximum(np.linalg.norm(self.n, axis=-1, keepdims=True), 1e-6)
            rgb = ((n * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)
            Image.fromarray(np.dstack([rgb, alpha]), 'RGBA').save(os.path.join(outdir, name + '_n.png'), optimize=True)
        if 'h' in maps:
            hh = np.clip(self.hgt, 0, 255).astype(np.uint8)
            Image.fromarray(np.dstack([hh, hh, hh, alpha]), 'RGBA').save(os.path.join(outdir, name + '_h.png'), optimize=True)
        if 'e' in maps and self.em.max() > 0.004:
            rgb = (np.clip(self.em, 0, 1) * 255 + 0.5).astype(np.uint8)
            Image.fromarray(np.dstack([rgb, alpha]), 'RGBA').save(os.path.join(outdir, name + '_e.png'), optimize=True)


def strip(frames):
    """Pack equally sized sprites horizontally into one sheet."""
    w, h = frames[0].w, frames[0].h
    s = Sprite(w * len(frames), h)
    for i, f in enumerate(frames):
        s.blit(f, i * w, 0)
    return s


def sheet(rows):
    """Pack rows (lists of sprites, same size) into a grid sheet."""
    w, h = rows[0][0].w, rows[0][0].h
    cols = max(len(r) for r in rows)
    s = Sprite(w * cols, h * len(rows))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            s.blit(f, i * w, j * h)
    return s


def save_icon(sprite, outdir, name):
    """UI icons only need colour."""
    sprite.save(outdir, name, maps=('a',))
