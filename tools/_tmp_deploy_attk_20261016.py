# -*- coding: utf-8 -*-
"""四拍 attack 帧布置(2026-10-16):.godot/unit_review/attk4/<uid>/ → assets。

链:拷 sheet_attack.png → anim.json(counts.attack=4,outline.baked=false=运行时
shader 描边,去 width_px/frame_basis;无现役则新建,idle 缺=回退静态卡图)。
拷完后另跑 anim_subject_normalize.py --dir <uid>(attack 对齐 idle+写 subject 块,
部署门 G7)与 _tmp_anim_foot_frac.py(幂等,idle 卡不动)。

备份:.godot/unit_anims_backup_20261016/(已拷 25 卡现役,8 卡首次布置)。

用法:python -I -u -X utf8 tools/_tmp_deploy_attk_20261016.py <uid,uid|=all>
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, ".godot", "unit_review", "attk4")
DST = os.path.join(ROOT, "assets", "effects", "unit_anims")
# 重掷批未回卡布置时排除(2026-10-16 批全回,清空)
HOLD = set()


def deploy_uid(uid):
    sp = os.path.join(SRC, uid, "sheet_attack.png")
    if not os.path.isfile(sp):
        return "no sheet"
    dd = os.path.join(DST, uid)
    os.makedirs(dd, exist_ok=True)
    import shutil
    shutil.copyfile(sp, os.path.join(dd, "sheet_attack.png"))
    jp = os.path.join(dd, "anim.json")
    if os.path.isfile(jp):
        meta = json.load(open(jp, encoding="utf-8"))
    else:
        meta = {"fps": 8, "frame_size": 256, "counts": {}}
    meta.setdefault("counts", {})["attack"] = 4
    meta["outline"] = {"baked": False}
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    return "ok"


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    uids = sorted(os.listdir(SRC)) if arg == "all" else [u for u in arg.split(",") if u]
    for uid in uids:
        if uid.startswith("_") or uid in HOLD:
            continue
        print(uid, deploy_uid(uid), flush=True)
