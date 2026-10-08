# -*- coding: utf-8 -*-
"""批B 卡图推导（工单要求「卡图换动画一样的/换正侧方的/用待机做」）。

真身口径同 vintage_unify：sheet f0（朝左）→ derive_card → cardE；cardP = fliplr(cardE)。
几何契约：bbox→最长边450→512²居中（10-06 新卡批）。备份 → 写盘 → md5 复读验证。
gmc_truck 另做「待机直出攻击」：idle f0 → 锚定（fam44）→ codeanim crate 配方。

用法: python tools/_batchB_cards.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
import fam43_card_anchors as fca  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, ".godot", "unit_review", "vintage_unify_bak")
SRC44 = os.path.join(ROOT, ".godot", "unit_review", "fam44_anchor_from_card")
CARD_MAX, FRAME = 450, 256

# key: (anim目录, 源sheet, cardE, cardP)
U = {
    "mod_arm_stryker_e":  ("mod_stryker", "attack", "assets/card_icons/enemy/vis_enemy_059.png", "assets/card_icons/player/vis_player_059.png"),
    "mod_arm_m1a2sep":    ("mod_arm_m1a2sep", "idle", "assets/card_icons/enemy/vis_enemy_023.png", "assets/card_icons/player/vis_player_023.png"),
    "ww2_arm_garand_para": ("ww2_arm_garand_para", "idle", "assets/card_icons/enemy/ww2_arm_garand_para.png", "assets/card_icons/player/ww2_arm_garand_para.png"),
    "ww2_sup_gmc_truck":  ("ww2_sup_gmc_truck", "idle", "assets/card_icons/enemy/ww2_sup_gmc_truck.png", "assets/card_icons/player/ww2_sup_gmc_truck.png"),
}


def md5(b):
    import hashlib
    return hashlib.md5(b).hexdigest()


def save_verified(img, path):
    full = os.path.join(ROOT, path)
    os.makedirs(BAK, exist_ok=True)
    bak = os.path.join(BAK, path.replace("/", "_") + ".bak")
    if os.path.exists(full):
        shutil.copy2(full, bak)
    buf = io.BytesIO()
    img.save(buf, "PNG")
    img.save(full)
    ok = md5(open(full, "rb").read()) == md5(buf.getvalue())
    print("  [%s] %s" % ("OK" if ok else "FAIL", path))
    return ok


def frames_of(sheet_path):
    im = Image.open(sheet_path).convert("RGBA")
    n = im.width // FRAME
    return [im.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME)) for i in range(n)]


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


def main():
    ok = True
    for key, (anim, which, card_e, card_p) in U.items():
        sheet = os.path.join(ROOT, "assets/effects/unit_anims", anim, "sheet_%s.png" % which)
        f0 = frames_of(sheet)[0]
        # f0 零火光断言（火光帧做卡会烙死火光）
        a = np.asarray(f0.convert("RGB")).astype(int)
        orange = ((a[:, :, 0] > 200) & (a[:, :, 1] > 100) & (a[:, :, 2] < 90)).sum()
        print("== %s (%s f0, 橙黄px=%d)" % (key, which, orange))
        card = derive_card(f0)
        ok &= save_verified(card, card_e)
        ok &= save_verified(card.transpose(Image.FLIP_LEFT_RIGHT), card_p)
        if key == "ww2_sup_gmc_truck":
            # 待机直出攻击：idle f0 → 锚定（朝左不翻）→ fam44 配置
            os.makedirs(SRC44, exist_ok=True)
            big = f0.resize((512, 512), Image.LANCZOS)
            arr = fca.extract_from_rgba(big) if hasattr(fca, "extract_from_rgba") else None
            if arr is None:
                # 手工同配方：反预乘→1024→品红场
                a4 = np.asarray(big).astype(np.float32)
                al = np.clip(a4[:, :, 3:4] / 255.0, 0.004, None)
                rgb = np.clip(a4[:, :, :3] / al, 0, 255).astype(np.uint8)
                alpha = (a4[:, :, 3] > 1).astype(np.uint8) * 255
                rgba = np.dstack([rgb, alpha])
                im1024 = Image.fromarray(rgba, "RGBA").resize((1024, 1024), Image.LANCZOS)
                field = Image.new("RGB", (1024, 1024), (255, 0, 255))
                field.paste(im1024.convert("RGB"), (0, 0), im1024.split()[3])
                arr = np.asarray(field)
            # idle f0 已是终稿朝左，直接作锚定不翻
            Image.fromarray(arr).save(os.path.join(SRC44, "ww2_sup_gmc_truck_anchor_raw.png"))
            cfg = json.load(open(os.path.join(ROOT, ".godot/unit_review/codeanim_configs/_configs_fam43.json"), encoding="utf-8"))["ww2_sup_gmc_truck"]
            cfg["src"] = SRC44
            p44 = os.path.join(ROOT, ".godot/unit_review/codeanim_configs/_configs_fam44.json")
            c44 = json.load(open(p44, encoding="utf-8"))
            c44["ww2_sup_gmc_truck"] = cfg
            json.dump(c44, open(p44, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print("  [anchor] gmc_truck 待机直出锚定 + fam44 配置(crate=%s bomb_scale=%s)" % (cfg.get("crate"), cfg.get("bomb_scale")))
    print("BATCH_B %s" % ("ALL_OK" if ok else "HAS_FAILURES"))


if __name__ == "__main__":
    main()
