#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v12 核爆 hero 贴图重生 —— 改进提示词(体积感/电影感/高保真)+ 黑底抠图。

Phase 2A: 重生 4 张核波单 sprite + 9 帧蘑菇云生长序列(由 1 张 3x3 sheet 切片,
保证 9 帧连贯,而非各自独立的跳动 AI 帧)。

输出(覆盖 assets/effects/nuclear/,原件备份到 _backup_v12/):
  nuke_fireball.png   1024  体积感白热火球(ADD 混合)
  nuke_mushroom.png   1024  高耸蘑菇云单 sprite(备用/单 sprite 路径)
  nuke_shockwave.png  1024  扩散冲击波环(ADD)
  nuke_burn.png       1024  焦土弹坑(地面贴花)
  nuke_mushroom_f0..f8.png  341  3x3 sheet 切片的 9 帧生长动画

用法:
  python tools/regen_nuclear_textures_v12.py           # 全部
  python tools/regen_nuclear_textures_v12.py --only fireball,mushroom_sheet
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "assets", "effects", "nuclear")
BACKUP_DIR = os.path.join(OUT_DIR, "_backup_v12")

GEN_SIZE = "1024x1024"

SINGLES = [
    {
        "id": "nuke_fireball",
        "prompt": (
            "catastrophic nuclear detonation fireball, blinding incandescent white-hot core, "
            "searing yellow-white plasma sphere with volumetric 3D depth, turbulent billowing "
            "orange-red flames rolling outward in layered volumetric clouds, intense radiant glow, "
            "cinematic dramatic lighting, photorealistic high-fidelity, top-down aerial view, "
            "perfectly centered, solid pure black background #000000, high contrast, "
            "volumetric smoke and fire, no ground no horizon"
        ),
    },
    {
        "id": "nuke_mushroom",
        "prompt": (
            "towering nuclear mushroom cloud, thick volumetric gray smoke stem rising into a wide "
            "billowing turbulent cap, swirling smoke with deep 3D volume, dramatic cinematic lighting, "
            "bright glowing hot orange core at the base fading upward to dense dark gray smoke, "
            "photorealistic high-fidelity, top-down aerial view, perfectly centered, "
            "solid pure black background #000000, high contrast, dense realistic smoke"
        ),
    },
    {
        "id": "nuke_shockwave",
        "prompt": (
            "expanding circular blast shockwave ring seen from above, bright white-yellow pressurized "
            "energy wall, volumetric dust and debris ring blasting radially outward, sharp glowing rim "
            "with turbulent trailing edge, cinematic, photorealistic, top-down aerial view, perfectly "
            "centered, solid pure black background #000000, high contrast, single clean expanding ring"
        ),
    },
    {
        "id": "nuke_burn",
        "prompt": (
            "scorched earth nuclear blast crater, charred black ground with glowing orange-red hot "
            "embers around the rim, ash and soot texture, cracked scorched earth, top-down flat decal "
            "view, perfectly centered, solid pure black background #000000, high contrast, "
            "realistic charred ground texture"
        ),
    },
]

SHEET = {
    "id": "nuke_mushroom_sheet_growth",
    "prompt": (
        "3 by 3 grid sprite sheet showing a nuclear mushroom cloud growing over 9 sequential stages, "
        "arranged left to right top to bottom, progressing from a small bright ground-level fireball "
        "in the first cell to a towering full mushroom cloud with thick stem and wide billowing cap "
        "in the last cell, each of the 9 cells a distinct growth stage, consistent cinematic art style, "
        "volumetric gray smoke with 3D depth, top-down aerial view, solid pure black background, "
        "no grid lines no labels no borders, photorealistic high-fidelity, dense realistic smoke"
    ),
    "slice": (3, 3),  # 切成 3x3 = 9 帧
    "frame_prefix": "nuke_mushroom_f",
    "frame_count": 9,
}


def load_keys():
    if not os.path.exists(KEY_FILE):
        sys.exit("[FATAL] key 文件不存在: " + KEY_FILE)
    keys = [ln.strip() for ln in open(KEY_FILE, encoding="utf-8").read().splitlines() if ln.strip()]
    if not keys:
        sys.exit("[FATAL] " + KEY_FILE + " 为空")
    return keys


def mask(k):
    return k[:6] + "..." + k[-4:] if len(k) > 12 else k[:3] + "..." + k[-3:]


