# -*- coding: utf-8 -*-
"""精确核对：每个组的磁盘 png vs 拼版渲染单元（去重后），找漏网文件。"""
import os, glob, re

def norm(p):
    return os.path.normpath(p).lower()

groups = {}
groups['anims'] = [p for p in glob.glob('assets/effects/unit_anims/*/sheet_idle.png')] + \
                  [p for p in glob.glob('assets/effects/unit_anims/*/sheet_attack.png')]
groups['cards_player'] = glob.glob('assets/card_icons/player/*.png')
groups['cards_enemy'] = glob.glob('assets/card_icons/enemy/*.png')
groups['backgrounds'] = glob.glob('assets/backgrounds/*.png')
groups['masters'] = glob.glob('assets/enemies/phase_masters/*.png')
groups['ui_icons'] = glob.glob('assets/ui/icons/*.png')
groups['ui_instruments'] = glob.glob('assets/ui/instruments/*.png')
groups['ui_misc'] = glob.glob('assets/ui/instruments/_thumb128/*.png') + glob.glob('assets/ui/factions/*.png') + \
                    glob.glob('assets/ui/ranks/*.png') + glob.glob('assets/ui/stars/*.png') + glob.glob('assets/ui/truck_base/*.png')
groups['runes'] = glob.glob('assets/runes/common/*.png') + glob.glob('assets/runes/rare/*.png') + \
                  glob.glob('assets/runes/epic/*.png') + glob.glob('assets/runes/legendary/*.png')
groups['fx_weapons'] = glob.glob('assets/effects/projectiles/weapons_realistic/*.png') + glob.glob('assets/effects/projectiles/omega_platform/*.png')
groups['fx_other'] = glob.glob('assets/effects/particle_textures/*.png') + glob.glob('assets/effects/explosion_frames/*.png') + \
                     glob.glob('assets/effects/nuclear/*.png') + glob.glob('assets/effects/spell_burst/*.png') + \
                     glob.glob('assets/effects/ultimate_projectiles/*.png') + glob.glob('assets/effects/dot/*.png') + \
                     glob.glob('assets/effects/aura/*.png')
groups['misc'] = glob.glob('assets/map/*.png') + glob.glob('assets/intro/*.png') + glob.glob('assets/intro/comic/*.png') + \
                 glob.glob('assets/cards/backgrounds/*.png') + glob.glob('assets/cards/frames/*.png') + \
                 glob.glob('assets/resources/*.png') + glob.glob('assets/icons/*.png') + glob.glob('assets/battle/*.png') + \
                 glob.glob('assets/phase_field/*.png')

# 磁盘全量
disk = set()
for p in glob.glob('assets/**/*.png', recursive=True):
    s = norm(p)
    if '_thumb' in s or 'bak_' in s or '_backup' in s or s.endswith('.import'):
        continue
    disk.add(s)

covered = set()
print('%-16s %6s %6s' % ('group', 'disk', 'in sheets'))
for g, lst in groups.items():
    lst = [p for p in lst if '_backup' not in p and 'bak_' not in p]
    for p in lst:
        covered.add(norm(p))
    print('%-16s %6d' % (g, len(lst)))
missing = sorted(disk - covered)
print('\nTOTAL disk(unique, no thumbs/backup):', len(disk))
print('covered by sheets:', len(covered & disk))
print('NOT covered (%d):' % len(missing))
for p in missing[:60]:
    print('  ', p)
