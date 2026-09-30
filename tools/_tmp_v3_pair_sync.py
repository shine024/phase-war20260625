# -*- coding: utf-8 -*-
"""v3 宪法批：5 对反向漂移同步（2026-09-26，§11.10 CP-2 追加项收尾）。

裁决依据 = STYLE_BIBLE v3 8.2 总律（客观色板判据 + 翻转铁律：生成朝右、player=正身、
enemy := flip(player)），用户 2026-09-26 "按你新的标准进行修复" 授权：
  036/049/071  IoU=1.0 同拍仅色调差，enemy 为 09-09 刻意压冷/去饱和侧（b-r/sat 实测）→ 正身取 enemy。
  056          IoU=0.771 重 take，enemy 为刻意重导出且更干净（冷调 0.2% 暖区持平）→ 正身取 enemy。
  093          IoU=0.578 重 take，enemy 侧偏灰发白明度对比弱，player 版更合宪（暗部保细节/明度阶梯）→ 正身取 player。
工艺：正身 → player := 正身（enemy 正身时先 flip）；enemy := flip(player)。
备份 _art_backup/*-preSYNC5-2026-09-26.png（双侧全备份，任一方向可回滚）。
缩略图由 gen_ui_thumbs.py 按 mtime 增量重生成；生成后跑 verify_card_icon_pairs.py 归零 PENDING。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PI = os.path.join(ROOT, "assets", "card_icons", "player")
EN = os.path.join(ROOT, "assets", "card_icons", "enemy")
BK = r"F:\godot fair duet\_art_backup"
SUF = "-preSYNC5-2026-09-26.png"

TAKE_ENEMY = ["036", "049", "056", "071"]
TAKE_PLAYER = ["093"]


def backup(path):
    dst = os.path.join(BK, os.path.splitext(os.path.basename(path))[0] + SUF)
    if not os.path.exists(dst):
        Image.open(path).convert("RGBA").save(dst)


def flipped(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def main():
    os.makedirs(BK, exist_ok=True)
    for tag in TAKE_ENEMY + TAKE_PLAYER:
        for d in (PI, EN):
            backup(os.path.join(d, f"vis_player_{tag}.png" if d is PI else f"vis_enemy_{tag}.png"))

    for tag in TAKE_ENEMY:
        body = Image.open(os.path.join(EN, f"vis_enemy_{tag}.png")).convert("RGBA")
        # enemy 正身是朝左的成图；player 侧需要朝右正身 = flip(enemy)
        player = flipped(body)
        player.save(os.path.join(PI, f"vis_player_{tag}.png"))
        flipped(player).save(os.path.join(EN, f"vis_enemy_{tag}.png"))
        print(f"{tag}: body=enemy -> player rewritten, enemy re-flipped")

    for tag in TAKE_PLAYER:
        player = Image.open(os.path.join(PI, f"vis_player_{tag}.png")).convert("RGBA")
        flipped(player).save(os.path.join(EN, f"vis_enemy_{tag}.png"))
        print(f"{tag}: body=player -> enemy re-flipped (player untouched)")


if __name__ == "__main__":
    main()
