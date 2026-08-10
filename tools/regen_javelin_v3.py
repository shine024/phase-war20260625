#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重抽标枪导弹兵 4 张（v3）。

唯一要解决的问题：上一版士兵手里多了一把步枪。
策略：保留上一版你认可的整体风格（跪姿+肩扛标枪发射筒+CLU），
针对步枪用正向遮挡式描述——双手紧握CLU瞄准屏，武器系统遮挡双手和身体，
让 AI 没有空间画第二件武器。
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
    "不要：步枪、突击步枪、M4卡宾枪、冲锋枪、手枪、额外枪支、手里的枪、枪套、背带枪、"
    "三分之四视角、斜侧视、透视 perspective、背景场景、地面、投影底板、文字、水印、logo、人脸五官。"
)

PROMPT = STRICT_PREFIX + (
    "现代FGM-148标枪反坦克导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
    "科幻硬表面步兵设定图，以【现代·步兵】标枪导弹兵为主体。"
    "士兵单膝跪地呈稳定反坦克瞄准姿态，一膝着地、另一腿蹲撑，身体压低。"
    "标枪系统是士兵身上唯一的武器：肩上扛着一根粗圆柱形标枪反坦克导弹发射筒，"
    "发射筒水平指向远方地面目标（反坦克打地面装甲，发射筒水平，绝不朝天），"
    "发射筒前方紧贴一个方盒形CLU指令发射单元，CLU侧面有热成像瞄准显示屏和操作按钮，"
    "射手右眼紧贴CLU瞄准屏观察。"
    "关键构图：士兵的双手都紧紧握住CLU瞄准屏和发射筒握把，双手完全被导弹系统占用、紧贴武器，"
    "大型CLU方盒和发射筒遮挡住士兵的双手和上半身大部分，画面中看不到士兵的手有空闲，"
    "士兵身上除了这套标枪导弹系统外没有任何其它武器、没有枪套、没有背着的步枪。"
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
    print("=== 标枪导弹兵 v3 (4 candidates, 唯一改: 去步枪) ===")
    for i in range(4):
        cand_path = os.path.join(OUTPUT_DIR, "标枪导弹兵_候选%d.png" % (i + 1))
        print("[候选 %d/4]" % (i + 1))
        success, msg = generate_image(PROMPT, cand_path)
        print("  " + ("OK: " + msg if success else "FAILED: " + msg))
        time.sleep(1)
    print("\n=== Done ===")


if __name__ == "__main__":
    main()
