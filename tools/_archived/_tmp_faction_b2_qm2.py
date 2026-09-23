# -*- coding: utf-8 -*-
"""2b + 2c PartA 行级安全版：quest_manager 双新目标 + attack/defend 退役。
行级状态机删除（锚点成对），全文件统一 LF 落盘。"""
import io

P = 'managers/quest_manager.gd'
raw = io.open(P, encoding='utf-8', newline='').read()
lines = raw.splitlines()
fails = []


def find_idx(pred, start=0):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return -1


def delete_span(a_anchor, b_anchor, tag, include_a=True, include_b=True):
    """删除 [a_anchor 行, b_anchor 行] 区间（含端点按 include_*）。"""
    ai = find_idx(lambda l: a_anchor in l)
    if ai < 0:
        fails.append(tag + ':A')
        return
    bi = find_idx(lambda l: b_anchor in l, ai)
    if bi < 0:
        fails.append(tag + ':B')
        return
    lo = ai if include_a else ai + 1
    hi = bi + 1 if include_b else bi
    del lines[lo:hi]


def insert_after(anchor, new_lines, tag, skip=0):
    ai = find_idx(lambda l: anchor in l)
    if ai < 0:
        fails.append(tag + ':anchor')
        return
    lines[ai + 1 + skip:ai + 1 + skip] = new_lines


def replace_line(anchor, new_line, tag):
    ai = find_idx(lambda l: anchor in l)
    if ai < 0:
        fails.append(tag + ':anchor')
        return
    lines[ai] = new_line


# ── 2b 头注 ──
replace_line('##   reach_reputation  — 声望达到N（实时查询 FactionSystemManager）',
             '##   reach_reputation  — 贡献达到N（实时查询 FactionSystemManager；UI 口径=贡献，v6.22）', 'hdr_rr')
insert_after('##   reach_reputation  — 贡献达到N',
             ['##   reach_intel      — 某敌形情报研究%达到N（实时查询 IntelManual，零信号；v6.22 新增）',
              '##   salvage_items    — 回收N件战利品（内部计数 salvaged，ground_loot_layer 收集链上报；v6.22 新增）'],
             'hdr_new')

# ── 2b 进度分支（挂 reach_reputation 后）──
insert_after('return _get_max_reputation()',
             ['\tif otype == "reach_intel":',
              '\t\treturn _get_archetype_intel_percent(String(def.get("target", {}).get("archetype_id", "")))',
              '\tif otype == "salvage_items":',
              '\t\treturn int(progress.get("salvaged", 0))'],
             'progress', skip=1)

# ── 2b 完成判定分支（挂 reach_reputation >= 后）──
insert_after('return _get_max_reputation() >= int(target_val)',
             ['\tif otype == "reach_intel":',
              '\t\treturn _get_archetype_intel_percent(String(def.get("target", {}).get("archetype_id", ""))) >= int(target_val)',
              '\tif otype == "salvage_items":',
              '\t\treturn int(progress.get("salvaged", 0)) >= int(target_val)'],
             'done')

# ── 2b 显示分支 ──
insert_after('var target: Variant = def.get("target", 0)',
             ['\tif otype == "reach_intel":',
              '\t\treturn int(def.get("target", {}).get("target", 0))'],
             'display')

# ── 2b notify_items_salvaged（挂 notify_item_bought 整函数后）──
insert_after('\t\t\t_inc_progress(qid, "buy_count")',
             ['\t\t\t_try_complete(qid)', '',
              '## v6.22: 战利品回收上报（ground_loot_layer _quick_collect/_collect_all_staggered 汇总口调用；',
              '## 培养性委托 salvage_items 计数，参考 notify_item_bought 先例）',
              'func notify_items_salvaged(count: int = 1) -> void:',
              '\tif count <= 0:',
              '\t\treturn',
              '\tfor qid in _accepted.keys():',
              '\t\tvar def: Dictionary = QuestDefs.get_by_id(qid)',
              '\t\tif def.get("objective_type", "") == "salvage_items":',
              '\t\t\t_inc_progress(qid, "salvaged", count)',
              '\t\t\t_try_complete(qid)'],
             'notify_salv', skip=1)

# ── 2b 情报 % 助手（挂 _get_max_reputation 定义前）──
ai = find_idx(lambda l: l.startswith('func _get_max_reputation'))
if ai < 0:
    fails.append('intel_helper:anchor')
else:
    lines[ai:ai] = ['## v6.22: 敌形情报 % 整数口径（0-100；实时查 IntelManual，零信号照 reach_reputation 模式）',
                    'func _get_archetype_intel_percent(archetype_id: String) -> int:',
                    '\tif archetype_id.is_empty():',
                    '\t\treturn 0',
                    '\tvar im: Node = get_node_or_null("/root/IntelManual")',
                    '\tif im == null or not im.has_method("get_intel_progress"):',
                    '\t\treturn 0',
                    '\treturn clampi(int(round(float(im.get_intel_progress(archetype_id)) * 100.0)), 0, 100)',
                    '', '']

# ── 2c PartA ──
# 头注两行删（行级精确匹配）
for anchor in ['##   attack_faction   — 击败指定相位师（内部追踪）',
               '##   defend_faction   — 在指定势力关卡击败相位师（内部追踪）']:
    i = find_idx(lambda l, a=anchor: l == a)
    if i < 0:
        fails.append('hdr_ad')
    else:
        del lines[i]
i = find_idx(lambda l: l == '##   collect_fragments — 已废弃，等同 collect_cards（兼容旧存档任务）')
if i >= 0:
    lines[i + 1:i + 1] = ['##   （v6.22: attack_faction/defend_faction 战争框架已退役）']

# notify_phase_master_defeated 整函数删：从注释行到「内部进度追踪」节头前
delete_span('## 通知任务系统：击败了相位师', '# ──────────────── 内部进度追踪', 'notify_fn')

# 进度分支 attack/defend 两行删
i = find_idx(lambda l: l.strip() == 'if otype in ["attack_faction", "defend_faction"]:')
if i < 0:
    fails.append('progress_ad')
else:
    assert 'get_quest_progress_for_mission' in lines[i + 1]
    del lines[i:i + 2]

# is_quest_done attack/defend 分支删：attack_faction 行 → collect_fragments 行前
delete_span('if otype == "attack_faction":', 'if otype == "collect_fragments":', 'done_ad', include_b=False)

# get_quest_progress_for_mission 整函数删：func 行 → 「进攻/防守任务辅助」节头后到下一节头
i = find_idx(lambda l: l.startswith('func get_quest_progress_for_mission'))
if i < 0:
    fails.append('gm_fn:A')
else:
    j = find_idx(lambda l: l.startswith('func ') or (l.startswith('# ─') and i > 0), i + 1)
    # 找该函数后第一个 func 或 section 头（含 v6.22 注记行区间）
    k = find_idx(lambda l: l.startswith('func refresh_faction_quests'))
    if k < 0:
        fails.append('gm_fn:B')
    else:
        # 向上吞掉紧邻的空行与节头注释「进攻/防守任务辅助」
        lo = i
        while lo > 0 and (lines[lo - 1].strip() == '' or lines[lo - 1].startswith('#') or lines[lo - 1].startswith('##')):
            lo -= 1
        lo += 1
        del lines[lo:k]

out = '\n'.join(lines) + '\n'
io.open(P, 'w', encoding='utf-8', newline='\n').write(out)
print("FAILS:", fails if fails else "none", "| lines:", len(lines))
