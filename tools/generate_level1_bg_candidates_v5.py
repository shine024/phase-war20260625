#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v5。

用户反馈（v4 后）：
1. 车道还是不够宽 → 要求"占画面从上到下一半宽" = 车道占画面高度 50%，即整个下半部分。
2. 车道上障碍太多 → 要求车道是干净战斗地面，零障碍。

v5 策略：
- 所有 5 张：车道强制占整个下半画面（horizon 在垂直中线，下半全是可战斗地面）。
- 用直白几何描述（lower half / vertical center / fills entirely）代替易被忽略的形容词。
- 车道内零障碍：删除原 prompt 里 "Props allowed on lane edges"，改为强约束 "completely empty lane interior, no obstacles, no objects, no props, no barricades inside the lane".
- 障碍物(木桩/沙袋/铁丝网)移到中景过渡带，不污染车道。
- 5 张差异放在「车道质感 + 天空压缩程度」让用户挑，而非宽度（宽度已锁定50%）。
端点：apihub.agnes-ai.cn / agnes-image-2.0-flash / 1792x1024
输出：docs/第一关战场候选_5张_v5/
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v5")
SIZE = "1792x1024"

NEGATIVE = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, "
    "letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, "
    "obstacles inside the lane, barricades on the lane, barbed wire on the lane, rocks on the lane, "
    "crates on the lane, stumps on the lane, debris on the lane, pits on the lane, "
    "top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, "
    "unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes"
)

# 固定不变的几何约束（直白，易执行）
GEOMETRY = (
    "Strict geometric composition: the HORIZON line is exactly at the VERTICAL CENTER of the frame. "
    "The ENTIRE UPPER HALF of the image is sky and distant mountains. "
    "The ENTIRE LOWER HALF of the image is the open battle ground / combat lane — the ground fills the whole lower half from left edge to right edge. "
    "The combat lane is a single continuous flat ground band running straight left-to-right across the full frame width, near side-view, sharp edges, unbroken, not curved. "
    "Exactly ONE lane only, no secondary paths, no forks, no diagonal roads. "
    "HARD CONSTRAINT: the lane interior is COMPLETELY EMPTY and FLAT — no obstacles, no props, no barricades, no sandbags, no barbed wire, no crates, no rocks, no stumps, no pits, no debris, NOTHING inside the lane area. "
    "Only a smooth, clear, muddy worn ground surface. "
    "Any battlefield props (wooden stakes, sandbag berms, barbed wire lines, barricades, ammo crates, trench traces) must appear ONLY in the thin transition zone near the horizon line, NEVER down in the lower-half lane."
)


def build_prompt(sky_desc, ground_desc):
    return (
        "16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.\n"
        "UPPER HALF (sky and distance): " + sky_desc + " "
        "dawn sky with layered blue-cyan distant mountains, soft clouds, morning light, "
        "light post-rain cool gray-blue haze and wet atmosphere, mountains fading into atmospheric perspective, "
        "faint cyan electric haze along the horizon, subtle sci-fi undertone.\n"
        + GEOMETRY + "\n"
        "LOWER HALF (battle ground texture): " + ground_desc + "\n"
        "Near the horizon transition zone: WW1 Somme morning shattered woods, river mist, distant craters, "
        "ruined farmhouse silhouettes, barbed wire lines, sandbag berms, low bunkers, trench traces "
        "(all kept UP near horizon, none down in the lane). "
        "Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.\n"
        'Narrative: Phase War Stage 1 "晨曦中的索姆河，第一阶段突破作战" (no text). '
        'Roster "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons).\n'
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable, "
        "no characters, no combat VFX, no text, 16:9 horizontal."
    )


# 5 张：宽度全锁定 50%（下半画面），差异在车道质感 + 天空压缩（仍保持下半是地面）
CANDIDATES = [
    {"idx": 1, "label": "干泥土车道",
     "sky_desc": "Open",
     "ground_desc": "dry packed dirt ground, flat and clear, with subtle worn vehicle ruts and footprints texture."},
    {"idx": 2, "label": "湿泥反光车道",
     "sky_desc": "Slightly compressed",
     "ground_desc": "wet muddy ground, flat and clear, with glossy rainwater puddles reflecting the sky and soft sheen."},
    {"idx": 3, "label": "草泥混合车道",
     "sky_desc": "Compressed",
     "ground_desc": "mixed grass-and-mud churned ground, flat and clear, trampled WW1 battlefield earth, low patches of trodden grass."},
    {"idx": 4, "label": "沙土干裂车道",
     "sky_desc": "Narrow",
     "ground_desc": "sandy cracked earth ground, flat and clear, parched with faint dried-mud crack patterns across the surface."},
    {"idx": 5, "label": "整洁夯土车道",
     "sky_desc": "Very narrow",
     "ground_desc": "smooth compacted earth ground, flat and clear, clean and well-trodden, minimal texture, almost like a prepared battle platform."},
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
    print("v5 策略：车道锁定占下半画面(50%) + 车道内零障碍\n")

    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = build_prompt(c["sky_desc"], c["ground_desc"])
        fname = "level1_v5_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] %s -> %s" % (idx, c["label"], fname))
        ok = False
        msg = ""
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            ok, msg = call_api(prompt, NEGATIVE, key, "v5_%d k%d" % (idx, ki), fpath)
            if ok:
                print("  OK: " + msg)
                break
            print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["label"], fname, ok))
        time.sleep(1)

    print("\n" + "=" * 50 + "\n汇总")
    for r in results:
        print("  v5_%d [%s] %s : %s" % (r[0], r[1], r[2], "OK" if r[3] else "FAIL"))
    print("-> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
