class_name ModuleDefinitions
extends RefCounted
## v6.0 词条定义表（替代旧 affix_definitions.gd）
##
## 强化 = 逐级选择词条，每次升级选择一个新词条或升级已有词条
## 16 个词条分 3 层池：
##   - 基础池（Lv2 起可用，7 个）
##   - 进阶池（Lv6 起可用，5 个）
##   - 特殊池（Lv10 起可用，4 个）
##
## 词条等级 Lv1-3：
##   Lv1 = 1.0× 基础值
##   Lv2 = 1.3× 基础值（+30%）
##   Lv3 = 1.7× 基础值（+70%）

# ─────────────────────────────────────────────
#  池层级常量
# ─────────────────────────────────────────────

const POOL_BASIC: int = 0    # 基础池，Lv2 起解锁
const POOL_ADVANCED: int = 1 # 进阶池，Lv6 起解锁
const POOL_SPECIAL: int = 2  # 特殊池，Lv10 起解锁

# ─────────────────────────────────────────────
#  词条等级系数
# ─────────────────────────────────────────────

const LEVEL_FACTORS: Dictionary = {
	1: 1.0,
	2: 1.3,
	3: 1.7,
}

# ─────────────────────────────────────────────
#  16 个词条定义
# ─────────────────────────────────────────────

## { module_id: { name, description, effect_key, effect_type, base_value,
##   pool_tier, category, cap_key, cap_value } }
##
## effect_type:
##   "percent_mult"  — 百分比乘算（如 HP+12%）
##   "percent_flat"  — 百分比点数（如 减伤+8%）
##   "flat_add"      — 固定值加算（如 防御+2）
##   "speed_add"     — 部署速度加算
##   "range_mult"    — 射程乘算
##   "interval_mult" — 攻击间隔乘算（负值=加速）

