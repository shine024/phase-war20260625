#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v12 Phase B+C —— 爆炸帧序列 + 技能/大招 hero 贴图重生。

Phase B(爆炸,影响最广:火箭/导弹/高炮/欧米茄/电磁/激光 + tier 变体):
  explosion_conv_f0..f5   6 帧常规火球(由 3x2 sheet 切片,保证连贯)
  explosion_energy_f0..f5 6 帧能量爆炸(同上)
Phase C(技能/大招):
  inferno_hell / player_shield / player_rage / ult_nuke_player  单 sprite

改进提示词:体积感/电影感/高保真 + 黑底抠图。原件备份到对应 _backup_v12/。
爆炸帧降采样到 256x256(保持原尺寸,scale 不变)。

用法:
  python tools/regen_explosion_skill_textures_v12.py
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
GEN_SIZE = "1024x1024"

EXP_DIR = os.path.join(ROOT, "assets", "effects", "explosion_frames")
SPELL_DIR = os.path.join(ROOT, "assets", "effects", "spell_burst")
ULT_DIR = os.path.join(ROOT, "assets", "effects", "ultimate_projectiles")

# Phase B: 2 张 sheet(各 3x2 切 6 帧)
EXP_SHEETS = [
    {
        "id": "explosion_conv",
        "dir": EXP_DIR,
        "prompt": (
            "3 by 2 grid sprite sheet of a military high-explosive detonation, 6 sequential frames "
            "arranged left to right top to bottom showing progression from an initial blinding white "
            "flash to a peak volumetric fireball to dissipating dark smoke, each cell a distinct phase, "
            "volumetric orange-red fireball with yellow-white incandescent core, billowing turbulent "
            "dark gray smoke, flying debris embers, cinematic dramatic lighting, top-down aerial view, "
            "solid pure black background, no grid lines no labels, photorealistic high-fidelity"
        ),
        "rows": 2, "cols": 3, "frame_prefix": "explosion_conv_f", "count": 6, "cell_size": 256,
    },
    {
        "id": "explosion_energy",
        "dir": EXP_DIR,
        "prompt": (
            "3 by 2 grid sprite sheet of an energy weapon detonation, 6 sequential frames left to right "
            "top to bottom from initial bright flash to peak plasma sphere to dissipating energy, "
            "bright white-blue plasma explosion with crackling electric arcs, glowing energy discharge "
            "rim, volumetric, cinematic, top-down aerial view, solid pure black background, no grid lines "
            "no labels, photorealistic high-fidelity"
        ),
        "rows": 2, "cols": 3, "frame_prefix": "explosion_energy_f", "count": 6, "cell_size": 256,
    },
]

# Phase C: 单 sprite
SINGLES = [
    {
        "id": "inferno_hell", "dir": SPELL_DIR,
        "prompt": (
            "inferno hellfire spell burst, raging volumetric orange-red flames erupting radially outward "
            "from a bright yellow-white incandescent core, billowing fire and dark smoke, cinematic "
            "dramatic lighting, top-down view, perfectly centered, solid pure black background #000000, "
            "high contrast, photorealistic high-fidelity game VFX"
        ),
    },
    {
        "id": "player_shield", "dir": SPELL_DIR,
        "prompt": (
            "energy force field shield dome, bright cyan-blue translucent energy bubble with glowing "
            "hexagonal energy grid patterns, volumetric shimmering barrier, radiant glowing rim, "
            "cinematic, top-down view, perfectly centered, solid pure black background #000000, "
            "high contrast, photorealistic high-fidelity"
        ),
    },
    {
        "id": "player_rage", "dir": SPELL_DIR,
        "prompt": (
            "rage power aura burst, intense fiery red-orange energy explosion radiating outward, "
            "glowing hot power burst with crackling energy, volumetric, cinematic dramatic, top-down view, "
            "perfectly centered, solid pure black background #000000, high contrast, photorealistic high-fidelity"
        ),
    },
    {
        "id": "ult_nuke_player", "dir": ULT_DIR,
        "prompt": (
            "ultimate nuclear ballistic missile projectile, sleek detailed military rocket with bright "
            "white-orange glowing flame trail and hot exhaust plume, pointed nose, metallic body with "
            "markings, side view flying right, solid pure black background #000000, high contrast, "
            "photorealistic high-fidelity game sprite"
        ),
    },
]


def load_keys():
    if not os.path.exists(KEY_FILE):
        sys.exit("[FATAL] key 文件不存在: " + KEY_FILE)
    keys = [ln.strip() for ln in open(KEY_FILE, encoding="utf-8").read().splitlines() if ln.strip()]
    if not keys:
        sys.exit("[FATAL] " + KEY_FILE + " 为空")
    return keys


