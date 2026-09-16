#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W3 步骤 4 C 档重生成（2026-09-14 收尾计划；用户已裁决"非手改，按 C 档重生成"）。

对象：vis_player_001（罗尔斯装甲车·一战坦克）/ vis_player_075（Flak 88 防空炮）/
ww2_arm_garand_para（二战伞兵步兵）——09-11 flow 轮产物照片感越档（写实度 5）。
prompt=STYLE_BIBLE §6.1 十段拼装逐字（历史写实系→冰天青 rim；负面栏 5 词结构性白名单）。
输出白底原图 docs/待生成卡图_批4x_收尾2026-09-14/ 供人工审核；
审核过目后另跑部署（white_to_alpha→fit_square→player 直出/enemy 翻转→thumbs）。
API 复用 _gen_r5_jets.py 已验证模式（agnes-image-2.0-flash + tools/_api_key.txt）。
"""
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _netfix as netfix

netfix.install()  # 绕系统代理 + 跳证书校验（批次④ §9 同款）

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.readline().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_批4x_收尾2026-09-14")

# §6.1 基础锚段（第 4~7、9 段逐字）——历史写实系 rim 档
TAIL = (
    " overcast diffused lighting, one narrow cool sky-blue rim light along the "
    "back edge, muted cold palette of deep blue-grey steel and cold grey, thick "
    "painterly illustration, clean painterly silhouettes defined by value "
    "contrast and a narrow rim light, smooth blended brushwork, hard-edge steel "
    "surfaces, clean pure white background with NO ground"
)
NEG = " text, perspective view, frame, ground, ceiling"

# §6.1 第 1-3 段：era 插槽 + 构图串头（取至 even white margins）+ 兵种变体句
UNITS = [
    {
        "fname": "vis_player_001",
        "display": "vis_player_001 罗尔斯装甲车（一战坦克 identity 沿批2）",
        "prompt": (
            "WWI single military vehicle, full body, eye-level side view, facing "
            "right, historically accurate equipment detail, unit fills about "
            "three quarters of the frame with even white margins, a single tank "
            "with rotating turret and long main gun barrel, layered hull armor, "
            "wide track runs" + TAIL + NEG
        ),
    },
    {
        "fname": "vis_player_075",
        "display": "vis_player_075 Flak88 防空炮（二轮：锁拖车十字炮架）",
        "prompt": (
            "WWII single military vehicle, full body, eye-level side view, facing "
            "right, historically accurate equipment detail, unit fills about "
            "three quarters of the frame with even white margins, a single towed "
            "heavy anti-aircraft gun emplaced for firing, mounted on a low flat "
            "cruciform base frame with four outrigger legs and a split trail "
            "carriage, its one long barrel angled steeply upward, a flat gunner "
            "shield plate and an ammunition rack stand beside the mount, the gun "
            "stands alone with no wheels and no engine vehicle" + TAIL + NEG
        ),
    },
    {
        "fname": "ww2_arm_garand_para",
        "display": "ww2_arm_garand_para 二战伞兵步兵（二轮：锁单主体）",
        "prompt": (
            "WWII single military unit, full body, eye-level side view, facing "
            "right, historically accurate equipment detail, unit fills about "
            "three quarters of the frame with even white margins, one lone foot "
            "soldier standing completely alone, a single soldier holding his "
            "rifle across the chest with both hands muzzle pointing right, full "
            "field pack and helmet, calm ready stance, only one soldier in the "
            "whole image with no second figure and no echo copy" + TAIL + NEG
        ),
    },
]


def generate_image(prompt: str, output_path: str) -> tuple:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1152x768", "n": 1}).encode("utf-8")
    req = urllib.request.Request(
        BASE_URL + "/images/generations",
        data=payload,
        headers={"Authorization": "Bearer " + API_KEY, "Content-Type": "application/json"},
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


def main() -> int:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    units = [u for u in UNITS if not only or u["fname"] == only]
    print("Output dir: " + OUTPUT_DIR)
    ok = 0
    for i, unit in enumerate(units):
        fpath = os.path.join(OUTPUT_DIR, unit["fname"] + ".png")
        print("[%d/%d] %s ..." % (i + 1, len(units), unit["display"]), flush=True)
        success, msg = generate_image(unit["prompt"], fpath)
        if not success:
            print("  FAILED: %s -- retry once" % msg, flush=True)
            time.sleep(3)
            success, msg = generate_image(unit["prompt"], fpath)
        print("  %s: %s" % ("OK" if success else "STILL FAIL", msg), flush=True)
        ok += 1 if success else 0
        time.sleep(1)
    print("\nTotal: %d/%d OK" % (ok, len(units)))
    return 0 if ok == len(units) else 1


if __name__ == "__main__":
    sys.exit(main())
