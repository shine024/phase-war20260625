extends RefCounted
class_name PhaseMasterSkillTree

## ═══════════════════════════════════════════════════════════
##  相位师技能树（v8.x 新增）
##  全局独立养成系统，4 分支：指挥 / 智能化 / 火力 / 概念武器
##
##  技能点来源：相位场 XP 升级（PhaseInstrumentManager.grant_phase_field_xp）
##  解锁内容：相位仪 / 兵种特殊能力 / 新兵种独占机制 / 概念武器 / 特殊卡 / 进化 / affix
##
##  节点结构：
##    id:        唯一 ID（pms_<branch>_<n>）
##    name:      显示名称
##    desc:      描述
##    branch:    分支（command/intelligence/firepower/concept_weapon）
##    tier:      等级层（0-7，技能树深度，需逐层解锁）
##    cost:      技能点消耗
##    requires:  前置节点 ID 数组（全部解锁才能点本节点）
##    unlocks:   解锁内容（见下方 UNLOCK_TYPES）
##    effects:   战斗效果（stat_bonus/aura/conditional 等，参照 faction_skill_tree）
##
##  UNLOCK_TYPES（unlocks 字段的 type 值，驱动不同子系统）：
##    phase_instrument  → PhaseInstrumentManager.unlock_instrument(id)
##    unit_ability      → 兵种特殊能力解锁（原 enhance_level 解锁的暴击/吸血等）
##    unit_mechanism    → 兵种机制技能解锁（v8.5：定向爆破/瞄准狙击/闪电穿插/电子屏蔽/战术核武/护盾投射/定时标记）
##    evolution         → 进化形态解锁（替代 enhance_level 门槛）
##    affix             → affix 词条池赋予（替代随机 roll）
##    card_skill        → 卡片定时技能解锁（CardPeriodicSkillEngine 查询）
##    tactic            → 战法解锁（TacticDetector 查询）
##  v8.5 废弃类型（仅旧存档兼容读取，不再有新节点使用）：
##    concept_weapon    → 原概念武器大技（已改为 unit_mechanism 或 stat_bonus）
##    special_card      → 原特殊卡解锁（已改为 unit_mechanism）
## ═══════════════════════════════════════════════════════════

const BRANCH_COMMAND := "command"
const BRANCH_INTELLIGENCE := "intelligence"
const BRANCH_FIREPOWER := "firepower"
const BRANCH_CONCEPT_WEAPON := "concept_weapon"

## 技能点随相位场等级（Lv1-16）增长：v8.5 提升产量（Lv16: 15→28），让玩家能体验 2-3 个分支 + 多个机制技能
## 原：[0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]（满级15点只够1-2分支）
## 新：中期加速，满级28点可点满2分支+部分机制技能
const POINTS_BY_PHASE_FIELD_LEVEL := [0, 0, 1, 2, 3, 5, 7, 9, 11, 13, 16, 19, 22, 24, 26, 28, 30]

