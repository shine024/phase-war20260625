# -*- coding: utf-8 -*-
"""复审清单: 名称->key 映射 + 抠图方向诊断
诊断指标(每动画):
  keep%    帧均不透明占比
  card%    卡图不透明占比(仅统计, 供对照)
  resid%   残渣率: 不透明且近纯白(mn>=235,sat<=20)占比  -> 高=抠少(留白块)
  eaten    吃主体嫌疑: keep% 相对卡图过低(<60%)
"""
import glob
import importlib.util
import json
import os
import sys

from PIL import Image

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
UNITS = gua.UNITS
extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
for k, v in extra.items():
    UNITS.setdefault(k, v)

BASE = r'资料/单位分帧动画'
KW = ['火箭炮', '艾布拉姆斯', '机甲', '巴祖卡', '迫击', 'ZSU', '皮卡', 'M6',
      '侦察无人机', '再生骨架', '发射井', '雷达', '维克斯', '黄蜂', 'Hummel',
      'PaK', 'GMC', 'P-18', 'BREM', 'EA-18G', 'X-9', '毛瑟', 'SS-C-1', 'PS-9']

print('== 名称匹配 ==')
for k, v in sorted(UNITS.items()):
    nm = str(v.get('name', ''))
    if any(w.lower() in nm.lower() for w in KW):
        print('%-34s %s' % (k, nm))


def anim_metrics(adir):
    frames = sorted(glob.glob(os.path.join(adir, 'f*.png')))
    if not frames:
        return None
    tot = res = 0
    n = 0
    for f in frames:
        im = Image.open(f).convert('RGBA')
        px = im.load()
        w, h = im.size
        for y in range(0, h, 4):
            for x in range(0, w, 4):
                r, g, b, a = px[x, y]
                if a <= 16:
                    continue
                tot += 1
                mn, mx = min(r, g, b), max(r, g, b)
                if mn >= 235 and (mx - mn) <= 20:
                    res += 1
        n += 1
    sampled = (im.size[0] // 4 + 1) * (im.size[1] // 4 + 1) * n
    return 100.0 * tot / sampled, 100.0 * res / max(tot, 1)
