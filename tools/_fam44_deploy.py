# -*- coding: utf-8 -*-
"""fam44 批C 部署（2026-10-06 用户令：fam44_review 37 条全「可以」）。

来源：tools/fam44_review*.json 按 (N) 后缀新到旧合并，无前缀键且 status=可以 → 部署
（A:/B: 前缀=批A/B 资产早已写盘，跳过）。
配方 = fam43_deploy_v2 拍板铁律：
  · attack = staged 5×2 sheet 10 帧 → 256 拼条 → 描边暗烘（实测 staged 无描边，必须烘）
  · idle 已有目录不动（22 家保旧 idle 与 counts.idle）；缺目录（plat basic 8 家）= f0 bob [0,-1,-2,-1]
  · foot_frac = attack 条描边前内容底缘余量占比
  · 旧件先备份 .godot/unit_review/fam44_deploy/_old/<k>/（PNG 删=永久）
用法: python tools/_fam44_deploy.py [--dry] [key ...]
"""
import glob
import io
import json
import os
import re
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import numpy as np

import deploy_unit_anims as dua

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGED = os.path.join(ROOT, ".godot", "unit_review", "codeanim")
ANIM_BASE = os.path.join(ROOT, "assets", "effects", "unit_anims")
BACKUP = os.path.join(ROOT, ".godot", "unit_review", "fam44_deploy", "_old")
FRAME = 256
IDLE_DY = [0, -1, -2, -1]


def load_ok():
    v = {}
    ps = glob.glob(os.path.join(ROOT, "tools", "fam44_review*.json"))
    ps.sort(key=lambda p: int(re.findall(r"\((\d+)\)", p)[-1])
            if re.search(r"\(\d+\)", p) else -1)
    for p in ps:
        v.update(json.load(open(p, encoding="utf-8")))
    return [k for k, d in v.items()
            if ":" not in k and d.get("status") == "可以"]


def staged_cells(k):
    st = Image.open(os.path.join(STAGED, "%s_codeanim_sheet.png" % k)).convert("RGBA")
    assert st.size == (2560, 1024), (k, st.size)
    return [st.crop((c * 512, r * 512, (c + 1) * 512, (r + 1) * 512))
            for r in range(2) for c in range(5)]


def content_bottom(strip):
    a = np.asarray(strip)[:, :, 3]
    return int(np.where((a >= 16).any(axis=1))[0].max())


def deploy(k, dry):
    cells = staged_cells(k)
    adir = os.path.join(ANIM_BASE, k)
    idle_path = os.path.join(adir, "sheet_idle.png")
    ajson = os.path.join(adir, "anim.json")
    old = json.load(open(ajson, encoding="utf-8")) if os.path.exists(ajson) else None
    if dry:
        print("[dry] %-26s %s" % (k, "旧counts=%s" % old["counts"] if old else "全新"))
        return
    os.makedirs(adir, exist_ok=True)
    # 1. 备份旧件
    bk = os.path.join(BACKUP, k)
    os.makedirs(bk, exist_ok=True)
    for f in ("sheet_attack.png", "sheet_idle.png", "anim.json"):
        s = os.path.join(adir, f)
        if os.path.exists(s):
            shutil.copy2(s, os.path.join(bk, f))
    # 2. attack = 10 帧全量（描边前算 foot_frac）
    atk = Image.new("RGBA", (FRAME * 10, FRAME), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        atk.paste(c.resize((FRAME, FRAME), Image.LANCZOS), (i * FRAME, 0))
    foot = round((FRAME - 1 - content_bottom(atk)) / FRAME, 4)
    atk = dua.bake_outline_on_sheet(atk)
    # 3. idle：已有不动；全新 = f0 bob
    n_idle = None
    if not os.path.exists(idle_path):
        idle = Image.new("RGBA", (FRAME * len(IDLE_DY), FRAME), (0, 0, 0, 0))
        base = cells[0].resize((FRAME, FRAME), Image.LANCZOS)
        for i, dy in enumerate(IDLE_DY):
            sh = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
            sh.paste(base, (0, dy))
            idle.alpha_composite(sh, (i * FRAME, 0))
        idle = dua.bake_outline_on_sheet(idle)
        idle.save(idle_path)
        n_idle = len(IDLE_DY)
    else:
        n_idle = (old or {}).get("counts", {}).get("idle", 8)
    # 4. 落盘
    atk.save(os.path.join(adir, "sheet_attack.png"))
    meta = {"fps": 8, "frame_size": FRAME,
            "counts": {"idle": n_idle, "attack": 10},
            "outline": dua.outline_meta(), "foot_frac": foot}
    with open(ajson, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    print("[deploy] %-26s attack 10 帧 idle %d 帧 foot=%s (%s)"
          % (k, n_idle, foot, "新目录" if not old else "attack重部署"))


def main():
    dry = "--dry" in sys.argv
    keys = [a for a in sys.argv[1:] if not a.startswith("--")] or load_ok()
    for k in sorted(keys):
        deploy(k, dry)
    print("[done] %d 家%s" % (len(keys), "（dry）" if dry else ""))


if __name__ == "__main__":
    main()
