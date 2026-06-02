## 军衔系统模块
## 统一军衔等级 + 兵种称号显示

## 核心类
const UnifiedRankSystem = preload("res://data/military_titles/unified_rank_system.gd")
const TitleDisplayNames = preload("res://data/military_titles/title_display_names.gd")

## ─────────────────────────────────────────────
##  便捷接口
## ─────────────────────────────────────────────

## 根据战力倍率获取军衔称号（组合调用）
static func get_military_title(unit_type: int, power_ratio: float) -> Dictionary:
	var rank = UnifiedRankSystem.get_rank_by_power_ratio(power_ratio)
	var title_info = TitleDisplayNames.get_title_info(unit_type, rank)
	return {
		"rank": rank,
		"name": title_info.name,
		"name_en": title_info.name_en,
		"desc": title_info.desc,
		"power_ratio": power_ratio,
	}
