# -*- coding: utf-8 -*-
"""plat17+ind1 批：标记页无动画的 17 家 → codeanim 卡图直出生成（2026-10-06 用户令）。

来源：tools/card_anim_review_marked.html 全段扫描 miss 集（fam 0 + ind 1 + plat 16）。
卡图全部朝右（玩家/平台域）→ 提取期统一预翻朝左。
mode/色按族：steel=cutout3；flame=vfx 橙焰；thunder=vfx 青电；void=vfx 紫；helix/void_stealth=air。
枪口=autoL（翻后最左本体像素）起手，探针页目检后修正。
用法: python tools/plat17_batch.py            # 提取+配置+生成全家
      python tools/plat17_batch.py --only k1  # 单家
"""
import io
import json
import os
import re
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import fam43_card_anchors as fca

CFG_PATH = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")

# key: (mode, cat, flash_color, flash_angle, extra)
U = {
    "fe_helix_phantom":        ("vfx", "air", None, -2, dict(recoil=1, smoke_n=1)),
    "steel_fortress_advanced": ("cutout3", "ground", None, -2, dict(split_y=560, barrel=(540,580,380), recoil=5)),
    "steel_titan_advanced":    ("cutout3", "ground", None, -2, dict(split_y=560, barrel=(540,580,380), recoil=6)),
    "steel_fortress_expert":   ("cutout3", "ground", None, -2, dict(split_y=560, barrel=(540,580,380), recoil=5)),
    "steel_titan_expert":      ("cutout3", "ground", None, -2, dict(split_y=560, barrel=(540,580,380), recoil=6)),
    "flame_raider_advanced":   ("vfx", "ground", [255, 120, 30], -4, dict(recoil=1, smoke_n=0, flash_scale=1.2)),
    "flame_siege_advanced":    ("vfx", "ground", [255, 120, 30], -6, dict(recoil=1, smoke_n=0, flash_scale=1.3)),
    "flame_raider_expert":     ("vfx", "ground", [255, 120, 30], -4, dict(recoil=1, smoke_n=0, flash_scale=1.2)),
    "flame_siege_expert":      ("vfx", "ground", [255, 120, 30], -6, dict(recoil=1, smoke_n=0, flash_scale=1.3)),
    "thunter_striker_advanced": ("vfx", "ground", [110, 225, 255], -3, dict(recoil=1, smoke_n=0)),
    "thunter_sniper_advanced":  ("vfx", "ground", [110, 225, 255], -6, dict(recoil=1, smoke_n=0)),
    "thunter_striker_expert":   ("vfx", "ground", [110, 225, 255], -3, dict(recoil=1, smoke_n=0)),
    "thunter_sniper_expert":    ("vfx", "ground", [110, 225, 255], -6, dict(recoil=1, smoke_n=0)),
    "void_stealth_advanced":   ("vfx", "air", [160, 110, 255], -2, dict(recoil=0, smoke_n=0)),
    "void_mage_advanced":      ("vfx", "ground", [160, 110, 255], -8, dict(recoil=1, smoke_n=0)),
    "void_stealth_expert":     ("vfx", "air", [160, 110, 255], -2, dict(recoil=0, smoke_n=0)),
    "void_mage_expert":        ("vfx", "ground", [160, 110, 255], -8, dict(recoil=1, smoke_n=0)),
}

SRC = os.path.join(ROOT, ".godot", "unit_review", "fam43_anchor_from_card")


def card_path(k):
    html = open(os.path.join(ROOT, "tools", "card_anim_review_marked.html"), encoding="utf-8").read()
    data = json.loads(re.search(r"const DATA = (\{.*?\});\n", html, re.S).group(1))
    for s in data["sections"]:
        for r in s["rows"]:
            if (r.get("anim_key") or r["id"]) == k:
                ic = r.get("icon_e") or r.get("icon") or ""
                if ic:
                    p = os.path.normpath(os.path.join(ROOT, "tools", ic))
                    if os.path.exists(p):
                        return p
    return None


def extract_all(keys):
    import numpy as np
    for k in keys:
        cp = card_path(k)
        assert cp, "无卡图: " + k
        arr = fca.extract(cp)
        arr = arr[:, ::-1, :]  # 朝右→朝左 统一预翻
        arr, npix = fca.purge_pink_pockets(arr)
        Image.fromarray(arr).save(os.path.join(SRC, "%s_anchor_raw.png" % k))
        # autoL 枪口
        a = np.asarray(Image.fromarray(arr).convert("RGB"))
        PINK = np.array([255, 0, 255])
        dist = np.sqrt(((a.astype(int) - PINK) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)
        print("[anchor] %-24s pocket=%d autoL=(%d,%d)" % (k, npix, xs.min(), int(ys[xs == xs.min()].mean())))
        U[k] = U[k] + (int(xs.min()), int(ys[xs == xs.min()].mean()))


def write_configs():
    cfg = json.load(open(CFG_PATH, encoding="utf-8"))
    D = dict(flip=False, outline=False, gain=1.0, pink_scrub=True, src=SRC)
    for k, (mode, cat, fc, ang, extra, mx, my) in U.items():
        c = dict(D, mode=mode, cat=cat, muzzle=[mx, my], flash_angle=ang)
        if fc:
            c["flash_color"] = fc
        c.update(extra)
        cfg[k] = c
    json.dump(cfg, open(CFG_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("configs + %d → %s" % (len(U), CFG_PATH))


def main():
    keys = sys.argv[2:] if "--only" in sys.argv else list(U)
    if "--only" in sys.argv:
        keys = sys.argv[sys.argv.index("--only") + 1:]
    extract_all(keys)
    write_configs()
    for k in keys:
        r = subprocess.run([sys.executable, "tools/codeanim_gen.py", "--configs",
                            os.path.relpath(CFG_PATH, ROOT), k],
                           capture_output=True, text=True, cwd=ROOT)
        line = [l for l in r.stdout.split("\n") if k in l]
        print(line[0] if line else r.stdout[-200:])


if __name__ == "__main__":
    main()