const MODULE_TABLE: Dictionary = {
	# ── 基础池（Lv2起可用，7个）──
	"module_hp_up": {
		"name": "铁甲强化",
		"description": "HP提升",
		"effect_key": "max_hp",
		"effect_type": "percent_mult",
		"base_value": 0.12,
		"pool_tier": POOL_BASIC,
		"category": "survival",
		"cap_key": "hp_total_mult",
		"cap_value": 3.0,
	},
	"module_dmg_up": {
		"name": "穿透弹芯",
		"description": "攻击提升",
		"effect_key": "attack_damage",
		"effect_type": "percent_mult",
		"base_value": 0.15,
		"pool_tier": POOL_BASIC,
		"category": "damage",
		"cap_key": "dmg_total_mult",
		"cap_value": 3.0,
	},
	"module_def_up": {
		"name": "纳米装甲",
		"description": "伤害减免",
		"effect_key": "damage_reduction",
		"effect_type": "percent_flat",
		"base_value": 0.08,
		"pool_tier": POOL_BASIC,
		"category": "survival",
		"cap_key": "damage_reduction",
		"cap_value": 0.60,
	},
	"module_def_flat": {
		"name": "复合装甲",
		"description": "防御提升",
		"effect_key": "defense",
		"effect_type": "flat_add",
		"base_value": 2.0,
		"pool_tier": POOL_BASIC,
		"category": "survival",
		"cap_key": null,
		"cap_value": 0.0,
	},
	"module_speed_up": {
		"name": "疾行引擎",
		"description": "部署速度+1",
		"effect_key": "deploy_speed",
		"effect_type": "speed_add",
		"base_value": 1.0,
		"pool_tier": POOL_BASIC,
		"category": "mobility",
		"cap_key": null,
		"cap_value": 0.0,
	},
	"module_range_up": {
		"name": "延伸枪管",
		"description": "射程提升",
		"effect_key": "attack_range",
		"effect_type": "range_mult",
		"base_value": 0.10,
		"pool_tier": POOL_BASIC,
		"category": "damage",
		"cap_key": null,
		"cap_value": 0.0,
	},
	"module_atkspd_up": {
		"name": "速射改装",
		"description": "攻击加速",
		"effect_key": "attack_interval",
		"effect_type": "interval_mult",
		"base_value": -0.10,
		"pool_tier": POOL_BASIC,
		"category": "damage",
		"cap_key": null,
		"cap_value": 0.0,
	},

	# ── 进阶池（Lv6起可用，5个）──
	"module_crit": {
		"name": "精准打击",
		"description": "暴击率提升",
		"effect_key": "crit_chance",
		"effect_type": "percent_flat",
		"base_value": 0.08,
		"pool_tier": POOL_ADVANCED,
		"category": "damage",
		"cap_key": "crit_chance",
		"cap_value": 0.60,
	},
	"module_lifesteal": {
		"name": "汲能吸血",
		"description": "造成伤害回复HP",
		"effect_key": "lifesteal",
		"effect_type": "percent_flat",
		"base_value": 0.05,
		"pool_tier": POOL_ADVANCED,
		"category": "survival",
		"cap_key": "lifesteal",
		"cap_value": 0.50,
	},
	"module_splash": {
		"name": "爆裂弹头",
		"description": "溅射伤害",
		"effect_key": "splash_damage",
		"effect_type": "percent_flat",
		"base_value": 0.15,
		"pool_tier": POOL_ADVANCED,
		"category": "damage",
		"cap_key": "splash_damage",
		"cap_value": 0.60,
	},
	"module_penetration": {
		"name": "穿甲射击",
		"description": "穿甲提升",
		"effect_key": "armor_penetration",
		"effect_type": "percent_flat",
		"base_value": 0.10,
		"pool_tier": POOL_ADVANCED,
		"category": "damage",
		"cap_key": "armor_penetration",
		"cap_value": 0.60,
	},
	"module_regen": {
		"name": "纳米自愈",
		"description": "每秒回复HP",
		"effect_key": "hp_regen",
		"effect_type": "percent_flat",
		"base_value": 0.003,
		"pool_tier": POOL_ADVANCED,
		"category": "survival",
		"cap_key": null,
		"cap_value": 0.0,
	},

	# ── 特殊池（Lv10起可用，4个）──
	"module_chain": {
		"name": "链式放电",
		"description": "闪电链攻击",
		"effect_key": "chain_chance",
		"effect_type": "percent_flat",
		"base_value": 0.08,
		"pool_tier": POOL_SPECIAL,
		"category": "damage",
		"cap_key": "chain_chance",
		"cap_value": 0.50,
	},
	"module_shield_kill": {
		"name": "歼灭护盾",
		"description": "击杀获得护盾",
		"effect_key": "shield_on_kill",
		"effect_type": "percent_flat",
		"base_value": 0.03,
		"pool_tier": POOL_SPECIAL,
		"category": "survival",
		"cap_key": null,
		"cap_value": 0.0,
	},
	"module_dodge": {
		"name": "相位闪避",
		"description": "闪避率提升",
		"effect_key": "dodge_chance",
		"effect_type": "percent_flat",
		"base_value": 0.05,
		"pool_tier": POOL_SPECIAL,
		"category": "survival",
		"cap_key": "dodge_chance",
		"cap_value": 0.40,
	},
	"module_crit_dmg": {
		"name": "致命一击",
		"description": "暴击伤害加成",
		"effect_key": "crit_damage_bonus",
		"effect_type": "flat_add",
		"base_value": 0.20,
		"pool_tier": POOL_SPECIAL,
		"category": "damage",
		"cap_key": null,
		"cap_value": 0.0,
	},
}

# ─────────────────────────────────────────────
#  查询接口
# ─────────────────────────────────────────────

## 获取词条定义数据，无数据返回空字典
static func get_module_data(module_id: String) -> Dictionary:
	return MODULE_TABLE.get(module_id, {})

## 获取词条名称
static func get_module_name(module_id: String) -> String:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	return d.get("name", "未知词条")

## 获取词条效果基础值
static func get_base_value(module_id: String) -> float:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	return float(d.get("base_value", 0.0))

## 获取词条效果键
static func get_effect_key(module_id: String) -> String:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	return d.get("effect_key", "")

## 获取词条效果类型
static func get_effect_type(module_id: String) -> String:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	return d.get("effect_type", "")

## 获取词条池层级
static func get_pool_tier(module_id: String) -> int:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	return int(d.get("pool_tier", POOL_BASIC))

## 获取词条等级对应的实际效果值
static func get_effect_value(module_id: String, level: int) -> float:
	var base: float = get_base_value(module_id)
	var factor: float = float(LEVEL_FACTORS.get(clampi(level, 1, 3), 1.0))
	return base * factor

## 获取所有词条ID
static func get_all_module_ids() -> Array:
	return MODULE_TABLE.keys()

