# -*- coding: utf-8 -*-
"""fix5: x9/growler 加 matte 覆盖并重建 idle; x9 attack prompt 改单兵;
然后从修好的 x9 idle f00 链式重生成 attack; repack+自检
"""
import glob
import importlib.util
import json
import os
import shutil
import sys
import time

from PIL import Image

SRC = 'tools/generate_unit_animations.py'
EXTRA_P = 'tools/unit_animations_extra.json'

extra = json.load(open(EXTRA_P, encoding='utf-8'))
for u in ('fut_inf_x9', 'mod_sup_growler'):
    extra[u]['matte_edge'] = True
    extra[u]['nw_trim'] = False
# x9 attack prompt 单兵化
HEAD = "严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
extra['fut_inf_x9']['anims']['attack']['prompt'] = HEAD + \
    "画面中只有这一名渗透兵，绝对没有第二个人。士兵保持提枪战斗姿势向画面左侧射击：" \
    "仅枪口火光闪烁与枪身轻微后坐，人数、装备、姿态与首帧完全一致，无烟雾弥漫，背景保持纯白。" \
    "镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。纯白色无缝背景，无地面，无阴影，无文字，无水印。"
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

spec = importlib.util.spec_from_file_location('gua', SRC)
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
gua.UNITS.update(extra)

BASE = gua.OUT_DIR


def dname(u):
    import re
    return next(x for x in os.listdir(BASE)
                if re.sub(r'^\d{3}_', '', x).startswith(u + '_'))


# ── ① 重建 x9 idle + growler idle/attack ──
for u, a in [('fut_inf_x9', 'idle'), ('mod_sup_growler', 'idle'), ('mod_sup_growler', 'attack')]:
    adir = os.path.join(BASE, dname(u), a)
    bak = os.path.join(adir, 'bak_fix5')
    os.makedirs(bak, exist_ok=True)
    for f in glob.glob(os.path.join(adir, 'f*.png')):
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
    print('== rebuild %s/%s' % (u, a), flush=True)
    gua.step_build(u, a)

# ── ② x9 attack: 从修好的 idle f00 链式重生成 ──
u, a = 'fut_inf_x9', 'attack'
adir = os.path.join(BASE, dname(u), a)
bak = os.path.join(adir, 'bak_fix5')
os.makedirs(bak, exist_ok=True)
for f in glob.glob(os.path.join(adir, 'f*.png')):
    dst = os.path.join(bak, os.path.basename(f))
    if not os.path.exists(dst):
        shutil.copy2(f, dst)
mp4 = os.path.join(adir, 'source.mp4')
pre = os.path.join(adir, 'source_pre_fix5.mp4')
if os.path.exists(mp4) and not os.path.exists(pre):
    shutil.copy2(mp4, pre)

f0 = sorted(glob.glob(os.path.join(BASE, dname(u), 'idle', 'f*.png')))[0]
im = Image.open(f0).convert('RGBA')
cv = Image.new('RGB', (512, 512), (255, 255, 255))
cv.paste(im, (0, 0), im)
refname = 'fut_inf_x9_fromidle_white.jpg'
cv.save(os.path.join(gua.REF_DIR, refname), quality=92)
old_ref = gua.UNITS[u]['ref']
gua.UNITS[u]['ref'] = refname
try:
    task = os.path.join(adir, '_task.json')
    if os.path.exists(task):
        os.remove(task)
    for attempt in range(4):
        try:
            gua.step_create(u, a)
            break
        except Exception as e:
            print('  create fail(%d): %s' % (attempt, str(e)[:140]))
            time.sleep(65)
    gua.step_poll(u, a, max_wait=900)
finally:
    gua.UNITS[u]['ref'] = old_ref
gua.step_build(u, a)

# ── ③ repack + 自检 ──
spec2 = importlib.util.spec_from_file_location('rp', 'tools/repack_unit_sheet.py')
rp = importlib.util.module_from_spec(spec2)
sys.modules['rp'] = rp
spec2.loader.exec_module(rp)
import subprocess
for u in ('fut_inf_x9', 'mod_sup_growler'):
    d = dname(u)
    rp.repack(d, 'idle')
    rp.repack(d, 'attack')
    r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py', d],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    lines = (r.stdout or '').strip().splitlines()
    print('[selfcheck %s]' % d, [x for x in lines if 'FAIL' in x] or ['PASS'])
print('FIX5 DONE')
