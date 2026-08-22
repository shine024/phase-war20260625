extends RefCounted
class_name UnitStatsTable
## 数值表：从 CardResource 战斗卡字段构建 UnitStats
##
## v3 重构：主入口 build_stats_from_card() 直接从 CardResource 读取 base_* 字段，
## 不再依赖 platform_type + weapon_type 二元查表。
## v6.0: 新增 apply_module_effects() 将强化词条效果应用到 UnitStats。
## 旧 build_stats / build_multi_stats 已改为内部构造 CardResource 后调用新入口，
## 保留函数签名做兼容。

const GC = preload("res://resources/game_constants.gd")
# v9.1: 组合技套路检测（单卡改造组合 → 激活套路增益）
const ComboTactics = preload("res://data/combo_tactics.gd")
# 卡片定时技能：派生 law_family meta（阵营→flame/thunder/void），供 source_tag 触发判定
const CardPeriodicSkills = preload("res://data/card_periodic_skills.gd")


# ─────────────────────────────────────────────
#  新主入口：从 CardResource 战斗卡直接构建
# ─────────────────────────────────────────────

## 从 CardResource 的战斗卡字段直接构建 UnitStats
## card: CardResource（必须是 COMBAT_UNIT 类型）
## era_override: 覆盖时代（-1=使用 card.era）
static func build_stats_from_card(card: CardResource, era_override: int = -1) -> UnitStats:
	var stats = UnitStats.new()
	var e: int = era_override if era_override >= 0 else card.era
	stats.era = e
	stats.combat_kind = card.combat_kind
	stats.unit_subtype = card.unit_subtype  # v6.2: 透传子类标记
	stats.weapon_label = card.weapon_label
	stats.card_id = card.card_id
	# v8.x: 复制卡牌 tags 到 stats meta，供 _apply_v8_unit_type_meta 读取
	# （修复原 bug：_apply_v8_unit_type_meta 读 stats.has_meta("card_tags") 但从未写入）
	stats.set_meta("card_tags", card.tags.duplicate() if card.tags is Array else [])

	# 基础数值直接从卡牌读取
	stats.max_hp = card.base_hp
	# v3：使用新字段替代旧的base_interval/base_range
	# v5.0: 透传 per-target 攻速（替代旧的统一 attack_speed）
	stats.attack_light_speed = card.attack_light_speed
	stats.attack_armor_speed = card.attack_armor_speed
	stats.attack_air_speed = card.attack_air_speed
	# 旧兼容：用对轻装攻速作为统一 attack_interval
	stats.attack_interval = 1.0 / card.attack_light_speed if card.attack_light_speed > 0 else 1.0
	stats.attack_range = float(card.range_value * 100.0)  # 格转像素（1格=100px）
	stats.move_speed = card.base_speed
	stats.is_stationary = (card.base_speed <= 0.0)

	# v5.0 透传
	stats.power = card.power
	stats.enhance_level = card.enhance_level

	# 多维攻防
	stats.weapon_type = card.weapon_type
	stats.deploy_speed = card.deploy_speed
	stats.attack_light = card.attack_light
	stats.attack_armor = card.attack_armor
	stats.attack_air = card.attack_air
	# v6.2: 防御维度重新标定——由单位类型派生，覆盖旧的"防武器类型"语义数据
	var recal_def: Dictionary = derive_defense_by_unit_type(card.combat_kind, card.unit_subtype, e)
	stats.defense_light = recal_def["defense_light"]
	stats.defense_armor = recal_def["defense_armor"]
	stats.defense_air = recal_def["defense_air"]

	# v6.8: 时代缩放已移除（我方单位不按时代放大数值，敌方走独立的 wave/level 难度曲线）

	# 多武器（如果有）
	stats.weapons.clear()
	if card.multi_weapons.size() > 0:
		for w_entry in card.multi_weapons:
			var entry: Dictionary = w_entry.duplicate()
			entry["timer"] = 0.0
			stats.weapons.append(entry)

	# ═══════════════════════════════════════════════════════════
	# 武器槽位系统（新）— 无条件初始化
	# 旧逻辑：只有 card.multi_weapons.size() > 0 时才初始化，
	# 导致绝大多数默认战斗卡的 weapon_slots 始终为空，
	# ConstructUnitAI.get_weapon_for_target() 直接返回 null，
	# 战斗回退到陈旧路径，出现"不攻击"现象。
	# ═══════════════════════════════════════════════════════════
	stats.weapon_slots.clear()
	if card.has_method("_ensure_weapon_slots_initialized"):
		card._ensure_weapon_slots_initialized()

	var tmp_slots: Array[WeaponResource] = []
	for weapon in card.weapon_slots:
		if weapon is WeaponResource and weapon.enabled:
			var w_copy = weapon.clone()
			tmp_slots.append(w_copy)
		else:
			# 添加空槽位占位
			tmp_slots.append(WeaponResource.create_empty_slot(tmp_slots.size()))

	# v9.x: 兵种防御保底（轻装闪避/堡垒减伤）前置到改造应用之前——
	# 保底=单位基础属性先立，改造/词条叠加其上。原实现放在 apply_combat_kind_modifiers
	# （mod 之后）用 maxf，词条值低于保底时被整段吞掉（enh_dodge +6% < 轻装 0.18 保底 → 装了无效）。
	_apply_unit_type_defense_floors(stats)

	# v6.0/v6.13: 应用改造效果
	# 时序：先应用 stat 效果（attack_armor 等），再处理武器槽。
	# 原因：grant_slot 以载体 attack_armor 为基准派生对空伤害，必须读到加成后的值。
	if card.mods and not card.mods.is_empty():
		# v6.2: 先应用改造的 stat 效果（穿甲/条件穿甲/attack_armor 百分比等）到 UnitStats
		_apply_mod_stat_effects(stats, card.mods)
		# v6.0/v6.13: 再应用改造效果到武器槽位（传入 stats 作 source_stats，grant_slot 据此派生伤害）
		if ModificationRegistry and ModificationRegistry.has_method("apply_to_weapon_slots"):
			tmp_slots = ModificationRegistry.apply_to_weapon_slots(tmp_slots, card.mods, stats)

	stats.weapon_slots = tmp_slots

	# 旧字段兼容（写入旧字段让过渡期代码仍能工作）
	stats.platform_type = card.platform_type
	stats.legacy_weapon_type = card.legacy_weapon_type
	stats.platform_card_id = card.card_id

	# 战斗定位修正
	apply_combat_kind_modifiers(stats)

	# 综合防御：若未显式设置，从三维防御取最大值（格子战术护甲公式用）
	if stats.defense <= 0.0:
		stats.defense = maxf(stats.defense_light, maxf(stats.defense_armor, stats.defense_air))

	# v6.0: 应用强化词条效果（如有 module_slots）
	if card.module_slots.size() > 0:
		apply_module_effects(stats, card.module_slots, card.enhance_level)

	# v6.11: 应用强化等级加成（原战力星级②系统合并至此——星级0-7映射到强化0-10）
	apply_enhance_level_bonus(stats, card)

	return stats


## v6.11: 强化等级加成 — 固定数值（按兵种差异化）+ 特殊能力
## 取代已删除的战力星级系统（apply_battle_star_bonus），数据源从 battle_star 改为 enhance_level
## 满级(★10)总加成 ≈ 原满星(★7)，系数按 7/10 折算避免数值膨胀
static func apply_enhance_level_bonus(stats: UnitStats, card: CardResource) -> void:
	if stats == null or card == null:
		return
	# v7.4: 修复强化等级加成失效——原用 `"enhance_level" in card` 判断，但 `in` 操作符
	# 对 Object/RefCounted 恒返回 false（除非实现 _get），导致 lvl 永远 0，
	# 强化等级加成（HP/攻击/防御/特殊能力）完全不生效。直接读 card.enhance_level 字段。
	var lvl: int = int(card.enhance_level)
	if lvl <= 0:
		return
	var lvl_f: float = float(lvl)
	# 兵种差异化每级加成（原每星系数 × 7/10，保持满级总加成≈原满星）
	match stats.combat_kind:
		0:  # 轻装
			_apply_enhance_fixed(stats, lvl_f, 0.021, 0.028, "dodge", 0.0105)
			_apply_enhance_abilities(stats, 0, lvl)
		1:  # 装甲
			_apply_enhance_fixed(stats, lvl_f, 0.035, 0.021, "damage_reduction", 0.007)
			_apply_enhance_abilities(stats, 1, lvl)
		2:  # 支援
			_apply_enhance_fixed(stats, lvl_f, 0.028, 0.021, "hp_regen", 0.014)
			_apply_enhance_abilities(stats, 2, lvl)
		3:  # 空中
			_apply_enhance_fixed(stats, lvl_f, 0.0175, 0.035, "move_speed", 0.0105)
			_apply_enhance_abilities(stats, 3, lvl)
		4:  # 堡垒
			_apply_enhance_fixed(stats, lvl_f, 0.042, 0.0105, "damage_reduction", 0.014)
			_apply_enhance_abilities(stats, 4, lvl)
		_:
			_apply_enhance_fixed(stats, lvl_f, 0.021, 0.021, "", 0.0)
	# v8.x: 相位师技能树解锁的兵种特殊能力（叠加在强化等级解锁之上）
	_apply_skill_tree_unit_abilities(stats)

