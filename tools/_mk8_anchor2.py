# -*- coding: utf-8 -*-
"""MK8 锚定批 2（2026-10-05）：fe_void_dimensional_soldier / fe_iron_wall_juggernaut
抬枪手术判死（前者枪反持几何死路，后者枪托压肩盒提必撕甲）→ 走 m4 同款锚定路线：
玩家卡图（朝右）img2img 锚定帧 → 全身校验 → idle 8f → attack 3×2 cells（朝右 extra）。
注意：本批锚定面朝【正右】（与现役 sheet 朝向一致），须 patch anchor_gen 的朝左硬锁。
产物只落 staging；部署另跑 _mk8_deploy.py。
用法: python tools/_mk8_anchor2.py
"""
import io
import json
import os
import subprocess
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG_A = os.path.join(ROOT, ".godot", "unit_review", "mk8_staging")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
os.makedirs(STG_A, exist_ok=True)
os.makedirs(OUT, exist_ok=True)


def load(name, path):
    src = open(path, encoding="utf-8").read()
    # 只剥顶层 wrapper 行（startswith）；嵌套引用该串的行必须保留（10-05 二次踩坑）
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load("mk8_ag", os.path.join(ROOT, "tools", "img25_anchor_gen.py"))
agk = load("mk8_agk", os.path.join(ROOT, "tools", "img25_attack_gen.py"))
img25 = load("mk8_img25", os.path.join(ROOT, "tools", "img25_card_sideview_redo.py"))

from PIL import Image  # noqa: E402
import numpy as np  # noqa: E402

# ── 朝向 patch：锚定帧朝正右（玩家朝向，与现役 sheet 一致）─────────
_orig_build = ag.build_prompt


def build_prompt_r(subject):
    p = _orig_build(subject)
    return p.replace("面朝画面正左方，绝不朝右", "面朝画面正右方，绝不朝左")


ag.build_prompt = build_prompt_r

UNITS = {
    "fe_void_dimensional_soldier": (
        "参考图中的这名虚空相位次元行者（男性超级步兵，深灰紫色贴身动力装甲、"
        "紫色能量纹路、深色短发，双手持一柄紫色虚空能量步枪收于身前）",
        dict(seq="虚空能量步枪三连射",
             cells={"1": "步枪抬平指向正前方，枪口凝聚紫色能量光球",
                    "2": "枪口爆发紫色能量光芒，紫色火花四溅",
                    "3": "紫光衰减，枪口萦绕紫色余辉",
                    "4": "枪身被后坐轻推，紫色余辉消散",
                    "5": "回到待机持枪"},
             fx="只有紫色能量光效与火花，无实弹弹道无曳光，绝无橙色火光"),
    ),
    "fe_iron_wall_juggernaut": (
        "参考图中的这名钢壁防务重装先驱（重型装甲超级步兵，灰黑色复合反应装甲板、"
        "蓝色能量裂纹、全覆式头盔蓝色目镜，双手持一柄重型科幻战斗步枪收于身前）",
        dict(seq="重型战斗步枪点射",
             cells={"1": "枪托抵肩微微上抬，枪口泛起点点微光",
                    "2": "枪口爆出大团橙白色火光，弹壳向后方抛出",
                    "3": "火光衰减，枪口青烟拉出一缕",
                    "4": "枪身被重后坐推退，枪口余烟",
                    "5": "回到待机持枪"},
             fx="只要枪口火光与硝烟弹壳，无弹道无曳光"),
    ),
}

EXTRA_RIGHT = ("Strictly flat side profile facing right: the camera is exactly at the subject's "
               "own side, level with its midline; the subject's long axis stretches horizontally "
               "across the whole image, its upright parts stay vertical, no perspective "
               "foreshortening. Zoomed-out wide framing: the whole subject fully inside each cell "
               "with generous empty space on all four sides, far from the cell edges.")


def fullbody_check(keyed):
    """半身的真判别 = 身体被画布底边裁切；高宽比不作门槛（宽姿全身 1.2-1.4）。"""
    a = np.asarray(keyed)
    ys, xs = np.where(a[:, :, 3] > 40)
    if not len(ys):
        return False, "empty"
    h = ys.max() - ys.min() + 1
    w = xs.max() - xs.min() + 1
    touches = ys.max() >= keyed.height - 6
    return not touches, "h=%d w=%d ratio=%.2f touches_bottom=%s" % (
        h, w, h / max(w, 1), touches)


