#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重新生成攻击无人机（换描述思路）。

原思路用"无人机/飞翼"AI 仍画成有人战机。改用 MQ-9 死神/察打一体 UCAV 具体型号引导，
把"无座舱、无垂尾"放最前面，强化"无人飞行载具"概念。
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
    "不要：座舱盖、驾驶舱、驾驶员、垂直尾翼、垂尾、有人战机、战斗机座舱、"
    "三分之四视角、斜侧视、透视 perspective、背景场景、地面、投影底板、文字、水印、logo、人物脸。"
)

PROMPT = STRICT_PREFIX + (
    "近未来科幻察打一体无人飞行载具（参考MQ-9死神无人机），严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
    "科幻硬表面无人空中单位设定图。"
    "关键特征：这是无人飞行载具，机身中段是一个平滑隆起的设备舱（内部装传感器和电子设备，绝对不是驾驶舱，"
    "没有透明座舱盖、没有玻璃风挡、没有舷窗、没有驾驶员），机身后部延伸出细长尾梁连接单个倒V型尾翼。"
    "完整单位居中入镜，细长流线机身、超长平直大展弦比机翼、机翼下方挂载多枚地狱火导弹与激光制导炸弹轮廓清晰，"
    "机首球型光电侦察转塔与尾部螺旋桨推进器结构明确。"
    "注意：只有倒V型尾翼或双尾撑，没有大型垂直尾翼。整体造型修长优雅，是一架无人攻击机而非战斗机。"
    "低饱和冷灰主色，多处蓝色能量核心、传感器与推进器发光，"
    "干净棚拍纯白背景，无地面无场景无杂物，高清。"
) + NEGATIVE


def generate_image(prompt: str, output_path: str, retries: int = 3):
    """生成图片，支持多次重试（每次结果不同）。"""
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
    out_path = os.path.join(OUTPUT_DIR, "攻击无人机.png")
    print("Re-generating 攻击无人机 (attempt with MQ-9 Reaper guided prompt)...\n")
    # 生成多张候选，让用户选最好的
    candidates = []
    for i in range(4):
        cand_path = os.path.join(OUTPUT_DIR, "攻击无人机_候选%d.png" % (i + 1))
        print("[候选 %d/4]" % (i + 1))
        success, msg = generate_image(PROMPT, cand_path)
        if success:
            print("  OK: " + msg)
            candidates.append(cand_path)
        else:
            print("  FAILED: " + msg)
        time.sleep(1)
    print("\n=== Done ===")
    print("生成了 %d 张候选，路径：docs/待生成卡图_7张我方卡/攻击无人机_候选*.png" % len(candidates))
    print("请挑选最满意的一张，重命名为 攻击无人机.png（覆盖原文件）。")


if __name__ == "__main__":
    main()
