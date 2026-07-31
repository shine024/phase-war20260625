#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""关卡战场背景图生成工作流（可复用，带回家直接跑）。

来源：phase-war 项目第1关背景 v1-v5 迭代收敛版（v6）。
端点：https://apihub.agnes-ai.cn/v1 / 模型 agnes-image-2.0-flash / 尺寸 1792x1024(≈16:9)
Key：同级目录 api_keys.txt（3 个 key 轮换，失败自动切下一个 + 间隔重试，规避 520/审核临时故障）

【v6 几何（按用户反馈调对）】
  地平线压到画面顶部约 1/3 处 →
    天空+远景  ~33%（从 50% 压下来）
    中景过渡  ~10%
    战斗车道  ~55%（从 40% 扩上去，车道占下半画面主导）
  车道主体开阔平坦，但【最底部边缘允许稀疏小元素】（枯草/车辙/浅水洼/碎石），
  不堆叠成障碍——满足「最下边可以有一些东西」。

用法：
  python generate_level_bg.py                 # 默认：第1关，4 张车道质感变体
  python generate_level_bg.py --level 1 --variants 4
  python generate_level_bg.py --level 21      # 换关卡（用 LEVEL_THEMES 里的风格）
  python generate_level_bg.py --single        # 只出 1 张（快速试参数）

产出：docs/关卡背景_生成/level<N>_v<序号>.png
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))  # 项目根（phase-war）
KEY_FILE = os.path.join(HERE, "api_keys.txt")
OUTPUT_ROOT = os.path.join(ROOT, "docs", "关卡背景_生成")

BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
SIZE = "1792x1024"

# 负面词（独立 negative_prompt 字段传，模型才真正执行）
NEGATIVE = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, "
    "letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, "
    "large obstacles in the lane, barricades blocking the lane, barbed wire across the lane, "
    "dense debris filling the lane, pits breaking the lane, "
    "top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, "
    "unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes"
)

# v6 几何约束块（直白几何词，模型易执行；车道占下半主导 + 底部允许稀疏小元素）
GEOMETRY = (
    "Strict geometric composition: "
    "the HORIZON line sits at about ONE-THIRD down from the TOP of the frame. "
    "The TOP ONE-THIRD (~33%) of the image is sky and distant mountains / far horizon. "
    "A THIN midground transition strip (~10%) just below the horizon holds distant WW1 battlefield elements. "
    "The BOTTOM ~55% — the LARGEST region — is the wide open battle lane / combat ground, dominating the entire lower part of the image. "
    "The lane is a single continuous flat ground band running straight left-to-right across the FULL frame width, near side-view, sharp edges, unbroken. "
    "Exactly ONE lane only, no secondary paths, no forks, no diagonal roads. "
    "The MAIN lane body stays OPEN and clear, but the VERY BOTTOM EDGE of the lane may contain SPARSE, LOW ground details only "
    "(a few low dried grass tufts, shallow vehicle ruts, scattered small pebbles, faint shallow puddles) — "
    "these must stay sparse, small and flat, NEVER stacking into obstacles, barricades or blockades. "
    "The lane center and upper part remain clear and walkable."
)

# 关卡主题表（扩展：回家后往里加更多关卡即可）
# 每关：era / faction 配色 / 天空叙事 / 中景元素 / 4 种车道质感变体
LEVEL_THEMES = {
    1: {
        "name": "第1关·一战索姆河黎明",
        "era": "World War I",
        "faction_style": "Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy",
        "sky": "dawn sky with layered blue-cyan distant mountains, soft clouds, morning light, light post-rain cool gray-blue haze and wet atmosphere, mountains fading into atmospheric perspective, faint cyan electric haze along the horizon, subtle sci-fi undertone",
        "midground": "WW1 Somme morning: shattered woods, river mist, distant craters, ruined farmhouse silhouettes, barbed wire lines, sandbag berms, low bunkers, trench traces (kept UP near the horizon, none down in the lane)",
        "narrative": 'Phase War Stage 1 "晨曦中的索姆河，第一阶段突破作战" (no text). Roster "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons)',
        "variants": [
            ("dry_dirt", "dry packed dirt, flat and clear, subtle worn vehicle ruts and footprint texture"),
            ("wet_mud", "wet muddy ground, flat and clear, glossy rainwater puddles reflecting sky with soft sheen"),
            ("grass_mud", "mixed grass-and-mud churned ground, flat and clear, low patches of trodden grass"),
            ("smooth_earth", "smooth compacted earth, flat and clear, clean and well-trodden, minimal texture"),
        ],
    },
    # 回家后照此格式添加更多关卡，例如：
    # 21: {"name": "第21关·二战不列颠空战", "era": "World War II", "faction_style": "...", ...},
}


