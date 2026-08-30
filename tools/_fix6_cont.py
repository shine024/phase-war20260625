# -*- coding: utf-8 -*-
"""fix6 续: D 删帧 + E 卡图 + F 三重生成 (A/B/C 已完成)"""
import glob
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time

from PIL import Image

EXTRA_P = 'tools/unit_animations_extra.json'
BASE = r'资料/单位分帧动画'

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
UNITS = gua.UNITS
extra = json.load(open(EXTRA_P, encoding='utf-8'))
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


# ── D. abrams_mk2 attack 删第8帧 ──
u = 'mod_arm_abrams_mk2'
aadir = backup(u, 'attack')
f7 = os.path.join(aadir, 'f07.png')
if os.path.exists(f7):
    rest = sorted(os.path.basename(f) for f in glob.glob(os.path.join(aadir, 'f*.png'))
                  if os.path.basename(f) > 'f07.png')
    os.remove(f7)
    for old, new in zip(rest, ['f%02d.png' % i for i in range(7, 7 + len(rest))]):
        os.rename(os.path.join(aadir, old), os.path.join(aadir, new))
    files = ['f%02d.png' % i for i in range(7 + len(rest))]
    meta_set(aadir, files)
    repack(aadir, 'attack')
    print('== D abrams_mk2 attack -> %d frames' % len(files))
else:
    print('== D f07 already gone, skip')

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
print('== E mech card replaced')

# ── F. API 重生成 ──
HEAD = "严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
TAIL = "镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。纯白色无缝背景，无地面，无阴影，无文字，无水印。"

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
        cv_ = Image.new('RGB', (512, 512), (255, 255, 255))
        cv_.paste(im, (0, 0), im)
        refname = '%s_fromidle_white.jpg' % u
        cv_.save(os.path.join(gua.REF_DIR, refname), quality=92)
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

# ── 收尾: repack + 自检 ──
rp = importlib.util.spec_from_file_location('rp', 'tools/repack_unit_sheet.py')
rpm = importlib.util.module_from_spec(rp)
sys.modules['rp'] = rpm
rp.loader.exec_module(rpm)
for u in ('mod_arm_abrams_mk2', 'mod_abrams', 'cold_m60', 'ww2_pschreck'):
    d = dname(u)
    rpm.repack(d, 'idle')
    rpm.repack(d, 'attack')
    r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py', d],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    lines = (r.stdout or '').strip().splitlines()
    print('[selfcheck %s]' % d, [x for x in lines if 'FAIL' in x] or ['PASS'])
print('FIX6 CONT DONE')
