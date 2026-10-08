# -*- coding: utf-8 -*-
"""fam44 AI 生图批·已拍板 raw → 品红锚定 → codeanim 配置 → sheet（staging）。

输入: .godot/unit_review/fam44_cards_redo/<key>_raw.png（白底·朝右·已过用户拍板）
管线: white_to_alpha(边缘泛洪) → fliplr(朝左契约) → fca.extract(品红场) →
      purge_pink_pockets → fam44_anchor_from_card/<key>_anchor_raw.png
配置: 增量并入 _configs_fam44.json（只加缺失键，绝不改既有 26 家已校正枪口）
用法: python tools/_fam44_anchor_from_raw.py [key ...]   # 缺省=APPROVED 全部
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
import numpy as np  # noqa: E402
import fam43_card_anchors as fca  # noqa: E402
import fam44_cards_page as fp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam44_cards_redo")
SRC = os.path.join(ROOT, ".godot", "unit_review", "fam44_anchor_from_card")
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam44.json")
PINK = np.array([255, 0, 255])

C_ORANGE = [255, 120, 30]
C_CYAN = [110, 225, 255]
C_PURPLE = [160, 110, 255]

# 已拍板（fam44_cards.json status=可以，7/7）；10-06 深夜二轮补入 void_soldier/juggernaut
APPROVED = {
    "fe_quantum_mobile_base": dict(cat="ground", flash=C_CYAN, angle=-2, gain=1.0,
                                   extra=dict(recoil=0, smoke_n=0, flash_scale=1.2)),
    "fe_quantum_repair_drone": dict(cat="air", flash=C_CYAN, angle=-2, gain=1.0,
                                    extra=dict(recoil=0, smoke_n=0, flash_scale=0.8)),
    "fe_frontier_veteran": dict(cat="ground", flash=C_ORANGE, angle=-2, gain=1.6,
                                extra=dict(recoil=1, smoke_n=0)),
    "fe_void_dimensional_soldier": dict(cat="ground", flash=C_PURPLE, angle=-2, gain=1.9,
                                        extra=dict(recoil=1, smoke_n=0)),
    "fe_iron_wall_juggernaut": dict(cat="ground", flash=C_CYAN, angle=-2, gain=1.8,
                                    extra=dict(recoil=2, smoke_n=0)),
}


def extract_key(key):
    raw = Image.open(os.path.join(STAGE, "%s_raw.png" % key))
    rgba = fp.white_to_alpha(raw).transpose(Image.FLIP_LEFT_RIGHT)  # 朝右 → 朝左
    tmp = os.path.join(STAGE, "_tmp_rgba_%s.png" % key)
    rgba.save(tmp)
    arr = fca.extract(tmp)
    os.remove(tmp)
    arr, npix = fca.purge_pink_pockets(arr)
    Image.fromarray(arr).save(os.path.join(SRC, "%s_anchor_raw.png" % key))
    a = arr.astype(int)
    dist = np.sqrt(((a - PINK) ** 2).sum(axis=2))
    ys, xs = np.where(dist >= 100)
    mx, my = int(xs.min()), int(ys[xs == xs.min()].mean())
    h = int((dist >= 100).any(axis=1).sum())
    print("[anchor] %-26s pocket=%d autoL=(%d,%d) 展幅h=%d" % (key, npix, mx, my, h), flush=True)
    return mx, my


def probe(keys):
    TH, cols = 460, min(4, len(keys))
    rows = (len(keys) + cols - 1) // cols
    page = Image.new("RGB", (cols * TH, rows * (TH + 20)), (24, 24, 28))
    d0 = ImageDraw.Draw(page)
    for i, k in enumerate(keys):
        p = os.path.join(SRC, "%s_anchor_raw.png" % k)
        im = Image.open(p).convert("RGB").resize((TH, TH), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        sc = TH / 1024.0
        for v in range(0, 1025, 100):
            d.line((v * sc, 0, v * sc, TH), fill=(0, 255, 120))
            d.line((0, v * sc, TH, v * sc), fill=(0, 255, 120))
        a = np.asarray(Image.open(p).convert("RGB")).astype(int)
        dist = np.sqrt(((a - PINK) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)
        x0, y0 = int(xs.min()), int(ys[xs == xs.min()].mean())
        cx, cy = x0 * sc, y0 * sc
        d.line((cx - 9, cy, cx + 9, cy), fill=(255, 255, 0), width=2)
        d.line((cx, cy - 9, cx, cy + 9), fill=(255, 255, 0), width=2)
        x, y = (i % cols) * TH, (i // cols) * (TH + 20)
        page.paste(im, (x, y))
        d0.text((x + 4, y + TH + 3), "%s  autoL=(%d,%d)@1024" % (k, x0, y0), fill=(255, 220, 120))
    out = os.path.join(SRC, "_probe_fam44_raw.png")
    page.save(out)
    print("[probe] %s (%d家)" % (out, len(keys)), flush=True)


def merge_cfg(items):
    cfg = {}
    if os.path.exists(CFG):
        try:
            cfg = json.load(open(CFG, encoding="utf-8"))
        except Exception:
            cfg = {}
    base = dict(mode="vfx", flip=False, outline=False, pink_scrub=True, src=SRC)
    added = []
    for key, (mx, my) in items:
        if key in cfg:
            print("[cfg] %s 已存在，跳过（不覆盖既有枪口）" % key, flush=True)
            continue
        u = APPROVED[key]
        c = dict(base, cat=u["cat"], muzzle=[mx, my], flash_angle=u["angle"],
                 gain=u["gain"], flash_color=u["flash"])
        c.update(u["extra"])
        cfg[key] = c
        added.append(key)
    json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[cfg] +%d → %s（现 %d 家）" % (len(added), CFG, len(cfg)), flush=True)
    return added


def gen(keys):
    for k in keys:
        r = subprocess.run([sys.executable, "tools/codeanim_gen.py", "--configs",
                            os.path.relpath(CFG, ROOT), k],
                           capture_output=True, cwd=ROOT)
        out = r.stdout.decode("utf-8", "replace") or r.stderr.decode("utf-8", "replace")
        line = [l for l in out.split("\n") if k in l or "md5" in l.lower()]
        print(line[0] if line else out[-160:], flush=True)


def main():
    keys = sys.argv[1:] or list(APPROVED)
    items = [(k, extract_key(k)) for k in keys]
    probe(keys)
    gen(merge_cfg(items))


if __name__ == "__main__":
    main()
