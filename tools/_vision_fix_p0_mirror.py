# -*- coding: utf-8 -*-
## P0 修复：镜像断裂 3 案 —— 敌图为源水平翻转覆盖我图（管线正路 enemy-first）
## 成因: img25 重掷出朝左敌图后未翻回我侧。修后敌我两卡面=同一画。
## 备份: assets/card_icons/player/_vision_fix_backup_20261003/
import os, shutil, sys, io
from datetime import date
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

CASES = [
    ("assets/card_icons/enemy/vis_enemy_061.png", "assets/card_icons/player/vis_player_061.png", "mod_inf_delta_e"),
    ("assets/card_icons/enemy/mod_sup_m4_carbine.png", "assets/card_icons/player/mod_sup_m4_carbine.png", "mod_sup_m4_carbine"),
    ("assets/card_icons/enemy/ww2_air_dive_bomber.png", "assets/card_icons/player/ww2_air_dive_bomber.png", "ww2_air_dive_bomber"),
]

BK = os.path.join(ROOT, "assets", "card_icons", "player", "_vision_fix_backup_%s" % date.today().isoformat().replace("-", ""))


def main():
    os.makedirs(BK, exist_ok=True)
    for e_rel, p_rel, name in CASES:
        e, p = os.path.join(ROOT, e_rel), os.path.join(ROOT, p_rel)
        assert os.path.isfile(e), "缺敌图 " + e_rel
        assert os.path.isfile(p), "缺我图 " + p_rel
        im_e = Image.open(e).convert("RGBA")
        im_p = Image.open(p).convert("RGBA")
        # 修前留证：镜像差
        import hashlib
        md5_old = hashlib.md5(open(p, "rb").read()).hexdigest()[:10]
        # 备份旧我图
        shutil.copy2(p, os.path.join(BK, os.path.basename(p_rel)))
        # 翻转覆盖
        mir = im_e.transpose(Image.FLIP_LEFT_RIGHT)
        if mir.size != im_p.size:
            print("  [!] 尺寸不同 %s vs %s —— 以敌图尺寸为准" % (im_e.size, im_p.size))
        mir.save(p)
        md5_new = hashlib.md5(open(p, "rb").read()).hexdigest()[:10]
        # 验证：新我图再翻回应与敌图逐字节一致
        back = Image.open(p).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
        same = list(back.getdata()) == list(im_e.getdata())
        print("[%s] %s %s md5 %s→%s 回翻一致=%s" % (name, e_rel.split("/")[-1], p_rel.split("/")[-1], md5_old, md5_new, same))
        assert same, "回翻校验失败 " + name
    print("P0 DONE 3 案, 备份于", os.path.relpath(BK, ROOT))


if __name__ == "__main__":
    main()
