# -*- coding: utf-8 -*-
"""B4 gain 补刀：API relight 后仍暗的 raw 做确定性亮度对齐（img25 批成熟配方）。
源=_raw_dark2.png（relit 版，明暗层次较好），目标 body mean 对齐成品卡水平；
原 _raw.png（首掷暗图）先改名 _raw_dark1.png 备份，gain 结果覆盖 _raw.png。
用法: python tools/_b4_gain.py [target_mean=92]
"""
import glob, io, json, os, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
TARGET = float(sys.argv[1]) if len(sys.argv) > 1 else 92.0
GAIN_MAX = 2.4
WHITE_SNAP = 238  # min(rgb)>=此值 → 255，保底纯白背景


def body_mask(a):
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a.astype(float) - bg) ** 2).sum(axis=2))
    return bg, dist > 100


def gate(a):
    bg, body = body_mask(a)
    n = int(body.sum())
    if n < 4000:
        return False, {"verdict": "empty"}
    bg_ok = bool(bg.min() >= 225)
    rgb = a[body]
    mean = float(rgb.mean())
    lit = float((rgb.max(axis=1) > 100).mean())
    ok = bg_ok and mean >= 80 and lit >= 0.35
    return ok, {"mean": round(mean, 1), "lit": round(lit, 2),
                "verdict": "pass" if ok else "dark"}


def main():
    n_pass = n_dark = 0
    for d2 in sorted(glob.glob(os.path.join(STAGE, "*_raw_dark2.png"))):
        cid = os.path.basename(d2).replace("_raw_dark2.png", "")
        raw = d2.replace("_raw_dark2.png", "_raw.png")
        if not os.path.isfile(raw):
            print("[skip] %s 无 _raw" % cid)
            continue
        a = np.asarray(Image.open(d2).convert("RGB")).astype(float)
        _, body = body_mask(a)
        m = float(a[body].mean())
        gain = max(1.0, min(TARGET / max(m, 1.0), GAIN_MAX))
        b = np.clip(a * gain, 0, 255)
        b[b.min(axis=2) >= WHITE_SNAP] = 255.0  # 白场吸附
        im2 = Image.fromarray(b.astype(np.uint8))
        ok, info = gate(np.asarray(im2).astype(int))
        d1 = d2.replace("_raw_dark2.png", "_raw_dark1.png")
        if not os.path.isfile(d1):
            os.rename(raw, d1)  # 首掷暗图备份
        im2.save(raw)
        if ok:
            n_pass += 1
        else:
            n_dark += 1
        print("[%s] %s gain=%.2f (src mean %.1f) %s" % (
            "OK " if ok else "MISS", cid, gain, m, json.dumps(info)), flush=True)
    print("gain 轮：过门 %d / 仍暗 %d（目标 mean=%.0f）" % (n_pass, n_dark, TARGET))


if __name__ == "__main__":
    main()
