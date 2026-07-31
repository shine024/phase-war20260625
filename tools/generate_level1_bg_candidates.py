#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第一关战场背景候选图生成（5 张，每张可战斗区域占比递增 5%）。

题材：一战西线平原战壕（= 第一关 bg_level_01 同场景）。
差异化：每张图的"可通行战斗地面"横向占比逐张 +5%（片1≈50% → 片5≈70%），
       其余风格统一，便于横向对比挑出"利用率最好"的一张。
端点：https://apihub.agnes-ai.cn/v1 （用户提供，与文档里的 .com 不同）。
Key：tools/_api_keys_level1.txt，3 个 key 轮换。
输出：docs/第一关战场候选_5张/level1_candidate_01.png ~ _05.png
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_keys_level1.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "第一关战场候选_5张")

# 先试横版（贴合现有战场 1376x768），API 不支持时回退正方形
SIZE_CANDIDATES = ["1536x1024", "1792x1024", "1024x1024"]

# 通用风格前缀：一战战场背景（场景图，非单位立绘）
STYLE_PREFIX = (
    "一战西线平原战场，横版广角侧视游戏战斗背景图，2.5D战术策略游戏场景设定，"
    "低饱和战时灰绿土黄色调，阴沉硝烟弥漫的天空与低矮地平线，"
    "战壕与弹坑荒原地面，科幻相位元素点缀（地表局部悬浮蓝色能量光带与全息扫描线纹路），"
    "无人物无士兵无车辆无单位，无文字无水印无logo无UI边框，高清横版场景壁纸构图。"
)
NEGATIVE = (
    "不要：人物、士兵、坦克、车辆、武器装备、单位立绘、文字、水印、logo、UI、边框、"
    "正视图、纯俯视图、鸟瞰、严重广角畸变、现代建筑、卡通风格。"
)


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
    """单次 API 调用 + 下载。返回 (ok, msg)。"""
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
        # 有些 API 直接返回 b64
        b64 = data["data"][0].get("b64_json", "")
        if b64:
            import base64
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
    """连通性自检：确认端点/模型/尺寸可用，返回可用 size。"""
    print("=" * 60)
    print("连通性自检：端点 " + BASE_URL + " / 模型 " + MODEL)
    print("=" * 60)
    test_prompt = "a simple flat grass field, side view, no objects, clean"
    chosen_size = None
    for size in SIZE_CANDIDATES:
        for ki, key in enumerate(keys):
            tag = "probe " + size + " key" + str(ki)
            print("  尝试 " + size + " + key " + mask(key) + " ...", end=" ", flush=True)
            probe_path = os.path.join(OUTPUT_DIR, "_probe.png")
            ok, msg = call_api(test_prompt, key, size, tag, probe_path)
            print("OK" if ok else "FAIL")
            if ok:
                chosen_size = size
                # 清理探测图
                try:
                    os.unlink(probe_path)
                except OSError:
                    pass
                print("  >>> 自检通过，采用尺寸 " + size + "\n")
                return chosen_size
            else:
                print("    " + msg)
        print("  --- 尺寸 " + size + " 所有 key 均失败，尝试下一个尺寸 ---")
    return None


# 5 张候选：可战斗地面横向占比逐张 +5%
CANDIDATES = [
    {
        "idx": 1,
        "ground_pct": "约50%",
        "desc": "两侧远景多",
        "prompt": STYLE_PREFIX + (
            "可通行战斗地面（战壕壕沟边缘与可站立平原台地）从画面左侧约20%处延伸到右侧约70%处，"
            "横向约占画面宽度50%；画面左右两侧为远景天空硝烟与不可通行的荒野丘陵，"
            "地平线位于画面上方约1/3处，主体可战斗区域居中。" + NEGATIVE
        ),
    },
    {
        "idx": 2,
        "ground_pct": "约55%",
        "desc": "左侧加前哨",
        "prompt": STYLE_PREFIX + (
            "可通行战斗地面从画面左侧约15%处延伸到右侧约70%处，横向约占画面宽度55%；"
            "左侧加入前哨沙袋掩体阵地边缘，可战斗地面比第一张向左扩展约5%；"
            "地平线位于画面上方约1/3处。" + NEGATIVE
        ),
    },
    {
        "idx": 3,
        "ground_pct": "约60%",
        "desc": "右侧加纵深壕",
        "prompt": STYLE_PREFIX + (
            "可通行战斗地面从画面左侧约10%处延伸到右侧约70%处，横向约占画面宽度60%；"
            "右侧加入纵深纵横交通壕网络，可战斗地面继续向左扩展约5%；"
            "地平线位于画面上方约1/3处。" + NEGATIVE
        ),
    },
    {
        "idx": 4,
        "ground_pct": "约65%",
        "desc": "全景宽广",
        "prompt": STYLE_PREFIX + (
            "可通行战斗地面从画面左侧约5%处延伸到右侧约70%处，横向约占画面宽度65%；"
            "全景宽广战壕网络与弹坑荒原，可战斗地面进一步扩展约5%；"
            "地平线略下压，可战斗区域宽阔。" + NEGATIVE
        ),
    },
    {
        "idx": 5,
        "ground_pct": "约70%",
        "desc": "超宽战斗平台",
        "prompt": STYLE_PREFIX + (
            "可通行战斗地面从画面左边缘延伸到右侧约70%处，横向约占画面宽度70%；"
            "超宽战斗平台几乎横贯画面，战壕与平原台地连成大片可部署区域，"
            "地平线压低到画面上方约1/4处，可战斗地面占比最大。" + NEGATIVE
        ),
    },
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("载入 " + str(len(keys)) + " 个 key: " + ", ".join(mask(k) for k in keys))
    print("输出目录: " + OUTPUT_DIR + "\n")

    size = probe(keys)
    if not size:
        print("\n[FATAL] 所有端点/模型/尺寸组合均不通，终止。请检查端点/key/模型名。")
        sys.exit(2)

    print("开始生成 5 张候选（尺寸 " + size + "，可战斗地面占比 50%→70%）...\n")
    results = []
    for c in CANDIDATES:
        idx = c["idx"]
        fname = "level1_candidate_%02d.png" % idx
        fpath = os.path.join(OUTPUT_DIR, fname)
        print("[%d/5] 可战斗地面 %s (%s) -> %s" % (idx, c["ground_pct"], c["desc"], fname))

        ok = False
        msg = ""
        # 3 个 key 各试一次
        for ki in range(len(keys)):
            key = keys[(idx - 1 + ki) % len(keys)]
            tag = "c%d k%d" % (idx, ki)
            ok, msg = call_api(c["prompt"], key, size, tag, fpath)
            if ok:
                print("  OK: " + msg)
                break
            else:
                print("  重试(" + mask(key) + "): " + msg)
            time.sleep(2)
        results.append((idx, c["ground_pct"], fname, ok, msg))
        time.sleep(1)

    print("\n" + "=" * 60)
    print("汇总")
    print("=" * 60)
    for r in results:
        status = "OK  " if r[3] else "FAIL"
        print("  片%d [%s] %s : %s" % (r[0], r[1], r[2], status))
    ok_n = sum(1 for r in results if r[3])
    print("\n共 " + str(ok_n) + "/" + str(len(results)) + " 张成功 → " + OUTPUT_DIR)


if __name__ == "__main__":
    main()
