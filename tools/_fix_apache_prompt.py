# -*- coding: utf-8 -*-
"""apache 双单位 prompt: 模糊盘→清晰细桨叶"""
import io

p = 'tools/generate_unit_animations.py'
src = io.open(p, encoding='utf-8').read()

pairs = [
    ('主旋翼高速旋转带轻微动态模糊，',
     '主旋翼画成两片清晰的细长深色实体桨叶并旋转到不同角度，绝不画成半透明白色模糊圆盘，绝无白色光晕，'),
    ('主旋翼持续高速旋转。',
     '主旋翼保持清晰的细长深色实体桨叶，绝不画成半透明白色模糊圆盘。'),
]
for old, new in pairs:
    n = src.count(old)
    assert n == 2, (old, n)  # mod_apache + mod_apache_e 各一处
    src = src.replace(old, new)
    print('replaced x%d: %s' % (n, old[:20]))

io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('apache prompts updated')
