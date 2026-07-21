extends RefCounted
class_name MasterPlatformPower
## 相位师「卡战力计算器」(v7.x 单分量公式)
##
## 把"一张战斗卡从裸卡到加成后战场 stats"的完整链路抽出来，
## 供 MasterPowerEvaluator 和 UI 共用，实现：
##   相位师战力 = Σ 每张装备卡经过完整加成后的实战力
##
## ── 玩家侧（compute_player_card_power）──
## 完整复刻 battle_spawn_system._build_stats_cached 的 7 层加成链：
##   1. UnitStatsTable.build_stats_from_card（基础 + 强化词条 + 强化等级 + mod_effects）
##   2. BlueprintManager.apply_growth_to_stats（稀有度/强化/改造/进化HP下限/军衔）
##   3. 激活势力技能 stat_bonus（玩家主动构筑）
##   4. AffixManager.apply_affixes_to_stats（词条养成）
##   5. PhaseInstrumentManager.apply_phase_field_bonus_to_unit_stats（相位仪+相位场+星级系数）
##   6. 符文之语全局加成
## → EvolutionHelpers.combat_power_from_unit_stats
##
## ── 敌方侧（compute_enemy_platform_power）──
## 复刻 enemy_phase_field_driver 的"相位师固有加成链"（不含战场波动项）：
##   1. 构造 CardResource from archetype（复用 _build_stats_from_archetype 逻辑）
##   2. EnemyStatResolver.apply_phase_master_to_unit_stats（相位师属性）
##   3. 相位师符文加成（master.equipment.runes，按 tier 限量）
##   4. 相位师相位仪加成（pi_atk/pi_def/pi_hp）
##   5. 配档 tier bonus（atk_pct/hp_pct/def_pct）
## → EvolutionHelpers.combat_power_from_unit_stats
##
## **不含**：wave/level/faction_buff（战场难度，属于关卡不属于相位师）
##           elite/boss 序列标记（出兵节奏，单次产兵的临时增强）
##           精英词缀（随机 roll，非相位师固有）
## 这保证同一相位师在任何关卡的战力都是同一个数（固有威胁）。
##
## ⚠️ 改动同步：敌方加成逻辑需与 enemy_phase_field_driver.gd 保持一致
##    （driver 是战斗产兵真身，此处是战力评估复刻）。

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const RuneDefinitions = preload("res://data/runes.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const GC = preload("res://resources/game_constants.gd")


# ═══════════════════════════════════════════════════════════════
#  玩家单卡战力（7 层加成，复刻 _build_stats_cached 链路）
# ═══════════════════════════════════════════════════════════════

## 计算玩家装备的一张战斗卡的"加成后战力"
## card: 装备槽里的 CardResource（可能是实例卡或裸模板）
## pm:   PhaseInstrumentManager autoload 节点
## bpm:  BlueprintManager autoload 节点
## 返回：combat_power_from_unit_stats（≥1.0）
static func compute_player_card_power(card: CardResource, pm: Node, bpm: Node) -> float:
	if card == null:
		return 0.0

	# ── 1. effective_card 解析 ──
	# 实例卡（instance_id 非空）养成数据直接在对象上；非实例卡走旧路径查 CardEnhancementManager。
	var effective_card: CardResource = card
	if card.instance_id.is_empty():
		var cem: Node = _get_autoload("CardEnhancementManager")
		if cem != null and cem.has_method("get_module_slots"):
			var enhance_slots: Array = cem.get_module_slots(card.card_id)
			if not enhance_slots.is_empty():
				var enhance_lvl: int = 0
				if cem.has_method("get_card_enhancement_level"):
					enhance_lvl = cem.get_card_enhancement_level(card.card_id)
				if effective_card.enhance_level != enhance_lvl or effective_card.module_slots.is_empty():
					var card_clone: CardResource = effective_card.clone()
					card_clone.enhance_level = enhance_lvl
					card_clone.module_slots = enhance_slots
					effective_card = card_clone

	# ── 2. 基础 stats（含强化词条 + 强化等级 + mod_effects）──
	var era: int = EvolutionHelpers._preview_battle_era()
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(effective_card, era)
	if stats == null:
		return 0.0

	# ── 3. 养成加成（稀有度/强化/改造/进化HP下限/军衔）──
	if bpm != null and bpm.has_method("apply_growth_to_stats"):
		bpm.apply_growth_to_stats(stats, effective_card, [])

	# ── 4. 激活势力技能 stat_bonus（玩家主动构筑）──
	var fsm: Node = _get_autoload("FactionSystemManager")
	if fsm != null and fsm.has_method("get_active_faction_skill_effects"):
		var faction_fx: Dictionary = fsm.get_active_faction_skill_effects()
		if not faction_fx.is_empty():
			_apply_faction_stat_bonus(stats, faction_fx.get("stat_bonus", {}))

	# ── 5. 词条 affix ──
	var am: Node = _get_autoload("AffixManager")
	if am != null and am.has_method("apply_affixes_to_stats"):
		am.apply_affixes_to_stats(stats, effective_card, [])

	# ── 6. 相位仪 + 相位场 + 星级系数 ──
	if pm != null and pm.has_method("apply_phase_field_bonus_to_unit_stats"):
		pm.apply_phase_field_bonus_to_unit_stats(stats)

	# ── 7. 符文之语全局加成 ──
	if pm != null and pm.has_method("get_rune_bonus"):
		_apply_rune_bonus_to_stats(stats, pm.get_rune_bonus())

	return EvolutionHelpers.combat_power_from_unit_stats(stats)


# ═══════════════════════════════════════════════════════════════
#  敌方单平台卡战力（archetype + 固有加成，不含波动项）
# ═══════════════════════════════════════════════════════════════

## 计算敌方相位师装备的一张平台卡的"加成后战力"
## platform_id: archetype id（master.equipment.platforms 的元素）
## master:      相位师配置字典（含 stats / equipment）
## era:         战斗时代（派生防御用）
## tier:        配档档位（"LOW"/"MID"/"HIGH"），UI/排行榜默认 HIGH（满配威胁）
## 返回：combat_power_from_unit_stats（≥1.0）
static func compute_enemy_platform_power(platform_id: String, master: Dictionary, era: int, tier: String = "HIGH") -> float:
	if platform_id.is_empty():
		return 0.0

	# ── 0. enriched equipment（含派生的 runes）──
	var equip: Dictionary = master.get("equipment", {})
	var master_id: String = String(master.get("id", ""))
	var rune_ids: Array = equip.get("runes", [])
	# 若 equip 无 runes（原始 JSON），尝试取 enriched
	if rune_ids.is_empty() and not master_id.is_empty():
		var enriched: Dictionary = EnemyPhaseMasters.get_enriched_equipment(master_id)
		if not enriched.is_empty():
			rune_ids = enriched.get("runes", [])

	# ── 1. 构造 CardResource from archetype + build_stats ──
	# 复刻 enemy_phase_field_driver._build_stats_from_archetype 的核心（archetype cfg → CardResource → build_stats_from_card）
	# v7.x C: tier 参数化（enhance_level + 满配改造 mods），对称玩家养成档位
	var tier_int: int = _tier_str_to_int(tier)
	var built: Dictionary = _build_stats_from_archetype_static(platform_id, era, tier_int)
	if built.is_empty():
		return 100.0  # archetype 查不到的兜底
	var stats: UnitStats = built.stats
	var arch_card: CardResource = built.card
	# v7.x C: apply_growth（军衔/强化/进化 HP 下限，对称玩家养成核心）——显著提升单卡战力
	var bpm: Node = _get_autoload("BlueprintManager")
	if bpm != null and bpm.has_method("apply_growth_to_stats"):
		bpm.apply_growth_to_stats(stats, arch_card, [], true)

	# ── 2. 相位师属性加成 ──
	var master_stats: Dictionary = master.get("stats", {})
	if not master_stats.is_empty():
		EnemyStatResolver.apply_phase_master_to_unit_stats(stats, master_stats)

	# ── 3. 相位师符文加成（按 tier 限量）──
	_apply_master_rune_bonus_static(stats, rune_ids, tier)

	# ── 4. 相位师相位仪加成（pi_atk/pi_def/pi_hp）──
	_apply_enemy_phase_instrument_bonus_static(stats, String(equip.get("phase_instrument", "")))

	# ── 5. 配档 tier bonus（atk_pct/hp_pct/def_pct）──
	var tier_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(_tier_str_to_int(tier))
	var tier_atk: float = float(tier_bonus.get("atk_pct", 0.0))
	var tier_hp: float = float(tier_bonus.get("hp_pct", 0.0))
	var tier_def: float = float(tier_bonus.get("def_pct", 0.0))
	if tier_atk > 0.0:
		var m: float = 1.0 + tier_atk
		stats.attack_damage = maxf(0.1, stats.attack_damage * m)
		stats.attack_light = maxf(0.1, stats.attack_light * m)
		stats.attack_armor = maxf(0.1, stats.attack_armor * m)
		stats.attack_air = maxf(0.1, stats.attack_air * m)
	if tier_hp > 0.0:
		stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + tier_hp))
	if tier_def > 0.0:
		var dm: float = 1.0 + tier_def
		stats.defense = maxf(0.0, stats.defense * dm)
		stats.defense_light = maxf(0.0, stats.defense_light * dm)
		stats.defense_armor = maxf(0.0, stats.defense_armor * dm)
		stats.defense_air = maxf(0.0, stats.defense_air * dm)

	return EvolutionHelpers.combat_power_from_unit_stats(stats)


