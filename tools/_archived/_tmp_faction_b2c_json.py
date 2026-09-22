# -*- coding: utf-8 -*-
"""批2c Part C：quest_definitions JSON 57条改版 + LEGACY_QUESTS 同步 + 头注（势力批2）"""
import io
import json

fails = []

# ═══ 1. JSON 改版 ═══
JP = 'data/json/quest_definitions.json'
doc = json.load(io.open(JP, encoding='utf-8'))
data = doc['data']

RETARGET = {
    "q_attack_void": {"objective_type": "clear_boss_count", "target": 2, "title": "铲除相位威胁",
                      "description": "击败 2 个相位师盘踞的首领关卡（每时代终点关），为新星兵工肃清前进通道。",
                      "rewards": {"nano_materials": 300, "faction_rep": {"nova_arms": 25}}},
    "q_attack_nova": {"objective_type": "kill_enemies", "target": 60, "title": "火力破袭",
                      "description": "累计击毁 60 个敌方单位，为钢壁防务检验新一批装甲装备。",
                      "rewards": {"nano_materials": 300, "faction_rep": {"iron_wall_corp": 25}}},
    "q_attack_aether": {"objective_type": "win_battles", "target": 5, "title": "协同演练",
                        "description": "胜利完成 5 场战斗，与以太动力校准后勤护送节奏。",
                        "rewards": {"nano_materials": 300, "faction_rep": {"quantum_logistics": 25}}},
    "q_defend_iron": {"objective_type": "clear_boss_count", "target": 1, "title": "关隘肃清",
                      "description": "攻克 1 个相位师盘踞的首领关卡，帮钢壁防务回收废弃装备。",
                      "rewards": {"nano_materials": 240, "faction_rep": {"iron_wall_corp": 30}}},
    "q_defend_frontier": {"objective_type": "kill_enemies", "target": 50, "title": "商路护航",
                          "description": "累计击毁 50 个敌方单位，为边境联合的运输队打开安全通道。",
                          "rewards": {"nano_materials": 240, "faction_rep": {"frontier_union": 30}}},
    "q_defend_helix": {"objective_type": "win_battles", "target": 6, "title": "纵深侦察",
                       "description": "胜利完成 6 场战斗，为螺旋侦察带回纵深情报。",
                       "rewards": {"nano_materials": 240, "faction_rep": {"helix_recon": 30}}},
}
RETARGET_REP = {
    "q_tutorial_faction": {"target": 1200, "title": "组织联络", "description": "任一组织对你的贡献达到 1200。"},
    "q_faction_helix_30": {"target": 2000, "title": "螺旋同路：信赖", "description": "任一组织贡献达到 2000（螺旋侦察同贺）。"},
    "q_faction_iron_30": {"target": 2000, "title": "钢壁盟友", "description": "任一组织贡献达到 2000（钢壁防务同贺）。"},
    "q_faction_nova_30": {"target": 2000, "title": "新星同路人", "description": "任一组织贡献达到 2000（新星兵工同贺）。"},
    "q_faction_aether_30": {"target": 2000, "title": "以太之友", "description": "任一组织贡献达到 2000（以太动力同贺）。"},
    "q_faction_void_30": {"target": 2000, "title": "虚空探索者", "description": "任一组织贡献达到 2000（虚空相位同贺）。"},
    "q_faction_all_20": {"target": 1500, "title": "多方认可", "description": "任一组织贡献达到 1500，赢得多方协作认可。"},
    "q_faction_max_50": {"target": 6200, "title": "全域信赖", "description": "任一组织贡献达到 6200（激活商店全域访问）。"},
}

hit_rt = hit_rr = 0
for q in data:
    qid = q.get('id', '')
    if qid in RETARGET:
        q.update(RETARGET[qid])
        hit_rt += 1
    elif qid in RETARGET_REP:
        q.update(RETARGET_REP[qid])
        hit_rr += 1
    rw = q.get('rewards', {})
    if 'company_rep' in rw:
        rw['faction_rep'] = rw.pop('company_rep')
    # 文案换轴兜底：描述/标题残余「声望」→「贡献」
    for k in ('title', 'description'):
        if '声望' in str(q.get(k, '')):
            q[k] = str(q[k]).replace('声望', '贡献')