## 获取指定池层级（及更低层级）可用的词条列表
static func get_available_modules(enhance_level: int) -> Array:
	var pool_limit: int = POOL_BASIC
	if enhance_level >= 10:
		pool_limit = POOL_SPECIAL
	elif enhance_level >= 6:
		pool_limit = POOL_ADVANCED
	var result: Array = []
	for mid in MODULE_TABLE:
		var tier: int = int(MODULE_TABLE[mid].get("pool_tier", POOL_BASIC))
		if tier <= pool_limit:
			result.append(mid)
	return result

## 检查词条效果是否达到上限
## accumulator: Dictionary — 当前该效果键的累计值
static func check_cap(module_id: String, current_accumulated: float) -> bool:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	var cap_key: String = d.get("cap_key", "")
	if cap_key.is_empty():
		return false
	var cap_value: float = float(d.get("cap_value", 0.0))
	return current_accumulated >= cap_value

## 获取词条上限值（用于显示，如 "≤60%"）
static func get_cap_display(module_id: String) -> String:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	var cap_value: float = float(d.get("cap_value", 0.0))
	var effect_type: String = d.get("effect_type", "")
	if cap_value <= 0.0:
		return ""
	match effect_type:
		"percent_mult", "percent_flat":
			return "≤%.0f%%" % (cap_value * 100.0)
		"flat_add":
			return "≤%.1f" % cap_value
		_:
			return "≤%.0f%%" % (cap_value * 100.0)

## 获取效果描述（用于UI显示，含等级）
static func get_effect_description(module_id: String, level: int) -> String:
	var d: Dictionary = MODULE_TABLE.get(module_id, {})
	if d.is_empty():
		return "未知效果"
	var name: String = d.get("name", "未知词条")
	var value: float = get_effect_value(module_id, level)
	var effect_type: String = d.get("effect_type", "")
	var effect_key: String = d.get("effect_key", "")

	var value_str: String = _format_effect_value(effect_key, effect_type, value)
	var cap_str: String = get_cap_display(module_id)
	if not cap_str.is_empty():
		value_str += " %s" % cap_str
	return "%s %s" % [name, value_str]

## 获取分类图标标记
static func get_category_icon(category: String) -> String:
	match category:
		"survival": return "🛡️"
		"damage": return "⚔️"
		"mobility": return "💨"
		_: return "❓"

# ─────────────────────────────────────────────
#  强化等级 → 词条槽位规则
# ─────────────────────────────────────────────

## 奇数强化等级(Lv2/4/6/8/10) = 获得新词条槽
## 偶数强化等级(Lv3/5/7/9) = 升级已有词条
static func is_new_slot_level(level: int) -> bool:
	return (level >= 2) and (level % 2 == 0)

## 获取指定强化等级应有的最大词条槽位数
static func get_max_slots_for_level(level: int) -> int:
	if level < 2:
		return 0
	return mini(level / 2, 5)  # Lv2=1, Lv4=2, Lv6=3, Lv8=4, Lv10=5

## 获取指定强化等级的动作类型
## 返回 "new_slot" / "upgrade_slot" / "none"
static func get_level_action(level: int) -> String:
	if level < 2:
		return "none"
	if level > 10:
		return "none"
	if is_new_slot_level(level):
		return "new_slot"
	return "upgrade_slot"

## Lv10 全属性加成倍率
const LEVEL10_ALL_STAT_BONUS: float = 0.10

# ─────────────────────────────────────────────
#  词条效果应用到 UnitStats
# ─────────────────────────────────────────────

