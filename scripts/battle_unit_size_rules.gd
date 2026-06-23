extends RefCounted
class_name BattleUnitSizeRules
## 战场单位卡图按类型缩放 + 空中单位悬浮的尺寸规则（单一真相源）
##
## 纯视觉规则：只影响卡图渲染大小与悬浮偏移，不改战斗逻辑
## （索敌/碰撞/伤害判定坐标完全不变）。
## 倍率作用于：立绘 + 势力底图 + 稀有度框 + 军衔条 + 名称条（整张卡一起缩放）。
## 血条不缩放（保持可读），仅锚定位置。

const GC = preload("res://resources/game_constants.gd")

## combat_kind → 尺寸倍率
const _SIZE_MUL: Dictionary = {
	GC.CombatKind.LIGHT: 0.8,    # 人类/步兵
	GC.CombatKind.ARMOR: 1.5,    # 装甲/战斗车
	GC.CombatKind.SUPPORT: 1.1,  # 支援/轻装
	GC.CombatKind.AIR: 1.5,      # 空中
	GC.CombatKind.FORT: 1.5,     # 堡垒
}

## 空中单位悬浮 Y 偏移（向上为负），让空中单位高于地面单位一行
const AIR_HOVER_OFFSET_PX: float = -90.0


## 返回指定 combat_kind 的尺寸倍率；未知类型默认 1.0
static func get_size_multiplier(combat_kind: int) -> float:
	return float(_SIZE_MUL.get(combat_kind, 1.0))


## 返回空中单位悬浮 Y 偏移（仅 is_hovering_kind 为真时使用）
static func get_air_hover_offset_px() -> float:
	return AIR_HOVER_OFFSET_PX


## 仅空中单位（AIR）悬浮于地面单位上方一行
static func is_hovering_kind(combat_kind: int) -> bool:
	return combat_kind == GC.CombatKind.AIR
