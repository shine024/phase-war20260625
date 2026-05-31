extends RefCounted
class_name IntelDimensions
## v6.0: 情报维度定义
## 将情报从单一进度条扩展为4个独立维度，每个维度有独立的揭示事件和奖励
##
## 维度说明：
##   basic    — 基础侦察：HP/攻击/防御等数值属性
##   tactical — 战术分析：行为模式/技能/弱点
##   material — 素材研究：可掉落的专属材料信息
##   secret   — 机密档案：隐藏进化线索/传奇配方

# ── 维度ID ─────────────────────────────────────────────────────────

const DIM_BASIC: String = "basic"
const DIM_TACTICAL: String = "tactical"
const DIM_MATERIAL: String = "material"
const DIM_SECRET: String = "secret"

## 所有效维度的有序列表
const ALL_DIMENSIONS: Array[String] = [DIM_BASIC, DIM_TACTICAL, DIM_MATERIAL, DIM_SECRET]

# ── 维度名称 ───────────────────────────────────────────────────────

const DIM_NAMES: Dictionary = {
	DIM_BASIC: "基础侦察",
	DIM_TACTICAL: "战术分析",
	DIM_MATERIAL: "素材研究",
	DIM_SECRET: "机密档案",
}

# ── 维度图标（emoji，用于战斗结算UI） ────────────────────────────

const DIM_ICONS: Dictionary = {
	DIM_BASIC: "🔵",
	DIM_TACTICAL: "🟠",
	DIM_MATERIAL: "🟢",
	DIM_SECRET: "🟣",
}

# ── 维度颜色主题 ─────────────────────────────────────────────────

const DIM_COLORS: Dictionary = {
	DIM_BASIC: Color(0.4, 0.65, 0.95),       # 蓝色
	DIM_TACTICAL: Color(0.92, 0.58, 0.18),  # 橙色
	DIM_MATERIAL: Color(0.25, 0.82, 0.45),  # 绿色
	DIM_SECRET: Color(0.75, 0.3, 0.92),     # 紫色
}

## 进度条背景色（暗色版本）
const DIM_BG_COLORS: Dictionary = {
	DIM_BASIC: Color(0.15, 0.2, 0.3),
	DIM_TACTICAL: Color(0.25, 0.18, 0.08),
	DIM_MATERIAL: Color(0.1, 0.22, 0.15),
	DIM_SECRET: Color(0.2, 0.1, 0.25),
}

# ── 揭示阈值 ──────────────────────────────────────────────────────

## 每个维度4个揭示等级的阈值
const REVEAL_THRESHOLDS: Dictionary = {
	0: 0.25,   # Tier 1 揭示
	1: 0.50,   # Tier 2 揭示
	2: 0.75,   # Tier 3 揭示
	3: 1.00,   # Tier 4 揭示（满）
}

# ── 揭示等级名称 ─────────────────────────────────────────────────

const REVEAL_TIER_NAMES: Dictionary = {
	DIM_BASIC: {
		0: "名称识别",
		1: "完整参数",
		2: "隐藏属性",
		3: "图鉴百科",
	},
	DIM_TACTICAL: {
		0: "行为概要",
		1: "技能列表",
		2: "弱点分析",
		3: "AI逻辑全解",
	},
	DIM_MATERIAL: {
		0: "素材类型",
		1: "专属掉落",
		2: "敌源改造",
		3: "进化材料",
	},
	DIM_SECRET: {
		0: "隐秘暗示",
		1: "进化线索",
		2: "秘密配方",
		3: "完整机密",
	},
}

# ── 情报维度权重（计算总情报时使用） ──────────────────────────────

const DIMENSION_WEIGHTS: Dictionary = {
	DIM_BASIC: 0.30,
	DIM_TACTICAL: 0.30,
	DIM_MATERIAL: 0.25,
	DIM_SECRET: 0.15,
}

# ── 敌人类型到默认标签的映射（用于情报维度分配） ───────────────

const ENEMY_TYPE_DIMENSION_HINTS: Dictionary = {
	"infantry":   {"primary": DIM_BASIC,    "secondary": DIM_TACTICAL},
	"flame":      {"primary": DIM_MATERIAL, "secondary": DIM_SECRET},
	"heavy_armor": {"primary": DIM_MATERIAL, "secondary": DIM_TACTICAL},
	"artillery":  {"primary": DIM_TACTICAL, "secondary": DIM_BASIC},
	"stealth":    {"primary": DIM_SECRET,   "secondary": DIM_TACTICAL},
	"scout":      {"primary": DIM_TACTICAL, "secondary": DIM_BASIC},
	"air":        {"primary": DIM_TACTICAL, "secondary": DIM_MATERIAL},
	"boss_nano":  {"primary": DIM_SECRET,   "secondary": DIM_MATERIAL},
	"boss_phase": {"primary": DIM_SECRET,   "secondary": DIM_TACTICAL},
	"medic":      {"primary": DIM_BASIC,    "secondary": DIM_MATERIAL},
	"command":    {"primary": DIM_TACTICAL, "secondary": DIM_SECRET},
}