## v8.x: 应用相位师技能树解锁的兵种特殊能力
## 技能树 firepower 分支的 unit_ability 节点（light_crit/armor_pen/lifesteal_unlock 等）
## 解锁后给所有对应兵种单位叠加额外能力加成。
static func _apply_skill_tree_unit_abilities(stats: UnitStats) -> void:
	if stats == null:
		return
	var tree = Engine.get_main_loop()
	if tree == null or not (tree is SceneTree) or tree.root == null:
		return
	var pmsm: Node = tree.root.get_node_or_null("PhaseMasterSkillManager")
	if pmsm == null or not pmsm.has_method("is_content_unlocked"):
		return
	# 轻装暴击（light_crit）
	if pmsm.is_content_unlocked("unit_ability", "light_crit") and stats.combat_kind == 0:
		stats.crit_chance = minf(0.75, stats.crit_chance + 0.10)
	# 装甲穿甲（armor_pen）
	if pmsm.is_content_unlocked("unit_ability", "armor_pen") and stats.combat_kind == 1:
		stats.armor_penetration = minf(0.80, stats.armor_penetration + 0.15)
	# 吸血解锁（lifesteal_unlock，所有兵种）
	if pmsm.is_content_unlocked("unit_ability", "lifesteal_unlock"):
		stats.lifesteal = minf(0.60, stats.lifesteal + 0.05)

## v6.11: 强化固定数值加成（HP/攻击/兵种特殊）
static func _apply_enhance_fixed(stats: UnitStats, lvl_f: float, hp_pct: float, atk_pct: float, extra_key: String, extra_per_lvl: float) -> void:
	stats.max_hp *= (1.0 + hp_pct * lvl_f)
	var atk_mult: float = atk_pct * lvl_f
	stats.attack_light *= (1.0 + atk_mult)
	stats.attack_armor *= (1.0 + atk_mult)
	stats.attack_air *= (1.0 + atk_mult)
	for i in range(stats.weapons.size()):
		var wd: Dictionary = stats.weapons[i] as Dictionary
		if wd.has("damage"):
			wd["damage"] = float(wd["damage"]) * (1.0 + atk_mult)
			stats.weapons[i] = wd
	var extra_val: float = extra_per_lvl * lvl_f
	match extra_key:
		"dodge":
			stats.dodge_chance = minf(0.75, stats.dodge_chance + extra_val)
		"damage_reduction":
			stats.damage_reduction = minf(0.75, stats.damage_reduction + extra_val)
		"hp_regen":
			# v7.x: 加上限保护，与 _apply_ability_list 的 hp_regen 分支一致
			stats.hp_regen = minf(0.20, stats.hp_regen + extra_val)
		"move_speed":
			stats.move_speed *= (1.0 + extra_val)

## v6.11: 强化等级解锁的特殊能力（原星级3/5/7解锁 → 强化4/7/10解锁）
static func _apply_enhance_abilities(stats: UnitStats, combat_kind: int, lvl: int) -> void:
	# 每兵种最多3个能力，分别在强化4/7/10级解锁
	var unlocks: Array[int] = [4, 7, 10]
	match combat_kind:
		0:  # 轻装
			var defs: Array = [
				{"ek": "crit_chance", "ev": 0.10},
				{"ek": "lifesteal", "ev": 0.08},
				{"ek": "armor_penetration", "ev": 0.20},
			]
			_apply_ability_list(stats, defs, unlocks, lvl)
		1:  # 装甲
			var defs: Array = [
				{"ek": "damage_reduction", "ev": 0.05},
				{"ek": "shield_on_kill", "ev": 0.30},   # 击杀护盾 30%HP（v7.x 修复：原误写 30.0 → 3000%）
				{"ek": "damage_reduction", "ev": 0.10},
			]
			_apply_ability_list(stats, defs, unlocks, lvl)
		2:  # 支援
			var defs: Array = [
				{"ek": "splash_damage", "ev": 0.10},
				{"ek": "hp_regen", "ev": 0.05},   # 每秒回血 5%HP（v7.x 修复：原误写 5.0 → 500%/秒）
				{"ek": "splash_damage", "ev": 0.20},
			]
			_apply_ability_list(stats, defs, unlocks, lvl)
		3:  # 空中
			var defs: Array = [
				{"ek": "crit_chance", "ev": 0.10},
				{"ek": "chain_chance", "ev": 0.10},
				{"ek": "armor_penetration", "ev": 0.20},
			]
			_apply_ability_list(stats, defs, unlocks, lvl)
		4:  # 堡垒
			var defs: Array = [
				{"ek": "damage_reduction", "ev": 0.05},
				{"ek": "hp_regen", "ev": 0.03},   # 每秒回血 3%HP（v7.x 修复：原误写 3.0 → 300%/秒，第49关相位师产兵每秒回满血3次）
				{"ek": "damage_reduction", "ev": 0.10},
			]
			_apply_ability_list(stats, defs, unlocks, lvl)

## v6.11: 应用能力列表（按解锁等级阈值）
static func _apply_ability_list(stats: UnitStats, defs: Array, unlocks: Array[int], lvl: int) -> void:
	for i in range(defs.size()):
		if i < unlocks.size() and lvl >= unlocks[i]:
			var ek: String = String(defs[i].ek)
			var ev: float = float(defs[i].ev)
			match ek:
				"crit_chance":
					stats.crit_chance = minf(0.75, stats.crit_chance + ev)
				"lifesteal":
					stats.lifesteal = minf(0.60, stats.lifesteal + ev)
				"armor_penetration":
					stats.armor_penetration = minf(0.80, stats.armor_penetration + ev)
				"damage_reduction":
					stats.damage_reduction = minf(0.75, stats.damage_reduction + ev)
				"splash_damage":
					stats.splash_damage = minf(0.80, stats.splash_damage + ev)
				"hp_regen":
					# v7.x: 加上限保护（防止单位/数据写错导致回血失控），与其他字段的 minf(...) 同模式
					stats.hp_regen = minf(0.20, stats.hp_regen + ev)
				"chain_chance":
					stats.chain_chance = minf(0.60, stats.chain_chance + ev)
				"shield_on_kill":
					# v7.x: 加上限保护（与 damage_reduction 同量级）
					stats.shield_on_kill = minf(0.50, stats.shield_on_kill + ev)


## v6.4: 将强化词条效果应用到 UnitStats（统一管线）
## module_slots 里的旧 module_id（module_hp_up 等）需映射到新 enh_ ID，
## 通过 ModificationRegistry.apply_with_level 统一处理。
## enhance_level: int — 强化等级（用于Lv10全属性加成判断）
static func apply_module_effects(stats: UnitStats, module_slots: Array, enhance_level: int = 0) -> void:
	if stats == null or module_slots.is_empty():
		return
	# 将 module_slots 转为统一 mods 格式 [{id, level}]
	# 旧 module_id → 新 enh_ ID 映射
	var mods: Array = []
	for s in module_slots:
		var mod_id: String = ""
		var mod_level: int = 1
		if s is ModuleSlot:
			mod_id = _map_legacy_module_id(s.module_id)
			mod_level = clampi(s.level, 1, 3)
		elif s is Dictionary:
			mod_id = _map_legacy_module_id(String(s.get("module_id", "")))
			mod_level = clampi(int(s.get("level", 1)), 1, 3)
		if not mod_id.is_empty():
			mods.append({id = mod_id, level = mod_level})
	# 通过统一管线应用（复用 _apply_mod_stat_effects 的逻辑）
	if not mods.is_empty():
		_apply_mod_stat_effects(stats, mods)
	# Lv10 全属性加成（保留原有逻辑）
	if enhance_level >= 10:
		var bonus: float = 0.10
		stats.max_hp *= (1.0 + bonus)
		stats.attack_light *= (1.0 + bonus)
		stats.attack_armor *= (1.0 + bonus)
		stats.attack_air *= (1.0 + bonus)
		stats.attack_damage = stats.attack_light


