# 审查表标准：card_id -> icon_num (vis编号)
import json, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)
# 反查：vis_num -> card_id
num_to_card = {}
for cid, v in std.items():
    if v['icon_num'] is not None:
        num_to_card[v['icon_num']] = (cid, v['display_name'])
lines = []
lines.append("===== 审查表 vis_enemy_NNN 编号对照（你确认的标准）=====")
for n in sorted(num_to_card):
    cid, name = num_to_card[n]
    lines.append("  vis_%03d (player/enemy) = %-24s %s" % (n, cid, name))
with open('tools/_std_num_table.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print("wrote _std_num_table.txt, %d entries" % len(num_to_card))