## 将词条效果应用到 UnitStats（从基础值叠加，不含Lv10全属性）
## module_slots: Array of Dictionary — [{"module_id": str, "level": int, "slot_index": int}]
## 返回修改后的 stats（不修改原对象，创建副本效果字典）
static func apply_modules_to_stats(base_stats: Dictionary, module_slots: Array) -> Dictionary:
	var result: Dictionary = base_stats.duplicate(true)

	# 先重置词条效果字段到默认值（以防残留）
	result["damage_reduction"] = float(result.get("damage_reduction", 0.0))
	result["crit_chance"] = float(result.get("crit_chance", 0.0))
	result["crit_damage_bonus"] = float(result.get("crit_damage_bonus", 0.0))
	result["lifesteal"] = float(result.get("lifesteal", 0.0))
	result["splash_damage"] = float(result.get("splash_damage", 0.0))
	result["armor_penetration"] = float(result.get("armor_penetration", 0.0))
	result["chain_chance"] = float(result.get("chain_chance", 0.0))
	result["shield_on_kill"] = float(result.get("shield_on_kill", 0.0))
	result["hp_regen"] = float(result.get("hp_regen", 0.0))

	var hp_mult: float = 1.0
	var dmg_mult: float = 1.0
	var range_mult: float = 1.0
	var interval_mult: float = 1.0

	for slot in module_slots:
		var mid: String = slot.get("module_id", "")
		var lv: int = int(slot.get("level", 1))
		var d: Dictionary = MODULE_TABLE.get(mid, {})
		if d.is_empty():
			continue
		var effect_key: String = d.get("effect_key", "")
		var effect_type: String = d.get("effect_type", "")
		var value: float = get_effect_value(mid, lv)

		match effect_type:
			"percent_mult":
				match effect_key:
					"max_hp":
						hp_mult += value
					"attack_damage":
						dmg_mult += value
			"percent_flat":
				# 百分比点数直接叠加
				var current: float = float(result.get(effect_key, 0.0))
				result[effect_key] = minf(current + value, _get_cap_for_key(effect_key))
			"flat_add":
				var current: float = float(result.get(effect_key, 0.0))
				result[effect_key] = current + value
			"speed_add":
				var current: int = int(result.get(effect_key, 0))
				result[effect_key] = current + int(value)
			"range_mult":
				range_mult += value
			"interval_mult":
				interval_mult += value  # value 是负数

	# 应用乘算效果
	result["max_hp"] = float(result.get("max_hp", 100.0)) * maxf(hp_mult, 0.1)
	result["attack_light"] = float(result.get("attack_light", 0.0)) * maxf(dmg_mult, 0.1)
	result["attack_armor"] = float(result.get("attack_armor", 0.0)) * maxf(dmg_mult, 0.1)
	result["attack_air"] = float(result.get("attack_air", 0.0)) * maxf(dmg_mult, 0.1)
	result["attack_range"] = float(result.get("attack_range", 120.0)) * maxf(range_mult, 0.1)

	# 攻速间隔乘算（interval_mult < 0 代表加速）
	var base_interval: float = float(result.get("attack_interval", 1.0))
	result["attack_interval"] = base_interval * clampf(1.0 + interval_mult, 0.2, 3.0)

	return result

## 应用Lv10全属性加成到已有的 apply_modules_to_stats 结果
static func apply_level10_bonus(stats_dict: Dictionary) -> Dictionary:
	var r: Dictionary = stats_dict.duplicate(true)
	r["max_hp"] = float(r.get("max_hp", 100.0)) * (1.0 + LEVEL10_ALL_STAT_BONUS)
	r["attack_light"] = float(r.get("attack_light", 0.0)) * (1.0 + LEVEL10_ALL_STAT_BONUS)
	r["attack_armor"] = float(r.get("attack_armor", 0.0)) * (1.0 + LEVEL10_ALL_STAT_BONUS)
	r["attack_air"] = float(r.get("attack_air", 0.0)) * (1.0 + LEVEL10_ALL_STAT_BONUS)
	return r

## 计算词条总加成摘要（用于UI显示）
static func get_module_summary(module_slots: Array, enhance_level: int) -> Dictionary:
	var summary: Dictionary = {
		"hp_mult": 1.0,
		"dmg_mult": 1.0,
		"range_mult": 1.0,
		"interval_mult": 0.0,
		"damage_reduction": 0.0,
		"crit_chance": 0.0,
		"crit_damage_bonus": 0.0,
		"lifesteal": 0.0,
		"splash_damage": 0.0,
		"armor_penetration": 0.0,
		"chain_chance": 0.0,
		"shield_on_kill": 0.0,
		"hp_regen": 0.0,
		"dodge_chance": 0.0,
		"defense_flat": 0.0,
		"deploy_speed_add": 0,
		"level10_bonus": enhance_level >= 10,
	}

	for slot in module_slots:
		var mid: String = slot.get("module_id", "")
		var lv: int = int(slot.get("level", 1))
		var d: Dictionary = MODULE_TABLE.get(mid, {})
		if d.is_empty():
			continue
		var effect_key: String = d.get("effect_key", "")
		var effect_type: String = d.get("effect_type", "")
		var value: float = get_effect_value(mid, lv)

		match effect_type:
			"percent_mult":
				match effect_key:
					"max_hp":
						summary["hp_mult"] += value
					"attack_damage":
						summary["dmg_mult"] += value
					"attack_range":
						summary["range_mult"] += value
			"percent_flat":
				summary[effect_key] = float(summary.get(effect_key, 0.0)) + value
			"flat_add":
				if effect_key == "deploy_speed":
					summary["deploy_speed_add"] += int(value)
				elif effect_key == "crit_damage_bonus":
					summary["crit_damage_bonus"] += value
				else:
					summary["defense_flat"] += value
			"interval_mult":
				summary["interval_mult"] += value

	if enhance_level >= 10:
		summary["hp_mult"] += LEVEL10_ALL_STAT_BONUS
		summary["dmg_mult"] += LEVEL10_ALL_STAT_BONUS

	return summary

