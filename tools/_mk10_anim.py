# -*- coding: utf-8 -*-
"""MK10 重做批·阶段2（2026-10-05）：ww1_arm_rolls / ww1_arty_77mm 动画整体重生成。
"重做"拍板：rolls 现役动画主体错（履带坦克≠轮式装甲车）、77mm 没正侧面。
链路（_mk8_anchor2 同款，朝向保持默认朝左契约）：
  t2i 新卡图（mk10_staging/*_icon_raw_t2i.png）→ 锚定帧（品红底，朝左硬锁）
  → 键控/depink/主体保留/全身校验 → idle 8f 微呼吸环（本地合成）
  → attack 3×2 cells 掷 2 版（img25_attack_gen --direct → 832 sheet）
产物只落 staging；目验手术后另行部署。
用法: python tools/_mk10_anim.py
"""
import io
import json
import os
import subprocess
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, ".godot", "unit_review", "mk10_staging")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
os.makedirs(OUT, exist_ok=True)


def load(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load("mk10_ag", os.path.join(ROOT, "tools", "img25_anchor_gen.py"))
agk = load("mk10_agk", os.path.join(ROOT, "tools", "img25_attack_gen.py"))
a2 = load("mk10_a2", os.path.join(ROOT, "tools", "_mk8_anchor2.py"))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

EXTRA_LEFT = ("Strictly flat side profile facing left: the camera is exactly at the subject's "
              "own side, level with its midline; the subject's long axis stretches horizontally "
              "across the whole image, its upright parts stay vertical, no perspective "
              "foreshortening. Zoomed-out wide framing: the whole subject fully inside each cell "
              "with generous empty space on all four sides, far from the cell edges.")

UNITS = {
    "ww1_arm_rolls": dict(
        subject="参考图中的这辆一战英国劳斯莱斯轮式装甲车（修长引擎盖、木辐条车轮、"
                "车体后部球形旋转炮塔伸出细机枪管，浅蓝灰绿涂装）",
        cells=dict(seq="车顶炮塔机枪点射",
                   cells={"2": "炮塔机枪口爆出一簇短促火光，车体微微一颤",
                          "3": "火光消散，枪口冒出一缕细烟，一枚小弹壳向右后方弹出",
                          "4": "机枪口再度短点射，又一簇火光",
                          "5": "硝烟在枪口萦绕后飘散",
                          "6": "回到待机，与锚定帧完全一致"},
                   fx="只要机枪口小火光与细硝烟弹壳，无弹道无曳光，火光只出现在炮塔机枪口"),
    ),
    "ww1_arty_77mm": dict(
        subject="参考图中的这门一战 77mm 野战炮（细长炮管、弧形炮盾、大木辐条车轮、"
                "向左后方斜撑的驻锄尾梁，钢蓝灰炮身与原木色车轮）",
        cells=dict(seq="77mm 野战炮全装药射击",
                   cells={"2": "炮口爆出大团橙白色火光，炮身沿驻锄方向向后猛退",
                          "3": "火光衰减，炮口涌出浓白硝烟",
                          "4": "浓烟弥漫在炮口前方，炮身缓缓复位",
                          "5": "硝烟散尽只剩一缕青烟",
                          "6": "回到待机，与锚定帧完全一致"},
                   fx="只要炮口火光与硝烟，无弹道无曳光，火光只出现在炮口"),
    ),
}


def main():
    for key, u in UNITS.items():
        print("== %s ==" % key, flush=True)
        card = os.path.join(STG, "%s_icon_raw_t2i.png" % key)
        rc = subprocess.call([sys.executable, os.path.join(ROOT, "tools", "img25_anchor_gen.py"),
                              key, card, "--subject", u["subject"], "--chroma-out"], cwd=ROOT)
        print("  [anchor] rc=%d" % rc, flush=True)
        raw_p = os.path.join(OUT, "%s_anchor_raw.png" % key)
        if not os.path.exists(raw_p):
            print("  锚定帧缺失，跳过该单位", flush=True)
            continue
        raw = Image.open(raw_p).convert("RGB")
        keyed = ag.chroma_key(raw)
        keyed = agk.depink(keyed)
        keyed = agk.keep_main_bodies(keyed, 0.35)
        ok, info = a2.fullbody_check(keyed)
        print("  全身校验: ok=%s %s" % (ok, info), flush=True)
        if not ok:
            print("  非全身/触底，保留锚定待目验再处理", flush=True)
            continue
        keyed.save(os.path.join(OUT, "%s_anchor_keyed.png" % key))
        a2.build_idle(key)
        cj = os.path.join(STG, "_mk10_cells_%s.json" % key)
        spec = dict(u["cells"])
        spec["extra"] = EXTRA_LEFT
        with open(cj, "w", encoding="utf-8") as f:
            json.dump(spec, f, ensure_ascii=False)
        rc = subprocess.call([sys.executable, os.path.join(ROOT, "tools", "img25_attack_gen.py"),
                              key, "--subject", u["subject"], "--rolls", "2",
                              "--cells-json", cj], cwd=ROOT)
        print("  [attack] rc=%d" % rc, flush=True)
    print("MK10 阶段2 动画重生成结束", flush=True)


if __name__ == "__main__":
    main()
