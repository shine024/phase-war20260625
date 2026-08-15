# -*- coding: utf-8 -*-
"""UI 资源图标生成：agnes-image-2.0-flash → 白底转透明 → 96px PNG → assets/ui/icons/"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
API_KEY = open(KEY_FILE, encoding="utf-8").read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"
OUT_RAW = os.path.join(ROOT, "assets", "ui", "icons", "_raw")
OUT_DIR = os.path.join(ROOT, "assets", "ui", "icons")
os.makedirs(OUT_RAW, exist_ok=True)

PREFIX = "单对象游戏UI资源图标，扁平矢量插画风，粗轮廓剪影，居中占画面70%，科幻霓虹风，纯白背景，无文字无水印无阴影无场景，"
NEGATIVE = "不要文字，不要边框，不要多对象，不要透视，不要照片写实。"

ICONS = [
    {"id": "res_nano",     "prompt": PREFIX + "一簇发光的青蓝色纳米材料晶体碎片，聚集的微粒云团轮廓，霓虹青色发光边缘" + NEGATIVE},
    {"id": "res_alloy",    "prompt": PREFIX + "两块堆叠的银灰色金属合金锭块，机械质感，蓝色高光棱线" + NEGATIVE},
    {"id": "res_crystal",  "prompt": PREFIX + "一颗紫色能量水晶原石，多面体切面，紫色霓虹内发光" + NEGATIVE},
    {"id": "res_energy",   "prompt": PREFIX + "一块橙色发光能量电池方块，充电格纹，橙色霓虹边缘" + NEGATIVE},
    {"id": "res_research", "prompt": PREFIX + "一支蓝色化学实验烧瓶与数据芯片组合，研究点数意象，蓝色霓虹" + NEGATIVE},
    {"id": "res_permit",   "prompt": PREFIX + "一张军事许可证证件卡片，卡片上有五角星徽记与条纹，金色调" + NEGATIVE},
    {"id": "res_lore",     "prompt": PREFIX + "一卷摊开的古老情报文献卷轴，纸张上有印章纹样，青紫色点缀" + NEGATIVE},
]

def generate(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = output_path + ".payload.json"
    open(tmp, "w", encoding="utf-8").write(payload)
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", output_path + ".resp.json", "--max-time", "120"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    os.unlink(tmp)
    if r.returncode != 0:
        return False, "curl exit " + str(r.returncode)
    content = open(output_path + ".resp.json", encoding="utf-8").read()
    os.unlink(output_path + ".resp.json")
    try:
        data = json.loads(content)
    except Exception:
        return False, "bad json: " + content[:150]
    if "data" not in data or not data["data"]:
        return False, "no data: " + content[:150]
    url = data["data"][0].get("url", "")
    if not url:
        return False, "no url"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, timeout=150)
    ok = os.path.exists(output_path) and os.path.getsize(output_path) > 1000
    return ok, "ok" if ok else "download failed"

def deploy(raw_path, out_path, size=96):
    from PIL import Image
    import numpy as np
    im = Image.open(raw_path).convert("RGB")
    arr = np.array(im, dtype=np.int16)
    brightness = arr.sum(axis=2) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    rgba = np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                      arr[:, :, 2].astype(np.uint8), alpha])
    im = Image.fromarray(rgba, "RGBA")
    # 裁到内容包围盒再等比缩放
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    im.thumbnail((size, size), Image.LANCZOS)
    im.save(out_path)
    return True

if __name__ == "__main__":
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for icon in ICONS:
        if only and icon["id"] != only:
            continue
        raw = os.path.join(OUT_RAW, icon["id"] + ".png")
        final = os.path.join(OUT_DIR, icon["id"] + ".png")
        if os.path.exists(final):
            print("skip (exists):", icon["id"])
            continue
        ok, msg = generate(icon["prompt"], raw)
        print("gen:", icon["id"], "->", msg)
        if ok:
            deploy(raw, final)
            print("deployed:", final)