## 4 分支技能节点（v8.x 骨架版，阶段 1 先填代表性节点，阶段 6 逐步填充）
const SKILL_TREE: Dictionary = {
	# ═══════════ 指挥分支：单位上限 / 光环 / 部署 / 特殊卡 ═══════════
		"command": [
			# tier 0：起点（v8.5：原 unit_limit 字段战斗侧从不读取，改三维攻击）
			{"id": "pms_cmd_0", "name": "指挥觉醒", "desc": "相位师获得基础指挥能力，所有单位三维攻击 +5%",
			 "branch": BRANCH_COMMAND, "tier": 0, "cost": 1, "requires": [],
			 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.05, "atk_armor": 0.05, "atk_air": 0.05}}},
			# tier 1：攻击/攻速二选一（v8.5：原 unit_limit/deploy_speed 无效，换有效数值）
			{"id": "pms_cmd_1a", "name": "集结号令", "desc": "所有单位三维攻击 +8%",
			 "branch": BRANCH_COMMAND, "tier": 1, "cost": 1, "requires": ["pms_cmd_0"],
			 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}}},
			{"id": "pms_cmd_1b", "name": "急行军", "desc": "所有单位三维攻击 +8%（另一侧强化）",
			 "branch": BRANCH_COMMAND, "tier": 1, "cost": 1, "requires": ["pms_cmd_0"],
			 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}}},
			# tier 2：战术协调（v8.5：原 command_aura 空转——光环靠卡牌tags驱动与技能树无关，换暴击伤害）
			{"id": "pms_cmd_2", "name": "战术协调", "desc": "所有单位暴击伤害 +15%",
			 "branch": BRANCH_COMMAND, "tier": 2, "cost": 2, "requires": ["pms_cmd_1a"],
			 "unlocks": [], "effects": {"stat_bonus": {"crit_damage_bonus": 0.15}}},
			# tier 3：解锁一架指挥专用相位仪
			{"id": "pms_cmd_3", "name": "指挥相位仪", "desc": "解锁相位仪：擎天-战术核心",
			 "branch": BRANCH_COMMAND, "tier": 3, "cost": 2, "requires": ["pms_cmd_2"],
			 "unlocks": [{"type": "phase_instrument", "id": "pi_atlas_01"}],
			 "effects": {}},
			# tier 4：军团统帅（v8.5：删无效 unit_limit，三维防御 12%→15%）
			{"id": "pms_cmd_4", "name": "军团统帅", "desc": "所有友军三维防御 +15%",
			 "branch": BRANCH_COMMAND, "tier": 4, "cost": 3, "requires": ["pms_cmd_3"],
			 "unlocks": [], "effects": {"stat_bonus": {"def_light": 0.15, "def_armor": 0.15, "def_air": 0.15}}},
		# tier 4b：相位场强化（v8.6：单位+基地双效——hp 键同时作用于单位/产兵/基地三处）
		{"id": "pms_cmd_4b", "name": "相位场强化", "desc": "所有单位与相位场基地生命值 +20%",
		 "branch": BRANCH_COMMAND, "tier": 4, "cost": 2, "requires": ["pms_cmd_3"],
		 "unlocks": [], "effects": {"stat_bonus": {"hp": 0.20}}},
		],

	# ═══════════ 智能化分支：自动行为 / AI 加成 / 经验加成 / affix 赋予 ═══════════
	"intelligence": [
		# tier 0：起点
		{"id": "pms_int_0", "name": "智能核心", "desc": "相位师获得智能辅助，所有单位暴击率 +5%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 0, "cost": 1, "requires": [],
		 "unlocks": [], "effects": {"stat_bonus": {"crit_chance": 0.05}}},
		# tier 1：经验加成 / 闪避二选一
		{"id": "pms_int_1a", "name": "战斗学习", "desc": "战斗获得经验 +30%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 1, "cost": 1, "requires": ["pms_int_0"],
		 "unlocks": [], "effects": {"experience_bonus": 0.30}},
		{"id": "pms_int_1b", "name": "战术规避", "desc": "所有单位闪避 +8%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 1, "cost": 1, "requires": ["pms_int_0"],
		 "unlocks": [], "effects": {"stat_bonus": {"dodge_chance": 0.08}}},
		# tier 2：解锁 affix 词条赋予（替代随机 roll）
		{"id": "pms_int_2", "name": "模块化武装", "desc": "解锁 affix 词条系统：所有卡获得基础 affix 槽",
		 "branch": BRANCH_INTELLIGENCE, "tier": 2, "cost": 2, "requires": ["pms_int_1a"],
		 "unlocks": [{"type": "affix", "pool": ["affix_basic_atk", "affix_basic_def", "affix_basic_hp"]}],
		 "effects": {}},
			# tier 3：智能火控（v8.5：原 smart_targeting 未实装，换暴击+闪避数值）
			{"id": "pms_int_3", "name": "智能火控", "desc": "所有单位暴击率 +8%，闪避 +5%",
			 "branch": BRANCH_INTELLIGENCE, "tier": 3, "cost": 2, "requires": ["pms_int_2"],
			 "unlocks": [], "effects": {"stat_bonus": {"crit_chance": 0.08, "dodge_chance": 0.05}}},
		# tier 4：智能化终极——自动升级
		{"id": "pms_int_4", "name": "自适应进化", "desc": "战斗中存活超过 30 秒的单位全属性 +15%",
		 "branch": BRANCH_INTELLIGENCE, "tier": 4, "cost": 3, "requires": ["pms_int_3"],
		 "unlocks": [],
		 "effects": {"conditional": {"survive_seconds": 30.0, "stat_bonus": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15, "max_hp": 0.15}}}},
	],

	# ═══════════ 火力分支：三维攻击 / 暴击 / 穿甲 / 射程 / 兵种特殊能力 ═══════════
	"firepower": [
		# tier 0：起点
		{"id": "pms_fp_0", "name": "火力觉醒", "desc": "相位师获得火力增幅，所有单位三维攻击 +8%",
		 "branch": BRANCH_FIREPOWER, "tier": 0, "cost": 1, "requires": [],
		 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}}},
		# tier 1：穿甲 / 暴击二选一（兵种特殊能力解锁）
		{"id": "pms_fp_1a", "name": "穿甲弹道", "desc": "解锁穿甲能力：装甲单位对装甲目标穿透 +20%",
		 "branch": BRANCH_FIREPOWER, "tier": 1, "cost": 1, "requires": ["pms_fp_0"],
		 "unlocks": [{"type": "unit_ability", "id": "armor_pen"}],
		 "effects": {"stat_bonus": {"armor_penetration": 0.20}}},
		{"id": "pms_fp_1b", "name": "精确射击", "desc": "解锁暴击能力：步兵单位暴击率 +15%",
		 "branch": BRANCH_FIREPOWER, "tier": 1, "cost": 1, "requires": ["pms_fp_0"],
		 "unlocks": [{"type": "unit_ability", "id": "light_crit"}],
		 "effects": {"stat_bonus": {"crit_chance": 0.15}}},
		# tier 2：解锁一架火力专用相位仪
		{"id": "pms_fp_2", "name": "火力相位仪", "desc": "解锁相位仪：新星-超弦",
		 "branch": BRANCH_FIREPOWER, "tier": 2, "cost": 2, "requires": ["pms_fp_1a"],
		 "unlocks": [{"type": "phase_instrument", "id": "pi_nova_03"}],
		 "effects": {}},
		# tier 3：射程 + 吸血（更多兵种能力）
		{"id": "pms_fp_3", "name": "纵深打击", "desc": "所有单位射程 +10%，解锁吸血能力",
		 "branch": BRANCH_FIREPOWER, "tier": 3, "cost": 2, "requires": ["pms_fp_2"],
		 "unlocks": [{"type": "unit_ability", "id": "lifesteal_unlock"}],
		 "effects": {"stat_bonus": {"attack_range": 0.10, "lifesteal": 0.08}}},
		# tier 4：火力终极——狂暴
		{"id": "pms_fp_4", "name": "火力压制", "desc": "所有单位三维攻击 +15%，暴击伤害 +30%",
		 "branch": BRANCH_FIREPOWER, "tier": 4, "cost": 3, "requires": ["pms_fp_3"],
		 "unlocks": [],
		 "effects": {"stat_bonus": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15, "crit_damage_bonus": 0.30}}},
	],

	# ═══════════ 概念武器分支：核子轰炸 / 酸雨 / 能量罩等大技 + 进化解锁 ═══════════
		"concept_weapon": [
			# tier 0：起点（v8.5：原 energy_regen 字段战斗侧从不读取，改三维攻击+暴击）
			{"id": "pms_cw_0", "name": "概念突破", "desc": "相位师掌握概念武器基础，三维攻击 +5%，暴击率 +5%",
			 "branch": BRANCH_CONCEPT_WEAPON, "tier": 0, "cost": 1, "requires": [],
			 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.05, "atk_armor": 0.05, "atk_air": 0.05, "crit_chance": 0.05}}},
			# tier 1：战术核武（v8.5：原 phase_shield_8000 空转——由相位仪能力触发不走技能树；改为机制技能：导弹发射井堡垒发射核弹）
			{"id": "pms_cw_1", "name": "战术核武", "desc": "解锁机制：导弹发射井堡垒每45秒发射战术核弹，对敌方密集区造成 35% 最大生命的范围伤害",
			 "branch": BRANCH_CONCEPT_WEAPON, "tier": 1, "cost": 2, "requires": ["pms_cw_0"],
			 "unlocks": [{"type": "unit_mechanism", "id": "nuclear_strike"}],
			 "effects": {}},
			# tier 2：进化形态解锁（替代 enhance_level 门槛）
			{"id": "pms_cw_2", "name": "形态进化", "desc": "解锁卡牌进化能力（一战时代）",
			 "branch": BRANCH_CONCEPT_WEAPON, "tier": 2, "cost": 2, "requires": ["pms_cw_1"],
			 "unlocks": [{"type": "evolution", "era": 0}],
			 "effects": {}},
			# tier 3：能量过载（v8.5：原 nuclear_bombardment 空转——由相位仪能力触发不走技能树；改数值加成）
			{"id": "pms_cw_3", "name": "能量过载", "desc": "所有单位三维攻击 +12%，暴击伤害 +25%",
			 "branch": BRANCH_CONCEPT_WEAPON, "tier": 3, "cost": 3, "requires": ["pms_cw_2"],
			 "unlocks": [], "effects": {"stat_bonus": {"atk_light": 0.12, "atk_armor": 0.12, "atk_air": 0.12, "crit_damage_bonus": 0.25}}},
			# tier 4：护盾投射（v8.5：原 phase_guardian 特殊卡空转——special_card 分支未实装；改为机制技能 + 保留全时代进化解锁）
			{"id": "pms_cw_4", "name": "护盾投射", "desc": "解锁机制：护盾发射器堡垒每20秒为半径250内生命最低的3个友军投射护盾；解锁所有时代进化",
			 "branch": BRANCH_CONCEPT_WEAPON, "tier": 4, "cost": 3, "requires": ["pms_cw_3"],
			 "unlocks": [{"type": "unit_mechanism", "id": "shield_projector"},
			             {"type": "evolution", "era": -1}],
			 "effects": {}},
		],
}