def mask(k):
    return k[:6] + "..." + k[-4:] if len(k) > 12 else k[:3] + "..." + k[-3:]


def call_api(prompt, key, out_path):
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
        return False, "非JSON"
    if "data" not in data or not data["data"]:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:120]) if isinstance(err, dict) else str(data)[:120]
        return False, "无data:" + str(msg)
    url = data["data"][0].get("url", "")
    b64 = data["data"][0].get("b64_json", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out_path, url, "--max-time", "150"],
                       capture_output=True, text=True, timeout=180)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 2000:
            return True, "OK(%dB)" % os.path.getsize(out_path)
        return False, "下载失败"
    if b64:
        import base64
        with open(out_path, "wb") as f:
            f.write(base64.b64decode(b64))
        if os.path.getsize(out_path) > 2000:
            return True, "OK(b64)"
    return False, "无url/b64"


def cutout_black_bg(path):
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


def slice_sheet_resize(sheet_path, rows, cols, prefix, count, out_dir, cell_size):
    """切 rows×cols 网格,每帧 resize 到 cell_size×cell_size 并抠图。"""
    from PIL import Image
    img = Image.open(sheet_path).convert("RGBA")
    w, h = img.size
    cw, ch = w // cols, h // rows
    n = 0
    for i in range(count):
        r, c = i // cols, i % cols
        cell = img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
        if cell.size != (cell_size, cell_size):
            cell = cell.resize((cell_size, cell_size), Image.LANCZOS)
        fp = os.path.join(out_dir, "%s%d.png" % (prefix, i))
        cell.save(fp)
        cutout_black_bg(fp)
        n += 1
    return n


def backup(paths):
    backed = 0
    for p in paths:
        d = os.path.dirname(p)
        bdir = os.path.join(d, "_backup_v12")
        os.makedirs(bdir, exist_ok=True)
        if os.path.exists(p):
            dst = os.path.join(bdir, os.path.basename(p))
            if not os.path.exists(dst):
                from PIL import Image
                Image.open(p).save(dst)
                backed += 1
    return backed


def main():
    from PIL import Image
    keys = load_keys()
    ki = 0

    # 备份
    bk = []
    for s in EXP_SHEETS:
        bk += [os.path.join(s["dir"], "%s%d.png" % (s["frame_prefix"], i)) for i in range(s["count"])]
        bk.append(os.path.join(s["dir"], s["id"] + "_sheet.png"))
    for s in SINGLES:
        bk.append(os.path.join(s["dir"], s["id"] + ".png"))
    print("备份 %d 张原件" % backup(bk))

    # Phase B: sheets
    for s in EXP_SHEETS:
        os.makedirs(s["dir"], exist_ok=True)
        sheet_path = os.path.join(s["dir"], s["id"] + "_sheet.png")
        ok = False
        for _ in range(3):
            key = keys[ki % len(keys)]; ki += 1
            print("[%s] key%s sheet..." % (s["id"], mask(key)), end=" ", flush=True)
            ok, msg = call_api(s["prompt"], key, sheet_path)
            print("OK" if ok else "FAIL " + msg)
            if ok: break
            time.sleep(2)
        if ok:
            n = slice_sheet_resize(sheet_path, s["rows"], s["cols"], s["frame_prefix"], s["count"], s["dir"], s["cell_size"])
            print("  切片 %d 帧 -> %s_f0..f%d (%dx%d)" % (n, s["frame_prefix"], n - 1, s["cell_size"], s["cell_size"]))
        else:
            print("  !! %s sheet 失败,保留旧帧" % s["id"])
        time.sleep(2)

    # Phase C: singles
    for s in SINGLES:
        os.makedirs(s["dir"], exist_ok=True)
        out = os.path.join(s["dir"], s["id"] + ".png")
        ok = False
        for _ in range(3):
            key = keys[ki % len(keys)]; ki += 1
            print("[%s] key%s..." % (s["id"], mask(key)), end=" ", flush=True)
            ok, msg = call_api(s["prompt"], key, out)
            print("OK" if ok else "FAIL " + msg)
            if ok: break
            time.sleep(2)
        if ok:
            pct = cutout_black_bg(out)
            im = Image.open(out).convert("RGBA")
            print("  抠图 %d%% 尺寸=%s" % (pct, im.size))
        else:
            print("  !! %s 失败,保留旧件" % s["id"])
        time.sleep(2)


if __name__ == "__main__":
    main()
