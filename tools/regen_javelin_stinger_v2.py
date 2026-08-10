#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重抽标枪/毒刺，解决"AI总给士兵配枪"问题。

策略：士兵+武器都画，但武器系统占满画面主体，士兵双手都握着导弹系统，
明确"双手被导弹系统完全占用、手中无空隙持枪、身上无可见枪套枪带"。
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
    "不要：步枪、突击步枪、M4卡宾枪、冲锋枪、手枪、任何额外枪支、手里的枪、腰间的枪、枪套、背带枪、"
    "三分之四视角、斜侧视、透视 perspective、背景场景、地面、投影底板、文字、水印、logo、人脸五官。"
)

JOBS = [
    {
        "fname": "标枪导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代FGM-148标枪反坦克导弹系统特写立绘，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面设定图，以【现代·步兵】标枪反坦克导弹系统为主体。"
            "构图：标枪导弹系统（CLU+发射筒）占据画面中心70%以上，是绝对主体；一名射手剪影跪在系统后方操作，"
            "射手很小只露半身剪影作陪衬，被大型导弹系统遮挡大部分身体。"
            "标枪系统画法：粗圆柱形一次性发射筒水平横置指向画面左侧远方（反坦克打地面目标，水平方向），"
            "发射筒上方/后方紧贴一个方盒形CLU指令发射单元（CLU侧面有热成像瞄准显示屏和操作面板），"
            "射手眼睛贴着CLU瞄准屏观察，双手托住CLU和发射筒。"
            "关键：射手的双手完全被CLU和发射筒占用、紧紧握着导弹系统，手中没有任何空隙握枪，"
            "身上没有可见的枪套、枪带、步枪、手枪，士兵身上唯一的武器就是这套标枪导弹系统。"
            "射手单膝跪地反坦克瞄准姿态，防弹头盔（深色面罩无脸），轻度磨损，"
            "低饱和军绿沙色主色，CLU瞄准屏发出局部蓝色能量光，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "fname": "毒刺导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代FIM-92毒刺防空导弹系统特写立绘，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面设定图，以【现代·支援】毒刺防空导弹系统为主体。"
            "构图：毒刺导弹发射筒占据画面中心70%以上，是绝对主体；一名射手剪影站在系统后方高举操作，"
            "射手很小只露半身剪影作陪衬，被大型发射筒遮挡部分身体。"
            "毒刺系统画法：细长圆柱形发射筒以明显大仰角（约60-80度）斜指天空（防空打飞机，朝天，绝不水平），"
            "发射筒中部有圆形望远式瞄准器和方形电池冷却单元凸出，射手双手高举握住发射筒中段握把。"
            "关键：射手的双手完全被发射筒握把占用、高举握紧导弹筒，手中没有任何空隙握枪，"
            "身上没有可见的枪套、枪带、步枪、手枪，士兵身上唯一的武器就是这套毒刺导弹系统。"
            "射手双腿站立仰射姿态（防空向上瞄准，身体微后仰），防弹头盔（深色面罩无脸），轻度磨损，"
            "低饱和军绿主色，瞄准器发出局部蓝色能量光，"
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


if __name__ == "__main__":
    main()
