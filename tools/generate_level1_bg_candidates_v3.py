#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v3（文件原版 prompt + 独立 negative_prompt 字段 + 车道更宽）。

修正点（相对 v2）：
1. 负面词：完整使用文件第1关原版负面词，并作为 API 独立 negative_prompt 字段传（文本里也保留，双保险）。
2. 车道更宽：起点 30%（v2 是 22%），每张 +5% 到 50%；天空从 65% 压到 35%（真正变窄）。
3. lane width 倍数逐张加大（2.0x→4.0x），让车道条更粗。
prompt 主体（天空/中景/配色/叙事）= 文件第1关原版，仅替换 {top}/{mid}/{bot}/{lane}/{w} 数字。
端点：https://apihub.agnes-ai.cn/v1 / agnes-image-2.0-flash（1792x1024 真16:9）。
输出：docs/第一关战场候选_5张_v3/level1_v3_01.png ~ _05.png
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v3")
SIZE = "1792x1024"

# 文件第1关原版完整负面词（一字不改）
NEGATIVE = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, "
    "letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, "
    "top-down view, isometric, strong perspective distortion, fisheye, photorealistic 3D render, "
    "unreal engine screenshot, dark horror, gore, blur, low resolution, messy composition, duplicate lanes"
)

# 文件第1关原版 prompt 模板，仅替换数字 {top}/{mid}/{bot}/{lane}/{w}
PROMPT_TEMPLATE = (
    "16:9 horizontal 2D mobile game scene with fixed 3-layer composition "
    "(top {top}% sky / middle {mid}% midground transition / bottom {bot}% single battle lane).\n"
    "Top {top}%: dawn sky with layered blue-cyan distant mountains, soft clouds, morning light; "
    "light post-rain cool gray-blue haze and wet atmosphere; layered mountain ranges fading into "
    "atmospheric perspective; faint cyan electric haze along horizon, tasteful sci-fi undertone "
    "integrated subtly into sky and horizon readability.\n"
    "Middle {mid}%: transition zone — WW1 Somme morning: shattered woods, river mist, distant craters, "
    "ruined farmhouse silhouettes, barbed wire lines, sandbag berms, low bunkers, trench traces. "
    "Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy.\n"
    "Bottom {bot}%: one single main battle lane running straight from left to right across the entire frame; "
    "lane baseline is positioned slightly higher than the absolute bottom edge (leave a small ground margin below). "
    "Lane width is {w}x wider than the default narrow lane while remaining uniform across the full frame; "
    "lane occupies about {lane}% of total frame height (visibly broader than a thin strip), centered in the lower area. "
    "near side-view perspective, sharp edges, unbroken, not curved, not occluded. "
    "Hard constraint: exactly one lane only, no secondary paths, no forks, no diagonal roads. "
    "Muddy or era-appropriate ground surface with slightly wet / worn texture where fitting. "
    "Props allowed ONLY on lane edges: wooden stakes, barricades, ammo crates, barbed wire posts, "
    "short communication trench openings — must NOT intrude into the lane silhouette.\n"
    'Theme must match Phase War Stage 1 background — narrative cue: "晨曦中的索姆河，第一阶段突破作战" '
    '(no text in image). Thematically aligned with roster theme "Stage 1 — Infantry Squad · MP18" '
    "(no soldiers, no weapons depicted).\n"
    "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, "
    "readable composition, no characters, no combat VFX, no text, 16:9 horizontal.\n"
    "Negative prompt: " + NEGATIVE
)

