#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v6。

用户实测反馈（v5 后）：天空远景 50% / 中景 10% / 车道 40% —— 车道还是太小。
关键洞察：模型系统性把车道做小（要求 50% 只给 40%，约打 8 折）。

v6 策略（反向超额 + 强制差异化）：
1. 反向超额：既然模型打 8 折，就要求"地面占下 2/3~3/4"，让它最终落在 55~65%。
2. 5 档把地平线逐档往上推（upper third → near top），强制每张车道都比上一张大。
3. 天空/远景明确最小化（thin band / minimal sky / compressed）。
4. 车道底部允许少量点缀（用户说"最下边可以有一些东西"）：近底缘可有零星弹坑/碎石/草丛/车辙，但不挡车道主体。
5. 障碍物（沙袋/铁丝网/木桩）仍约束在地平线过渡带，不进车道中段。
端点：apihub.agnes-ai.cn / agnes-image-2.0-flash / 1792x1024
输出：docs/第一关战场候选_5张_v6/
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v6")
SIZE = "1792x1024"

NEGATIVE = (
    "characters, people, soldiers, infantry, human silhouettes, enemies, monsters, "
    "weapons held by figures, rifles, pistols, MP18, combat effects, blood, corpses, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris bodies, UI, HUD, buttons, text, "
    "letters, numbers, watermark, logo, curved road, S-shaped path, broken path, blocked lane, "
    "large obstacles blocking the lane, barricades across the lane, barbed wire across the lane, "
    "rocks blocking the lane, stumps blocking the lane, debris blocking the lane, pits blocking the lane, "
    "huge sky, dominant sky, mostly sky, top-down view, isometric, strong perspective distortion, "
    "fisheye, photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, "
    "low resolution, messy composition, duplicate lanes"
)


def build_prompt(horizon_desc, ground_share_desc, ground_edge_desc):
    return (
        "16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.\n"
        "IMPORTANT: The GROUND is the dominant, largest element of the image. The sky is kept minimal and compressed.\n"
        "Horizon line placement: " + horizon_desc + "\n"
        + ground_share_desc + "\n"
        "The combat lane is a single continuous flat ground band running straight left-to-right across the full frame width, "
        "near side-view, sharp edges, unbroken, not curved. Exactly ONE lane only, no secondary paths, no forks, no diagonal roads.\n"
        "Lane interior is mostly OPEN and flat so units can deploy — the main body of the lane stays clear. "
        + ground_edge_desc + "\n"
        "Any fortified props (sandbag berms, barbed wire lines, wooden stake rows, low bunkers, trench traces, ruined farmhouse silhouettes, "
        "shattered woods) appear ONLY in the THIN transition zone right around the horizon line up high — they must NOT come down into the "
        "broad lane area.\n"
        "Near horizon: WW1 Somme morning, river mist, distant craters, faint cyan electric haze, subtle sci-fi undertone. "
        "Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy. Dawn light, morning glow, "
        "layered blue-cyan distant mountains fading into atmospheric perspective.\n"
        'Narrative: Phase War Stage 1 "晨曦中的索姆河，第一阶段突破作战" (no text). '
        'Roster "Stage 1 — Infantry Squad · MP18" (no soldiers, no weapons).\n'
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable, "
        "no characters, no combat VFX, no text, 16:9 horizontal."
    )


# 5 档：地平线逐档升高（车道逐档变大），每档超额要求（应对模型打8折）
CANDIDATES = [
    {"idx": 1, "label": "地面占下2/3",
     "horizon_desc": "horizon line is in the UPPER THIRD of the frame (about 1/3 down from the top), so the ground takes the lower two-thirds.",
     "ground_share_desc": "The entire lower two-thirds of the image is open ground / combat lane. The sky and distant mountains fill only the top third.",
     "ground_edge_desc": "Along the very bottom edge, a few scattered details are welcome: faint muddy vehicle ruts, low scattered grass tufts, small shallow puddles, minor ground texture."},
    {"idx": 2, "label": "地面占下3/4",
     "horizon_desc": "horizon line is near the TOP QUARTER of the frame, so the ground takes the lower three-quarters.",
     "ground_share_desc": "The entire lower three-quarters of the image is open ground / combat lane — the ground is the main subject. The sky is reduced to a thin band at the top.",
     "ground_edge_desc": "Along the very bottom edge, scattered details are welcome: a few shallow shell craters near the bottom, scattered rubble bits, trampled churned earth, small puddles."},
    {"idx": 3, "label": "地面占下4/5",
     "horizon_desc": "horizon line is HIGH, about one-fifth down from the top, so the ground fills the lower four-fifths.",
     "ground_share_desc": "Open ground / combat lane fills almost the whole image — the lower four-fifths is ground. The sky is just a slim strip across the very top.",
     "ground_edge_desc": "Near the bottom edge, welcome some detail: scattered crater lips, broken ground texture, sparse dead grass patches, faint track marks."},
    {"idx": 4, "label": "地面占主导(地平线近顶)",
     "horizon_desc": "horizon line is very HIGH, near the top of the frame, so the ground dominates almost the entire image.",
     "ground_share_desc": "The ground / combat lane is the overwhelmingly dominant element, filling nearly the entire frame. Only a narrow sliver of sky sits at the very top.",
     "ground_edge_desc": "Near the bottom edge, welcome richer detail: scattered battlefield debris along the bottom, shallow craters, churned muddy earth, broken fence posts lying flat."},
    {"idx": 5, "label": "几乎全是地面",
     "horizon_desc": "horizon line is at the very TOP edge of the frame, so the ground fills essentially the entire image.",
     "ground_share_desc": "Almost the ENTIRE image is open ground / combat lane — an expansive flat battlefield stretching edge to edge. The sky is barely a thin line at the top.",
     "ground_edge_desc": "Near the bottom edge, welcome detail: scattered shell craters, rubble, churned earth, scattered debris, muddy patches — a worn battlefield floor."},
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
    print("v6 策略：反向超额要求地面占2/3~全屏（应对模型打8折）+ 5档地平线逐档升高 + 底缘允许点缀\n")

    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = build_prompt(c["horizon_desc"], c["ground_share_desc"], c["ground_edge_desc"])
        fname = "level1_v6_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] %s -> %s" % (idx, c["label"], fname))
        ok = False
        msg = ""
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            ok, msg = call_api(prompt, NEGATIVE, key, "v6_%d k%d" % (idx, ki), fpath)
            if ok:
                print("  OK: " + msg)
                break
            print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["label"], fname, ok))
        time.sleep(1)

    print("\n" + "=" * 50 + "\n汇总")
    for r in results:
        print("  v6_%d [%s] %s : %s" % (r[0], r[1], r[2], "OK" if r[3] else "FAIL"))
    print("-> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
