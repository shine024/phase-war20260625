#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v30.5 R5 二战尾部实验性喷气机卡图生成（2 张，D 段 card_id 命名，
仿 _gen_v26_air_cards.py 模板）：ww2_air_me262(Me-262 燕子) /
ww2_air_meteor_e(流星 F.3 特遣机)。

输出白底原图到 docs/待生成卡图_r5试验机/ 供审核（看过后再 _deploy_r5_jets.py）。"""
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _netfix as netfix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.readline().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_r5试验机")

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
    "机头必须朝向画面左侧。"
)

UNITS = [
    {
        "fname": "ww2_air_me262",
        "display": "Me-262 燕子",
        "prompt": STRICT_PREFIX + (
            "The aircraft nose is painted as a WIDE OPEN FIERCE SHARK MOUTH with sharp "
            "white teeth (classic flying-tigers style shark mouth nose art wrapping the "
            "nose), and the vertical tail fin carries a cartoon roaring TIGER HEAD FACE "
            "emblem with orange fur and black stripes (fictional squadron mascot badge "
            "painted large on the tail fin). "
            "Absolutely NO iron cross, NO Balkenkreuz, NO swastika, NO national roundel, "
            "NO military insignia, NO code numbers, NO tail bands, NO cross-like shapes "
            "or X-shaped marks anywhere on wings or fuselage. Clean smooth dark grey "
            "livery with panel lines, minimal weathering, decorated ONLY by the shark "
            "mouth nose art and the tiger head tail emblem. "
            "科幻架空世界实验性喷气战斗机（虚构涂装，无国籍无军队标识），严格2D正侧视，正交投影，"
            "游戏单位立绘/精灵图姿态，科幻设定图，以后掠翼双发喷气战机为主体，"
            "机头朝向画面左侧，完整机体居中入镜，整机只有一架飞机的完整结构：机尾单个垂直尾翼、"
            "浅后掠形机翼、近侧翼根下方紧贴机身的喷气引擎舱（与机翼连为一体，无间隙），"
            "气泡座舱盖轮廓清晰，机头机腹完全干净无任何吊舱无副油箱无外挂物，"
            "机鼻环绕张开的鲨鱼大嘴彩绘（白牙利齿，飞虎队风格机头艺术，凶悍醒目），"
            "垂直尾翼上绘制一枚醒目的卡通咆哮虎头正面像队徽（橙色虎毛黑色虎纹、虎目獠牙，"
            "像老虎吉祥物 logo 直接画在垂尾上，虚构徽章），"
            "素色深灰金属蒙皮为底，低饱和深灰主色，局部蓝色能量引擎喷口微光，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。"
            "不要：铁十字、国籍识别标识、编号数字、字母代码、过度做旧锈蚀、"
            "双垂尾、多余尾翼结构、机腹外挂、重复机翼。" + NEGATIVE
        ),
    },
    {
        "fname": "ww2_air_meteor_e",
        "display": "流星 F.3 特遣机",
        "prompt": STRICT_PREFIX + (
            "二战末期盟军喷气战斗机（流星 Meteor F.3，盟军第一种实战喷气机），严格2D正侧视，"
            "正交投影，游戏单位立绘/精灵图姿态，军事设定图，以【二战·喷气战斗机】"
            "直翼双发喷气战机为主体，机头朝向画面左侧，完整机体居中入镜，"
            "平直梯形机翼、翼中段双引擎短舱与圆润机鼻轮廓清晰，"
            "高置水平尾翼与气泡座舱结构明确，英军暗银灰涂装，"
            "低饱和银灰主色，局部蓝色能量引擎喷口微光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
]


def generate_image(prompt: str, output_path: str) -> tuple:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1}).encode("utf-8")
    req = urllib.request.Request(
        BASE_URL + "/images/generations",
        data=payload,
        headers={
            "Authorization": "Bearer " + API_KEY,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=150) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return False, "request fail: " + str(e)[:200]
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(data)[:200]
        return False, "no data: " + msg
    url = data["data"][0].get("url", "")
    if not url:
        return False, "no url in response"
    try:
        urllib.request.urlretrieve(url, output_path)
    except Exception as e:
        return False, "download fail: " + str(e)[:200]
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (%d bytes)" % os.path.getsize(output_path)
    return False, "downloaded file too small"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    # argv 过滤：只生成指定 fname（如 python _gen_r5_jets.py ww2_air_me262）
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    units = [u for u in UNITS if not only or u["fname"] == only]
    print("Output dir: " + OUTPUT_DIR)
    print("Generating %d images...\n" % len(units))
    ok = 0
    for i, unit in enumerate(units):
        fpath = os.path.join(OUTPUT_DIR, unit["fname"] + ".png")
        print("[%d/%d] %s..." % (i + 1, len(units), unit["display"]))
        success, msg = generate_image(unit["prompt"], fpath)
        if success:
            print("  OK: " + msg)
            ok += 1
        else:
            print("  FAILED: " + msg + " -- retrying once...")
            time.sleep(3)
            success, msg = generate_image(unit["prompt"], fpath)
            if success:
                print("  RETRY OK: " + msg)
                ok += 1
            else:
                print("  RETRY FAILED: " + msg)
        time.sleep(1)
    print("\nTotal: %d OK, %d FAIL" % (ok, len(units) - ok))
    if ok < len(units):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
