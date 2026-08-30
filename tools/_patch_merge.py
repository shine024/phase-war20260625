# -*- coding: utf-8 -*-
"""管线补丁: UNITS 合并 unit_animations_extra.json + air 旗标"""
import io

p = 'tools/generate_unit_animations.py'
src = io.open(p, encoding='utf-8').read()

# 1) UNITS 字典闭合后合并 JSON —— 找 UNITS 定义后的第一个顶级语句锚点
anchor = '\nREF_DIR = os.path.join(OUT_DIR, "_ref")'
assert src.count(anchor) == 1
merge_code = '''
# ---- 补充单位(A/B/E/POOL 段 72 种)从 JSON 合并: 2026-08-29 全量补齐轮 ----
# JSON 由 tools/_build_extra_cfg.py 生成(名字/类目/白底ref/prompt 模板化);
# 条目可携带额外键: art(卡图源) / category / air(空中单位 foot_frac=0.80)
_EXTRA_CFG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "unit_animations_extra.json")
if os.path.exists(_EXTRA_CFG):
    import json as _json
    with open(_EXTRA_CFG, "r", encoding="utf-8") as _f:
        UNITS.update(_json.load(_f))
'''
src = src.replace(anchor, merge_code + anchor)

# 2) air 旗标
old = '    foot_frac = 0.80 if unit in air_units else 0.92'
assert src.count(old) == 1
src = src.replace(old,
                  '    foot_frac = 0.80 if (unit in air_units or bool(UNITS.get(unit, {}).get("air"))) else 0.92')

io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('patched')
