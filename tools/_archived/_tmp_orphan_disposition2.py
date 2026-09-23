import os, shutil, json

BAK = os.path.join('.godot', 'art_backup_orphan_20260922')
# 人工甄别记录（行级证据）：
# pi_drop.png         — manager:1361 为组合 id "pi_drop_%s_%d"；mvp_panel:816 为同名局部 Dictionary 变量；均非文件引用
# bubble_boss/cleared — world_map:150 为 v23 退役注释文本
# 大地图.png           — bunker_manager:55,180 / game_manager:473 为中文注释散文"大地图"
final4 = ['assets/ui/instruments/pi_drop.png', 'assets/map/bubble_boss.png',
          'assets/map/bubble_cleared.png', 'assets/map/大地图.png']
just = {
    'pi_drop.png': 'manager:1361 组合id + mvp_panel:816 同名局部变量，非文件引用',
    'bubble_boss.png': 'world_map:150 v23 退役注释文本',
    'bubble_cleared.png': 'world_map:150 v23 退役注释文本',
    '大地图.png': 'bunker_manager/game_manager 中文注释散文，非文件引用',
}
for cand in final4:
    dst = os.path.join(BAK, cand)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(cand, dst)
    if os.path.exists(cand + '.import'):
        shutil.move(cand + '.import', dst + '.import')
    print('moved:', cand)

p = 'tests/evidence/art_audit_2026-09-22/orphan_disposition.json'
d = json.load(open(p, encoding='utf-8'))
moved_total = []
for root, dirs, files in os.walk(BAK):
    for f in files:
        if f.endswith('.png'):
            rel = os.path.relpath(os.path.join(root, f), BAK).replace(chr(92), '/')
            moved_total.append(rel)
d['moved'] = sorted(moved_total)
d['kept'] = [k for k in d.get('kept', []) if k[1] != '文件不存在']
d['manual_adjudication'] = {c: just[os.path.basename(c)] for c in final4}
d['kept_in_place_by_design'] = ['assets/map/gate_near.png（注记保留终局演出）',
                                 'assets/map/black_sun.png（接线候选）',
                                 'assets/map/mountain_bunker_marker.png（接线候选）']
d['total_moved'] = len(moved_total)
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(f'最终留档总数: {len(moved_total)}')
