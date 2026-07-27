extends RefCounted
class_name PhaseMasterSkillTreeV8Extension
## ═══════════════════════════════════════════════════════════
##  v8.x 相位师技能树扩展（40 个新节点，4 分支 × 10 节点）
##
##  本文件独立于 phase_master_skill_tree.gd 主文件，避免破坏现有 20 节点结构。
##  PhaseMasterSkillTree 通过 get_skills_for_branch() 合并本扩展：
##    主表 SKILL_TREE[branch] + V8Extension.get_extension_nodes(branch)
##
##  新增解锁类型（unlocks[].type）：
##    card_skill      → 卡片定时技能解锁（CardPeriodicSkillEngine 查询）
##    tactic          → 战法解锁（TacticDetector 查询）
##    unit_mechanism  → 兵种特殊机制解锁（已有，本扩展追加 stalker/ecm 等）
##
##  新增效果字段（effects）：
##    stat_bonus      → 累加到 get_active_effects()（已有）
##    conditional     → 条件型 Buff（已有）
##    aura            → 光环（已有）
## ═══════════════════════════════════════════════════════════

const BRANCH_COMMAND := "command"
const BRANCH_INTELLIGENCE := "intelligence"
const BRANCH_FIREPOWER := "firepower"
const BRANCH_CONCEPT_WEAPON := "concept_weapon"

