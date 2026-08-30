# -*- coding: utf-8 -*-
"""fix5 目录加序号: <key>_<名> -> NNN_<key>_<名> (NNN=UNITS合并序=preview编号)
兼容已改名(跳过)。完成后重建 preview(路径引用变了)。
"""
import importlib.util
import json
import os
import sys

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)

BASE = gua.OUT_DIR
n_new = n_skip = 0
for idx, (unit, ucfg) in enumerate(gua.UNITS.items(), 1):
    new = '%03d_%s_%s' % (idx, unit, ucfg['name'])
    new_p = os.path.join(BASE, new)
    if os.path.isdir(new_p):
        n_skip += 1
        continue
    old = '%s_%s' % (unit, ucfg['name'])
    old_p = os.path.join(BASE, old)
    if not os.path.isdir(old_p):
        print('!! 缺目录:', old)
        continue
    import time
    ok = False
    for att in range(4):
        try:
            os.rename(old_p, new_p)
            ok = True
            break
        except PermissionError:
            time.sleep(1.5)
    if ok:
        n_new += 1
    else:
        print('!! 锁定无法改名:', old)
print('renamed %d, skipped(already) %d' % (n_new, n_skip))

gua.step_preview()
print('preview rebuilt')
