extends RefCounted
class_name DisplayNames
## 全局显示名称翻译工具类
## 统一管理所有游戏标签、枚举、状态的中文名称映射
## 提供一致的本地化显示，避免UI中出现英文ID或数字编号

const GC = preload("res://resources/game_constants.gd")

# ─────────────────────────────────────────────
#  环境标签翻译
# ─────────────────────────────────────────────

## 天气名称映射
static func get_weather_name(weather: String) -> String:
	match weather:
		"clear": return "晴朗"
		"rain":  return "降雨"
		"storm": return "风暴"
		"fog":   return "迷雾"
		_:       return weather

## 地形名称映射
static func get_terrain_name(terrain: String) -> String:
	match terrain:
		"plain":   return "平原"
		"city":    return "城市"
		"mountain": return "山地"
		"forest":  return "森林"
		_:         return terrain

## 能量场名称映射
static func get_energy_field_name(field: String) -> String:
	match field:
		"normal":     return "常规场"
		"high_field": return "高能场"
		"nano_fog":   return "纳米雾"
		"void_rift":  return "虚空裂隙"
		_:            return field

## 时间段名称映射
static func get_time_of_day_name(tod: String) -> String:
	match tod:
		"day":  return "白天"
		"dusk": return "黄昏"
		"night": return "夜晚"
		_:      return tod

## 完整环境标签翻译（通用入口）
static func get_environment_label(env_key: String, raw_value: String) -> String:
	match env_key:
		"weather":      return get_weather_name(raw_value)
		"terrain":      return get_terrain_name(raw_value)
		"energy_field": return get_energy_field_name(raw_value)
		"time_of_day":  return get_time_of_day_name(raw_value)
		_:              return raw_value

## 批量翻译环境标签
static func translate_environment(env: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in env.keys():
		var value: String = str(env[key])
		result[key] = get_environment_label(key, value)
	return result

# ─────────────────────────────────────────────
#  战斗相关标签翻译
# ─────────────────────────────────────────────

## 单位类型名称映射
static func get_unit_type_name(unit_type: String) -> String:
	match unit_type:
		"infantry":  return "步兵"
		"vehicle":   return "载具"
		"turret":    return "阵地"
		"support":   return "支援"
		"aircraft":  return "航空"
		"tank":      return "坦克"
		"armored":   return "装甲"
		"frontline": return "前线"
		"backline":  return "后方"
		"elite":     return "精英"
		"boss":      return "头目"
		"sustained": return "持续"
		"fast":      return "快速"
		"stealth":   return "隐匿"
		"antitank":  return "反坦克"
		_:           return unit_type

## 标签名称批量翻译
static func translate_tag(tag: String) -> String:
	return get_unit_type_name(tag)

## 批量翻译标签数组
static func translate_tags(tags: Array) -> Array:
	var result: Array = []
	for tag in tags:
		result.append(translate_tag(str(tag)))
	return result

# ─────────────────────────────────────────────
#  词条相关翻译
# ─────────────────────────────────────────────

## 词条类型名称
static func get_affix_type_name(affix_type: String) -> String:
	match affix_type:
		"base_property":    return "基础属性"
		"combat_feature":   return "战斗特性"
		"special_mechanic": return "特殊机制"
		_:                  return affix_type

## 词条稀有度名称
static func get_affix_rarity_name(rarity: String) -> String:
	match rarity:
		"common":    return "普通"
		"uncommon":  return "优秀"
		"rare":      return "稀有"
		"epic":      return "史诗"
		"legendary": return "传说"
		_:           return "普通"

# ─────────────────────────────────────────────
#  法则相关翻译
# ─────────────────────────────────────────────

## 法则家族名称
static func get_law_family_name(family: String) -> String:
	match family:
		"STEEL":   return "钢铁"
		"FLAME":   return "烈焰"
		"THUNDER": return "雷霆"
		"VOID":    return "虚空"
		_:         return family

## 法则类型名称
static func get_law_kind_name(kind: String) -> String:
	match kind:
		"passive": return "被动"
		"active":  return "主动"
		_:         return kind

## 法则效果目标阵营
static func get_law_target_side_name(side: String) -> String:
	match side:
		"ALLY":  return "友方"
		"ENEMY": return "敌方"
		"BOTH":  return "双方"
		_:       return side

## 法则效果目标类型
static func get_law_target_type_name(type: String) -> String:
	match type:
		"ALL":      return "全部"
		"VEHICLE":  return "载具"
		"INFANTRY": return "步兵"
		"TURRET":   return "阵地"
		"AIRCRAFT": return "航空"
		_:          return type

# ─────────────────────────────────────────────
#  资源相关翻译
# ─────────────────────────────────────────────

## 基础资源名称
static func get_resource_name(resource_id: String) -> String:
	match resource_id:
		"nano_materials", "basic_nano": return "纳米材料"  # 兼容旧ID
		"alloy":         return "合金"
		"crystal":       return "晶体"
		"energy_block":  return "能量块"
		"law_shard":     return "法则碎片"
		"research_points": return "研究点"
		_:               return resource_id

## 资源单位
static func get_resource_unit(resource_id: String) -> String:
	match resource_id:
		"nano_materials", "basic_nano": return "纳"  # 兼容旧ID
		"alloy":         return "合"
		"crystal":       return "晶"
		"energy_block":  return "块"
		"law_shard":     return "片"
		"research_points": return "点"
		_:               return ""

# ─────────────────────────────────────────────
#  时代相关翻译
# ─────────────────────────────────────────────

## 时代名称
static func get_era_name(era: int) -> String:
	match era:
		0: return "一战"
		1: return "二战"
		2: return "冷战"
		3: return "现代"
		4: return "近未来"
		_: return "未知时代"

## 时代简称
static func get_era_short(era: int) -> String:
	match era:
		0: return "WW1"
		1: return "WW2"
		2: return "Cold"
		3: return "Modern"
		4: return "Future"
		_: return "??"

# ─────────────────────────────────────────────
#  格式化辅助方法
# ─────────────────────────────────────────────

## 格式化数量显示（添加单位）
static func format_count(count: int, unit: String = "") -> String:
	if unit.is_empty():
		return str(count)
	return "%d%s" % [count, unit]

## 格式化百分比显示
static func format_percent(value: float, decimals: int = 0) -> String:
	var format_str: String = "%%.%df%%%%" % decimals
	return format_str % (value * 100.0)

## 格式化范围显示（最小值-最大值）
static func format_range(min_val: float, max_val: float, decimals: int = 0) -> String:
	var format_str: String = "%%.%df - %%.%df" % [decimals, decimals]
	return format_str % [min_val, max_val]

## 格式化时间显示（秒转可读格式）
static func format_time(seconds: float) -> String:
	if seconds < 60:
		return "%.1f秒" % seconds
	var minutes: int = int(seconds) / 60
	var secs: float = fmod(seconds, 60.0)
	return "%d分%.1f秒" % [minutes, secs]

## 格式化大数值显示（添加K/M后缀）
static func format_big_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	return str(value)

## 格式化等级显示
static func format_level(level: int, prefix: String = "Lv.") -> String:
	return "%s%d" % [prefix, level]

## 格式化稀有度显示（带颜色）
static func format_rarity(rarity: String) -> String:
	return "[color=%s]%s[/color]" % [GC.get_rarity_color(rarity).to_html(), GC.get_rarity_name(rarity)]
