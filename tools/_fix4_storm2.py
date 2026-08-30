# -*- coding: utf-8 -*-
"""回退 ww1_storm 的 edge/nw 标记 + build 植入 6px 清边 + 重建 storm"""
import importlib.util
import sys

SRC = 'tools/generate_unit_animations.py'
txt = open(SRC, encoding='utf-8').read()
ref = '"ref": "ww1_storm_white.jpg",'
patch = ref + '\n        "matte_edge": True,\n        "nw_trim": False,'
if txt.count(patch) == 1:
    txt = txt.replace(patch, ref)
    open(SRC, 'w', encoding='utf-8').write(txt)
    print('storm flags reverted')

# 植入清边(幂等检查)
old = '''        fp = os.path.join(adir, "f%02d.png" % i)
        canvas = defringe_rgba(canvas)
        canvas.save(fp)'''
new = '''        fp = os.path.join(adir, "f%02d.png" % i)
        canvas = defringe_rgba(canvas)
        # fix4 清画布边框6px: 视频自画边框线环会连着主体存活(士兵/器械永不贴画布边, 合成保证>=8px留白)
        if clear_border:
            px = canvas.load()
            w, h = canvas.size
            for yy in range(h):
                for xx in range(w):
                    if xx < 6 or yy < 6 or xx >= w - 6 or yy >= h - 6:
                        px[xx, yy] = (0, 0, 0, 0)
        canvas.save(fp)'''
assert txt.count(old) == 1
txt = txt.replace(old, new)
marker = 'unit_nw = bool(UNITS.get(unit, {}).get("nw_trim", True))'
assert txt.count(marker) == 1
if 'clear_border = not' not in txt:
    txt = txt.replace(marker, marker + '''
    clear_border = not bool(UNITS.get(unit, {}).get("keep_border_ring", False))''')
open(SRC, 'w', encoding='utf-8').write(txt)
print('clear_border step wired')

spec = importlib.util.spec_from_file_location('gua', SRC)
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
for a in ('idle', 'attack'):
    print('== rebuild ww1_storm/' + a, flush=True)
    gua.step_build('ww1_storm', a)
print('DONE')