# ═══════════════════════════════════════════════════════════════
#  内部辅助（复刻敌方加成链 —— 与 enemy_phase_field_driver 保持同步）
# ═══════════════════════════════════════════════════════════════

## 复刻 enemy_phase_field_driver._build_stats_from_archetype 的核心逻辑。
## 输入 archetype_id（含 aircraft tag 推断 combat_kind），输出含真实数值的 UnitStats。
## ⚠️ 改动需同步 enemy_phase_field_driver._build_stats_from_archetype（L905-999）
static func _build_stats_from_archetype_static(archetype_id: String, era: int, tier_int: int = EnemyLoadoutTiers.TIER_HIGH) -> Dictionary:
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if cfg.is_empty():
		return null
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = int(cfg.get("era", era))
	c.combat_kind = _archetype_combat_kind(cfg)
	# v7.x C: tier 参数化（enhance_level + 满配改造 mods），对称玩家养成档位
	var tier_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(tier_int)
	c.enhance_level = int(tier_bonus.get("enhance_level", 0))
	var legacy_wt: int = int(cfg.get("weapon_type", 1))
	c.legacy_weapon_type = legacy_wt
	var tags: Array = cfg.get("tags", [])
	var is_aircraft: bool = tags.has("air") or tags.has("aircraft")
	c.weapon_type = GC.legacy_weapon_to_new_weapon_type(legacy_wt, is_aircraft)
	c.base_hp = float(cfg.get("hp", 100.0))
	c.base_speed = absf(float(cfg.get("speed", -80.0)))
	c.range_value = max(1, int(round(float(cfg.get("attack_range", 120.0)) / 100.0)))
	var interval: float = float(cfg.get("attack_interval", 1.0))
	c.attack_speed = 1.0 / maxf(0.001, interval)
	# 三维攻击（优先读 UCT 覆盖字段，回退 attack_damage 派生）
	if cfg.has("attack_light") or cfg.has("attack_armor") or cfg.has("attack_air"):
		c.attack_light = float(cfg.get("attack_light", 0.0))
		c.attack_armor = float(cfg.get("attack_armor", 0.0))
		c.attack_air = float(cfg.get("attack_air", 0.0))
	else:
		var dmg_fallback: float = float(cfg.get("attack_damage", 10.0))
		c.attack_light = dmg_fallback
		c.attack_armor = dmg_fallback * 0.8
		c.attack_air = dmg_fallback * 0.7
	# 三维攻速（优先读 per-target interval）
	var ivl_l: float = float(cfg.get("attack_light_interval", interval))
	var ivl_a: float = float(cfg.get("attack_armor_interval", interval))
	var ivl_air: float = float(cfg.get("attack_air_interval", interval))
	c.attack_light_speed = 1.0 / maxf(0.001, ivl_l)
	c.attack_armor_speed = 1.0 / maxf(0.001, ivl_a)
	c.attack_air_speed = 1.0 / maxf(0.001, ivl_air)
	# 防御（沿用通用表，archetype 无防御字段）
	c.defense_light = 8.0
	c.defense_armor = 8.0 * 1.2
	c.defense_air = 8.0 * 0.6
	# v7.x C: 加满配改造（按 tier，对称玩家改造槽；build_stats_from_card 内部 _apply_mod_stat_effects + ModificationRegistry.apply_to_weapon_slots 自动应用）
	var tier_mods: Array = EnemyLoadoutTiers.get_modifications_for_tier(tier_int)
	c.mods = []
	for mod_id in tier_mods:
		c.mods.append({"id": String(mod_id)})
	var stats := UnitStatsTable.build_stats_from_card(c, era)
	# 防御对齐真实敌兵量级（与 driver L966-998 同款）
	var single_def: int = EnemyArchetypes.compute_defense_from_config(cfg)
	var ck: int = c.combat_kind
	if ck != GC.CombatKind.AIR and tags.has("aircraft"):
		ck = GC.CombatKind.AIR
	var def_l: float = float(single_def)
	var def_a: float = float(single_def)
	var def_air: float = float(single_def)
	match ck:
		GC.CombatKind.LIGHT:
			def_l = float(single_def); def_a = float(single_def) * 0.5; def_air = float(single_def) * 0.3
		GC.CombatKind.ARMOR:
			def_l = float(single_def) * 0.7; def_a = float(single_def); def_air = float(single_def) * 0.6
		GC.CombatKind.SUPPORT:
			def_l = float(single_def) * 0.5; def_a = float(single_def) * 0.7; def_air = float(single_def) * 0.3
		GC.CombatKind.AIR:
			def_l = float(single_def) * 0.6; def_a = float(single_def) * 0.4; def_air = float(single_def)
		GC.CombatKind.FORT:
			def_l = float(single_def) * 1.3; def_a = float(single_def) * 1.5; def_air = float(single_def) * 0.8
	stats.defense_light = def_l
	stats.defense_armor = def_a
	stats.defense_air = def_air
	stats.defense = maxf(def_l, maxf(def_a, def_air))
	return {"card": c, "stats": stats}