def call_api(prompt, key, out_path, retries=2):
    """生成单张。成功返回 True。轮换 key 重试。"""
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": GEN_SIZE, "n": 1})
    tmp = out_path + ".payload.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    resp = out_path + ".resp.json"
    try:
        cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
               "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
               "--data-binary", "@" + tmp, "-o", resp, "--max-time", "150"]
        subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    finally:
        try: os.unlink(tmp)
        except OSError: pass
    if not os.path.exists(resp) or os.path.getsize(resp) < 10:
        return False, "无响应"
    content = open(resp, encoding="utf-8", errors="replace").read()
    try: os.unlink(resp)
    except OSError: pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "非JSON: " + content[:120]
    if "data" not in data or not data["data"]:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:120]) if isinstance(err, dict) else str(data)[:120]
        return False, "无data: " + str(msg)
    url = data["data"][0].get("url", "")
    b64 = data["data"][0].get("b64_json", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out_path, url, "--max-time", "150"],
                       capture_output=True, text=True, timeout=180)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 2000:
            return True, "OK(url,%dB)" % os.path.getsize(out_path)
        return False, "下载失败"
    if b64:
        import base64
        with open(out_path, "wb") as f:
            f.write(base64.b64decode(b64))
        if os.path.getsize(out_path) > 2000:
            return True, "OK(b64)"
    return False, "无url/b64"


def cutout_black_bg(path):
    """黑底阈值抠图:亮度<20 全透,20-50 羽化。返回去背景占比。"""
    from PIL import Image
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    removed = 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            b = (p[0] + p[1] + p[2]) // 3
            if b < 20:
                px[x, y] = (p[0], p[1], p[2], 0)
                removed += 1
            elif b < 50:
                px[x, y] = (p[0], p[1], p[2], int(255 * (b - 20) / 30))
    img.save(path)
    return removed * 100 // (w * h)


def slice_sheet(sheet_path, rows, cols, prefix, count, out_dir):
    """把 sheet 切成 count 帧(prefix_f0..fN),每帧单独抠图。"""
    from PIL import Image
    img = Image.open(sheet_path).convert("RGBA")
    w, h = img.size
    cw, ch = w // cols, h // rows
    sliced = 0
    for i in range(count):
        r, c = i // cols, i % cols
        cell = img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
        fp = os.path.join(out_dir, "%s%d.png" % (prefix, i))
        cell.save(fp)
        cutout_black_bg(fp)
        sliced += 1
    return sliced, (cw, ch)


def backup(names):
    os.makedirs(BACKUP_DIR, exist_ok=True)
    backed = 0
    for n in names:
        src = os.path.join(OUT_DIR, n + ".png")
        if os.path.exists(src):
            dst = os.path.join(BACKUP_DIR, n + ".png")
            if not os.path.exists(dst):
                Image_save(src, dst)
                backed += 1
    return backed


def Image_save(src, dst):
    from PIL import Image
    Image.open(src).save(dst)


def main():
    from PIL import Image
    os.makedirs(OUT_DIR, exist_ok=True)
    keys = load_keys()
    only = ""
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = a[len("--only="):].lower()
    only_set = set(filter(None, only.split(",")))

    # 备份原件
    bk_names = [s["id"] for s in SINGLES] + [SHEET["id"]] + \
               ["%s%d" % (SHEET["frame_prefix"], i) for i in range(SHEET["frame_count"])]
    nb = backup(bk_names)
    print("备份 %d 张原件 -> %s" % (nb, BACKUP_DIR))

    ki = 0  # key 轮换指针(跨所有生成连续轮换)

    # --- 单 sprite ---
    for tex in SINGLES:
        if only_set and tex["id"] not in only_set:
            continue
        out = os.path.join(OUT_DIR, tex["id"] + ".png")
        ok = False
        for attempt in range(3):
            key = keys[ki % len(keys)]; ki += 1
            print("[%s] key%s 生成..." % (tex["id"], mask(key)), end=" ", flush=True)
            ok, msg = call_api(tex["prompt"], key, out)
            print("OK" if ok else "FAIL " + msg)
            if ok:
                break
            time.sleep(2)
        if ok:
            pct = cutout_black_bg(out)
            # 自检
            im = Image.open(out).convert("RGBA")
            print("  抠图去背景 %d%%  尺寸=%s" % (pct, im.size))
        else:
            print("  !! %s 生成失败 3 次,跳过(保留旧件)" % tex["id"])
        time.sleep(2)

    # --- 蘑菇云 9 帧 sheet 切片 ---
    if not only_set or SHEET["id"] in only_set or "mushroom_sheet" in only_set:
        sheet_path = os.path.join(OUT_DIR, SHEET["id"] + ".png")
        ok = False
        for attempt in range(3):
            key = keys[ki % len(keys)]; ki += 1
            print("[%s] key%s 生成 growth sheet..." % (SHEET["id"], mask(key)), end=" ", flush=True)
            ok, msg = call_api(SHEET["prompt"], key, sheet_path)
            print("OK" if ok else "FAIL " + msg)
            if ok:
                break
            time.sleep(2)
        if ok:
            rows, cols = SHEET["slice"]
            n, cell = slice_sheet(sheet_path, rows, cols, SHEET["frame_prefix"], SHEET["frame_count"], OUT_DIR)
            print("  切片 %d 帧 (%dx%d) -> %s_f0..f%d.png" % (n, cell[0], cell[1], SHEET["frame_prefix"], n - 1))
        else:
            print("  !! mushroom sheet 生成失败,9 帧保留旧件")


if __name__ == "__main__":
    main()
