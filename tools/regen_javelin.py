#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重新生成标枪导弹兵 4 张候选。

上一版问题：士兵拿的是突击步枪+背普通火箭筒，缺标枪核心特征CLU。
改进：
  1. 明确士兵手里没有步枪/没有M4/没有任何枪支，只操作标枪导弹系统
  2. 细化标枪系统结构：方形CLU热像瞄准单元贴在射手眼睛前方瞄准 +
     CLU下方/前方连接圆柱形发射筒，整体扛在肩上
  3. 跪姿反坦克瞄准
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
    "不要：步枪、突击步枪、M4卡宾枪、手枪、任何额外枪支、手里的枪、"
    "三分之四视角、斜侧视、透视 perspective、背景场景、地面、投影底板、文字、水印、logo、人脸五官。"
)

PROMPT = STRICT_PREFIX + (
    "现代FGM-148标枪反坦克导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
    "科幻硬表面步兵设定图，以【现代·步兵】标枪导弹兵为主体。"
    "关键：士兵手里没有任何步枪、没有突击步枪、没有任何额外枪支，整个画面只有标枪导弹系统这一件武器。"
    "标枪系统结构必须完整画对：士兵右眼贴着一个方形CLU指令发射单元（CLU是方盒形电子瞄准设备，"
    "侧面有热成像瞄准显示屏和操作按钮，射手眼睛紧贴CLU瞄准屏观察），CLU下方通过支架连接一根"
    "粗圆柱形一次性发射筒（发射筒水平指向远方地面装甲目标，发射筒前端封闭、后端有排气口），"
    "整个标枪系统（CLU+发射筒）扛在士兵肩上，重心靠肩支撑。"
    "士兵姿势：单膝跪地反坦克瞄准姿态，一膝着地蹲撑、上身前倾压低，双手托住标枪系统瞄准。"
    "战术背心、防弹头盔（深色面罩遮挡无脸）与跪姿剪影结构明确，轻度磨损，"
    "低饱和军绿沙色主色，CLU瞄准屏发出局部蓝色能量光，发射筒指示灯发光，"
    "干净棚拍纯白背景，无地面无场景无杂物，高清。"
) + NEGATIVE


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
    print("=== 标枪导弹兵 (4 candidates, 重抽强化CLU) ===")
    for i in range(4):
        cand_path = os.path.join(OUTPUT_DIR, "标枪导弹兵_候选%d.png" % (i + 1))
        print("[候选 %d/4]" % (i + 1))
        success, msg = generate_image(PROMPT, cand_path)
        print("  " + ("OK: " + msg if success else "FAILED: " + msg))
        time.sleep(1)
    print("\n=== Done ===")
    print("候选在 docs/待生成卡图_7张我方卡/标枪导弹兵_候选*.png")


if __name__ == "__main__":
    main()