## 复刻 enemy_phase_field_driver._archetype_combat_kind（L1003-1014）
static func _archetype_combat_kind(cfg: Dictionary) -> int:
	var tags: Array = cfg.get("tags", [])
	if tags.has("infantry"):
		return int(GC.CombatKind.LIGHT)
	if tags.has("vehicle") or tags.has("armor") or tags.has("tank"):
		return int(GC.CombatKind.ARMOR)
	if tags.has("turret") or tags.has("fort") or tags.has("fortress"):
		return int(GC.CombatKind.FORT)
	if tags.has("air") or tags.has("aircraft"):
		return int(GC.CombatKind.AIR)
	return int(UnitStatsTable.PLATFORM_TO_COMBAT_KIND.get(0, GC.CombatKind.LIGHT))


## 复刻 enemy_phase_field_driver._apply_master_rune_bonus（L1036-1081）
## 按 tier 限量应用符文（LOW=1/MID=3/HIGH=6）。
## ⚠️ 改动需同步 enemy_phase_field_driver._apply_master_rune_bonus
static func _apply_master_rune_bonus_static(stats: UnitStats, rune_ids: Array, tier: String) -> void:
	if rune_ids.is_empty():
		return
	var rune_cap: int = int(EnemyLoadoutTiers.get_bonus_for_tier(_tier_str_to_int(tier)).get("rune_count", 99))
	var applied: int = 0
	for rid_var in rune_ids:
		if applied >= rune_cap:
			break
		var rid: String = String(rid_var)
		if rid.is_empty():
			continue
		var rune: Dictionary = RuneDefinitions.get_rune(rid)
		if rune.is_empty():
			continue
		var fx: Dictionary = rune.get("primary_effect", {})
		if fx.is_empty():
			continue
		var stat: String = String(fx.get("stat", ""))
		var val: float = float(fx.get("value", 0.0))
		if val == 0.0:
			continue
		var mult: float = 1.0 + val
		match stat:
			"attack":
				stats.attack_light *= mult
				stats.attack_armor *= mult
				stats.attack_air *= mult
				stats.attack_damage *= mult
			"defense":
				stats.defense_light *= mult
				stats.defense_armor *= mult
				stats.defense_air *= mult
				stats.defense *= mult
			"hp":
				stats.max_hp *= mult
			"attack_speed":
				stats.attack_light_speed /= mult
				stats.attack_armor_speed /= mult
				stats.attack_air_speed /= mult
				stats.attack_interval /= mult
		applied += 1


