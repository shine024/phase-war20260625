#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v26 补发撞限流失败的 2 个动画任务 + 等待 + 构建。用 py -3.10 跑。"""
import importlib.util
import os
import sys
import time
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('gua', os.path.join(ROOT, 'tools', 'generate_unit_animations.py'))
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
gua.FFMPEG = 'ffmpeg'
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import _netfix
_netfix.install()

MISSING = [
    ('fut_air_stealth_bomber', 'idle'),
    ('fut_air_stealth_bomber', 'attack'),
]

def main():
    created = []
    for u, a in MISSING:
        for attempt in range(4):
            try:
                gua.step_create(u, a)
                print('[create ok] %s/%s (第%d次尝试)' % (u, a, attempt + 1), flush=True)
                created.append((u, a))
                break
            except Exception as e:
                print('[create FAIL %d] %s/%s: %s' % (attempt + 1, u, a, str(e)[:120]), flush=True)
                time.sleep(75)  # 限流 5/min，等窗口滑过
        time.sleep(15)
    # 给最早的服务端渲染留时间，再逐个 poll+build
    time.sleep(60)
    fails = []
    for u, a in created:
        try:
            gua.step_poll(u, a, max_wait=900)
            gua.step_build(u, a)
            print('[build ok] %s/%s' % (u, a), flush=True)
        except Exception:
            print('[poll/build FAIL] %s/%s' % (u, a), flush=True)
            traceback.print_exc()
            fails.append('%s/%s' % (u, a))
    print('=== 补发完成，失败 %d：%s' % (len(fails), ', '.join(fails)))

if __name__ == '__main__':
    main()
