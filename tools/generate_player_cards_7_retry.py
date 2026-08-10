#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重新生成 3 张不满意的我方卡图（攻击无人机/标枪导弹兵/毒刺导弹兵）。

改进点：
  攻击无人机 — 原图画成有人战机（有座舱+垂尾），改为明确无人飞翼布局。
  标枪导弹兵 — 强化反坦克特征：跪姿+发射筒水平指地。
  毒刺导弹兵 — 强化防空特征：站姿+发射筒大仰角指天，与标枪拉开差异。

输出到原文件夹 docs/待生成卡图_7张我方卡/，覆盖原文件，文件名仍是中文名。
只生成，不部署、不改代码。
"""
import json
import os
import subprocess
import sys
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
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人物脸。"
)

UNITS = [
    {
        "card_id": "fut_attack_drone",
        "fname": "攻击无人机",
        "prompt": STRICT_PREFIX + (
            "近未来察打一体攻击无人机，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面无人空中单位设定图，以【近未来·空中】攻击无人机为主体。"
            "重要：这是无人机，绝对没有座舱、没有驾驶员座舱盖、没有透明驾驶舱、没有垂直尾翼、没有垂尾，"
            "纯飞翼/融合翼无人飞行器布局。"
            "完整单位居中入镜，扁平大展弦比飞翼机身、机腹外挂多枚地狱火导弹与激光炮吊舱轮廓清晰，"
            "机腹球型光电侦察传感器与尾部螺旋桨/喷口结构明确，机身中央隆起为设备舱（非座舱），整体扁平紧凑，"
            "棱角分明的硬表面科幻无人飞行器，低饱和冷灰主色，"
            "多处蓝色能量核心、传感器与推进器发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE + "不要座舱、不要驾驶舱盖、不要垂尾、不要垂直尾翼、不要驾驶员。"
    },
    {
        "card_id": "mod_javelin",
        "fname": "标枪导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代标枪反坦克导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面步兵设定图，以【现代·步兵】标枪导弹兵为主体。"
            "士兵单膝跪地呈反坦克瞄准姿势，完整单位居中入镜，"
            "肩上扛标枪反坦克导弹发射筒水平指向地平线方向（反坦克，发射筒水平略下压，不是朝天），"
            "发射筒前方连接方盒形CLU指令发射单元与红外热像瞄准器轮廓清晰，"
            "战术背心、头盔（无脸面罩）与士兵跪姿剪影结构明确，轻度磨损，"
            "低饱和军绿沙色主色，局部蓝色能量瞄准器与发射器指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE
    },
    {
        "card_id": "mod_stinger",
        "fname": "毒刺导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代毒刺防空导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援步兵设定图，以【现代·支援】毒刺导弹兵为主体。"
            "士兵站立举射姿势，完整单位居中入镜，"
            "双臂高举肩扛毒刺防空导弹发射筒呈大仰角斜指天空（防空打飞机，发射筒明显朝上，区别于反坦克），"
            "发射筒握把、圆形望远瞄准器与电池冷却单元轮廓清晰，"
            "战术装具、头盔（无脸面罩）与士兵仰射剪影结构明确，轻度磨损，"
            "低饱和军绿主色，局部蓝色能量瞄准器与指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE
    },
]


def generate_image(prompt: str, output_path: str) -> tuple:
    """调用 agnes-image-2.0-flash 生成图片。"""
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "n": 1,
    })
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)

    hdr = "Authorization: Bearer " + API_KEY
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", BASE_URL + "/images/generations",
        "-H", hdr,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file,
        "--max-time", "120",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try:
        os.unlink(tmpfile)
    except OSError:
        pass

    if result.returncode != 0:
        return False, "curl exit " + str(result.returncode) + ": " + (result.stderr or "")[:200]

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
        return False, "Response not JSON: " + content[:200]

    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(data)[:200]
        return False, "No data: " + msg

    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL in response"

    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)

    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed/too small"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Output dir: " + OUTPUT_DIR)
    print("Re-generating " + str(len(UNITS)) + " images...\n")

    results = []
    for i, unit in enumerate(UNITS):
        fname = unit["fname"] + ".png"
        fpath = os.path.join(OUTPUT_DIR, fname)
        label = unit["fname"] + " (" + unit["card_id"] + ")"
        print("[" + str(i + 1) + "/" + str(len(UNITS)) + "] " + label + "...")

        success, msg = generate_image(unit["prompt"], fpath)
        results.append((unit["card_id"], unit["fname"], fname, success, msg))

        if success:
            print("  OK: " + msg)
        else:
            print("  FAILED: " + msg + " — retrying once...")
            time.sleep(3)
            success2, msg2 = generate_image(unit["prompt"], fpath)
            results[-1] = (unit["card_id"], unit["fname"], fname, success2, msg2)
            if success2:
                print("  RETRY OK: " + msg2)
            else:
                print("  RETRY FAILED: " + msg2)
        time.sleep(1)

    print("\n=== Summary ===")
    ok = sum(1 for r in results if r[3])
    fail = len(results) - ok
    for r in results:
        status = "OK" if r[3] else "FAIL"
        print("  " + r[1] + " (" + r[0] + ") -> " + r[2] + " : " + status)
    print("\nTotal: " + str(ok) + " OK, " + str(fail) + " FAIL of " + str(len(results)))


if __name__ == "__main__":
    main()
