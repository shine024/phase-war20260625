# -*- coding: utf-8 -*-
"""fix3 第二阶段: 非战斗单位 attack = idle 复制(用户: 不用有开火动作)
cold_fort_radar / ww2_sup_gmc_truck / cold_arm_p18 / cold_arty_brem1 / fut_sup_ps9
快照 attack f* -> bak_fix3/, 用 idle f* 覆盖 attack f*, 更新 meta.json, repack attack sheet
"""
import glob
import json
import os
import shutil
import sys

from PIL import Image

BASE = r'资料/单位分帧动画'
UNITS = ['cold_fort_radar', 'ww2_sup_gmc_truck', 'cold_arm_p18', 'cold_arty_brem1', 'fut_sup_ps9']


def dname(u):
    for d in os.listdir(BASE):
        if d == u or d.startswith(u + '_'):
            return d
    raise SystemExit('no dir ' + u)


for u in UNITS:
    d = dname(u)
    idir = os.path.join(BASE, d, 'idle')
    adir = os.path.join(BASE, d, 'attack')
    bak = os.path.join(adir, 'bak_fix3')
    os.makedirs(bak, exist_ok=True)
    # 快照旧 attack 帧
    old = sorted(glob.glob(os.path.join(adir, 'f*.png')))
    for f in old:
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
    # 清现 attack 帧(已备份), 拷 idle
    for f in old:
        os.remove(f)
    idl = sorted(glob.glob(os.path.join(idir, 'f*.png')))
    for i, f in enumerate(idl):
        shutil.copy2(f, os.path.join(adir, 'f%02d.png' % i))
    # 更新 meta.json
    mp = os.path.join(adir, 'meta.json')
    meta = json.load(open(mp, encoding='utf-8')) if os.path.exists(mp) else {}
    meta.update({
        'frames': len(idl),
        'frame_files': ['f%02d.png' % i for i in range(len(idl))],
        'fix3_note': 'attack = idle copy (user: no fire action); original attack frames in bak_fix3/',
    })
    json.dump(meta, open(mp, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    # repack attack sheet
    ims = [Image.open(f).convert('RGBA') for f in sorted(glob.glob(os.path.join(adir, 'f*.png')))]
    w, h = ims[0].size
    sheet = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im, (i * w, 0))
    sheet.save(os.path.join(adir, 'sheet_attack.png'))
    print('%s: attack<-idle %d frames, sheet %dx%d' % (d, len(ims), sheet.size[0], sheet.size[1]))
print('COPY DONE')
