# -*- coding: utf-8 -*-
"""最终差集: A段28 + B段5 + E段10 + POOL池 vs 已做动画"""
import glob
import io
import os
import re

t = io.open('data/enemy_unit_manifest.gd', encoding='utf-8').read()

def seg(name):
    i = t.index(name)
    i = t.index('[', t.index('=', i))       # 跳过 Array[String] 的伪 ]
    j = t.index(']', i)
    ids = re.findall(r'"([a-z0-9_]+)"', t[i:j])
    return ids

A = seg('FOE_PLATFORM_CARD_IDS')
B = seg('FOE_SPECIAL_CARD_IDS')
E = seg('FORT_ENEMY_IDS')
P = seg('POOL_ENEMY_IDS')
C36 = seg('FIXED_ENEMY_IDS')
print('A段=%d B段=%d C段=%d E段=%d POOL=%d  合计=%d' % (len(A), len(B), len(C36), len(E), len(P),
      len(A) + len(B) + len(C36) + len(E) + len(P)))

# 已做动画目录名
anim = [d for d in os.listdir(r'资料/单位分帧动画') if os.path.isdir(os.path.join(r'资料/单位分帧动画', d))]
print('动画目录 %d:' % len(anim))

# POOL 图是否存在(enemy/<id>.png 直接命名)
have_art = [i for i in P if os.path.exists('assets/card_icons/enemy/%s.png' % i)]
no_art = [i for i in P if not os.path.exists('assets/card_icons/enemy/%s.png' % i)]
print('POOL 有图 %d:' % len(have_art), ', '.join(have_art))
print('POOL 无图 %d:' % len(no_art), ', '.join(no_art))

# vis_enemy_072~081 堡垒图存在性
forts_art = [n for n in range(72, 82) if glob.glob('assets/card_icons/enemy/vis_enemy_%03d.png' % n)]
print('堡垒图 072-081 存在:', len(forts_art))
forts_artB = [n for n in range(30, 35) if glob.glob('assets/card_icons/enemy/vis_enemy_%03d.png' % n)]
print('B段图 030-034 存在:', len(forts_artB))
forts_artA = [n for n in range(1, 29) if glob.glob('assets/card_icons/enemy/vis_enemy_%03d.png' % n)]
print('A段图 001-028 存在:', len(forts_artA))

print('\nPOOL 全列表:', ', '.join(P))
print('\nA段全列表:', ', '.join(A))
