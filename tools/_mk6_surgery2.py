# -*- coding: utf-8 -*-
"""MK6 终手术 v2——idle 剪影差分法（描边桥接破局）：
attack 帧中「idle 透明处」的内容 = 飘浮物。其中
  亮核(V>150&S>40)CC≥40px → 火光：搬到枪口（枪口=带内最外灰金属像素）；
  其余 → 擦除（烟圈/黑渣/游离描边圈）。
剪影差 3px 腐蚀护体；接触残端补刀一轮。适用于 thompson/hellcat/pillbox。
用法: python tools/_mk6_surgery2.py
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


def dilate(mask, r):
    m = mask.copy()
    for _ in range(r):
        m2 = m.copy()
        m2[1:, :] |= m[:-1, :]; m2[:-1, :] |= m[1:, :]
        m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
        m = m2
    return m


def erode(mask, r):
    return ~dilate(~mask, r)


def hsv_of(arr):
    return np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert('HSV')).astype(int)


def muzzle_grey(arr, side, band):
    """带内最外灰金属像素 (x,y)。"""
    hsv = hsv_of(arr)
    V = hsv[:, :, 2]; S = hsv[:, :, 1]
    grey = (S < 75) & (V > 45) & (V < 145)
    y0, y1 = band
    best = None
    for y in range(y0, min(y1, arr.shape[0])):
        xs = np.nonzero(grey[y])[0]
        if len(xs) == 0:
            continue
        x = int(xs.min()) if side == 'L' else int(xs.max())
        if best is None or (side == 'L' and x < best[0]) or (side == 'R' and x > best[0]):
            best = (x, y)
    return best


def surgery(unit, side, band, extra_boxes=()):
    meta_i, fs, idle = mk.load_frames(unit, 'idle')
    meta, fs2, atk = mk.load_frames(unit, 'attack')
    mk.backup(unit, 'sheet_attack.png', 'anim.json')
    out = []
    for i, fr in enumerate(atk):
        arr = np.asarray(fr).copy()
        idl = np.asarray(idle[0])
        sky = erode(idl[:, :, 3] < 40, 3)          # idle 无物处（腐蚀3护体）
        extra = (arr[:, :, 3] > 40) & sky
        if not extra.any():
            out.append(fr); continue
        hsv = hsv_of(arr)
        V = hsv[:, :, 2]; S = hsv[:, :, 1]
        bright = (V > 150) & (S > 40) & extra
        did = []
        # 火光：亮核 CC ≥40px（自建 CC，只跑 bright 掩码）
        core_list = []
        seen = np.zeros_like(bright, dtype=bool)
        for y0 in range(arr.shape[0]):
            for x0 in range(arr.shape[1]):
                if bright[y0, x0] and not seen[y0, x0]:
                    stack = [(y0, x0)]; seen[y0, x0] = True; pix = []
                    while stack:
                        y, x = stack.pop(); pix.append((y, x))
                        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            ny, nx = y + dy, x + dx
                            if 0 <= ny < arr.shape[0] and 0 <= nx < arr.shape[1] \
                               and bright[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True; stack.append((ny, nx))
                    core_list.append(pix)
        core_mask = np.zeros(arr.shape[:2], dtype=bool)
        moved = False
        for pix in core_list:
            if len(pix) < 40:
                continue
            cm = np.zeros(arr.shape[:2], dtype=bool)
            cm[[p[0] for p in pix], [p[1] for p in pix]] = True
            core_mask |= cm
            tip = muzzle_grey(arr, side, band)
            if tip is None:
                continue
            region = dilate(cm, 1)
            arr = move_region2(arr, region, tip, side)
            moved = True
            did.append('火光%dpx→%s' % (len(pix), tip))
        # 擦除：extra 中非亮核保护带、且距实心(V>=60)4px 外
        protect = dilate(core_mask, 2)
        solid = dilate(V >= 60, 4) | ~sky  # 实心邻域 + idle 实体区全保
        junk = extra & ~protect & ~solid
        # 接触残端补刀：junk 邻域 2px 内 extra 的暗像素(V<60)
        junk = junk | (dilate(junk, 2) & extra & (V < 60) & ~protect)
        n = int(junk.sum())
        if n:
            arr[junk] = 0
            did.append('擦%dpx' % n)
        for (x0, y0, x1, y1) in extra_boxes:
            box = np.zeros(arr.shape[:2], dtype=bool)
            box[y0:y1, x0:x1] = True
            bx = box & (arr[:, :, 3] > 40) & (V < 60) & ~dilate(V >= 70, 3)
            if bx.any():
                arr[bx] = 0
                did.append('盒擦%dpx' % int(bx.sum()))
        if did:
            print('  [f%d] %s' % (i, '; '.join(did)))
        out.append(Image.fromarray(arr))
    mk.save_strip(unit, 'attack', out, meta, fs)
    mk.preview(unit, 'attack', out, fs)


def move_region2(arr, mask, tip, side):
    ys, xs = np.nonzero(mask)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    reg = arr[y0:y1 + 1, x0:x1 + 1].copy()
    m = mask[y0:y1 + 1, x0:x1 + 1]
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


def main():
    print('── thompson')
    surgery('ww2_thompson', 'L', (30, 128))
    print('── hellcat')
    surgery('ww2_inf_hellcat', 'R', (30, 170))
    print('── pillbox')
    surgery('ww1_fort_pillbox', 'L', (30, 170), extra_boxes=((0, 40, 52, 150),))


if __name__ == '__main__':
    main()
