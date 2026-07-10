# 生成"我方卡图审查"对照：每张我方卡 -> 它实际加载的 player 图 -> 该图对应的标准 card_id/名称
import json, io, sys, os, shutil
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)

# 标准编号 -> card_id/name
num_to = {}
for cid, v in std.items():
    if v['icon_num'] is not None:
        num_to[v['icon_num']] = (cid, v['display_name'])
    else:
        num_to[cid] = (cid, v['display_name'])  # 同名卡

# 准备输出目录：拷贝 player 图 + 标注
outdir = 'tools/player_card_review'
imgdir = os.path.join(outdir, 'img')
os.makedirs(imgdir, exist_ok=True)

rows = []
for cid, v in std.items():
    num = v['icon_num']
    if num is not None:
        player_fn = "vis_player_%03d.png" % num
    else:
        player_fn = cid + ".png"
    src = os.path.join('assets/card_icons/player', player_fn)
    exists = os.path.exists(src)
    rows.append({
        'card_id': cid, 'display_name': v['display_name'],
        'icon_num': num, 'player_file': player_fn, 'exists': exists,
        'section': v.get('section','')
    })

print("total rows:", len(rows), "| missing player imgs:", sum(1 for r in rows if not r['exists']))
# 保存
with open(os.path.join(outdir,'data.json'),'w',encoding='utf-8') as f:
    json.dump(rows, f, ensure_ascii=False, indent=2)
print("wrote", os.path.join(outdir,'data.json'))
