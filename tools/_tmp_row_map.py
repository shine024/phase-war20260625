# -*- coding: utf-8 -*-
import glob, os
dirs = sorted(d for d in glob.glob('assets/effects/unit_anims/*/')
              if os.path.exists(os.path.join(d, 'sheet_idle.png')))
out = '.godot/art_audit_20261011/sheets/anims/row_map.txt'
with open(out, 'w') as f:
    for i, d in enumerate(dirs):
        name = os.path.basename(d.rstrip('/\\'))
        f.write('sheet_%02d row%02d: %s\n' % (i // 12 + 1, i % 12 + 1, name))
print(len(dirs), 'dirs mapped')
