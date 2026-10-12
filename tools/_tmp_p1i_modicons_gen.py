# -*- coding: utf-8 -*-
"""P1-I mod_icons 28 张重生成（2026-10-12）：火苗模板池 22 + 错配 6。

族色（采样定案）：air/arm=冰青、gen=银白、inf=荧光绿、rec=霓虹紫、art=橙金。
风格模板 text2img（不喂火苗锚——img2img 会残留火苗先验）：深黑底+华丽对称
霓虹勋章框+中央母题。尺寸 1024²（族标准，arm_04/art_13 的 128px 离群顺带清）。

产物只落 .godot/unit_review/img25_staging/mod_icons/（staging 铁律，目验后布置）。
断点续跑：已存在的输出跳过。用法:
  python -I tools/_tmp_p1i_modicons_gen.py          # 全量
  python -I tools/_tmp_p1i_modicons_gen.py air_08_ecm gen_20_squad_tablet  # 子集
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
STAGING = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'mod_icons')
API_MD = os.path.join(ROOT, 'tools', '_agnes_image_api.md')
IMG_API = 'https://apihub.agnes-ai.cn/v1/images/generations'

CYAN = '鲜艳的冰青蓝色（bright cyan，严禁银白或无彩色）'
SILVER = '银白色（silver-white）'
GREEN = '鲜艳的荧光绿色（bright neon green，严禁银白或无彩色）'
PURPLE = '鲜艳的霓虹紫色（bright neon purple，严禁银白或无彩色）'
GOLD = '鲜艳的橙金色（bright golden orange，严禁银白或无彩色）'

ICONS = [
    # --- 火苗模板池 22 ---
    (CYAN, 'air_08_ecm', '发射同心波纹的电子干扰天线阵列'),
    (CYAN, 'air_09_air_refuel', '空中加油装置：加油机的加油锥套与受油探头对接'),
    (CYAN, 'air_10_drop_tank', '一枚流线型纺锤状飞机副油箱'),
    (CYAN, 'air_12_data_link', '两个节点之间由光点串联的数据链路'),
    (CYAN, 'air_13_ejection_seat', '带导轨与火箭包的飞行员弹射座椅'),
    (CYAN, 'air_14_swing_wing', '一架变后掠翼战机的俯视图，机翼呈可变后掠状态'),
    (CYAN, 'air_16_phase_shift', '一架战机实体与其半透明相位残影重叠'),
    (CYAN, 'air_17_bombsight', '轰炸瞄准具：十字准星套住地面目标圆环'),
    (CYAN, 'air_22_countermeasure', '一架飞机尾部洒出一幕干扰曳光弹'),
    (CYAN, 'air_23_cockpit_armor', '带附加装甲板的战机座舱盖'),
    (CYAN, 'air_24_canard', '一架带前置鸭翼的战机俯视图'),
    (CYAN, 'air_25_dual_mode_seeker', '导弹导引头镜头同时发出红外与雷达两组波纹'),
    (CYAN, 'air_26_drone_wingman', '一架小型作战无人机（僚机）'),
    (CYAN, 'air_thermolite_bomb', '一枚温压炸弹：纺锤弹体带爆燃波纹'),
    (CYAN, 'arm_11_fire_control', '火控系统：火控雷达碟与弹道预测线交织'),
    (CYAN, 'arm_12_thermal_sight', '热像观瞄镜：圆形热成像镜头带温度分划'),
    (SILVER, 'gen_09_ir_jammer', '一台发射锥形干扰波的红外干扰发射器'),
    (GREEN, 'inf_21_thermal', '单目热成像观察仪'),
    (GREEN, 'inf_29_iron_sights', '步枪机械瞄具：准星与照门对齐'),
    (PURPLE, 'rec_02_ir_suppression', '一台发射压制波束的红外压制装置'),
    (GOLD, 'art_06_fire_computer', '弹道计算机：计算机屏幕上显示弹道曲线'),
    (GOLD, 'art_09_rapid_fire', '速射：旋转炮管加特林机枪与抛出的弹壳'),
    # --- 错配 6 ---
    (GREEN, 'inf_09_dual_mag', '两个并联在一起的步枪弹匣（双弹匣）'),
    (SILVER, 'gen_20_squad_tablet', '显示战术地图的军用加固平板电脑'),
    (CYAN, 'arm_13_deep_wading', '装甲车辆深水涉水：车体浸入水中露出涉水通气管'),
    (CYAN, 'arm_19_track_guards', '带防护板的坦克履带段'),
    (CYAN, 'arm_04_aps', '主动防护系统：雷达探测来袭导弹并射出拦截弹'),
    (GOLD, 'art_13_apfsds_sabot', '尾翼稳定脱壳穿甲弹弹芯（细长杆+尾翼）'),
]

TPL = (
    "深黑色背景的正方形游戏升级图标，霓虹发光风格，{color}色调。"
    "画面四周一个华丽的对称霓虹勋章边框（八角星形尖角框，多层描线，强光晕），"
    "正中央是一个{motif}，同样{color}霓虹发光金属质感，细节清晰锐利，"
    "占画面约一半大小。对称构图，深底霓虹描线游戏图标风格，无文字、无水印、无场景。"
)


def get_keys() -> list:
    txt = open(API_MD, encoding='utf-8').read()
    keys = re.findall(r'sk-[A-Za-z0-9]{20,}', txt)
    if not keys:
        raise SystemExit('no key in ' + API_MD)
    return keys


def gen_one(uri_none: None, prompt: str, keys: list, idx: int, out_path: str) -> bool:
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
            print(f'  {out_path} a{attempt}: timeout')
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
    todo = [(c, n, m) for c, n, m in ICONS if not only or n in only]
    done = fail = 0
    for i, (color, name, motif) in enumerate(todo):
        out = os.path.join(STAGING, name + '.png')
        if os.path.isfile(out):
            print(f'[{i + 1}/{len(todo)}] {name}: 已存在跳过', flush=True)
            done += 1
            continue
        print(f'[{i + 1}/{len(todo)}] {name} ...', flush=True)
        if gen_one(None, TPL.format(color=color, motif=motif), keys, i, out):
            done += 1
        else:
            fail += 1
            print(f'  [fail] {name}')
    print(f'done={done} fail={fail} / {len(todo)}')


if __name__ == '__main__':
    main()
