#!/usr/bin/env python3
"""余烬要塞 P4 · 观星台终局背景图生成（v22.3）。

生成 1 张：observatory_sky.png（1280×720 不透明深空背景）
  - 消费方：scenes/bunker/ui/observatory_ending_panel.gd（BG_PATH）
  - 缺图时面板有程序化星空兜底，本图是氛围升级而非硬依赖
  - 风格对齐 bunker v3：This War of Mine 阴郁手绘 + 冷青星光 + 一点暖琥珀

调用 agnes-image-2.0-flash（模板复用 generate_bunker_assets.py）。
用法：python tools/generate_observatory_ending_bg.py [--force]
生成后必须：
  1) godot --headless --import 生成 .import 元数据
  2) 按美术备份铁律打包 assets/bunker/ 到项目外 zip
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
RAW_DIR = os.path.join(ROOT, "assets", "bunker", "_raw")
OUT_PATH = os.path.join(ROOT, "assets", "bunker", "observatory_sky.png")

FORCE = "--force" in sys.argv

PROMPT = (
    "This War of Mine inspired 2D game background, hand-painted gritty somber style, "
    "muted desaturated palette. View from inside a dark concrete observatory dome looking "
    "up through a wide circular aperture at deep space: a vast cold starfield in cyan and "
    "pale blue, faint nebula haze, and a luminous timeline of glowing light threads "
    "sweeping across the sky like a river of stars. The dome rim is dark silhouette with "
    "rough concrete texture, a single small warm amber lamp glow on the rim edge as the "
    "only warm accent. Melancholic, quiet, monumental. Dark overall so UI text on top "
    "stays readable. No text, no watermark, no human figures, no lens flare."
    "。不要：文字、水印、人物、镜头光斑、边框。"
)


def generate_image(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
        "-H", "Authorization: Bearer " + API_KEY,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "120",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if result.returncode != 0:
        return False, "curl exit " + str(result.returncode)
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "No response file"
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Response not JSON: " + content[:200]
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(err)[:200]
        return False, "No data: " + str(msg)
    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL in response"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed/too small"


def post_process(raw_path, out_path):
    """1024² → 中央 16:9 横带 → 1280×720（面版背后是 0.90 暗底，取最空的星域段）。"""
    from PIL import Image
    img = Image.open(raw_path).convert("RGB")
    w, h = img.size
    band_h = int(w * 9 / 16)                       # 576
    top = (h - band_h) // 2
    band = img.crop((0, top, w, top + band_h))
    # 整体再压暗一档（终局演出基调 + 保面板文字可读）
    from PIL import ImageEnhance
    band = ImageEnhance.Brightness(band).enhance(0.82)
    band = band.resize((1280, 720), Image.LANCZOS)
    band.save(out_path)
    return band.size


def main():
    os.makedirs(RAW_DIR, exist_ok=True)
    if os.path.exists(OUT_PATH) and not FORCE:
        print("SKIP (exists): " + OUT_PATH)
        return 0
    raw_path = os.path.join(RAW_DIR, "observatory_sky_raw.png")
    print("generating observatory_sky ...")
    ok, msg = generate_image(PROMPT, raw_path)
    print("  generate: " + msg)
    if not ok:
        return 1
    size = post_process(raw_path, OUT_PATH)
    print("post-processed -> %s %s" % (OUT_PATH, size))
    print("next: godot --headless --import  +  项目外美术备份 zip")
    return 0


if __name__ == "__main__":
    sys.exit(main())
