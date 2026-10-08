#!/usr/bin/env python3
"""Minimal AI Horde client (https://aihorde.net - free, community GPUs).

Anonymous key works (slow queue). Set HORDE_API_KEY for priority.
  python3 tools/horde.py "prompt" out.png --model "AIO Pixel Art" --w 512 --h 320 --seed 1
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.request

API = 'https://aihorde.net/api/v2'
KEY = os.environ.get('HORDE_API_KEY', '0000000000')
HEADERS = {'apikey': KEY, 'Content-Type': 'application/json', 'Client-Agent': 'hollow-hours:1.0:github.com/ywsc/8001g',
           'User-Agent': 'hollow-hours/1.0 (+https://github.com/ywsc/8001g)'}


def _req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data, method=method, headers=HEADERS)
    with urllib.request.urlopen(r, timeout=60) as resp:
        return json.loads(resp.read())


def generate(prompt, out, model, w=512, h=320, seed=1, steps=28, cfg=6.5, negative='', sampler='k_euler_a',
             loras=None, timeout=7200, verbose=True):
    params = {'width': w, 'height': h, 'steps': steps, 'cfg_scale': cfg, 'seed': str(seed),
              'sampler_name': sampler, 'n': 1, 'karras': True}
    if loras:
        params['loras'] = loras
    full = prompt + (' ### ' + negative if negative else '')
    job = _req('POST', '/generate/async', {'prompt': full, 'params': params, 'models': [model],
                                            'r2': True, 'nsfw': False, 'censor_nsfw': True, 'trusted_workers': False})
    jid = job['id']
    t0 = time.time()
    last = None
    while True:
        st = _req('GET', '/generate/check/' + jid)
        if st.get('done'):
            break
        if not st.get('is_possible', True):
            raise RuntimeError('no worker can run this request: ' + json.dumps(st))
        msg = 'queue %s wait %ss' % (st.get('queue_position'), st.get('wait_time'))
        if verbose and msg != last:
            print('  ', model, msg, flush=True)
            last = msg
        if time.time() - t0 > timeout:
            _req('DELETE', '/generate/status/' + jid)
            raise TimeoutError('horde job timed out')
        time.sleep(6)
    res = _req('GET', '/generate/status/' + jid)
    gen = res['generations'][0]
    img = gen['img']
    if img.startswith('http'):
        with urllib.request.urlopen(img, timeout=120) as r:
            data = r.read()
    else:
        data = base64.b64decode(img)
    with open(out, 'wb') as f:
        f.write(data)
    if verbose:
        print('  done in %.0fs by %s' % (time.time() - t0, gen.get('worker_name')))
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('prompt')
    ap.add_argument('out')
    ap.add_argument('--model', default='AIO Pixel Art')
    ap.add_argument('--w', type=int, default=512)
    ap.add_argument('--h', type=int, default=320)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--steps', type=int, default=28)
    ap.add_argument('--neg', default='')
    a = ap.parse_args()
    generate(a.prompt, a.out, a.model, a.w, a.h, a.seed, a.steps, negative=a.neg)
