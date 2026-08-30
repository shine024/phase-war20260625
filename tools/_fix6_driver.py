# -*- coding: utf-8 -*-
"""fix6 驱动: 11 项复审修复
A. matte 重建: 067 titan×2 / 064 heavy_mech×2 / 057 m6 idle / 027 mlrs attack(烟雾修剪)
B. 002 storm attack 四帧定向擦环(全擦走廊)
C. 084 vickers idle <- attack 抽帧
D. 071 abrams_mk2 attack 删第8帧
E. 034 fut_mech f04 -> 替换敌我卡图
F. API 重生成: 029 abrams attack(简化火光) / 018 m60 attack(idle链) / 013 pschreck attack(idle链)
"""
import glob
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time

import cv2
import numpy as np
from PIL import Image

SRC = 'tools/generate_unit_animations.py'
EXTRA_P = 'tools/unit_animations_extra.json'
BASE = r'资料/单位分帧动画'

spec = importlib.util.spec_from_file_location('gua', SRC)
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
UNITS = gua.UNITS
extra = json.load(open(EXTRA_P, encoding='utf-8'))

# ── 0. json 旗标: titan/heavy_mech ──
for u in ('fut_arm_titan_mk2', 'fut_arm_heavy_mech'):
    extra[u]['matte_edge'] = True
    extra[u]['nw_trim'] = False
# mlrs 烟雾修剪
txt = open(SRC, encoding='utf-8').read()
ref = '"ref": "mod_mlrs_white.jpg",'
assert txt.count(ref) == 1
if '"smoke_trim"' not in txt.split(ref, 1)[1][:300]:
    txt = txt.replace(ref, ref + '\n        "smoke_trim": True,', 1)
    open(SRC, 'w', encoding='utf-8').write(txt)
    print('mlrs smoke_trim patched')
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
gua.UNITS.update(extra)


def dname(u):
    return next(x for x in os.listdir(BASE)
                if re.sub(r'^\d{3}_', '', x).startswith(u + '_'))


def backup(u, a, tag='bak_fix6'):
    adir = os.path.join(BASE, dname(u), a)
    bak = os.path.join(adir, tag)
    os.makedirs(bak, exist_ok=True)
    for f in glob.glob(os.path.join(adir, 'f*.png')):
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
    return adir