## 4 分支扩展节点（tier 5-12），每节点结构与 phase_master_skill_tree.gd 完全一致
const EXTENSION_NODES: Dictionary = {
	# ═══════════ 指挥分支扩展（10 节点）：渗透战术 / 工兵 / 战法 ═══════════
	BRANCH_COMMAND: [
		# tier 5：渗透战术（解锁 STALKER 兵种）
		{"id": "pms_cmd_5", "name": "渗透战术", "desc": "解锁 STALKER 兵种：部署后前 4 秒受伤 -60%，首次攻击×1.5",
		 "branch": BRANCH_COMMAND, "tier": 5, "cost": 2, "requires": ["pms_cmd_4"],
		 "unlocks": [{"type": "unit_mechanism", "id": "stalker_stealth"}],
		 "effects": {"stat_bonus": {"stealth_grace_duration": 4.0, "first_hit_mult": 0.50}}},
		# tier 6：工兵部队（解锁 ENGINEER 兵种 + 卡片技能触发源）
		{"id": "pms_cmd_6", "name": "工兵部队", "desc": "解锁 ENGINEER 兵种：定时触发维修/布雷/净化技能",
		 "branch": BRANCH_COMMAND, "tier": 6, "cost": 2, "requires": ["pms_cmd_5"],
		 "unlocks": [{"type": "unit_mechanism", "id": "engineer_build"},
		             {"type": "card_skill", "id": "cps_repair_aura"},
		             {"type": "card_skill", "id": "cps_cleanse"}],
		 "effects": {}},
		# tier 7a：钳形攻势（战法）
		{"id": "pms_cmd_7a", "name": "钳形攻势", "desc": "解锁战法「钳形攻势」：≥2 ARMOR + ≥1 FAST 时 ARMOR 对最高威胁+25% 伤害",
		 "branch": BRANCH_COMMAND, "tier": 7, "cost": 3, "requires": ["pms_cmd_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_pincer"}],
		 "effects": {}},
		# tier 7b：刺猬防御（战法）
		{"id": "pms_cmd_7b", "name": "刺猬防御", "desc": "解锁战法「刺猬防御」：≥3 FORT + ≥1 ENGINEER 时全体 -25% 受伤",
		 "branch": BRANCH_COMMAND, "tier": 7, "cost": 3, "requires": ["pms_cmd_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_hedgehog"}],
		 "effects": {}},
		# tier 8：军团方阵
		{"id": "pms_cmd_8", "name": "军团方阵", "desc": "解锁战法「龟甲阵」：≥4 FORT 时全体 -35% 受伤；FORT +15% HP",
		 "branch": BRANCH_COMMAND, "tier": 8, "cost": 3, "requires": ["pms_cmd_7a"],
		 "unlocks": [{"type": "tactic", "id": "tactic_testudo"}],
		 "effects": {"stat_bonus": {"max_hp_fort": 0.15}}},
		# tier 9a：围点打援
		{"id": "pms_cmd_9a", "name": "围点打援", "desc": "解锁战法「围点打援」：FORT 受伤 -20%，ARMOR 对新进入敌方+50%",
		 "branch": BRANCH_COMMAND, "tier": 9, "cost": 3, "requires": ["pms_cmd_8"],
		 "unlocks": [{"type": "tactic", "id": "tactic_siege_intercept"}],
		 "effects": {}},
		# tier 9b：纵深作战
		{"id": "pms_cmd_9b", "name": "纵深作战", "desc": "解锁战法「纵深作战」：≥3 不同兵种时全体 +10% 全属性；单位上限+2",
		 "branch": BRANCH_COMMAND, "tier": 9, "cost": 3, "requires": ["pms_cmd_8"],
		 "unlocks": [{"type": "tactic", "id": "tactic_depth_operation"}],
		 "effects": {"stat_bonus": {"unit_limit": 2}}},
		# tier 10：战术大师（强化所有战法）
		{"id": "pms_cmd_10", "name": "战术大师", "desc": "全部已解锁战法效果 +20%；全体三维防御+10%",
		 "branch": BRANCH_COMMAND, "tier": 10, "cost": 4, "requires": ["pms_cmd_9a", "pms_cmd_9b"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"tactic_effect_mult": 0.20, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}}},
		# tier 11：闪电穿插（高级战法）
		{"id": "pms_cmd_11", "name": "闪电穿插", "desc": "解锁高级战法「闪电穿插」：≥3 FAST 时 FAST 攻速+40%、伤害+30%",
		 "branch": BRANCH_COMMAND, "tier": 11, "cost": 4, "requires": ["pms_cmd_10"],
		 "unlocks": [{"type": "tactic", "id": "tactic_blitz"}],
		 "effects": {}},
		# tier 12：天罗地网（高级战法）
		{"id": "pms_cmd_12", "name": "天罗地网", "desc": "解锁高级战法「天罗地网」：STEEL+THUNDER 时全体敌方攻速-30%、移速-30%",
		 "branch": BRANCH_COMMAND, "tier": 12, "cost": 5, "requires": ["pms_cmd_11"],
		 "unlocks": [{"type": "tactic", "id": "tactic_sky_net"}],
		 "effects": {}},
	],

	# ═══════════ 火力分支扩展（10 节点）：狙击手 / 火炮协调 / 战法 ═══════════
	BRANCH_FIREPOWER: [
		# tier 5：狙击手培养（解锁 SNIPER 兵种）
		{"id": "pms_fp_5", "name": "狙击手培养", "desc": "解锁 SNIPER 兵种：射程+30%，首次攻击必暴击",
		 "branch": BRANCH_FIREPOWER, "tier": 5, "cost": 2, "requires": ["pms_fp_4"],
		 "unlocks": [{"type": "unit_mechanism", "id": "sniper_training"}],
		 "effects": {"stat_bonus": {"attack_range_sniper": 0.30, "first_hit_crit_chance": 1.0}}},
		# tier 6：火炮协调（卡片技能）
		{"id": "pms_fp_6", "name": "火炮协调", "desc": "解锁卡片技能「炮兵协调射击」：每 15s 对敌方密集区炮击",
		 "branch": BRANCH_FIREPOWER, "tier": 6, "cost": 2, "requires": ["pms_fp_5"],
		 "unlocks": [{"type": "card_skill", "id": "cps_artillery_coord"}],
		 "effects": {}},
		# tier 7a：箭矢阵（战法）
		{"id": "pms_fp_7a", "name": "箭矢阵", "desc": "解锁战法「箭矢阵」：≥3 SNIPER 时 SNIPER 射程+30%、伤害+25%、必命中",
		 "branch": BRANCH_FIREPOWER, "tier": 7, "cost": 3, "requires": ["pms_fp_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_arrow"}],
		 "effects": {}},
		# tier 7b：饱和打击（战法）
		{"id": "pms_fp_7b", "name": "饱和打击", "desc": "解锁战法「饱和打击」：≥2 ARTILLERY + ≥1 ECM 时火炮伤害+50%、射程+20%",
		 "branch": BRANCH_FIREPOWER, "tier": 7, "cost": 3, "requires": ["pms_fp_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_saturation"}],
		 "effects": {}},
		# tier 8：斩首行动（战法）
		{"id": "pms_fp_8", "name": "斩首行动", "desc": "解锁战法「斩首行动」：SNIPER+STALKER+VOID 时对 Boss/相位师伤害×2",
		 "branch": BRANCH_FIREPOWER, "tier": 8, "cost": 3, "requires": ["pms_fp_7a"],
		 "unlocks": [{"type": "tactic", "id": "tactic_decapitation"}],
		 "effects": {}},
		# tier 9a：电磁轨道炮（卡片技能）
		{"id": "pms_fp_9a", "name": "电磁轨道炮", "desc": "解锁卡片技能「电磁轨道炮」：每 30s 对最高 HP 敌方 350% 穿甲伤害",
		 "branch": BRANCH_FIREPOWER, "tier": 9, "cost": 3, "requires": ["pms_fp_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_railgun"}],
		 "effects": {}},
		# tier 9b：超视距打击（卡片技能）
		{"id": "pms_fp_9b", "name": "超视距打击", "desc": "解锁卡片技能「超视距标记」：每 18s 标记最高威胁敌方",
		 "branch": BRANCH_FIREPOWER, "tier": 9, "cost": 3, "requires": ["pms_fp_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_bvr_mark"}],
		 "effects": {}},
		# tier 10：火力精通
		{"id": "pms_fp_10", "name": "火力精通", "desc": "全体三维攻击+10%；SNIPER 伤害+25%",
		 "branch": BRANCH_FIREPOWER, "tier": 10, "cost": 4, "requires": ["pms_fp_9a", "pms_fp_9b"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"atk_light": 0.10, "atk_armor": 0.10, "atk_air": 0.10, "sniper_damage_bonus": 0.25}}},
		# tier 11：凤凰涅槃（高级战法）
		{"id": "pms_fp_11", "name": "凤凰涅槃", "desc": "解锁高级战法「凤凰涅槃」：FLAME 时全体 HP+20%，死亡 20% 复活",
		 "branch": BRANCH_FIREPOWER, "tier": 11, "cost": 4, "requires": ["pms_fp_10"],
		 "unlocks": [{"type": "tactic", "id": "tactic_phoenix"}],
		 "effects": {}},
		# tier 12：四维打击（高级战法）
		{"id": "pms_fp_12", "name": "四维打击", "desc": "解锁高级战法「四维打击」：4 家族技能时全体 +25% 全属性",
		 "branch": BRANCH_FIREPOWER, "tier": 12, "cost": 5, "requires": ["pms_fp_11"],
		 "unlocks": [{"type": "tactic", "id": "tactic_4d_strike"}],
		 "effects": {}},
	],

	# ═══════════ 智能化分支扩展（10 节点）：电子战 / 卡片技能 / 战法 ═══════════
	BRANCH_INTELLIGENCE: [
		# tier 5：电子战（解锁 ECM 兵种）
		{"id": "pms_int_5", "name": "电子战", "desc": "解锁 ECM 兵种：光环减敌方攻速-25%、暴击-15%、闪避-20%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 5, "cost": 2, "requires": ["pms_int_4"],
		 "unlocks": [{"type": "unit_mechanism", "id": "ecm_aura"}],
		 "effects": {"aura": {"radius": 2.5, "target": "enemy",
		                     "debuff": {"attack_speed": -0.25, "crit_chance": -0.15, "dodge_chance": -0.20}}}},
		# tier 6：EMP 战术（卡片技能）
		{"id": "pms_int_6", "name": "EMP 战术", "desc": "解锁卡片技能「EMP 打击」：每 12s 对最高威胁敌方攻速-60%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 6, "cost": 2, "requires": ["pms_int_5"],
		 "unlocks": [{"type": "card_skill", "id": "cps_emp_strike"}],
		 "effects": {}},
		# tier 7a：声东击西（战法）
		{"id": "pms_int_7a", "name": "声东击西", "desc": "解锁战法「声东击西」：ECM+2 FAST 时 FAST 暴击+25%，ECM 受伤-25%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 7, "cost": 3, "requires": ["pms_int_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_feint"}],
		 "effects": {}},
		# tier 7b：新月阵（战法）
		{"id": "pms_int_7b", "name": "新月阵", "desc": "解锁战法「新月阵」：2 FAST 两侧分布时 FAST 伤害+30%，中央防御+30%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 7, "cost": 3, "requires": ["pms_int_6"],
		 "unlocks": [{"type": "tactic", "id": "tactic_crescent"}],
		 "effects": {}},
		# tier 8：自适应护盾（卡片技能）
		{"id": "pms_int_8", "name": "自适应护盾", "desc": "解锁卡片技能「自适应护盾」：HP<30% 时自动+2000 护盾",
		 "branch": BRANCH_INTELLIGENCE, "tier": 8, "cost": 3, "requires": ["pms_int_7a"],
		 "unlocks": [{"type": "card_skill", "id": "cps_adaptive_shield"}],
		 "effects": {}},
		# tier 9a：智能维修（卡片技能）
		{"id": "pms_int_9a", "name": "智能维修", "desc": "解锁卡片技能「定时维修」：每 10s 全体机械+3% HP",
		 "branch": BRANCH_INTELLIGENCE, "tier": 9, "cost": 3, "requires": ["pms_int_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_smart_repair"}],
		 "effects": {}},
		# tier 9b：智能净化（卡片技能）
		{"id": "pms_int_9b", "name": "智能净化", "desc": "解锁卡片技能「定时净化」：每 18s 清除全体 debuff",
		 "branch": BRANCH_INTELLIGENCE, "tier": 9, "cost": 3, "requires": ["pms_int_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_smart_cleanse"}],
		 "effects": {}},
		# tier 10：AI 指挥
		{"id": "pms_int_10", "name": "AI 指挥", "desc": "全体友军攻速+15%、暴击+10%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 10, "cost": 4, "requires": ["pms_int_9a", "pms_int_9b"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"attack_speed": 0.15, "crit_chance": 0.10}}},
		# tier 11：虚空降临（高级战法）
		{"id": "pms_int_11", "name": "虚空降临", "desc": "解锁高级战法「虚空降临」：2 VOID 时全体敌方受到伤害+20%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 11, "cost": 4, "requires": ["pms_int_10"],
		 "unlocks": [{"type": "tactic", "id": "tactic_void_descent"}],
		 "effects": {}},
		# tier 12：诸神黄昏（高级战法）
		{"id": "pms_int_12", "name": "诸神黄昏", "desc": "解锁高级战法「诸神黄昏」：4 终极技能时全体 +40% 全属性，敌方每秒-1% HP",
		 "branch": BRANCH_INTELLIGENCE, "tier": 12, "cost": 5, "requires": ["pms_int_11"],
		 "unlocks": [{"type": "tactic", "id": "tactic_ragnarok"}],
		 "effects": {}},
	],

	# ═══════════ 概念武器分支扩展（10 节点）：卡片终极技能 ═══════════
	BRANCH_CONCEPT_WEAPON: [
		# tier 5：钢铁风暴（卡片技能——召唤傀儡）
		{"id": "pms_cw_5", "name": "钢铁风暴", "desc": "解锁卡片技能「召唤钢铁傀儡」：每 90s 召唤 3 个临时单位",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 5, "cost": 3, "requires": ["pms_cw_4"],
		 "unlocks": [{"type": "card_skill", "id": "cps_steel_storm"}],
		 "effects": {}},
		# tier 6：焚城（卡片技能——全图火焰轰炸）
		{"id": "pms_cw_6", "name": "焚城", "desc": "解锁卡片技能「全图火焰轰炸」：每 100s 全图 250 火伤+燃烧",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 6, "cost": 3, "requires": ["pms_cw_5"],
		 "unlocks": [{"type": "card_skill", "id": "cps_burn_city"}],
		 "effects": {}},
		# tier 7a：天罚雷阵（卡片技能）
		{"id": "pms_cw_7a", "name": "天罚雷阵", "desc": "解锁卡片技能「全图雷击」：每 100s 15 道闪电，全图感电",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 7, "cost": 3, "requires": ["pms_cw_6"],
		 "unlocks": [{"type": "card_skill", "id": "cps_heaven_thunder"}],
		 "effects": {}},
		# tier 7b：湮灭之光（卡片技能——全图虚空+斩杀）
		{"id": "pms_cw_7b", "name": "湮灭之光", "desc": "解锁卡片技能「全图虚空伤害」：3s 蓄力后全图 300% ATK，HP<30% 斩杀",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 7, "cost": 3, "requires": ["pms_cw_6"],
		 "unlocks": [{"type": "card_skill", "id": "cps_annihilate"}],
		 "effects": {}},
		# tier 8：时间迟缓（卡片技能）
		{"id": "pms_cw_8", "name": "时间迟缓", "desc": "解锁卡片技能「全场减速」：每 30s 全体敌方移速-50%、攻速-50%（4s）",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 8, "cost": 4, "requires": ["pms_cw_7a"],
		 "unlocks": [{"type": "card_skill", "id": "cps_time_slow"}],
		 "effects": {}},
		# tier 9：现实崩溃（卡片技能——斩杀）
		{"id": "pms_cw_9", "name": "现实崩溃", "desc": "解锁卡片技能「斩杀低 HP」：每 60s HP<15% 敌方直接斩杀",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 9, "cost": 4, "requires": ["pms_cw_8"],
		 "unlocks": [{"type": "card_skill", "id": "cps_reality_collapse"}],
		 "effects": {}},
		# tier 10：维度叠加（卡片技能——全体虚化）
		{"id": "pms_cw_10", "name": "维度叠加", "desc": "解锁卡片技能「全体虚化」：每 150s 全体闪避+40%、受伤-30%（12s）",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 10, "cost": 4, "requires": ["pms_cw_9"],
		 "unlocks": [{"type": "card_skill", "id": "cps_dimension_overlay"}],
		 "effects": {}},
		# tier 11：时间回溯（卡片技能——回血清 debuff）
		{"id": "pms_cw_11", "name": "时间回溯", "desc": "解锁卡片技能「全体回血」：每 90s 全体恢复 30% HP+清除 debuff",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 11, "cost": 5, "requires": ["pms_cw_10"],
		 "unlocks": [{"type": "card_skill", "id": "cps_time_rewind"}],
		 "effects": {}},
		# tier 12a：焦土政策（卡片技能）
		{"id": "pms_cw_12a", "name": "焦土政策", "desc": "解锁卡片技能「区域燃烧」：每 16s 敌方密集区燃烧 8s",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 12, "cost": 5, "requires": ["pms_cw_11"],
		 "unlocks": [{"type": "card_skill", "id": "cps_scorched_earth"}],
		 "effects": {}},
		# tier 12b：烈焰风暴（卡片技能——全图燃烧）
		{"id": "pms_cw_12b", "name": "烈焰风暴", "desc": "解锁卡片技能「全图燃烧」：每 80s 全图燃烧+恐慌",
		 "branch": BRANCH_CONCEPT_WEAPON, "tier": 12, "cost": 5, "requires": ["pms_cw_11"],
		 "unlocks": [{"type": "card_skill", "id": "cps_firestorm"}],
		 "effects": {}},
	],
}

## 获取指定分支的扩展节点
static func get_extension_nodes(branch: String) -> Array:
	return EXTENSION_NODES.get(branch, []).duplicate(true)

## 获取所有扩展节点（扁平化）
static func get_all_extension_nodes() -> Array:
	var all: Array = []
	for branch in EXTENSION_NODES.keys():
		for node in EXTENSION_NODES[branch]:
			all.append(node)
	return all

## 根据 ID 查找扩展节点
static func get_extension_skill(skill_id: String) -> Dictionary:
	for branch in EXTENSION_NODES.keys():
		for node in EXTENSION_NODES[branch]:
			if node.get("id", "") == skill_id:
				return node.duplicate(true)
	return {}
