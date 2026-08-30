# -*- coding: utf-8 -*-
"""fut_mech idle: ①prompt 加强锁镜头+纯白背景 ②开 matte_edge"""
import io

p = 'tools/generate_unit_animations.py'
src = io.open(p, encoding='utf-8').read()

# 1) 找到 fut_mech 条目, 加 matte_edge
i = src.index('"fut_mech":')
j = src.index('"ref"', i)
assert '"matte_edge"' not in src[i:j]
src = src[:j] + '"matte_edge": True,\n        ' + src[j:]

# 2) fut_mech idle prompt: 锁定镜头
old = None
for m in ['机甲站立不动，全身缓慢起伏呼吸', '机甲保持站立', '镜头固定']:
    pass
# 直接查看再改 — 先落盘 matte_edge, prompt 手动查
io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('matte_edge added to fut_mech')