## v6.4: 旧 module_id → 新 enh_ ID 映射表
static func _map_legacy_module_id(old_id: String) -> String:
	var mapping: Dictionary = {
		"module_hp_up": "enh_hp_up",
		"module_dmg_up": "enh_dmg_up",
		"module_def_up": "enh_def_up",
		"module_def_flat": "enh_def_flat",
		"module_speed_up": "enh_speed_up",
		"module_range_up": "enh_range_up",
		"module_atkspd_up": "enh_atkspd_up",
		"module_crit": "enh_crit",
		"module_lifesteal": "enh_lifesteal",
		"module_splash": "enh_splash",
		"module_penetration": "enh_penetration",
		"module_regen": "enh_regen",
		"module_chain": "enh_chain",
		"module_shield_kill": "enh_shield_kill",
		"module_dodge": "enh_dodge",
		"module_crit_dmg": "enh_crit_dmg",
	}
	# 新 enh_ ID 直接透传
	if old_id.begins_with("enh_"):
		return old_id
	return String(mapping.get(old_id, old_id))


## v6.4: 将改造的 stat 效果应用到 UnitStats（统一管线，支持level）
## 通过 ModificationRegistry.apply_with_level 处理所有 effects key，
## 然后把结果写回 UnitStats。
## 注：武器槽位效果（伤害/射程/攻速）由 apply_to_weapon_slots 单独处理。
static func _apply_mod_stat_effects(stats: UnitStats, mods: Array) -> void:
	if stats == null or mods.is_empty():
		return
	# v6.8: 提取 ally_* 光环配置存到 stats meta（供 construct_unit setup 时
	# 复制到节点，ModAuraHandler 读取后给全体友军广播 buff）
	_extract_aura_summary_to_meta(stats, mods)
	# 构建 base 字典（UnitStats → Dictionary）
	var base_dict: Dictionary = {
		"max_hp": stats.max_hp,
		"attack_light": stats.attack_light,
		"attack_armor": stats.attack_armor,
		"attack_air": stats.attack_air,
		"defense_light": stats.defense_light,
		"defense_armor": stats.defense_armor,
		"defense_air": stats.defense_air,
		"move_speed": stats.move_speed,
		"attack_range": stats.attack_range,
		"attack_interval": stats.attack_interval,
		# v7.5: per-target 攻速（attack_interval 死字段后，攻速改造改写这三个）
		"attack_light_speed": stats.attack_light_speed,
		"attack_armor_speed": stats.attack_armor_speed,
		"attack_air_speed": stats.attack_air_speed,
		"deploy_speed": stats.deploy_speed,
		"crit_chance": stats.crit_chance,
		"crit_damage_bonus": stats.crit_damage_bonus,
		# v7.x: crit_resist 补全（modification_registry:258 已写入 result，此处补 base + 回写）
		"crit_resist": stats.crit_resist,
		"dodge_chance": stats.dodge_chance,
		"damage_reduction": stats.damage_reduction,
		"armor_penetration": stats.armor_penetration,
		"armor_pen_vs_light": stats.armor_pen_vs_light,
		"armor_pen_vs_armor": stats.armor_pen_vs_armor,
		"armor_pen_vs_air": stats.armor_pen_vs_air,
		"lifesteal": stats.lifesteal,
		"splash_damage": stats.splash_damage,
		"chain_chance": stats.chain_chance,
		"shield_on_kill": stats.shield_on_kill,
		"hp_regen": stats.hp_regen,
		# v6.6: 改造条件型/乘数加成字段
		"attack_fort_bonus": stats.attack_fort_bonus,
		"splash_radius_bonus": stats.splash_radius_bonus,
		"single_target_penalty": stats.single_target_penalty,
		# v8: 兵种固定机制条件型攻击加成（供改造叠加）
		"attack_light_bonus": stats.attack_light_bonus,
		"attack_air_bonus": stats.attack_air_bonus,
		# v6.9: move_speed 类改造重定向为部署延迟百分比（move_speed 种子值保留供写回，不被 effects 增量）
		"deploy_delay_bonus": stats.deploy_delay_bonus,
		# v7.x: 新机制字段（成长型 / debuff 型 / 兵种专属）
		"combo_max": stats.combo_max,
		"combo_bonus_mult": stats.combo_bonus_mult,
		"rage_max": stats.rage_max,
		"rage_bonus_mult": stats.rage_bonus_mult,
		"armor_break_per_hit": stats.armor_break_per_hit,
		"armor_break_max_stacks": stats.armor_break_max_stacks,
		"mark_chance": stats.mark_chance,
		"mark_duration": stats.mark_duration,
		"mark_vuln_bonus": stats.mark_vuln_bonus,
		"crit_mark_chance": stats.crit_mark_chance,
		"crit_mark_duration": stats.crit_mark_duration,
		"crit_mark_bonus": stats.crit_mark_bonus,
		"siege_bonus_pct": stats.siege_bonus_pct,
		"urban_defense_bonus": stats.urban_defense_bonus,
		"has_counter_battery": stats.has_counter_battery,
		"counter_battery_shots": stats.counter_battery_shots,
		# v8: 堡垒阵地坚守光环（供改造叠加）
		"fort_shelter_aura": stats.fort_shelter_aura,
		# v7.x 第二批次新机制字段
		"revive_on_death": stats.revive_on_death,
		"revive_hp_ratio": stats.revive_hp_ratio,
		"reflect_damage_pct": stats.reflect_damage_pct,
		"reflect_charges": stats.reflect_charges,
		"intercept_chance": stats.intercept_chance,
		"intercept_charges": stats.intercept_charges,
		"death_heal_allies_pct": stats.death_heal_allies_pct,
		"death_heal_radius": stats.death_heal_radius,
		"minefield_damage": stats.minefield_damage,
		"slow_aura_pct": stats.slow_aura_pct,
		"slow_aura_radius": stats.slow_aura_radius,
		"command_aura_bonus": stats.command_aura_bonus,
		"phase_shield_pool": stats.phase_shield_pool,
		"phase_shield_regen": stats.phase_shield_regen,
		"laser_mark_on_hit": stats.laser_mark_on_hit,
		# v8.6 现实/科幻伤害类型
		"true_damage": stats.true_damage,
		"chem_chance": stats.chem_chance, "chem_dps": stats.chem_dps, "chem_duration": stats.chem_duration,
		"burn_chance": stats.burn_chance, "burn_dps": stats.burn_dps, "burn_duration": stats.burn_duration,
		"emp_chance": stats.emp_chance, "emp_true_damage": stats.emp_true_damage,
		"nano_chance": stats.nano_chance, "nano_pct": stats.nano_pct, "nano_duration": stats.nano_duration,
		# v9.1 组合技套路增益乘区
		"burn_dps_mult": stats.burn_dps_mult, "chem_dps_mult": stats.chem_dps_mult,
		"emp_true_damage_bonus": stats.emp_true_damage_bonus, "beam_damage_bonus": stats.beam_damage_bonus,
		# v10 解题式玩法：转换型改造字段
		"salvage_repair_pct": stats.salvage_repair_pct,
		"phase_shift_counter": stats.phase_shift_counter,
		"hijack_aura_radius": stats.hijack_aura_radius,
		"hijack_aura_duration": stats.hijack_aura_duration,
		"hijack_aura_cd": stats.hijack_aura_cd,
	}
	# 统一应用（支持 level_effects + effects 两种格式）
	var result: Dictionary = ModificationRegistry.apply_with_level(base_dict, mods)
	# 写回 UnitStats
	stats.max_hp = float(result.get("max_hp", stats.max_hp))
	stats.attack_light = float(result.get("attack_light", stats.attack_light))
	stats.attack_armor = float(result.get("attack_armor", stats.attack_armor))
	stats.attack_air = float(result.get("attack_air", stats.attack_air))
	stats.defense_light = float(result.get("defense_light", stats.defense_light))
	stats.defense_armor = float(result.get("defense_armor", stats.defense_armor))
	stats.defense_air = float(result.get("defense_air", stats.defense_air))
	stats.move_speed = float(result.get("move_speed", stats.move_speed))
	stats.attack_range = float(result.get("attack_range", stats.attack_range))
	stats.attack_interval = float(result.get("attack_interval", stats.attack_interval))
	# v7.5: per-target 攻速写回（attack_interval 死字段后，攻速改造经 registry 转写至此）
	stats.attack_light_speed = float(result.get("attack_light_speed", stats.attack_light_speed))
	stats.attack_armor_speed = float(result.get("attack_armor_speed", stats.attack_armor_speed))
	stats.attack_air_speed = float(result.get("attack_air_speed", stats.attack_air_speed))
	stats.deploy_speed = int(result.get("deploy_speed", stats.deploy_speed))
	stats.crit_chance = float(result.get("crit_chance", stats.crit_chance))
	stats.crit_damage_bonus = float(result.get("crit_damage_bonus", stats.crit_damage_bonus))
	# v7.x: crit_resist 回写（暴抗改造生效）
	stats.crit_resist = float(result.get("crit_resist", stats.crit_resist))
	stats.dodge_chance = float(result.get("dodge_chance", stats.dodge_chance))
	stats.damage_reduction = float(result.get("damage_reduction", stats.damage_reduction))
	stats.armor_penetration = float(result.get("armor_penetration", stats.armor_penetration))
	stats.armor_pen_vs_light = float(result.get("armor_pen_vs_light", stats.armor_pen_vs_light))
	stats.armor_pen_vs_armor = float(result.get("armor_pen_vs_armor", stats.armor_pen_vs_armor))
	stats.armor_pen_vs_air = float(result.get("armor_pen_vs_air", stats.armor_pen_vs_air))
	stats.lifesteal = float(result.get("lifesteal", stats.lifesteal))
	stats.splash_damage = float(result.get("splash_damage", stats.splash_damage))
	stats.chain_chance = float(result.get("chain_chance", stats.chain_chance))
	stats.shield_on_kill = float(result.get("shield_on_kill", stats.shield_on_kill))
	stats.hp_regen = float(result.get("hp_regen", stats.hp_regen))
	# v6.6: 改造条件型/乘数加成字段写回
	stats.attack_fort_bonus = float(result.get("attack_fort_bonus", stats.attack_fort_bonus))
	# v8: 兵种固定机制条件型攻击加成写回
	stats.attack_light_bonus = float(result.get("attack_light_bonus", stats.attack_light_bonus))
	stats.attack_air_bonus = float(result.get("attack_air_bonus", stats.attack_air_bonus))
	stats.splash_radius_bonus = float(result.get("splash_radius_bonus", stats.splash_radius_bonus))
	stats.single_target_penalty = float(result.get("single_target_penalty", stats.single_target_penalty))
	# v6.9: 部署延迟百分比加成写回（move_speed 类改造经 registry 重定向后落到此字段）
	stats.deploy_delay_bonus = float(result.get("deploy_delay_bonus", stats.deploy_delay_bonus))
	# v10 解题式玩法：转换型改造字段写回
	stats.salvage_repair_pct = float(result.get("salvage_repair_pct", stats.salvage_repair_pct))
	stats.phase_shift_counter = bool(result.get("phase_shift_counter", stats.phase_shift_counter))
	stats.hijack_aura_radius = float(result.get("hijack_aura_radius", stats.hijack_aura_radius))
	stats.hijack_aura_duration = float(result.get("hijack_aura_duration", stats.hijack_aura_duration))
	stats.hijack_aura_cd = float(result.get("hijack_aura_cd", stats.hijack_aura_cd))
	# v7.x: 新机制字段写回
	stats.combo_max = int(result.get("combo_max", stats.combo_max))
	stats.combo_bonus_mult = float(result.get("combo_bonus_mult", stats.combo_bonus_mult))
	stats.rage_max = int(result.get("rage_max", stats.rage_max))
	stats.rage_bonus_mult = float(result.get("rage_bonus_mult", stats.rage_bonus_mult))
	stats.armor_break_per_hit = float(result.get("armor_break_per_hit", stats.armor_break_per_hit))
	stats.armor_break_max_stacks = int(result.get("armor_break_max_stacks", stats.armor_break_max_stacks))
	stats.mark_chance = float(result.get("mark_chance", stats.mark_chance))
	stats.mark_duration = float(result.get("mark_duration", stats.mark_duration))
	stats.mark_vuln_bonus = float(result.get("mark_vuln_bonus", stats.mark_vuln_bonus))
	stats.crit_mark_chance = float(result.get("crit_mark_chance", stats.crit_mark_chance))
	stats.crit_mark_duration = float(result.get("crit_mark_duration", stats.crit_mark_duration))
	stats.crit_mark_bonus = float(result.get("crit_mark_bonus", stats.crit_mark_bonus))
	stats.siege_bonus_pct = float(result.get("siege_bonus_pct", stats.siege_bonus_pct))
	stats.urban_defense_bonus = float(result.get("urban_defense_bonus", stats.urban_defense_bonus))
	stats.has_counter_battery = bool(result.get("has_counter_battery", stats.has_counter_battery))
	stats.counter_battery_shots = int(result.get("counter_battery_shots", stats.counter_battery_shots))
	# v8: 堡垒阵地坚守光环写回
	stats.fort_shelter_aura = float(result.get("fort_shelter_aura", stats.fort_shelter_aura))
	# v7.x 第二批次新机制字段写回
	stats.revive_on_death = bool(result.get("revive_on_death", stats.revive_on_death))
	stats.revive_hp_ratio = float(result.get("revive_hp_ratio", stats.revive_hp_ratio))
	stats.reflect_damage_pct = float(result.get("reflect_damage_pct", stats.reflect_damage_pct))
	stats.reflect_charges = int(result.get("reflect_charges", stats.reflect_charges))
	stats.intercept_chance = float(result.get("intercept_chance", stats.intercept_chance))
	stats.intercept_charges = int(result.get("intercept_charges", stats.intercept_charges))
	stats.death_heal_allies_pct = float(result.get("death_heal_allies_pct", stats.death_heal_allies_pct))
	stats.death_heal_radius = float(result.get("death_heal_radius", stats.death_heal_radius))
	stats.minefield_damage = float(result.get("minefield_damage", stats.minefield_damage))
	stats.slow_aura_pct = float(result.get("slow_aura_pct", stats.slow_aura_pct))
	stats.slow_aura_radius = float(result.get("slow_aura_radius", stats.slow_aura_radius))
	stats.command_aura_bonus = float(result.get("command_aura_bonus", stats.command_aura_bonus))
	stats.phase_shield_pool = float(result.get("phase_shield_pool", stats.phase_shield_pool))
	stats.phase_shield_regen = float(result.get("phase_shield_regen", stats.phase_shield_regen))
	stats.laser_mark_on_hit = bool(result.get("laser_mark_on_hit", stats.laser_mark_on_hit))
	# v8.6 现实/科幻伤害类型回写
	stats.true_damage = float(result.get("true_damage", stats.true_damage))
	stats.chem_chance = float(result.get("chem_chance", stats.chem_chance))
	stats.chem_dps = float(result.get("chem_dps", stats.chem_dps))
	stats.chem_duration = float(result.get("chem_duration", stats.chem_duration))
	stats.burn_chance = float(result.get("burn_chance", stats.burn_chance))
	stats.burn_dps = float(result.get("burn_dps", stats.burn_dps))
	stats.burn_duration = float(result.get("burn_duration", stats.burn_duration))
	stats.emp_chance = float(result.get("emp_chance", stats.emp_chance))
	stats.emp_true_damage = float(result.get("emp_true_damage", stats.emp_true_damage))
	stats.nano_chance = float(result.get("nano_chance", stats.nano_chance))
	stats.nano_pct = float(result.get("nano_pct", stats.nano_pct))
	stats.nano_duration = float(result.get("nano_duration", stats.nano_duration))
	# v9.1 组合技套路增益乘区回写
	stats.burn_dps_mult = float(result.get("burn_dps_mult", stats.burn_dps_mult))
	stats.chem_dps_mult = float(result.get("chem_dps_mult", stats.chem_dps_mult))
	stats.emp_true_damage_bonus = float(result.get("emp_true_damage_bonus", stats.emp_true_damage_bonus))
	stats.beam_damage_bonus = float(result.get("beam_damage_bonus", stats.beam_damage_bonus))
	# v6.5→v6.6: 武器类改造改变武器型号，写入 legacy_weapon_type（不污染 weapon_type 弹道字段）
	# bullet 的 VFX/弹道 match 读 legacy_weapon_type，AI 曲射判断读 weapon_type
	if result.has("legacy_weapon_type"):
		stats.legacy_weapon_type = int(result["legacy_weapon_type"])
	# _special 里的效果暂不处理（如 smoke_ignore 等无直接stat对应）
	# 同步旧兼容字段
	stats.attack_damage = stats.attack_light
	# v9.1: 组合技套路——单卡改造组合检测。装了 ≥2 个同套路配套改造 → 该卡激活套路。
	# 把激活的 combo_id 列表 + _special 里的触发 flag 写入 stats meta，供 construct_unit 运行时读取。
	var _combo_mods_on_card: Array = []
	for m in mods:
		if m is Dictionary:
			_combo_mods_on_card.append(String(m.get("id", "")))
		else:
			_combo_mods_on_card.append(String(m))
	var _card_combos: Array = ComboTactics.detect_card_combos(_combo_mods_on_card)
	if not _card_combos.is_empty():
		stats.set_meta("combo_active", _card_combos.duplicate())
	# 把 _special 里的触发 flag（incendiary_chance/graphite_chance/chem_pollute 等）也存 meta，
	# 供 construct_unit 复制到节点，module_effect_handler 运行时读取后触发套路机制。
	if result.has("_special") and not result["_special"].is_empty():
		var _sp: Dictionary = result["_special"]
		stats.set_meta("mod_special_flags", _sp.duplicate(true))


