#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v4。

根因修正：AI 图像模型几乎不执行百分比数字指令，所以 v1-v3 的 5 张图几乎没变化。
本版放弃百分比，改用「强视觉形容词」+「截然不同的构图档次」，强制每张图可见差异化。

策略：
- 从 45% 当量起步（用户要求），5 档逐张更宽更占主导。
- 每档用完全不同的空间描述（broad→massive→huge→enormous→colossal），不是改数字。
- 天空对应从"较窄"到"只剩一线天"。
- 主题/配色/叙事 = 文件第1关原版，负面词走独立 negative_prompt 字段。
端点：https://apihub.agnes-ai.cn/v1 / agnes-image-2.0-flash / 1792x1024
输出：docs/第一关战场候选_5张_v4/level1_v4_01.png ~ _05.png
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v4")
SIZE = "1792x1024"

NEGATIVE = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, "
    "letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, "
    "top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, "
    "unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes"
)


def build_prompt(sky_desc, mid_desc, lane_desc):
    """固定主题/配色/叙事；天空/中景/车道用强视觉语言替换。"""
    return (
        "16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.\n"
        "SKY (top): " + sky_desc + " dawn sky with layered blue-cyan distant mountains, soft clouds, morning light, "
        "light post-rain cool gray-blue haze and wet atmosphere, layered mountain ranges fading into atmospheric perspective, "
        "faint cyan electric haze along horizon, subtle sci-fi undertone.\n"
        "MIDGROUND (transition zone): " + mid_desc + " WW1 Somme morning shattered woods, river mist, distant craters, "
        "ruined farmhouse silhouettes, barbed wire lines, sandbag berms, low bunkers, trench traces. "
        "Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.\n"
        "BATTLE LANE (bottom, the most important — emphasize strongly): " + lane_desc + " "
        "The lane runs straight from left to right across the entire frame, near side-view, sharp edges, "
        "unbroken, not curved, exactly ONE lane only, no secondary paths, no forks, no diagonal roads. "
        "Muddy worn ground surface. Props ONLY on lane edges: wooden stakes, barricades, ammo crates, "
        "barbed wire posts — must NOT intrude into the lane.\n"
        'Narrative: Phase War Stage 1 "晨曦中的索姆河，第一阶段突破作战" (no text). '
        'Roster "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons).\n'
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable, "
        "no characters, no combat VFX, no text, 16:9 horizontal."
    )


# 5 档：从 45% 当量起步，每档用截然不同的强视觉语言（不再用百分比数字）
CANDIDATES = [
    {
        "idx": 1,
        "label": "约45%（宽）",
        "sky_desc": "a relatively narrow band of",
        "mid_desc": "a thin transition strip of",
        "lane_desc": "a BROAD, clearly wide main battle lane occupying nearly the entire lower half of the frame — a thick, prominent ground band noticeably wider than normal, a clearly substantial strip of land.",
    },
    {
        "idx": 2,
        "label": "约50%（很宽）",
        "sky_desc": "a small, compressed portion of",
        "mid_desc": "a minimal sliver of",
        "lane_desc": "a VERY WIDE main battle lane filling the WHOLE lower half of the frame — a massive, broad ground platform that is the dominant feature below the middle line, thick and imposing.",
    },
    {
        "idx": 3,
        "label": "约55%（巨大）",
        "sky_desc": "a thin strip of",
        "mid_desc": "a narrow ribbon of",
        "lane_desc": "an EXTRA-WIDE main battle lane taking up MORE THAN HALF the frame height — a huge, expansive flat ground field that sprawls across the bottom and pushes upward, dwarfing everything else.",
    },
    {
        "idx": 4,
        "label": "约60%（超大）",
        "sky_desc": "a tiny, thin sliver of",
        "mid_desc": "a barely-visible band of",
        "lane_desc": "an ENORMOUS main battle lane covering MOST of the lower two-thirds of the frame — a vast, sprawling ground area that is the main feature, the lane dominates almost everything below a thin sky.",
    },
    {
        "idx": 5,
        "label": "约65%（几乎全屏）",
        "sky_desc": "almost no sky, only a faint thin line of",
        "mid_desc": "essentially absorbed into, just a faint hint of",
        "lane_desc": "a COLOSSAL main battle lane nearly filling the ENTIRE frame except a thin sky sliver at the very top — immense ground taking up almost everything, the lane is overwhelmingly the main subject of the whole image.",
    },
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
    print("v4 策略：放弃百分比，用强视觉形容词强制差异化（45%当量起步）\n")

    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = build_prompt(c["sky_desc"], c["mid_desc"], c["lane_desc"])
        fname = "level1_v4_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] %s -> %s" % (idx, c["label"], fname))
        ok = False
        msg = ""
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            ok, msg = call_api(prompt, NEGATIVE, key, "v4_%d k%d" % (idx, ki), fpath)
            if ok:
                print("  OK: " + msg)
                break
            print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["label"], fname, ok))
        time.sleep(1)

    print("\n" + "=" * 50 + "\n汇总")
    for r in results:
        print("  v4_%d [%s] %s : %s" % (r[0], r[1], r[2], "OK" if r[3] else "FAIL"))
    print("-> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
