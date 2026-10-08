# -*- coding: utf-8 -*-
"""mark4 候选 G（单血统 rest 帧 Mix5）定向部署（2026-10-07 用户拍板「候选G/已选」）。

Mix5 832 白底 sheet → 六格键控 → 二次归一（卡图口径）→ 256 拼条 → 描边暗烘 → assets。

二次归一（v2 教训：chain_norm 口径=锚定帧自身，832 格内容占 43.5%；
战场单位尺寸由卡图标定 CONTENT_BBOX+attach scale×2 决定，动画帧内容必须匹配卡图口径）：
  · 目标 = 旧 attack 实测（与卡图 h_frac 0.318 一致）：实心高 83px、底线 y207、cx125
  · 全卷统一 (dx,dy)（格1 rest 本体 bbox 推导）——保 intra-strip 相对对齐
键控配方 = _fam44_sf_mark4_105mm.key_chain 骨架，跳过 keep_main_bodies（保独立烟团/余烬）。
idle 不动（8 帧保旧）；旧件先备份 .godot/unit_review/fam44_deploy/_old/ww1_mark4/。
后检：尺寸契约/空帧/品红残留/地线极差(实心)/描边占比/anim.json 互差/贴边扫描。
用法: python tools/_fam44_mark4_deploy_g.py [--dry]
"""
import hashlib
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image

import deploy_unit_anims as dua
import img25_attack_gen as ag

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, ".godot", "unit_review", "img25_staging",
                   "ww1_mark4_chainMix5_n_sheet_832.png")
ADIR = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww1_mark4")
BACKUP = os.path.join(ROOT, ".godot", "unit_review", "fam44_deploy", "_old", "ww1_mark4")
FRAME = 256
CELL = 832
# 二次归一口径（来源：旧 sheet_attack.png 实测 + 卡图 CONTENT_BBOX h0.318）
TARGET_H = 83    # 实心内容高 px @256
TARGET_BOT = 207 # 实心底缘 y（地面线）
TARGET_CX = 125  # 实心内容中心 x
DRY = "--dry" in sys.argv


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()[:10]


def kill_pink(rgba):
    a = np.asarray(rgba).copy()
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    hit = ((r - g > 30) & (b - g > 10)) | ((r > 100) & (r > g * 1.9) & (b > g * 1.4) & (g < 70)) \
        | ((r - g > 12) & (b - g > 8) & (r > 150))
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


def key_cell(cell):
    rgb = cell.convert("RGB")
    rgba = ag.chroma_key(rgb, ag.detect_bg_color(rgb))
    rgba = kill_pink(rgba)
    rgba = ag.depink(rgba)
    return rgba


def solid_bbox(rgba):
    """实心内容 bbox（alpha≥200；软阴影/烟羽不入）。"""
    a = np.asarray(rgba)
    m = a[:, :, 3] >= 200
    ys, xs = np.where(m)
    return xs.min(), xs.max(), ys.min(), ys.max()


def build_strip():
    sh = Image.open(SRC).convert("RGB")
    assert sh.size == (CELL * 3, CELL * 2), sh.size
    keyed832 = []
    for i in range(6):
        c, r = i % 3, i // 3
        keyed832.append(key_cell(sh.crop((c * CELL, r * CELL,
                                          (c + 1) * CELL, (r + 1) * CELL))))
    # 二次归一：格1（rest 纯车体）实心 bbox 定 (dx,dy)，全卷统一
    x0, x1, y0, y1 = solid_bbox(keyed832[0])
    f = TARGET_H / (y1 - y0 + 1.0)
    dx = round(TARGET_CX - (x0 + x1) / 2.0 * f)
    dy = round(TARGET_BOT - y1 * f)
    strip = Image.new("RGBA", (FRAME * 6, FRAME), (0, 0, 0, 0))
    for i, cell in enumerate(keyed832):
        w = max(1, round(CELL * f))
        sc = cell.resize((w, w), Image.LANCZOS)
        strip.paste(sc, (dx + i * FRAME, dy))
    print("[norm] f=%.4f dx=%d dy=%d（832→%d px/格）" % (f, dx, dy, w))
    return strip


