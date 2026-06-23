class_name EvolutionHelpers
## 战力估算与属性增长 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）访问核心数据

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const RankRules = preload("res://data/rank_rules.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")

const _LAW_BLUEPRINT_PREFIX: String = "law:"

static func _is_law_blueprint_id(card_id: String) -> bool:
	return not card_id.is_empty() and card_id.begins_with(_LAW_BLUEPRINT_PREFIX)

## ─────────── 稀有度 ───────────

static func get_card_base_rarity(card_id: String) -> String:
	if _is_law_blueprint_id(card_id):
		return "rare"
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card:
		return card.rarity
	return "common"

static func get_card_rarity(card_id: String) -> String:
	return get_card_base_rarity(card_id)

static func get_rarity_multiplier(card_id: String) -> float:
	# v6.8: 稀有度乘区压缩（6档），避免稀有度过度主导战力
	var r: String = get_card_rarity(card_id)
	match r:
		"uncommon":  return 1.04
		"rare":      return 1.08
		"epic":      return 1.12
		"legendary": return 1.16
		"mythic":    return 1.20
		_:           return 1.0

static func get_effective_power_multiplier(card_id: String, bpm_ref: Node) -> float:
	if _is_law_blueprint_id(card_id):
		var enhance: int = _get_card_enhance_level(card_id)
		return 1.0 + float(maxi(0, enhance - 1)) * 0.07
	var rarity_mul: float = get_rarity_multiplier(card_id)
	var enhance: int = _get_card_enhance_level(card_id)
	var enhance_mul: float = BattleCardV3.enhance_stat_multiplier(enhance, get_card_rarity(card_id))
	return rarity_mul * enhance_mul

## ─────────── 内部辅助 ───────────

## 单武器：`stats.weapons[0]` 与 `attack_damage` 保持一致
static func _sync_single_weapon_damage_from_attack(stats: UnitStats) -> void:
	if stats == null or stats.weapons.size() != 1:
		return
	var w: Dictionary = stats.weapons[0] as Dictionary
	w["damage"] = stats.attack_damage
	stats.weapons[0] = w

static func _multiply_attack_damage_and_weapon_slots(stats: UnitStats, factor: float) -> void:
	if stats == null or factor == 1.0:
		return
	stats.attack_damage *= factor
	for i in range(stats.weapons.size()):
		var w: Dictionary = stats.weapons[i] as Dictionary
		if w.has("damage"):
			w["damage"] = float(w["damage"]) * factor
			stats.weapons[i] = w

static func _preview_battle_era() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 0
	var gm: Node = tree.root.get_node_or_null("GameManager")
	if gm != null and "current_level" in gm:
		return GC.get_era_for_level(int(gm.current_level))
	return 0

## ─────────── 强化成长倾斜 / 进化 HP 下限 ───────────

static func _apply_platform_enhance_growth_bias(stats: UnitStats, platform_card_id: String, bpm_ref: Node) -> void:
	if stats == null or platform_card_id.is_empty():
		return
	var enhance: int = _get_card_enhance_level(platform_card_id)
	var tiers: float = float(enhance)
	if tiers <= 0.0:
		return
	var bias: Dictionary = UnitStatsTable.get_combat_kind_growth_bias(stats.combat_kind)
	var hp_bias: float = float(bias.get("hp_bias", 0.04))
	var dmg_bias: float = float(bias.get("dmg_bias", 0.04))
	stats.max_hp *= 1.0 + tiers * hp_bias
	_multiply_attack_damage_and_weapon_slots(stats, 1.0 + tiers * dmg_bias)
	if bias.has("range_bias"):
		var range_mul: float = 1.0 + tiers * float(bias["range_bias"])
		stats.attack_range *= range_mul
		for i in range(stats.weapons.size()):
			var w: Dictionary = stats.weapons[i] as Dictionary
			if w.has("range"):
				w["range"] = float(w["range"]) * range_mul
				stats.weapons[i] = w
	if bias.has("def_bias"):
		stats.defense += tiers * float(bias["def_bias"]) * 2.0

static func _apply_evolution_hp_floor(stats: UnitStats, platform_card_id: String, era: int, bpm_ref: Node) -> void:
	if stats == null or platform_card_id.is_empty():
		return
	var floor_base: float = float(bpm_ref.blueprint_evolution_hp_floor.get(platform_card_id, 0.0))
	if floor_base <= 0.0:
		return
	# v6.8: 时代缩放已移除，进化 HP 下限直接用 floor_base（不再乘时代倍率）
	stats.max_hp = maxf(stats.max_hp, floor_base)

## ─────────── 军衔 ───────────

static func get_rank_info(card_id: String, bpm_ref: Node) -> Dictionary:
	if card_id.is_empty():
		return {}
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {}
	var base_rank: String = RankRules.get_base_rank_by_combat_kind(card.combat_kind)
	var power_score: float = estimate_power_score(card_id, bpm_ref)
	var rank_id: String = RankRules.get_rank_by_power(base_rank, power_score)
	var out: Dictionary = {
		"rank_id": rank_id,
		"rank_name": RankRules.get_rank_display_name(rank_id),
		"power_score": power_score,
	}
	bpm_ref.blueprint_rank_cache[card_id] = out.duplicate(true)
	return out

## ─────────── 战力估算 ───────────

