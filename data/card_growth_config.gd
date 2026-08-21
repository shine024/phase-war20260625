extends RefCounted
class_name CardGrowthConfig
## v18.c 统一等级成长表（双方战斗卡共用，派生式 flat）
##
## 设计（用户定稿）：
## - 兵种卡等级上限 30（我方=战斗经验驱动；敌方=关卡映射 ceil(关卡×0.3)）
## - 每级给派生固定值（加法，注入在全部乘区之后——成长轴纯加法，不进百分比堆叠）
## - 步进档：Lv1-10 ×1 / Lv11-20 ×1.5 / Lv21-30 ×2（单级值随档增长）
## - 词条节点：每 5 级一个（Lv5/10/15/20/25/30，共 6 个，对齐词条槽 4→6）
##
## 派生公式：每级基准[时代] × 兵种权重[combat_kind] × 稀有度系数[rarity]
## 数值锚点：各时代卡池中位基数（实测 2026-08-20），满级累计 ≈ 基数 +45~70%
## 校准：tests/player_progression_audit.gd 等级层实测，超带调 ERA_BASE。
##
## 敌方相位师（Lv5-30）等级加成也走本表（v18 的 % 曲线替换，ratio 重校见批次C）。

## 等级上限（兵种卡 = 相位师 = 30，全项目统一数字）
const MAX_CARD_LEVEL: int = 30

## 步进档边界（level → 单级值倍率）
const TIER_STEPS: Array = [
	{"min": 1, "max": 10, "mult": 1.0},
	{"min": 11, "max": 20, "mult": 1.5},
	{"min": 21, "max": 30, "mult": 2.0},
]

## 时代每级基准（对齐卡池中位：atk 39/71/105/205/232，hp 175/409/572/900/1100）
## def 不用实测中位（44/154/154/44/44 跨时代噪声大，兵种构成差异所致），
## 锚定 atk × 0.6 保持攻防同步。
const ERA_BASE: Dictionary = {
	0: {"atk": 0.5, "hp": 2.0, "def": 0.3},   # 一战
	1: {"atk": 0.9, "hp": 5.0, "def": 0.5},   # 二战
	2: {"atk": 1.3, "hp": 7.0, "def": 0.8},   # 冷战
	3: {"atk": 2.5, "hp": 11.0, "def": 1.5},  # 现代
	4: {"atk": 2.8, "hp": 13.0, "def": 1.7},  # 近未来
}

## 兵种权重（combat_kind → 各维权重；强化兵种个性：堡垒血厚攻弱、空军攻锐血薄）
const KIND_WEIGHT: Dictionary = {
	0: {"atk": 1.0, "hp": 1.0, "def": 1.0},    # LIGHT
	1: {"atk": 0.8, "hp": 1.4, "def": 1.3},    # ARMOR
	2: {"atk": 1.2, "hp": 0.8, "def": 0.8},    # AIR
	3: {"atk": 0.9, "hp": 0.9, "def": 1.0},    # SUPPORT
	4: {"atk": 0.6, "hp": 1.6, "def": 1.5},    # FORT
}

## 稀有度系数（稀有度获得成长身份，不只基础值差异）
const RARITY_MULT: Dictionary = {
	"common": 0.8, "uncommon": 0.9, "rare": 1.0,
	"epic": 1.1, "legendary": 1.2, "mythic": 1.3,
}

## 步进档倍率查询
static func tier_mult(level: int) -> float:
	for step in TIER_STEPS:
		if level >= step.min and level <= step.max:
			return float(step.mult)
	return 2.0  # 越界按最高档


## 派生单级加值：card 为 CardResource（era/combat_kind/rarity），敌方传裸参数用 derive_raw
static func derive_growth(card) -> Dictionary:
	return derive_raw(int(card.era), int(card.combat_kind), String(card.rarity))


static func derive_raw(era: int, combat_kind: int, rarity: String) -> Dictionary:
	var base: Dictionary = ERA_BASE.get(clampi(era, 0, 4), ERA_BASE[4])
	var kw: Dictionary = KIND_WEIGHT.get(clampi(combat_kind, 0, 4), KIND_WEIGHT[0])
	var rm: float = float(RARITY_MULT.get(rarity, 1.0))
	return {
		"atk": float(base.atk) * float(kw.atk) * rm,
		"hp": float(base.hp) * float(kw.hp) * rm,
		"def": float(base.def) * float(kw.def) * rm,
	}


## 累计成长（Lv1→target_level 的加值总和，float 供注入端取整）
static func total_growth(card, target_level: int) -> Dictionary:
	var g: Dictionary = derive_growth(card)
	return _accumulate(g, target_level)


static func total_growth_raw(era: int, combat_kind: int, rarity: String, target_level: int) -> Dictionary:
	return _accumulate(derive_raw(era, combat_kind, rarity), target_level)


static func _accumulate(g: Dictionary, target_level: int) -> Dictionary:
	var lv: int = clampi(target_level, 0, MAX_CARD_LEVEL)
	return {
		"atk": float(g.atk) * _weighted_levels(lv),
		"hp": float(g.hp) * _weighted_levels(lv),
		"def": float(g.def) * _weighted_levels(lv),
	}


## Σ(步进倍率)——Lv30 = 10×1 + 10×1.5 + 10×2 = 45
static func _weighted_levels(level: int) -> float:
	var sum: float = 0.0
	for i in range(1, level + 1):
		sum += tier_mult(i)
	return sum


## 词条节点（每 5 级一个，共 6 个）
static func is_affix_milestone(level: int) -> bool:
	return level > 0 and level % 5 == 0 and level <= MAX_CARD_LEVEL


## 敌方经典敌兵等级映射：关卡 1-100 → Lv1-30（ceil(关卡×0.3)）
static func enemy_level_for_stage(game_level: int) -> int:
	return clampi(ceili(maxi(1, game_level) * 30 / 100), 1, MAX_CARD_LEVEL)


## 注入端：把累计成长加到 UnitStats（最终加法——调用方保证在全部乘区之后）
## atk/hp/def 三维同加；def 加到三维防御。
static func apply_to_stats(stats, growth_total: Dictionary) -> void:
	if stats == null:
		return
	var a: float = float(growth_total.get("atk", 0.0))
	var h: float = float(growth_total.get("hp", 0.0))
	var d: float = float(growth_total.get("def", 0.0))
	if a > 0.0:
		stats.attack_light += a
		stats.attack_armor += a
		stats.attack_air += a
	if h > 0.0:
		stats.max_hp += h
	if d > 0.0:
		stats.defense += d
		stats.defense_light += d
		stats.defense_armor += d
		stats.defense_air += d
