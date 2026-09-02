#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v26 动画本地重抽：extra.json 已给 8 单位开 matte_edge/nw_trim=False，
从既有 source.mp4 重跑 step_build（不耗 API）。用 py -3.10 跑。"""
import importlib.util
import os
import sys
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('gua', os.path.join(ROOT, 'tools', 'generate_unit_animations.py'))
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
gua.FFMPEG = 'ffmpeg'

UNITS = [
    'ww2_air_bomber', 'ww2_air_dive_bomber',
    'cold_air_strike_fighter', 'cold_air_bomber',
    'mod_air_multirole', 'mod_air_bomber',
    'fut_air_stealth_multirole', 'fut_air_stealth_bomber',
]

def main():
    fails = []
    for u in UNITS:
        for anim in ('idle', 'attack'):
            try:
                gua.step_build(u, anim)
                print('[rebuild ok] %s/%s' % (u, anim), flush=True)
            except Exception:
                print('[rebuild FAIL] %s/%s' % (u, anim), flush=True)
                traceback.print_exc()
                fails.append('%s/%s' % (u, anim))
    print('=== 重抽完成，失败 %d：%s' % (len(fails), ', '.join(fails)))

if __name__ == '__main__':
    main()
