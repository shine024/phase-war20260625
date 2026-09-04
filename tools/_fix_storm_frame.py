# -*- coding: utf-8 -*-
# v27.9 修复：暴风突击队卡图烤进矩形框（AI 生图残渣）
# 框实测：矩形 (31,31)-(480,480)，4px 渐变线 + 1px 内侧 AA（第 35/476 行列）
# 清理：保留内区 [36,475]²，其余 alpha 归零；player 按美术管线规则重做水平镜像；
#       同步重生成 _thumb256/_thumb384（LANCZOS，与 regen_wwi_icons.make_thumb 同法）
from PIL import Image
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
E = os.path.join(ROOT, 'assets', 'card_icons', 'enemy', 'vis_enemy_040.png')
P = os.path.join(ROOT, 'assets', 'card_icons', 'player', 'vis_player_040.png')
KEEP_LO, KEEP_HI = 36, 475  # 保留区（含）

im = Image.open(E).convert('RGBA')
px = im.load()
W, H = im.size
for y in range(H):
    for x in range(W):
        if x < KEEP_LO or x > KEEP_HI or y < KEEP_LO or y > KEEP_HI:
            px[x, y] = (0, 0, 0, 0)

bbox = im.getchannel('A').getbbox()
assert bbox is not None and bbox[0] >= KEEP_LO and bbox[1] >= KEEP_LO \
    and bbox[2] <= KEEP_HI + 1 and bbox[3] <= KEEP_HI + 1, '角色 bbox 越出保留区: %s' % (bbox,)
print('cleaned enemy, character bbox =', bbox)

# 美术管线铁律：改 enemy 原图后，player 重做 FLIP_LEFT_RIGHT
player = im.transpose(Image.FLIP_LEFT_RIGHT)
player.save(P)
im.save(E)
print('saved enemy + mirrored player')

# 缩略图两档（LANCZOS thumbnail，与 regen_wwi_icons.make_thumb 同法）
for size, tname in [(256, '_thumb256'), (384, '_thumb384')]:
    for src, sub in [(E, 'enemy'), (P, 'player')]:
        t = Image.open(src).convert('RGBA')
        t.thumbnail((size, size), Image.LANCZOS)
        out_dir = os.path.join(ROOT, 'assets', 'card_icons', tname, sub)
        os.makedirs(out_dir, exist_ok=True)
        t.save(os.path.join(out_dir, os.path.basename(src)))
print('thumbs regenerated: _thumb256 + _thumb384 x enemy/player')
