# -*- coding: utf-8 -*-
"""B4 gain 收敛循环：对不过亮度门的 raw 直接迭代提亮到过门（每轮在 raw 上累计，非 dark2 重算）。
目标逐轮放宽 90→88→86→85，最多 4 轮；白场吸附保纯白底。
用法: python tools/_b4_gain_loop.py
"""
import glob, io, json, os, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
TARGETS = [90.0, 88.0, 86.0, 85.0]
WHITE_SNAP = 238


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
    rgb = a[body]
    mean = float(rgb.mean())
    lit = float((rgb.max(axis=1) > 100).mean())
    ok = bool(bg.min() >= 225) and mean >= 80 and lit >= 0.35
    return ok, {"mean": round(mean, 1), "lit": round(lit, 2),
                "verdict": "pass" if ok else "dark"}


def main():
    n_ok = n_left = 0
    for p in sorted(glob.glob(os.path.join(STAGE, "*_raw.png"))):
        cid = os.path.basename(p).replace("_raw.png", "")
        a = np.asarray(Image.open(p).convert("RGB")).astype(float)
        ok, info = gate(a.astype(int))
        if ok:
            continue
        rounds = 0
        for tgt in TARGETS:
            _, body = body_mask(a)
            m = float(a[body].mean())
            gain = max(1.0, min(tgt / max(m, 1.0), 1.35))
            if gain <= 1.01:
                continue
            a = np.clip(a * gain, 0, 255)
            a[a.min(axis=2) >= WHITE_SNAP] = 255.0
            rounds += 1
            ok, info = gate(a.astype(int))
            if ok:
                break
        Image.fromarray(a.astype(np.uint8)).save(p)
        if ok:
            n_ok += 1
            print("[OK ] %s ×%d轮 %s" % (cid, rounds, json.dumps(info)))
        else:
            n_left += 1
            print("[MISS] %s ×%d轮 %s" % (cid, rounds, json.dumps(info)))
    print("gain 循环：新过门 %d / 仍暗 %d" % (n_ok, n_left))


if __name__ == "__main__":
    main()