## v6.8: 扫描 mods，提取 ally_* 光环配置存到 stats meta
## 供 construct_unit setup 时复制到节点，ModAuraHandler 读取后广播给全体友军
## ally_* 效果不进入 modification_registry 的 stat match（它们是"给友军"而非"给自己"）
## mods 格式: [{id, level}, ...] 或 [String, ...]，effects 通过 ModificationRegistry.get_data 查
static func _extract_aura_summary_to_meta(stats: UnitStats, mods: Array) -> void:
	var aura_keys := {
		"ally_hit_bonus": "crit_chance", "formation_bonus": "crit_chance", "network_bonus": "crit_chance",
		"ally_hp_regen": "hp_regen", "ally_fort_regen": "hp_regen",
		"ally_ammo": "attack_interval", "command_efficiency": "attack_interval",
		"ally_detection": "dodge_chance",
		"ally_arty_bonus": "attack_armor",
		"ally_river_bonus": "deploy_delay_bonus",
		"ally_bonus": "attack_all",
	}
	var summary: Dictionary = {}  # {stat_field: {op, raw}}
	for mod_entry in mods:
		var mod_id: String = ""
		if mod_entry is Dictionary:
			mod_id = String(mod_entry.get("id", ""))
			# 跳过已禁用的改造（与 modification_registry.apply_with_level 一致）
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		else:
			mod_id = String(mod_entry)
		if mod_id.is_empty():
			continue
		# 通过 registry 查改造数据拿 effects
		var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			continue
		var effects: Dictionary = mod_data.get("effects", {})
		for effect_key in effects:
			if not aura_keys.has(effect_key):
				continue
			var stat_field: String = aura_keys[effect_key]
			var raw: float = float(effects[effect_key])
			# 按 op 分类聚合
			var op: String = "add"
			match effect_key:
				"ally_ammo", "command_efficiency":
					op = "ammo"
				"ally_detection":
					op = "abs_add"
				"ally_arty_bonus", "ally_bonus":
					op = "mult_int"
				"ally_river_bonus":
					op = "river"
			if not summary.has(stat_field):
				summary[stat_field] = {"op": op, "raw": 0.0}
			summary[stat_field]["raw"] += raw
			summary[stat_field]["op"] = op
	if not summary.is_empty():
		stats.set_meta("mod_aura_summary", summary)