# 5 张：车道 30%→50%（每张+5%），天空 55%→35%（真正变窄），车道倍数 2.0x→4.0x（更宽）
CANDIDATES = [
    {"idx": 1, "lane": 30, "w": 2.0, "top": 55, "mid": 18, "bot": 27, "note": "车道30% / 天空55%"},
    {"idx": 2, "lane": 35, "w": 2.5, "top": 50, "mid": 17, "bot": 33, "note": "车道35% / 天空50%"},
    {"idx": 3, "lane": 40, "w": 3.0, "top": 45, "mid": 16, "bot": 39, "note": "车道40% / 天空45%"},
    {"idx": 4, "lane": 45, "w": 3.5, "top": 40, "mid": 16, "bot": 44, "note": "车道45% / 天空40%"},
    {"idx": 5, "lane": 50, "w": 4.0, "top": 35, "mid": 15, "bot": 50, "note": "车道50% / 天空35%"},
]


def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        print("ERROR: 无可用 key")
        sys.exit(1)
    return keys


def mask(k):
    return (k[:6] + "..." + k[-4:]) if len(k) > 12 else (k[:3] + "..." + k[-3:])


def call_api(prompt, negative, key, tag, output_path):
    """关键：negative_prompt 作为独立字段传（双保险，文本里也保留）。"""
    payload_obj = {"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1, "negative_prompt": negative}
    payload = json.dumps(payload_obj)
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", BASE_URL + "/images/generations",
        "-H", "Authorization: Bearer " + key,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file,
        "--max-time", "120",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    finally:
        try:
            os.unlink(tmpfile)
        except OSError:
            pass
    if result.returncode != 0:
        return False, "[" + tag + "] curl exit " + str(result.returncode) + ": " + (result.stderr or "")[:160]
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
        return False, "[" + tag + "] 响应非 JSON: " + content[:200]
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(data)[:200]
        return False, "[" + tag + "] 无 data: " + msg
    url = data["data"][0].get("url", "")
    if not url:
        b64 = data["data"][0].get("b64_json", "")
        if b64:
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(b64))
            if os.path.getsize(output_path) > 1000:
                return True, "[" + tag + "] OK(b64)"
        return False, "[" + tag + "] 响应无 URL"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "[" + tag + "] OK(url, " + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 下载失败/过小"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("载入 " + str(len(keys)) + " 个 key: " + ", ".join(mask(k) for k in keys))
    print("输出目录: " + OUTPUT_DIR)
    print("尺寸 " + SIZE + " / 负面词走独立 negative_prompt 字段\n")

    print("=== 自检：API 是否接受 negative_prompt 字段 ===")
    probe_path = os.path.join(OUTPUT_DIR, "_probe.png")
    test_prompt = "a red square on white background"
    ok_probe = False
    for ki, key in enumerate(keys):
        tag = "probe k" + str(ki)
        ok, msg = call_api(test_prompt, NEGATIVE, key, tag, probe_path)
        print("  " + mask(key) + ": " + msg)
        if ok:
            ok_probe = True
            try:
                os.unlink(probe_path)
            except OSError:
                pass
            break
        time.sleep(2)
    if not ok_probe:
        print("\n[FATAL] 自检失败，终止。")
        sys.exit(2)
    print(">>> negative_prompt 字段被 API 接受，继续\n")

    print("开始生成 5 张 v3（车道 30%→50%，天空 55%→35%）...\n")
    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = PROMPT_TEMPLATE.format(top=c["top"], mid=c["mid"], bot=c["bot"], lane=c["lane"], w=c["w"])
        fname = "level1_v3_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] %s -> %s" % (idx, c["note"], fname))
        ok = False
        msg = ""
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            tag = "v3_%d k%d" % (idx, ki)
            ok, msg = call_api(prompt, NEGATIVE, key, tag, fpath)
            if ok:
                print("  OK: " + msg)
                break
            else:
                print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["lane"], c["top"], fname, ok, msg))
        time.sleep(1)

    print("\n" + "=" * 60)
    print("汇总")
    print("=" * 60)
    for r in results:
        status = "OK  " if r[4] else "FAIL"
        print("  v3_%d [车道%d%% / 天空%d%%] %s : %s" % (r[0], r[1], r[2], r[3], status))
    ok_n = sum(1 for r in results if r[4])
    print("\n共 " + str(ok_n) + "/" + str(len(results)) + " 张成功 -> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
