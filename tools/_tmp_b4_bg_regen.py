#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④ 批 1 子批 B：10 张战场背景重生成（2026-09-09）。

清单/配装依据 docs/统一化/plans/2026-09-09-批次4-资产重生成计划.md §1；
prompt 逐字取自 STYLE_BIBLE §6.2（时代基础段+环境修饰词表+场景域固定段），
负面栏〔场景〕只 text, frame。生成 1152×768 → 程序化质检（尺寸+暖区占比）→
aspect-fill 裁 1280×720 → 备份原图后部署 assets/backgrounds/。
调用 agnes-image-2.0-flash（模式先例 tools/gen_missing_instruments_32.py）。
"""
import json
import os
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "docs", "待生成背景_批1子批B")
ASSETS = os.path.join(ROOT, "assets", "backgrounds")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"

# ── STYLE_BIBLE §6.2 固定片段（逐字，不发明） ──
ERA_BASE = {
    "WW1": "great war era landscape, long trench lines and timber revetments, early steel gantries, distant biplane silhouette",
    "WW2": "WWII era landscape, fortified blockhouse silhouettes, steel truss bridge, an armored column on a raised road",
    "COLD": "cold war era landscape, brutalist concrete structures, radar arrays on the horizon, wide frozen plain",
    "MODERN": "modern era landscape, container yards and highway viaducts, distant glass-and-steel towers",
    "FUTURE": "near-future landscape, sleek monolithic towers, elevated transit lines, one colossal dark monolith on the horizon",
}
WEATHER = {
    "rain": "fine rain across the whole scene",
    "storm": "heavy storm with driving rain, sky one low unbroken grey",
    "snow": "wind-carved snow fields, flat overcast sky, distant colossal black monolith with faint violet halo",
    "sandstorm": "dense pale sand haze swallowing the midground",
    "clear": "flat pale overcast sky, diffuse daylight",
}
TERRAIN = {
    "city": "low dense skyline of cold grey buildings on the horizon",
    "plain": "wide open flatland stretching to the horizon",
}
FIELD = {
    "low_field": "faint violet shimmer in the air",
    "high_field": "violet aurora bands rippling high over the horizon",
    "nano_fog": "low-lying luminous blue-grey nano fog drifting through the midground",
}
TIME = {
    "day": "diffuse daylight",
    "dusk": "dim grey-blue dusk",
    "night": "deep blue-grey night",
}
CITY_NIGHT_LOCK = "the skyline stays fully dark, unlit building silhouettes"
COMPOSITION = ("vast empty composition, low horizon, flat overcast sky, monumental lone "
               "industrial structure, one tiny human silhouette against huge machinery")
PALETTE = "muted cold palette of deep blue-grey steel and cold grey, one small warm ember-orange accent, flat overcast sky"
LIGHT = ("single warm ember light source in a cold blue-grey world, volumetric glow "
         "around the light source, aerial perspective, distant objects fade into "
         "blue-grey haze")
BRUSH = "thick painterly illustration, film grain texture, soft airbrush smoke against hard-edge scuffed steel"
NEGATIVE = "text, frame"


def build_prompt(era, weather, terrain, field, tod, city_night_lock=False):
    parts = [ERA_BASE[era]]
    parts.append(WEATHER[weather])
    parts.append(TERRAIN[terrain])
    if field in FIELD:
        parts.append(FIELD[field])
    parts.append(TIME[tod])
    if terrain == "city" and tod == "night":
        parts.append(CITY_NIGHT_LOCK)
    parts.append(COMPOSITION)
    parts.append(PALETTE)
    parts.append(LIGHT)
    parts.append(BRUSH)
    return ", ".join(parts) + ". " + NEGATIVE


GATE_LIGHT = ("a single faint violet halo around the distant monolith gate, volumetric glow "
              "around the light source, aerial perspective, distant objects fade into "
              "blue-grey haze")

JOBS = [
    ("bg_level_12", build_prompt("WW1", "clear", "plain", "normal", "day")),
    ("bg_level_22", build_prompt("WW2", "rain", "plain", "normal", "dusk")),
    ("bg_level_38", build_prompt("WW2", "rain", "plain", "normal", "dusk")),
    ("bg_level_42", build_prompt("COLD", "snow", "city", "normal", "day")),
    ("bg_level_55", build_prompt("COLD", "snow", "city", "normal", "day")),
    ("bg_level_58", build_prompt("COLD", "snow", "city", "normal", "day")),
    ("bg_level_68", build_prompt("MODERN", "storm", "city", "high_field", "night", True)),
    ("bg_level_92", build_prompt("FUTURE", "sandstorm", "plain", "nano_fog", "dusk")),
    # 黑门无限模式门图：无时代段；雪原锁意象串的 monolith 为门本体；唯一叙事光源=violet halo
    ("bg_endless_gate_t0",
     "distant colossal black monolith gate with faint violet halo, wind-carved snow fields, "
     + COMPOSITION + ", " + PALETTE + ", " + GATE_LIGHT + ", " + BRUSH + ". " + NEGATIVE),
    ("bg_endless_gate_t1",
     "a colossal black monolith gate looming closer in the midground with faint violet halo, "
     "wind-carved snow fields, heavier blue-grey haze swallowing the horizon, "
     + COMPOSITION + ", " + PALETTE + ", " + GATE_LIGHT + ", " + BRUSH + ". " + NEGATIVE),
]


def generate_image(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1152x768", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY,
           "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200, encoding="utf-8")
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if r.returncode != 0 or not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "curl/response failed"
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "not JSON: " + content[:120]
    url = None
    if isinstance(data.get("data"), list) and data["data"]:
        url = data["data"][0].get("url")
    if not url:
        return False, "no url: " + content[:120]
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"]
    d = subprocess.run(dl, capture_output=True, timeout=200)
    if d.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) < 50000:
        return False, "download failed"
    return True, "ok"


def warm_ratio(path):
    """暖区粗检：R 明显高于 B 的像素占比（审计口径的简化版，防暖黄复发）。"""
    im = Image.open(path).convert("RGB").resize((192, 128))
    px = im.load()
    warm = 0
    total = 192 * 128
    for y in range(128):
        for x in range(192):
            r, g, b = px[x, y]
            if r > b + 30 and r > 90:
                warm += 1
    return warm / total


def aspect_fill_16x9(src, dst, w=1280, h=720):
    im = Image.open(src).convert("RGB")
    sw, sh = im.size
    scale = max(w / sw, h / sh)
    nw, nh = int(sw * scale + 0.5), int(sh * scale + 0.5)
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - w) // 2, (nh - h) // 2
    im.crop((left, top, left + w, top + h)).save(dst, "PNG")


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    deploy, review, failed = [], [], []
    for fname, prompt in JOBS:
        out = os.path.join(OUT_DIR, fname + ".png")
        if not (os.path.exists(out) and os.path.getsize(out) > 50000):
            print("-- generate", fname, flush=True)
            ok, msg = generate_image(prompt, out)
            if not ok:
                print("   FAIL:", msg, flush=True)
                failed.append(fname)
                continue
            time.sleep(2)
        im = Image.open(out)
        wr = warm_ratio(out)
        status = []
        if abs(im.size[0] / im.size[1] - 1.5) > 0.01:
            status.append("ratio=%s" % (im.size,))   # 3:2 源图均可（1248x832 实测），非 3:2 才拦
        if wr >= 0.12:
            status.append("warm=%.0f%%" % (wr * 100))
        if status:
            print("   REVIEW:", fname, ",".join(status), "(暖区 %.1f%%)" % (wr * 100), flush=True)
            review.append(fname)
            continue
        print("   OK: %s 暖区 %.1f%%" % (fname, wr * 100), flush=True)
        deploy.append(fname)

    if deploy:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        for fname in deploy:
            src = os.path.join(ASSETS, fname + ".png")
            if os.path.exists(src):
                dst = os.path.join(BACKUP_DIR, fname + "-preB-2026-09-09.png")
                if not os.path.exists(dst):
                    with open(src, "rb") as fi, open(dst, "wb") as fo:
                        fo.write(fi.read())
            aspect_fill_16x9(os.path.join(OUT_DIR, fname + ".png"), src)
            print("   deployed:", fname, flush=True)

    print("[SUMMARY] deploy=%d review=%d failed=%d" % (len(deploy), len(review), len(failed)))
    if review:
        print("  review:", ", ".join(review))
    if failed:
        print("  failed:", ", ".join(failed))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
