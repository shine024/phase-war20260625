# -*- coding: utf-8 -*-
"""m1a2sep 卡图本地推导（备选路线，不落 assets）。

源=.godot/unit_review/img25_approved/mod_m1a2_anchor_raw.png（img25 拍板版=用户「有一版
是可以的」），load_anchor 全清（chroma_key+depink+边晕回填）→ derive_card（bbox→450→512²）
→ cardE(朝左) + cardP(镜像)。staging 进 fam44_cards_redo/ 与 API 生图批同台目检。
用法: python tools/_fam44_m1a2_card_local.py
"""
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
import codeanim_gen as cg  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam44_cards_redo")
CARD_MAX = 450


def derive_card(frame):
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


def on_dark(im, size=256):
    bg = Image.new("RGBA", im.size, (24, 24, 28, 255))
    bg.alpha_composite(im.convert("RGBA"))
    return bg.convert("RGB").resize((size, size), Image.LANCZOS)


def main():
    rgba = cg.load_anchor("mod_m1a2")
    a = np.asarray(rgba)
    body = (a[:, :, 3] >= 16)
    ys, xs = np.where(body)
    print("锚定本体 bbox x[%d,%d] y[%d,%d] px=%d 朝向=%s" % (
        xs.min(), xs.max(), ys.min(), ys.max(), body.sum(),
        "左(枪口在左)" if _nose_x(a) < 512 else "右"))
    card_e = derive_card(rgba)
    card_p = card_e.transpose(Image.FLIP_LEFT_RIGHT)
    card_e.save(os.path.join(STAGE, "mod_arm_m1a2sep_cardE_local.png"))
    card_p.save(os.path.join(STAGE, "mod_arm_m1a2sep_cardP_local.png"))

    # 三联对比：现役卡(批B=idle f0) vs 本地推导(锚定) —— 同暗底
    cur = Image.open(os.path.join(ROOT, "assets/card_icons/enemy/vis_enemy_023.png"))
    trip = Image.new("RGB", (3 * 256 + 20, 256), (18, 20, 24))
    trip.paste(on_dark(cur), (0, 0))
    trip.paste(on_dark(card_e), (256 + 10, 0))
    trip.paste(on_dark(card_p), (2 * (256 + 10), 0))
    trip.save(os.path.join(STAGE, "mod_arm_m1a2sep_local_vs_cur.jpg"), quality=90)
    print("staged: mod_arm_m1a2sep_cardE/P_local.png + 对比图 (左=现役 中=新E 右=新P)")


def _nose_x(a):
    """最重火器端在哪侧：取本体 bbox 左/右 1/5 段的不透明像素量，士兵/坦克枪炮侧更碎更长。"""
    m = a[:, :, 3] >= 16
    ys, xs = np.where(m)
    return (xs.min() + xs.max()) / 2.0


if __name__ == "__main__":
    main()
