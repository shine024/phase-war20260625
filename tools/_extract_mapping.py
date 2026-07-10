import re, json, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
with open('tools/enemy_card_review.html', encoding='utf-8') as f:
    html = f.read()
m = re.search(r'const CARDS = (\[.*?\]);\s*\nconst SECTION_LABELS', html, re.S)
out = []
out.append('found: %s' % bool(m))
if m:
    cards = json.loads(m.group(1))
    out.append('cards count: %d' % len(cards))
    mapping = {}
    for c in cards:
        mapping[c['card_id']] = {'icon_num': c.get('icon_num'), 'filename': c['filename'], 'display_name': c['display_name']}
    # 保存
    with open('tools/_icon_standard_mapping.json', 'w', encoding='utf-8') as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)
    vis = {k:v for k,v in mapping.items() if v['icon_num'] is not None}
    named = {k:v for k,v in mapping.items() if v['icon_num'] is None}
    out.append('vis编号卡: %d, 同名卡: %d' % (len(vis), len(named)))
with open('tools/_extract_log.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
