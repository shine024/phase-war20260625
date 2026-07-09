extends RefCounted
class_name CompanyDefinitions
## 公司/势力定义：用于任务委托与公司贡献度
##
## 字段：
## - id: 唯一ID（存档与脚本用）
## - name: 显示名称
## - desc: 简短描述（后续可用于商店/任务说明）
## - color: Palette B 高饱和阵营色（战斗/UI 统一用）
##
## 阵营颜色统一来源（Palette B，高饱和醒目）：
## 钢蓝/火焰橙/青/金/绿/紫/品红
## 所有引用阵营色的面板（occupation/world_map/leaderboard/battle）均从此表读取，
## 不再在各自文件里维护本地 FACTION_COLORS 副本。

const COMPANIES: Array[Dictionary] = [
	{
		"id": "iron_wall_corp",
		"name": "钢壁防务公司",
		"desc": "老牌防务承包商，偏好稳扎稳打的装甲与防线。",
		"color": Color(0.7, 0.85, 1.0, 1.0),  # 钢蓝
	},
	{
		"id": "nova_arms",
		"name": "新星兵工制造",
		"desc": "主攻火力与射速的武器研发公司。",
		"color": Color(1.0, 0.4, 0.2, 1.0),   # 火焰橙
	},
	{
		"id": "aether_dynamics",
		"name": "以太动力重工",
		"desc": "提供机动载具与相位推进技术。",
		"color": Color(0.2, 0.8, 1.0, 1.0),   # 青色
	},
	{
		"id": "quantum_logistics",
		"name": "量子后勤集团",
		"desc": "掌管补给线与资源调配的幕后巨头。",
		"color": Color(1.0, 0.843, 0.0, 1.0), # 金色
	},
	{
		"id": "helix_recon",
		"name": "螺旋侦察系统",
		"desc": "专精侦察与情报收集的科技公司。",
		"color": Color(0.5, 1.0, 0.2, 1.0),   # 绿色
	},
	{
		"id": "void_research",
		"name": "虚空相位研究所",
		"desc": "研究相位场与战争魔法的半官方机构。",
		"color": Color(0.7, 0.3, 1.0, 1.0),   # 紫色
	},
	{
		"id": "frontier_union",
		"name": "边境联合公司",
		"desc": "活跃在前线与灰色地带的多元承包商。",
		"color": Color(1.0, 0.2, 0.8, 1.0),   # 品红
	},
]

## 中性灰兜底（未知/空 faction_id 用，与 v6.9 无主之地语义一致）
const NEUTRAL_COLOR := Color(0.6, 0.6, 0.7, 1.0)

## 统一阵营色查找表（id → Color），懒初始化
static var _color_map_cache: Dictionary = {}

## 获取阵营色（统一入口，所有面板调用此函数）
static func get_faction_color(faction_id: String) -> Color:
	if _color_map_cache.is_empty():
		for c in COMPANIES:
			_color_map_cache[String(c.get("id", ""))] = c.get("color", NEUTRAL_COLOR)
	if faction_id.is_empty():
		return NEUTRAL_COLOR
	return _color_map_cache.get(faction_id, NEUTRAL_COLOR)

static func get_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in COMPANIES:
		out.append(c.duplicate(true))
	return out

static func get_by_id(company_id: String) -> Dictionary:
	for c in COMPANIES:
		if String(c.get("id", "")) == company_id:
			return c.duplicate(true)
	return {}
