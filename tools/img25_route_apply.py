# -*- coding: utf-8 -*-
"""img25 三方式决策台拍板结果应用器（消费 .godot/unit_review/img25_route_decisions.json）。

--adopt-r3   15 个 sel=route3 单位：codeanim 10 帧闭环(512²×5×2) → 256 降采样 →
             描边烘焙(deploy_unit_anims.bake_outline_on_sheet) → 覆盖部署
             assets/effects/unit_anims/<key>/sheet_attack.png，counts.attack=10，
             anim.json 其余字段不动；旧件先备份 .godot/art_backup_route3_20261001/。
             加载器 attack=正向单次回 idle（unit_frame_anim.gd），f9==f0 闭环无倒放 artefact。
--worklist   输出剩余工作清单 JSON+MD（redo3 批产/抠图修/方向帧修/换卡图/雷达转动/特例）。

用法：
    python -X utf8 tools/img25_route_apply.py --adopt-r3 [--keys k1,k2]
    python -X utf8 tools/img25_route_apply.py --worklist
"""
import json
import os
import shutil
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deploy_unit_anims import bake_outline_on_sheet, outline_meta
from codeanim_gen import UNITS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UR = os.path.join(ROOT, ".godot", "unit_review")
DEC = os.path.join(UR, "img25_route_decisions.json")
ANIM_ROOT = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_route3_20261001")
CELL, COLS = 512, 5
FRAME = 256


