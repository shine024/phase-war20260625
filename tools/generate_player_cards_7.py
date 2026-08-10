#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 7 张我方卡专属卡图（供审核）。

涉及卡牌：
  ww1_37mm           37mm高射炮      （一战·支援防空炮）
  mod_javelin        标枪导弹兵      （现代·步兵反坦克）
  mod_stinger        毒刺导弹兵      （现代·支援防空步兵）
  fut_attack_drone   攻击无人机      （近未来·空中察打一体）
  fut_nano_drone     纳米修复机      （近未来·空中支援无人机）
  fut_space_fighter  空天战斗机      （近未来·空中高超音速战机）
  fut_stealth_bomber 隐形轰炸机      （近未来·空中隐身飞翼）

按 docs/ART_PIPELINE_AI_ICON_GENERATION.md 工作流：
  调 agnes-image-2.0-flash API → 输出白底 1024×1024 到单独文件夹。
  文件名用中文名，方便人工审核。
  审核通过后，再复制 deploy_card_icons_11.py 改 FILES 部署（白底转透明+缩放+翻转），
  并更新 scripts/ui_asset_loader.gd 的 PLAYER_ICON_OVERRIDE。

注意：本脚本只生成，不部署、不改代码。
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

# 复用 regenerate_7_sprites.py / generate_missing_card_icons_11.py 的 prompt 模板
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
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人物。"
)

# 7 张卡：显示名（=文件名）、prompt
UNITS = [
    {
        "card_id": "ww1_37mm",
        "fname": "37mm高射炮",
        "prompt": STRICT_PREFIX + (
            "一战37毫米高射炮，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援防空炮设定图，以【一战·支援】37mm高射炮为主体，"
            "完整单位居中入镜，细长高射炮管高仰角指向天空、十字形/三脚炮架与轮式拖架轮廓清晰，"
            "老式机械瞄准具与炮闩结构明确，金属磨损旧化，"
            "低饱和军绿灰主色，局部蓝色能量炮膛发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "card_id": "mod_javelin",
        "fname": "标枪导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代标枪反坦克导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面步兵设定图，以【现代·步兵】标枪导弹兵为主体，"
            "完整单位居中入镜，肩扛标枪反坦克导弹发射筒、红外瞄准器与发射控制单元轮廓清晰，"
            "战术背心、头盔与士兵身形剪影结构明确，轻度磨损，"
            "低饱和军绿沙色主色，局部蓝色能量瞄准器与发射器指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "card_id": "mod_stinger",
        "fname": "毒刺导弹兵",
        "prompt": STRICT_PREFIX + (
            "现代毒刺防空导弹兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援步兵设定图，以【现代·支援】毒刺导弹兵为主体，"
            "完整单位居中入镜，肩扛毒刺防空导弹发射筒高仰角、圆形瞄准器与电池冷却单元轮廓清晰，"
            "战术装具与士兵身形剪影结构明确，轻度磨损，"
            "低饱和军绿主色，局部蓝色能量瞄准器与指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "card_id": "fut_attack_drone",
        "fname": "攻击无人机",
        "prompt": STRICT_PREFIX + (
            "近未来攻击无人机，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面空中单位设定图，以【近未来·空中】攻击无人机为主体，"
            "完整单位居中入镜，大展弦比飞翼/三角翼机身、机腹挂载地狱火导弹与激光炮吊舱轮廓清晰，"
            "机首光电球传感器与尾部喷口结构明确，棱角分明，"
            "低饱和冷灰主色，多处蓝色能量核心、传感器与推进器发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "card_id": "fut_nano_drone",
        "fname": "纳米修复机",
        "prompt": STRICT_PREFIX + (
            "近未来纳米修复无人机，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面支援空中单位设定图，以【近未来·空中】纳米修复机为主体，"
            "完整单位居中入镜，圆润球形/蛋形机身、下方多条纳米修复射线发射管与医疗机械臂轮廓清晰，"
            "小型稳定翼与悬浮能量场结构明确，柔和科幻医疗风格，"
            "低饱和白蓝主色，多处柔和蓝色能量修复光晕与核心发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "card_id": "fut_space_fighter",
        "fname": "空天战斗机",
        "prompt": STRICT_PREFIX + (
            "近未来空天战斗机，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面空中单位设定图，以【近未来·空中】空天战斗机为主体，"
            "完整单位居中入镜，高超音速三角翼融合机身、双外倾垂尾与机腹粒子炮轮廓清晰，"
            "空天导弹挂点与矢量喷口结构明确，棱角分明，"
            "低饱和冷灰白主色，多处蓝色能量引擎喷口与武器核心发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
    },
    {
        "card_id": "fut_stealth_bomber",
        "fname": "隐形轰炸机",
        "prompt": STRICT_PREFIX + (
            "近未来隐形轰炸机，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面空中单位设定图，以【近未来·空中】隐形轰炸机为主体，"
            "完整单位居中入镜，飞翼式隐身布局、平滑锯齿后缘与机腹内置弹仓轮廓清晰，"
            "隐身涂层蒙皮与背部进气口结构明确，无垂尾，棱角分明的扁平轮廓，"
            "低饱和暗灰黑主色，多处蓝色能量光学边缘与核心发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"
        ) + NEGATIVE,
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

    # 下载图片
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)

    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed/too small"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Output dir: " + OUTPUT_DIR)
    print("Generating " + str(len(UNITS)) + " images...\n")

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
