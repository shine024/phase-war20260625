#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""黑门三档底图生成（v27 Phase B，prompt 草稿见 docs/黑门三档底图_prompts_v1.md）。

产出：docs/黑门底图生成/gate_t{0,1,2}.png（1792x1024 原图，人工/judge 过目后
由 deploy 步骤底边对齐裁到 1280:648 再入 assets/backgrounds/bg_endless_gate_t{0,1,2}.png）。

档位：t0 初期·渗入 / t1 中期·侵蚀 / t2 深渊·渡暮（渗度 0-1 / 2-3 / 4-5）。
规则：负面词只留结构性排除（独立 negative_prompt 字段）；正面意象锁死；
不画部署格线（程序化层负责）；色板锁近黑蓝靛+青紫+淡金。

用法：
  python generate_endless_gate_tiers.py            # 三档各 1 张
  python generate_endless_gate_tiers.py --tier 2   # 只重出某一档
  python generate_endless_gate_tiers.py --tier 1 --variants 2  # 某档出 2 张候选
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
KEY_FILE = os.path.join(HERE, "level_bg_workflow", "api_keys.txt")
OUTPUT_ROOT = os.path.join(os.path.dirname(HERE), "docs", "黑门底图生成")

BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
SIZE = "1792x1024"

# 结构性排除（独立 negative_prompt 字段；概念性负面词无效且反激活，勿加）
NEGATIVE = (
    "any person, people, human, humanoid, soldier, creature, monster, animal, "
    "text, letters, words, logo, watermark, user interface, frame, border, "
    "regular grid lines, straight grid pattern, graph paper, "
    "perspective view, first person view, top down view, isometric, "
    "bright daylight, sun, blue sky, green grass, trees, clouds"
)

SKELETON = """16:9 horizontal 2D mobile game scene, side-scrolling battlefield background.
ABSOLUTELY NO PEOPLE, NO HUMANS, NO FIGURES, NO CREATURES — empty scenery background only.

LAYOUT (strict): the upper three quarters is DEEP SPACE sky. The bottom quarter is ONE SINGLE
floating rock platform seen from the side — imagine ONE whole fallen monolith slab lying
horizontally, like a single giant stone tablet: one solid rock mass whose top edge is one
continuous surface line running from the LEFT edge of the frame to the RIGHT edge of the frame
without interruption. NO void gaps dividing it, NO separate smaller side platforms, NO split
islands, NO floating sections at the same height — small floating shards appear ONLY BELOW the
slab's jagged underside, never beside or above its top surface, never splitting the slab.

SKY (dominant): {sky}

COMBAT LANE PLATFORM: grey-blue alien rock; organic irregular cracks across its surface with
{veins} The flat top surface stays walkable and unbroken across the full width, its left and
right ends reaching the frame edges. NO text, no letters, no logo, no UI, no frame, no border,
no regular grid pattern.
Style: stylized, clean, polished 2D side-scrolling mobile game background; muted low-key palette
of near-black indigo, deep violet, dim cyan and pale gold."""

# 结构性排除（prompt 正文内嵌；该端点已不接受独立 negative_prompt 字段）
NEGATIVE_INLINE = (
    "no void gap dividing the platform, no separate smaller platforms, no split islands, "
    "no missing platform sections, no text, no letters, no logo, no watermark, "
    "no user interface, no frame, no border, no regular grid lines, "
    "no people, no humanoids, no creatures, no bright daylight, no sun, no blue sky, "
    "no green grass, no trees, no clouds"
)