def bake_outline_body_only(sheet, frame=FRAME, w_px=4, color=(13, 18, 28, 217),
                           feather=0.6, keep_frac=0.4):
    """deploy_unit_anims.bake_outline_on_sheet 的 VFX 保护变体：
    每帧切片内只对"本体"（面积 ≥ 最大连通域×keep_frac 的组件）描边，
    悬浮 VFX（烟团/曳光点/抛壳）不包边——256 尺度 4px 描边会反超小烟团体量，
    把过审 codeanim 里干净的灰烟变成深色圆角块（10-01 cold_mig21 实测）。"""
    import numpy as np
    import cv2
    arr = np.asarray(sheet).copy()
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * w_px + 1, 2 * w_px + 1))
    for i in range(arr.shape[1] // frame):
        x0, x1 = i * frame, (i + 1) * frame
        cell = arr[:, x0:x1]
        a = cell[..., 3]
        mask = (a > 16).astype(np.uint8)
        if not mask.any():
            continue
        n, lab = cv2.connectedComponents(mask)
        if n <= 1:
            continue
        sizes = np.bincount(lab.ravel())
        sizes[0] = 0
        keep = np.zeros(n, dtype=bool)
        keep[1:] = sizes[1:] >= sizes.max() * keep_frac
        body = keep[lab]
        dil = cv2.dilate(body.astype(np.uint8) * 255, k) > 0
        zone = dil & (a < 16)
        if not zone.any():
            continue
        layer = np.zeros_like(cell)
        layer[..., 0], layer[..., 1], layer[..., 2] = color[0], color[1], color[2]
        layer[..., 3] = np.where(zone, color[3], 0)
        layer[..., 3] = cv2.GaussianBlur(layer[..., 3], (0, 0), feather)
        lf = layer.astype(np.float32)
        cf = cell.astype(np.float32)
        la = lf[..., 3:4] / 255.0
        ca = cf[..., 3:4] / 255.0
        t = np.clip((ca - 0.02) / (0.38 - 0.02), 0.0, 1.0)
        la = la * (1.0 - t * t * (3.0 - 2.0 * t))
        oa = la + ca * (1.0 - la)
        mixed = np.where(oa > 0, (lf * la + cf * ca * (1.0 - la)) / np.maximum(oa, 1e-6), 0.0)
        out = np.where(la > 0, mixed, cf)
        arr[:, x0:x1] = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def load_decisions():
    for p in (DEC, os.path.join(UR, "img25_route_decisions (1).json")):
        if os.path.exists(p):
            return json.load(open(p, encoding="utf-8"))
    sys.exit("缺决策文件 img25_route_decisions.json")


def adopt_r3(keys_filter=None, dry=False, no_outline=False):
    dec = load_decisions()
    keys = sorted(k for k, v in dec.items() if v.get("sel") == "route3")
    if keys_filter:
        keys = [k for k in keys if k in set(keys_filter)]
    _deploy_keys(keys, dry, no_outline)


def adopt_keys(keys, dry=False, no_outline=False):
    """按显式名单部署（拍板 reroll→3 的 redo 批不走 sel=route3 口径）。"""
    _deploy_keys(sorted(keys), dry, no_outline)


def _deploy_keys(keys, dry, no_outline=False):
    ok, fail = [], []
    for key in keys:
        cfg = UNITS.get(key)
        sheet_p = os.path.join(UR, "codeanim", "%s_codeanim_sheet.png" % key)
        dst_dir = os.path.join(ANIM_ROOT, key)
        if not os.path.exists(sheet_p) or not os.path.isdir(dst_dir):
            fail.append((key, "缺 codeanim 产物或缺部署目录"))
            continue
        if cfg is None:
            print("[提示] %s 不在内置 UNITS（外部配置单位），照常部署" % key)
        im = Image.open(sheet_p).convert("RGBA")
        frames = [im.crop(((i % COLS) * CELL, (i // COLS) * CELL,
                           (i % COLS) * CELL + CELL, (i // COLS) * CELL + CELL))
                  .resize((FRAME, FRAME), Image.LANCZOS) for i in range(COLS * 2)]
        sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            sheet.paste(f, (i * FRAME, 0))
        # --no-outline：批量旗（10-02 锚定换装批 35 单位——备份 f0 本尊锚自带原版描边）；
        # cfg 级 outline=False 旋钮仍优先（gmc 先例）。
        # 10-02 修复：原写法 `no_outline or cfg.outline(默认True)` 恒真，--no-outline
        # 从未生效，全部历史部署都被二次烘边（描边加倍=用户"亮度不对"实感来源之一）。
        bake = (cfg or {}).get("outline", True)
        if no_outline:
            bake = False
        if bake:
            sheet = bake_outline_body_only(sheet)
        aj_p = os.path.join(dst_dir, "anim.json")
        aj = json.load(open(aj_p, encoding="utf-8"))
        if dry:
            print("[dry][%s] 10帧 attack, 旧 counts=%s" % (key, aj["counts"]))
            continue
        bdir = os.path.join(BAK, key)
        os.makedirs(bdir, exist_ok=True)
        for fn in ("sheet_attack.png", "anim.json"):
            src = os.path.join(dst_dir, fn)
            bak_f = os.path.join(bdir, fn)
            if os.path.exists(src) and not os.path.exists(bak_f):
                shutil.copy2(src, bak_f)
        sheet.save(os.path.join(dst_dir, "sheet_attack.png"))
        old_n = aj["counts"].get("attack")
        aj["counts"]["attack"] = len(frames)
        aj["outline"] = outline_meta()
        json.dump(aj, open(aj_p, "w", encoding="utf-8"), ensure_ascii=False)
        ok.append((key, old_n, len(frames)))
        print("[%s] attack %s帧→%d帧 已部署（备份 %s）" % (key, old_n, len(frames), bdir))
    print("=== adopt-r3 完成 %d 失败 %d ===" % (len(ok), len(fail)))
    for k, why in fail:
        print("  FAIL", k, why)


def worklist():
    dec = load_decisions()
    wl = {}
    redo3, keep1, card_redo, matte_fix, facing_fix, radar_rot, special = [], [], [], [], [], [], []
    CARD_REDO_KEYS = {"platform_future_radar": "原卡图重新生成", "platform_modern_stealth": "原卡图不好重新生成",
                      "ww1_105mm": "原卡图不行重新生成", "ww1_a7v": "原卡图重新生成", "ww1_lanchest": "原卡图重新生成",
                      "ww1_mark4": "原图重生成", "ww2_air_dive_bomber": "原图重新生成",
                      "mod_ranger": "半身换全身", "mod_stinger": "原卡图可换", "mod_stryker_m2": "原卡图可换",
                      "mod_sup_m4_carbine": "半身换全身"}
    for k, v in sorted(dec.items()):
        sel, rr, note = v.get("sel", ""), v.get("reroll", ""), v.get("note", "")
        if sel == "route1":
            keep1.append(k)
        if rr == "3" and sel != "route3":
            redo3.append(k)
        if k in CARD_REDO_KEYS:
            card_redo.append((k, CARD_REDO_KEYS[k]))
        if any(w in note for w in ("抠图", "没抠好")):
            matte_fix.append(k)
        if "方向不对" in note or "方向不对" in note.replace(" ", ""):
            facing_fix.append(k)
        if k in ("cold_arm_p18", "cold_fort_radar", "platform_cold_radar", "platform_future_radar",
                 "platform_modern_radar", "platform_ww1_radar"):
            radar_rot.append(k)
        if k == "ww2_sup_gmc_truck":
            special.append((k, "attack=idle 合法现状，勿动（AGENTS 五单位口径）"))
        if k == "drop_phase_lance":
            special.append((k, "锚定重做：枪放平、图中不应有无人机；重做后重跑 codeanim_gen 再部署"))
        if k == "mod_air_bomber":
            special.append((k, "弹道调整：丢下导弹向前发射（codeanim bomb 参数）"))
        if k == "ww2_t34_85":
            special.append((k, "方向错帧+火光出格：建议并入 redo3 批（同坦克族）"))
        if k == "guardian_future_omega":
            special.append((k, "原图已抬枪只开火——现 codeanim vfx 配置即只开火，核对即可"))
        if k == "cold_rpg":
            special.append((k, "已采纳 route1；方向错帧+抠图待 500px 逐格复核后 flip/清渍"))
    wl["adopt_route3_deployed"] = "见 --adopt-r3 输出"
    wl["keep_route1"] = keep1
    wl["redo3_new_codeanim"] = sorted(set(redo3) - set(k for k, _ in card_redo))
    wl["card_regenerate"] = card_redo
    wl["matte_cleanup"] = matte_fix
    wl["facing_frame_fix"] = facing_fix
    wl["radar_rotation_codeanim"] = radar_rot
    wl["special_notes"] = special
    out = os.path.join(UR, "img25_route_worklist.json")
    json.dump(wl, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("worklist ->", out)
    for k in ("keep_route1", "redo3_new_codeanim", "card_regenerate", "matte_cleanup",
              "facing_frame_fix", "radar_rotation_codeanim", "special_notes"):
        print(" %-24s %d" % (k, len(wl[k])))


if __name__ == "__main__":
    argv = sys.argv[1:]
    if "--adopt-r3" in argv or "--adopt-keys" in argv:
        kf = None
        for i, a in enumerate(argv):
            if a in ("--keys", "--adopt-keys") and i + 1 < len(argv):
                kf = [x.strip() for x in argv[i + 1].split(",") if x.strip()]
        if "--adopt-keys" in argv:
            adopt_keys(kf or [], dry="--dry" in argv, no_outline="--no-outline" in argv)
        else:
            adopt_r3(kf, dry="--dry" in argv, no_outline="--no-outline" in argv)
    elif "--worklist" in argv:
        worklist()
    else:
        print(__doc__)