io.open(JP, 'w', encoding='utf-8', newline='\n').write(
    json.dumps(doc, ensure_ascii=False, indent=2) + '\n')
print('json: retarget=%d rep=%d total=%d' % (hit_rt, hit_rr, len(data)))
if hit_rt != 6:
    fails.append('json_retarget=%d' % hit_rt)
if hit_rr != 8:
    fails.append('json_rep=%d' % hit_rr)

# ═══ 2. LEGACY_QUESTS 同步（.gd 精确块替换）═══
GP = 'data/quest_definitions.gd'
s = io.open(GP, encoding='utf-8', newline='').read()


def rep(old, new, tag, cnt=1):
    global s
    n = s.count(old)
    if n < cnt:
        fails.append(tag)
        return
    s = s.replace(old, new)


rep('''##   - attack_faction: 进攻任务，击败某势力的相位师
##   - defend_faction: 防守任务，保护某势力免受相位师进攻''',
    '##   - （v6.22: attack_faction/defend_faction 战争框架已退役，委托改贡献驱动三类模板）', 'hdr1')
rep('''##   - attack_faction→{target_faction: 势力ID, target_master: 相位师名}
##   - defend_faction→{defend_faction: 势力ID, attacker_master: 相位师名}
''', '', 'hdr2')
rep('## company_rep 与 FactionSystemManager 声望同源（任务奖励仍可用 company_rep 键名）',
    '## faction_rep 与 FactionSystemManager 贡献轴同源（读侧保留 company_rep 旧键兼容；v6.22 新写统一 faction_rep）', 'hdr3')

LEGACY_RT = [
    ('''		"id": "q_attack_void",
		"title": "进攻：虚空相位",
		"description": "击败虚空相位的驻守相位师「终焉之镰」，夺取其领地。",
		"objective_type": "attack_faction",
		"target": {"target_faction": "void_research", "target_master": "终焉之镰"},
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 240,
			"faction_rep": {"nova_arms": 25, "void_research": -20},
		},''',
     '''		"id": "q_attack_void",
		"title": "铲除相位威胁",
		"description": "击败 2 个相位师盘踞的首领关卡（每时代终点关），为新星兵工肃清前进通道。",
		"objective_type": "clear_boss_count",
		"target": 2,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"nova_arms": 25},
		},'''),
    ('''		"id": "q_attack_nova",
		"title": "进攻：新星兵工",
		"description": "击败新星兵工的驻守相位师「炽焰星痕」，夺取其领地。",
		"objective_type": "attack_faction",
		"target": {"target_faction": "nova_arms", "target_master": "炽焰星痕"},
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 240,
			"faction_rep": {"iron_wall_corp": 25, "nova_arms": -20},
		},''',
     '''		"id": "q_attack_nova",
		"title": "火力破袭",
		"description": "累计击毁 60 个敌方单位，为钢壁防务检验新一批装甲装备。",
		"objective_type": "kill_enemies",
		"target": 60,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"iron_wall_corp": 25},
		},'''),
    ('''		"id": "q_attack_aether",
		"title": "进攻：以太动力",
		"description": "击败以太动力的驻守相位师「雷霆判官」，瓦解其防御体系。",
		"objective_type": "attack_faction",
		"target": {"target_faction": "aether_dynamics", "target_master": "雷霆判官"},
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 240,
			"faction_rep": {"quantum_logistics": 25, "aether_dynamics": -20},
		},''',
     '''		"id": "q_attack_aether",
		"title": "协同演练",
		"description": "胜利完成 5 场战斗，与以太动力校准后勤护送节奏。",
		"objective_type": "win_battles",
		"target": 5,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"quantum_logistics": 25},
		},'''),
    ('''		"id": "q_defend_iron",
		"title": "防守：钢壁防务",
		"description": "守住钢壁防务领地，击退来犯的敌方相位师。",
		"objective_type": "defend_faction",
		"target": {"defend_faction": "iron_wall_corp"},''',
     '''		"id": "q_defend_iron",
		"title": "关隘肃清",
		"description": "攻克 1 个相位师盘踞的首领关卡，帮钢壁防务回收废弃装备。",
		"objective_type": "clear_boss_count",
		"target": 1,'''),
    ('''		"id": "q_defend_frontier",
		"title": "防守：边境联合",
		"description": "守住边境联合领地，击退敌方相位师的进攻。",
		"objective_type": "defend_faction",
		"target": {"defend_faction": "frontier_union"},''',
     '''		"id": "q_defend_frontier",
		"title": "商路护航",
		"description": "累计击毁 50 个敌方单位，为边境联合的运输队打开安全通道。",
		"objective_type": "kill_enemies",
		"target": 50,'''),
    ('''		"id": "q_defend_helix",
		"title": "防守：螺旋侦察",
		"description": "守住螺旋侦察的侦察网络，击退来犯之敌。",
		"objective_type": "defend_faction",
		"target": {"defend_faction": "helix_recon"},''',
     '''		"id": "q_defend_helix",
		"title": "纵深侦察",
		"description": "胜利完成 6 场战斗，为螺旋侦察带回纵深情报。",
		"objective_type": "win_battles",
		"target": 6,'''),
]
for old, new in LEGACY_RT:
    rep(old, new, 'legacy:' + old.split('"')[3])

