#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v20.22: 生成轻动能(0/4)白热火花粒子贴图（spark_burst_white）。

病根（2026-08-27 像素取证）：现有 spark_drop 内容均色 (160,86,50)、impact_metal
(223,182,123)——贴图蓝通道是硬上限，modulate/ramp 都乘不回白热，f00/f04 命中
white=0，违族规格"放射状黄白小火花"。本脚本用 agnes-image-2.0-flash 生成
"黑底白热放射火花"候选 ×3，PIL 自动评审（白色占比/内容占比/各向同性）选优，
黑→alpha 反乘转透明底，缩至 128×128 部署到 assets/effects/particle_textures/。

沙箱注意：DSH 禁外部程序捕获管道（subprocess capture_output 会 EPERM），
全部 curl 用 -o 落盘、stderr 直通控制台。
"""
import json
import math
import os
import sys
import time
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    # v20.22-fix: 文件里有多行 key（3 个），取第一个非空行（review_vfx_realism 同范式）
    API_KEY = next(ln.strip() for ln in f if ln.strip())
# v20.22: 用 .cn 域名——.com 证书已过期（curl exit 35 实锤；review_vfx_realism.py
# 注释同佐证".cn 可用; .com 证书过期"）。评审基建 72 格调用全走 .cn，urllib 通道已验证。
BASE_URL = "https://apihub.agnes-ai.cn"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "docs", "待生成火花贴图_v20.22")
DEPLOY_PATH = os.path.join(ROOT, "assets", "effects", "particle_textures", "spark_burst_white.png")

PROMPT = (
    "游戏特效粒子贴图素材，纯黑色背景，单一主体居中：一个白炽过曝的圆形光核，"
    "从光核向四周 360 度均匀放射 12-16 条细长的火花线条，火花由中心白热色渐变到"
    "亮黄色再到暖橙色末梢，各条火花长短略有变化但角度均匀分布，中心有强烈的白色"
    "光晕，形态锐利利落像金属撞击迸溅的火花，正方形构图，主体占画面约七成，"
    "无文字无水印无边框无场景。"
)
NEGATIVE = "不要：文字、水印、边框、背景场景、多主体、人物、透视、暗色主体。"


def generate_one(idx: int) -> str:
    out = os.path.join(OUT_DIR, f"candidate_{idx}.png")
    payload = json.dumps({"model": MODEL, "prompt": PROMPT + NEGATIVE,
                          "size": "1024x1024", "n": 1}).encode()
    req = urllib.request.Request(
        BASE_URL + "/v1/images/generations", data=payload,
        headers={"Authorization": "Bearer " + API_KEY,
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read().decode())
    except Exception as e:
        print(f"   ✗ candidate_{idx}: API 失败 {e}", flush=True)
        return ""
    url = None
    if isinstance(data.get("data"), list) and data["data"]:
        item = data["data"][0]
        url = item.get("url")
        if not url and item.get("b64_json"):
            import base64
            with open(out, "wb") as f:
                f.write(base64.b64decode(item["b64_json"]))
            print(f"   ✓ candidate_{idx}.png (b64, {os.path.getsize(out)} bytes)", flush=True)
            return out
    if not url:
        print(f"   ✗ candidate_{idx}: 无 url: {json.dumps(data)[:200]}", flush=True)
        return ""
    try:
        with urllib.request.urlopen(url, timeout=120) as r:
            img = r.read()
        with open(out, "wb") as f:
            f.write(img)
    except Exception as e:
        print(f"   ✗ candidate_{idx}: 下载失败 {e}", flush=True)
        return ""
    print(f"   ✓ candidate_{idx}.png ({len(img)} bytes)", flush=True)
    return out


def score_candidate(path: str) -> dict:
    """黑底图评审：亮度>60 为前景。白色占比越高越好，各向同性越好越好。"""
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    lum = a.max(axis=2)
    fg = lum > 60
    if fg.sum() < 100:
        return {"ok": False, "why": "前景过少"}
    h, w = lum.shape
    ys, xs = np.where(fg)
    cx, cy = xs.mean(), ys.mean()
    px = a[fg]
    white = ((px[:, 0] >= 225) & (px[:, 1] >= 225) & (px[:, 2] >= 205)).sum()
    white_share = float(white) / fg.sum()
    # 各向同性：前景像素角度直方图（16 扇区）的均匀度 = 1 - 变异系数
    ang = np.arctan2(ys - cy, xs - cx)
    hist, _ = np.histogram(ang, bins=16, range=(-math.pi, math.pi))
    mean_f = hist.mean()
    iso = 1.0 - float(hist.std() / mean_f) if mean_f > 0 else 0.0
    content_frac = float(fg.sum()) / (h * w)
    return {"ok": True, "white_share": round(white_share, 3), "iso": round(iso, 3),
            "content_frac": round(content_frac, 3),
            "bbox": (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)),
            "mean_rgb": tuple(int(v) for v in px.mean(axis=0)),
            "_lum": lum, "_fg": fg}


def to_alpha_sprite(scored: dict, out_path: str) -> None:
    """黑底 → 透明底：alpha = 亮度，颜色反乘（un-premultiply）。缩至 128×128。"""
    lum = scored["_lum"]
    img = np.asarray(Image.open(scored["_path"]).convert("RGB"), dtype=np.float32)
    a = np.clip(lum / 255.0, 0.0, 1.0)
    rgb = np.zeros((*lum.shape, 3), dtype=np.float32)
    mask = a > 0.02
    for c in range(3):
        rgb[:, :, c][mask] = np.clip(img[:, :, c][mask] / a[mask], 0.0, 255.0)
    rgba = np.dstack([rgb, a * 255.0]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    im = im.resize((128, 128), Image.LANCZOS)
    im.save(out_path)
    # 复测部署件
    d = np.asarray(Image.open(out_path).convert("RGBA"), dtype=np.int32)
    m = d[:, :, 3] > 60
    px = d[m]
    print(f"   部署件 {os.path.basename(out_path)}: content_px={int(m.sum())} "
          f"meanRGBA=({px[:,0].mean():.0f},{px[:,1].mean():.0f},{px[:,2].mean():.0f},"
          f"{px[:,3].mean():.0f})", flush=True)


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    cands = []
    for i in range(1, 4):
        print(f"── 生成候选 {i}/3 ...", flush=True)
        p = generate_one(i)
        if p:
            cands.append(p)
        time.sleep(2)
    if not cands:
        print("全部候选生成失败")
        return 1
    scored = []
    for p in cands:
        s = score_candidate(p)
        s["_path"] = p
        if s["ok"]:
            # 评分：白占比 50% + 各向同性 30% + 内容占比适中 20%（0.25-0.5 满分）
            cf = s["content_frac"]
            cf_score = 1.0 if 0.25 <= cf <= 0.5 else max(0.0, 1.0 - abs(cf - 0.375) * 2)
            s["total"] = s["white_share"] * 0.5 + s["iso"] * 0.3 + cf_score * 0.2
            print(f"{os.path.basename(p)}: white={s['white_share']} iso={s['iso']} "
                  f"content={s['content_frac']} bbox={s['bbox']} rgb={s['mean_rgb']} "
                  f"total={s['total']:.3f}", flush=True)
            scored.append(s)
        else:
            print(f"{os.path.basename(p)}: 不可用（{s['why']}）", flush=True)
    if not scored:
        return 1
    best = max(scored, key=lambda s: s["total"])
    print(f"★ 选优: {os.path.basename(best['_path'])} (total={best['total']:.3f})", flush=True)
    to_alpha_sprite(best, DEPLOY_PATH)
    print(f"部署完成 → {DEPLOY_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