## 获取分支技能列表
## v8.x: 合并主表节点 + V8Extension 扩展节点
static func get_skills_for_branch(branch: String) -> Array:
	var main_nodes: Array = SKILL_TREE.get(branch, []).duplicate(true)
	# v8.x: 合并扩展节点（tier 5-12）
	var V8Ext = preload("res://data/phase_master_skill_tree_v8_extension.gd")
	var ext_nodes: Array = V8Ext.get_extension_nodes(branch)
	main_nodes.append_array(ext_nodes)
	return main_nodes

## 获取指定 tier 的技能
static func get_skills_at_tier(branch: String, tier: int) -> Array:
	var out: Array = []
	for s in get_skills_for_branch(branch):
		if int(s.get("tier", 0)) == tier:
			out.append(s)
	return out

## 获取技能定义
## v8.x: 优先查主表，找不到再查 V8Extension
static func get_skill(skill_id: String) -> Dictionary:
	for branch in SKILL_TREE.keys():
		for s in SKILL_TREE[branch]:
			if s.get("id", "") == skill_id:
				return s.duplicate(true)
	# v8.x: 查扩展节点
	var V8Ext = preload("res://data/phase_master_skill_tree_v8_extension.gd")
	var ext_node: Dictionary = V8Ext.get_extension_skill(skill_id)
	if not ext_node.is_empty():
		return ext_node
	return {}

