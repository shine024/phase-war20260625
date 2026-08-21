import re, json

src = open('data/unified_card_table.gd', encoding='utf-8').read()
chunks = ['{"card_id":"' + c for c in src.split('\n\t{"card_id":"')[1:]]
entries = []
for body in chunks:
    def g(k):
        mm = re.search(r'"%s":([^,\n]+)' % k, body)
        if not mm:
            return ''
        v = mm.group(1).strip().rstrip(',').strip('"').replace('}"', '')
        return v
    entries.append({
        'id': g('card_id'), 'era': g('era'), 'tier': g('tier').replace('Tier.', ''),
        'wt': g('weapon_type'), 'label': g('weapon_label'), 'name': g('display_name'),
        'eo': 'enemy_only":true' in body.replace(' ', ''),
    })

js = json.load(open('data/json/enemy_archetypes.json', encoding='utf-8'))
arch_ids = set(js.get('data', {}).keys())

wt_name = {'0': '直射', '1': '曲射', '2': '空射', '3': '支援'}
era_name = ['一战', '二战', '冷战', '现代', '近未来']
tier_name = {'GRUNT': '普通', 'VETERAN': '老练', 'ELITE': '精英', 'CHAMPION': '精锐头目',
             'BOSS': 'Boss', 'ULTIMATE': '终极', 'FORT': '堡垒'}

enemy = [e for e in entries if e['eo'] or e['id'] in arch_ids]
print('解析条目 %d，敌方使用 %d（enemy_only %d + 命中archetype %d）' % (
    len(entries), len(enemy), sum(1 for e in enemy if e['eo']),
    sum(1 for e in enemy if not e['eo'])))
for era in range(5):
    rows = [e for e in enemy if e['era'] == str(era)]
    print()
    print('### %s时代（%d 张）' % (era_name[era], len(rows)))
    print('| 卡牌 | 主武器 | 弹道 | 档次 |')
    print('|------|--------|------|------|')
    for e in rows:
        tag = ' ✓' if e['eo'] else ''
        print('| %s%s | %s | %s | %s |' % (
            e['name'], tag, e['label'] or '—',
            wt_name.get(e['wt'], e['wt']), tier_name.get(e['tier'], e['tier'])))