## 复刻 enemy_phase_field_driver._apply_enemy_phase_instrument_bonus（L1113-1142）
## ⚠️ 改动需同步 enemy_phase_field_driver._apply_enemy_phase_instrument_bonus
static func _apply_enemy_phase_instrument_bonus_static(stats: UnitStats, instrument_id: String) -> void:
	if instrument_id.is_empty():
		return
	var cfg: Dictionary = EnemyPhaseEquipment.get_phase_instrument(instrument_id)
	if cfg.is_empty():
		return
	var props: Array = cfg.get("properties", [])
	var atk_pct: float = 0.0
	var def_pct: float = 0.0
	var hp_pct: float = 0.0
	for p in props:
		match String(p.get("id", "")):
			"pi_atk": atk_pct = float(p.get("value", 0.0))
			"pi_def": def_pct = float(p.get("value", 0.0))
			"pi_hp":  hp_pct  = float(p.get("value", 0.0))
	if atk_pct > 0.0:
		stats.attack_light *= (1.0 + atk_pct)
		stats.attack_armor *= (1.0 + atk_pct)
		stats.attack_air *= (1.0 + atk_pct)
		stats.attack_damage *= (1.0 + atk_pct)
	if hp_pct > 0.0:
		stats.max_hp *= (1.0 + hp_pct)
	if def_pct > 0.0:
		stats.defense *= (1.0 + def_pct)
		stats.defense_light *= (1.0 + def_pct)
		stats.defense_armor *= (1.0 + def_pct)
		stats.defense_air *= (1.0 + def_pct)


