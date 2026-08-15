#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
重生成 19 张实心底改造图标（白底管线 → 透明，与其余 66 张风格统一）。
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_KEY = open(os.path.join(ROOT, "tools", "_api_key.txt"), encoding="utf-8").read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"
D = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
RAW = os.path.join(D, "_solid_raw")
os.makedirs(RAW, exist_ok=True)

P = "单个军事科技部件图标，扁平矢量插画，粗轮廓剪影，居中占画面65%，霓虹青蓝科幻风配少量橙色点缀，" \
    "纯白背景，无文字无水印无阴影无场景，"
N = "不要文字，不要边框，不要多对象，不要透视，不要照片写实。"

UNITS = [
    {"f": "mod_aerodynamics",     "p": P + "流线型气动套件与导流翼片组件" + N},
    {"f": "mod_armor",            "p": P + "多层复合装甲板块与倾斜附加装甲" + N},
    {"f": "mod_automation",       "p": P + "工业自动化机械臂与传动齿轮组" + N},
    {"f": "mod_countermeasure",   "p": P + "烟幕弹发射器阵列对抗措施吊舱" + N},
    {"f": "mod_drone",            "p": P + "四旋翼侦察无人机" + N},
    {"f": "mod_engine",           "p": P + "燃气轮机发动机与排气管组件" + N},
    {"f": "mod_environment",      "p": P + "环境适应系统过滤罐与散热鳍片" + N},
    {"f": "mod_fire_control",     "p": P + "火控计算机机柜与电路板模块" + N},
    {"f": "mod_fortification",    "p": P + "装配式防御工事掩体板与沙袋" + N},
    {"f": "mod_fuze",             "p": P + "可编程电子引信与压电元件" + N},
    {"f": "mod_laser",            "p": P + "激光发射器与聚焦透镜阵列" + N},
    {"f": "mod_mobility",         "p": P + "强化履带与负重轮行走机构" + N},
    {"f": "mod_obstacle",         "p": P + "反坦克拒桩与铁丝网障碍物" + N},
    {"f": "mod_optics",           "p": P + "光学瞄准镜与物镜组" + N},
    {"f": "mod_protection",       "p": P + "球形防护力场发生器与辐射环" + N},
    {"f": "mod_recovery",         "p": P + "回收打捞机械爪与缆线绞盘" + N},
    {"f": "mod_shield",           "p": P + "六边形能量护盾发生器与光弧" + N},
    {"f": "mod_shield_reactive",  "p": P + "爆炸反应装甲块与触发阵列" + N},
    {"f": "mod_weapon_air",       "p": P + "航空机炮吊舱与挂架" + N},
]


def generate(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = output_path + ".payload.json"
    open(tmp, "w", encoding="utf-8").write(payload)
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", output_path + ".resp.json", "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200)
    os.unlink(tmp)
    if r.returncode != 0:
        return False, "curl exit " + str(r.returncode)
    content = open(output_path + ".resp.json", encoding="utf-8").read()
    os.unlink(output_path + ".resp.json")
    try:
        data = json.loads(content)
    except Exception:
        return False, "bad json"
    url = (data.get("data") or [{}])[0].get("url", "")
    if not url:
        return False, "no url: " + content[:120]
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"],
                   capture_output=True, timeout=200)
    return os.path.exists(output_path) and os.path.getsize(output_path) > 1000, "ok"


def deploy(raw_path, out_path):
    from PIL import Image
    import numpy as np
    arr = np.array(Image.open(raw_path).convert("RGB"), dtype=np.int16)
    brightness = arr.sum(axis=2) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                                     arr[:, :, 2].astype(np.uint8), alpha]), "RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(512 / w, 512 / h) * 0.84
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(img, ((512 - nw) // 2, (512 - nh) // 2), img)
    canvas.save(out_path)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    ok = fail = 0
    for u in UNITS:
        f = u["f"]
        if only and f != only:
            continue
        raw = os.path.join(RAW, f + ".png")
        out = os.path.join(D, f + ".png")
        if not (os.path.exists(raw) and os.path.getsize(raw) > 1000):
            good, msg = generate(u["p"], raw)
            print("gen:", f, "->", msg)
            if not good:
                fail += 1
                continue
        deploy(raw, out)
        print("deploy:", f)
        ok += 1
    print(f"\nDone: {ok} ok, {fail} fail")


if __name__ == "__main__":
    main()
