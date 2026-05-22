extends RefCounted
class_name CompanyDefinitions
## 公司/势力定义：用于任务委托与公司贡献度
##
## 字段：
## - id: 唯一ID（存档与脚本用）
## - name: 显示名称
## - desc: 简短描述（后续可用于商店/任务说明）

const COMPANIES: Array[Dictionary] = [
	{
		"id": "iron_wall_corp",
		"name": "钢壁防务公司",
		"desc": "老牌防务承包商，偏好稳扎稳打的装甲与防线。",
	},
	{
		"id": "nova_arms",
		"name": "新星兵工制造",
		"desc": "主攻火力与射速的武器研发公司。",
	},
	{
		"id": "aether_dynamics",
		"name": "以太动力重工",
		"desc": "提供机动载具与相位推进技术。",
	},
	{
		"id": "quantum_logistics",
		"name": "量子后勤集团",
		"desc": "掌管补给线与资源调配的幕后巨头。",
	},
	{
		"id": "helix_recon",
		"name": "螺旋侦察系统",
		"desc": "专精侦察与情报收集的科技公司。",
	},
	{
		"id": "void_research",
		"name": "虚空相位研究所",
		"desc": "研究相位场与战争魔法的半官方机构。",
	},
	{
		"id": "frontier_union",
		"name": "边境联合公司",
		"desc": "活跃在前线与灰色地带的多元承包商。",
	},
]

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
