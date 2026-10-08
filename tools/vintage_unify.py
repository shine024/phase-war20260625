# -*- coding: utf-8 -*-
"""资产年代统一批（2026-10-06）——用户口径：以后生成的为准。

病案分类（裁定来源：vintage_audit 双信号 + 四宫格目验，quad_1..5）：
  flip : cardP 落后 cardE（镜像债）      → cardP = fliplr(cardE)
  idle : idle 落后 atk（旧代设计）        → 4帧 code-bob 从 atk f0（bazooka 配方；
         atk 已烘描边，帧整体平移描边随行，不重烘；foot_frac 只描述 atk，不动）
  card : 卡图落后 atk（technical_e 新攻击=母本，用户指定）
         → 干净帧(argmin 面积) bbox→最长边450→512²居中（10-06 新卡批几何契约）

用法:
  python tools/vintage_unify.py preview   # 只出 _anim_review/_vintage_quad_6.png 供人工核
  python tools/vintage_unify.py apply    # 备份→写盘→md5 对照复读验证
"""
import hashlib
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIT = os.path.join(ROOT, "_anim_review", "vintage_audit.json")
BAK = os.path.join(ROOT, ".godot", "unit_review", "vintage_unify_bak")
FRAME = 256
IDLE_DY = (0, -1, -2, -1)
CARD_MAX = 450  # 10-06 批契约：bbox→最长边450→512²居中

# fam 行 id → 修复集
CASES = {
    "foe_ww2_arm_tiger":     ("flip",),                    # cardE 09-14 > cardP 09-09
    "foe_fut_arm_titan_mk2": ("flip",),                    # cardE 09-28 > cardP 09-26
    "foe_ww2_inf_bazooka":   ("flip",),                    # cardE 用户手改 10-06 15:57
    "ww2_air_dive_bomber":   ("flip",),                    # cardE SBD 重掷 10-06 15:39
    "mod_sup_m4_carbine":    ("flip",),                    # cardE 10-06 > cardP 10-05(旧沙漠迷彩)
    "ww1_inf_mp18_x":        ("flip", "idle"),             # +用户标注"待机"重做
    "ww2_arm_garand_para":   ("flip", "idle"),
    "foe_fut_arm_prism":     ("flip", "idle"),             # 用户首报：光棱坦克
    "mod_air_technical_e":   ("flip", "idle", "card"),     # 用户指定：新攻击帧=母本做卡图
}
# 预览附带终审：77mm SOFT 疑炮兵姿态误报（同代证据：palette 过/idle_atk .808/B5 谱系）
PREVIEW_EXTRA = ("ww1_arty_77mm",)


def rows():
    rep = json.load(open(AUDIT, encoding="utf-8"))
    out = {}
    for e in rep:
        if e["sec"] == "fam" and e["id"] in CASES:
            out[e["id"]] = e
        elif e["sec"] == "ind" and e["id"] in PREVIEW_EXTRA:
            out[e["id"]] = e
    return out


def frames_of(sheet_path, fs=FRAME):
    im = Image.open(sheet_path).convert("RGBA")
    n = im.size[0] // fs
    return [im.crop((i * fs, 0, (i + 1) * fs, fs)) for i in range(n)]


def clean_frame(sheet_path, fs=FRAME):
    """argmin 剪影面积帧（避火光烟）。"""
    fr = frames_of(sheet_path, fs)
    areas = [int((np.asarray(f)[:, :, 3] > 32).sum()) for f in fr]
    i = int(np.argmin(areas))
    return fr[i], i


def bob_idle(atk_path):
    """atk f0 → 4 帧 dy bob（帧随移，描边已在像素里跟着走，不重烘）。"""
    base = frames_of(atk_path)[0]
    out = Image.new("RGBA", (FRAME * len(IDLE_DY), FRAME), (0, 0, 0, 0))
    for i, dy in enumerate(IDLE_DY):
        cell = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        cell.paste(base, (0, dy))
        out.alpha_composite(cell, (i * FRAME, 0))
    return out


