#!/usr/bin/env python3
"""v28 T3 战场地面贴片生成：弹坑 / 碎石堆 / 履带印 / 枯草丛（4 张，可重跑）。
agnes-image-2.1-flash 文生图（白底）→ flood_white_to_alpha → autocrop → 归一 512px。
输出 assets/battle/decals/ground_decal_{crater,rubble,tracks,grass}.png
prompt 规则遵循 docs/统一化/STYLE_BIBLE.md（正面意象锁死 / 无负面概念词 / muted palette）。
"""
import json
import os
import subprocess
import time
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "battle", "decals")
os.makedirs(OUT_DIR, exist_ok=True)

KEYS = [
    "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv",
    "sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN",
    "sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K",
]
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"

# 结构性负面（STYLE_BIBLE 铁律 2：只写结构性排除，概念词反激活）
NEGATIVE = "text, watermark, frame, border, perspective view, isometric grid"

STYLE = (
    "stylized painterly hand-painted game texture, muted palette of dark grey-brown "
    "and umber with a hint of olive green, soft overcast lighting, "
    "isolated on a clean pure white background, nothing else in the image, "
    "object fully inside the frame with wide white margins"
)

DECALS = {
    "crater": (
        "a single artillery shell crater seen from directly above, bowl of packed dark "
        "earth with a raised irregular splash rim of lighter soil, a few small pebbles "
        "scattered near the rim, " + STYLE
    ),
    "rubble": (
        "one small compact pile of broken bricks and stone chunks seen from slightly "
        "above, a single low heap about as wide as it is tall, " + STYLE
    ),
    "tracks": (
        "a short band of tank tread track marks pressed into bare earth seen from "
        "directly above, two parallel horizontal lines of repeated tread block patterns "
        "in churned dark soil, the band fills the frame horizontally edge to edge, " + STYLE
    ),
    "grass": (
        "one small tuft of dry yellowed wild grass growing from a patch of bare earth "
        "seen from slightly above, thin dry stalks leaning in the wind, "
        "muted palette of dry straw yellow and olive green, " + STYLE
    ),
}


def generate_image(prompt: str, output_path: str, key_idx: int) -> tuple[bool, str]:
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt + "\n\nNegative prompt (structural only): " + NEGATIVE,
        "size": "1152x768",
    })
    tmpfile = output_path + ".payload.json"
    resp_file = output_path + ".resp.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    cmd = [
        "curl", "--http1.1", "-s",
        "-H", "Authorization: Bearer " + KEYS[key_idx % len(KEYS)],
        "-H", "Content-Type: application/json",
        "-d", "@" + tmpfile,
        BASE_URL + "/images/generations",
        "-o", resp_file, "--max-time", "180",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return False, "curl exit " + str(result.returncode) + ": " + (result.stderr or "")[:200]
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "empty response"
    with open(resp_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    if "data" not in data or not data["data"]:
        return False, "no data: " + json.dumps(data, ensure_ascii=False)[:200]
    url = data["data"][0].get("url", "")
    if not url:
        b64 = data["data"][0].get("b64_json", "")
        if not b64:
            return False, "no url/b64"
        import base64
        with open(output_path, "wb") as f:
            f.write(base64.b64decode(b64))
        return True, "OK b64"
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl, capture_output=True)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "download failed"


def flood_white_to_alpha(im, thresh=238):
    """从四边泛洪：与白色接近的连通区域 → 透明（deploy_bunker_v2.py 同款）。"""
    im = im.convert("RGBA")
    w, h = im.size
    work = im.copy()
    px = work.load()
    def is_white(p):
        return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh
    seen = bytearray(w * h)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(px[x, y]):
                dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(px[x, y]):
                dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        p = px[x, y]
        if not (p[0] >= thresh and p[1] >= thresh and p[2] >= thresh):
            continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        dq.append((x+1, y)); dq.append((x-1, y)); dq.append((x, y+1)); dq.append((x, y-1))
    return work


def autocrop(im, pad=8):
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad); t = max(0, t - pad)
    r = min(im.width, r + pad); b = min(im.height, b + pad)
    return im.crop((l, t, r, b))


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    fail = []
    for i, (name, prompt) in enumerate(DECALS.items()):
        if only and name != only:
            continue
        raw_path = os.path.join(OUT_DIR, "_raw_%s.png" % name)
        out_path = os.path.join(OUT_DIR, "ground_decal_%s.png" % name)
        if os.path.exists(out_path):
            print("[skip] %s 已存在" % name)
            continue
        print("[gen ] %s ..." % name, flush=True)
        ok, msg = generate_image(prompt, raw_path, i)
        if not ok:
            fail.append(name)
            print("  FAIL:", msg)
            continue
        im = Image.open(raw_path)
        im = flood_white_to_alpha(im)
        im = autocrop(im)
        # 归一：长边 512（tracks 保持横向带状）
        w, h = im.size
        scale = 512.0 / max(w, h)
        im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
        im.save(out_path)
        os.remove(raw_path)
        for junk in (raw_path + ".payload.json", raw_path + ".resp.json"):
            if os.path.exists(junk):
                os.remove(junk)
        print("  ->", out_path, im.size)
        time.sleep(2)
    if fail:
        print("FAILED:", fail)
        sys.exit(1)
    print("ALL DONE")


if __name__ == "__main__":
    main()
