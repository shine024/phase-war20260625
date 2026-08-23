extends RefCounted
class_name PhaseMasterSkillTree

## ═══════════════════════════════════════════════════════════
##  相位师技能树（v9 重设计）
##  全局独立养成系统，3 分支：指挥 / 智能化 / 火力
##
##  v9 变更：
##    - 概念武器不再独占分支（独支可绕开三系基础直接点满，过强）。
##      原内容以「奇点」节点（capstone: true）形式沉入三系深层 tier 5-15，
##      由「奇点解算」门关统一把门：要求三系 tier2 全点亮才能接触奇点科技
##    - 相位仪不再经技能树解锁（phase_instrument 类型 v9 起零节点），
##      仪器回归声望/商店/掉落等自有获取渠道；manager 派发代码仅旧档防御性保留
##
##  技能点来源：相位场 XP 升级（PhaseInstrumentManager.grant_phase_field_xp）
##  解锁内容：兵种特殊能力 / 新兵种独占机制 / 进化 / affix / 卡片技能 / 战法
##
##  节点结构：
##    id:        唯一 ID（pms_<branch>_<n>；奇点节点沿用历史 pms_cw_ 前缀，ID 不改保存档兼容）
##    name:      显示名称
##    desc:      描述
##    branch:    分支（command/intelligence/firepower）
##    tier:      等级层（基础层 0-4 在本文件，深层 5-15 在 v8_extension）
##    cost:      技能点消耗
##    requires:  前置节点 ID 数组（全部解锁才能点本节点；奇点链含跨分支前置）
##    unlocks:   解锁内容（见下方 UNLOCK_TYPES）
##    effects:   战斗效果（stat_bonus/aura/conditional 等，参照 faction_skill_tree）
##    capstone:  可选，true = 奇点节点（原概念武器内容，UI 紫色 ◈ 徽标）
##
##  UNLOCK_TYPES（unlocks 字段的 type 值，驱动不同子系统）：
##    unit_ability      → 兵种特殊能力解锁（原 enhance_level 解锁的暴击/吸血等）
##    unit_mechanism    → 兵种机制技能解锁（v8.5：定向爆破/瞄准狙击/闪电穿插/电子屏蔽/战术核武/护盾投射/定时标记）
##    evolution         → 进化形态解锁（替代 enhance_level 门槛）
##    affix             → affix 词条池赋予（替代随机 roll）
##    card_skill        → 卡片定时技能解锁（CardPeriodicSkillEngine 查询）
##    tactic            → 战法解锁（TacticDetector 查询）
##  v9 废弃：phase_instrument（技能树不再解锁相位仪，仅旧档兼容）
##  v8.5 废弃类型（仅旧存档兼容读取，不再有新节点使用）：
##    concept_weapon    → 原概念武器大技（已改为 unit_mechanism 或 stat_bonus）
##    special_card      → 原特殊卡解锁（已改为 unit_mechanism）
## ═══════════════════════════════════════════════════════════

const BRANCH_COMMAND := "command"
const BRANCH_INTELLIGENCE := "intelligence"
const BRANCH_FIREPOWER := "firepower"

