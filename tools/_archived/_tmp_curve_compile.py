# -*- coding: utf-8 -*-
"""B1.1c 产出汇编：解析 18 轮 curve_*.log → level_curve.json"""
import io
import json
import os
import re

EV = 'tests/evidence/playability_2026-09-22'
rows = []
for fn in sorted(os.listdir(EV)):
    m = re.match(r'curve_L(\d+)_([ab])(\d)\.log$', fn)
    if not m:
        continue
    level, grp, rnd = int(m.group(1)), m.group(2), int(m.group(3))
    raw = io.open(os.path.join(EV, fn), encoding='utf-8', errors='replace').read()
    raw = re.sub(r'\x1b\[[0-9;]*m', '', raw)

    def grab(pat, cast=str, default=None):
        mm = re.search(pat, raw, re.S)
        if not mm:
            return default
        try:
            return cast(mm.group(1))
        except Exception:
            return default

    won_sig = 'SIG battle_ended fired (args: true' in raw
    stars = grab(r'get_level_stars -> (\d+)', int)
    won = bool(stars and stars > 0) or won_sig
    # 战斗时长：开战 call 帧 → battle_ended 帧（60fps 假定）
    f_start = grab(r'SHOT res://\.godot/agent_tools/pr_curve_\w+_battle\.png \(frame (\d+)\)', int)
    f_end = grab(r'SIG battle_ended fired.*?frame=(\d+)', int)
    # 近似口径：battle shot（开战后150帧）→ battle_ended；再加 150 帧校正 = 开战起算
    dur = round((f_end - f_start + 150) / 60.0, 1) if f_start and f_end else None
    summary_nonempty = 'reward_summary = {  }' not in raw and '"player_won"' in raw
    inject_fail = raw.count('allocate_phase_field_point -> false')
    inject_ok = grp == 'a' or ('allocate_phase_field_point -> true' in raw)
    rows.append({
        'level': level, 'group': grp.upper(), 'round': rnd,
        'won': won, 'stars': stars if stars is not None else 0,
        'battle_duration_s': dur,
        'settlement_ok': summary_nonempty,
        'b_group_note': ('alloc_fail=%d(旧全攻分配)' % inject_fail) if (grp == 'b' and inject_fail) else ('ok' if grp == 'b' else '-'),
        'log': 'tests/evidence/playability_2026-09-22/' + fn,
    })

out = {
    'date': '2026-09-22',
    'task': 'B1.1c P2-11 L43/50/60 难度曲线采集',
    'method': '槽2裸档 set_current_level → 正常进关链（停靠关对齐）→ _on_start_battle → battle_ended → get_level_stars；每组 3 轮独立进程',
    'group_def': 'A=裸档；B=开战前注入相位场满级（grant_phase_field_xp 99999→Lv30）+加点：L43_b1/b2/b3 为全攻旧分配（~29点全攻），L50_b/L60_b 起为 12/10/7 均衡分配；卡牌强化未注入（如实登记）',
    'runs': rows,
}
per = {}
for r in rows:
    k = 'L%d_%s' % (r['level'], r['group'])
    per.setdefault(k, []).append(r)
summary = {}
for k, rs in per.items():
    summary[k] = {
        'wins': sum(1 for r in rs if r['won']),
        'total': len(rs),
        'avg_battle_duration_s': (round(sum(r['battle_duration_s'] or 0 for r in rs) / len(rs), 1) if any(r['battle_duration_s'] for r in rs) else None),
    }
out['summary'] = summary
io.open(os.path.join(EV, 'level_curve.json'), 'w', encoding='utf-8').write(
    json.dumps(out, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False, indent=1))
print('runs:', len(rows), '-> level_curve.json written')
