# -*- coding: utf-8 -*-
"""fix4 重生成: growler idle+attack 重摇; x9 idle 提枪蓄势 -> attack 用新 idle f00 链式生成; c96 attack 单兵修正"""
import glob
import importlib.util
import json
import os
import shutil
import sys
import time

from PIL import Image

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)

BASE = r'资料/单位分帧动画'
EXTRA_P = 'tools/unit_animations_extra.json'
STATE_P = 'tools/_fix4_reggen_state.json'

AIR_HEAD = ("严格保持首帧图像中这架EA-18G电子战飞机的外观、比例、涂装与细节完全一致，不改变设计。"
            "机身始终保持首帧的朝向，机头指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
            "飞机居中，机体清晰锐利、线条分明，占据画面约四成，完整展示机身与双翼。")
AIR_TAIL = ("镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。纯白色无缝背景，无地面，"
            "无阴影，无云，无文字，无水印。")

HEAD = "严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"

PROMPTS = {
    "mod_sup_growler": {
        "idle": AIR_HEAD + "战机原地待机：机身随气流极轻微上下浮动，发动机尾喷口微弱闪烁，"
                "翼下电子吊舱指示灯缓慢闪烁。动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。" + AIR_TAIL,
        "attack": AIR_HEAD + "战机向画面左侧释放电子干扰：翼下与机身挂载的电子吊舱发出淡蓝色干扰光波"
                 "向左侧扩散闪烁，机身保持静止，只有吊舱光波脉动，无烟雾，无机炮，无导弹。" + AIR_TAIL,
    },
    "fut_inf_x9": {
        "idle": HEAD + "画面中只有这一名渗透兵，没有其他人物。士兵呈提枪准备开火的战斗姿势："
                "双手将枪提起端平，枪口指向画面左侧，身体微微前倾蓄势待发，目视左侧，"
                "姿势保持稳定，只有极轻微的呼吸起伏与瞄准微调。"
                "镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。纯白色无缝背景，无地面，"
                "无阴影，无文字，无水印。动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。",
    },
    "fut_inf_c96": {
        "attack": HEAD + "画面中只有一名士兵，绝对没有第二个人，没有多出任何人物。"
                  "这名士兵向画面左侧射击：仅枪口火光闪烁与枪身轻微后坐，人数、装备、姿态与首帧完全一致，"
                  "无烟雾弥漫，背景保持纯白。镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。"
                  "纯白色无缝背景，无地面，无阴影，无文字，无水印。",
    },
}

TARGETS = [('mod_sup_growler', 'idle', None), ('mod_sup_growler', 'attack', None),
           ('fut_inf_x9', 'idle', None), ('fut_inf_c96', 'attack', None),
           ('fut_inf_x9', 'attack', 'fut_inf_x9')]


def dname(u):
    for d in os.listdir(BASE):
        if d == u or d.startswith(u + '_'):
            return d
    raise SystemExit('no dir ' + u)


def snapshot(u, a):
    adir = os.path.join(BASE, dname(u), a)
    bak = os.path.join(adir, 'bak_fix4')
    os.makedirs(bak, exist_ok=True)
    for f in glob.glob(os.path.join(adir, 'f*.png')):
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
    mp4 = os.path.join(adir, 'source.mp4')
    pre = os.path.join(adir, 'source_pre_fix4.mp4')
    if os.path.exists(mp4) and not os.path.exists(pre):
        shutil.copy2(mp4, pre)


def ref_from(u, anim):
    adir = os.path.join(BASE, dname(u), anim)
    f0 = sorted(glob.glob(os.path.join(adir, 'f*.png')))[0]
    im = Image.open(f0).convert('RGBA')
    cv = Image.new('RGB', (512, 512), (255, 255, 255))
    cv.paste(im, (0, 0), im)
    out = os.path.join(gua.REF_DIR, '%s_fromidle_white.jpg' % u)
    cv.save(out, quality=92)
    return os.path.basename(out)


state = json.load(open(STATE_P, encoding='utf-8')) if os.path.exists(STATE_P) else {}
extra = json.load(open(EXTRA_P, encoding='utf-8'))
for u, anims in PROMPTS.items():
    for a, p in anims.items():
        extra[u]['anims'][a]['prompt'] = p
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
gua.UNITS.update(extra)
print('prompts patched')

for u, a, ref_src in TARGETS:
    tag = '%s/%s' % (u, a)
    if state.get(tag, {}).get('created'):
        print('skip:', tag)
        continue
    if ref_src:
        state.setdefault(tag, {})['wait_ref'] = ref_src
        json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)
        continue
    snapshot(u, a)
    _create(u, a) if False else None
    for attempt in range(4):
        try:
            gua.step_create(u, a)
            state.setdefault(tag, {})['created'] = True
            json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)
            break
        except Exception as e:
            print('  create fail(%d): %s' % (attempt, str(e)[:140]))
            time.sleep(65)
    else:
        raise RuntimeError('create 耗尽 ' + tag)
    time.sleep(16)

# ── 轮询已创建的 ──
for u, a, ref_src in TARGETS:
    tag = '%s/%s' % (u, a)
    if not state.get(tag, {}).get('created') or state.get(tag, {}).get('polled'):
        continue
    gua.step_poll(u, a, max_wait=900)
    state[tag]['polled'] = True
    json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)

# ── build 已下载的 ──
for u, a, ref_src in TARGETS:
    tag = '%s/%s' % (u, a)
    if not state.get(tag, {}).get('polled') or state.get(tag, {}).get('built'):
        continue
    gua.step_build(u, a)
    state[tag]['built'] = True
    json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)

# ── x9 attack: 用新 idle f00 链式创建 ──
for u, a, ref_src in TARGETS:
    tag = '%s/%s' % (u, a)
    if not ref_src or state.get(tag, {}).get('created'):
        continue
    if not state.get('fut_inf_x9/idle', {}).get('built'):
        print('!! x9 idle 未 build, 跳过链式 attack')
        break
    snapshot(u, a)
    old = UNITS_REF_BACKUP = gua.UNITS[u]['ref']
    gua.UNITS[u]['ref'] = ref_from(ref_src, 'idle')
    print('[%s] chained ref from idle f00: %s' % (tag, gua.UNITS[u]['ref']))
    try:
        for attempt in range(4):
            try:
                gua.step_create(u, a)
                state.setdefault(tag, {})['created'] = True
                json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)
                break
            except Exception as e:
                print('  create fail(%d): %s' % (attempt, str(e)[:140]))
                time.sleep(65)
    finally:
        gua.UNITS[u]['ref'] = old
    gua.step_poll(u, a, max_wait=900)
    state[tag]['polled'] = True
    gua.step_build(u, a)
    state[tag]['built'] = True
    json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)

import subprocess
for u, a, ref_src in TARGETS:
    r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py', dname(u)],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    lines = (r.stdout or '').strip().splitlines()
    print('[selfcheck %s]' % dname(u), [x for x in lines if 'FAIL' in x or '失败' in x] or ['PASS'])
print('FIX4 REGGEN DONE')
