extends RefCounted
class_name ModEffects
## v5.0: 20种改造效果定义表 + 槽位消耗 + 查询接口
## BlueprintManager 改造系统消费此模块获取 MOD 数据与消耗公式

## ─────────────────────────────────────────────
##  20 种 MOD 完整定义
##  v5.0: 新增 attack_multiplier / condition_type 字段供战斗伤害公式使用
## ─────────────────────────────────────────────
const MOD_DATA: Dictionary = {
	"MOD_01": {"id": "MOD_01", "name": "火力改造",   "desc": "攻击力+15%",             "type": "attack",   "power_mult": 1.15,
		"attack_multiplier": 1.15, "condition_type": "",
		"effects": {"attack_mult": 0.15}},
	"MOD_02": {"id": "MOD_02", "name": "装甲改造",   "desc": "防御力+20%",             "type": "defense",  "power_mult": 1.20,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"defense_mult": 0.20}},
	"MOD_03": {"id": "MOD_03", "name": "机动改造",   "desc": "部署速度+2",             "type": "mobility", "power_mult": 1.08,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"deploy_speed_bonus": 2}},
	"MOD_04": {"id": "MOD_04", "name": "射程改造",   "desc": "射程+1(仅直射)",         "type": "attack",   "power_mult": 1.08,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"range_bonus": 1, "direct_only": true}},
	"MOD_05": {"id": "MOD_05", "name": "穿甲专精",   "desc": "对甲+30%,对轻-10%",      "type": "attack",   "power_mult": 1.30,
		"attack_multiplier": 1.30, "condition_type": "vs_armor",
		"effects": {"armor_bonus": 0.30, "light_penalty": -0.10}},
	"MOD_06": {"id": "MOD_06", "name": "高爆专精",   "desc": "对轻+30%,对甲-10%",      "type": "attack",   "power_mult": 1.30,
		"attack_multiplier": 1.30, "condition_type": "vs_light",
		"effects": {"light_bonus": 0.30, "armor_penalty": -0.10}},
	"MOD_07": {"id": "MOD_07", "name": "防空专精",   "desc": "对空+40%,对地-15%",      "type": "attack",   "power_mult": 1.40,
		"attack_multiplier": 1.40, "condition_type": "vs_air",
		"effects": {"air_bonus": 0.40, "ground_penalty": -0.15}},
	"MOD_08": {"id": "MOD_08", "name": "快速装填",   "desc": "攻击间隔-20%",           "type": "attack",   "power_mult": 1.20,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"speed_mult": 0.20}},
	"MOD_09": {"id": "MOD_09", "name": "精确瞄准",   "desc": "命中精度+20%",           "type": "attack",   "power_mult": 1.10,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"accuracy_mult": 0.20}},
	"MOD_10": {"id": "MOD_10", "name": "战场维修",   "desc": "每秒回复1%生命",         "type": "survival", "power_mult": 1.15,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"hp_regen_pct": 0.01}},
	"MOD_11": {"id": "MOD_11", "name": "能量效率",   "desc": "部署能量-20%",           "type": "tactical", "power_mult": 1.25,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"energy_reduction": 0.20}},
	"MOD_12": {"id": "MOD_12", "name": "纳米装甲",   "desc": "减伤+10%",               "type": "defense",  "power_mult": 1.15,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"damage_reduction": 0.10}},
	"MOD_13": {"id": "MOD_13", "name": "过载射击",   "desc": "暴击率+15%",             "type": "attack",   "power_mult": 1.30,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"crit_bonus": 0.15}},
	"MOD_14": {"id": "MOD_14", "name": "范围溅射",   "desc": "攻击造成20%范围伤害",    "type": "attack",   "power_mult": 1.25,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"splash_pct": 0.20}},
	"MOD_15": {"id": "MOD_15", "name": "护盾生成",   "desc": "部署时获得20%HP护盾",    "type": "defense",  "power_mult": 1.20,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"shield_pct": 0.20}},
	"MOD_16": {"id": "MOD_16", "name": "死亡自爆",   "desc": "死亡时造成100%攻击伤害",  "type": "special",  "power_mult": 1.15,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"death_explosion": 1.0}},
	"MOD_17": {"id": "MOD_17", "name": "回收利用",   "desc": "死亡返还50%部署能量",    "type": "tactical", "power_mult": 1.10,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"energy_refund_pct": 0.50}},
	"MOD_18": {"id": "MOD_18", "name": "双倍供弹",   "desc": "攻击有10%概率双倍伤害",   "type": "attack",   "power_mult": 1.25,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"double_damage_chance": 0.10}},
	"MOD_19": {"id": "MOD_19", "name": "硬化装甲",   "desc": "对穿甲伤害抗性+25%",     "type": "defense",  "power_mult": 1.15,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"armor_break_resist": 0.25}},
	"MOD_20": {"id": "MOD_20", "name": "电磁脉冲",   "desc": "攻击有20%概率瘫痪1秒",    "type": "control",  "power_mult": 1.20,
		"attack_multiplier": 1.0, "condition_type": "",
		"effects": {"stun_chance": 0.20, "stun_duration": 1.0}},
}

## 改造槽位消耗系数（0-based）
## 改造消耗 = 基础战力 × get_mod_slot_cost(slot_index)
const SLOT_COST: Dictionary = {
	0: 2.0, 1: 4.0, 2: 8.0, 3: 10.0, 4: 12.0,
	5: 14.0, 6: 16.0, 7: 18.0, 8: 20.0,
}

## 最大改造次数
const MAX_MOD_SLOTS: int = 9

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取 MOD 完整信息（返回副本）
static func get_mod_info(mod_id: String) -> Dictionary:
	if MOD_DATA.has(mod_id):
		return MOD_DATA[mod_id].duplicate(true)
	return {}

## 获取 MOD 类型 (attack/defense/mobility/survival/tactical/special/control)
static func get_mod_type(mod_id: String) -> String:
	var info = get_mod_info(mod_id)
	return String(info.get("type", ""))

## 获取 MOD 战力倍率
static func get_mod_power_multiplier(mod_id: String) -> float:
	var info = get_mod_info(mod_id)
	return float(info.get("power_mult", 1.0))

## 获取全部 MOD ID 列表（按编号排序）
static func get_all_mod_ids() -> Array:
	var ids: Array = []
	for i in range(1, 21):
		var key: String = "MOD_%02d" % i
		if MOD_DATA.has(key):
			ids.append(key)
	return ids

## 获取第 slot_index 个槽位的消耗系数（0-based）
static func get_mod_slot_cost(slot_index: int) -> float:
	return float(SLOT_COST.get(slot_index, 20.0))

## ── 兼容 BlueprintManager（子任务3引用的旧接口）──
## 获取全部 MOD 定义（旧名 get_all_mod_definitions，保留兼容）
static func get_all_mod_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_id in get_all_mod_ids():
		result.append(get_mod_info(mod_id))
	return result

## 获取冲突组（同类型视为冲突）
static func get_conflict_group(mod_id: String) -> String:
	return get_mod_type(mod_id)

## 旧名兼容
static func get_mod_definition(mod_id: String) -> Dictionary:
	return get_mod_info(mod_id)
