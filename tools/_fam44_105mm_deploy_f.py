# -*- coding: utf-8 -*-
"""105mm 候选 F（wheelR3b 轮锁+体对齐卷）定向部署（2026-10-07 用户拍板 v7 JSON「ok」）。

源 = _ww1_105mm_wheelR3b_strip_1536.png（wheel-norm 工具产出 RGBA 条带：
键控/火焰豁免/轮锁/体相对轮补偿/帧裁剪全部已在工具内完成）——不重键控、不缩放。
（旧部署脚本 key_cell 的 kill_pink 有 uint8 回绕病 + ag.chroma_key 白球吃浅钢，
10-07 深夜「火炮抠图不对」两病根；本脚本从带 alpha 的条带走完全绕开。）

口径断言（deploy 前闸门）：rest 帧实心高 124-130（卡图 frac 0.498×256≈127，
旧卷非火光帧实测 120-127 同带）、cx 122-128（旧卷 124/131、新 125）。
底线不迁移（旧 209 → 新 219）：渲染端按 anim.json foot_frac 对地，部署时重算。
idle 不动（8 帧保旧）；旧件先备份 .godot/unit_review/fam44_deploy/_old/ww1_105mm/。
后检：尺寸契约/空帧/品红残留/地线极差(实心)/描边占比/贴边扫描。
用法: python tools/_fam44_105mm_deploy_f.py [--dry]
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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, ".godot", "unit_review", "img25_staging",
                   "_ww1_105mm_wheelR3b_strip_1536.png")
ADIR = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww1_105mm")
BACKUP = os.path.join(ROOT, ".godot", "unit_review", "fam44_deploy", "_old", "ww1_105mm")
FRAME = 256
DRY = "--dry" in sys.argv


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()[:10]


def content_checks(strip):
    """描边烘培前量：尺寸契约/空帧/品红残留/实心地线极差/口径断言/贴边。"""
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
    bots, hs, cxs = [], [], []
    for i, f in enumerate(fr):
        m = f[:, :, 3] >= 200
        ys, xs = np.where(m)
        bots.append(int(ys.max()) if len(ys) else -1)
        hs.append(int(ys.max() - ys.min() + 1) if len(ys) else 0)
        cxs.append(float((xs.min() + xs.max()) / 2) if len(xs) else -1)
    span = max(bots) - min(bots)
    if span > 4:
        print("  [NG] 实心底缘极差 %d px %s" % (span, bots))
        ok = False
    # 口径断言：rest 帧（f1/f6）
    for i in (0, 5):
        if not (124 <= hs[i] <= 130):
            print("  [NG] f%d 实心高 %d 出卡标带 124-130" % (i + 1, hs[i]))
            ok = False
        if not (122 <= cxs[i] <= 128):
            print("  [NG] f%d cx %.0f 出带 122-128" % (i + 1, cxs[i]))
            ok = False
    for i, f in enumerate(fr):
        m = f[:, :, 3] >= 16
        sides = {"L": int(m[:, :2].sum()), "R": int(m[:, -2:].sum()),
                 "T": int(m[:2, :].sum()), "B": int(m[-2:, :].sum())}
        hits = {k: v for k, v in sides.items() if v > 40}
        if hits:
            print("  [warn] 帧%d 贴边 %s" % (i + 1, hits))
    print("  实心高 %s（卡标 127）| cx %s | 底缘 %s 极差 %d"
          % (hs, ["%.0f" % c for c in cxs], bots, span))
    return ok


def outline_check(atk):
    """描边烘培后量：暗描边占空比（1%-45%）。"""
    a = np.asarray(atk)
    edge = ((a[:, :, :3].astype(int).sum(axis=2) < 180) & (a[:, :, 3] >= 200)).sum()
    frac = edge / a[:, :, 3].size
    ok = 0.01 <= frac <= 0.45
    print("  描边占比 %.3f %s" % (frac, "" if ok else "[NG]"))
    return ok


def main():
    strip = Image.open(SRC).convert("RGBA")
    assert strip.size == (FRAME * 6, FRAME), strip.size
    good = content_checks(strip)
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
    print("[pre] 旧 sheet md5=%s foot=%s counts=%s" % (md5(os.path.join(ADIR, "sheet_attack.png")),
                                                       old.get("foot_frac"), old["counts"]))
    if DRY:
        print("[dry] foot 将=%s counts 将=%s" % (foot, meta["counts"]))
        return
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
