import json

p = 'tests/evidence/art_audit_2026-09-22/task41_ui_asset_refs.json'
d = json.load(open(p, encoding='utf-8'))

d['corrected_verdict'] = {
    'note': '初扫三项误报已复核修正：(1) mod_special.png 悬空——唯一引用方是归档测试 tests/_archived/_tmp_v35_legacy_audit_check.gd，运行期数据零引用，不构成悬空；(2) 3 条 svg "悬空"——svg 文件实际在盘，初扫清点只收 png 所致；(3) ranks 13 张——rank_icons.gd 以 const DIR + 字符串拼接 preload，字面正则扫不到，全部在用。',
    'dangling_refs_final': [],
    'true_orphans': [
        {'files': 'assets/ui/factions/*_32.png ×8', 'reason': '128 版在用（faction_logo_128 模板），32 版遗留'},
        {'files': 'assets/ui/icons/res_permit.png, res_research.png', 'reason': '退役货币图标（许可证 v7.3 删、科研点随 P2-7 退役）'},
        {'files': 'assets/ui/truck_base/truck_sprite_era1~5.png ×5', 'reason': '仅归档测试引用，正身是 truck_tier%d 模板'},
    ],
    'orphan_count': 15,
}
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('修正完成：悬空 0 / 真孤儿 15（factions_32×8 + 退役货币×2 + truck_sprite_era×5）')
