# -*- coding: utf-8 -*-
"""批A 定向部署：指定单位的 attack f*.png → assets sheet_attack（保留 idle 与 counts.idle）。

不入 deploy_unit_anims 全量扫描（222 家重部署会踩今天 vintage/idle 改动）。
帧缘断言：实心(α≥128)零触边（v6.30 振铃教训），违者报错不写盘。
用法: python tools/_batchA_deploy.py ww1_a7v [ww1_mark4 ...]
"""
import glob
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402

import deploy_unit_anims as dua  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ROOT = os.path.join(ROOT, "资料", "单位分帧动画")


def src_dir(key):
    """按键前缀找资料目录（剥离 NNN_ 前缀匹配，同 deploy_unit_anims 规则）。"""
    import re
    for d in sorted(os.listdir(SRC_ROOT)):
        p = os.path.join(SRC_ROOT, d, "attack")
        if not os.path.isdir(p):
            continue
        stripped = re.sub(r"^\d{3}_", "", d)
        if stripped == key or stripped.startswith(key + "_"):
            return p
    return None


def deploy(key):
    src = src_dir(key)
    frames = sorted(glob.glob(os.path.join(src, "f*.png"))) if src else []
    if len(frames) < 4:
        print("[skip] %s 可用f帧=%d (<4)" % (key, len(frames)))
        return False
    out = os.path.join(ROOT, dua.DST, key)
    os.makedirs(out, exist_ok=True)
    sheet = Image.new("RGBA", (dua.FRAME * len(frames), dua.FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im = Image.open(f).convert("RGBA")
        if im.size != (dua.FRAME, dua.FRAME):
            im = im.resize((dua.FRAME, dua.FRAME), Image.LANCZOS)
        sheet.paste(im, (i * dua.FRAME, 0))
    # 帧缘断言：实心零触边（先于烘焙，防振铃被 dilate 拽到画框外）
    import numpy as np
    arr = np.asarray(sheet)
    for i in range(len(frames)):
        cell = arr[:, i * dua.FRAME:(i + 1) * dua.FRAME]
        solid = cell[..., 3] >= 128
        if solid[0, :].any() or solid[-1, :].any() or solid[:, 0].any() or solid[:, -1].any():
            print("[FAIL] %s f%02d 实心像素触帧缘（振铃/截断），不写盘" % (key, i))
            return False
    sheet = dua.bake_outline_on_sheet(sheet)
    # 原子写：先落 tmp 再改名
    tmp = os.path.join(out, "sheet_attack.tmp.png")
    sheet.save(tmp)
    os.replace(tmp, os.path.join(out, "sheet_attack.png"))
    # anim.json：保留 idle 计数与 foot_frac，attack 换新
    aj = os.path.join(out, "anim.json")
    old = json.load(open(aj, encoding="utf-8")) if os.path.exists(aj) else {}
    counts = dict(old.get("counts", {}))
    counts["attack"] = len(frames)
    idle_sheet = os.path.join(out, "sheet_idle.png")
    if not os.path.exists(idle_sheet):
        counts.pop("idle", None)
    meta = {"fps": dua.FPS, "frame_size": dua.FRAME, "counts": counts}
    if dua.OUTLINE_BAKE:
        meta["outline"] = dua.outline_meta()
    if "foot_frac" in old:
        meta["foot_frac"] = old["foot_frac"]
    json.dump(meta, open(aj, "w", encoding="utf-8"))
    print("[deploy] %s attack=%d帧 idle=%s" % (key, counts["attack"], counts.get("idle", "-")))
    return True


if __name__ == "__main__":
    ok = [k for k in sys.argv[1:] if deploy(k)]
    print("deployed:", ok)
