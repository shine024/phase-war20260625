#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④ 批 3：徽章真废 5 张重生成（2026-09-09）。

清单（资产分档审计 §相位仪徽章；真废=媒介/纹章语言脱节疑素材混入）：
  pi_helix_04    高饱翠绿+方形框+5脑多主体 → 青绿+圆形框+单核心（6.4+helix 族色）
  pi_generic_07  水印+腕表斜置+乱码       → generic 族刻度环纹章（对照 pi_generic_01 金橙环+冰蓝芯）
  pi_r_overload  灰度拟物警示三角         → 过载反应堆核（128 传奇小图）
  pi_r_shield    灰度盾+黑字+棋盘格痕     → 层叠能量护盾（128）
  pi_hp          灰度空心爱心             → 医疗十字×生命波纹（128）

模板=STYLE_BIBLE §6.4 基础锚段（中文逐字）+族先例氛围（生成前对照 pi_helix_01/
pi_generic_01 实图）+域先例尾句「无文字无水印无logo」+结构性负面 text, frame。
生成 1024×1024 → r_*/pi_hp 缩 128（对齐现尺寸）→ 备份原图 → 部署。
"""
import json
import os
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "docs", "待生成徽章_批3")
ASSETS = os.path.join(ROOT, "assets", "ui", "instruments")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"

ANCHOR = ("科幻策略游戏装备徽章图标，单一主体居中，对称纹章构图，"
          "深空黑到深灰蓝的深底径向渐变，"
          "霓虹发光勾线与能量光晕，正方形徽章构图，主体完整居中，无文字无水印无logo")

JOBS = [
    ("pi_helix_04", 1024,
     ANCHOR + "主体是一颗悬浮的半透明青绿色晶体神经核心，两条螺旋神经束对称环绕核心旋转，"
              "外围一圈青绿色发光圆形徽章框，体现『幻影分身』的侦察科技感。text, frame"),
    ("pi_generic_07", 1024,
     ANCHOR + "主体是一座精密的六边形合金能量核心，中心一颗冰蓝色冷光芯，"
              "外围两圈金属精密刻度环，外环泛暖金金属光泽、内圈冰蓝冷光，与系列表盘徽章同语言。text, frame"),
    ("pi_r_overload", 128,
     ANCHOR + "主体是一颗过载的反应堆能量核心，橙红色电弧沿环形导轨迸发，核心白炽过载光。text, frame"),
    ("pi_r_shield", 128,
     ANCHOR + "主体是一面层叠的能量护盾，冰蓝色六边形力场纹发光，盾面双层投影前后错叠。text, frame"),
    ("pi_hp", 128,
     ANCHOR + "主体是一枚医疗十字与生命体征波纹融合的能量徽记，青绿色生命光晕。text, frame"),
]


def generate_image(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY,
           "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200, encoding="utf-8")
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if r.returncode != 0 or not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "curl/response failed"
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "not JSON: " + content[:120]
    url = None
    if isinstance(data.get("data"), list) and data["data"]:
        url = data["data"][0].get("url")
    if not url:
        return False, "no url: " + content[:120]
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"]
    d = subprocess.run(dl, capture_output=True, timeout=200)
    if d.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) < 30000:
        return False, "download failed"
    return True, "ok"


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)
    failed = []
    for fname, out_size, prompt in JOBS:
        raw = os.path.join(OUT_DIR, fname + "_raw.png")
        if not (os.path.exists(raw) and os.path.getsize(raw) > 30000):
            print("-- generate", fname, flush=True)
            ok, msg = generate_image(prompt, raw)
            if not ok:
                print("   FAIL:", msg, flush=True)
                failed.append(fname)
                continue
            time.sleep(2)
        # 备份原图
        orig = os.path.join(ASSETS, fname + ".png")
        if os.path.exists(orig):
            bdst = os.path.join(BACKUP_DIR, fname + "-preB3-2026-09-09.png")
            if not os.path.exists(bdst):
                with open(orig, "rb") as fi, open(bdst, "wb") as fo:
                    fo.write(fi.read())
        # 部署（对齐原尺寸；r_*/pi_hp 为 128 传奇小图）
        im = Image.open(raw).convert("RGB")
        if im.size != (out_size, out_size):
            im = im.resize((out_size, out_size), Image.LANCZOS)
        im.convert("RGBA").save(orig, "PNG")
        print("   deployed:", fname, "->", (out_size, out_size), flush=True)
    print("[SUMMARY] failed:", failed if failed else "none")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
