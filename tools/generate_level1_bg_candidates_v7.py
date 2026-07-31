#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v7。

用户反馈（v6 后，共5点）：
1. 车道够宽了 → 锁定 v6 的地面主导比例（占下3/4~4/5）。
2. 天空部分还是太宽 → 天空进一步压缩（仅顶部窄带）。
3. 中景要宽一点 → 过渡带(树林/废墟/战壕痕迹)加厚。
4. 左右车道入口不要有障碍 → 画面左右两端(单位进出入口)清空，障碍只放中间区域或地平线。
5. 下边的修饰也太宽了 → 底缘装饰带(弹坑/碎石)收窄，只在最底缘薄薄一层。

v7 策略：重新分配比例 — 天空压缩 + 中景加厚 + 地面宽度不变 + 左右入口清空 + 底缘收窄。
端点：apihub.agnes-ai.cn / agnes-image-2.0-flash / 1792x1024
输出：docs/第一关战场候选_5张_v7/
"""
import base64
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_keys_level1.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v7")
SIZE = "1792x1024"

NEGATIVE = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, "
    "letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, "
    "obstacles at the lane entries, barricades at the left edge, barricades at the right edge, "
    "barbed wire blocking entry, rocks blocking entry, objects at the left side, objects at the right side, "
    "thick debris band at the bottom, wide crater strip, large rubble pile at the bottom, "
    "huge sky, dominant sky, mostly sky, top-down view, isometric, strong perspective distortion, "
    "fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, "
    "low resolution, messy composition, duplicate lanes"
)


def build_prompt(sky_desc, mid_desc, entry_desc):
    return (
        "16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.\n"
        "LAYOUT (strict): the GROUND / combat lane is the dominant element and takes the lower three-quarters of the image. "
        "The sky is COMPRESSED to a thin band at the top. The midground transition zone is deliberately THICKENED.\n"
        "SKY (thin, compressed): " + sky_desc + " — only a narrow strip of sky along the very top of the frame.\n"
        "MIDGROUND TRANSITION (thickened, this is important): " + mid_desc + "\n"
        "COMBAT LANE (bottom three-quarters, the dominant element): a single continuous flat ground band running straight "
        "left-to-right across the full frame width, near side-view, sharp edges, unbroken, not curved. Exactly ONE lane only, "
        "no secondary paths, no forks, no diagonal roads. The lane interior is OPEN and flat so units can deploy freely.\n"
        "ENTRY ZONES (critical): " + entry_desc + "\n"
        "BOTTOM EDGE: only a VERY THIN scattering of small details right along the bottommost edge — a thin line of faint "
        "muddy ruts, sparse tiny grass tufts, a couple of small shallow puddles. Keep this bottom decoration band NARROW "
        "and minimal — do NOT make a wide cluttered debris field. Most of the lower area must stay open clear ground.\n"
        "Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy. Dawn light, "
        "morning glow, faint cyan electric haze along the horizon, subtle sci-fi undertone. Near horizon: WW1 Somme morning, "
        "river mist, distant craters.\n"
        'Narrative: Phase War Stage 1 "晨曦中的索姆河，第一阶段突破作战" (no text). '
        'Roster "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons).\n'
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable, "
        "no characters, no combat VFX, no text, 16:9 horizontal."
    )


# 5 档：地面宽度统一锁定（下3/4），差异在中景厚度 + 天空压缩 + 入口清空程度
CANDIDATES = [
    {"idx": 1, "label": "中景适中/天空窄",
     "sky_desc": "a compressed thin strip of dawn sky with layered blue-cyan distant mountains, morning light, post-rain cool gray-blue haze",
     "mid_desc": "a moderately thick band of WW1 Somme terrain: shattered woods, ruined farmhouse silhouettes, sandbag berms, barbed wire lines, low bunkers, trench traces, river mist",
     "entry_desc": "Both the LEFT edge and RIGHT edge of the lane are completely CLEAR and open — nothing blocks where units enter from the sides. Keep the entry zones empty."},
    {"idx": 2, "label": "中景较厚/天空更窄",
     "sky_desc": "a very thin compressed strip of dawn sky with faint distant mountains, minimal sky",
     "mid_desc": "a THICK band of WW1 Somme terrain: dense shattered woods, multiple ruined farmhouses, extensive sandbag berms, barbed wire lines, low bunkers, zigzag trench traces, river mist — a rich layered transition",
     "entry_desc": "Both the LEFT edge and RIGHT edge of the lane must be COMPLETELY CLEAR and open for unit entry — no objects, no props, no barricades at the side entrances."},
    {"idx": 3, "label": "中景厚/天空极窄",
     "sky_desc": "a minimal sliver of dawn sky, barely a thin line, distant mountains barely peeking",
     "mid_desc": "a wide rich midground band with layered WW1 Somme elements: shattered woods, ruined buildings, sandbag walls, barbed wire, bunkers, trench networks, mist — thickly detailed transition",
     "entry_desc": "Both the LEFT edge and RIGHT edge of the lane are CLEAR and open — the left 10% and right 10% of the lane must have zero obstacles."},
    {"idx": 4, "label": "中景很厚/天空一线",
     "sky_desc": "almost no sky, just a thin line of dawn light at the very top",
     "mid_desc": "a VERY THICK, richly detailed midground band: dense shattered woods, multiple ruined farmhouses, sandbag fortifications, barbed wire, bunkers, deep trench traces, river mist — a deep layered transition zone",
     "entry_desc": "Both side entry zones (left edge and right edge of the lane) are COMPLETELY CLEAR — no objects blocking where units come in from the sides."},
    {"idx": 5, "label": "中景最厚/装饰最少",
     "sky_desc": "minimal sky, a thin band of dawn light and faint mountains at the top",
     "mid_desc": "the thickest, richest midground transition: extensive shattered woods, ruined farmhouses, sandbag berms, barbed wire lines, bunkers, trench networks, mist — a deep detailed layered zone",
     "entry_desc": "Both side entries are CLEAR. Bottom decoration is the absolute minimum — just a thin faint ground texture line, no clutter."},
]


def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()] or (print("无 key"), sys.exit(1))


def mask(k):
    return (k[:6] + "..." + k[-4:]) if len(k) > 12 else (k[:3] + "..." + k[-3:])


def call_api(prompt, negative, key, tag, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1, "negative_prompt": negative})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "120"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    finally:
        try:
            os.unlink(tmpfile)
        except OSError:
            pass
    if r.returncode != 0:
        return False, "[" + tag + "] curl exit " + str(r.returncode)
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "[" + tag + "] 无响应"
    content = open(resp_file, "r", encoding="utf-8", errors="replace").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "[" + tag + "] 非JSON: " + content[:160]
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:160]) if isinstance(err, dict) else str(data)[:160]
        return False, "[" + tag + "] 无data: " + msg
    url = data["data"][0].get("url", "")
    if not url:
        b64 = data["data"][0].get("b64_json", "")
        if b64:
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(b64))
            if os.path.getsize(output_path) > 1000:
                return True, "[" + tag + "] OK(b64)"
        return False, "[" + tag + "] 无URL"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "[" + tag + "] OK(" + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 下载失败"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("载入 " + str(len(keys)) + " 个 key / 输出: " + OUTPUT_DIR)
    print("v7 策略：天空压缩 + 中景加厚 + 地面锁宽(下3/4) + 左右入口清空 + 底缘装饰收窄\n")

    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = build_prompt(c["sky_desc"], c["mid_desc"], c["entry_desc"])
        fname = "level1_v7_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] %s -> %s" % (idx, c["label"], fname))
        ok = False
        msg = ""
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            ok, msg = call_api(prompt, NEGATIVE, key, "v7_%d k%d" % (idx, ki), fpath)
            if ok:
                print("  OK: " + msg)
                break
            print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["label"], fname, ok))
        time.sleep(1)

    print("\n" + "=" * 50 + "\n汇总")
    for r in results:
        print("  v7_%d [%s] %s : %s" % (r[0], r[1], r[2], "OK" if r[3] else "FAIL"))
    print("-> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