def build_prompt(theme, ground_desc):
    return (
        "16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.\n"
        "UPPER REGION (sky and distance): " + theme["sky"] + ".\n"
        + GEOMETRY + "\n"
        "BATTLE GROUND TEXTURE (lower 55% lane): " + ground_desc + ".\n"
        "Midground transition elements: " + theme["midground"] + ".\n"
        "Era: " + theme["era"] + ". " + theme["faction_style"] + ".\n"
        "Narrative: " + theme["narrative"] + ".\n"
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable, "
        "no characters, no combat VFX, no text, 16:9 horizontal."
    )


def load_keys():
    if not os.path.exists(KEY_FILE):
        print("[FATAL] 找不到 key 文件: " + KEY_FILE)
        sys.exit(1)
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        print("[FATAL] key 文件为空: " + KEY_FILE)
        sys.exit(1)
    return keys


def mask(k):
    return (k[:6] + "..." + k[-4:]) if len(k) > 12 else (k[:3] + "..." + k[-3:])


def call_api(prompt, key, tag, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1, "negative_prompt": NEGATIVE})
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
        return False, "[" + tag + "] curl exit " + str(r.returncode) + (": " + (r.stderr or "")[:120] if r.stderr else "")
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "[" + tag + "] 无响应文件"
    content = open(resp_file, "r", encoding="utf-8", errors="replace").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "[" + tag + "] 响应非JSON: " + content[:160]
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
        return False, "[" + tag + "] 响应无URL"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "[" + tag + "] OK(" + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 下载失败/过小"


def run_one(prompt, keys, tag, fpath):
    """3 个 key 轮换重试，规避 520/审核临时故障。"""
    for ki in range(len(keys)):
        key = keys[ki % len(keys)]
        ok, msg = call_api(prompt, key, tag + "_k%d" % ki, fpath)
        if ok:
            return True, msg
        print("    重试(" + mask(key) + "): " + msg)
        time.sleep(4 + ki * 2)
    return False, "全部 key 失败"


def main():
    ap = argparse.ArgumentParser(description="关卡背景图生成工作流")
    ap.add_argument("--level", type=int, default=1, help="关卡号（需在 LEVEL_THEMES 里定义），默认1")
    ap.add_argument("--variants", type=int, default=0, help="变体数（0=该关全部质感变体），默认0")
    ap.add_argument("--single", action="store_true", help="只出 1 张（快速试参数，等价 --variants 1）")
    args = ap.parse_args()

    if args.level not in LEVEL_THEMES:
        print("[FATAL] 关卡 %d 未在 LEVEL_THEMES 定义，请先在脚本顶部 LEVEL_THEMES 添加。" % args.level)
        sys.exit(2)
    theme = LEVEL_THEMES[args.level]
    variants = theme["variants"]
    if args.single:
        variants = variants[:1]
    elif args.variants > 0:
        variants = variants[:args.variants]

    keys = load_keys()
    out_dir = os.path.join(OUTPUT_ROOT, "level%d" % args.level)
    os.makedirs(out_dir, exist_ok=True)
    print("关卡: " + theme["name"])
    print("key: " + str(len(keys)) + " 个 / 尺寸 " + SIZE + " / 变体 " + str(len(variants)))
    print("输出: " + out_dir + "\n")

    results = []
    for i, (vid, ground_desc) in enumerate(variants):
        prompt = build_prompt(theme, ground_desc)
        fname = "level%d_%s.png" % (args.level, vid)
        fpath = os.path.join(out_dir, fname)
        print("[%d/%d] %s -> %s" % (i + 1, len(variants), vid, fname))
        ok, msg = run_one(prompt, keys, "lv%d_%s" % (args.level, vid), fpath)
        print("  " + ("OK: " + msg if ok else "FAIL: " + msg))
        results.append((vid, fname, ok))
        time.sleep(1)

    print("\n" + "=" * 50 + "\n汇总")
    for r in results:
        print("  %s -> %s : %s" % (r[0], r[1], "OK" if r[2] else "FAIL"))
    ok_n = sum(1 for r in results if r[2])
    print("\n%d/%d 成功 -> %s" % (ok_n, len(results), out_dir))


if __name__ == "__main__":
    main()
