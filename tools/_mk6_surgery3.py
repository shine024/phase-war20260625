# -*- coding: utf-8 -*-
"""MK6 终手术 v3 收尾：
T1 thompson/hellcat：擦「游离 CC」残渣（v2 后已脱离主体的棕 glow/烟圈/白点）
T2 hellcat：星花从误贴位 (229,169) 搬到真炮口（窄带 y110-165 右端灰金属）
用法: python tools/_mk6_surgery3.py
"""
import io
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)


def hsv_of(arr):
    return np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert('HSV')).astype(int)


def detach_junk(arr, max_area=2600, keep_bottom_shadow=True):
    """擦掉与主体脱离的 CC（小域）。返回 (新arr, 擦除数, 星花mask或None)。"""
    ccs = sorted(mk.components(arr), key=lambda c: -c[2])
    if len(ccs) < 2:
        return arr, 0, None
    hsv = hsv_of(arr)
    V = hsv[:, :, 2]; S = hsv[:, :, 1]
    body = ccs[0]
    bottom = max(p[0] for p in body[0])
    n = 0
    star = None
    for pix, bb, area in ccs[1:]:
        if area < 12:
            arr[np.array([p[0] for p in pix]), np.array([p[1] for p in pix])] = 0
            n += area
            continue
        ys = np.array([p[0] for p in pix]); xs = np.array([p[1] for p in pix])
        w = bb[2] - bb[0] + 1; h = bb[3] - bb[1] + 1
        flat_ground = keep_bottom_shadow and bb[3] >= bottom - 14 and w > 2.5 * h
        if flat_ground:
            continue
        bright = int(((V[ys, xs] > 140) & (S[ys, xs] > 45)).sum())
        m = np.zeros(arr.shape[:2], dtype=bool)
        m[ys, xs] = True
        if bright >= 60 and star is None:
            star = m   # 第一个含亮核的游离域 = 误贴星花候选
            continue
        arr[m] = 0
        n += area
    return arr, n, star


def relocate_star(arr, star, tip, side):
    ys, xs = np.nonzero(star)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    reg = arr[y0:y1 + 1, x0:x1 + 1].copy()
    m = star[y0:y1 + 1, x0:x1 + 1]
    arr[y0:y1 + 1, x0:x1 + 1][m] = 0
    w, h = x1 - x0 + 1, y1 - y0 + 1
    tx, ty = tip
    nx = int(round(tx - w * 0.75)) if side == 'L' else int(round(tx - w * 0.25))
    ny = int(round(ty - h / 2))
    H, W = arr.shape[:2]
    nx = max(0, min(W - w, nx)); ny = max(0, min(H - h, ny))
    sub = arr[ny:ny + h, nx:nx + w]
    sub[m] = np.maximum(sub[m], reg[m])
    return arr


def muzzle_band(arr, side, band):
    hsv = hsv_of(arr)
    V = hsv[:, :, 2]; S = hsv[:, :, 1]
    grey = (S < 75) & (V > 45) & (V < 145)
    best = None
    for y in range(band[0], min(band[1], arr.shape[0])):
        xs = np.nonzero(grey[y])[0]
        if len(xs) == 0:
            continue
        x = int(xs.min()) if side == 'L' else int(xs.max())
        if best is None or (side == 'L' and x < best[0]) or (side == 'R' and x > best[0]):
            best = (x, y)
    return best


def run(unit, side, band, star_box=None, star_frames=()):
    meta, fs, frs = mk.load_frames(unit, 'attack')
    mk.backup(unit, 'sheet_attack.png', 'anim.json')
    out = []
    for i, fr in enumerate(fr_s := frs):
        arr = np.asarray(fr).copy()
        # 星花先行（否则 detach 会把它当 junk 擦掉——含亮核域保留逻辑在，但双保险）
        star = None
        if star_box and i in star_frames:
            hsv = hsv_of(arr)
            V = hsv[:, :, 2]; S = hsv[:, :, 1]
            x0, y0, x1, y1 = star_box
            bm = np.zeros(arr.shape[:2], dtype=bool)
            sub = (V[y0:y1, x0:x1] > 140) & (S[y0:y1, x0:x1] > 45)
            bm[y0:y1, x0:x1] = sub
            if bm.sum() >= 60:
                star = bm
        arr, n, star2 = detach_junk(arr)
        if star is None:
            star = star2
        did = ['擦%d' % n] if n else []
        if star is not None:
            tip = muzzle_band(arr, side, band)
            if tip is not None:
                arr = relocate_star(arr, star, tip, side)
                did.append('星花→%s' % (tip,))
        if did:
            print('  [f%d] %s' % (i, '; '.join(did)))
        out.append(Image.fromarray(arr))
    mk.save_strip(unit, 'attack', out, meta, fs)
    mk.preview(unit, 'attack', out, fs)


def main():
    print('── thompson')
    run('ww2_thompson', 'L', (30, 128))
    print('── hellcat')
    run('ww2_inf_hellcat', 'R', (110, 165), star_box=(195, 130, 256, 205),
        star_frames=(2, 3, 4))


if __name__ == '__main__':
    main()
