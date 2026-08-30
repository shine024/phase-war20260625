#!/usr/bin/env python3
"""地图材质贴图生成（配合 compose_greenland_map.py 质感升级轮）。
AI 没有图生图 → 走游戏业标准流程：AI 画"无缝材质贴图"（纯材质、无轮廓先验问题），
程序把纹理铺进精确格陵兰轮廓。5 张 1024²：苔原草/雪原/山岩/海面/松林。
采样时用镜像三角波坐标，天然无缝（AI tile 接缝不可见）。
"""
import json
import os
import subprocess
import sys
import time

from PIL import Image

# Windows GBK 控制台下 ✓/✗ 等 Unicode 符号会让 print 直接崩溃，强制 UTF-8 输出
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
DEFAULT_OUT_DIR = os.path.join(ROOT, "docs", "地图重设计", "generated", "greenland", "textures")
# 可选命令行参数：输出目录（不传 = 原定稿轮目录，文档 §1 命令行为不变）
OUT_DIR = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT_DIR

HEAD = "seamless tileable texture, hand-painted watercolor game asset, top-down flat view, " \
       "even soft lighting, uniform repeating pattern filling the whole square, " \
       "no objects, no border, no vignette, no text, no watermark"

TILES = [
    ("tex_grass", "arctic tundra grassland and moss, muted sage green with dry grass "
     "brush strokes and small patches of bare earth"),
    ("tex_snow", "fresh snow field, pale blue-white, faint wind ripples, sparse ice "
     "crystal sparkle, soft drifts"),
    ("tex_rock", "rugged grey-brown mountain rock and scree slope, painterly cracks, "
     "gravel and lichen speckles"),
    ("tex_sea", "calm deep ocean water seen from directly above, dark blue, subtle "
     "current brush strokes and faint wave shimmer"),
    ("tex_forest", "dense dark pine forest canopy seen from high above, muted blue-green, "
     "painterly clumping tree crowns with tiny snow gaps"),
]


def generate(prompt: str, output_path: str) -> bool:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = output_path + ".p.json"
    open(tmp, "w").write(payload)
    resp = output_path + ".r.json"
    r = subprocess.run([
        "curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
        "-H", "Authorization: Bearer " + API_KEY,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmp, "-o", resp, "--max-time", "180",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=200)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    if r.returncode != 0 or not os.path.exists(resp):
        return False
    data = json.loads(open(resp).read())
    try:
        os.unlink(resp)
    except OSError:
        pass
    url = (data.get("data") or [{}])[0].get("url")
    if not url:
        return False
    d = subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url,
                        "--max-time", "180"], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=200)
    return d.returncode == 0 and os.path.getsize(output_path) > 30000


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    ok = 0
    for name, desc in TILES:
        out = os.path.join(OUT_DIR, name + ".png")
        print(f"── {name} ...", flush=True)
        if generate(HEAD + " ; " + desc, out):
            print(f"   ✓ {out} ({os.path.getsize(out)} bytes)", flush=True)
            ok += 1
        else:
            print("   ✗ 失败", flush=True)
        time.sleep(2)
    print(f"完成 {ok}/5 → {OUT_DIR}")


if __name__ == "__main__":
    main()