def build_idle(key):
    """锚定帧 → 键控/depink/主体保留/bbox → 512 基 fit（底缘锚定）→ 8 帧微呼吸环。"""
    raw = Image.open(os.path.join(OUT, key + "_anchor_raw.png")).convert("RGB")
    rgba = ag.chroma_key(raw)
    rgba = agk.depink(rgba)
    rgba = agk.keep_main_bodies(rgba, 0.35)
    box = agk.alpha_bbox(rgba)
    if box is None:
        print("[idle:%s] 键控后空图！" % key, flush=True)
        return False
    body = rgba.crop(box)
    FS2 = 512
    w, h = body.size
    sc = min((FS2 - 40) / w, (FS2 - 40) / h, 1.6)
    body = body.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    base = Image.new("RGBA", (FS2, FS2), (0, 0, 0, 0))
    base.paste(body, ((FS2 - body.width) // 2, FS2 - 16 - body.height), body)
    a0 = np.asarray(base)
    up = np.roll(a0, -2, axis=0)
    up[-2:, :] = 0
    loop = [a0, a0, up, up, a0, a0, a0, a0]
    sheet = Image.new("RGBA", (8 * FS2, FS2), (0, 0, 0, 0))
    for i, f in enumerate(loop):
        sheet.paste(Image.fromarray(f), (i * FS2, 0))
    sheet.save(os.path.join(OUT, "%s_idle_sheet_512.png" % key))
    g = Image.new("RGBA", (4 * 256, 2 * 256), (40, 44, 52, 255))
    for i, f in enumerate(loop):
        fr = Image.fromarray(f).resize((256, 256), Image.LANCZOS)
        g.paste(fr, (i % 4 * 256, i // 4 * 256), fr)
    g.convert("RGB").save(os.path.join(STG_A, "%s_idle_grid_preview.png" % key))
    print("[idle:%s] OK" % key, flush=True)
    return True


def main():
    for key, (subject, cells) in UNITS.items():
        print("== %s ==" % key, flush=True)
        raw_p = os.path.join(OUT, key + "_anchor_raw.png")
        if not os.path.isfile(raw_p):  # 中断续跑：已有锚定帧则跳过重掷
            sys.argv = ["img25_anchor_gen.py", key,
                        os.path.join(ROOT, "assets", "card_icons", "player", key + ".png"),
                        "--subject", subject, "--chroma-out"]
            try:
                ag.main()
            except SystemExit:
                pass
        if not os.path.isfile(raw_p):
            print("[FAIL] %s 锚定无果" % key, flush=True)
            continue
        raw = Image.open(raw_p).convert("RGB")
        keyed = ag.chroma_key(raw)
        keyed = agk.depink(keyed)
        keyed = agk.keep_main_bodies(keyed, 0.35)
        ok, info = fullbody_check(keyed)
        print("  全身校验: ok=%s %s" % (ok, info), flush=True)
        if not ok:
            os.remove(raw_p)
            print("[FAIL] %s 非全身（半身/触底），删 raw 重跑本脚本重掷" % key, flush=True)
            continue
        keyed.save(os.path.join(OUT, key + "_anchor_keyed.png"))
        build_idle(key)
        cj = os.path.join(OUT, "_mk8_cells_%s.json" % key)
        with open(cj, "w", encoding="utf-8") as f:
            json.dump(dict(cells, extra=EXTRA_RIGHT), f, ensure_ascii=False)
        rc = subprocess.call([sys.executable, os.path.join(ROOT, "tools", "img25_attack_gen.py"),
                              key, "--subject", subject, "--rolls", "2", "--cells-json", cj],
                             cwd=ROOT)
        print("[%s] anchor+idle 完成；attack rc=%d（2 掷落 img25_staging）" % (key, rc), flush=True)
    print("MK8 锚定批 2 结束", flush=True)


if __name__ == "__main__":
    main()