def content_checks(strip):
    """描边烘培前量：尺寸契约/空帧/品红残留/实心地线极差/实心高/贴边。"""
    a = np.asarray(strip)
    fr = [a[:, i * FRAME:(i + 1) * FRAME] for i in range(6)]
    ok = True
    if strip.size != (FRAME * 6, FRAME):
        print("  [NG] 尺寸 %s" % (strip.size,))
        ok = False
    for i, f in enumerate(fr):
        n = int((f[:, :, 3] >= 16).sum())
        if n < 300:
            print("  [NG] 帧%d 内容像素 %d" % (i + 1, n))
            ok = False
    d = np.sqrt(((a[:, :, :3].astype(int) - np.array([255, 0, 255])) ** 2).sum(axis=2))
    n = int(((d < 60) & (a[:, :, 3] >= 200)).sum())
    if n > 50:
        print("  [NG] 品红残留 %d px" % n)
        ok = False
    bots, hs = [], []
    for i, f in enumerate(fr):
        m = f[:, :, 3] >= 200
        ys = np.where(m.any(axis=1))[0]
        bots.append(int(ys.max()) if len(ys) else -1)
        hs.append(int(ys.max() - ys.min() + 1) if len(ys) else 0)
    span = max(bots) - min(bots)
    if span > 4:
        print("  [NG] 实心底缘极差 %d px %s" % (span, bots))
        ok = False
    for i, f in enumerate(fr):
        m = f[:, :, 3] >= 16
        sides = {"L": int(m[:, :2].sum()), "R": int(m[:, -2:].sum()),
                 "T": int(m[:2, :].sum()), "B": int(m[-2:, :].sum())}
        hits = {k: v for k, v in sides.items() if v > 40}
        if hits:
            print("  [warn] 帧%d 贴边 %s" % (i + 1, hits))
    print("  实心高 %s（目标 %d）| 底缘 %s 极差 %d"
          % (hs, TARGET_H, bots, span))
    return ok, bots


def outline_check(atk):
    """描边烘培后量：暗描边占空比（1%-45%）。"""
    a = np.asarray(atk)
    edge = ((a[:, :, :3].astype(int).sum(axis=2) < 180) & (a[:, :, 3] >= 200)).sum()
    frac = edge / a[:, :, 3].size
    ok = 0.01 <= frac <= 0.45
    print("  描边占比 %.3f %s" % (frac, "" if ok else "[NG]"))
    return ok


def main():
    strip = build_strip()
    good, bots_solid = content_checks(strip)
    # foot 取全卷最下可见缘（alpha≥16），描边烘培前——与旧卷口径一致
    a = np.asarray(strip)
    bots16 = []
    for i in range(6):
        m = a[:, i * FRAME:(i + 1) * FRAME][:, :, 3] >= 16
        bots16.append(int(np.where(m.any(axis=1))[0].max()) if m.any() else -1)
    foot = round((FRAME - 1 - max(bots16)) / FRAME, 4)
    old_json = os.path.join(ADIR, "anim.json")
    old = json.load(open(old_json, encoding="utf-8"))
    meta = {"fps": 8, "frame_size": FRAME,
            "counts": {"idle": old["counts"]["idle"], "attack": 6},
            "outline": dua.outline_meta(), "foot_frac": foot}
    if DRY:
        print("[dry] foot 将=%s counts 将=%s（实心底缘 %s）"
              % (foot, meta["counts"], bots_solid))
        return
    print("[pre] 旧 sheet md5=%s foot=%s counts=%s" % (md5(os.path.join(ADIR, "sheet_attack.png")),
                                                       old.get("foot_frac"), old["counts"]))
    os.makedirs(BACKUP, exist_ok=True)
    for f in ("sheet_attack.png", "sheet_idle.png", "anim.json"):
        s = os.path.join(ADIR, f)
        if os.path.exists(s):
            shutil.copy2(s, os.path.join(BACKUP, f))
    atk = dua.bake_outline_on_sheet(strip)
    good = outline_check(atk) and good
    atk.save(os.path.join(ADIR, "sheet_attack.png"))
    with open(old_json, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    print("[deploy] sheet_attack.png md5=%s anim.json counts=%s foot=%s"
          % (md5(os.path.join(ADIR, "sheet_attack.png")), meta["counts"], foot))
    print("[check] %s" % ("PASS" if good else "FAIL"))
    sys.exit(0 if good else 1)


if __name__ == "__main__":
    main()