## 获取技能所属分支
## v8.x: 支持扩展节点
static func get_branch_of(skill_id: String) -> String:
	for branch in SKILL_TREE.keys():
		for s in SKILL_TREE[branch]:
			if s.get("id", "") == skill_id:
				return branch
	# v8.x: 查扩展节点
	var V8Ext = preload("res://data/phase_master_skill_tree_v8_extension.gd")
	for branch in V8Ext.EXTENSION_NODES.keys():
		for s in V8Ext.EXTENSION_NODES[branch]:
			if s.get("id", "") == skill_id:
				return branch
	return ""

## 相位场等级对应的总技能点
static func max_skill_points_at_phase_field_level(phase_field_level: int) -> int:
	var idx: int = clampi(phase_field_level, 0, POINTS_BY_PHASE_FIELD_LEVEL.size() - 1)
	return POINTS_BY_PHASE_FIELD_LEVEL[idx]

## 获取所有分支 ID
static func get_all_branches() -> Array:
	return SKILL_TREE.keys()

## 分支中文名
static func get_branch_display_name(branch: String) -> String:
	match branch:
		BRANCH_COMMAND: return "指挥"
		BRANCH_INTELLIGENCE: return "智能化"
		BRANCH_FIREPOWER: return "火力"
		BRANCH_CONCEPT_WEAPON: return "概念武器"
		_: return branch

## 分支代表色
static func get_branch_color(branch: String) -> Color:
	match branch:
		BRANCH_COMMAND: return Color(0.30, 0.70, 1.00)       # 蓝（指挥）
		BRANCH_INTELLIGENCE: return Color(0.40, 1.00, 0.50)  # 绿（智能）
		BRANCH_FIREPOWER: return Color(1.00, 0.45, 0.25)     # 橙红（火力）
		BRANCH_CONCEPT_WEAPON: return Color(0.80, 0.40, 1.00) # 紫（概念）
		_: return Color.WHITE
