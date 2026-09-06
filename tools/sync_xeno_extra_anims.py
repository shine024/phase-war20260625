#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 xeno_assets_config.ANIMS 合并进 tools/unit_animations_extra.json。

extra json 是 generate_unit_animations.py（create/poll/build）与
deploy_unit_animins.py（雪碧条部署）共同识别的单位注册表；
星冥 20 单位的动画源帧目录为 资料/单位分帧动画/<NNN>_vis_xeno_<short>_<中文名>/。
幂等：重复跑只更新星冥段，不动既有条目。
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xeno_assets_config import ANIMS, UNITS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRA = os.path.join(ROOT, "tools", "unit_animations_extra.json")

with open(EXTRA, "r", encoding="utf-8") as f:
    cfg = json.load(f)

for u in UNITS:
    key = u["key"]
    cfg[key] = {
        "name": u["display"],
        "ref": key + "_white.jpg",
        "art": "assets/card_icons/enemy/%s.png" % key,
        "category": "xeno",
        "air": bool(u["air"]),
        "anims": ANIMS[key],
    }

with open(EXTRA, "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=1)
print("unit_animations_extra.json 合并完成，总条目 %d（含星冥 %d）" % (len(cfg), len(UNITS)))
