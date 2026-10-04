# -*- coding: utf-8 -*-
"""B4/R2 暂存卡图部署：staging → assets/card_icons/（41 目标）。
- plat 24 → card_icons/<pid>.png（card_icon_path_for 分支0 专属卡面，根目录）
- regen 6 → player/enemy 成对（宪法口径：生成朝右，player=直出，enemy=FLIP）；phantom 仅 player
- derive 6 → player/enemy 060/065/061（061 对=R2 真生图版；060/065 与现役同源，md5 预期不变）
配方：flood_white_to_alpha(238)（边界泛洪，保主体内高光）→ fit_square(512, 0.88)；已透明输入直过。
门：先备份 .godot/art_backup_b4_deploy_20261004/ → md5 覆盖门 → 规格扫描（512 RGBA/角透明/主体不触边）。
用法: python tools/_b4_deploy.py
"""
import hashlib
import io
import json
import os
import shutil
import sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
BACKUP = os.path.join(ROOT, ".godot", "art_backup_b4_deploy_20261004")
ICONS = os.path.join(ROOT, "assets", "card_icons")


def load(name, path):
    import types
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines() if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


img25 = load("b4d_img25", os.path.join(ROOT, "tools", "img25_card_sideview_redo.py"))
flood_white_to_alpha = img25.flood_white_to_alpha
fit_square = img25.fit_square
grow_alpha = img25.grow_alpha

PLAT_IDS = ["%s_%s" % (f, t) for f in ("flame_raider", "flame_siege", "steel_fortress", "steel_titan",
                                       "thunter_striker", "thunter_sniper", "void_stealth", "void_mage")
            for t in ("basic", "advanced", "expert")]
# staging raw cid → (player 相对 card_icons, enemy 相对或 None)
PAIR = {
    "mod_arm_stryker_e":   ("player/vis_player_059.png", "enemy/vis_enemy_059.png"),
    "fut_arm_prism":       ("player/vis_player_026.png", "enemy/vis_enemy_026.png"),
    "ww1_arm_rolls":       ("player/vis_player_001.png", "enemy/vis_enemy_001.png"),
    "ww1_inf_mp18_x":      ("player/ww1_inf_mp18_x.png", "enemy/ww1_inf_mp18_x.png"),
    "mod_inf_scout_drone": ("player/vis_player_022.png", "enemy/vis_enemy_022.png"),
    "fe_helix_phantom":    ("player/fe_helix_phantom.png", None),
}
DERIVE = ["vis_player_060.png", "vis_enemy_060.png", "vis_player_065.png", "vis_enemy_065.png",
          "vis_player_061.png", "vis_enemy_061.png"]


def md5(p):
    with open(p, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def has_opaque_bg(im):
    """边角是否不透明（需要泛洪）。"""
    a = np.asarray(im.convert("RGBA"))[:, :, 3]
    border = np.concatenate([a[:4].ravel(), a[-4:].ravel(), a[:, :4].ravel(), a[:, -4:].ravel()])
    return float(border.mean()) > 200


def convert(raw_path):
    """staging 图 → 部署用 512 RGBA 透明底。"""
    im = Image.open(raw_path)
    if has_opaque_bg(im):
        im = flood_white_to_alpha(im, 238)
        im = grow_alpha(im, 215, max_iter=30)  # 除浅色地影残边（未登记户自适应）
    return fit_square(im, 512, 0.88)


def main():
    jobs = []  # (staging源, 目标绝对路径, 是否翻转enemy)
    for pid in PLAT_IDS:
        jobs.append((os.path.join(STAGE, "%s_raw.png" % pid),
                     os.path.join(ICONS, "%s.png" % pid), False))
    for cid, (prel, erel) in PAIR.items():
        rp = os.path.join(STAGE, "%s_raw.png" % cid)
        jobs.append((rp, os.path.join(ICONS, prel), False))
        if erel:
            jobs.append((rp, os.path.join(ICONS, erel), True))
    for f in DERIVE:
        jobs.append((os.path.join(STAGE, f), os.path.join(ICONS, "player" if f.startswith("vis_player") else "enemy", f), False))

    # 1) 备份全部目标 + md5 清单
    os.makedirs(BACKUP, exist_ok=True)
    manifest, missing_backup = {}, []
    for _, dst, _f in jobs:
        rel = os.path.relpath(dst, ROOT)
        if os.path.isfile(dst):
            bdst = os.path.join(BACKUP, rel)
            os.makedirs(os.path.dirname(bdst), exist_ok=True)
            shutil.copy2(dst, bdst)
            manifest[rel] = md5(dst)
        else:
            missing_backup.append(rel)
            manifest[rel] = ""
    with open(os.path.join(BACKUP, "_md5_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print("备份 %d 个现存目标 → %s（另 %d 个为新文件）" % (
        len(manifest) - len(missing_backup), BACKUP, len(missing_backup)))

    # 2) 转换+写入
    ok = fail = same = 0
    for src, dst, flip in jobs:
        if not os.path.isfile(src):
            print("[FAIL] 缺 staging 源:", src)
            fail += 1
            continue
        im = convert(src)
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(dst)
        rel = os.path.relpath(dst, ROOT)
        if manifest.get(rel) and md5(dst) == manifest[rel]:
            same += 1
        else:
            ok += 1
    print("写入完成：更新 %d，内容未变 %d，失败 %d" % (ok, same, fail))

    # 3) 规格扫描（512 RGBA / 角透明 / 主体不触边）
    bad = []
    for _, dst, _f in jobs:
        a = np.asarray(Image.open(dst).convert("RGBA"))
        h, w = a.shape[:2]
        corners = [a[0, 0, 3], a[0, -1, 3], a[-1, 0, 3], a[-1, -1, 3]]
        body = a[:, :, 3] > 20
        ys, xs = np.where(body)
        margin = min(xs.min(), ys.min(), w - 1 - xs.max(), h - 1 - ys.max()) if len(xs) else -1
        if (w, h) != (512, 512) or max(corners) > 0 or margin < 8:
            bad.append("%s size=%dx%d corners=%s margin=%d" % (
                os.path.relpath(dst, ROOT), w, h, corners, margin))
    if bad:
        print("规格门异常 %d:" % len(bad))
        for b in bad:
            print("  ", b)
    else:
        print("规格门全过：41 目标 512 RGBA / 角透明 / 主体留边 ≥8px")


if __name__ == "__main__":
    main()
