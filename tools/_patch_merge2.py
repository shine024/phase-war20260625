# -*- coding: utf-8 -*-
"""修复: 合并代码从 UNITS 定义前挪到定义后(锚 def api_keys)"""
import io

p = 'tools/generate_unit_animations.py'
src = io.open(p, encoding='utf-8').read()

block_start = src.index('# ---- 补充单位(A/B/E/POOL 段 72 种)从 JSON 合并')
block_end = src.index('REF_DIR = os.path.join(OUT_DIR, "_ref")', block_start)
block = src[block_start:block_end]
src = src[:block_start] + src[block_end:]

anchor = '\ndef api_keys():'
assert src.count(anchor) == 1
src = src.replace(anchor, '\n' + block + anchor)

io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('merge block moved after UNITS')
