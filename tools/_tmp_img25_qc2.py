# -*- coding: utf-8 -*-
"""img25 重掷/救援复查（2026-09-30）：重切+废单重掷后的第二轮 QC。

产物（img25_staging/）：
  _qc2_regen_attack.png  15 重掷废单 attack 行
  _qc2_regen_idle.png    6 重掷废单 idle 行（+mig21/fut_space_fighter skip 救援 idle 行）
  _qc2_rescue.png        SKIP/FLIP 救援单位重切后 attack 行
  _qc2_hard.txt          全 88 候选硬指标异常（帧高>246 / 帧宽>252 / 缺格）
  _qc2_anchor.txt        锚验证抽样（帧高/脚底分布，应≈200/235）
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
FS = 256

REGEN_ATTACK = ["cold_f4", "cold_rpk", "cold_arm_p18", "drop_phase_lance", "fut_space_fighter",
                "fut_sup_ps9", "mod_ah64", "mod_air_bomber", "mod_arty_rq7", "mod_challenger2",
                "platform_cold_scout", "ww2_air_me262", "ww2_air_meteor_e", "ww2_arm_tiger",
                "ww1_lanchest"]
REGEN_IDLE = ["cold_f4", "cold_rpk", "mod_ah64", "mod_air_bomber", "mod_stinger", "mod_uh60",
              "cold_mig21", "fut_space_fighter"]
RESCUE = ["fut_arm_omega", "guardian_future_omega", "mod_hummer_tow", "mod_stryker_mgs",
          "mod_uh60", "platform_cold_light", "platform_modern_radar", "mod_ranger",
          "ww1_a7v", "ww2_sup_gmc_truck", "mod_stryker_m2"]
ALL88 = [k for k in os.listdir(OUT) if k.endswith("_attackC.png")]
ALL88 = sorted(k[:-len("_attackC.png")] for k in ALL88)


def strip(key, tag):
    p = os.path.join(OUT, "%s_%s.png" % (key, tag))
    if not os.path.exists(p):
        return None
    return Image.open(p).convert("RGBA")


def grid(rows, path, label_w=190):
    if not rows:
        return
    H = 128
    W = label_w + FS * 6 // 2
    img = Image.new("RGBA", (W, (H + 4) * len(rows)), (24, 26, 32, 255))
    d = ImageDraw.Draw(img)
    for r, (label, sheet) in enumerate(rows):
        y = r * (H + 4)
        small = sheet.resize((FS * 6 // 2, FS // 2), Image.LANCZOS)
        img.alpha_composite(small, (label_w, y))
        d.text((4, y + 50), label, fill=(255, 210, 120, 255))
    img.convert("RGB").save(os.path.join(OUT, path))
    print("已拼:", path, "%d 行" % len(rows))


def hard_check():
    problems = []
    anchors = []
    for key in ALL88:
        for tag in ("attackC", "idle"):
            p = os.path.join(OUT, "%s_%s.png" % (key, tag))
            if not os.path.exists(p):
                problems.append("%s %s: 缺候选" % (key, tag))
                continue
            im = Image.open(p).convert("RGBA")
            hs, bases = [], []
            for i in range(6):
                fr = np.asarray(im.crop((i * FS, 0, (i + 1) * FS, FS)))
                ys, xs = np.where(fr[:, :, 3] > 8)
                if len(ys) == 0:
                    problems.append("%s %s f%d: 空格" % (key, tag, i))
                    continue
                h = int(ys.max() - ys.min() + 1)
                w = int(xs.max() - xs.min() + 1)
                hs.append(h)
                bases.append(int(ys.max()))
                if h > 246:
                    problems.append("%s %s f%d: 高爆 %d" % (key, tag, i, h))
                if w > 252:
                    problems.append("%s %s f%d: 宽爆 %d" % (key, tag, i, w))
                if int(ys.min()) == 0:
                    problems.append("%s %s f%d: 贴顶" % (key, tag, i))
            if hs:
                anchors.append("%s %s: 高中位%d 脚底中位%d" % (key, tag, int(np.median(hs)), int(np.median(bases))))
    open(os.path.join(OUT, "_qc2_hard.txt"), "w", encoding="utf-8").write("\n".join(problems) or "全部干净")
    open(os.path.join(OUT, "_qc2_anchor.txt"), "w", encoding="utf-8").write("\n".join(anchors))
    print("硬指标异常 %d 条 -> _qc2_hard.txt" % len(problems))


def main():
    rows = [(k + " !!" if k else "", strip(k, "attackC")) for k in REGEN_ATTACK]
    grid([(l, s) for l, s in rows if s is not None], "_qc2_regen_attack.png")
    rows = [(k, strip(k, "idle")) for k in REGEN_IDLE]
    grid([(l, s) for l, s in rows if s is not None], "_qc2_regen_idle.png")
    rows = [(k, strip(k, "attackC")) for k in RESCUE]
    grid([(l, s) for l, s in rows if s is not None], "_qc2_rescue.png")
    hard_check()


if __name__ == "__main__":
    main()
