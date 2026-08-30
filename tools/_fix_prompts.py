# -*- coding: utf-8 -*-
"""一次性修复提示词: garand单兵化 / ak强开火 / m60 idle单人 / spectre强开火"""
import io

p = 'tools/generate_unit_animations.py'
src = io.open(p, encoding='utf-8').read()


def slice_of(a, b):
    i = src.index('"%s"' % a)
    j = src.index('"%s"' % b)
    return i, j


def rep1(s, old, new):
    assert s.count(old) == 1, 'expect 1, got %d: %s' % (s.count(old), old[:40])
    return s.replace(old, new)


# ---- garand: 单兵化 idle+attack ----
i, j = slice_of('ww2_garand', 'ww2_mg42')
g = src[i:j]
for old, new, cnt in [
    ('这支步兵班的外观、服装、装备、人数、队形与细节', '这名士兵的外观、服装、装备与细节', 2),
    ('所有士兵的身体和头部', '士兵的身体和头部', 2),
    ('步兵班原地站立', '士兵原地站立', 1),
    ('队形轻微晃动后回位', '身体轻微晃动后回位', 1),
    ('步兵班原地站定，向画面左侧方向依次齐射步枪', '士兵原地站定，向画面左侧方向连续射击步枪', 1),
    ('枪口火光在左侧枪口处依次闪现', '枪口火光在左侧枪口处连续闪现', 1),
]:
    assert g.count(old) == cnt, 'expect %d, got %d: %s' % (cnt, g.count(old), old[:40])
    g = g.replace(old, new)
g = g.replace('不改变设计。"', '不改变设计。画面中只有这一名士兵，绝不增加人数，绝不出现第二名士兵。"')
assert g.count('绝不出现第二名士兵') == 2
src = src[:i] + g + src[j:]

# ---- cold_ak: attack 强开火 ----
i, j = slice_of('cold_ak', 'cold_m60')
a = src[i:j]
a = rep1(a, '枪口火光在左侧枪口处连续闪烁，枪身后坐抖动，弹壳向右后方抛出。',
         '每一名士兵全程持续射击不中断：枪口火光大幅连续闪烁，枪身明显后坐抖动，弹壳不断向右后方抛出，射击动作清晰可见，绝不静止站立。')
src = src[:i] + a + src[j:]

# ---- cold_m60: idle 单人 ----
i, j = slice_of('cold_m60', 'cold_btr')
m = src[i:j]
k = m.index('"attack"')
idle, attack = m[:k], m[k:]
idle = rep1(idle, '这支机枪班的外观、人数、机枪、服装装备与细节', '这名机枪射手的单人外观、机枪、服装装备与细节')
idle = rep1(idle, '所有射手的身体和头部', '射手的身体和头部')
idle = rep1(idle, '不改变设计。"', '不改变设计。画面中只有这一名射手，绝不增加人数，绝不出现副射手或弹药手，绝不出现第二个人。"')
idle = rep1(idle, '机枪班原地待命，', '机枪手单人原地待命，')
idle = rep1(idle, '只有射手呼吸的轻微起伏，副射手轻微整理弹链后回到初始姿态。',
            '只有呼吸带来的轻微起伏，握持机枪的手臂轻微调整后回到初始姿态。')
src = src[:i] + idle + attack + src[j:]

# ---- fut_spectre: attack 强开火 ----
i, j = slice_of('fut_spectre', 'fut_colossus')
sp = src[i:j]
sp = rep1(sp, '士兵原地站定，向画面左侧方向连续射击：',
          '士兵原地站定，做出明显而持续的射击攻击动作，向画面左侧方向连续开火：')
sp = rep1(sp, '枪口火光在左侧枪口处连续闪烁，光学迷彩流光加剧，枪身随之后坐抖动。',
          '每一帧都有明显的枪口火光在左侧枪口处闪烁，光学迷彩流光加剧，枪身反复后坐抖动，全程持续开火不中断，绝不静止站立。')
src = src[:i] + sp + src[j:]

io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('prompts updated OK')
