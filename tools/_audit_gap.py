# -*- coding: utf-8 -*-
"""精确差集: manifest 单位 -> 卡图(visual_id) -> 动画目录覆盖"""
import glob
import io
import os
import re

t = io.open('data/enemy_unit_manifest.gd', encoding='utf-8').read()

# manifest 是什么结构? 打印前 80 行看骨架
lines = t.splitlines()
print('manifest 总行数:', len(lines))
for i, ln in enumerate(lines[:60]):
    print('%4d %s' % (i + 1, ln[:110]))
