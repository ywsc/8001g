#!/usr/bin/env python3
"""Generate every graphic asset of the game into assets/gfx.

Usage:  python3 tools/gen_assets.py [--only apartment,neighborhood,chars,items]
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pixgen import apartment  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'gfx')


def save_set(sub, bg_name, bg, props):
    d = os.path.join(OUT, sub)
    if bg is not None:
        bg.save(d, bg_name)
    for name, spr in props.items():
        spr.save(d, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', default='apartment,neighborhood,chars,items')
    args = ap.parse_args()
    only = set(args.only.split(','))
    t0 = time.time()
    if 'apartment' in only:
        bg, props = apartment.build(os.path.join(ROOT, 'maps', 'apartment.txt'))
        save_set('apartment', 'apartment_bg', bg, props)
        print('apartment done %.1fs' % (time.time() - t0))
    if 'neighborhood' in only:
        from pixgen import neighborhood
        bg, props = neighborhood.build(os.path.join(ROOT, 'maps', 'neighborhood.txt'))
        save_set('outdoor', 'outdoor_bg', bg, props)
        print('neighborhood done %.1fs' % (time.time() - t0))
    if 'chars' in only:
        from pixgen import characters
        save_set('chars', None, None, characters.build())
        print('characters done %.1fs' % (time.time() - t0))
    if 'items' in only:
        from pixgen import items
        items.build(os.path.join(OUT, 'items'))
        print('items done %.1fs' % (time.time() - t0))


if __name__ == '__main__':
    main()
