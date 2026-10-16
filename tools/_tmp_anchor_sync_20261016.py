# -*- coding: utf-8 -*-
"""G8 锚点三处同步(2026-10-16):fire_tr 质心 → json + muzzle_anchors.gd。

- fire_tr=[x,y] 帧 256 坐标 → fireX=x/256, fireY_pct=y/256*100(敌朝左自身口径,
  unit_frame_anim 头注:enemy fireX=1-player,fireY_pct 顶起)
- fire_tr null 且有现役锚=保留;null 且新卡(无现役锚)=TR 帧主体 bbox 左缘中点估
- ff/hf 部署后 anim.json foot_frac 实测值(布置+foot_frac 工具跑完后执行本脚本)

用法:python -I -u -X utf8 tools/_tmp_anchor_sync_20261016.py
"""
import glob
import json
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATT = os.path.join(ROOT, ".godot", "unit_review", "attk4")
AJ = os.path.join(ROOT, "docs", "敌我双方卡头脚和开火位置.json")
GD = os.path.join(ROOT, "data", "muzzle_anchors.gd")
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")

sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_api_card_regen_20261014 as R1  # noqa: E402
import _tmp_api_card_regen_batch2 as R2  # noqa: E402

UID = {}
for u in R1.UNITS:
    UID[u["no"]] = u["uid"]
for u in R2.UNITS2:
    UID.setdefault(u["no"], u["uid"])

rep = {r["no"]: r for r in json.load(open(os.path.join(ATT, "_report.json"), encoding="utf-8"))}
anchors = json.load(open(AJ, encoding="utf-8"))
by_id = {a["id"]: a for a in anchors}
gd = open(GD, encoding="utf-8").read()


def est_fire(uid):
    """null 兜底:TR 帧(第 2 帧)主体 bbox 左缘垂直中点。"""
    p = os.path.join(ANIM, uid, "sheet_attack.png")
    if not os.path.isfile(p):
        return None
    a = np.asarray(Image.open(p).convert("RGBA"))
    fr = a[:, 256:512, 3]
    ys, xs = np.where(fr > 60)
    if not len(xs):
        return None
    x0 = int(xs.min())
    col = ys[xs <= x0 + 6]
    return [x0 + 3, int(col.mean()) if len(col) else int(ys.mean())]


upd, skip = [], []
for no, r in rep.items():
    uid = UID.get(no)
    if not uid or no in ("012", "078"):  # 重掷中批回来重转再同步
        continue
    fr = r.get("fire_tr")
    if fr is None:
        old = by_id.get(uid)
        if old is None:
            fr = est_fire(uid)
            if fr is None:
                skip.append(uid)
                continue
        else:
            skip.append(uid + "(keep)")
            continue
    fx = round(fr[0] / 256.0, 4)
    fy = round(fr[1] / 256.0 * 100.0, 2)
    aj = os.path.join(ANIM, uid, "anim.json")
    ff = 0.35
    if os.path.isfile(aj):
        meta = json.load(open(aj, encoding="utf-8"))
        ff = float(meta.get("foot_frac", ff))
    rec = {"id": uid, "ff": ff, "hf": ff, "fireX": fx, "fireY_pct": fy}
    if uid in by_id:
        by_id[uid].update(rec)
    else:
        anchors.append(rec)
        by_id[uid] = rec
    upd.append((uid, fx, fy))
    pat = re.compile(r'"%s": \{[^}]*\}' % uid)
    line = '"%s": {"fireX": %s, "fireY_pct": %s},' % (uid, fx, fy)
    if pat.search(gd):
        gd = pat.sub(line, gd, count=1)
    else:
        gd = gd.replace("\n}", "\n\t%s\n}" % line, 1)
    print("upd", uid, fx, fy, flush=True)

with open(AJ, "w", encoding="utf-8") as f:
    json.dump(anchors, f, ensure_ascii=False, separators=(",", ":"))
with open(GD, "w", encoding="utf-8") as f:
    f.write(gd)
print("updated %d, skip %d" % (len(upd), len(skip)), flush=True)
