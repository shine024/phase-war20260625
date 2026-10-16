# -*- coding: utf-8 -*-
"""灵耀暂存拍转正(2026-10-16):.godot/unit_review/lingyao/<no>·<name>_<beat>.png
→ raw/poses/(resize 1024²)→ 四拍齐则重拼卷。

用法:python -I -u -X utf8 tools/_tmp_ly_promote_20261016.py 078:TR,BR 012:TL,TR,BR 070:BR
(冒号后=拍列表,全拍=ALL)
"""
import glob
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_api_firegrid_v2_20261015 as V2  # noqa: E402
import _tmp_api_card_regen_batch2 as B2  # noqa: E402

SRC = os.path.join(ROOT, ".godot", "unit_review", "lingyao")
RAW = V2.RAW
POSES = os.path.join(RAW, "poses")
BEATS = ["TL", "TR", "BL", "BR"]

allu = {u["no"]: u for u in V2.UNITS}
for u in B2.UNITS2:
    allu.setdefault(u["no"], u)

for spec in sys.argv[1:]:
    no, beats = spec.split(":")
    u = allu.get(no)
    if not u:
        print(no, "no unit")
        continue
    beats = BEATS if beats.upper() == "ALL" else [b.upper() for b in beats.split(",")]
    for b in beats:
        sp = os.path.join(SRC, "%s·%s_%s.png" % (no, u["name"], b))
        dp = os.path.join(POSES, "%s·%s_%s.png" % (no, u["name"], b))
        if not os.path.isfile(sp):
            print(no, b, "暂存缺")
            continue
        Image.open(sp).convert("RGB").resize((1024, 1024), Image.LANCZOS).save(dp)
        print("转正", no, b, flush=True)
    # 四拍齐则重拼
    ps = [os.path.join(POSES, "%s·%s_%s.png" % (no, u["name"], b)) for b in BEATS]
    if all(os.path.isfile(p) for p in ps):
        grid = Image.new("RGB", (2048, 2048), (255, 0, 255))
        for p, (cx, cy) in zip(ps, ((0, 0), (1024, 0), (0, 1024), (1024, 1024))):
            grid.paste(Image.open(p).convert("RGB").resize((1024, 1024), Image.LANCZOS), (cx, cy))
        out = os.path.join(RAW, "%s·%s_开火4格.png" % (no, u["name"]))
        grid.save(out)
        print("卷拼", no, flush=True)
