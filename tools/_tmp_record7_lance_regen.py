# -*- coding: utf-8 -*-
"""刺刀突击班（drop_phase_lance，原"相位刺刀班"）卡图重生成（记录7 追加，用户裁决）。

用户三点：①改名去未来风（另案已改 unified_card_table/card_flavor_texts）
②重新出图（原图=未来装甲+能量刺刀，与 WW2 时代违和）③背包卡图半截（根因=_thumb384
陈旧裁切缩略图，另案全量刷新）。

本脚本：agnes 文生图（prompt 按 _agnes_image_api.md 正面意象锁死纪律）→ 白底泛洪转
透明 → 内容 fit 512 画布（脚线留 31px 底边距，与卡图家族一致）→ player/enemy 镜像双份。
原图备份 .godot/art_backup_lance_regen_20260924/。
可重跑：python tools/_tmp_record7_lance_regen.py
"""
import base64
import json
import os
import re
import subprocess

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, 'tools', '_agnes_image_api.md')
BASE_URL = 'https://apihub.agnes-ai.com/v1'
MODEL = 'agnes-image-2.1-flash'
RAW_DIR = os.path.join(ROOT, '.godot', 'art_regen')
BACKUP = os.path.join(ROOT, '.godot', 'art_backup_lance_regen_20260924')

PROMPT = (
    "One World War Two infantry soldier in an early-1940s field-grey wool uniform and "
    "steel helmet, standing in a full-body alert firing stance facing right, holding an "
    "early assault rifle fitted with a long fixed sword bayonet pointed slightly upward. "
    "Hand-painted digital illustration in a stylized tabletop-card art style, visible "
    "painterly brush strokes, muted palette of field grey, olive brown and gunmetal, "
    "soft even lighting, crisp clean silhouette. "
    "The complete figure from helmet to boots is fully inside the frame with generous "
    "empty margin around the soldier, standing on an invisible floor line, isolated on "
    "a plain pure white background. No text, no border, no frame, no watermark."
)


def load_keys():
    src = open(KEY_MD, 'r', encoding='utf-8').read()
    keys = re.findall(r'sk-[A-Za-z0-9]{20,}', src)
    if not keys:
        raise SystemExit('tools/_agnes_image_api.md 里找不到 key')
    return keys


def call_api(prompt, key, out, size):
    payload = json.dumps({'model': MODEL, 'prompt': prompt, 'size': size, 'n': 1})
    tmp, resp = out + '.payload.json', out + '.resp.json'
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(payload)
    subprocess.run(['curl', '--http1.1', '-s', '-X', 'POST', BASE_URL + '/images/generations',
                    '-H', 'Authorization: Bearer ' + key, '-H', 'Content-Type: application/json',
                    '--data-binary', '@' + tmp, '-o', resp, '--max-time', '180'],
                   capture_output=True, text=True, timeout=200)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    content = open(resp, 'r', encoding='utf-8', errors='replace').read()
    try:
        os.unlink(resp)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        print('  非法响应: ' + content[:160])
        return False
    url = (data.get('data') or [{}])[0].get('url', '')
    if url:
        subprocess.run(['curl', '--http1.1', '-s', '-L', '-o', out, url, '--max-time', '180'],
                       capture_output=True, text=True, timeout=200)
        return os.path.exists(out) and os.path.getsize(out) > 5000
    b64 = (data.get('data') or [{}])[0].get('b64_json', '')
    if b64:
        with open(out, 'wb') as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 5000
    print('  无图像数据: ' + content[:160])
    return False


def flood_white_to_alpha(im, tol=232):
    im = im.convert('RGBA')
    w, h = im.size
    px = im.load()
    near_white = lambda x, y: (lambda c: c[3] > 160 and c[0] >= tol and c[1] >= tol and c[2] >= tol)(px[x, y])
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if near_white(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near_white(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                stack.append((x, y))
    n = 0
    while stack:
        x, y = stack.pop()
        r, g, b, a = px[x, y]
        px[x, y] = (r, g, b, 0)
        n += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and near_white(nx, ny):
                seen[ny * w + nx] = 1
                stack.append((nx, ny))
    return im, n


def fit_512(im):
    """内容 fit 512 画布：等比放到内容高 440，脚线底边距 31，水平居中。"""
    bbox = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bbox:
        return None
    content = im.crop(bbox)
    ch = content.height
    scale = 440.0 / ch
    cw = max(1, int(content.width * scale))
    content = content.resize((cw, 440), Image.LANCZOS)
    canvas = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    canvas.alpha_composite(content, ((512 - cw) // 2, 512 - 31 - 440))
    return canvas


def main():
    os.makedirs(RAW_DIR, exist_ok=True)
    keys = load_keys()
    got = None
    for attempt in range(2):
        size = '1024x1024' if attempt == 0 else '1152x768'
        out = os.path.join(RAW_DIR, f'lance_raw_{attempt}.png')
        key = keys[attempt % len(keys)]
        print(f'attempt {attempt} size={size} ...')
        if not call_api(PROMPT, key, out, size):
            continue
        im = Image.open(out).convert('RGBA')
        im, cleared = flood_white_to_alpha(im)
        bbox = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
        if not bbox or cleared < 5000:
            print(f'  候选 {attempt} 泛洪失败 cleared={cleared} bbox={bbox}')
            continue
        canvas = fit_512(im)
        if canvas is None:
            continue
        got = canvas
        break
    if got is None:
        print('REGEN_FAIL：两投皆未过审，人工看 raw 候选')
        return
    # 备份原图（player + enemy）
    for camp in ('player', 'enemy'):
        src = os.path.join(ROOT, 'assets', 'card_icons', camp, 'drop_phase_lance.png')
        dst = os.path.join(BACKUP, camp, 'drop_phase_lance.png')
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            import shutil
            shutil.copy2(src, dst)
    got.save(os.path.join(ROOT, 'assets', 'card_icons', 'player', 'drop_phase_lance.png'))
    got.transpose(Image.FLIP_LEFT_RIGHT).save(
        os.path.join(ROOT, 'assets', 'card_icons', 'enemy', 'drop_phase_lance.png'))
    print('REGEN_OK：player 朝右 / enemy 镜像，已落盘（缩略图请跑刷新脚本）')


if __name__ == '__main__':
    main()