## 技能点随相位场等级（Lv1-30）增长的【累计上限】表。
## v8.x: 等级上限 16→30。Lv1-2 不给点（起步），Lv3 起 2/3 点交替发放（累计）。
## 满 Lv30 = 70 点 ≈ 占节点总 cost 187 的 37%，可点满 ~1.2 个分支
## （v9：奇点节点沉入深层 + 交叉前置，满级也难凑齐全树，奇点是 endgame 追求）。
## 旧档兼容：Lv16 由原 30 点 → 新 35 点（玩家多 5 点可花，不丢失不降级）。
## 历史：v8.5 满级 15→28（Lv16）；v8.x 满级 28→70（Lv30，2-3 交替累计）
## ⚠️ 索引 = 等级（max_skill_points_at_phase_field_level 用 level 直接做下标），
##    故索引 0 是 Lv0 占位（不存在），Lv1=索引1，Lv30=索引30，共 31 个元素。
## ⚠️ 表中数值是【累计】（与原表格式一致），不是每级增量。
const POINTS_BY_PHASE_FIELD_LEVEL := [
	0,          # [0]  Lv0 占位（不存在，clampi 防越界用）
	0,          # Lv1  (起步，+0)
	0,          # Lv2  (+0)
	2,          # Lv3  (+2)
	5,          # Lv4  (+3)
	7,          # Lv5  (+2)
	10,         # Lv6  (+3)
	12,         # Lv7  (+2)
	15,         # Lv8  (+3)
	17,         # Lv9  (+2)
	20,         # Lv10 (+3)
	22,         # Lv11 (+2)
	25,         # Lv12 (+3)
	27,         # Lv13 (+2)
	30,         # Lv14 (+3)
	32,         # Lv15 (+2)
	35,         # Lv16 (+3)  ← 原满级（旧档 30→35，+5 兼容）
	37,         # Lv17 (+2)
	40,         # Lv18 (+3)
	42,         # Lv19 (+2)
	45,         # Lv20 (+3)
	47,         # Lv21 (+2)
	50,         # Lv22 (+3)
	52,         # Lv23 (+2)
	55,         # Lv24 (+3)
	57,         # Lv25 (+2)
	60,         # Lv26 (+3)
	62,         # Lv27 (+2)
	65,         # Lv28 (+3)
	67,         # Lv29 (+2)
	70,         # Lv30 (+3)  ← 新满级（累计 70）
]

## 3 分支技能节点（基础层 tier 0-4；深层 tier 5-15 见 phase_master_skill_tree_v8_extension）
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
			# tier 3：军团韧性（v9：原「指挥相位仪」——相位仪不再经技能树解锁，改三维防御数值）
			{"id": "pms_cmd_3", "name": "军团韧性", "desc": "所有友军三维防御 +8%，暴击抗性 +8%",
				"branch": BRANCH_COMMAND, "tier": 3, "cost": 2, "requires": ["pms_cmd_2"],
				"unlocks": [],
				"effects": {"stat_bonus": {"def_light": 0.08, "def_armor": 0.08, "def_air": 0.08, "crit_resist": 0.08}}},
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
			# tier 3 并列：奇点解算（v9 奇点门关——三系 tier2 全点亮才可解锁，
			# 是所有奇点节点（原概念武器内容）的统一前置；ID 沿用 pms_cw_0 保旧档兼容）
			{"id": "pms_cw_0", "name": "奇点解算", "desc": "三系基础修成后解算相位奇点：解锁各分支深层的「奇点」技能（时间/空间/现实规则级兵器）。三维攻击 +5%，暴击率 +5%",
				"branch": BRANCH_INTELLIGENCE, "tier": 3, "cost": 2, "requires": ["pms_cmd_2", "pms_int_2", "pms_fp_2"],
				"unlocks": [],
				"effects": {"stat_bonus": {"atk_light": 0.05, "atk_armor": 0.05, "atk_air": 0.05, "crit_chance": 0.05}},
				"capstone": true},
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
		# tier 2：弹道改良（v9：原「火力相位仪」——相位仪不再经技能树解锁，改射程+穿甲数值）
		{"id": "pms_fp_2", "name": "弹道改良", "desc": "所有单位射程 +8%，穿甲 +10%",
			"branch": BRANCH_FIREPOWER, "tier": 2, "cost": 2, "requires": ["pms_fp_1a"],
			"unlocks": [],
			"effects": {"stat_bonus": {"attack_range": 0.08, "armor_penetration": 0.10}}},
		# tier 3：射程 + 击杀修复（更多兵种能力）
		{"id": "pms_fp_3", "name": "纵深打击", "desc": "所有单位射程 +10%，解锁战场回收（击杀回复自身6%最大HP）",
		 "branch": BRANCH_FIREPOWER, "tier": 3, "cost": 2, "requires": ["pms_fp_2"],
		 "unlocks": [{"type": "unit_ability", "id": "lifesteal_unlock"}],
		 # v6.15: 击杀修复只走 lifesteal_unlock 解锁路径（unit_stats_table +0.06）；
		 # 原此处 stat_bonus lifesteal 0.08 与解锁检查 +0.05 双发，实际 0.13 超出描述承诺
		 "effects": {"stat_bonus": {"attack_range": 0.10}}},
		# tier 4：火力终极——狂暴
		{"id": "pms_fp_4", "name": "火力压制", "desc": "所有单位三维攻击 +15%，暴击伤害 +30%",
			"branch": BRANCH_FIREPOWER, "tier": 4, "cost": 3, "requires": ["pms_fp_3"],
			"unlocks": [],
			"effects": {"stat_bonus": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15, "crit_damage_bonus": 0.30}}},
	],

	# ═══════════ 概念武器分支：v9 已解散 ═══════════
	# 原节点未删除，按主题重新安家（ID 全保留 → 旧档零迁移）：
	#   pms_cw_0  奇点解算（门关）→ 智能化 tier 3（见上方）
	#   pms_cw_1  战术核武        → 火力 tier 11（v8_extension）
	#   pms_cw_2  形态进化        → 指挥 tier 5（v8_extension）
	#   pms_cw_3  能量过载        → 火力 tier 7（v8_extension）
	#   pms_cw_4  护盾投射        → 指挥 tier 10（v8_extension）
	#   其余 cw 节点（5-13）      → 见 v8_extension 三系深层
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

