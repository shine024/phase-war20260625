# -*- coding: utf-8 -*-
"""从 docs 拉全部敌方单位中文名 -> unit 配置 JSON"""
import io
import json
import re

t = io.open(r'docs/card_icon_manifest_100_zh（100敌人设定）.md', encoding='utf-8').read()
print('doc lines:', len(t.splitlines()))
# 找 vis 编号/英文id/中文名 的行
pat = re.compile(r'(vis_(?:enemy|player)_(\d{3})|([a-z0-9_]{6,}))\s*[:|｜]\s*([^\n|｜]{2,20})')
rows = []
for ln in t.splitlines():
    m = re.search(r'(vis_player_|vis_enemy_)(\d{3})', ln)
    if m:
        name = re.search(r'[｜|]\s*([^\s|｜]{2,24})\s*$', ln.strip()) or re.search(r'[:：]\s*(\S{2,24})', ln)
        rows.append((int(m.group(2)), ln.strip()[:120]))
for n, ln in rows[:40]:
    print(n, ln)
