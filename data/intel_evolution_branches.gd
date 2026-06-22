extends RefCounted
class_name IntelEvolutionBranches
## v6.0: 情报进化分支定义表
## 隐藏进化路线：只有当玩家拥有特定敌人的秘密情报达到阈值后才会揭示
## 这些分支不在 UnitLineageConfig.LINEAGES 的常规路线中

# ── 情报进化分支定义 ─────────────────────────────────────────────
# intel_requirements: 多个敌人的情报条件（AND关系）
#   key = enemy_type, value = {"threshold": float}
#   v6.7: 单维度化，已移除 dimension 字段，直接用总情报进度对比 threshold
# unique_bonus: 分支的特殊奖励
# cost_modifier: 消耗倍率（1.0=正常）
# is_hidden: 未发现时是否可见

const INTEL_BRANCHES: Dictionary = {

	# ═══ 轻装线隐藏分支 ═══
	"IB_INFANTRY_SPECIAL": {
		"branch_id": "IB_INFANTRY_SPECIAL",
		"name": "特种作战路线",
		"description": "结合步兵战术与隐匿技术的混合进化——从步兵到幽灵特种兵",
		"source_card_ids": ["ww1_mp18", "cold_ak47", "mod_marine"],
		"target_card_id": "fut_spectre",
		"intel_requirements": {
			"infantry": {"threshold": 0.75},
			"stealth": {"threshold": 0.50},
		},
		"unique_bonus": {
			"inherit_ratio": 0.45,
			"extra_mod_slot": true,
			"special_ability": "tactical_cloak",
		},
		"cost_modifier": 1.3,
		"is_hidden": true,
	},
	"IB_ARMOR_BREAKER": {
		"branch_id": "IB_ARMOR_BREAKER",
		"name": "破甲猎手路线",
		"description": "研究重装甲弱点后开发的反坦克专家进化——从反坦克兵到终极破甲手",
		"source_card_ids": ["ww2_panzerschrek", "cold_rpg", "mod_javelin"],
		"target_card_id": "fut_cyborg",
		"intel_requirements": {
			"heavy_armor": {"threshold": 0.80},
			"heavy_armor_mat": {"threshold": 0.75},
		},
		"unique_bonus": {
			"inherit_ratio": 0.50,
			"special_ability": "armor_pierce_ult",
		},
		"cost_modifier": 1.2,
		"is_hidden": true,
	},

	# ═══ 装甲线隐藏分支 ═══
	"IB_ADAPTIVE_ARMOR": {
		"branch_id": "IB_ADAPTIVE_ARMOR",
		"name": "自适应装甲路线",
		"description": "融合纳米技术与热能防护的主战坦克进化——从坦克到纳米机甲",
		"source_card_ids": ["ww2_pz3", "cold_t55", "mod_m1a1"],
		"target_card_id": "fut_heavy_mech",
		"intel_requirements": {
			"boss_nano": {"threshold": 0.80},
			"flame": {"threshold": 0.60},
		},
		"unique_bonus": {
			"inherit_ratio": 0.40,
			"extra_mod_slot": true,
			"special_ability": "adaptive_shield",
		},
		"cost_modifier": 1.4,
		"is_hidden": true,
	},

	# ═══ 跨线隐藏分支（极稀有） ═══
	"IB_CROSS_ARTILLERY_AIR": {
		"branch_id": "IB_CROSS_ARTILLERY_AIR",
		"name": "空中炮艇路线",
		"description": "将火炮装载到飞行平台的跨类型疯狂进化——支援线到空中线",
		"source_card_ids": ["mod_m270", "fut_howitzer"],
		"target_card_id": "fut_space_fighter",
		"intel_requirements": {
			"artillery": {"threshold": 1.00},
			"air": {"threshold": 0.75},
			"stealth": {"threshold": 0.80},
		},
		"unique_bonus": {
			"inherit_ratio": 0.55,
			"extra_mod_slot": true,
			"special_ability": "aerial_bombardment",
			"cross_class": true,
		},
		"cost_modifier": 1.8,
		"is_hidden": true,
	},
}

# ── 工具函数 ───────────────────────────────────────────────────────

## 获取分支定义
static func get_branch(branch_id: String) -> Dictionary:
	return INTEL_BRANCHES.get(branch_id, {})

## 检查分支是否存在
static func has_branch(branch_id: String) -> bool:
	return INTEL_BRANCHES.has(branch_id)

## 获取所有分支ID
static func get_all_branch_ids() -> Array:
	return INTEL_BRANCHES.keys()

## 检查分支是否是隐藏的
static func is_hidden_branch(branch_id: String) -> bool:
	var b: Dictionary = INTEL_BRANCHES.get(branch_id, {})
	return b.get("is_hidden", true)

## 获取分支的情报条件列表
static func get_intel_requirements(branch_id: String) -> Dictionary:
	var b: Dictionary = INTEL_BRANCHES.get(branch_id, {})
	return b.get("intel_requirements", {})

## 获取适合某张卡的分支列表
static func get_branches_for_card(card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bid in INTEL_BRANCHES:
		var b: Dictionary = INTEL_BRANCHES[bid]
		var sources: Array = b.get("source_card_ids", [])
		if card_id in sources:
			result.append(b)
	return result
