# -*- coding: utf-8 -*-
"""P2 修复批7（2026-10-12）：mod_icons 生成包 27 张（128px 升清 4 + 漂移 2 +
弱匹配 11 + 近重复换主体 10）。管线同批5（_tmp_p1i_modicons_gen.py）。

族色采样定案：aa=钴蓝方框 / eng=橙 / for=橙红 / gen=银白（gen_21-23=mythic
红圆徽档保留）/ air=冰青 / inf=荧光绿 / rec=霓虹紫 / art=橙金 / enh=紫粉。
产物只落 .godot/unit_review/img25_staging/mod_icons_p2/（目验后布置）。
断点续跑。用法: python -I tools/_tmp_p2_batch7_icons_gen.py [name ...]
"""
import base64
import io
import json
import os
import re
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
STAGING = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'mod_icons_p2')
API_MD = os.path.join(ROOT, 'tools', '_agnes_image_api.md')
IMG_API = 'https://apihub.agnes-ai.cn/v1/images/generations'

BLUE = '鲜艳的钴蓝色（bright cobalt blue，严禁青色或金色）'
CYAN = '鲜艳的冰青蓝色（bright cyan，严禁银白或无彩色）'
SILVER = '银白色（silver-white）'
GREEN = '鲜艳的荧光绿色（bright neon green，严禁银白或无彩色）'
PURPLE = '鲜艳的霓虹紫色（bright neon purple，严禁银白或无彩色）'
GOLD = '鲜艳的橙金色（bright golden orange，严禁银白或无彩色）'
ORANGE = '鲜艳的暖橙色（bright warm orange，区别于金黄）'
ORRED = '鲜艳的橙红色（bright orange-red）'
RED = '鲜艳的深红色（bright crimson red，mythic 红档）'
MAGENTA = '鲜艳的品红紫色（bright magenta-purple）'

FRAME = '画面四周一个华丽的对称霓虹边框（八角星形尖角勋章框，多层描线，强光晕）'
ROUND = '画面中央一个华丽的圆形霓虹徽章（环形多层描线，强光晕），徽章外无方框'

ICONS = [
    # --- 128px 升清 4（aa_06 断族修正回蓝框；gen_21-23 保红圆徽档）---
    (BLUE, FRAME, 'aa_06_laser', '一台发射激光束的激光发射器'),
    (RED, ROUND, 'gen_21_vanguard_repair', '交叉的扳手与维修焊枪（先锋抢修）'),
    (RED, ROUND, 'gen_22_aegis_protocol', '一面蜂窝纹理的能量盾牌（宙斯盾协议）'),
    (RED, ROUND, 'gen_23_singularity_core', '一个被光环环绕的黑洞奇点核心'),
    # --- 风格漂移 2 ---
    (ORANGE, FRAME, 'eng_01_mine_sweeper', '一辆带扫雷辊的装甲工程车（厚涂质感）'),
    (CYAN, FRAME, 'air_05_helmet_sight', '一顶带HUD瞄准显示的飞行头盔（霓虹线稿质感）'),
    # --- 弱匹配/抽象 11 ---
    (BLUE, FRAME, 'aa_02_iff', '敌我识别应答机：雷达屏上一个问号信号被判定为友军勾选标记'),
    (SILVER, FRAME, 'gen_02_digital', '一名士兵剪影正在分解为上升的像素方块与数据流（数字化改造，剪影一半实体一半像素化）'),
    (SILVER, FRAME, 'gen_07_mine_resistant', '装甲车底的V形防雷车底装甲断面'),
    (SILVER, FRAME, 'gen_stealth_coating', '一架战机轮廓表面覆盖消波纹隐身涂层，边缘信号波被吸收'),
    (SILVER, FRAME, 'gen_17_electronic_hijack', '入侵线缆刺入电路板，数据流被劫持改道'),
    (PURPLE, FRAME, 'rec_11_decoy', '一辆充气式假坦克诱饵目标'),
    (GOLD, FRAME, 'art_14_counter_battery', '反炮兵雷达探测来袭炮弹并标记反击弧线'),
    (CYAN, FRAME, 'air_02_vector_thrust', '发动机尾喷口向下偏转喷射矢量尾焰'),
    (GREEN, FRAME, 'inf_32_heavy_barrel', '一挺粗重加厚的重枪管特写'),
    (ORRED, FRAME, 'for_12_anti_tank_trench', '反坦克壕沟断面：深沟与斜坡上残留履带痕迹'),
    (MAGENTA, FRAME, 'enh_regen_up', '一只医疗箱上方升起再生光十字与向上光箭头'),
    # --- 近重复池换主体 10 ---
    (GREEN, FRAME, 'inf_17_tourniquet', '一条扎紧在肢体上的止血带束带'),
    (GREEN, FRAME, 'inf_18_ifak', '一只打开的单兵急救包，内嵌药品格'),
    (GREEN, FRAME, 'inf_25_medic_sacrifice', '一顶低垂的军医钢盔与佩戴的十字徽章'),
    (GREEN, FRAME, 'inf_34_kill_field_dressing', '一卷战地绷带卷'),
    (PURPLE, FRAME, 'rec_10_medkit', '一只带提手的军医手提急救箱'),
    (ORANGE, FRAME, 'eng_08_medical', '一台工程医疗单元：机械臂托着医疗罐'),
    (GREEN, FRAME, 'inf_30_load_vest', '一件挂满弹匣包的弹药携行背心'),
    (PURPLE, FRAME, 'rec_14_crit_designator', '激光指示准星中央带一枚爆裂四芒星（暴击标记）'),
    (GOLD, FRAME, 'sup_targeting_drone', '一架无人机向下发射目标照射激光束'),
    (ORANGE, FRAME, 'eng_16_field_generator', '一台野战发电机组连着电缆盘'),
]

