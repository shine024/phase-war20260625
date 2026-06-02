extends Node
## 军衔称号注册表
## 管理统一军衔等级和兵种称号显示

## ─────────────────────────────────────────────
##  战力到军衔计算
## ─────────────────────────────────────────────

## 根据当前战力和基础战力获取军衔信息
static func get_military_title(base_power: int, current_power: int, unit_type: int) -> Dictionary:
	var power_ratio = float(current_power) / float(base_power) if base_power > 0 else 1.0
	var rank_level = UnifiedRankSystem.get_rank_by_power_ratio(power_ratio)
	var title_info = TitleDisplayNames.get_title_info(unit_type, rank_level)

	return {
		rank = rank_level,
		name = title_info.name,
		name_en = title_info.name_en,
		desc = title_info.desc,
		power_ratio = power_ratio,
		base_power = base_power,
		current_power = current_power,
	}

## 获取军衔等级（仅返回等级数字）
static func get_rank_level(base_power: int, current_power: int) -> int:
	var power_ratio = float(current_power) / float(base_power) if base_power > 0 else 1.0
	return UnifiedRankSystem.get_rank_by_power_ratio(power_ratio)

## 获取称号名称
static func get_title_name(base_power: int, current_power: int, unit_type: int) -> String:
	var info = get_military_title(base_power, current_power, unit_type)
	return info.name

## 获取称号英文名称
static func get_title_name_en(base_power: int, current_power: int, unit_type: int) -> String:
	var info = get_military_title(base_power, current_power, unit_type)
	return info.name_en

## ─────────────────────────────────────────────
##  战力计算
## ─────────────────────────────────────────────

## 计算当前战力（基础属性 + 强化 + 改造加成）
## 这应该由CardResource提供，这里提供辅助计算
static func calculate_current_power(card: Dictionary) -> int:
	var base_power = card.get("power", 0)
	var level = card.get("level", 1)

	# 强化倍率（通过UnifiedRankSystem统一计算）
	var level_bonus = UnifiedRankSystem.get_power_multiplier(level)

	# 改造加成
	var mod_bonus = get_modifications_power_bonus(card.get("installed_modifications", []))

	return int(base_power * level_bonus) + mod_bonus

## 计算改造战力加成
static func get_modifications_power_bonus(modifications: Array) -> int:
	var bonus = 0
	for mod_entry in modifications:
		var mod_id = mod_entry.get("id", "")
		# ModificationRegistry是autoload，直接访问
		var mod_data = ModificationRegistry.get_data(mod_id)
		var power_mult = mod_data.get("power_mult", 1.0)
		# 简化：每个改造增加固定战力
		bonus += int(power_mult * 10)
	return bonus

## ─────────────────────────────────────────────
##  UI显示辅助
## ─────────────────────────────────────────────

## 获取下一级军衔信息
static func get_next_rank_info(base_power: int, current_power: int, unit_type: int) -> Dictionary:
	var current_rank = get_rank_level(base_power, current_power)
	if current_rank >= 10:
		return {}  # 已满级

	var next_rank = current_rank + 1
	var next_rank_data = UnifiedRankSystem.get_rank_data(next_rank)
	var next_title_info = TitleDisplayNames.get_title_info(unit_type, next_rank)

	# 计算需要达到的战力
	var min_ratio = next_rank_data.get("power_ratio_min", 1.0)
	var target_power = int(base_power * min_ratio)

	# 防止除零错误
	var progress = 0.0
	if target_power > 0:
		progress = float(current_power) / float(target_power)

	return {
		current_rank = current_rank,
		next_rank = next_rank,
		next_name = next_title_info.name,
		next_name_en = next_title_info.name_en,
		next_desc = next_title_info.desc,
		target_power = target_power,
		current_power = current_power,
		progress = progress,
	}

## 获取军衔进度条信息（0-1）
static func get_rank_progress(base_power: int, current_power: int) -> float:
	var current_rank = get_rank_level(base_power, current_power)
	if current_rank >= 10:
		return 1.0

	var current_rank_data = UnifiedRankSystem.get_rank_data(current_rank)
	var next_rank_data = UnifiedRankSystem.get_rank_data(current_rank + 1)

	var current_min = base_power * current_rank_data.get("power_ratio_min", 1.0)
	var next_min = base_power * next_rank_data.get("power_ratio_min", 1.0)

	if next_min <= current_min:
		return 1.0

	var progress = (current_power - current_min) / (next_min - current_min)
	return clamp(progress, 0.0, 1.0)
