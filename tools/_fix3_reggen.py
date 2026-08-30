# -*- coding: utf-8 -*-
"""fix3 重生成驱动: prompt 修正 -> 快照 -> 自定义参考图(bazooka/fut_mech 用 attack 首帧)
-> 16s 限速创建 -> 轮询下载 -> build -> selfcheck
状态文件 tools/_fix3_reggen_state.json 保证可断点续跑
"""
import glob
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
UNITS = gua.UNITS

BASE = r'资料/单位分帧动画'
EXTRA_P = 'tools/unit_animations_extra.json'
STATE_P = 'tools/_fix3_reggen_state.json'

HEAD = "严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
TAIL = "镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。纯白色无缝背景，无地面，无阴影，无文字，无水印。"

PROMPTS = {
    "ww1_arty_m81": {"attack": HEAD +
        "画面中绝对没有任何士兵或人物，只有迫击炮武器本身。迫击炮向画面左上方开火："
        "仅炮口处火光一闪伴少量硝烟，炮身极轻微后坐随即复位，除此之外没有任何其他动作，无人操作。" + TAIL},
    "cold_sup_zsu23": {"attack": HEAD +
        "画面中只有ZSU-23-4自行高炮本身，没有任何士兵或人物。四联装炮管向画面左侧连续射击："
        "仅炮口火光连续闪烁，车身、炮塔、履带保持完全静止，没有后坐位移，没有弹链抽动，没有抛壳，"
        "没有任何其他动作。" + TAIL},
    "cold_fort_missile": {"attack": HEAD +
        "导弹发射井开火：井盖开启，一枚导弹从井中垂直向上发射升空，导弹笔直向上飞出，"
        "尾焰在井口向下喷涌，井体轻微震动，除此之外没有任何其他动作，没有任何人物。"
        "井体主体始终完整在画面内。" + TAIL},
    "ww1_sup_vickers": {"idle": HEAD +
        "维克斯机枪阵地几乎完全静止待机：枪身与三脚架、沙袋工事全部纹丝不动，"
        "只有枪管周围极轻微的热浪扰动与枪身极微小的颤动，动作幅度非常小，没有任何人员活动，"
        "没有任何大动作。镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。"
        "纯白色无缝背景，无地面，无阴影，无文字，无水印。动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。"},
    "ww2_arty_hummel": {"attack": HEAD +
        "画面中绝对没有任何士兵或人物，只有黄蜂自行火炮本身。主炮向画面左侧开火："
        "炮口火光闪现，炮管后坐复位，车身其余部分保持静止，除此之外没有任何其他动作。" + TAIL},
    "mod_sup_growler": {
        "idle": "严格保持首帧图像中这架EA-18G电子战飞机的外观、比例、涂装与细节完全一致，不改变设计。"
        "机身始终保持首帧的朝向，机头指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
        "战机原地待机：机身随气流极轻微上下浮动，发动机尾喷口微弱闪烁，翼下电子吊舱指示灯缓慢闪烁。"
        "镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。纯白色无缝背景，无地面，"
        "无阴影，无云，无文字，无水印。动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。",
        "attack": "严格保持首帧图像中这架EA-18G电子战飞机的外观、比例、涂装与细节完全一致，不改变设计。"
        "机身始终保持首帧的朝向，机头指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
        "战机向画面左侧释放电子干扰：翼下与机身挂载的电子吊舱发出淡蓝色干扰光波向左侧扩散闪烁，"
        "机身保持静止，只有吊舱光波脉动，无烟雾，无机炮，无导弹。" + TAIL},
    "fut_inf_x9": {"attack": HEAD +
        "士兵们保持站位与队形完全不变，向画面左侧连续射击：仅枪口火光闪烁与枪身轻微后坐，"
        "人数、装备、姿态与首帧完全一致，无烟雾弥漫，背景保持纯白。" + TAIL},
    "fut_inf_c96": {"attack": HEAD +
        "士兵们保持站位与队形完全不变，向画面左侧连续射击：仅枪口火光闪烁与枪身轻微后坐，"
        "人数、装备、姿态与首帧完全一致，无烟雾弥漫，背景保持纯白。" + TAIL},
    "ww2_inf_bazooka": {"idle": HEAD +
        "画面中没有任何士兵或人物，只有架设好的巴祖卡火箭筒武器本身，没有任何人趴在、站在或出现在武器上。"
        "武器原地静止待机：仅极轻微的待机震颤，除此之外没有任何动作。"
        "镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。纯白色无缝背景，无地面，"
        "无阴影，无文字，无水印。动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。"},
}

