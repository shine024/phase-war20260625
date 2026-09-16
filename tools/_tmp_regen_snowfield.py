# -*- coding: utf-8 -*-
"""v36 B3：重生成开场醒来雪原图（wakeup_snowfield.png），车辆对齐基地车外景。

FLOW 站点 2026-09-16 连接超时不可达 → 兜底走 agnes-image（1152x768，aspect-fill 裁 1280x720）。
prompt 按 _agnes_image_api.md 实测纪律：正面意象锁死（车=truck_tier1 的特征清单）、
无负面词、屏幕级构图描述。原图备份 _art_backup/。产出先落 .godot/ 供人工过目，不直接覆盖。
"""
from PIL import Image
import json
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, ".godot", "art_regen")
os.makedirs(OUT_DIR, exist_ok=True)

API_KEY = open(KEY_FILE).read().strip()

PROMPT = (
    "电影感宽幅概念插画，冷雪原晨光，天空飘雪。"
    "画面中景偏左停放一辆方正硬朗的军用六轮装甲卡车，侧面视角略朝右："
    "棱角分明的装甲驾驶舱在车头，橄榄绿军规涂装，车顶纵排行李架与备胎，"
    "车身侧面有一条青色能量发光饰条，六个大尺寸越野轮胎，车尾是封闭式装甲车厢。"
    "车辆在雪地上留下深深车辙，排气管有淡淡废气白雾。"
    "远景天边地平线上矗立一座巨大的漆黑方尖巨门，剪影感，吞掉周围光线。"
    "地平线处有低垂的云层与淡金色晨光，整体冷蓝灰色调，"
    "电影构图，留白呼吸感，无人物，无文字，高清细节。"
)


def generate(prompt: str, output_path: str, size: str = "1152x768") -> tuple[bool, str]:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)
    hdr = "Authorization: Bearer " + API_KEY
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", BASE_URL + "/images/generations",
        "-H", hdr, "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file, "--max-time", "120",
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
    content = open(resp_file).read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Not JSON: " + content[:150]
    if "data" not in data or not data["data"]:
        err = data.get("error", {})
        return False, "No data: " + str(err.get("message", data))[:150]
    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK"
    return False, "Download failed"


def aspect_fill(src_path: str, out_path: str, w: int = 1280, h: int = 720) -> None:
    im = Image.open(src_path).convert("RGB")
    sw, sh = im.size
    k = max(w / sw, h / sh)
    im = im.resize((max(w, int(sw * k + 0.5)), max(h, int(sh * k + 0.5))), Image.LANCZOS)
    x0 = (im.width - w) // 2
    y0 = (im.height - h) // 2
    im.crop((x0, y0, x0 + w, y0 + h)).save(out_path)


if __name__ == "__main__":
    ok_count = 0
    for i in range(1, 4):   # 三轮：按计划兜底纪律，出图供人工挑选/过目
        raw = os.path.join(OUT_DIR, "snowfield_raw_%d.png" % i)
        final = os.path.join(OUT_DIR, "snowfield_%d_1280x720.png" % i)
        if os.path.exists(final):
            print("skip", final)
            ok_count += 1
            continue
        ok, msg = generate(PROMPT, raw)
        if not ok:
            print("gen %d FAIL:" % i, msg)
            continue
        aspect_fill(raw, final)
        print("gen %d OK ->" % i, final)
        ok_count += 1
    print("done, ok =", ok_count)
