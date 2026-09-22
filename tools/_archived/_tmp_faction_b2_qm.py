# -*- coding: utf-8 -*-
"""2b + 2c PartA 重做（CRLF 安全版）：quest_manager 双新目标 + attack/defend 退役"""
import io
import re

P = 'managers/quest_manager.gd'
s = io.open(P, encoding='utf-8', newline='').read()
fails = []


def sub(pattern, repl, tag, n=1, flags=re.S):
    global s
    s2, cnt = re.subn(pattern, repl, s, count=n, flags=flags)
    if cnt != n:
        fails.append('%s(cnt=%d)' % (tag, cnt))
    else:
        s = s2


NL = r'\r?\n'

# ── 2b ──
sub(r'##   reach_reputation  — 声望达到N（实时查询 FactionSystemManager）' + NL,
    '##   reach_reputation  — 贡献达到N（实时查询 FactionSystemManager；UI 口径=贡献，v6.22）' + NL
    + '##   reach_intel      — 某敌形情报研究%达到N（实时查询 IntelManual，零信号；v6.22 新增）' + NL
    + '##   salvage_items    — 回收N件战利品（内部计数 salvaged，ground_loot_layer 收集链上报；v6.22 新增）' + NL,
    'hdr')

sub(r'(\tif otype == "reach_reputation":' + NL + r'\t\treturn _get_max_reputation\(\)' + NL + r')'
    r'(\tif otype == "buy_items":' + NL + r'\t\treturn int\(progress\.get\("buy_count", 0\)\)' + NL + r')',
    r'\1' + '\tif otype == "reach_intel":\n\t\treturn _get_archetype_intel_percent(String(def.get("target", {}).get("archetype_id", "")))\n'
    + '\tif otype == "salvage_items":\n\t\treturn int(progress.get("salvaged", 0))\n' + r'\2',
    'progress_branch')

sub(r'(\tif otype == "reach_reputation":' + NL + r'\t\treturn _get_max_reputation\(\) >= int\(target_val\)' + NL + r')'
    r'(\tif otype == "buy_items":' + NL + r'\t\treturn int\(progress\.get\("buy_count", 0\)\) >= int\(target_val\)' + NL + r')',
    r'\1' + '\tif otype == "reach_intel":\n\t\treturn _get_archetype_intel_percent(String(def.get("target", {}).get("archetype_id", ""))) >= int(target_val)\n'
    + '\tif otype == "salvage_items":\n\t\treturn int(progress.get("salvaged", 0)) >= int(target_val)\n' + r'\2',
    'done_branch')

sub(r'(\tif otype == "collect_cards" or otype == "reach_reputation" \\' + NL + r'\t\tor otype == "quick_win" or otype == "survive_waves":' + NL + r'\t\treturn int\(target\)' + NL + r')',
    '\tif otype == "reach_intel":\n\t\treturn int(def.get("target", {}).get("target", 0))\n' + r'\1',
    'display_branch')

sub(r'(## 商店购买后调用' + NL + r'func notify_item_bought\(\) -> void:' + NL
    + r'\tfor qid in _accepted\.keys\(\):' + NL
    + r'\t\tvar def: Dictionary = QuestDefs\.get_by_id\(qid\)' + NL
    + r'\t\tif def\.get\("objective_type", ""\) == "buy_items":' + NL
    + r'\t\t\t_inc_progress\(qid, "buy_count"\)' + NL
    + r'\t\t\t_try_complete\(qid\)' + NL + r')',
    r'\1\n\n## v6.22: 战利品回收上报（ground_loot_layer _quick_collect/_collect_all_staggered 汇总口调用；\n## 培养性委托 salvage_items 计数，参考 notify_item_bought 先例）\n'
    + 'func notify_items_salvaged(count: int = 1) -> void:\n\tif count <= 0:\n\t\treturn\n'
    + '\tfor qid in _accepted.keys():\n\t\tvar def: Dictionary = QuestDefs.get_by_id(qid)\n'
    + '\t\tif def.get("objective_type", "") == "salvage_items":\n\t\t\t_inc_progress(qid, "salvaged", count)\n\t\t\t_try_complete(qid)',
    'notify_salvaged')

sub(r'(func _get_max_reputation\(\) -> int:)',
    '## v6.22: 敌形情报 % 整数口径（0-100；实时查 IntelManual，零信号照 reach_reputation 模式）\n'
    'func _get_archetype_intel_percent(archetype_id: String) -> int:\n'
    '\tif archetype_id.is_empty():\n\t\treturn 0\n'
    '\tvar im: Node = get_node_or_null("/root/IntelManual")\n'
    '\tif im == null or not im.has_method("get_intel_progress"):\n\t\treturn 0\n'
    '\treturn clampi(int(round(float(im.get_intel_progress(archetype_id)) * 100.0)), 0, 100)\n\n\n' + r'\1',
    'intel_helper')

# ── 2c Part A ──
sub(r'##   attack_faction   — 击败指定相位师（内部追踪）' + NL + r'##   defend_faction   — 在指定势力关卡击败相位师（内部追踪）' + NL,
    '##   （v6.22: attack_faction/defend_faction 战争框架已退役删除）' + NL, 'hdr_ad')

sub(r'## 通知任务系统：击败了相位师' + NL + r'func notify_phase_master_defeated\(master_name: String\) -> void:.*?' + NL + NL,
    '', 'notify_fn_del')

sub(r'\tif otype in \["attack_faction", "defend_faction"\]:' + NL + r'\t\treturn get_quest_progress_for_mission\(quest_id\)' + NL + r'(\treturn 0)',
    r'\1', 'progress_ad_del')

sub(r'\tif otype == "attack_faction":' + NL + r'\t\treturn get_quest_progress_for_mission\(quest_id\)' + NL
    + r'\tif otype == "defend_faction":' + NL
    + r'\t\tvar t: Dictionary = def\.get\("target", \{\}\)' + NL
    + r'\t\tvar defend_faction: String = t\.get\("defend_faction", ""\)' + NL
    + r'\t\tvar LevelInfo = LevelInfoClass\.new\(\)' + NL
    + r'\t\tvar gm = get_node_or_null\("/root/GameManager"\)' + NL
    + r'\t\tvar current_level: int = gm\.get\("current_level"\) if gm else 1' + NL
    + r'\t\tvar current_faction: String = LevelInfo\.get_level_faction\(current_level\)' + NL
    + r'\t\tif current_faction != defend_faction:' + NL + r'\t\t\treturn false' + NL
    + r'\t\treturn data\.get\("defeated_masters", \[\]\)\.size\(\) > 0' + NL,
    '', 'done_ad_del')

sub(r'func get_quest_progress_for_mission\(quest_id: String\) -> int:.*?' + NL + r'\treturn 0' + NL + NL + NL,
    '## v6.22: 原 get_quest_progress_for_mission 已随 attack/defend 类型退役删除。\n\n\n',
    'progress_mission_del')

io.open(P, 'w', encoding='utf-8', newline='').write(s)
print("FAILS:", fails if fails else "none", "| lines:", s.count('\n'))
