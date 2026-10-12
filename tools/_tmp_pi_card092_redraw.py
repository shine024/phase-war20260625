# -*- coding: utf-8 -*-
"""P1-G 卡图 vis_092 重绘（2026-10-12）：img2img 提完成度对齐 091/093 写实标准。

病：092 线稿感半透明球形机甲（中心 alpha 126 玻璃感），同族 091/093 写实灰蓝
战机——同族内完成度/风格断裂。
路：原 092 铺白底 → agnes img2img（extra_body.image 数组）→ 保构图保冷蓝色相，
提金属质感完成度 → chroma 去白底回透明 → staging 对比图目验。
enemy=原图，player=水平翻转（镜像惯例 diff 0.0 已验证）。

用法: python -I tools/_tmp_pi_card092_redraw.py [rolls]
"""
import base64
import io
import json
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'assets', 'card_icons', 'enemy', 'vis_enemy_092.png')
STAGING = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging')
API_MD = os.path.join(ROOT, 'tools', '_agnes_image_api.md')
IMG_API = 'https://apihub.agnes-ai.cn/v1/images/generations'

PROMPT = (
    "第一张图是一张科幻卡牌插画：一个球形战斗机甲（带侧翼与机械爪）。"
    "但它完成度过低，呈半透明线稿感/玻璃质感，与同系列其他卡牌的写实金属质感断裂。\n"
    "请输出重绘后的新图，要求：\n"
    "【保持】完全保持第一张图的构图、视角、姿态与大小——球形机甲主体、侧翼、"
    "机械爪等全部部件逐一对齐，不增不减不改位置；主体淡蓝灰冷色调保持不变。\n"
    "【只提完成度】改为完全不透明的实金属机甲：清晰明暗光影、铆钉与装甲板缝隙等"
    "结构细节清晰可读、哑光军事涂装；最亮处有高光，暗部层次分明。\n"
    "【背景】整幅纯白色平涂，无场景无地面无投影。\n"
    "【严禁】半透明、玻璃质感、线稿风、改变视角或姿态、增删部件、文字、水印、边框。"
)


def get_keys() -> list:
    txt = open(API_MD, encoding='utf-8').read()
    keys = re.findall(r'sk-[A-Za-z0-9]{20,}', txt)
    if not keys:
        raise SystemExit('no key in ' + API_MD)
    return keys


def to_data_uri(path: str) -> str:
    with open(path, 'rb') as f:
        b = f.read()
    return 'data:image/png;base64,' + base64.b64encode(b).decode()


def flatten_white(im: Image.Image) -> Image.Image:
    """透明底铺白底（img2img 需不透明输入）。"""
    bg = Image.new('RGBA', im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    return bg.convert('RGB')


def gen_one(uri: str, keys: list, idx: int, out_path: str) -> bool:
    """payload 落盘 --data-binary @file（命令行超长坑）；b64/url 双兼容。"""
    body = {
        'model': 'agnes-image-2.5-flash',
        'prompt': PROMPT,
        'n': 1,
        'size': '1024x1024',
        'response_format': 'b64_json',
        'extra_body': {'image': [uri], 'response_format': 'b64_json'},
    }
    payload = os.path.join(STAGING, '_card092_payload.json')
    with open(payload, 'w', encoding='utf-8') as f:
        json.dump(body, f)
    for attempt in range(3):
        key = keys[(idx + attempt) % len(keys)]
        r = subprocess.run(
            ['curl', '--http1.1', '-s', '-X', 'POST', IMG_API,
             '-H', 'Authorization: Bearer ' + key,
             '-H', 'Content-Type: application/json',
             '--data-binary', '@' + payload, '--max-time', '360'],
            capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print(f'R{idx} a{attempt}: 非 JSON', r.stdout[:120])
            continue
        if d.get('error') or d.get('code'):
            print(f'R{idx} a{attempt}: API 报错', json.dumps(d, ensure_ascii=False)[:180])
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
            print(f'R{idx} a{attempt}: 空 data', json.dumps(d, ensure_ascii=False)[:180])
            continue
        im = Image.open(io.BytesIO(raw)).convert('RGB')
        im.save(out_path)
        print(f'R{idx}: saved {out_path} {im.size}')
        return True
    return False


def chroma_white(path: str, out_path: str) -> None:
    """去纯白底回透明（边缘连通 BFS + 品红兼容由 v3 简化：本图无品红）。"""
    from collections import deque
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    rgb = a[..., :3].astype(int)
    near_white = (rgb.min(axis=2) >= 235) & (rgb.max(axis=2) - rgb.min(axis=2) <= 12)
    h, w = near_white.shape
    seen = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near_white[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near_white[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                dq.append((ny, nx))
    a[seen, 3] = 0
    # 半透明白边软化：贴近背景域 1px 内 alpha 128
    Image.fromarray(a, 'RGBA').save(out_path)
    print('chroma ->', out_path, 'bg frac', round(float(seen.mean()), 3))


def main() -> None:
    rolls = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    os.makedirs(STAGING, exist_ok=True)
    keys = get_keys()
    uri = to_data_uri(os.path.join(STAGING, 'vis_enemy_092_white.png'))
    outs = []
    for i in range(rolls):
        raw = os.path.join(STAGING, f'vis_enemy_092_redraw_R{i + 1}.png')
        if gen_one(uri, keys, i, raw):
            outs.append(raw)
    if not outs:
        raise SystemExit('all rolls failed')
    for i, raw in enumerate(outs):
        chroma_white(raw, raw.replace('_redraw_', '_redraw_c_'))
    print('rolls done:', [os.path.basename(o) for o in outs])


if __name__ == '__main__':
    if not os.path.isfile(os.path.join(STAGING, 'vis_enemy_092_white.png')):
        flatten_white(Image.open(SRC).convert('RGBA')).save(
            os.path.join(STAGING, 'vis_enemy_092_white.png'))
        print('white flattened saved')
    main()
