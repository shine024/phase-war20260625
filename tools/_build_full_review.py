import json, os, shutil, io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)

# 按 icon_num 排序（同名的放最后）
def sort_key(item):
    cid, v = item
    return (0, v['icon_num']) if v['icon_num'] is not None else (1, cid)
ordered = sorted(std.items(), key=sort_key)

out = 'tools/player_card_review'
os.makedirs(out, exist_ok=True)
# 清空旧 img
imgdir = os.path.join(out, 'img')
if os.path.isdir(imgdir):
    shutil.rmtree(imgdir)
os.makedirs(imgdir, exist_ok=True)

cards = []
for cid, v in ordered:
    num = v['icon_num']
    if num is not None:
        player_fn = "vis_player_%03d.png" % num
        enemy_fn = "vis_enemy_%03d.png" % num
    else:
        player_fn = cid + ".png"
        enemy_fn = cid + ".png"
    psrc = f'assets/card_icons/player/{player_fn}'
    esrc = f'assets/card_icons/enemy/{enemy_fn}'
    p_dst = f'img/player_{player_fn}'
    e_dst = f'img/enemy_{enemy_fn}'
    if os.path.exists(psrc): shutil.copy(psrc, os.path.join(out, p_dst))
    if os.path.exists(esrc): shutil.copy(esrc, os.path.join(out, e_dst))
    cards.append({
        'card_id': cid, 'display_name': v['display_name'],
        'icon_num': num, 'player_file': p_dst, 'enemy_file': e_dst,
        'p_exists': os.path.exists(psrc), 'e_exists': os.path.exists(esrc),
    })

# 写 HTML
html = []
html.append('<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><title>我方战斗卡卡图审查</title>')
html.append('''<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:"Microsoft YaHei",sans-serif;background:#0d1117;color:#c9d1d9;padding:16px}
h1{text-align:center;color:#58a6ff;font-size:22px;margin-bottom:4px}
.sub{text-align:center;color:#8b949e;font-size:13px;margin-bottom:16px}
table{width:100%;border-collapse:collapse;font-size:12px}
th{background:#161b22;color:#58a6ff;padding:8px 6px;border-bottom:2px solid #30363d;position:sticky;top:0;text-align:left}
td{padding:6px;border-bottom:1px solid #21262d;vertical-align:middle}
tr:hover{background:#161b22}
.num{color:#f0883e;font-weight:bold;font-family:monospace}
.cid{color:#8b949e;font-family:monospace;font-size:11px}
.name{color:#f0f6fc;font-weight:bold}
img{width:80px;height:80px;object-fit:contain;background:#0d1117;border-radius:4px;vertical-align:middle}
.imgwrap{display:inline-block}
.legend{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:12px;margin-bottom:16px;font-size:13px;line-height:1.7}
.legend code{background:#0d1117;padding:2px 6px;border-radius:4px;color:#f0883e}
</style></head><body>''')
html.append('<h1>我方战斗卡卡图审查（对照敌方原图）</h1>')
html.append('<p class="sub">共 %d 张 | 每行：审查表标注 → 我方实际加载图(player) → 敌方原图(enemy) | 两图应为水平翻转关系</p>' % len(cards))
html.append('<div class="legend">说明：<code>player 图</code> = 我方卡在游戏里显示的图（敌方原图的水平翻转）。<br>核对方法：看 <code>审查表标注名</code> 是否与 <code>player 图</code> 的实际内容一致。若不一致，说明该编号的 enemy 原图内容放错了位置。</div>')
html.append('<table><thead><tr><th>编号</th><th>card_id</th><th>审查表标注</th><th>我方图(player)</th><th>敌方原图(enemy)</th></tr></thead><tbody>')
for c in cards:
    num_disp = '#%03d' % c['icon_num'] if c['icon_num'] else '(同名)'
    p_img = f'<img src="{c["player_file"]}">' if c['p_exists'] else '<span style="color:#f85149">缺失</span>'
    e_img = f'<img src="{c["enemy_file"]}">' if c['e_exists'] else '<span style="color:#f85149">缺失</span>'
    html.append(f'<tr><td class="num">{num_disp}</td><td class="cid">{c["card_id"]}</td><td class="name">{c["display_name"]}</td><td>{p_img}</td><td>{e_img}</td></tr>')
html.append('</tbody></table></body></html>')

with open(os.path.join(out, 'index.html'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(html))
print('生成完成:', os.path.join(out, 'index.html'))
print('卡片数:', len(cards))