## 平台/武器/合成卡用 UnitStats 推导；能量/法则用养成向公式
static func estimate_power_score(card_id: String, bpm_ref: Node) -> float:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return estimate_power_score_meta_only(card_id, bpm_ref)
	if card.card_type == GC.CardType.ENERGY or card.card_type == GC.CardType.LAW:
		return estimate_power_score_meta_only(card_id, bpm_ref)
	var stats: UnitStats = build_unit_stats_for_power_preview(card, bpm_ref)
	if stats == null:
		return estimate_power_score_meta_only(card_id, bpm_ref)
	return combat_power_from_unit_stats(stats)

static func estimate_power_score_meta_only(card_id: String, bpm_ref: Node) -> float:
	var enhance: int = _get_card_enhance_level(card_id)
	var mod_count: int = ModManager.get_modification_count(card_id, bpm_ref.blueprint_mods)
	var rarity_mul: float = get_rarity_multiplier(card_id)
	var inherit_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(card_id, 0.0))
	return (80.0 + float(enhance) * 28.0 + float(mod_count) * 22.0) * rarity_mul * (1.0 + inherit_bonus)

static func build_unit_stats_for_power_preview(card: CardResource, bpm_ref: Node) -> UnitStats:
	if card == null:
		return null
	var era: int = _preview_battle_era()
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		if stats == null:
			return null
		apply_growth_to_stats(stats, card, [], bpm_ref, false)
		# v6.0: 词条效果已由 UnitStatsTable.build_stats_from_card 内部处理
		# 不再需要额外调用 AffixManager
		return stats
	return null

## 与 RankRules 阈值（约 120~780）同量级
static func combat_power_from_unit_stats(stats: UnitStats) -> float:
	if stats == null:
		return 0.0
	var interval: float = maxf(float(stats.attack_interval), 0.05)
	var dps: float = float(stats.attack_damage) / interval
	var hp: float = maxf(float(stats.max_hp), 0.0)
	var range_f: float = maxf(float(stats.attack_range), 0.0)
	var spd: float = maxf(float(stats.move_speed), 0.0)
	var out: float = (
		hp * 0.28
		+ dps * 2.2
		+ range_f * 0.22
		+ spd * 0.08
		+ float(stats.damage_reduction) * 80.0
		+ float(stats.crit_chance) * 120.0
		+ float(stats.armor_penetration) * 60.0
	)
	return maxf(out, 1.0)

## ─────────── 属性增长 ───────────

static func apply_growth_to_stats(stats: UnitStats, platform_card: CardResource, weapon_cards: Array, bpm_ref: Node, apply_rank_bonus: bool = true) -> void:
	if stats == null:
		return
	var cards_to_check: Array = []
	if platform_card != null:
		cards_to_check.append(platform_card)
	for wc_raw in weapon_cards:
		if wc_raw is CardResource:
			cards_to_check.append(wc_raw)
	if cards_to_check.is_empty():
		return
	var hp_mul: float = 1.0
	var dmg_mul: float = 1.0
	var n: int = cards_to_check.size()
	for c_raw in cards_to_check:
		var c: CardResource = c_raw
		if c.card_id.is_empty():
			continue
		var m: float = get_effective_power_multiplier(c.card_id, bpm_ref)
		hp_mul += (m - 1.0) / float(n)
		dmg_mul += (m - 1.0) / float(n)
	stats.max_hp *= hp_mul
	_multiply_attack_damage_and_weapon_slots(stats, dmg_mul)
	if platform_card != null and not platform_card.card_id.is_empty():
		var inherit_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(platform_card.card_id, 0.0))
		if inherit_bonus > 0.0:
			var inh_mul: float = 1.0 + inherit_bonus
			stats.max_hp *= inh_mul
			_multiply_attack_damage_and_weapon_slots(stats, inh_mul)
		if apply_rank_bonus:
			var rank_info: Dictionary = get_rank_info(platform_card.card_id, bpm_ref)
			var rank_id: String = String(rank_info.get("rank_id", ""))
			var rank_bonus: Dictionary = RankRules.get_rank_bonus(rank_id)
			stats.max_hp *= float(rank_bonus.get("hp_mul", 1.0))
			var rank_dmg: float = float(rank_bonus.get("dmg_mul", 1.0))
			_multiply_attack_damage_and_weapon_slots(stats, rank_dmg)
		_apply_platform_enhance_growth_bias(stats, platform_card.card_id, bpm_ref)
		_apply_evolution_hp_floor(stats, platform_card.card_id, _preview_battle_era(), bpm_ref)
	_sync_single_weapon_damage_from_attack(stats)

## 计算 era0 预览 HP
static func compute_platform_preview_hp(card_id: String, era: int, bpm_ref: Node) -> float:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null or card.card_type != GC.CardType.COMBAT_UNIT:
		return 0.0
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
	if stats == null:
		return 0.0
	apply_growth_to_stats(stats, card, [], bpm_ref, false)
	return stats.max_hp

## 获取卡片强化等级（通过 CardEnhancementManager Autoload）
static func _get_card_enhance_level(card_id: String) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var cem: Node = tree.root.get_node_or_null("CardEnhancementManager")
		if cem != null and cem.has_method("get_card_enhancement_level"):
			return cem.get_card_enhancement_level(card_id)
	return 1