# (unit, anim, custom_ref_from_attack)
TARGETS = [
    ('ww1_arty_m81', 'attack', False),
    ('cold_sup_zsu23', 'attack', False),
    ('cold_fort_missile', 'attack', False),
    ('ww1_sup_vickers', 'idle', False),
    ('ww2_arty_hummel', 'attack', False),
    ('mod_sup_growler', 'idle', False),
    ('mod_sup_growler', 'attack', False),
    ('fut_inf_x9', 'attack', False),
    ('fut_inf_c96', 'attack', False),
    ('ww2_inf_bazooka', 'idle', True),
    ('fut_mech', 'idle', True),
]


def dname(u):
    for d in os.listdir(BASE):
        if d == u or d.startswith(u + '_'):
            return d
    raise SystemExit('no dir ' + u)


def snapshot(u, a):
    adir = os.path.join(BASE, dname(u), a)
    bak = os.path.join(adir, 'bak_fix3')
    os.makedirs(bak, exist_ok=True)
    for f in glob.glob(os.path.join(adir, 'f*.png')):
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
    mp4 = os.path.join(adir, 'source.mp4')
    pre = os.path.join(adir, 'source_pre_fix3.mp4')
    if os.path.exists(mp4) and not os.path.exists(pre):
        shutil.copy2(mp4, pre)


def custom_ref(u):
    """attack f00 -> 白底512 jpg"""
    adir = os.path.join(BASE, dname(u), 'attack')
    f0 = sorted(glob.glob(os.path.join(adir, 'f*.png')))[0]
    im = Image.open(f0).convert('RGBA')
    cv = Image.new('RGB', (512, 512), (255, 255, 255))
    cv.paste(im, (0, 0), im)
    out = os.path.join(gua.REF_DIR, '%s_fromattack_white.jpg' % u)
    cv.save(out, quality=92)
    return out


state = json.load(open(STATE_P, encoding='utf-8')) if os.path.exists(STATE_P) else {}

# ── ① 写回 prompt(json) ──
extra = json.load(open(EXTRA_P, encoding='utf-8'))
for u, anims in PROMPTS.items():
    if u in extra:
        for a, p in anims.items():
            extra[u]['anims'][a]['prompt'] = p
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
gua.UNITS.update(extra)  # 关键: 刷新内存 UNITS, 否则 create 用旧 prompt
print('prompts patched:', sum(len(v) for v in PROMPTS.values()))

# ── ② 快照 + 自定义 ref + 创建 ──
for u, a, custom in TARGETS:
    tag = '%s/%s' % (u, a)
    if state.get(tag, {}).get('created'):
        print('skip create (done):', tag)
        continue
    snapshot(u, a)
    old_ref = None
    if custom:
        ref_path = custom_ref(u)
        old_ref = UNITS[u]['ref']
        UNITS[u]['ref'] = os.path.basename(ref_path)
        print('[%s] custom ref from attack f00: %s' % (tag, os.path.basename(ref_path)))
    try:
        for attempt in range(4):
            try:
                gua.step_create(u, a)
                state.setdefault(tag, {})['created'] = True
                json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)
                break
            except Exception as e:
                msg = str(e)
                print('  create fail(%d): %s' % (attempt, msg[:160]))
                if 'rate' in msg.lower() or 'queue' in msg.lower() or 'limit' in msg.lower():
                    time.sleep(65)
                else:
                    raise
        else:
            raise RuntimeError('create 重试耗尽 ' + tag)
    finally:
        if old_ref:
            UNITS[u]['ref'] = old_ref
    time.sleep(16)

# ── ③ 轮询 + 下载 ──
for u, a, custom in TARGETS:
    tag = '%s/%s' % (u, a)
    if state.get(tag, {}).get('polled'):
        print('skip poll (done):', tag)
        continue
    gua.step_poll(u, a, max_wait=900)
    state.setdefault(tag, {})['polled'] = True
    json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)

# ── ④ build ──
for u, a, custom in TARGETS:
    tag = '%s/%s' % (u, a)
    if state.get(tag, {}).get('built'):
        print('skip build (done):', tag)
        continue
    gua.step_build(u, a)
    state.setdefault(tag, {})['built'] = True
    json.dump(state, open(STATE_P, 'w', encoding='utf-8'), ensure_ascii=False)

# ── ⑤ selfcheck ──
for u, a, custom in TARGETS:
    r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py', dname(u)],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[selfcheck %s] %s' % (dname(u), tail[-1] if tail else 'no-output'))
print('REGGEN ALL DONE')