# ── 工具函数 ───────────────────────────────────────────────────────

## 检查维度ID是否合法
static func is_valid_dimension(dim: String) -> bool:
	return dim in ALL_DIMENSIONS

## 获取维度名称（安全）
static func get_dim_name(dim: String) -> String:
	return DIM_NAMES.get(dim, "未知")

## 获取维度颜色（安全）
static func get_dim_color(dim: String) -> Color:
	return DIM_COLORS.get(dim, Color(0.6, 0.6, 0.6))

## 获取维度图标（安全）
static func get_dim_icon(dim: String) -> String:
	return DIM_ICONS.get(dim, "⚪")

## 获取当前揭示等级 (0-3)
static func get_reveal_tier(progress: float) -> int:
	if progress >= 1.0:  return 3
	if progress >= 0.75: return 2
	if progress >= 0.50: return 1
	if progress >= 0.25: return 0
	return -1  # 未达最低阈值

## 获取揭示等级名称
static func get_reveal_tier_name(dim: String, tier: int) -> String:
	var names: Dictionary = REVEAL_TIER_NAMES.get(dim, {})
	return names.get(tier, "???")

## 根据情报来源和敌人类型，计算4维情报分配权重
## 返回 {"basic": float, "tactical": float, "material": float, "secret": float}
## 值为 0.0-1.0 的权重，调用者乘以总情报量得到各维度增长
static func calc_dimension_weights(
	source: String,        # "first_encounter" | "defeat_normal" | "defeat_elite" | "defeat_boss" | "recon" | "decompose"
	enemy_type: String,    # 敌人类型标签
	victory_stars: int = 0 # 胜利星级(0-3)，用于额外加成
) -> Dictionary:
	var weights: Dictionary = {
		DIM_BASIC: 0.0,
		DIM_TACTICAL: 0.0,
		DIM_MATERIAL: 0.0,
		DIM_SECRET: 0.0,
	}
	var hints: Dictionary = ENEMY_TYPE_DIMENSION_HINTS.get(enemy_type, {
		"primary": DIM_BASIC, "secondary": DIM_TACTICAL
	})
	var primary: String = hints.get("primary", DIM_BASIC)
	var secondary: String = hints.get("secondary", DIM_TACTICAL)

	match source:
		"first_encounter":
			weights[DIM_BASIC] = 1.0
		"defeat_normal":
			weights[primary] = 0.40
			weights[secondary] = 0.30
			weights[DIM_MATERIAL] = 0.20
			weights[DIM_SECRET] = 0.10
		"defeat_elite":
			weights[primary] = 0.30
			weights[secondary] = 0.30
			weights[DIM_MATERIAL] = 0.25
			weights[DIM_SECRET] = 0.15
		"defeat_boss":
			weights[primary] = 0.25
			weights[secondary] = 0.25
			weights[DIM_MATERIAL] = 0.25
			weights[DIM_SECRET] = 0.25
		"recon":
			weights[DIM_TACTICAL] = 0.55
			weights[DIM_BASIC] = 0.20
			weights[DIM_SECRET] = 0.15
			weights[DIM_MATERIAL] = 0.10
		"decompose":
			weights[DIM_MATERIAL] = 0.45
			weights[DIM_BASIC] = 0.20
			weights[DIM_TACTICAL] = 0.20
			weights[DIM_SECRET] = 0.15
		_:
			weights[DIM_BASIC] = 0.50
			weights[DIM_TACTICAL] = 0.30
			weights[DIM_MATERIAL] = 0.15
			weights[DIM_SECRET] = 0.05

	# 3星胜利加成：所有维度额外+10%
	if victory_stars >= 3:
		for dim in ALL_DIMENSIONS:
			weights[dim] += 0.10

	return weights

## 计算4维情报的加权平均值（用于向后兼容的 intel_progress）
static func calc_weighted_average(dimensions: Dictionary) -> float:
	var total: float = 0.0
	var weight_sum: float = 0.0
	for dim in ALL_DIMENSIONS:
		var val: float = float(dimensions.get(dim, 0.0))
		var w: float = float(DIMENSION_WEIGHTS.get(dim, 0.25))
		total += val * w
		weight_sum += w
	return clampf(total / maxf(weight_sum, 0.01), 0.0, 1.0)
