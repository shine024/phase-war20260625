extends RefCounted
class_name IntelDimensions
## v6.7: 情报维度定义（单维度化）
## 原 v6.0 的 4 维（basic/tactical/material/secret）已合并为单一情报进度。
## 所有奖励（弱点加成/掉落加成/EOM/进化分支）改为按 4 档阈值触发。
##
## 保留 ALL_DIMENSIONS / DIM_* 常量名以兼容旧调用点，运行时只有单一维度 "intel"。
## 旧 4 维权重分配表（DIMENSION_WEIGHTS/calc_dimension_weights/calc_weighted_average）已移除，
## 存档迁移改用 merge_legacy_dimensions（取4维最大值合并到单标量）。

# ── 维度ID（兼容旧常量名，统一指向单维度） ────────────────────────

const DIM_BASIC: String = "intel"      ## 兼容别名
const DIM_TACTICAL: String = "intel"   ## 兼容别名
const DIM_MATERIAL: String = "intel"   ## 兼容别名
const DIM_SECRET: String = "intel"     ## 兼容别名
const DIM_INTEL: String = "intel"      ## 当前规范名

## 所有效维度的有序列表（单元素）
const ALL_DIMENSIONS: Array[String] = [DIM_INTEL]

# ── 维度名称/图标/颜色（统一为单一主题） ──────────────────────────

const DIM_NAMES: Dictionary = {
	DIM_INTEL: "情报分析",
}

const DIM_ICONS: Dictionary = {
	DIM_INTEL: "🔵",
}

const DIM_COLORS: Dictionary = {
	DIM_INTEL: Color(0.4, 0.65, 0.95),  # 蓝色
}

const DIM_BG_COLORS: Dictionary = {
	DIM_INTEL: Color(0.15, 0.2, 0.3),
}

# ── 揭示阈值 ──────────────────────────────────────────────────────

## 4个揭示等级的阈值（不变）
const REVEAL_THRESHOLDS: Dictionary = {
	0: 0.25,   # Tier 1 揭示
	1: 0.50,   # Tier 2 揭示
	2: 0.75,   # Tier 3 揭示
	3: 1.00,   # Tier 4 揭示（满）
}

# ── 揭示等级名称（单维度4档） ─────────────────────────────────────

const REVEAL_TIER_NAMES: Dictionary = {
	DIM_INTEL: {
		0: "初步情报",
		1: "深入分析",
		2: "弱点破解",
		3: "完全掌握",
	},
}

# ── 工具函数 ───────────────────────────────────────────────────────

## 检查维度ID是否合法（单维度下恒为 "intel"）
static func is_valid_dimension(dim: String) -> bool:
	return dim == DIM_INTEL

## 获取维度名称（安全）
static func get_dim_name(dim: String) -> String:
	return DIM_NAMES.get(dim, "情报分析")

## 获取维度颜色（安全）
static func get_dim_color(dim: String) -> Color:
	return DIM_COLORS.get(dim, Color(0.4, 0.65, 0.95))

## 获取维度图标（安全）
static func get_dim_icon(dim: String) -> String:
	return DIM_ICONS.get(dim, "🔵")

## 获取当前揭示等级 (0-3)，未达最低阈值返回 -1
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

# ── 存档迁移用：旧4维→单维度合并（仅 load_state 调用） ────────────

## 将旧 4 维情报合并为单一标量（v2→v3 存档迁移专用）
## 采用最大值策略：单维度下任一维度达标即视为该 tier 已解锁，
## 取最大值最能保留玩家旧进度（比加权平均更慷慨，避免降级感）
static func merge_legacy_dimensions(legacy_dims: Dictionary) -> float:
	var max_val: float = 0.0
	for key in legacy_dims:
		var v: float = float(legacy_dims[key])
		if v > max_val:
			max_val = v
	return clampf(max_val, 0.0, 1.0)
