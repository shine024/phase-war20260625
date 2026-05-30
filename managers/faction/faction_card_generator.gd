extends RefCounted
class_name FactionCardGenerator
## 势力变体卡牌生成器
##
## 职责：
##   1. generate_faction_variant(base_card_id, faction_id, level) -> CardResource
##   2. format_faction_card_name(base_name, faction_id, level) -> String
##   3. calculate_faction_power(base_power, bonus) -> int
##   4. is_faction_variant(card) -> bool
##   5. get_variant_meta(card) -> Dictionary
##
## 纯静态工具类，无实例状态。
## 缓存由调用方（battle_spawn_system._stats_cache）管理。

const DefaultCards = preload("res://data/default_cards.gd")
const FactionBonuses = preload("res://data/faction_card_bonuses.gd")

## 生成势力变体卡
## base_card_id: 基础卡ID（来自 DefaultCards）
## faction_id: 势力ID
## level: 势力等级（1-10）
## 返回 clone + 叠加加成后的 CardResource，失败返回 null
static func generate_faction_variant(base_card_id: String, faction_id: String, level: int) -> CardResource:
	# 参数校验
	if base_card_id.is_empty() or faction_id.is_empty() or level < 1 or level > 10:
		return null

	# 获取基础卡
	var base_card: CardResource = DefaultCards.get_card_by_id(base_card_id)
	if base_card == null:
		return null

	# 获取加成
	var bonus: Dictionary = FactionBonuses.get_bonus(faction_id, level)
	if bonus.is_empty():
		return null

	# clone 基础卡
	var variant: CardResource = base_card.clone()
	if variant == null:
		return null

	# 设置势力元数据
	variant.faction_id = faction_id
	variant.faction_level = level
	variant.base_card_id = base_card_id
	variant.is_faction_variant = true

	# 修改卡名
	variant.display_name = FactionBonuses.format_name(base_card.display_name, faction_id, level)

	# ── 叠加数值加成 ──
	apply_faction_bonus(variant, bonus)

	# 重算战力
	variant.power = FactionBonuses.calculate_power(base_card.power, bonus)

	return variant

## 将加成字典应用到 CardResource 上
static func apply_faction_bonus(card: CardResource, bonus: Dictionary) -> void:
	if card == null or bonus.is_empty():
		return

	# HP加成
	var hp_bonus: float = float(bonus.get("hp_bonus", 0.0))
	if hp_bonus != 0.0:
		card.base_hp = maxi(1.0, card.base_hp * (1.0 + hp_bonus))

	# 三维攻击加成
	var atk_l: float = float(bonus.get("atk_light_bonus", 0.0))
	var atk_a: float = float(bonus.get("atk_armor_bonus", 0.0))
	var atk_air: float = float(bonus.get("atk_air_bonus", 0.0))
	if atk_l != 0.0:
		card.attack_light = maxi(0.0, card.attack_light * (1.0 + atk_l))
	if atk_a != 0.0:
		card.attack_armor = maxi(0.0, card.attack_armor * (1.0 + atk_a))
	if atk_air != 0.0:
		card.attack_air = maxi(0.0, card.attack_air * (1.0 + atk_air))

	# 三维防御加成
	var def_l: float = float(bonus.get("def_light_bonus", 0.0))
	var def_a: float = float(bonus.get("def_armor_bonus", 0.0))
	var def_air: float = float(bonus.get("def_air_bonus", 0.0))
	if def_l != 0.0:
		card.defense_light = maxf(0.0, card.defense_light * (1.0 + def_l))
	if def_a != 0.0:
		card.defense_armor = maxf(0.0, card.defense_armor * (1.0 + def_a))
	if def_air != 0.0:
		card.defense_air = maxf(0.0, card.defense_air * (1.0 + def_air))

	# 能量消耗减少
	var energy_reduce: float = float(bonus.get("energy_cost_reduce", 0.0))
	if energy_reduce != 0.0:
		card.energy_cost = maxf(1.0, card.energy_cost * (1.0 - energy_reduce))

	# 部署速度加成
	var deploy_bonus: int = int(bonus.get("deploy_speed_bonus", 0))
	if deploy_bonus != 0:
		card.deploy_speed = clampi(card.deploy_speed + deploy_bonus, 0, 10)

	# 攻击速度加成
	var atk_spd: float = float(bonus.get("attack_speed_bonus", 0.0))
	if atk_spd != 0.0:
		card.attack_speed = maxf(0.1, card.attack_speed * (1.0 + atk_spd))
		# 同步 per-target 速度（按比例缩放）
		if card.attack_light_speed > 0:
			card.attack_light_speed = maxf(0.1, card.attack_light_speed * (1.0 + atk_spd))
		if card.attack_armor_speed > 0:
			card.attack_armor_speed = maxf(0.1, card.attack_armor_speed * (1.0 + atk_spd))
		if card.attack_air_speed > 0:
			card.attack_air_speed = maxf(0.1, card.attack_air_speed * (1.0 + atk_spd))

	# 射程加成
	var range_bonus: int = int(bonus.get("range_bonus", 0))
	if range_bonus != 0:
		card.range_value = maxi(1, card.range_value + range_bonus)

## 判断是否为势力变体卡
static func is_faction_variant(card: CardResource) -> bool:
	if card == null:
		return false
	return card.is_faction_variant

## 获取势力变体元数据
## 返回: { "faction_id": String, "level": int, "base_card_id": String }
static func get_variant_meta(card: CardResource) -> Dictionary:
	if card == null or not card.is_faction_variant:
		return {}
	return {
		"faction_id": card.faction_id,
		"level": card.faction_level,
		"base_card_id": card.base_card_id,
	}

## 将势力特殊加成应用到 UnitStats（由 battle_spawn_system 调用）
## 这些加成不直接在 CardResource 上体现，需要在 UnitStats 层注入
static func apply_faction_special_to_stats(stats: UnitStats, bonus: Dictionary) -> void:
	if stats == null or bonus.is_empty():
		return

	# 闪避加成
	var dodge: float = float(bonus.get("dodge_bonus", 0.0))
	if dodge > 0.0:
		stats.dodge_chance = minf(0.90, stats.dodge_chance + dodge)

	# 暴击率加成
	var crit_c: float = float(bonus.get("crit_chance_bonus", 0.0))
	if crit_c > 0.0:
		stats.crit_chance = minf(1.0, stats.crit_chance + crit_c)

	# 暴击伤害加成
	var crit_d: float = float(bonus.get("crit_damage_bonus", 0.0))
	if crit_d > 0.0:
		stats.crit_damage_bonus = stats.crit_damage_bonus + crit_d

	# 命中精度加成（映射到 dodge_chance 惩罚，间接提高命中率）
	var acc: float = float(bonus.get("accuracy_bonus", 0.0))
	if acc > 0.0:
		stats.faction_accuracy_bonus = minf(0.50, acc)

	# HP回复
	var hp_regen: float = float(bonus.get("hp_regen_pct", 0.0))
	if hp_regen > 0.0:
		stats.hp_regen = stats.hp_regen + hp_regen

	# 减伤加成
	var dmg_red: float = float(bonus.get("damage_reduction_bonus", 0.0))
	if dmg_red > 0.0:
		stats.damage_reduction = minf(0.90, stats.damage_reduction + dmg_red)

	# 法则效果加成
	var effect: float = float(bonus.get("effect_bonus", 0.0))
	if effect > 0.0:
		stats.faction_effect_bonus = minf(2.0, effect)
