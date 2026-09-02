#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v26 新飞机帧动画驱动：generate_unit_animations.py 的 8 单位 × idle/attack 批量
create → poll → build。FFMPEG 走 PATH（原硬编码 D 盘路径本机不存在）。
用 py -3.10 跑（cv2 依赖只在 3.10 环境齐）。"""
import importlib.util
import os
import sys
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('gua', os.path.join(ROOT, 'tools', 'generate_unit_animations.py'))
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
gua.FFMPEG = 'ffmpeg'  # 本机 PATH（chocolatey）
# 网络：绕过系统代理(127.0.0.1:10808 间歇拒绝) + 跳过证书验证（直连证书链不被信任）
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import _netfix
_netfix.install()

UNITS = [
    'ww2_air_bomber', 'ww2_air_dive_bomber',
    'cold_air_strike_fighter', 'cold_air_bomber',
    'mod_air_multirole', 'mod_air_bomber',
    'fut_air_stealth_multirole', 'fut_air_stealth_bomber',
]

def main():
    # 阶段1：全部 create（服务端并行渲染）
    for u in UNITS:
        for anim in ('idle', 'attack'):
            try:
                gua.step_create(u, anim)
                print('  [create ok] %s/%s' % (u, anim), flush=True)
            except Exception as e:
                print('  [create FAIL] %s/%s: %r' % (u, anim, e), flush=True)
    # 阶段2：逐个 poll + build
    fails = []
    for u in UNITS:
        for anim in ('idle', 'attack'):
            try:
                gua.step_poll(u, anim, max_wait=900)
                gua.step_build(u, anim)
                print('  [build ok] %s/%s' % (u, anim), flush=True)
            except Exception:
                print('  [poll/build FAIL] %s/%s' % (u, anim), flush=True)
                traceback.print_exc()
                fails.append('%s/%s' % (u, anim))
    print('=== 动画批次完成，失败 %d：%s' % (len(fails), ', '.join(fails)))

if __name__ == '__main__':
    main()
