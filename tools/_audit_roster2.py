# -*- coding: utf-8 -*-
"""全量解析 enemy_unit_manifest: 所有敌方单位 id + 卡图映射 + 动画覆盖差集"""
import io
import os
import re

t = io.open('data/enemy_unit_manifest.gd', encoding='utf-8').read()
# 抓所有 a-z0-9_ 的 id 字符串(排除 gd 关键字)
ids = re.findall(r'"([a-z0-9_]+)"', t)
STOP = {'captured', 'id', 'archetype', 'icon', 'name', 'enemy', 'platform', 'card'}
ids = [i for i in ids if i not in STOP and not i.startswith('_')]
seen = []
for i in ids:
    if i not in seen:
        seen.append(i)
print('manifest 全部唯一 id:', len(seen))

# 动画目录已覆盖的(按 unit_key 前缀)
anim_dir = r'资料/单位分帧动画'
dirs = [d for d in os.listdir(anim_dir) if os.path.isdir(os.path.join(anim_dir, d))]
print('动画目录:', len(dirs))

# 已有卡图
import glob
icons = set(os.path.basename(f) for f in glob.glob('assets/card_icons/enemy/vis_enemy_*.png'))
print('vis_enemy 卡图:', len(icons))

# 按 era 前缀分组展示 manifest ids
for era, pats in [('ww1', ('ww1_',)), ('ww2', ('ww2_',)), ('cold', ('cold_',)),
                  ('mod', ('mod_',)), ('fut', ('fut_',))]:
    grp = [i for i in seen if i.startswith(pats)]
    print('\n[%s] %d 个:' % (era, len(grp)))
    print('  ' + ', '.join(grp))
other = [i for i in seen if not i.startswith(('ww1_', 'ww2_', 'cold_', 'mod_', 'fut_'))]
if other:
    print('\n[其他] %d 个: %s' % (len(other), ', '.join(other)))