## 复刻 battle_spawn_system._apply_active_faction_stat_bonus（L1277-1318）
## 注：此处只复刻三维攻击/防御/HP（产兵链无势力，但玩家链需要）。
static func _apply_faction_stat_bonus(stats: UnitStats, stat_bonus: Dictionary) -> void:
	if stat_bonus.is_empty():
		return
	var atk_keys: Array = ["atk_light", "atk_armor", "atk_air"]
	for i in range(atk_keys.size()):
		var k: String = atk_keys[i]
		if stat_bonus.has(k) and float(stat_bonus[k]) != 0.0:
			var mult: float = 1.0 + float(stat_bonus[k])
			match i:
				0: stats.attack_light *= mult
				1: stats.attack_armor *= mult
				2: stats.attack_air *= mult
	if stat_bonus.has("hp") and float(stat_bonus["hp"]) != 0.0:
		stats.max_hp *= (1.0 + float(stat_bonus["hp"]))


## 复刻 battle_spawn_system._apply_rune_bonus_to_stats（L1201-1268）
## 把符文之语加成应用到 stats（与玩家战场部署链完全一致）。
static func _apply_rune_bonus_to_stats(stats: UnitStats, bonus: Dictionary) -> void:
	var stat_map: Dictionary = bonus.get("stats", bonus.get("rune_stats", {}))
	if stat_map.is_empty():
		return
	# 攻击力
	if stat_map.has("attack") and float(stat_map["attack"]) != 0.0:
		var mult: float = 1.0 + float(stat_map["attack"])
		stats.attack_damage *= mult
		stats.attack_light *= mult
		stats.attack_armor *= mult
		stats.attack_air *= mult
	# 防御
	if stat_map.has("defense") and float(stat_map["defense"]) != 0.0:
		var dm: float = 1.0 + float(stat_map["defense"])
		stats.defense *= dm
		stats.defense_light *= dm
		stats.defense_armor *= dm
		stats.defense_air *= dm
	# HP
	if stat_map.has("hp") and float(stat_map["hp"]) != 0.0:
		stats.max_hp *= (1.0 + float(stat_map["hp"]))
	# 攻速
	if stat_map.has("attack_speed") and float(stat_map["attack_speed"]) != 0.0:
		var sm: float = 1.0 + float(stat_map["attack_speed"])
		stats.attack_light_speed /= sm
		stats.attack_armor_speed /= sm
		stats.attack_air_speed /= sm
		stats.attack_interval /= sm
	# 暴击
	if stat_map.has("crit") and float(stat_map["crit"]) != 0.0:
		stats.crit_chance = clampf(stats.crit_chance + float(stat_map["crit"]), 0.0, 0.95)
	# 闪避
	if stat_map.has("dodge") and float(stat_map["dodge"]) != 0.0:
		stats.dodge_chance = clampf(stats.dodge_chance + float(stat_map["dodge"]), 0.0, 0.75)
	# 穿甲
	if stat_map.has("attack_penetration") and float(stat_map["attack_penetration"]) != 0.0:
		stats.armor_penetration = clampf(stats.armor_penetration + float(stat_map["attack_penetration"]), 0.0, 1.0)


## tier 字符串/整数 → EnemyLoadoutTiers 的 int 档位（外部接口用 "HIGH"/"MID"/"LOW"，底层要 int）
static func _tier_str_to_int(tier) -> int:
	if typeof(tier) == TYPE_INT:
		return int(tier)
	match String(tier).to_upper():
		"HIGH": return EnemyLoadoutTiers.TIER_HIGH
		"MID":  return EnemyLoadoutTiers.TIER_MID
		"LOW":  return EnemyLoadoutTiers.TIER_LOW
	return EnemyLoadoutTiers.TIER_HIGH


## 安全获取 autoload 节点
static func _get_autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root:
		return tree.root.get_node_or_null(autoload_name)
	return null
