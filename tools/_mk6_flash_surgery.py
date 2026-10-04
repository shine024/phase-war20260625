# -*- coding: utf-8 -*-
"""MK6 火光/残渣终手术（黑盒转透明后 alpha 空间执行）：
S1 ww2_thompson attack   火光→枪口线 + 盔上黑渣擦除
S2 ww2_inf_hellcat attack 火光→炮口尖(朝右) + 烟圈擦除（亮核分离：粘住的烟圈留擦、亮核搬走）
S3 ww1_fort_pillbox attack 碉堡左侧游离描边圈擦除
S4 卡图取帧补漏          ww2_arm_garand_para / vis_xeno_dark_templar（真实 icon 路径自 dump 查询）
旧件已在 .godot/art_backup_mk6_20261004/（黑盒原卷）。用法: python tools/_mk6_flash_surgery.py
"""
import io
import json
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_mk6_20261004")
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")

_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)


def load(unit, anim):
    return mk.load_frames(unit, anim)


def hsv_of(arr):
    return np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert('HSV')).astype(int)


def surgery(unit, anim, side, band, move=True, erase_junk=True):
    """通用火光/残渣手术。side='L'|'R'；band=(y0,y1) 枪管高度带。"""
    meta, fs, frs = load(unit, anim)
    backup_files = ['sheet_%s.png' % anim, 'anim.json']
    mk.backup(unit, *backup_files)
    out = []
    for i, fr in enumerate(frs):
        arr = np.asarray(fr).copy()
        ccs = mk.components(arr)
        if not ccs:
            out.append(fr); continue
        ccs.sort(key=lambda c: -c[2])
        body = ccs[0]
        hsv = hsv_of(arr)
        did = []
        for pix, bb, area in ccs[1:]:
            if area < 25:
                continue
            ys = [p[0] for p in pix]; xs = [p[1] for p in pix]
            w = bb[2] - bb[0] + 1; h = bb[3] - bb[1] + 1
            vv = hsv[:, :, 2][ys, xs]; vs = hsv[:, :, 1][ys, xs]
            bright = (vv > 150) & (vs > 40)
            n_bright = int(bright.sum())
            bottom = max(p[0] for p in body[0])
            is_ground = bb[3] >= bottom - 14 and w > 2.5 * h
            if n_bright >= 150 and move:
                # 亮核分离：halo=亮核膨胀3∩本域 → 搬到枪口；其余本域像素擦除
                bmask = np.zeros(arr.shape[:2], dtype=bool)
                bys = [p[0] for p in pix]; bxs = [p[1] for p in pix]
                sel = bright[bys, bxs] if False else None
                # 直接构建亮核掩码
                bmask[ys, xs] = bright
                halo = mk_dilate(bmask, 3) & mk_pixmask(pix, arr.shape)
                tip = mk.muzzle_tip(body[0], side, band=band)
                arr = move_region(arr, halo, tip, side)
                rest = mk_pixmask(pix, arr.shape) & ~halo
                arr[rest] = 0
                did.append('火光亮核→%s 擦残%dpx' % (tip, int(rest.sum())))
            elif n_bright >= 150 and not move:
                did.append('保留亮域%d' % n_bright)
            elif erase_junk and not is_ground:
                arr[mk_pixmask(pix, arr.shape)] = 0
                did.append('擦离体%dpx(a%d)' % (len(pix), area))
        if did:
            print('  [f%d] %s' % (i, '; '.join(did)))
        out.append(Image.fromarray(arr))
    mk.save_strip(unit, anim, out, meta, fs)
    mk.preview(unit, anim, out, fs)


def mk_pixmask(pix, shape):
    m = np.zeros(shape[:2], dtype=bool)
    ys = [p[0] for p in pix]; xs = [p[1] for p in pix]
    m[ys, xs] = True
    return m


def mk_dilate(mask, r):
    m = mask.copy()
    for _ in range(r):
        m2 = m.copy()
        m2[1:, :] |= m[:-1, :]; m2[:-1, :] |= m[1:, :]
        m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
        m = m2
    return m


def move_region(arr, mask, tip, side):
    ys, xs = np.nonzero(mask)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    reg = arr[y0:y1 + 1, x0:x1 + 1].copy()
    m = mask[y0:y1 + 1, x0:x1 + 1]
    arr[y0:y1 + 1, x0:x1 + 1][m] = 0
    w, h = x1 - x0 + 1, y1 - y0 + 1
    tx, ty = tip
    if side == 'L':
        nx = int(round(tx - w * 0.7))
    else:
        nx = int(round(tx - w * 0.3))
    ny = int(round(ty - h / 2))
    H, W = arr.shape[:2]
    nx = max(0, min(W - w, nx)); ny = max(0, min(H - h, ny))
    sub = arr[ny:ny + h, nx:nx + w]
    sub[m] = np.maximum(sub[m], reg[m])
    return arr


def s4():
    """卡图取帧补漏：真实 icon 路径自 dump。"""
    d = json.load(open(os.path.join(ROOT, '_anim_review', 'unit_manifest_full.json'),
                       encoding='utf-8'))
    want = {'ww2_arm_garand_para', 'vis_xeno_dark_templar'}
    icons = {}
    for sec in ('enemies', 'players', 'captured'):
        for r in d[sec]:
            if r['id'] in want:
                icons[r['id']] = r['icon'].replace('res://', ROOT + os.sep).replace('/', os.sep)
    for uid, ipath in sorted(icons.items()):
        unit = 'ww2_arm_garand_para' if uid == 'ww2_arm_garand_para' else 'vis_xeno_dark_templar'
        meta, fs, frs = load(unit, 'idle')
        cur = Image.open(ipath).convert('RGBA')
        iw, ih = cur.size
        im = frs[0].resize((iw, ih), Image.LANCZOS) if (iw, ih) != (fs, fs) else frs[0]
        bd = os.path.join(BAK, 'card_icons', os.path.basename(ipath))
        os.makedirs(os.path.dirname(bd), exist_ok=True)
        if not os.path.exists(bd):
            shutil.copy2(ipath, bd)
        f_old, f_new = mk.facing(cur), mk.facing(im)
        if f_old and f_new and f_old != f_new:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
            print('  [flip] %s %s→%s' % (os.path.basename(ipath), f_new, f_old))
        im.save(ipath)
        im.resize((192, 192), Image.LANCZOS).save(
            os.path.join(STG, 'verify_icon_%s.png' % unit))
        print('  [icon] %s ← %s idle f0 (%dx%d)' % (os.path.basename(ipath), unit, iw, ih))


def main():
    print('── S1 thompson')
    surgery('ww2_thompson', 'attack', 'L', (30, 128))
    print('── S2 hellcat')
    surgery('ww2_inf_hellcat', 'attack', 'R', (30, 170))
    print('── S3 pillbox')
    surgery('ww1_fort_pillbox', 'attack', 'L', (30, 170), move=False)
    print('── S4 卡图补漏')
    s4()
    print('完成')


if __name__ == '__main__':
    main()
