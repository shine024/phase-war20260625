# -*- coding: utf-8 -*-
"""记录7 追加裁决（2026-09-24）：卡图朝向离群 15 族目检后的翻正。

用户裁决：15 族用视觉识别（朝向 + 人形脚部完整性）。目检结论：
  - 人形全员有脚（无缺脚/截断）；xeno 四族 + vis_player_004（骑兵）/064（雷达车）
    为质量判据假阳性，不动。
  - 方向真错 9 族（player 版朝左，违反"我右"约定；enemy 版互为镜像同错）：
    fe_frontier_veteran / fe_helix_phantom / fut_nano_drone /
    vis_player_011 / vis_player_063 / vis_player_067 / vis_player_088 /
    ww2_air_bomber / ww2_air_dive_bomber
9 族均无 attack_f0/sheet 联动（卡图与运行期动画朝向经 flip_h 解耦），直接整画布
水平镜像。原图备份 .godot/art_backup_cardflip_20260924/（幂等）。
可重跑：python tools/_tmp_record7_cardflip.py
"""
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(ROOT, '.godot', 'art_backup_cardflip_20260924')
FAMILIES = [
    'fe_frontier_veteran', 'fe_helix_phantom', 'fut_nano_drone',
    'vis_player_011', 'vis_player_063', 'vis_player_067', 'vis_player_088',
    'ww2_air_bomber', 'ww2_air_dive_bomber',
]
# enemy 侧 vis_player_0XX 的镜像文件叫 vis_enemy_0XX（另名，不在 FAMILIES 同名命中内）
ENEMY_EXTRA = ['vis_enemy_011', 'vis_enemy_063', 'vis_enemy_067', 'vis_enemy_088']


def main():
    for camp in ('player', 'enemy'):
        names = list(FAMILIES)
        if camp == 'enemy':
            names += ENEMY_EXTRA
        for name in names:
            p = os.path.join(ROOT, 'assets', 'card_icons', camp, name + '.png')
            if not os.path.exists(p):
                print(f'  MISS {camp}/{name}')
                continue
            bk = os.path.join(BACKUP, camp, name + '.png')
            if os.path.exists(bk):
                print(f'  SKIP(already) {camp}/{name}')
                continue
            os.makedirs(os.path.dirname(bk), exist_ok=True)
            shutil.copy2(p, bk)
            im = Image.open(p).convert('RGBA')
            im.transpose(Image.FLIP_LEFT_RIGHT).save(p)
            print(f'  FLIPPED {camp}/{name}')


if __name__ == '__main__':
    main()
