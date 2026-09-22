import os, re, shutil, json

BAK = os.path.join('.godot', 'art_backup_orphan_20260922')

# 孤儿处置清单（留档）： кабели = 相对路径
CANDIDATES = (
    # 第四块 assets/ui（15 张中的 15 张全留档：factions_32×8、退役货币×2、truck_sprite_era×5）
    [f'assets/ui/factions/{n}_32.png' for n in
     ['aether_dynamics', 'frontier_union', 'helix_recon', 'iron_wall_corp',
      'neutral', 'nova_arms', 'quantum_logistics', 'void_research']]
    + ['assets/ui/icons/res_permit.png', 'assets/ui/icons/res_research.png']
    + [f'assets/ui/truck_base/truck_sprite_era{i}.png' for i in range(1, 6)]
    # 第二块
    + ['assets/ui/instruments/pi_drop.png']
    # 第三块 漫画未入链 3 张
    + ['assets/intro/comic/b3_future_self.png', 'assets/intro/comic/b4_overlap.png',
       'assets/intro/comic/b8_timeline.png']
    # 第三块 地图：bubble 退役 7 + 大地图重复残留 1（gate_near/black_sun/mountain 留原地）
    + [f'assets/map/bubble_{n}.png' for n in
       ['boss', 'cleared', 'era_cold', 'era_future', 'era_modern', 'era_ww1', 'era_ww2']]
    + ['assets/map/大地图.png']
)

# 引用扫描：运行期源（.gd/.tscn/.tres/.cfg；排除 tools/ 开发脚本、本脚本自身、归档测试）
self_name = '_tmp_orphan_disposition'
rt_refs, arch_refs = {}, {}
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ('.git', '.godot', '.hermes')]
    for f in files:
        if not f.endswith(('.gd', '.tscn', '.tres', '.cfg')):
            continue
        p = os.path.join(root, f).replace('\\', '/')
        if '/tools/' in p or self_name in f or '/tests/_archived/' in p:
            continue
        p = os.path.join(root, f).replace('\\', '/')
        try:
            txt = open(p, encoding='utf-8', errors='ignore').read()
        except Exception:
            continue
        for cand in CANDIDATES:
            stem = os.path.basename(cand)[:-4]
            if stem in txt:
                (arch_refs if '/tests/_archived/' in p else rt_refs).setdefault(cand, []).append(p)

moved, kept = [], []
for cand in CANDIDATES:
    stem = os.path.basename(cand)
    if cand in rt_refs:
        kept.append((cand, '存在运行期引用，取消移动', rt_refs[cand][:2]))
        continue
    src_png = cand
    src_imp = cand + '.import'
    if not os.path.exists(src_png):
        kept.append((cand, '文件不存在', []))
        continue
    dst = os.path.join(BAK, cand)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(src_png, dst)
    if os.path.exists(src_imp):
        shutil.move(src_imp, dst + '.import')
    moved.append(cand)

print(f'移动 {len(moved)} 张 -> {BAK}')
for k, reason, refs in kept:
    print(f'保留: {k} [{reason}] {refs}')
json.dump({'date': '2026-09-22', 'moved': moved, 'kept': kept,
           'kept_in_place_by_design': ['assets/map/gate_near.png（注记保留终局演出）',
                                        'assets/map/black_sun.png（接线候选）',
                                        'assets/map/mountain_bunker_marker.png（接线候选）']},
          open('tests/evidence/art_audit_2026-09-22/orphan_disposition.json', 'w', encoding='utf-8'),
          ensure_ascii=False, indent=2)
print('DISPOSITION_OK')
