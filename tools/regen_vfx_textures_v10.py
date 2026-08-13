#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Phase D v10: VFX 粒子贴图 AI 重生(按真实度报告建议)
================================================
现有贴图(spark_metal/heavy/energy, muzzle_light/heavy, smoke_generic)经视觉模型分析:
软晕、缺热色梯度(白热核→黄→橙→暗红)、缺金属高光。本脚本用改进提示词重生,
1024 生图 → Lanczos+UnsharpMask 降采样到原尺寸 → 黑底阈值抠图 → 覆盖原文件。

保持原像素尺寸(32 或 64)→ CPUParticles2D 的 scale 调参零改动(零风险)。
原件自动备份到 particle_textures_backup_v10/。

用法:
  python tools/regen_vfx_textures_v10.py             # 全部 6 张
  python tools/regen_vfx_textures_v10.py spark_metal  # 只生指定
"""
import base64
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")
BACKUP_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures_backup_v10")
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"

# (name, 目标像素, 提示词) — 强调热色梯度/锐利边缘/金属质感/高对比(报告建议)
TEXTURES = [
    ("spark_metal", 32,
     "single ultra-thin elongated metal spark streak, horizontal fiery line, "
     "very sharp crisp edges NOT soft, white-hot bright tip on the right fading to bright yellow then orange then dark red tail, "
     "strong thermal temperature gradient, glowing hot, like a real bullet impact spark, high contrast, "
     "top-down game VFX sprite, perfectly centered, solid pure black background #000000, no background, sharp not blurry"),
    ("spark_heavy", 32,
     "single irregular jagged metal shrapnel fragment with sharp angular edges and barbs, "
     "molten glowing metal, strong thermal gradient white-hot yellow core to orange to dark red cooled edges, "
     "metallic highlights and molten flow traces, oxidation mottle, like real exploded hot debris, high contrast, "
     "top-down game VFX sprite, perfectly centered, solid pure black background #000000, no background, sharp crisp edges"),
    ("spark_energy", 32,
     "single bright blue-white plasma energy bolt, sharp jagged lightning shape with crisp electric arcs, "
     "white-hot bright core fading to cyan-blue glow edges, crackling electricity, intense glow, high contrast, "
     "top-down game VFX sprite, perfectly centered, solid pure black background #000000, no background, sharp not blurry"),
    ("muzzle_light", 32,
     "small firearm muzzle flash, sharp bright star-burst flash with crisp pointed tongues of flame, "
     "white-hot intense core fading to bright yellow then orange then dark red smoke edge, strong thermal gradient, "
     "compact and punchy, high contrast, top-down game VFX sprite, perfectly centered, "
     "solid pure black background #000000, no background, sharp crisp edges"),
    ("muzzle_heavy", 64,
     "large heavy cannon muzzle blast, big sharp fireball with crisp flame tongues radiating outward, "
     "white-hot blinding core fading to bright yellow to orange to dark red, thick smoke ring at edge, "
     "strong thermal gradient, intense and powerful, high contrast, top-down game VFX sprite, perfectly centered, "
     "solid pure black background #000000, no background, sharp crisp edges"),
    ("smoke_generic", 64,
     "single dense volumetric gray smoke puff cloud, soft puffy billowing shape with darker edges and lighter core, "
     "realistic turbulent smoke wisps, neutral gray gradient, semi-translucent cloudy texture, high contrast with black, "
     "top-down game VFX sprite, perfectly centered, solid pure black background #000000, no background"),
]

THRESHOLD = 18
FEATHER = 32


def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]


def call_api(prompt, key):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1}).encode()
    req = urllib.request.Request(BASE_URL + "/images/generations", data=payload, headers={
        "Authorization": "Bearer " + key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=150) as r:
        data = json.loads(r.read().decode())
    item = data["data"][0]
    if item.get("b64_json"):
        return base64.b64decode(item["b64_json"])
    url = item.get("url", "")
    if not url:
        raise RuntimeError("no image in response")
    with urllib.request.urlopen(url, timeout=150) as r:
        return r.read()


def process(raw_bytes, target_px, out_path):
    """1024 → 降采样到 target_px(Lanczos+锐化) → 黑底抠图 → 保存。"""
    import io
    img = Image.open(io.BytesIO(raw_bytes)).convert("RGBA")
    # 降采样(高质量)+ 锐化(补偿小尺寸的模糊)
    img = img.resize((target_px, target_px), Image.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=1, percent=120, threshold=2))
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            b = (p[0] + p[1] + p[2]) // 3
            if b < THRESHOLD:
                px[x, y] = (p[0], p[1], p[2], 0)
            elif b < THRESHOLD + FEATHER:
                px[x, y] = (p[0], p[1], p[2], int(255 * (b - THRESHOLD) / FEATHER))
    img.save(out_path)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    keys = load_keys()
    os.makedirs(BACKUP_DIR, exist_ok=True)
    targets = [(n, s, p) for (n, s, p) in TEXTURES if not only or n == only]
    print(f"重生 {len(targets)} 张贴图 (model={MODEL}), 备份→{os.path.basename(BACKUP_DIR)}")
    ok = 0
    for i, (name, size, prompt) in enumerate(targets):
        out = os.path.join(TEX_DIR, name + ".png")
        # 备份原件(仅首次)
        bak = os.path.join(BACKUP_DIR, name + ".png")
        if os.path.exists(out) and not os.path.exists(bak):
            shutil.copy2(out, bak)
        print(f"[{i+1}/{len(targets)}] {name} ({size}px) ...", end=" ", flush=True)
        success = False
        for attempt, key in enumerate(keys * 2):
            try:
                raw = call_api(prompt, key)
                process(raw, size, out)
                print(f"OK ({os.path.getsize(out)}B)")
                success = True
                break
            except Exception as e:
                last = f"{type(e).__name__}: {e}"
                if attempt >= len(keys):
                    break
                time.sleep(2)
        if not success:
            print(f"FAIL ({last})")
        else:
            ok += 1
        if i < len(targets) - 1:
            time.sleep(2)
    print(f"\n完成: {ok}/{len(targets)}")
    print("后续: 1) 肉眼/analyze_image 审查新贴图  2) Godot reload_filesystem  3) 重跑 vfx_showcase + review 对比")
    print("回滚: 从 particle_textures_backup_v10/ 复制回原文件")


if __name__ == "__main__":
    main()
