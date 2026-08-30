# -*- coding: utf-8 -*-
"""vickers idle 重摇: 加构图约束(居中留白~40%), 其余同 fix3 prompt"""
import importlib.util
import json
import sys
import time

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)

EXTRA_P = 'tools/unit_animations_extra.json'
extra = json.load(open(EXTRA_P, encoding='utf-8'))

HEAD = "严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。严格2D游戏精灵风格，平面正交正侧视。"
P = HEAD + \
    "单位位于画面正中央，四周留有充足的纯白空间，单位整体约占画面面积的四成，绝不顶到画面边缘。"
P += \
    "维克斯机枪阵地几乎完全静止待机：枪身与三脚架、沙袋工事全部纹丝不动，" \
    "只有枪管周围极轻微的热浪扰动与枪身极微小的颤动，动作幅度非常小，没有任何人员活动。" \
    "镜头完全锁定，无运镜，无变焦，无平移。纯白色无缝背景，无地面，无阴影，无文字，无水印。" \
    "动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。"
extra['ww1_sup_vickers']['anims']['idle']['prompt'] = P
json.dump(extra, open(EXTRA_P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
gua.UNITS.update(extra)

import os
os.remove('资料/单位分帧动画/ww1_sup_vickers_维克斯 .303 机枪阵地/idle/_task.json')

for attempt in range(4):
    try:
        gua.step_create('ww1_sup_vickers', 'idle')
        break
    except Exception as e:
        print('retry:', str(e)[:120])
        time.sleep(65)
gua.step_poll('ww1_sup_vickers', 'idle', max_wait=900)
gua.step_build('ww1_sup_vickers', 'idle')
import subprocess
r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py',
                    'ww1_sup_vickers_维克斯 .303 机枪阵地'],
                   capture_output=True, text=True, encoding='utf-8', errors='replace')
print((r.stdout or '').strip().splitlines()[-1])
print('VICKERS REROLL DONE')
