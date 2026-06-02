extends RefCounted
class_name UnifiedRankSystem
## 统一军衔等级系统
## 军衔根据战力动态计算，不存储在卡牌中
## Lv1-Lv10 对应不同的战力倍率和称号

## ─────────────────────────────────────────────
##  军衔等级定义（Lv1-Lv10）
##  战力倍率：当前战力 / 基础战力
## ─────────────────────────────────────────────

const RANK_DATA: Dictionary = {
	1: {
		level = 1,
		power_ratio_min = 1.00,  # 最小战力倍率
		power_ratio_max = 1.05,  # 最大战力倍率
		cost_multiplier = 0.0,   # 强化消耗倍率（首次无消耗）
	},
	2: {
		level = 2,
		power_ratio_min = 1.05,
		power_ratio_max = 1.10,
		cost_multiplier = 0.5,
	},
	3: {
		level = 3,
		power_ratio_min = 1.10,
		power_ratio_max = 1.15,
		cost_multiplier = 1.0,
	},
	4: {
		level = 4,
		power_ratio_min = 1.15,
		power_ratio_max = 1.20,
		cost_multiplier = 1.5,
	},
	5: {
		level = 5,
		power_ratio_min = 1.20,
		power_ratio_max = 1.25,
		cost_multiplier = 2.0,
	},
	6: {
		level = 6,
		power_ratio_min = 1.25,
		power_ratio_max = 1.30,
		cost_multiplier = 2.5,
	},
	7: {
		level = 7,
		power_ratio_min = 1.30,
		power_ratio_max = 1.35,
		cost_multiplier = 3.0,
	},
	8: {
		level = 8,
		power_ratio_min = 1.35,
		power_ratio_max = 1.50,
		cost_multiplier = 3.5,
	},
	9: {
		level = 9,
		power_ratio_min = 1.50,
		power_ratio_max = 1.60,
		cost_multiplier = 4.5,
	},
	10: {
		level = 10,
		power_ratio_min = 1.60,
		power_ratio_max = 999.0,  # 无上限
		cost_multiplier = 6.0,
	},
}

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 根据战力倍率获取军衔等级
static func get_rank_by_power_ratio(power_ratio: float) -> int:
	for level in range(1, 11):
		var data = RANK_DATA.get(level, RANK_DATA[1])
		if power_ratio >= data.power_ratio_min and power_ratio < data.power_ratio_max:
			return level
	# 超出最高等级则返回10
	return 10

## 获取军衔等级数据
static func get_rank_data(level: int) -> Dictionary:
	return RANK_DATA.get(level, RANK_DATA[1]).duplicate(true)

## 获取强化消耗倍率
static func get_cost_multiplier(level: int) -> float:
	var data = get_rank_data(level)
	return float(data.get("cost_multiplier", 1.0))

## 获取强化战力倍率
## 用于计算强化后的战力：base_power * get_power_multiplier(level)
static func get_power_multiplier(level: int) -> float:
	match level:
		1: return 1.00
		2: return 1.05
		3: return 1.10
		4: return 1.15
		5: return 1.20
		6: return 1.25
		7: return 1.30
		8: return 1.35
		9: return 1.50
		10: return 1.60
		_: return 1.0

## 获取战力倍率范围
static func get_power_ratio_range(level: int) -> Array:
	var data = get_rank_data(level)
	return [float(data.power_ratio_min), float(data.power_ratio_max)]
