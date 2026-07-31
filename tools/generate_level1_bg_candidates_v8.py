#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图 v8。

用户反馈（v7 后，2点）：
1. 中景占了车道 → v7 把中景加厚过头，模型把过渡带挤进地面区域。
   修正：中景严格约束在地平线上方，明确"不准向地面/车道延伸/下垂"。
2. 画面出现人物 → 负面词 soldiers/infantry 不够强，模型还是画了人。
   修正：正面 prompt 多处强调"无人/绝对空旷"，负面词大幅扩写人物相关条目。

其余沿用 v7：天空窄、地面锁宽(下3/4)、左右入口清空、底缘薄装饰。
端点：apihub.agnes-ai.cn / agnes-image-2.0-flash / 1799x1024
输出：docs/第一关战场候选_5张_v8/
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
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张_v8")
SIZE = "1792x1024"

# 大幅扩写人物/人形相关负面词（解决"出现人物"）
NEGATIVE = (
    "any person, people, human, humans, man, men, woman, women, soldier, soldiers, infantry, "
    "troops, fighter, fighters, warrior, warriors, gunman, riflemen, officer, commander, scout, "
    "human silhouette, human figure, human shape, human shadow, human face, face, head, "
    "person standing, person walking, person running, person crouching, person kneeling, "
    "any humanoid form, limbs, arms, legs, torso, body, bodies, "
    "enemies, monsters, creatures, animals, horses, "
    "weapons held by figures, rifles, pistols, MP18, bayonets, swords, "
    "combat effects, blood, corpses, bodies, "
    "aircraft, airplanes, helicopters, drones, tanks, armored vehicles, warships, missiles, "
    "skill VFX, muzzle flashes, explosions with debris, "
    "UI, HUD, buttons, text, letters, numbers, watermark, logo, "
    "curved road, S-shaped path, broken path, blocked lane, "
    "midground spilling onto the lane, midground dropping into the ground, "
    "vegetation growing down onto the lane, trench extending into the lane, "
    "obstacles at the lane entries, barricades at the left edge, barricades at the right edge, "
    "barbed wire blocking entry, rocks blocking entry, objects at the left side, objects at the right side, "
    "thick debris band at the bottom, wide crater strip, large rubble pile at the bottom, "
    "huge sky, dominant sky, mostly sky, "
    "top-down view, isometric, strong perspective distortion, fisheye, "
    "photorealistic 3D render, unreal engine screenshot, dark horror, gore, blur, "
    "low resolution, messy composition, duplicate lanes"
)


def build_prompt(mid_desc):
    return (
        "16:9 horizontal 2D mobile game scene, side-scrolling battlefield background. "
        "ABSOLUTELY NO PEOPLE, NO SOLDIERS, NO HUMANS, NO FIGURES, NO CHARACTERS — this is an EMPTY scenery background only. "
        "The image must show only landscape and terrain: sky, distant mountains, midground structures, and ground. "
        "Nothing alive, nothing with a face, nothing humanoid.\n"
        "LAYOUT (strict): the GROUND / combat lane is the dominant element taking the lower three-quarters of the image. "
        "The sky is COMPRESSED to a thin band at the top. "
        "CRITICAL: the MIDGROUND transition zone sits strictly ABOVE the ground lane, hugging the horizon line from above. "
        "The midground must NOT spill, drop, or extend downward into the ground lane area. "
        "The boundary between midground and ground is a clean horizon line — midground stays up near the horizon, ground stays clean below.\n"
        "SKY (thin, compressed): a narrow strip of dawn sky along the very top, layered blue-cyan distant mountains, "
        "morning light, post-rain cool gray-blue haze, faint cyan electric haze, subtle sci-fi undertone.\n"
        "MIDGROUND TRANSITION (stays above the horizon, does NOT invade the ground): " + mid_desc + "\n"
        "COMBAT LANE (bottom three-quarters, dominant, MUST STAY OPEN): a single continuous flat clean ground band running straight "
        "left-to-right across the full frame width, near side-view, sharp edges, unbroken, not curved. Exactly ONE lane only, "
        "no secondary paths, no forks, no diagonal roads. The lane interior is OPEN, FLAT, and CLEAR so units can deploy.\n"
        "ENTRY ZONES: both the LEFT edge and RIGHT edge of the lane are completely CLEAR and open — nothing blocks where units "
        "enter from the sides. No objects, no props, no barricades at the side entrances.\n"
        "BOTTOM EDGE: only a VERY THIN scattering of tiny details right along the bottommost edge — faint muddy ruts, sparse "
        "tiny grass tufts. Keep this band NARROW; most of the lower area stays open clear ground.\n"
        "Era: World War I. Iron Wall Corp style: steel-blue + earthy brown + khaki, fortified and sturdy. Dawn light.\n"
        'Narrative: Phase War Stage 1 "晨曦中的索姆河，第一阶段突破作战" (no text, no people). '
        'Roster "Stage 1 — Infantry Squad · MP18" (do NOT depict the squad or the MP18 — scenery only).\n'
        "Style: bright, clean, polished 2D side-scrolling mobile game background, high detail, readable, "
        "no characters, no combat VFX, no text, 16:9 horizontal."
    )


# 5 档：差异在中景内容（不同主题元素），但都约束"压在地平线上方不进地面"
CANDIDATES = [
    {"idx": 1, "label": "废墟农场中景",
     "mid_desc": "a band of ruined farmhouse silhouettes, collapsed walls, and distant craters hugging the horizon line from above."},
    {"idx": 2, "label": "树林中景",
     "mid_desc": "a band of shattered woods, broken tree trunks, and low mist hugging the horizon line from above."},
    {"idx": 3, "label": "战壕工事中景",
     "mid_desc": "a band of distant sandbag berms, low bunkers, and trench traces hugging the horizon line from above."},
    {"idx": 4, "label": "混合中景",
     "mid_desc": "a band of ruined farmhouses, shattered woods, and distant barbed wire lines hugging the horizon line from above."},
    {"idx": 5, "label": "极简中景",
     "mid_desc": "a thin band of faint distant ruined structures and mist hugging the horizon line from above."},
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
    print("v8 策略：中景约束在地平线上方(不进地面) + 大幅强化无人约束\n")

    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        prompt = build_prompt(c["mid_desc"])
        fname = "level1_v8_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] %s -> %s" % (idx, c["label"], fname))
        ok = False
        msg = ""
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            ok, msg = call_api(prompt, NEGATIVE, key, "v8_%d k%d" % (idx, ki), fpath)
            if ok:
                print("  OK: " + msg)
                break
            print("  重试(" + mask(key) + "): " + msg)
            time.sleep(4 + ki * 2)
        results.append((idx, c["label"], fname, ok))
        time.sleep(1)

    print("\n" + "=" * 50 + "\n汇总")
    for r in results:
        print("  v8_%d [%s] %s : %s" % (r[0], r[1], r[2], "OK" if r[3] else "FAIL"))
    print("-> " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
