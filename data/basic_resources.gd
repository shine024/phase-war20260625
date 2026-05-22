extends RefCounted
class_name BasicResources
## 基础资源：纳米材料、合金、晶体、能量块、研究点
##
## - 以背包格子形式展示，每格最多存放 STACK_SIZE 数量
## - 总量由 BasicResourceManager 维护，这里只提供配置与关卡掉落计算

const STACK_SIZE: int = 10000

# 统一的资源ID命名
const ID_NANO_MATERIALS := "nano_materials"
const ID_ALLOY := "alloy"
const ID_CRYSTAL := "crystal"
const ID_ENERGY_BLOCK := "energy_block"
const ID_RESEARCH_POINTS := "research_points"
const ID_PERMIT_GENERAL := "permit_general"
const ID_PERMIT_TYPE_ASSAULT := "permit_type_assault"
const ID_PERMIT_TYPE_HEAVY := "permit_type_heavy"
const ID_PERMIT_TYPE_SUPPORT := "permit_type_support"
const ID_PERMIT_TYPE_LAW := "permit_type_law"

# 兼容性常量（保留用于向后兼容）
const ID_BASIC_NANO := "basic_nano"  # 已弃用，请使用 ID_NANO_MATERIALS

const DEFINITIONS: Dictionary = {
	ID_NANO_MATERIALS: {
		"id": ID_NANO_MATERIALS,
		"name": "纳米材料",
		"desc": "用于制造与研究的基础纳米单元。",
		"icon": "res://assets/resources/basic_nano.png",
	},
	ID_ALLOY: {
		"id": ID_ALLOY,
		"name": "合金",
		"desc": "高强度金属材料，用于装甲和武器制造。",
		"icon": "res://assets/resources/alloy.png",
	},
	ID_CRYSTAL: {
		"id": ID_CRYSTAL,
		"name": "晶体",
		"desc": "能量晶体，用于高级装备和能量系统。",
		"icon": "res://assets/resources/crystal.png",
	},
	ID_ENERGY_BLOCK: {
		"id": ID_ENERGY_BLOCK,
		"name": "能量块",
		"desc": "可在后勤节点中转换为战场能源或其它增益。",
		"icon": "res://assets/resources/energy_block.png",
	},
	ID_RESEARCH_POINTS: {
		"id": ID_RESEARCH_POINTS,
		"name": "研究点",
		"desc": "用于卡牌升星与改装的专用资源。",
		"icon": "res://assets/resources/crystal.png",
	},
	ID_PERMIT_GENERAL: {
		"id": ID_PERMIT_GENERAL,
		"name": "改造许可函·通用",
		"desc": "用于卡牌改造的通用许可。",
		"icon": "res://assets/resources/crystal.png",
	},
	ID_PERMIT_TYPE_ASSAULT: {
		"id": ID_PERMIT_TYPE_ASSAULT,
		"name": "改造许可函·突击型",
		"desc": "用于突击型战斗卡的改造前置许可。",
		"icon": "res://assets/resources/crystal.png",
	},
	ID_PERMIT_TYPE_HEAVY: {
		"id": ID_PERMIT_TYPE_HEAVY,
		"name": "改造许可函·重装型",
		"desc": "用于重装型战斗卡的改造前置许可。",
		"icon": "res://assets/resources/crystal.png",
	},
	ID_PERMIT_TYPE_SUPPORT: {
		"id": ID_PERMIT_TYPE_SUPPORT,
		"name": "改造许可函·支援型",
		"desc": "用于支援型战斗卡的改造前置许可。",
		"icon": "res://assets/resources/crystal.png",
	},
	ID_PERMIT_TYPE_LAW: {
		"id": ID_PERMIT_TYPE_LAW,
		"name": "改造许可函·法则型",
		"desc": "用于法则卡改造的前置许可。",
		"icon": "res://assets/resources/crystal.png",
	},
	# 兼容性定义（映射到新ID）
	ID_BASIC_NANO: {
		"id": ID_NANO_MATERIALS,  # 映射到新的纳米材料ID
		"name": "纳米材料",
		"desc": "用于制造与研究的基础纳米单元。（已弃用ID）",
		"icon": "res://assets/resources/basic_nano.png",
	},
}

const LevelEras = preload("res://data/level_eras.gd")

static func get_def(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {})

static func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for key in DEFINITIONS.keys():
		result.append(String(key))
	return result

## 根据关卡计算本关结算时的基础资源掉落
## 返回：{ nano_materials: int, alloy: int, crystal: int, energy_block: int, research_points: int }
static func get_drops_for_level(level: int) -> Dictionary:
	var lv: int = max(1, level)
	var mult: float = LevelEras.get_drop_rate_multiplier(lv)
	# 纳米材料：随关卡线性上升
	var base_nano: float = (50.0 + 10.0 * lv) * mult
	# 合金：中等数量
	var base_alloy: float = (15.0 + 3.0 * lv) * mult
	# 晶体：较少数量
	var base_crystal: float = (5.0 + 2.0 * lv) * mult
	# 能量块：略低一些
	var base_energy: float = (20.0 + 5.0 * lv) * mult
	# 研究点：战斗成长主资源
	var base_research: float = (30.0 + 6.0 * lv) * mult
	return {
		ID_NANO_MATERIALS: int(round(base_nano)),
		ID_ALLOY: int(round(base_alloy)),
		ID_CRYSTAL: int(round(base_crystal)),
		ID_ENERGY_BLOCK: int(round(base_energy)),
		ID_RESEARCH_POINTS: int(round(base_research)),
	}

static func get_specific_permit_id(card_id: String) -> String:
	return "permit_card_%s" % String(card_id).strip_edges()
