# -*- coding: utf-8 -*-
"""fam44 生图批·第二轮卡图部署（void_soldier / juggernaut，2026-10-06 用户拍板「都可以了」）。

raw(朝右) → white_to_alpha → gain(暗图提亮) → derive_card → fliplr=cardE(朝左)
cardP = fliplr(cardE)。备份 → 写盘 → md5 复读验证（批B save_verified 同款）。
用法: python tools/_fam44_cards_deploy2.py
"""
import hashlib
import io
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
import fam44_cards_page as fp  # noqa: E402  (derive_card/white_to_alpha/gain_rgb/GAIN)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam44_cards_redo")
BAK = os.path.join(ROOT, ".godot", "unit_review", "vintage_unify_bak")

U = {
    "fe_void_dimensional_soldier": ("assets/card_icons/enemy/fe_void_dimensional_soldier.png",
                                    "assets/card_icons/player/fe_void_dimensional_soldier.png"),
    "fe_iron_wall_juggernaut":     ("assets/card_icons/enemy/fe_iron_wall_juggernaut.png",
                                    "assets/card_icons/player/fe_iron_wall_juggernaut.png"),
}


def md5(b):
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
    print("  [%s] %s%s" % ("OK" if ok else "FAIL", path, "（备份）" if os.path.exists(bak) else ""))
    return ok


def main():
    all_ok = True
    for key, (pe, pp) in U.items():
        raw = Image.open(os.path.join(STAGE, "%s_raw.png" % key))
        rgba = fp.white_to_alpha(raw)
        g = fp.GAIN.get(key)
        if g:
            rgba = fp.gain_rgb(rgba, g)
            print("[%s] gain x%.1f" % (key, g))
        cardE = fp.derive_card(rgba).transpose(Image.FLIP_LEFT_RIGHT)
        cardP = cardE.transpose(Image.FLIP_LEFT_RIGHT)
        all_ok &= save_verified(cardE, pe)
        all_ok &= save_verified(cardP, pp)
    # 判读落档：两案 可以
    vpath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fam44_cards.json")
    v = json.load(open(vpath, encoding="utf-8")) if os.path.exists(vpath) else {}
    for key in U:
        v[key] = {"status": "可以"}
    json.dump(v, open(vpath, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[verdict] tools/fam44_cards.json → %d 条（7/7 可以）" % len(v))
    print("ALL OK" if all_ok else "HAS FAIL", flush=True)


if __name__ == "__main__":
    main()
