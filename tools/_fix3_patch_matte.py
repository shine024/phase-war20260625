# -*- coding: utf-8 -*-
"""fix3 matte 覆盖: py 4单位补 nw_trim; json 8单位加 edge+nw_trim"""
import json

SRC = 'tools/generate_unit_animations.py'
PY_UNITS = ['mod_mlrs', 'mod_abrams', 'mod_technical', 'fut_mech']
JSON_UNITS = ['ww2_arty_m81', 'mod_inf_technical', 'mod_sup_m6',
              'mod_inf_scout_drone', 'fut_air_regen_frame', 'cold_fort_radar',
              'ww2_arty_pak40', 'fut_arty_ssc1']

txt = open(SRC, encoding='utf-8').read()
for u in PY_UNITS:
    pat = '"ref": "%s_white.jpg",' % u
    assert txt.count(pat) == 1, u
    txt = txt.replace(pat, pat + '\n        "nw_trim": False,', 1)
open(SRC, 'w', encoding='utf-8').write(txt)
print('py patched:', len(PY_UNITS))

extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
for u in JSON_UNITS:
    assert u in extra, u
    extra[u]['matte_edge'] = True
    extra[u]['nw_trim'] = False
json.dump(extra, open('tools/unit_animations_extra.json', 'w', encoding='utf-8'),
          ensure_ascii=False, indent=2)
print('json patched:', len(JSON_UNITS))
