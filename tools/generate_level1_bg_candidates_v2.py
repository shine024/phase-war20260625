#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v2（基于文档原版英文 prompt，车道高度逐张 +5%）。

来源：docs/level_background_ai_prompts_1-100(生图).md 第 1 关原版 English prompt。
      严格保留天空/中景/配色/负面词（保证与现有 bg_level_01.png 风格一致），
      仅逐张加大「战斗车道占画面高度比例」(22% → 42%，每张 +5%)，
      对应调整三层构图比例（天空压缩、底层加厚），用于对比挑出利用率最好的一张。
端点：https://apihub.agnes-ai.cn/v1 / agnes-image-2.0-flash（16:9 横版优先）
Key：tools/_api_keys_level1.txt，3 个 key 轮换。
输出：docs/第一关战场候选_5张_v2/level1_v2_01.png ~ _05.png
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v2")

# 16:9 优先（贴合原图 1376x768 比例），失败回退
SIZE_CANDIDATES = ["1792x1024", "1536x1024", "1024x1024"]

# 文档第 1 关原版负面词（一字不改，保证与现有图一致）
NEGATIVE = (
    "Negative prompt: characters, people, soldiers, infantry, human silhouettes, "
    "enemies, monsters, weapons held by figures, rifles, pistols, MP18, combat effects, "
    "blood, corpses, aircraft, airplanes, helicopters, drones, tanks, armored vehicles, "
    "warships, missiles, skill VFX, muzzle flashes, explosions with debris bodies, "
    "UI, HUD, buttons, text, letters, numbers, watermark, logo, curved road, "
    "S-shaped path, broken path, blocked lane, top-down view, isometric, "
    "strong perspective distortion, fisheye, photorealistic 3D render, unreal engine screenshot, "
    "dark horror, gore, blur, low resolution, messy composition, duplicate lanes"
)


def build_prompt(lane_pct, top_pct, mid_pct, bot_pct):
    """基于文档第 1 关原版 prompt，仅替换三层比例与车道高度。天空/中景/配色原样保留。"""
    return (
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
        "Lane width is 1.5x wider than the default narrow lane while remaining uniform across the full frame; "
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
        + NEGATIVE
    ).format(top=top_pct, mid=mid_pct, bot=bot_pct, lane=lane_pct)


# 5 张变体：车道高度 22%→42%（每张 +5%），三层比例相应调整，天空逐步压缩
CANDIDATES = [
    {"idx": 1, "lane": 22, "top": 65, "mid": 20, "bot": 15, "note": "原版基准（与现有图同参数）"},
    {"idx": 2, "lane": 27, "top": 60, "mid": 18, "bot": 22, "note": "车道 +5%"},
    {"idx": 3, "lane": 32, "top": 55, "mid": 18, "bot": 27, "note": "车道 +10%"},
    {"idx": 4, "lane": 37, "top": 50, "mid": 18, "bot": 32, "note": "车道 +15%"},
    {"idx": 5, "lane": 42, "top": 45, "mid": 16, "bot": 39, "note": "车道 +20%（最大）"},
]


def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        print("ERROR: 无可用 key（" + KEY_FILE + " 为空）")
        sys.exit(1)
    return keys


def mask(key):
    if len(key) <= 12:
        return key[:3] + "..." + key[-3:]
    return key[:6] + "..." + key[-4:]


def call_api(prompt, key, size, tag, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
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
                return True, "[" + tag + "] OK(b64, " + str(os.path.getsize(output_path)) + "B)"
        return False, "[" + tag + "] 响应无 URL"

    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "[" + tag + "] OK(url, " + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 下载失败/过小"


def probe(keys):
    print("=" * 60)
    print("连通性自检：端点 " + BASE_URL + " / 模型 " + MODEL)
    print("=" * 60)
    test_prompt = "a simple flat grass field, side view, no objects, clean"
    for size in SIZE_CANDIDATES:
        for ki, key in enumerate(keys):
            tag = "probe " + size + " k" + str(ki)
            print("  尝试 " + size + " + key " + mask(key) + " ...", end=" ", flush=True)
            probe_path = os.path.join(OUTPUT_DIR, "_probe.png")
            ok, msg = call_api(test_prompt, key, size, tag, probe_path)
            print("OK" if ok else "FAIL")
            if ok:
                try:
                    os.unlink(probe_path)
                except OSError:
                    pass
                print("  >>> 自检通过，采用尺寸 " + size + "\n")
                return size
            else:
                print("    " + msg)
        print("  --- 尺寸 " + size + " 所有 key 均失败，尝试下一个尺寸 ---")
    return None


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("载入 " + str(len(keys)) + " 个 key: " + ", ".join(mask(k) for k in keys))
    print("输出目录: " + OUTPUT_DIR + "\n")

    size = probe(keys)
    if not size:
        print("\n[FATAL] 所有端点/模型/尺寸组合均不通，终止。")
        sys.exit(2)

    print("开始生成 5 张候选 v2（尺寸 " + size + "，车道高度 22%→42%）...\n")
    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = build_prompt(c["lane"], c["top"], c["mid"], c["bot"])
        fname = "level1_v2_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] 车道 %d%% (%s) -> %s" % (idx, c["lane"], c["note"], fname))

        ok = False
        msg = ""
        # 3 个 key 各试一次，失败间隔递增（520/审核为临时故障）
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            tag = "v2_%d k%d" % (idx, ki)
            ok, msg = call_api(prompt, key, size, tag, fpath)
            if ok:
                print("  OK: " + msg)
                break
            else:
                print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["lane"], fname, ok, msg))
        time.sleep(1)

    print("\n" + "=" * 60)
    print("汇总")
    print("=" * 60)
    for r in results:
        status = "OK  " if r[3] else "FAIL"
        print("  v2_%d [车道%d%%] %s : %s" % (r[0], r[1], r[2], status))
    ok_n = sum(1 for r in results if r[3])
    print("\n共 " + str(ok_n) + "/" + str(len(results)) + " 张成功 -> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
