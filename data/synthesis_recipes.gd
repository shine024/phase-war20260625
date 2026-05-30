extends RefCounted
class_name SynthesisRecipes

## 合成规则（程序化匹配，无需手写配方）
## 匹配条件：两张卡 base_card_id 相同 && faction_id 不同

const FactionCardBonuses = preload("res://data/faction_card_bonuses.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ExclusiveCards = preload("res://data/faction_exclusive_cards.gd")

## 合成费用公式
static func get_synthesis_cost(base_card_id: String, faction_a: String, faction_b: String) -> Dictionary:
	var base_card: CardResource = DefaultCards.get_card_by_id(base_card_id)
	if base_card == null:
		# 可能是专属卡
		base_card = ExclusiveCards.create_card(_find_exclusive_cfg(base_card_id))
		if base_card == null:
			return {}
	var base_power: int = base_card.power
	return {
		"research_points": int(base_power * 2.5),
		"nanomaterial": int(base_power * 1.5),
		"synthesis_permit": 1,
	}

## 查找专属卡配置
static func _find_exclusive_cfg(card_id: String) -> Dictionary:
	for cfg in ExclusiveCards.EXCLUSIVE_CARDS:
		if cfg.get("id", "") == card_id:
			return cfg
	return {}

## 生成混血卡ID（使用双下划线分隔势力ID，避免歧义）
static func generate_hybrid_id(base_card_id: String, faction_a: String, faction_b: String) -> String:
	var pair: Array = [faction_a, faction_b]
	pair.sort()
	return "hybrid_%s__%s__%s" % [base_card_id, pair[0], pair[1]]

## 计算混血加成（两势力各取50%）
static func calculate_hybrid_bonus(base_card_id: String, faction_a: String, faction_b: String, level_a: int, level_b: int) -> Dictionary:
	var bonus_a: Dictionary = FactionCardBonuses.get_bonus(faction_a, level_a)
	var bonus_b: Dictionary = FactionCardBonuses.get_bonus(faction_b, level_b)
	var hybrid: Dictionary = {}
	# 所有数值字段取50%平均
	var numeric_keys: Array = [
		"hp_bonus", "atk_light_bonus", "atk_armor_bonus", "atk_air_bonus",
		"def_light_bonus", "def_armor_bonus", "def_air_bonus",
		"energy_cost_reduce", "attack_speed_bonus",
		"dodge_bonus", "crit_chance_bonus", "crit_damage_bonus",
		"accuracy_bonus", "hp_regen_pct", "damage_reduction_bonus", "effect_bonus",
	]
	for key in numeric_keys:
		var va: float = float(bonus_a.get(key, 0.0)) * 0.5
		var vb: float = float(bonus_b.get(key, 0.0)) * 0.5
		hybrid[key] = va + vb
	# 整数字段取平均后取整
	hybrid["deploy_speed_bonus"] = roundi(
		(float(bonus_a.get("deploy_speed_bonus", 0)) * 0.5) + (float(bonus_b.get("deploy_speed_bonus", 0)) * 0.5)
	)
	hybrid["range_bonus"] = roundi(
		(float(bonus_a.get("range_bonus", 0)) * 0.5) + (float(bonus_b.get("range_bonus", 0)) * 0.5)
	)
	# 名称
	var name_a: String = FactionCardBonuses.FACTION_NAMES.get(faction_a, "")
	var name_b: String = FactionCardBonuses.FACTION_NAMES.get(faction_b, "")
	hybrid["name_prefix"] = "混血·%s" % name_a
	hybrid["name_suffix"] = "x%s" % name_b
	return hybrid

## 检查是否为混血卡
static func is_hybrid_card(card_id: String) -> bool:
	return card_id.begins_with("hybrid_")

## 解析混血卡ID（支持双下划线分隔格式）
static func parse_hybrid_id(card_id: String) -> Dictionary:
	if not card_id.begins_with("hybrid_"):
		return {}
	# 新格式：hybrid_base__factionA__factionB
	if "__" in card_id:
		var parts: PackedStringArray = card_id.substr(7).split("__")
		if parts.size() < 3:
			return {}
		return {"base_card_id": parts[0], "faction_a": parts[1], "faction_b": parts[2]}
	# 旧格式兼容：hybrid_base_factionA_factionB（单下划线）
	var parts: Array = card_id.split("_", false, 4)
	if parts.size() < 5:
		return {}
	var rest: String = card_id.substr(7)
	var all_fid: Array = FactionCardBonuses.FACTION_NAMES.keys()
	var fid_a: String = ""
	var fid_b: String = ""
	for fid in all_fid:
		if rest.find("_" + fid + "_") >= 0 or rest.begins_with(fid + "_"):
			fid_a = fid
			var after_a: String = rest.substr(fid.length() + 1)
			for fid2 in all_fid:
				if after_a == fid2:
					fid_b = fid2
					break
			break
	if fid_a.is_empty() or fid_b.is_empty():
		return {}
	var base: String = rest.substr(0, rest.find("_" + fid_a + "_"))
	return {"base_card_id": base, "faction_a": fid_a, "faction_b": fid_b}
