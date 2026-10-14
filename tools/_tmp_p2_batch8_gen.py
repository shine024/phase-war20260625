# -*- coding: utf-8 -*-
"""P2 修复批8（2026-10-12）：mod_icons 外散项 8 张（text2img×4 + img2img×4）。

- runes 3 张（族色/语义修正，凯尔特石徽模板）：common/defense_01 紫⊘→钴蓝防御盾徽、
  common/energy_03 绿→金黄能量天平、legendary/special_06 丰饶角→战争号角
- alloy：扁平白胶囊→厚涂合金锭（对齐资源图标 3D 宝石族）
- pi_atlas_01：img2img 去蜜蜂剪影残留+直升机写实化
- pi_eon_03：img2img 底色相 粉绿→藏青（对齐 eon_01/02）
- pi_helix_04：img2img 玻璃徽记→仪表盘机械渲染（对齐 helix_01-03）
- bg_endless_gate_t2：img2img 奇幻卡通风→写实厚涂（对齐 t0/t1 黑门系，保构图）

产物落 .godot/unit_review/img25_staging/p2_batch8/。断点续跑。
用法: python -I tools/_tmp_p2_batch8_gen.py [name ...]
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
STAGING = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'p2_batch8')
API_MD = os.path.join(ROOT, 'tools', '_agnes_image_api.md')
IMG_API = 'https://apihub.agnes-ai.cn/v1/images/generations'

RUNE_TPL = (
    "一枚圆形石质魔法符文徽章，深灰色岩石圆底，四周凯尔特编绳花纹环绕，"
    "中央浮雕{motif}，{color}能量描线发光。浮雕质感厚重，对称构图，"
    "深色背景，游戏技能图标风格，无文字无水印。"
)

# (name, 模式, src相对路径或None, prompt)
TASKS = [
    ('rune_defense_01_common', 't2i', 'assets/runes/common/rune_defense_01.png',
     RUNE_TPL.format(motif='一面塔盾与交叠的防御壁垒', color='钴蓝色')),
    ('rune_energy_03_common', 't2i', 'assets/runes/common/rune_energy_03.png',
     RUNE_TPL.format(motif='一杆能量天平，两端各悬浮一颗发光能量晶体', color='金黄色')),
    ('rune_special_06_legendary', 't2i', 'assets/runes/legendary/rune_special_06.png',
     RUNE_TPL.format(motif='一支缠绕军旗的战争号角', color='紫晶色')),
    ('alloy', 't2i', 'assets/resources/alloy.png',
     "一枚游戏资源图标：厚涂 3D 质感的银灰色金属合金锭三块叠放，"
     "金属冷光与高光，深色圆形底座徽章。写实手绘厚涂风格，与宝石类资源图标同族，"
     "无文字无水印。"),
    ('pi_atlas_01', 'i2i', 'assets/ui/instruments/pi_atlas_01.png',
     "第一张图是一个战术仪表盘游戏图标。请去除画面中的黑色剪影蜜蜂与小飞虫，"
     "并把黑色扁平剪影直升机改为与仪表盘同风格的写实现代武装直升机群（金属质感、"
     "受光立体），保持仪表盘圆盘构图、青蓝色霓虹光效与整体配色不变。"
     "无文字无水印。"),
    ('pi_eon_03', 'i2i', 'assets/ui/instruments/pi_eon_03.png',
     "第一张图是一个怀表式仪表盘游戏图标，但它的底色相偏绿粉。"
     "请把整体色调改为深藏青蓝（与同系列仪表一致）：表盘底、外圈金属与光效全部"
     "转为藏青蓝系金属质感，只保留指针与刻度的银白金属。保持构图、表盘结构、"
     "星云纹理细节完全不变。无文字无水印。"),
    ('pi_helix_04', 'i2i', 'assets/ui/instruments/pi_helix_04.png',
     "第一张图是一个扁平玻璃质感的徽记游戏图标，与同系列的机械仪表盘风格断裂。"
     "请把它重绘为立体金属仪表盘质感：中央保持同样的对称翼形徽记构图，"
     "但改为拉丝金属浮雕+青绿色霓虹光效+圆形仪表盘外圈结构（带刻度与铆钉）。"
     "无文字无水印。"),
    ('bg_endless_gate_t2', 'i2i', 'assets/backgrounds/bg_endless_gate_t2.png',
     "第一张图是游戏关卡背景：浮空平台与两座巨门。它目前是高饱和奇幻卡通风格，"
     "与系列的写实厚涂战争风断裂。请保持完全相同的构图（前景浮岩平台、中央漩涡巨门、"
     "星云天空），重绘为写实厚涂战争风：暗黑破败的巨型石门与能量漩涡、"
     "裂纹浮空岩台、低饱和冷色（紫灰/暗青/铁黑），末世战场氛围。无文字无水印。"),
]


def get_keys() -> list:
    txt = open(API_MD, encoding='utf-8').read()
    keys = re.findall(r'sk-[A-Za-z0-9]{20,}', txt)
    if not keys:
        raise SystemExit('no key in ' + API_MD)
    return keys


def to_data_uri(path: str) -> str:
    with open(path, 'rb') as f:
        return 'data:image/png;base64,' + base64.b64encode(f.read()).decode()


def flatten_white(im: Image.Image) -> Image.Image:
    bg = Image.new('RGBA', im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    return bg.convert('RGB')


def gen_one(task, keys: list, idx: int) -> bool:
    name, mode, src_rel, prompt = task
    body = {
        'model': 'agnes-image-2.5-flash',
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024' if not name.startswith('bg_') else '1376x768',
        'response_format': 'b64_json',
    }
    if mode == 'i2i':
        uri = to_data_uri(os.path.join(STAGING, name + '_in.png'))
        body['extra_body'] = {'image': [uri], 'response_format': 'b64_json'}
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
        im.save(os.path.join(STAGING, name + '_raw.png'))
        print(f'  ok {name} {im.size}', flush=True)
        return True
    return False


def main() -> None:
    os.makedirs(STAGING, exist_ok=True)
    keys = get_keys()
    only = set(sys.argv[1:]) or None
    for i, task in enumerate(TASKS):
        name, mode, src_rel, _ = task
        if only and name not in only:
            continue
        raw_out = os.path.join(STAGING, name + '_raw.png')
        if os.path.isfile(raw_out):
            print(f'[{i}] {name}: 已存在跳过', flush=True)
            continue
        if mode == 'i2i':
            im = Image.open(os.path.join(ROOT, src_rel)).convert('RGBA')
            flatten_white(im).save(os.path.join(STAGING, name + '_in.png'))
        print(f'[{i}] {name} ({mode}) ...', flush=True)
        gen_one(task, keys, i)


if __name__ == '__main__':
    main()