def meta_set(adir, frames_files):
    mp = os.path.join(adir, 'meta.json')
    meta = json.load(open(mp, encoding='utf-8'))
    meta['frames'] = len(frames_files)
    meta['frame_files'] = frames_files
    json.dump(meta, open(mp, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


def repack(adir, anim):
    frames = sorted(glob.glob(os.path.join(adir, 'f*.png')))
    ims = [Image.open(f).convert('RGBA') for f in frames]
    w, h = ims[0].size
    sheet = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im, (i * w, 0))
    sheet.save(os.path.join(adir, 'sheet_%s.png' % anim))


# ── A. matte 重建 ──
for u, a in [('fut_arm_titan_mk2', 'idle'), ('fut_arm_titan_mk2', 'attack'),
             ('fut_arm_heavy_mech', 'idle'), ('fut_arm_heavy_mech', 'attack'),
             ('mod_sup_m6', 'idle'), ('mod_mlrs', 'attack')]:
    backup(u, a)
    print('== A rebuild %s/%s' % (u, a), flush=True)
    gua.step_build(u, a)

# ── B. storm attack 环全擦 ──
adir = os.path.join(BASE, dname('ww1_storm'), 'attack')
n = 0
for f in sorted(glob.glob(os.path.join(adir, 'f*.png'))):
    arr = np.asarray(Image.open(f).convert('RGBA')).copy()
    a = arr[..., 3]
    mask = (a >= 64).astype(np.uint8)
    lines = cv2.HoughLinesP(mask, 1, np.pi / 180, threshold=100,
                            minLineLength=100, maxLineGap=10)
    if lines is None:
        continue
    h, w = a.shape
    touched = False
    for ln in lines.reshape(-1, 4):
        x1, y1, x2, y2 = [int(v) for v in ln]
        horiz = abs(y1 - y2) <= 3
        vert = abs(x1 - x2) <= 3
        if not (horiz or vert):
            continue
        if horiz and not (min(y1, y2) < 80 or max(y1, y2) > h - 80):
            continue
        if vert and not (min(x1, x2) < 80 or max(x1, x2) > w - 80):
            continue
        if horiz:
            y0 = min(y1, y2)
            arr[max(0, y0 - 4):y0 + 5, max(0, min(x1, x2) - 4):min(w, max(x1, x2) + 5), 3] = 0
        else:
            x0 = min(x1, x2)
            arr[max(0, min(y1, y2) - 4):min(h, max(y1, y2) + 5), max(0, x0 - 4):x0 + 5, 3] = 0
        touched = True
    if touched:
        Image.fromarray(arr).save(f)
        n += 1
print('== B storm ring frames scrubbed:', n)

# ── C. vickers idle <- attack 抽帧 ──
u = 'ww1_sup_vickers'
aidle = backup(u, 'idle')
aatk = os.path.join(BASE, dname(u), 'attack')
af = sorted(glob.glob(os.path.join(aatk, 'f*.png')))
pick = [af[round(i * (len(af) - 1) / 7.0)] for i in range(8)]
for f in glob.glob(os.path.join(aidle, 'f*.png')):
    os.remove(f)
files = []
for i, f in enumerate(pick):
    dst = 'f%02d.png' % i
    shutil.copy2(f, os.path.join(aidle, dst))
    files.append(dst)
meta_set(aidle, files)
repack(aidle, 'idle')
print('== C vickers idle <- attack %d frames' % len(files))

# ── D. abrams_mk2 attack 删第8帧(f07) ──
u = 'mod_arm_abrams_mk2'
aadir = backup(u, 'attack')
f7 = os.path.join(aadir, 'f07.png')
if os.path.exists(f7):
    rest = [f for f in sorted(glob.glob(os.path.join(aadir, 'f*.png')))
            if os.path.basename(f) > 'f07.png']
    os.remove(f7)
    files = ['f%02d.png' % i for i in range(len(rest) + 7)]  # f00..f06 + 平移
    files = ['f%02d.png' % i for i in range(7)] + ['f%02d.png' % i for i in range(7, 7 + len(rest))]
    for old, new in zip(rest, files[7:]):
        os.rename(os.path.join(aadir, old), os.path.join(aadir, new))
    meta_set(aadir, files)
    repack(aadir, 'attack')
    print('== D abrams_mk2 attack -> %d frames' % len(files))

# ── E. fut_mech f04 -> 卡图 ──
f4 = os.path.join(BASE, dname('fut_mech'), 'idle', 'f04.png')
im = Image.open(f4).convert('RGBA')
bdir = r'assets/card_icons/bak_fix6_card'
os.makedirs(bdir, exist_ok=True)
for p in (r'assets/card_icons/enemy/vis_enemy_067.png',
          r'assets/card_icons/player/vis_player_067.png'):
    dst_bak = os.path.join(bdir, os.path.basename(p))
    if not os.path.exists(dst_bak):
        shutil.copy2(p, dst_bak)
im.save(r'assets/card_icons/enemy/vis_enemy_067.png')
im.transpose(Image.FLIP_LEFT_RIGHT).save(r'assets/card_icons/player/vis_player_067.png')
print('== E mech card replaced (enemy+player mirrored)')

# ── F. API 重生成 ──
HEAD = "严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
TAIL = "镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。纯白色无缝背景，无地面，无阴影，无文字，无水印。"
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

REGEN = [
    ('mod_abrams', 'attack', None,
     HEAD + "坦克原地静止，主炮向画面左侧开火一次：仅左侧炮口处一道干净的火光一闪即逝，"
            "炮管轻微后坐复位，没有任何硝烟，没有烟雾扩散，没有尘土，画面其余部分保持纯净。" + TAIL),
    ('cold_m60', 'attack', 'idle',
     HEAD + "画面中只有这几名机枪班士兵，人数与首帧完全一致。机枪与首帧待机时的枪完全相同，"
            "枪架也与首帧完全相同，绝不更换武器，绝不新增三脚架或其他支架。"
            "机枪向画面左侧连续射击：仅枪口火光连续闪烁与枪身轻微震动，无烟雾弥漫。" + TAIL),
    ('ww2_pschreck', 'attack', 'idle',
     HEAD + "画面中只有这几名士兵，人数、体型大小、装备与首帧完全一致，绝不改变任何人的大小与装备。"
            "铁拳反坦克火箭筒向画面左侧发射：火箭弹向左侧飞出，筒口尾焰一闪，"
            "持筒姿势不变，无烟雾弥漫。" + TAIL),
]
state = {}
for u, a, refsrc, prompt in REGEN:
    if u in extra:
        extra[u]['anims'][a]['prompt'] = prompt
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
gua.UNITS.update(extra)

for u, a, refsrc, prompt in REGEN:
    adir = backup(u, a)
    mp4 = os.path.join(adir, 'source.mp4')
    pre = os.path.join(adir, 'source_pre_fix6.mp4')
    if os.path.exists(mp4) and not os.path.exists(pre):
        shutil.copy2(mp4, pre)
    old_ref = None
    if refsrc:
        f0 = sorted(glob.glob(os.path.join(BASE, dname(u), refsrc, 'f*.png')))[0]
        im = Image.open(f0).convert('RGBA')
        cv2_ = Image.new('RGB', (512, 512), (255, 255, 255))
        cv2_.paste(im, (0, 0), im)
        refname = '%s_fromidle_white.jpg' % u
        cv2_.save(os.path.join(gua.REF_DIR, refname), quality=92)
        old_ref = UNITS[u]['ref']
        UNITS[u]['ref'] = refname
    task = os.path.join(adir, '_task.json')
    if os.path.exists(task):
        os.remove(task)
    try:
        for attempt in range(4):
            try:
                gua.step_create(u, a)
                break
            except Exception as e:
                print('  create fail(%d): %s' % (attempt, str(e)[:140]))
                time.sleep(65)
        gua.step_poll(u, a, max_wait=900)
    finally:
        if old_ref:
            UNITS[u]['ref'] = old_ref
    gua.step_build(u, a)
    print('== F regen %s/%s done' % (u, a), flush=True)
    time.sleep(16)

# ── 收尾: repack 改动单位 + 自检 ──
for u in ('fut_arm_titan_mk2', 'fut_arm_heavy_mech', 'mod_sup_m6', 'mod_mlrs',
          'ww1_storm', 'ww1_sup_vickers', 'mod_arm_abrams_mk2',
          'mod_abrams', 'cold_m60', 'ww2_pschreck'):
    d = dname(u)
    rp = importlib.util.spec_from_file_location('rp', 'tools/repack_unit_sheet.py')
    rpm = importlib.util.module_from_spec(rp)
    sys.modules['rp'] = rpm
    rp.loader.exec_module(rpm)
    rpm.repack(d, 'idle')
    rpm.repack(d, 'attack')
    r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py', d],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    lines = (r.stdout or '').strip().splitlines()
    print('[selfcheck %s]' % d, [x for x in lines if 'FAIL' in x] or ['PASS'])
print('FIX6 ALL DONE')
