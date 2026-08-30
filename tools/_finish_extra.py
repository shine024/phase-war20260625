# -*- coding: utf-8 -*-
"""72 单位批完成后的收尾: ①产物完整性 ②check 全量 ③preview ④备份 zip"""
import io
import json
import os
import subprocess
import sys

CFG = json.load(io.open('tools/unit_animations_extra.json', encoding='utf-8'))
BASE = r'资料/单位分帧动画'


def sh(*args):
    r = subprocess.run([sys.executable] + list(args), capture_output=True,
                       text=True, encoding='utf-8', errors='replace')
    return r.returncode, r.stdout or '', r.stderr or ''


# 1) 逐单位确认产物齐(f*.png >= 6 帧)
bad = []
for key, v in CFG.items():
    d = os.path.join(BASE, '%s_%s' % (key, v['name']))
    if not os.path.isdir(d):
        bad.append((key, 'NO-DIR'))
        continue
    for anim in ('idle', 'attack'):
        ad = os.path.join(d, anim)
        fs = [f for f in os.listdir(ad) if f.startswith('f') and f.endswith('.png')] if os.path.isdir(ad) else []
        if len(fs) < 6:
            bad.append((key, '%s-frames:%d' % (anim, len(fs))))

print('== 产物完整性: %d 异常 ==' % len(bad))
for b in bad:
    print(' ', b[0], b[1])

# 2) check 全量(输出本身即报告)
rc, out, err = sh('tools/generate_unit_animations.py', 'check')
print('== check(仅补充单位相关行 + 全局摘要) ==')
if rc != 0:
    print('check rc=%s err=%s' % (rc, err[-300:]))
keys = set(CFG)
for ln in (out or '').splitlines():
    if any(ln.startswith(k + '_') or ln.startswith(k + ' ') or (' ' + k + '_') in ln for k in keys) \
            or ln.startswith('==') or '残留' in ln and False:
        print(ln)

# 3) preview
_, out2, _ = sh('tools/generate_unit_animations.py', 'preview')
print('== preview ==')
print(out2)

# 4) 备份
_, out3, _ = sh('tools/_backup_anim.py')
print('== backup ==')
print(out3)