## v8: 侦察卡 card_id 前缀（与 recon_mods.gd._CARD_PREFIXES 同源，复用权威列表）
## 命中前缀的 LIGHT 卡是"侦察兵种"（拿潜入开局），否则是"步兵兵种"（拿巷战掩蔽）
const _RECON_PREFIXES: Array = ["ww1_inf_cavalry", "cold_spetsnaz", "mod_ranger", "fut_spectre", "fut_inf_scout_mech", "mod_inf_scout_drone"]

## 判定 card_id 是否为侦察兵种（复用 _RECON_PREFIXES 前缀匹配）
static func _is_recon_card(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	for prefix in _RECON_PREFIXES:
		if card_id.begins_with(prefix):
			return true
	return false


## 战斗定位固有修正（替代旧 apply_platform_innate_modifiers）
## v6.2: 防御维度与攻击维度对齐后，防御修正也改为对应维度
##       （装甲/堡垒擅长防装甲攻击 → defense_armor；空中擅长防空中攻击 → defense_air）
##       SUPPORT(2)/FORT(4) 旧值仍按其主类（LIGHT/ARMOR）处理，确保兼容未迁移数据。
## v8: 注入 8 兵种固定机制（天生被动，写在 base 层，无需改造/技能树）
## v9.x: 兵种防御保底（基础属性，改造应用之前执行——改造/词条在保底之上叠加）。
## 原三行 maxf 在 apply_combat_kind_modifiers（改造之后）执行，词条值低于保底时被吞，
## enh_dodge(+6~13%)/enh_def_up(+5~10%)/三防类(+30%) 对相应兵种装了无效。
static func _apply_unit_type_defense_floors(stats: UnitStats) -> void:
	if stats == null:
		return
	var is_light: bool = (stats.combat_kind == 0 or stats.combat_kind == 2)
	var is_air: bool = (stats.combat_kind == 3)
	var is_fort: bool = (stats.combat_kind == 4)
	var sub: int = stats.unit_subtype
	if sub == GC.UnitSubType.NONE and stats.combat_kind == 2:
		sub = GC.UnitSubType.SUPPORT
	if is_light:
		# 普通轻装步兵有闪避；火炮/重型支援无闪避（笨重装备）
		if sub != GC.UnitSubType.ARTILLERY:
			stats.dodge_chance = maxf(stats.dodge_chance, 0.18)
	# 火炮反炮兵保底（v9.x 前置：被攻击时标记攻击者，下 3 次射击优先打标记目标。
	# art_14 反击炮击改造经 registry 叠加 +2 次——保底须在改造前立好，改造增量才不被覆盖）
	if sub == GC.UnitSubType.ARTILLERY:
		stats.has_counter_battery = true
		stats.counter_battery_shots = maxi(stats.counter_battery_shots, 3)
	elif is_air:
		stats.dodge_chance = maxf(stats.dodge_chance, 0.12)
	elif is_fort:
		stats.damage_reduction = maxf(stats.damage_reduction, 0.30)

static func apply_combat_kind_modifiers(stats: UnitStats) -> void:
	if stats == null:
		return
	# 主类归属：LIGHT(0)/SUPPORT(2) → 轻装主类；ARMOR(1)/FORT(4) → 装甲主类；AIR(3) → 空中主类
	var is_light: bool = (stats.combat_kind == 0 or stats.combat_kind == 2)
	var is_armor: bool = (stats.combat_kind == 1 or stats.combat_kind == 4)
	# 子类判定：优先取 unit_subtype；若未设置则由旧 combat_kind 推断
	var sub: int = stats.unit_subtype
	if sub == GC.UnitSubType.NONE:
		if stats.combat_kind == 2:
			sub = GC.UnitSubType.SUPPORT  # 旧支援类 → 辅助子类
		elif stats.combat_kind == 4:
			sub = GC.UnitSubType.FORT      # 旧堡垒类 → 堡垒子类

	if is_light:
		# （闪避保底已前置至 _apply_unit_type_defense_floors——改造前执行，词条可叠加）
		if sub == GC.UnitSubType.SUPPORT:
			stats.max_hp *= 1.08  # 辅助单位（机枪巢/工兵）加HP
		# ── v8 兵种固定机制：按子类分派（SUPPORT(2) 归入 is_light 主类）──
		match sub:
			GC.UnitSubType.NONE:
				# 步兵 vs 侦察：都是 LIGHT/NONE，靠 card_id 前缀区分
				#   侦察（命中 _RECON_PREFIXES）→ 潜入开局标记（实际减伤在 construct_unit 运行时读 _is_recon_unit）
				#   步兵（不命中）→ 巷战掩蔽（受 ARMOR/AIR 攻击减伤 15%）
				if _is_recon_card(stats.card_id):
					stats.set_meta("is_recon_unit", true)  # 标记给 construct_unit 读取
				else:
					stats.urban_defense_bonus = maxf(stats.urban_defense_bonus, 0.15)
			GC.UnitSubType.ARTILLERY:
				# （火炮反炮兵保底已前置至 _apply_unit_type_defense_floors——改造前执行，art_14 增量可叠加）
				pass
			GC.UnitSubType.ANTI_AIR:
				# 防空空域封锁：对 AIR 伤害 +25%（索敌优先锁定 AIR 在 construct_unit_ai 处理）
				stats.attack_air_bonus = maxf(stats.attack_air_bonus, 0.25)
				stats.set_meta("is_anti_air_unit", true)  # 标记给索敌 AI 读取
			GC.UnitSubType.SUPPORT:
				# 工兵爆破专精：对 FORT/ARMOR 按攻击+最大HP 2%/击（siege_bonus_pct 已实装）
				stats.siege_bonus_pct = maxf(stats.siege_bonus_pct, 0.02)
	elif is_armor:
		# 装甲擅长防装甲攻击
		stats.defense_armor += 4.0
		if sub == GC.UnitSubType.FORT:
			# 堡垒：极高HP + 额外防装甲 + 全向防御加成
			stats.defense_armor += 4.0
			stats.defense_light += 4.0
			stats.defense_air += 4.0
			stats.max_hp *= 1.15
			# ── v8 兵种固定机制：堡垒阵地坚守 ──
			# （自身 30% 减伤保底已前置至 _apply_unit_type_defense_floors——改造前执行，词条可叠加）
			# 地面友军减伤光环 10%（fort_shelter_aura → module_effect_handler 每 tick 扫描）
			stats.fort_shelter_aura = maxf(stats.fort_shelter_aura, 0.10)
		else:
			# ── v8 兵种固定机制：装甲碾压 ──
			# 对 LIGHT 类目标伤害 +20%（attack_light_bonus → get_attack_vs 叠加）
			stats.attack_light_bonus = maxf(stats.attack_light_bonus, 0.20)
	elif stats.combat_kind == 3:  # 空中：高机动，擅长防空中攻击
		# （闪避保底已前置至 _apply_unit_type_defense_floors——改造前执行，词条可叠加）
		stats.defense_air += 2.0
		# ── v8 兵种固定机制：空中突袭击速 ──
		# 前 10s 攻速 ×1.5（标记给 construct_unit 运行时处理，避免此处改 attack_interval 被撤销逻辑覆盖）
		stats.set_meta("is_air_assault", true)

	# ── v8.x 新兵种机制 meta 标记 ──
	# ENGINEER(5)/SNIPER(6) 是新 CombatKind 值，归入 LIGHT 主类的运行时行为，
	# 但通过 meta 标记让 construct_unit 走独立的兵种机制分支。
	# 标记来源优先级：① 卡牌 tags 字段含 stalker/engineer/ecm/sniper → ② card_id 前缀匹配
	# 注意：这里只打标记，实际机制（隐身/首击/光环）由 construct_unit._init_unit_mechanisms 读取 meta 实现
	_apply_v8_unit_type_meta(stats)
	# 卡片定时技能：把玩家激活阵营的 law_family 写入 stats meta，供 source_tag 触发判定与卡牌面板显示
	_apply_law_family_meta(stats)
	# v8.6: 把 attack_*_bonus 同步到 weapon_slots[].damage（战斗主路径读 weapon.damage 不读 get_attack_vs，
	#   否则装甲碾压/防空封锁/对堡垒特攻的 bonus 字段全部空转）。weapon_slots 在本函数之前已建立。
	_sync_kind_bonus_to_weapon_slots(stats)


## v8.6: 把 attack_light_bonus / attack_air_bonus / attack_fort_bonus 同步到 weapon_slots[].damage。
## 战斗主路径（calculate_damage_with_weapon）读 weapon.damage 而非 get_attack_vs，
## 若不同步，兵种固定机制（装甲碾压 +20%、防空封锁 +25%、对堡垒特攻）全部空转。
## 槽位映射：slot[0]→LIGHT/SUPPORT、slot[1]→ARMOR/FORT、slot[2]→AIR。
static func _sync_kind_bonus_to_weapon_slots(stats: UnitStats) -> void:
	if stats == null or stats.weapon_slots.is_empty():
		return
	var light_bonus: float = float(stats.attack_light_bonus)
	var air_bonus: float = float(stats.attack_air_bonus)
	var fort_bonus: float = float(stats.attack_fort_bonus)
	if light_bonus <= 0.0 and air_bonus <= 0.0 and fort_bonus <= 0.0:
		return
	for i in range(stats.weapon_slots.size()):
		var w: Variant = stats.weapon_slots[i]
		if not (w is Dictionary):
			continue
		var wd: Dictionary = w
		var base_dmg: float = float(wd.get("damage", 0.0))
		if base_dmg <= 0.0:
			continue
		var mult: float = 1.0
		# slot[0] 对轻装（装甲碾压加成）
		if i == 0 and light_bonus > 0.0:
			mult += light_bonus
		# slot[1] 对装甲/堡垒（对堡垒特攻加成叠加到装甲槽）
		if i == 1 and fort_bonus > 0.0:
			mult += fort_bonus
		# slot[2] 对空中（防空封锁加成）
		if i == 2 and air_bonus > 0.0:
			mult += air_bonus
		if mult > 1.0:
			wd["damage"] = maxf(0.1, base_dmg * mult)
			stats.weapon_slots[i] = wd


## v8.x: 根据卡牌 tags 或 card_id 前缀，为新兵种（STALKER/ENGINEER/ECM/SNIPER）打 meta 标记
## 供 construct_unit._init_unit_mechanisms 读取并初始化运行时机制
static func _apply_v8_unit_type_meta(stats: UnitStats) -> void:
	if stats == null:
		return
	# 收集卡牌 tags（CardResource.tags 在 build_stats_from_card 时未复制到 UnitStats，
	# 这里从 stats.card_id 反查或读 meta "card_tags"）
	var card_tags: Array = []
	if stats.has_meta("card_tags"):
		var t = stats.get_meta("card_tags")
		if t is Array:
			card_tags = t
	# card_id 前缀推断（兜底：无 tags 时按命名约定）
	var cid: String = stats.card_id.to_lower()
	# STALKER：渗透者（隐身 + 首击×1.5）
	if "stalker" in card_tags or cid.find("stalker") >= 0 or cid.find("stealth") >= 0 \
	   or cid.find("spectre") >= 0 or cid.find("recon") >= 0:
		stats.set_meta("is_stalker", true)
	# ENGINEER：工程师（卡片技能触发源 + 打断施法）
	if "engineer" in card_tags or cid.find("engineer") >= 0 or cid.find("support") >= 0 \
	   or cid.find("combat_eng") >= 0:
		stats.set_meta("is_engineer", true)
	# ECM：电子战（光环减益）。v8.7 收紧匹配——原 "drone" 子串误伤全部无人机
	# （纳米修复机等非电子战单位也带敌方减益光环）；电子战单位改按
	# ecm/jammer/growler/electronic 显式匹配（growler=EA-18G 电子战机，此前漏配成零机制白板）。
	if "ecm" in card_tags or cid.find("ecm") >= 0 or cid.find("jammer") >= 0 \
	   or cid.find("growler") >= 0 or cid.find("electronic") >= 0:
		stats.set_meta("is_ecm", true)
	# SNIPER：狙击手（首击必爆 + 锁 Boss）
	if "sniper" in card_tags or cid.find("sniper") >= 0 or cid.find("marksman") >= 0 \
	   or cid.find("spetsnaz") >= 0:
		stats.set_meta("is_sniper", true)

	# ── v8.5: 兵种机制技能 meta（由技能树 unit_mechanism 解锁守卫）──
	# 载体：侦察/狙击/装甲/防空·电子战/堡垒·导弹井·护盾器/无人机
	# 守卫：必须技能树解锁对应 unit_mechanism 才打 meta（未解锁则机制不生效）
	var sm: Node = null
	if Engine.has_singleton("PhaseMasterSkillManager"):
		sm = Engine.get_singleton("PhaseMasterSkillManager")
	else:
		# v8.5: 静态上下文无 Engine.get_singleton，走 autoload 节点路径（运行时有效）
		var tree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			sm = tree.root.get_node_or_null("PhaseMasterSkillManager")
	if sm != null:
		# 定向爆破：侦察单位（复用 is_recon_unit 判定逻辑，或 card_id 前缀）
		var is_recon_unit := stats.has_meta("is_recon_unit") and bool(stats.get_meta("is_recon_unit", false))
		if is_recon_unit and sm.has_method("is_content_unlocked") \
		   and sm.is_content_unlocked("unit_mechanism", "demolition"):
			stats.set_meta("is_demolition", true)
		# 瞄准狙击：狙击单位
		if stats.has_meta("is_sniper") and bool(stats.get_meta("is_sniper", false)) \
		   and sm.is_content_unlocked("unit_mechanism", "sniper_aim"):
			stats.set_meta("is_sniper_aim", true)
		# 闪电穿插：装甲单位（ARMOR 主类且非 FORT 子类）
		if stats.combat_kind == GC.CombatKind.ARMOR and stats.unit_subtype != GC.UnitSubType.FORT \
		   and sm.is_content_unlocked("unit_mechanism", "blitz_pierce"):
			stats.set_meta("is_blitz_pierce", true)
		# 电子屏蔽：防空单位（ANTI_AIR 子类）或电子战单位（is_ecm）
		var is_aa_or_ecm := (stats.unit_subtype == GC.UnitSubType.ANTI_AIR) \
		                   or (stats.has_meta("is_ecm") and bool(stats.get_meta("is_ecm", false)))
		if is_aa_or_ecm and sm.is_content_unlocked("unit_mechanism", "jamming_field"):
			stats.set_meta("is_jamming_field", true)
		# 战术核武：堡垒单位且 card_id 含导弹井关键字
		if stats.combat_kind == GC.CombatKind.FORT \
		   and (cid.find("missile") >= 0 or cid.find("silo") >= 0 or cid.find("nuke") >= 0) \
		   and sm.is_content_unlocked("unit_mechanism", "nuclear_strike"):
			stats.set_meta("is_nuclear_strike", true)
		# 护盾投射：堡垒单位且 card_id 含护盾/发射器关键字
		if stats.combat_kind == GC.CombatKind.FORT \
		   and (cid.find("shield") >= 0 or cid.find("phalanx") >= 0 or cid.find("citadel") >= 0) \
		   and sm.is_content_unlocked("unit_mechanism", "shield_projector"):
			stats.set_meta("is_shield_projector", true)
		# 定时标记：无人机单位（card_id 含 drone/uav，含侦察无人机和战术无人机）
		if (cid.find("drone") >= 0 or cid.find("uav") >= 0) \
		   and sm.is_content_unlocked("unit_mechanism", "drone_mark"):
			stats.set_meta("is_drone_mark", true)
		# v8.6 化学武器：支援/火炮单位（解锁后自带化学弹头能力）
		if stats.combat_kind == GC.CombatKind.SUPPORT \
		   and sm.is_content_unlocked("unit_mechanism", "chemical_weapon"):
			stats.chem_chance = maxf(stats.chem_chance, 0.25)
			stats.chem_dps = maxf(stats.chem_dps, 6.0)
			stats.chem_duration = maxf(stats.chem_duration, 5.0)
		# v8.6 纳米病毒：支援/火炮单位（解锁后自带纳米病毒弹头）
		if stats.combat_kind == GC.CombatKind.SUPPORT \
		   and sm.is_content_unlocked("unit_mechanism", "nano_virus"):
			stats.nano_chance = maxf(stats.nano_chance, 0.20)
			stats.nano_pct = maxf(stats.nano_pct, 0.015)
			stats.nano_duration = maxf(stats.nano_duration, 6.0)


## 卡片定时技能：把玩家激活阵营的 law_family 写入 stats meta。
## 供 CardPeriodicSkills.compute_source_tags_for_stats 读取（flame/thunder/void 类技能触发源）。
## 复用 _apply_v8_unit_type_meta 的 autoload 读取模式（静态上下文 Engine.get_singleton → 兜底 autoload 节点）。
## 未激活阵营（空串）→ 不写 meta → flame/thunder/void 类技能休眠（设计如此：阵营选定后开启）。
static func _apply_law_family_meta(stats: UnitStats) -> void:
	if stats == null:
		return
	var fsm = null
	if Engine.has_singleton("FactionSystemManager"):
		fsm = Engine.get_singleton("FactionSystemManager")
	else:
		# 静态上下文无 Engine.get_singleton 时，走 autoload 节点路径（运行时有效）
		var tree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			fsm = tree.root.get_node_or_null("FactionSystemManager")
	if fsm == null:
		return
	var fid: String = ""
	if "active_faction" in fsm:
		fid = String(fsm.active_faction)
	elif fsm.has_method("get_active_faction"):
		fid = String(fsm.get_active_faction())
	var fam: String = CardPeriodicSkills.get_family_for_faction(fid)
	if not fam.is_empty():
		stats.set_meta("law_family", fam)


# ─────────────────────────────────────────────
#  v6.2 防御数值重新标定
# ─────────────────────────────────────────────

## v6.2: 按单位类型派生新的三维防御值（攻防维度对齐）
## 设计原则（defense_light=防轻装攻击者, defense_armor=防装甲攻击者, defense_air=防空中攻击者）：
##   轻装步兵：防轻装高（抗枪弹）／防装甲低（怕炮）／防空中低（怕飞机扫射）
##   火炮/辅助：防轻装中／防装甲低／防空中低（笨重装备，无掩体优势）
##   防空特化：防轻装中／防装甲低／防空中高（有装甲炮塔）
##   装甲坦克：防轻装极高（枪弹无效）／防装甲中高（同级对抗）／防空中中（对空一般）
##   空中单位：防轻装低（脆）／防装甲低（脆）／防空中中高（对空有防御）
##   堡垒：防轻装极高／防装甲极高／防空中高（全方位要塞化）
## 时代缩放：数值随时代递增（体现科技进步/装甲升级）
static func derive_defense_by_unit_type(combat_kind: int, unit_subtype: int, era: int) -> Dictionary:
	# 主类归属
	var is_light: bool = (combat_kind == GC.CombatKind.LIGHT or combat_kind == GC.CombatKind.SUPPORT)
	var is_armor: bool = (combat_kind == GC.CombatKind.ARMOR or combat_kind == GC.CombatKind.FORT)
	var is_air: bool = (combat_kind == GC.CombatKind.AIR)
	# 子类（兼容未设置 unit_subtype 的旧数据：combat_kind 推断）
	var sub: int = unit_subtype
	if sub == GC.UnitSubType.NONE:
		if combat_kind == GC.CombatKind.SUPPORT:
			# 进一步区分：原 SUPPORT 中 range≥99 多为火炮，但此处无 range 信息
			# 默认按 SUPPORT（辅助）处理；火炮与辅助数值接近，差异由 apply_combat_kind_modifiers 处理
			sub = GC.UnitSubType.SUPPORT
		elif combat_kind == GC.CombatKind.FORT:
			sub = GC.UnitSubType.FORT

	# 时代缩放系数（基础值 × 此系数）
	var e: int = clampi(era, 0, 4)
	var era_mul: float = 1.0 + e * 0.15  # WW1=1.0 .. 近未来=1.6

	# 基础数值表（WW1 基准，按主类×子类）
	var d_l: float = 0.0  # 防轻装
	var d_a: float = 0.0  # 防装甲
	var d_air: float = 0.0  # 防空中

	if is_armor:
		if sub == GC.UnitSubType.FORT:
			# 堡垒：全方位要塞化，防装甲最高（最抗重火力）
			d_l = 90.0
			d_a = 140.0
			d_air = 95.0
		else:
			# 普通装甲：枪弹无效，同级对抗中等，对空一般
			d_l = 60.0
			d_a = 90.0
			d_air = 28.0
	elif is_air:
		# 空中：脆（地面火力有效），但对空有防御
		d_l = 14.0
		d_a = 18.0
		d_air = 36.0
	else:
		# 轻装主类，按子类细分
		match sub:
			GC.UnitSubType.ARTILLERY:
				# 火炮：笨重，防轻装中等，怕重火力
				d_l = 24.0
				d_a = 16.0
				d_air = 14.0
			GC.UnitSubType.SUPPORT:
				# 辅助（机枪巢/工兵）：防轻装中等，怕重火力
				d_l = 26.0
				d_a = 18.0
				d_air = 16.0
			GC.UnitSubType.ANTI_AIR:
				# 防空特化：有装甲炮塔，对空防御较强
				d_l = 28.0
				d_a = 20.0
				d_air = 48.0
			_:
				# 普通轻装步兵：抗枪弹，怕炮，怕飞机
				d_l = 30.0
				d_a = 14.0
				d_air = 12.0

	return {
		"defense_light": d_l * era_mul,
		"defense_armor": d_a * era_mul,
		"defense_air": d_air * era_mul,
	}


# ─────────────────────────────────────────────
#  战斗定位成长倾斜
# ─────────────────────────────────────────────

## 按战斗定位的星级成长倾斜（每星叠一层，与 BlueprintManager.apply_growth_to_stats 配合）
static func get_combat_kind_growth_bias(kind: int) -> Dictionary:
	match kind:
		0:  # 轻装
			return {"hp_bias": 0.04, "dmg_bias": 0.05, "dodge_bias": 0.03}
		1:  # 装甲
			return {"hp_bias": 0.06, "def_bias": 0.04, "dmg_bias": 0.04}
		2:  # 支援
			return {"hp_bias": 0.05, "heal_bias": 0.08}
		3:  # 空中
			return {"hp_bias": 0.03, "dmg_bias": 0.06, "speed_bias": 0.05}
		4:  # 堡垒（v5.0）
			return {"hp_bias": 0.08, "def_bias": 0.06, "dmg_bias": 0.02}
		_:
			return {"hp_bias": 0.04, "dmg_bias": 0.04}




# ─────────────────────────────────────────────
#  PlatformType → combat_kind / 行为映射
# ─────────────────────────────────────────────

## PlatformType → combat_kind 映射（0=轻装, 1=装甲, 2=支援, 3=空中）
const PLATFORM_TO_COMBAT_KIND: Dictionary = {
	0: 0,    # HOUND → 轻装
	1: 1,    # GUARD → 装甲
	2: 1,    # TITAN → 装甲
	3: 2,    # FORTRESS → 支援
	4: 2,    # RADAR → 支援
	5: 0,    # SCOUT → 轻装
	6: 0,    # RAIDER → 轻装
	7: 2,    # SIEGE → 支援
	8: 3,    # CARRIER → 空中
	9: 2,    # MEDIC → 支援
	10: 0,   # STEALTH → 轻装
	11: 1,   # OMEGA_PLATFORM → 装甲
	12: 2,   # COMMAND → 支援
}

## PlatformType → 旧基础数据（HP, 速度, 是否固定）
const _PLATFORM_BASE: Dictionary = {
	0:  {"speed": 115.0, "hp": 65.0, "stationary": false},   # HOUND
	1:  {"speed": 75.0,  "hp": 110.0, "stationary": false},  # GUARD
	2:  {"speed": 40.0,  "hp": 200.0, "stationary": false},  # TITAN
	3:  {"speed": 0.0,   "hp": 260.0, "stationary": true},   # FORTRESS
	4:  {"speed": 0.0,   "hp": 180.0, "stationary": true},   # RADAR
	5:  {"speed": 135.0, "hp": 50.0,  "stationary": false},  # SCOUT
	6:  {"speed": 100.0, "hp": 90.0,  "stationary": false},  # RAIDER
	7:  {"speed": 0.0,   "hp": 300.0, "stationary": true},   # SIEGE
	8:  {"speed": 50.0,  "hp": 140.0, "stationary": false},  # CARRIER
	9:  {"speed": 75.0,  "hp": 80.0,  "stationary": false},  # MEDIC
	10: {"speed": 115.0, "hp": 50.0,  "stationary": false},  # STEALTH
	11: {"speed": 30.0,  "hp": 240.0, "stationary": false},  # OMEGA_PLATFORM
	12: {"speed": 0.0,   "hp": 150.0, "stationary": true},   # COMMAND
}

## 旧 WeaponType → 武器基础数据（damage, range, interval）
const _WEAPON_BASE: Dictionary = {
	0:  {"damage": 8.0,  "range": 95.0,  "interval": 0.38},   # SMG
	1:  {"damage": 14.0, "range": 155.0, "interval": 0.95},   # RIFLE
	2:  {"damage": 7.0,  "range": 160.0, "interval": 0.25},   # MG
	3:  {"damage": 30.0, "range": 195.0, "interval": 1.70},   # ROCKET
	4:  {"damage": 7.0,  "range": 85.0,  "interval": 0.45},   # PISTOL
	5:  {"damage": 22.0, "range": 60.0,  "interval": 0.85},   # SHOTGUN
	6:  {"damage": 28.0, "range": 240.0, "interval": 1.60},   # SNIPER
	7:  {"damage": 9.0,  "range": 125.0, "interval": 0.35},   # FLAK
	8:  {"damage": 13.0, "range": 185.0, "interval": 0.50},   # LASER
	9:  {"damage": 38.0, "range": 215.0, "interval": 2.00},   # MISSILE
	10: {"damage": 220.0,"range": 250.0, "interval": 2.20},   # OMEGA_CANNON
	11: {"damage": 140.0,"range": 240.0, "interval": 1.65},   # RAIL_CANNON
}

## 旧 PlatformType → 防御值
const _PLATFORM_DEFENSE: Dictionary = {
	0: 5,   # HOUND
	1: 9,   # GUARD
	2: 13,  # TITAN
	3: 20,  # FORTRESS
	4: 11,  # RADAR
	5: 4,   # SCOUT
	6: 7,   # RAIDER
	7: 14,  # SIEGE
	8: 8,   # CARRIER
	9: 6,   # MEDIC
	10: 5,  # STEALTH
	11: 15, # OMEGA_PLATFORM
	12: 10, # COMMAND
}



# ─────────────────────────────────────────────
#  旧接口兼容桥接
# ─────────────────────────────────────────────



## @deprecated 旧 build_multi_stats，内部已转为调用 build_stats_from_card
static func build_multi_stats(platform_type: int, weapon_types: Array, era: int = -1) -> UnitStats:
	var p: Dictionary = _PLATFORM_BASE.get(platform_type, {"speed": 80.0, "hp": 100.0, "stationary": false})
	# 取第一个武器做主武器
	var main_wt: int = int(weapon_types[0]) if weapon_types.size() > 0 else 1  # RIFLE=1
	var w: Dictionary = _WEAPON_BASE.get(main_wt, {"damage": 10.0, "range": 120.0, "interval": 1.0})

	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = era
	c.combat_kind = int(PLATFORM_TO_COMBAT_KIND.get(platform_type, 1))
	c.platform_type = platform_type
	c.legacy_weapon_type = main_wt
	c.weapon_type = main_wt
	c.base_hp = float(p.get("hp", 100.0))
	c.base_speed = float(p.get("speed", 80.0))
	c.range_value = max(1, int(round(float(w.get("range", 120.0)) / 100.0)))
	c.attack_speed = 1.0 / maxf(0.001, float(w.get("interval", 1.0)))
	var dmg: float = float(w.get("damage", 10.0))
	c.attack_light = dmg
	c.attack_armor = dmg * 0.8
	c.attack_air = dmg * 0.7
	var pd: float = float(_PLATFORM_DEFENSE.get(platform_type, 8))
	c.defense_light = pd
	c.defense_armor = pd * 1.2
	c.defense_air = pd * 0.6

	var stats := build_stats_from_card(c, era)
	stats.platform_type = platform_type

	# 多武器槽
	stats.weapons.clear()
	var max_range: float = 0.0
	for wt in weapon_types:
		var we: Dictionary = _WEAPON_BASE.get(int(wt), {"damage": 10.0, "range": 120.0, "interval": 1.0}).duplicate()
		var entry: Dictionary = {
			"weapon_type": int(wt),
			"damage": float(we.get("damage", 10.0)),
			"range": float(we.get("range", 120.0)),
			"interval": float(we.get("interval", 1.0)),
			"timer": 0.0,
		}
		stats.weapons.append(entry)
		if float(we.get("range", 0.0)) > max_range:
			max_range = float(we.get("range", 0.0))

	if stats.weapons.size() > 0:
		stats.attack_range = maxf(stats.attack_range, max_range)

	return stats