TPL = (
    "深黑色背景的正方形游戏升级图标，霓虹发光风格，{color}色调。"
    "{frame}，"
    "正中央是一个{motif}，同样{color}霓虹发光质感，细节清晰锐利，"
    "占画面约一半大小。对称构图，深底霓虹描线游戏图标风格，无文字、无水印、无场景。"
)


def get_keys() -> list:
    txt = open(API_MD, encoding='utf-8').read()
    keys = re.findall(r'sk-[A-Za-z0-9]{20,}', txt)
    if not keys:
        raise SystemExit('no key in ' + API_MD)
    return keys


def gen_one(prompt: str, keys: list, idx: int, out_path: str) -> bool:
    body = {
        'model': 'agnes-image-2.5-flash',
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024',
        'response_format': 'b64_json',
    }
    payload = os.path.join(STAGING, '_payload.json')
    with open(payload, 'w', encoding='utf-8') as f:
        json.dump(body, f)
    for attempt in range(3):
        key = keys[(idx + attempt) % len(keys)]
        try:
            r = subprocess.run(
                ['curl', '--http1.1', '-s', '-X', 'POST', IMG_API,
                 '-H', 'Authorization: Bearer ' + key,
                 '-H', 'Content-Type: application/json',
                 '--data-binary', '@' + payload, '--max-time', '360'],
                capture_output=True, text=True, timeout=380)
        except subprocess.TimeoutExpired:
            print(f'  a{attempt}: timeout')
            continue
        try:
            d = json.loads(r.stdout)
        except Exception:
            print(f'  a{attempt}: 非 JSON', r.stdout[:100])
            time.sleep(5)
            continue
        if d.get('error') or d.get('code'):
            print(f'  a{attempt}: API报错', json.dumps(d, ensure_ascii=False)[:150])
            time.sleep(5)
            continue
        item = (d.get('data') or [{}])[0]
        raw = None
        if item.get('b64_json'):
            raw = base64.b64decode(item['b64_json'])
        elif item.get('url'):
            dl = subprocess.run(['curl', '--http1.1', '-s', '-L', item['url'],
                                 '--max-time', '120'], capture_output=True, timeout=140)
            raw = dl.stdout
        if not raw:
            print(f'  a{attempt}: 空data')
            continue
        im = Image.open(io.BytesIO(raw))
        im.save(out_path)
        print(f'  ok {os.path.basename(out_path)} {im.size}', flush=True)
        return True
    return False


def main() -> None:
    os.makedirs(STAGING, exist_ok=True)
    keys = get_keys()
    only = set(sys.argv[1:]) or None
    todo = [(c, f, n, m) for c, f, n, m in ICONS if not only or n in only]
    done = fail = 0
    for i, (color, frame, name, motif) in enumerate(todo):
        out = os.path.join(STAGING, name + '.png')
        if os.path.isfile(out):
            print(f'[{i + 1}/{len(todo)}] {name}: 已存在跳过', flush=True)
            done += 1
            continue
        print(f'[{i + 1}/{len(todo)}] {name} ...', flush=True)
        if gen_one(TPL.format(color=color, frame=frame, motif=motif), keys, i, out):
            done += 1
        else:
            fail += 1
            print(f'  [fail] {name}')
    print(f'done={done} fail={fail} / {len(todo)}')


if __name__ == '__main__':
    main()
