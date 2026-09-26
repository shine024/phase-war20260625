#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""记录4：传说/神话档改造图标徽章管线样张（用户指令"补齐上面的"）。

- 对象：传说 3（aa_06_laser / arm_04_aps / art_13_apfsds_sabot）+ 神话 3（全部 mythic）
- 模板=STYLE_BIBLE §6.4 基础锚段（与 tools/_tmp_b4_badge_regen_b3.py 同源逐字）+
  档位色语言：legendary=琥珀金勾线/光晕，mythic=猩红勾线/双层徽章框顶端感。
- **样张不部署**：输出 docs/徽章管线样张_传说神话_20260924/（1024 + 128 各一份，
  附当前线上图标副本供并排审美裁决）。裁决通过后再走 _tmp_gen_modicon_full 部署链。
"""
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    KEYS = [k.strip() for k in f.read().splitlines() if k.strip()]
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "docs", "徽章管线样张_传说神话_20260924")
ICON_DIR = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
os.makedirs(OUT_DIR, exist_ok=True)

ANCHOR = ("科幻策略游戏装备徽章图标，单一主体居中，对称纹章构图，"
          "深空黑到深灰蓝的深底径向渐变，"
          "霓虹发光勾线与能量光晕，正方形徽章构图，主体完整居中，无文字无水印无logo")
LEG_TIER = "徽章整体以琥珀金为主色调，金色能量勾线与琥珀色光晕，传说级华贵质感"
MYTH_TIER = ("徽章整体以猩红为主色调，红色能量勾线与绯红光晕，"
             "外围再套一圈红色环形徽章框形成双层徽章，神话级顶端威压感")

JOBS = [
    ("aa_06_laser", "legendary", "主体是一座激光近防阵列：中央一枚旋转的 emitter 透镜，"
     "数道金色激光束呈扇形交汇于镜前焦点，" + LEG_TIER + "。text, frame"),
    ("arm_04_aps", "legendary", "主体是一套主动防护系统：坦克炮塔顶部相控阵盒子"
     "向侧前方弹出一枚拦截弹，拦截弹拖出金色弧线拦截轨迹，" + LEG_TIER + "。text, frame"),
    ("art_13_apfsds_sabot", "legendary", "主体是一枚尾翼稳定脱壳穿甲弹：细长弹杆高速向左飞行，"
     "弹托瓣刚分离飞散在弹体后侧，弹体拉出金色速度线，" + LEG_TIER + "。text, frame"),
    ("gen_21_vanguard_repair", "mythic", "主体是一台悬浮的先锋维修矩阵：环形阵列臂展开，"
     "中心 Nanomechanical 修复光束向下洒落，机械碎块被光束重构，" + MYTH_TIER + "。text, frame"),
    ("gen_22_aegis_protocol", "mythic", "主体是一面神盾协议力场：六边形蜂窝能量盾面完全展开，"
     "盾面中心一枚红色纹章核心发光，" + MYTH_TIER + "。text, frame"),
    ("gen_23_singularity_core", "mythic", "主体是一颗奇点核心：黑洞式吸积环旋转，"
     "吸入的光粒沿环面呈猩红螺旋坠入核心，核心白炽，" + MYTH_TIER + "。text, frame"),
]


def gen_one(api_key, prompt, out1024):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = out1024 + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = out1024 + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + api_key,
           "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200, encoding="utf-8")
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if r.returncode != 0 or not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return None, "curl failed"
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return None, "not JSON"
    url = None
    if isinstance(data, dict):
        d = data.get("data") or []
        if d and isinstance(d[0], dict):
            url = d[0].get("url")
    if not url:
        return None, "no url: " + content[:100]
    img_file = out1024 + ".img.bin"
    rc = subprocess.run(["curl", "-s", "-L", url, "-o", img_file, "--max-time", "120"],
                        capture_output=True, text=True)
    if rc.returncode != 0 or not os.path.exists(img_file) or os.path.getsize(img_file) < 1000:
        return None, "download failed"
    try:
        im = Image.open(img_file)
        im.load()
    except Exception as e:
        try:
            os.unlink(img_file)
        except OSError:
            pass
        return None, "not image: " + str(e)
    im.convert("RGBA").save(out1024)
    try:
        os.unlink(img_file)
    except OSError:
        pass
    return True, "ok"


def main():
    ki = 0
    for mod_id, tier, prompt in JOBS:
        out1024 = os.path.join(OUT_DIR, mod_id + "_badge_1024.png")
        if os.path.exists(out1024):
            print("SAMPLE skip(已有)", mod_id)
            continue
        ok, msg = False, ""
        for attempt in range(6):
            key = KEYS[ki % len(KEYS)]
            ki += 1
            ok, msg = gen_one(key, prompt, out1024)
            if ok:
                break
            print("SAMPLE retry", mod_id, "attempt", attempt + 1, msg)
            time.sleep(31)
        if ok:
            im = Image.open(out1024)
            im.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT_DIR, mod_id + "_badge_128.png"))
            cur = os.path.join(ICON_DIR, mod_id + ".png")
            if os.path.exists(cur):
                shutil.copy2(cur, os.path.join(OUT_DIR, mod_id + "_current.png"))
            print("SAMPLE ok", mod_id)
        else:
            print("SAMPLE FAIL", mod_id, msg)
        time.sleep(20)  # 限流礼貌间隔
    print("SAMPLES_DONE")


if __name__ == "__main__":
    main()
