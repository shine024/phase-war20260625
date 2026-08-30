# -*- coding: utf-8 -*-
"""修复名单单位: 定义位置(py/json) + 现有matte覆盖 + ref/anims结构"""
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)

extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
FIX = ['mod_mlrs', 'mod_abrams', 'ww2_arty_m81', 'ww1_arty_m81', 'mod_technical',
       'mod_inf_technical', 'mod_sup_m6', 'mod_inf_scout_drone', 'fut_air_regen_frame',
       'cold_fort_radar', 'ww2_arty_pak40', 'fut_arty_ssc1', 'fut_mech',
       'ww2_inf_bazooka', 'cold_sup_zsu23', 'cold_fort_missile', 'ww1_sup_vickers',
       'ww2_arty_hummel', 'mod_sup_growler', 'fut_inf_x9', 'fut_inf_c96',
       'ww2_sup_gmc_truck', 'cold_arm_p18', 'cold_arty_brem1', 'fut_sup_ps9']
for u in FIX:
    where = 'py  ' if u in gua.UNITS else ('json' if u in extra else 'MISS')
    src = gua.UNITS.get(u) or extra.get(u) or {}
    print('%-20s %s  edge=%s mn=%s ref=%s anims=%s' % (
        u, where, src.get('matte_edge'), src.get('mn_floor'),
        src.get('ref'), list(src.get('anims', {}).keys())))
# 确认 extra 合并进 UNITS
print('UNITS total after merge:', len(gua.UNITS))