TIERS = {
    0: {
        "name": "初期·渗入",
        "sky": (
            "deep space of near-black indigo, mostly dark, silent and dormant; a sparse scattering "
            "of tiny dim stars (small faint dots, never bright, never dense); one very faint thin "
            "wisp of dim violet nebula near the top corner; far on the horizon a barely-visible "
            "thin dark arc — the dormant silhouette of a colossal broken ring gate, almost fading "
            "into darkness."
        ),
        "veins": (
            "thin dim cyan crystal light seeping through, barely glowing, calm and weak."
        ),
    },
    1: {
        "name": "中期·侵蚀",
        "sky": (
            "deep space of near-black indigo and dark violet; a scattered field of small dim "
            "stars; broad soft veils of dim violet and teal nebula drifting across the upper sky; "
            "on the horizon the dark silhouette of the colossal broken ring gate is now clearly "
            "visible, faintly edged with thin cyan-gold light; a few tiny dark angular alien ship "
            "silhouettes drifting motionless high in the distance."
        ),
        "veins": (
            "clearly glowing cyan crystal veins, steady and bright in the larger cracks, a few "
            "pale gold veins among them."
        ),
    },
    2: {
        "name": "深渊·渡暮",
        "sky": (
            "deep space of near-black indigo drowned in rich violet; a dense field of stars, "
            "layers of deep violet and dim magenta nebula banks glowing softly across the whole "
            "sky; the colossal broken ring gate dominates the horizon, large and close, its rim "
            "traced with glowing cyan-gold crystal light, the space inside the ring a slowly "
            "swirling dim violet vortex; several small dark alien ship silhouettes drifting near it."
        ),
        "veins": (
            "a full network of glowing cyan and pale gold crystal veins blazing through every "
            "crack, bright and alive, the broken edges of the platform rimmed with crystal light, "
            "larger shattered rock chunks floating below."
        ),
    },
}


def load_keys():
    if not os.path.exists(KEY_FILE):
        print("[FATAL] 找不到 key 文件: " + KEY_FILE)
        sys.exit(1)
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        print("[FATAL] key 文件为空")
        sys.exit(1)
    return keys


def mask(k):
    return (k[:6] + "..." + k[-4:]) if len(k) > 12 else k[:6]


def call_api(prompt, key, tag, output_path):
    # 2026-09-06 实测：该端点已不接受 negative_prompt 字段（"not supported by text image
    # queue"）——结构性排除全部写在 prompt 正文内（见 SKELETON 尾部 NO 段）。
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
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
    for ki in range(len(keys)):
        key = keys[ki % len(keys)]
        ok, msg = call_api(prompt, key, tag + "_k%d" % ki, fpath)
        if ok:
            return True, msg
        print("    重试(" + mask(key) + "): " + msg)
        time.sleep(4 + ki * 2)
    return False, "全部 key 失败"


def main():
    ap = argparse.ArgumentParser(description="黑门三档底图生成")
    ap.add_argument("--tier", type=int, default=-1, help="只出某一档（0/1/2），默认全部")
    ap.add_argument("--variants", type=int, default=1, help="每档张数，默认 1")
    ap.add_argument("--suffix", type=str, default="", help="输出文件名后缀（如 _v2）")
    args = ap.parse_args()

    tiers = [args.tier] if args.tier >= 0 else [0, 1, 2]
    keys = load_keys()
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    print("key: %d 个 / 尺寸 %s / 档位 %s" % (len(keys), SIZE, tiers))

    results = []
    for tier in tiers:
        spec = TIERS[tier]
        prompt = SKELETON.format(sky=spec["sky"], veins=spec["veins"]) + "\n" + NEGATIVE_INLINE + "."
        for v in range(args.variants):
            suffix = args.suffix if args.variants == 1 else "%s_v%d" % (args.suffix, v + 1)
            fname = "gate_t%d%s.png" % (tier, suffix)
            fpath = os.path.join(OUTPUT_ROOT, fname)
            print("[t%d-%d] %s -> %s" % (tier, v + 1, spec["name"], fname))
            ok, msg = run_one(prompt, keys, "gate_t%d" % tier, fpath)
            print("  " + ("OK: " + msg if ok else "FAIL: " + msg))
            results.append((fname, ok))
            time.sleep(1)

    print("\n" + "=" * 50)
    ok_n = sum(1 for _, ok in results if ok)
    for fname, ok in results:
        print("  %s : %s" % (fname, "OK" if ok else "FAIL"))
    print("%d/%d 成功 -> %s" % (ok_n, len(results), OUTPUT_ROOT))


if __name__ == "__main__":
    main()