def derive_card(frame):
    """干净帧 → 512² 卡图（bbox→最长边 450→居中）。"""
    a = np.asarray(frame)
    m = a[:, :, 3] >= 16
    ys, xs = np.where(m)
    sub = frame.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    w, h = sub.size
    sc = CARD_MAX / float(max(w, h))
    nw, nh = max(1, int(round(w * sc))), max(1, int(round(h * sc)))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    cv.alpha_composite(sub, ((512 - nw) // 2, (512 - nh) // 2))
    return cv


def md5(b):
    return hashlib.md5(b).hexdigest()


def save_verified(img, path, bakdir):
    """备份→写盘→复读 md5 对照（改图写盘验证铁律）。"""
    os.makedirs(bakdir, exist_ok=True)
    if os.path.exists(path):
        shutil.copy2(path, os.path.join(bakdir, os.path.basename(path) + ".bak"))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    img.save(path)
    back = open(path, "rb").read()
    ok = md5(back) == md5(buf.getvalue())
    print("  [%s] %s (%d B)" % ("OK" if ok else "FAIL", os.path.relpath(path, ROOT), len(back)))
    return ok


def save_json_verified(obj, path, bakdir):
    os.makedirs(bakdir, exist_ok=True)
    if os.path.exists(path):
        shutil.copy2(path, os.path.join(bakdir, os.path.basename(path) + ".bak"))
    data = json.dumps(obj, ensure_ascii=False)
    with open(path, "w", encoding="utf-8") as f:
        f.write(data)
    back = open(path, encoding="utf-8").read()
    ok = back == data
    print("  [%s] %s" % ("OK" if ok else "FAIL", os.path.relpath(path, ROOT)))
    return ok


def P(p):
    return os.path.join(ROOT, p) if not os.path.isabs(p) else p


def preview(rs):
    out = os.path.join(ROOT, "_anim_review", "_vintage_quad_6.png")
    QW, LBL, PAD = 256, 24, 10
    rows_spec = []

    def cell(im, size=QW):
        if im.size[0] != size or im.size[1] != size:
            im = im.resize((size, size), Image.LANCZOS)
        return im

    # 行1: 77mm 终审（cardE / idle f0 / atk 干净帧）
    e = rs["ww1_arty_77mm"]
    atk_c, ci = clean_frame(P(e["files"]["atk"]))
    rows_spec.append(("1.ww1_arty_77mm 终审(同代?) cA=%.2f" % e["iou"]["cardE_atk"],
                      [Image.open(P(e["files"]["cardE"])).convert("RGBA"),
                       frames_of(P(e["files"]["idle"]))[0], atk_c],
                      ["cardE", "idle f0", "atk clean f%d" % ci]))
    # 行2: technical_e 新卡推导预览（推导卡 / atk f0 / 旧卡）
    e = rs["mod_air_technical_e"]
    atk_f = frames_of(P(e["files"]["atk"]))[0]  # f0 火光=0 且与 bob idle 同帧（三态同源）
    new_card = derive_card(atk_f)
    rows_spec.append(("2.mod_air_technical_e 推导预览(atk f0 零火光)",
                      [new_card, atk_f, Image.open(P(e["files"]["cardE"])).convert("RGBA")],
                      ["新推导卡图", "母本 atk f0", "旧卡图"]))
    # 行3: bob 预览（prism atk f0 原帧 vs bob 帧3 dy=-2）
    e = rs["foe_fut_arm_prism"]
    b = bob_idle(P(e["files"]["atk"]))
    rows_spec.append(("3.fut_arm_prism bob 预览",
                      [frames_of(P(e["files"]["atk"]))[0],
                       b.crop((0, 0, FRAME, FRAME)), b.crop((3 * FRAME, 0, 4 * FRAME, FRAME))],
                      ["atk f0=idle f0", "idle f0", "idle f3 dy=-2"]))

    W = QW * 3 + PAD * 4
    H = sum(QW + LBL + PAD for _ in rows_spec) + PAD
    sheet = Image.new("RGBA", (W, H), (12, 14, 18, 255))
    dr = ImageDraw.Draw(sheet)
    y = PAD
    for label, cells, caps in rows_spec:
        dr.text((PAD, y), label, fill=(255, 220, 120, 255))
        y += LBL
        x = PAD
        for c, cap in zip(cells, caps):
            sheet.alpha_composite(cell(c), (x, y))
            dr.text((x + 2, y + QW + 2), cap, fill=(140, 160, 190, 255))
            x += QW + PAD
        y += QW + PAD
    sheet.convert("RGB").save(out)
    print("PREVIEW -> %s (%dx%d)" % (os.path.relpath(out, ROOT), W, H))


def apply(rs):
    all_ok = True
    for cid, fixes in CASES.items():
        e = rs[cid]
        bakdir = os.path.join(BAK, cid)
        fE, fP = P(e["files"]["cardE"]), P(e["files"]["cardP"])
        print("== %s (%s)" % (cid, "+".join(fixes)))
        if "card" in fixes:
            # f0 = 零火光（f2 达 1011 火光px；f4 虽最小面积仍带 52px）且与 bob idle 同帧
            atk_f = frames_of(P(e["files"]["atk"]))[0]
            card = derive_card(atk_f)
            print("  卡图取帧: atk f0(零火光) → 512²")
            all_ok &= save_verified(card, fE, bakdir)
        if "flip" in fixes:
            flipped = Image.open(fE).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
            all_ok &= save_verified(flipped, fP, bakdir)
        if "idle" in fixes:
            idle = bob_idle(P(e["files"]["atk"]))
            all_ok &= save_verified(idle, P(e["files"]["idle"]), bakdir)
            aj = os.path.join(os.path.dirname(P(e["files"]["atk"])), "anim.json")
            meta = json.load(open(aj, encoding="utf-8"))
            meta["counts"]["idle"] = len(IDLE_DY)
            all_ok &= save_json_verified(meta, aj, bakdir)
    print("APPLY %s" % ("ALL_OK" if all_ok else "HAS_FAILURES"))
    return all_ok


if __name__ == "__main__":
    rs = rows()
    missing = [c for c in CASES if c not in rs] + [c for c in PREVIEW_EXTRA if c not in rs]
    if missing:
        print("audit 行缺失:", missing)
        sys.exit(1)
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if mode == "preview":
        preview(rs)
    elif mode == "apply":
        sys.exit(0 if apply(rs) else 2)
    else:
        print("用法: preview | apply")
        sys.exit(1)
