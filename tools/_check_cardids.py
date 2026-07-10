import json, io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)
std_ids = set(std.keys())

# 从 default_cards.gd 提取所有 card_id（combat unit）
with open('data/default_cards.gd', encoding='utf-8') as f:
    dc = f.read()
# 匹配 "card_id": "xxx" 或 card_id = "xxx"
ids = set(re.findall(r'"card_id"\s*:\s*"([^"]+)"', dc))
# 也匹配 _make_xxx("id", 形式
ids |= set(re.findall(r'_make_\w+\(\s*"([^"]+)"', dc))

combat_like = set(i for i in ids if any(i.startswith(p) for p in ['ww1_','ww2_','cold_','mod_','fut_']))

in_std_not_dc = sorted(std_ids - combat_like)
in_dc_not_std = sorted(combat_like - std_ids)
lines=[]
lines.append("审查表 card_id: %d | default_cards 战斗卡: %d" % (len(std_ids), len(combat_like)))
lines.append("\n=== 在审查表但不在 default_cards（可能命名差异）===")
lines.append('\n'.join('  '+x for x in in_std_not_dc) or '  (无)')
lines.append("\n=== 在 default_cards 但不在审查表（我方独有/未在审查表的卡）===")
lines.append('\n'.join('  '+x for x in in_dc_not_std[:60]) or '  (无)')
with open('tools/_cardid_diff.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print("done. std-only=%d dc-only=%d" % (len(in_std_not_dc), len(in_dc_not_std)))