## 构建词条效果文本行（用于 info panel / tooltip）
static func build_effect_lines(summary: Dictionary) -> Array:
	var lines: Array = []
	if summary.get("hp_mult", 1.0) > 1.001:
		lines.append("HP ×%.2f" % summary["hp_mult"])
	if summary.get("dmg_mult", 1.0) > 1.001:
		lines.append("攻击 ×%.2f" % summary["dmg_mult"])
	if summary.get("damage_reduction", 0.0) > 0.001:
		lines.append("减伤 %.1f%%" % (summary["damage_reduction"] * 100.0))
	if summary.get("crit_chance", 0.0) > 0.001:
		var dmg_str: String = ""
		if summary.get("crit_damage_bonus", 0.0) > 0.001:
			dmg_str = " (%.1fx)" % (1.5 + summary["crit_damage_bonus"])
		lines.append("暴击 %.1f%%%s" % [summary["crit_chance"] * 100.0, dmg_str])
	if summary.get("lifesteal", 0.0) > 0.001:
		lines.append("吸血 %.1f%%" % (summary["lifesteal"] * 100.0))
	if summary.get("splash_damage", 0.0) > 0.001:
		lines.append("溅射 %.1f%%" % (summary["splash_damage"] * 100.0))
	if summary.get("armor_penetration", 0.0) > 0.001:
		lines.append("穿甲 %.1f%%" % (summary["armor_penetration"] * 100.0))
	if summary.get("chain_chance", 0.0) > 0.001:
		lines.append("闪电链 %.1f%%" % (summary["chain_chance"] * 100.0))
	if summary.get("shield_on_kill", 0.0) > 0.001:
		lines.append("击杀护盾 %.1f%%HP" % (summary["shield_on_kill"] * 100.0))
	if summary.get("hp_regen", 0.0) > 0.0001:
		lines.append("每秒回血 %.2f%%HP" % (summary["hp_regen"] * 100.0))
	if summary.get("dodge_chance", 0.0) > 0.001:
		lines.append("闪避 %.1f%%" % (summary["dodge_chance"] * 100.0))
	if summary.get("defense_flat", 0.0) > 0.001:
		lines.append("防御 +%.0f" % summary["defense_flat"])
	if summary.get("deploy_speed_add", 0) > 0:
		lines.append("部署速度 +%d" % summary["deploy_speed_add"])
	if summary.get("range_mult", 1.0) > 1.001:
		lines.append("射程 ×%.2f" % summary["range_mult"])
	if summary.get("interval_mult", 0.0) < -0.001:
		lines.append("攻速加速 %.0f%%" % abs(summary["interval_mult"] * 100.0))
	return lines

# ─────────────────────────────────────────────
#  内部工具
# ─────────────────────────────────────────────

static func _get_cap_for_key(effect_key: String) -> float:
	match effect_key:
		"damage_reduction": return 0.60
		"crit_chance": return 0.60
		"lifesteal": return 0.50
		"splash_damage": return 0.60
		"armor_penetration": return 0.60
		"chain_chance": return 0.50
		"dodge_chance": return 0.40
		_: return 999.0

static func _format_effect_value(effect_key: String, effect_type: String, value: float) -> String:
	match effect_type:
		"percent_mult":
			if value > 0:
				return "+%.1f%%" % (value * 100.0)
			else:
				return "%.1f%%" % (value * 100.0)
		"percent_flat":
			return "+%.1f%%" % (value * 100.0)
		"flat_add":
			if effect_key == "crit_damage_bonus":
				return "+%.1fx" % value
			return "+%.1f" % value
		"speed_add":
			return "+%d" % int(value)
		"range_mult":
			return "+%.0f%%" % (value * 100.0)
		"interval_mult":
			if value < 0:
				return "%.0f%%加速" % abs(value * 100.0)
			return "+%.0f%%" % (value * 100.0)
		_:
			return "+%.1f" % value
