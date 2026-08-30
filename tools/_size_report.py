# -*- coding: utf-8 -*-
"""本会话新增磁盘占用统计"""
import json
import os

BASE = r'资料/单位分帧动画'


def du(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return total


extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
new_keys = set(extra.keys())
total = new = 0
for d in os.listdir(BASE):
    dp = os.path.join(BASE, d)
    if not os.path.isdir(dp) or d.startswith('_'):
        continue
    sz = du(dp)
    total += sz
    if any(d == k or d.startswith(k + '_') for k in new_keys):
        new += sz
print('源目录 总: %.1f MB  (其中本会话新增72单位: %.1f MB)' % (total / 1048576, new / 1048576))
print('assets 部署层: %.1f MB' % (du(r'assets/effects/unit_anims') / 1048576))
