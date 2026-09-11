#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批4 配套：从新战斗卡图 img2img 白底化出 ww1_arm_rolls / ww2_fort_flak 的动画参考图。

输入: docs/flow重生成_审查/战斗卡_批4/vis_player_001.png (罗尔斯装甲车)
      docs/flow重生成_审查/战斗卡_批4/vis_player_075.png (88mm防空塔)
输出: 资料/单位分帧动画/_ref/ww1_arm_rolls_white.jpg (512²)
      资料/单位分帧动画/_ref/ww2_fort_flak_white.jpg
通道: agnes-image-2.1-flash /images/generations + extra_body.image (img2img, 同 truck 管线)
"""
import base64
import io
import json
import os
import ssl
import sys
import time

import urllib.request

from PIL import Image

ssl._create_default_https_context = ssl._create_unverified_context
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = r"F:\godot fair duet\create\phase-war"
sys.path.insert(0, os.path.join(ROOT, "tools"))
from generate_truck_sprites import load_keys  # noqa: E402

MODEL = "agnes-image-2.1-flash"
BASE_URLS = ["https://api.agnes-ai.cn/v1", "https://apihub.agnes-ai.com/v1"]
REF_DIR = os.path.join(ROOT, "资料", "单位分帧动画", "_ref")

ANCHOR = ("Extract the main vehicle/weapon unit from this battle-card artwork."
          "Keep its appearance, silhouette, proportions, colors and every detail exactly identical"
          " — do not redesign it. Convert it into a strict 2D game sprite: flat orthographic"
          " perfect side view, the unit facing LEFT, centered, filling most of the frame."
          "Pure white seamless background, no ground, no shadow, no scene, no frame,"
          " no text, no watermark.")

JOBS = [
    ("ww1_arm_rolls", os.path.join(ROOT, "docs", "flow重生成_审查", "战斗卡_批4", "vis_player_001.png")),
    ("ww2_fort_flak", os.path.join(ROOT, "docs", "flow重生成_审查", "战斗卡_批4", "vis_player_075.png")),
]


def data_uri(path, max_w=1408):
    im = Image.open(path).convert("RGB")
    if im.width > max_w:
        im.thumbnail((max_w, max_w))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def call_img2img(prompt, key, out, ref_path):
    payload = json.dumps({
        "model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1,
        "extra_body": {"image": [data_uri(ref_path)], "response_format": "url"},
    }).encode("utf-8")
    for base in BASE_URLS:
        for k in key:
            req = urllib.request.Request(
                base + "/images/generations", data=payload,
                headers={"Authorization": "Bearer " + k, "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=240) as r:
                    data = json.loads(r.read().decode("utf-8", errors="replace"))
            except Exception as e:
                print("  [%s] %s 失败: %s" % (os.path.basename(out), base.split("//")[1][:14], str(e)[:110]), flush=True)
                continue
            url = (data.get("data") or [{}])[0].get("url", "")
            try:
                if url:
                    with urllib.request.urlopen(urllib.request.Request(url), timeout=240) as r, open(out, "wb") as f:
                        f.write(r.read())
                else:
                    b64 = (data.get("data") or [{}])[0].get("b64_json", "")
                    if not b64:
                        continue
                    with open(out, "wb") as f:
                        f.write(base64.b64decode(b64))
            except Exception as e:
                print("  下载失败: %s" % str(e)[:110], flush=True)
                continue
            if os.path.exists(out) and os.path.getsize(out) > 5000:
                return True
    return False


def main():
    keys = load_keys()
    os.makedirs(REF_DIR, exist_ok=True)
    for unit, card in JOBS:
        out = os.path.join(REF_DIR, unit + "_white_raw.png")
        ok = False
        for attempt in range(1, 4):
            print("[%s] img2img 第 %d 次…" % (unit, attempt), flush=True)
            if call_img2img(ANCHOR, keys, out, card):
                ok = True
                break
            time.sleep(8)
        if not ok:
            print("[%s] ❌ 三次失败" % unit, flush=True)
            continue
        im = Image.open(out).convert("RGB")
        if im.width > 512:
            im = im.resize((512, 512), Image.LANCZOS)
        ref = os.path.join(REF_DIR, unit + "_white.jpg")
        im.save(ref, "JPEG", quality=92)
        print("[%s] ✅ %s (%d bytes)" % (unit, ref, os.path.getsize(ref)), flush=True)
    print("[REF COMPLETE]")


if __name__ == "__main__":
    main()
