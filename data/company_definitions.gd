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

## v36 实机验收（用户设定落档）：势力 = 未来的公司/军队/学校/科技机构——它们的成员
## 也参与了深航计划（千名车队之中），玩家经「时空交换机」与后方各组织联络；
## 完成组织任务即赢得其支持（声望/商店/技能既有系统承载，文案层只立口径）。
const COMPANIES: Array[Dictionary] = [
	{
		"id": "iron_wall_corp",
		"name": "钢壁防务公司",
		"desc": "军方背景的防务巨头，装甲与防线是穿越行动的钢铁后盾。经时空交换机联络，完成任务即可赢得他们的支持。",
		"color": Color(0.7, 0.85, 1.0, 1.0),  # 钢蓝
	},
	{
		"id": "nova_arms",
		"name": "新星兵工制造",
		"desc": "深航计划的军火供应商，炮火与射速是他们的名片。成员随队穿越——完成任务，军械支援从不缺席。",
		"color": Color(1.0, 0.4, 0.2, 1.0),   # 火焰橙
	},
	{
		"id": "aether_dynamics",
		"name": "以太动力重工",
		"desc": "基地车引擎与相位推进技术的缔造者，派驻工程师随行。帮他们完成任务，载具科技倾囊相授。",
		"color": Color(0.2, 0.8, 1.0, 1.0),   # 青色
	},
	{
		"id": "quantum_logistics",
		"name": "量子后勤集团",
		"desc": "掌管时空交换机补给线的幕后巨头，各时代的物资都经他们中转。支持他们的任务，补给准时到达。",
		"color": Color(1.0, 0.843, 0.0, 1.0), # 金色
	},
	{
		"id": "helix_recon",
		"name": "螺旋侦察系统",
		"desc": "深空扫描仪的制造商，专精追踪散落各地的同伴踪迹。完成任务，他们的情报网络向你敞开。",
		"color": Color(0.5, 1.0, 0.2, 1.0),   # 绿色
	},
	{
		"id": "void_research",
		"name": "虚空相位研究所",
		"desc": "培养相位师的半官方学府，研究相位场与暗能的边界。完成他们布置的课题，深层的潜能随之解锁。",
		"color": Color(0.7, 0.3, 1.0, 1.0),   # 紫色
	},
	{
		"id": "frontier_union",
		"name": "边境联合公司",
		"desc": "活跃在前线与灰色地带的多元承包商，成员遍布整支车队。生意归生意——完成任务，一切好谈。",
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


## v6.22 势力改版：各组织的改造类型偏好（原 faction_conquest_buffs.FACTION_MOD_BIAS 搬家至此）。
## 消费方：game_manager 相位师蓝图掉落链（enemy_type 按 _pm_player_faction 偏好派生）、
## intel_discovery_manager 掉落 bias 形参（现传空数组，bias 语义仅此处保留数据源）。
const FACTION_MOD_BIAS: Dictionary = {
	"iron_wall_corp": ["armor", "fort"],       # 钢壁→装甲/堡垒改造
	"nova_arms": ["infantry", "anti_air"],     # 新星→步兵/防空改造（火力支援）
	"aether_dynamics": ["air", "recon"],       # 以太→空军/侦察改造（机动）
	"quantum_logistics": ["artillery", "engineer"],  # 量子→炮兵/工兵改造（后勤）
	"helix_recon": ["recon", "air"],           # 螺旋→侦察/空军改造（情报）
	"void_research": ["universal", "artillery"],  # 虚空→通用/炮兵改造（神秘）
	"frontier_union": [],                      # 边境→无偏好
}