# LEGACY 奖励键 company_rep → faction_rep（JSON 同步）
n_cr = s.count('"company_rep": ')
s = s.replace('"company_rep": ', '"faction_rep": ')
print('legacy company_rep→faction_rep:', n_cr)

# LEGACY reach_reputation 条目同步（与 JSON 同值）
LEGACY_REP = [
    ('"title": "势力接触",\n\t\t"description": "与任意势力建立关系（声望达到 10）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 10,',
     '"title": "组织联络",\n\t\t"description": "任一组织对你的贡献达到 1200。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 1200,'),
    ('"title": "各方势力",\n\t\t"description": "与全部 7 个势力的声望都达到 20。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 20,',
     '"title": "多方认可",\n\t\t"description": "任一组织贡献达到 1500，赢得多方协作认可。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 1500,'),
    ('"title": "势力领袖",\n\t\t"description": "与任意一个势力的声望达到 50。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 50,',
     '"title": "全域信赖",\n\t\t"description": "任一组织贡献达到 6200（激活商店全域访问）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 6200,'),
    ('"title": "钢壁盟友",\n\t\t"description": "与钢壁防务的声望达到 30。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 30,',
     '"title": "钢壁盟友",\n\t\t"description": "任一组织贡献达到 2000（钢壁防务同贺）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 2000,'),
    ('"title": "新星同路人",\n\t\t"description": "与新星兵工的声望达到 30。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 30,',
     '"title": "新星同路人",\n\t\t"description": "任一组织贡献达到 2000（新星兵工同贺）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 2000,'),
    ('"title": "以太之友",\n\t\t"description": "与以太动力的声望达到 30。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 30,',
     '"title": "以太之友",\n\t\t"description": "任一组织贡献达到 2000（以太动力同贺）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 2000,'),
    ('"title": "虚空探索者",\n\t\t"description": "与虚空相位的声望达到 30。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 30,',
     '"title": "虚空探索者",\n\t\t"description": "任一组织贡献达到 2000（虚空相位同贺）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 2000,'),
    ('"title": "螺旋声望：信赖",\n\t\t"description": "与螺旋侦察系统建立信赖关系（声望达到 30）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 30,',
     '"title": "螺旋同路：信赖",\n\t\t"description": "任一组织贡献达到 2000（螺旋侦察同贺）。",\n\t\t"objective_type": "reach_reputation",\n\t\t"target": 2000,'),
]
for old, new in LEGACY_REP:
    rep(old, new, 'legacy_rep:' + old[9:30])

io.open(GP, 'w', encoding='utf-8', newline='\n').write(s)
print('FAILS:', fails if fails else 'none')
