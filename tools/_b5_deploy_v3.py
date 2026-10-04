# -*- coding: utf-8 -*-
"""B5 拍板 v3 部署（2026-10-04，用户令「都可以了布置入项目」）：
11 攻击（10 SF 512 横条 + bomber R2 3×2 832）+ 3 idle（fut_arm_mech_e/mg_nest/77mm 净版重建）。
每帧→256 LANCZOS→横条→bake_outline_on_sheet 预烘焙描边→备份旧件→覆写 assets。
anim.json 更新 counts/outline（fps/frame_size/foot_frac 保留，foot_frac 事后跑
_tmp_anim_foot_frac.py 幂等重算）。kingtiger 源键 ww2_boss_kingtiger → 落 ww2_kingtiger。
m60 弃不部署。跑完手动过导入门禁：Godot --headless --path . --import。
用法: python tools/_b5_deploy_v3.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deploy_unit_anims import bake_outline_on_sheet, outline_meta  # noqa: E402  (v6.37 后 import 安全)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
DST = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_b5_deploy_20261004")
FRAME = 256

# (staging 源文件, 帧宽 or "R2", 目标单位目录, 动画名)
ATTACKS = [
    ("ww2_sup_mg42_SF_attack_sheet_512.png", 512, "ww2_sup_mg42", "attack"),
    ("ww2_boss_kingtiger_SF_attack_sheet_512.png", 512, "ww2_kingtiger", "attack"),
    ("ww2_air_bomber_R2_attack_sheet_832.png", "R2", "ww2_air_bomber", "attack"),
    ("ww1_arty_mortar_SF_attack_sheet_512.png", 512, "ww1_arty_mortar", "attack"),
    ("ww1_a7v_SF_attack_sheet_512.png", 512, "ww1_a7v", "attack"),
    ("ww1_lanchest_SF_attack_sheet_512.png", 512, "ww1_lanchest", "attack"),
    ("ww1_mark4_SF_attack_sheet_512.png", 512, "ww1_mark4", "attack"),
    ("mod_arm_m1a2sep_SF_attack_sheet_512.png", 512, "mod_arm_m1a2sep", "attack"),
    ("mod_air_technical_e_SF_attack_sheet_512.png", 512, "mod_air_technical_e", "attack"),
    ("ww1_arty_77mm_SF_attack_sheet_512.png", 512, "ww1_arty_77mm", "attack"),
    ("ww1_105mm_SF_attack_sheet_512.png", 512, "ww1_105mm", "attack"),
]
IDLES = [
    ("fut_arm_mech_e_idle_sheet_512.png", 512, "fut_arm_mech_e", "idle"),
    ("ww1_sup_mg_nest_idle_sheet_512.png", 512, "ww1_sup_mg_nest", "idle"),
    ("ww1_arty_77mm_idle_sheet_512.png", 512, "ww1_arty_77mm", "idle"),
]


def slice_frames(src_path, fw):
    """横条或 R2 3×2 网格 → 帧列表（各行高一致）。"""
    im = Image.open(src_path).convert("RGBA")
    if fw == "R2":
        cell = 832
        cols, rows = im.width // cell, im.height // cell
        return [im.crop((c * cell, r * cell, (c + 1) * cell, (r + 1) * cell))
                for r in range(rows) for c in range(cols)]
    n = im.width // fw
    return [im.crop((i * fw, 0, (i + 1) * fw, im.height)) for i in range(n)]


def deploy(src_name, fw, unit, anim):
    src = os.path.join(OUT, src_name)
    frames = slice_frames(src, fw)
    strip = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        if f.size != (FRAME, FRAME):
            f = f.resize((FRAME, FRAME), Image.LANCZOS)
        strip.paste(f, (i * FRAME, 0))
    strip = bake_outline_on_sheet(strip)
    od = os.path.join(DST, unit)
    jp = os.path.join(od, "anim.json")
    meta = json.load(open(jp, encoding="utf-8")) if os.path.exists(jp) else {}
    # 备份旧件
    bdir = os.path.join(BAK, unit)
    os.makedirs(bdir, exist_ok=True)
    sp = os.path.join(od, "sheet_%s.png" % anim)
    if os.path.exists(sp):
        shutil.copy2(sp, os.path.join(bdir, "sheet_%s.png" % anim))
    if os.path.exists(jp):
        shutil.copy2(jp, os.path.join(bdir, "anim.json"))
    strip.save(sp)
    meta.setdefault("fps", 8)
    meta["frame_size"] = FRAME
    meta.setdefault("counts", {})[anim] = len(frames)
    meta["outline"] = outline_meta(FRAME)
    json.dump(meta, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
    print("[deploy] %-22s %-6s %d 帧  counts=%s" % (unit, anim, len(frames), meta["counts"]))


def main():
    os.makedirs(BAK, exist_ok=True)
    for src_name, fw, unit, anim in ATTACKS + IDLES:
        deploy(src_name, fw, unit, anim)
    print("部署完成 %d 攻击 + %d idle，备份 → %s" % (len(ATTACKS), len(IDLES), BAK))
    print("下一步: python tools/_tmp_anim_foot_frac.py && Godot --headless --path . --import")


if __name__ == "__main__":
    main()