## v9 perf: ID→节点 / ID→分支 懒建索引。
## get_skill/get_branch_of 原为线性全表扫描（主表+扩展表双遍历），
## 技能树面板每行渲染都要经 can_unlock_node→get_skill 查一次（71 行/次重建），
## manager 的 is_content_unlocked/is_evolution_era_unlocked/get_unlocked_summary 同样逐节点查。
## 数据为 const 静态表，索引一次建成后永不失效。
static var _id_index: Dictionary = {}
static var _branch_index: Dictionary = {}

static func _ensure_lookup_index() -> void:
	if not _id_index.is_empty():
		return
	for branch in SKILL_TREE.keys():
		for s in SKILL_TREE[branch]:
			var sid: String = String(s.get("id", ""))
			_id_index[sid] = s
			_branch_index[sid] = branch
	var V8Ext = preload("res://data/phase_master_skill_tree_v8_extension.gd")
	for branch in V8Ext.EXTENSION_NODES.keys():
		for s in V8Ext.EXTENSION_NODES[branch]:
			var sid: String = String(s.get("id", ""))
			_id_index[sid] = s
			_branch_index[sid] = branch

## 获取技能定义
## v9 perf: O(1) 索引查询（原主表全扫 + 扩展表全扫）；返回深拷贝防调用方污染静态表
static func get_skill(skill_id: String) -> Dictionary:
	_ensure_lookup_index()
	var node: Variant = _id_index.get(skill_id)
	if node != null:
		return (node as Dictionary).duplicate(true)
	return {}

## 获取技能所属分支
## v9 perf: O(1) 索引查询（原主表全扫 + 扩展表全扫）
static func get_branch_of(skill_id: String) -> String:
	_ensure_lookup_index()
	return String(_branch_index.get(skill_id, ""))

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
		_: return branch

## 分支代表色
static func get_branch_color(branch: String) -> Color:
	match branch:
		BRANCH_COMMAND: return Color(0.30, 0.70, 1.00)       # 蓝（指挥）
		BRANCH_INTELLIGENCE: return Color(0.40, 1.00, 0.50)  # 绿（智能）
		BRANCH_FIREPOWER: return Color(1.00, 0.45, 0.25)     # 橙红（火力）
		_: return Color.WHITE

## 奇点节点统一配色（原概念武器内容，沉入三系深层的 capstone 节点）
const CAPSTONE_COLOR := Color(0.80, 0.40, 1.00)  # 紫（奇点）
