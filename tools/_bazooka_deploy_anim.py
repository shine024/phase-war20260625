# -*- coding: utf-8 -*-
"""ww2_inf_bazooka 动画部署（2026-10-06 新专属卡链收口）。

背景：bazooka 原无卡图，卡/锚定/attack/idle 全是 vis_009 tan 装甲车（身份病）。
新卡 cand_b（跪姿肩射，用户拍板）已部署 assets/card_icons/player/ww2_inf_bazooka.png，
锚定重提（预翻朝左），attack sheet 已按新锚定重生成（staged 10 帧 512 格）。

本脚本（可复现，替代 fam43 批丢失的内联部署步）：
  1. 备份旧 tan 车三件 → staging/_old_tancar/
  2. attack = staged f[0,1,2,3,5,7] 缩 256 拼条
  3. idle = staged f0 缩 256，dy=[0,-1,-2,-1] code-bob 4 帧（驱动器 ping-pong 补全周期）
     —— idle f0 与 attack f0 像素同源，切动画不跳变
  4. foot_frac = attack 条内容底缘余量占比（v6.32.3 语义）
  5. 描边暗烘（deploy_unit_anims.bake_outline_on_sheet，唯一真身参数）
  6. 写 sheet_attack/sheet_idle/anim.json
用法: python tools/_bazooka_deploy_anim.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image
import numpy as np

import deploy_unit_anims as dua

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGED = os.path.join(ROOT, ".godot", "unit_review", "codeanim",
                      "ww2_inf_bazooka_codeanim_sheet.png")
ANIM_DIR = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww2_inf_bazooka")
BACKUP = os.path.join(ROOT, ".godot", "unit_review", "bazooka_card_staging", "_old_tancar")
ATTACK_PICK = [0, 1, 2, 3, 5, 7]   # 瞄准→大火光→中火光→小火光+弹点→烟散→收势
IDLE_DY = [0, -1, -2, -1]          # 呼吸起伏（ping-pong 由驱动器补全）
FRAME = 256


def staged_cells(path):
    """staged 5x2·512格 → 10 张 512 RGBA cell。"""
    st = Image.open(path).convert("RGBA")
    assert st.size == (2560, 1024), st.size
    cells = []
    for r in range(2):
        for c in range(5):
            cells.append(st.crop((c * 512, r * 512, (c + 1) * 512, (r + 1) * 512)))
    return cells


def to_256(cell):
    return cell.resize((FRAME, FRAME), Image.LANCZOS)


def content_bottom(strip):
    """内容底缘（alpha≥16 的最大 y）。"""
    a = np.asarray(strip)[:, :, 3]
    ys = np.where((a >= 16).any(axis=0))[0] if False else np.where((a >= 16).any(axis=1))[0]
    return int(ys.max())


def main():
    cells = staged_cells(STAGED)

    # 1. 备份旧 tan 车三件
    os.makedirs(BACKUP, exist_ok=True)
    for f in ("sheet_attack.png", "sheet_idle.png", "anim.json"):
        src = os.path.join(ANIM_DIR, f)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(BACKUP, f))
            print("[backup] %s → _old_tancar/" % f)

    # 2-3. 拼条（先缩放/位移，后统一烘描边）
    atk = Image.new("RGBA", (FRAME * len(ATTACK_PICK), FRAME), (0, 0, 0, 0))
    for i, fi in enumerate(ATTACK_PICK):
        atk.paste(to_256(cells[fi]), (i * FRAME, 0))
    idle = Image.new("RGBA", (FRAME * len(IDLE_DY), FRAME), (0, 0, 0, 0))
    base = to_256(cells[0])
    for i, dy in enumerate(IDLE_DY):
        idle.paste(Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0)), (i * FRAME, 0))
        shifted = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        shifted.paste(base, (0, dy))
        idle.alpha_composite(shifted, (i * FRAME, 0))

    # 4. foot_frac（描边前测，描边会往下扩 4px 不算脚线）
    foot = round((FRAME - 1 - content_bottom(atk)) / FRAME, 4)

    # 5. 描边暗烘（逐帧切片，唯一真身）
    atk = dua.bake_outline_on_sheet(atk)
    idle = dua.bake_outline_on_sheet(idle)

    # 6. 落盘
    atk.save(os.path.join(ANIM_DIR, "sheet_attack.png"))
    idle.save(os.path.join(ANIM_DIR, "sheet_idle.png"))
    meta = {"fps": 8, "frame_size": FRAME,
            "counts": {"idle": len(IDLE_DY), "attack": len(ATTACK_PICK)},
            "outline": dua.outline_meta(), "foot_frac": foot}
    with open(os.path.join(ANIM_DIR, "anim.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    print("[deploy] attack %dx%d (%d 帧) idle %dx%d (%d 帧) foot_frac=%s"
          % (atk.width, FRAME, len(ATTACK_PICK), idle.width, FRAME, len(IDLE_DY), foot))
    print("[done] %s" % ANIM_DIR)


if __name__ == "__main__":
    main()
