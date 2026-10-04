# -*- coding: utf-8 -*-
## 视觉修复 B 组：用户 2026-10-03 12:10 网页标注 13 案中未修的 10 案
## （3 家族新建专属目录 + 4 原位重建，其中 37mm 仅攻击 / pillbox 仅待机去灯）
## 复用 A 组管线（_vision_fix_rebuild_a）：卡图直出 fill_80 v5，安全规则同款（显式清单+先备份）。
## 增强第8元素 parts：只重建指定列，另一列保留现役 sheet，anim.json counts 沿用旧值。
import json, os, sys, io
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

spec = importlib.util.spec_from_file_location("ra", os.path.join(ROOT, "tools", "_vision_fix_rebuild_a.py"))
ra = importlib.util.module_from_spec(spec)
sys.modules["ra"] = ra
spec.loader.exec_module(ra)  # __main__ 保护，import 安全；复用 load_card/to_canvas/build/BAK/ANIM/REV

# (key, 卡图res路径, idle_n, attack_n, air, flip[, muzzle(gx,gy)][, parts])
# fam 家族卡 icon_p=朝右源 → flip=True；新目录以家族键命名=解析链第2站自动接线，宿主目录(ww1_mg08/ww1_arty_m81/ww1_arm_ft17)降为候选不动
CASES = [
    # ── 新建专属目录（共享目录错画/错主体）──
    ("ww1_sup_mg_nest", "res://assets/card_icons/player/vis_player_038.png", 8, 10, False, True),
    ("ww1_arty_mortar", "res://assets/card_icons/player/vis_player_039.png", 8, 12, False, True, (110, 100)),
    #    ^ 迫击炮口在斜置炮管顶端 (110,100)，最左带中位会打在弹药箱上（探针网格实测）
    ("ww1_boss_av7",    "res://assets/card_icons/player/vis_player_042.png", 8, 12, False, True),
    # ── 原位重建（卡图与动画两门炮/残渣）──
    ("ww1_105mm",       "res://assets/card_icons/player/ww1_105mm.png",      8, 12, False, True),
    ("ww1_arty_77mm",   "res://assets/card_icons/player/vis_player_003.png", 8, 12, False, True),
    # ── 单列重建 ──
    # 37mm 源卡图本朝左（vis_player 里的例外），flip=False；炮口在炮管顶端 (62,38)，
    # 自动检测会打在左下角弹药车（探针网格实测）
    ("ww1_37mm",        "res://assets/card_icons/player/vis_player_088.png", 8, 10, False, False, (62, 38), ("attack",)),
    ("ww1_fort_pillbox","res://assets/card_icons/player/vis_player_072.png", 8, 12, False, True, None, ("idle",)),
]


def main():
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for case in CASES:
        key, card_res, idle_n, attack_n, air, flip = case[:6]
        muzzle = case[6] if len(case) > 6 and case[6] else None
        parts = case[7] if len(case) > 7 and case[7] else ("idle", "attack")
        out_dir = os.path.join(ra.ANIM, key)
        os.makedirs(out_dir, exist_ok=True)
        # 备份现役（仅一次；A 组同款规则）
        bdir = os.path.join(ra.BAK, key)
        os.makedirs(bdir, exist_ok=True)
        aj = os.path.join(out_dir, "anim.json")
        old_meta = json.load(open(aj, encoding="utf-8")) if os.path.isfile(aj) else {}
        old_counts = old_meta.get("counts", {})
        keep_idle, keep_attack = "idle" not in parts, "attack" not in parts
        if keep_idle:
            idle_n = int(old_counts.get("idle", idle_n) or idle_n)
        if keep_attack:
            attack_n = int(old_counts.get("attack", attack_n) or attack_n)
        for fn in ("sheet_idle.png", "sheet_attack.png", "anim.json", "attack_f0.png"):
            src = os.path.join(out_dir, fn)
            if os.path.isfile(src) and not os.path.isfile(os.path.join(bdir, fn)):
                ra.shutil.copy2(src, os.path.join(bdir, fn))
        # 卡图直出
        sub = ra.load_card(card_res, flip)
        cv = ra.to_canvas(sub, air)
        import numpy as np
        arr = np.asarray(cv)
        solid = arr[:, :, 3] > 8
        cols = np.where(solid.any(axis=0))[0]
        rows = np.where(solid.any(axis=1))[0]
        bb = (int(cols.min()), int(rows.min()), int(cols.max()), int(rows.max()))
        idle, atk = ra.build(cv, bb, air, idle_n, attack_n, muzzle)
        for anim, frames in (("idle", idle), ("attack", atk)):
            if anim not in parts:
                continue
            sh = ra.Image.new("RGBA", (ra.CANVAS * len(frames), ra.CANVAS), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                sh.paste(fr, (i * ra.CANVAS, 0))
            sh.save(os.path.join(ra.REV, "%s_%s_sheet_512.png" % (key, anim)))
            half = sh.resize((ra.FRAME * len(frames), ra.FRAME), ra.Image.LANCZOS)
            ra.dua.bake_outline_on_sheet(half).save(os.path.join(out_dir, "sheet_%s.png" % anim))
        meta = {"fps": old_meta.get("fps", 8), "frame_size": ra.FRAME,
                "counts": {"idle": idle_n, "attack": attack_n},
                "outline": ra.dua.outline_meta()}
        if old_meta.get("foot_frac") is not None:
            meta["foot_frac"] = old_meta["foot_frac"]
        json.dump(meta, open(aj, "w", encoding="utf-8"), ensure_ascii=False)
        print("[%s] parts=%s idle=%d attack=%d muzzle=%s 旧counts=%s md5 i=%s a=%s" % (
            key, "+".join(parts), idle_n, attack_n, muzzle, old_counts,
            ra.md5f(os.path.join(out_dir, "sheet_idle.png")),
            ra.md5f(os.path.join(out_dir, "sheet_attack.png"))))
    print("B 组直出完成（备份 %s/）" % os.path.relpath(ra.BAK, ROOT))


if __name__ == "__main__":
    main()
