extends RefCounted
class_name UnifiedRankSystem
## 强化等级数值系统（v6.11 瘦身：原军衔称号已移除，仅保留战力/消耗倍率）
## 战力倍率：当前战力 / 基础战力
## 强化倍率与战斗侧（attack_calculator/bullet 等）的 `1.0 + level * 0.05` 公式等价

## ─────────────────────────────────────────────
##  强化等级 → 战力倍率（Lv1-Lv10）
## ─────────────────────────────────────────────

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

## 强化消耗倍率（按目标等级）
static func get_cost_multiplier(level: int) -> float:
	match level:
		1: return 0.0
		2: return 0.5
		3: return 1.0
		4: return 1.5
		5: return 2.0
		6: return 2.5
		7: return 3.0
		8: return 3.5
		9: return 4.5
		10: return 6.0
		_: return 1.0
