#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重新生成标枪导弹兵 + 毒刺导弹兵，各抽 4 张候选。

强化差异化：
  标枪（反坦克）：单膝跪地、发射筒水平对地、CLU方盒瞄准单元
  毒刺（防空）：  站立仰射、发射筒大仰角朝天、圆形瞄准器
"""
import json
import os
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_7张我方卡")

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)
NEGATIVE = (
    "不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人脸五官。"
)

JOBS = [
    {
        "fname": "标枪导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代标枪反坦克导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面步兵设定图，以【现代·步兵】标枪导弹兵为主体。"
            "姿势必须：士兵单膝跪地呈稳定反坦克瞄准姿态，一膝着地、另一腿蹲撑，身体压低。"
            "肩上扛标枪反坦克导弹发射筒，发射筒呈水平方向指向远方地面目标（反坦克打地面装甲，发射筒水平，绝不朝天），"
            "发射筒前方紧贴一个方盒形CLU指令发射单元与圆筒形红外热像瞄准器，CLU明显凸出，"
            "战术背心、防弹头盔（深色面罩遮挡无脸）与跪姿士兵剪影结构明确，轻度磨损，"
            "低饱和军绿沙色主色，局部蓝色能量瞄准器屏幕与发射器指示灯发光，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "fname": "毒刺导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代毒刺防空导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援步兵设定图，以【现代·支援】毒刺导弹兵为主体。"
            "姿势必须：士兵双腿站立、双手高举武器向上瞄准天空（防空打飞机仰射姿态，身体微后仰）。"
            "肩扛毒刺FIM-92防空导弹发射筒，发射筒呈明显大仰角斜指天空（约60-80度仰角，指向高空目标，绝不水平），"
            "发射筒配有外挂圆形望远式瞄准器与下方握把、后端电池冷却单元轮廓清晰，"
            "战术装具、防弹头盔（深色面罩遮挡无脸）与仰射站立剪影结构明确，轻度磨损，"
            "低饱和军绿主色，局部蓝色能量瞄准器与指示灯发光，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
]


def generate_image(prompt: str, output_path: str):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    hdr = "Authorization: Bearer " + API_KEY
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
        "-H", hdr, "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "120",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if result.returncode != 0:
        return False, "curl exit " + str(result.returncode)
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "No response file"
    with open(resp_file, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Response not JSON"
    if "data" not in data or len(data["data"]) == 0:
        return False, "No data"
    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL"
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for job in JOBS:
        print("=== " + job["fname"] + " (4 candidates) ===")
        for i in range(4):
            cand_path = os.path.join(OUTPUT_DIR, job["fname"] + "_候选%d.png" % (i + 1))
            print("[候选 %d/4]" % (i + 1))
            success, msg = generate_image(job["prompt"], cand_path)
            print("  " + ("OK: " + msg if success else "FAILED: " + msg))
            time.sleep(1)
        print("")
    print("=== Done ===")
    print("候选图在 docs/待生成卡图_7张我方卡/ ，命名 标枪导弹兵_候选*.png / 毒刺导弹兵_候选*.png")


if __name__ == "__main__":
    main()
