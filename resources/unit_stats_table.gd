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
const BattleCardV3 = preload("res://data/battle_card_v3.gd")


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
	var lvl: int = int(card.enhance_level) if "enhance_level" in card else 0
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
			stats.hp_regen += extra_val
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
				{"ek": "shield_on_kill", "ev": 30.0},
				{"ek": "damage_reduction", "ev": 0.10},
			]
			_apply_ability_list(stats, defs, unlocks, lvl)
		2:  # 支援
			var defs: Array = [
				{"ek": "splash_damage", "ev": 0.10},
				{"ek": "hp_regen", "ev": 5.0},
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
				{"ek": "hp_regen", "ev": 3.0},
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
					stats.hp_regen += ev
				"chain_chance":
					stats.chain_chance = minf(0.60, stats.chain_chance + ev)
				"shield_on_kill":
					stats.shield_on_kill += ev


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
		"deploy_speed": stats.deploy_speed,
		"crit_chance": stats.crit_chance,
		"crit_damage_bonus": stats.crit_damage_bonus,
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
		# v6.9: move_speed 类改造重定向为部署延迟百分比（move_speed 种子值保留供写回，不被 effects 增量）
		"deploy_delay_bonus": stats.deploy_delay_bonus,
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
	stats.deploy_speed = int(result.get("deploy_speed", stats.deploy_speed))
	stats.crit_chance = float(result.get("crit_chance", stats.crit_chance))
	stats.crit_damage_bonus = float(result.get("crit_damage_bonus", stats.crit_damage_bonus))
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
	stats.splash_radius_bonus = float(result.get("splash_radius_bonus", stats.splash_radius_bonus))
	stats.single_target_penalty = float(result.get("single_target_penalty", stats.single_target_penalty))
	# v6.9: 部署延迟百分比加成写回（move_speed 类改造经 registry 重定向后落到此字段）
	stats.deploy_delay_bonus = float(result.get("deploy_delay_bonus", stats.deploy_delay_bonus))
	# v6.5→v6.6: 武器类改造改变武器型号，写入 legacy_weapon_type（不污染 weapon_type 弹道字段）
	# bullet 的 VFX/弹道 match 读 legacy_weapon_type，AI 曲射判断读 weapon_type
	if result.has("legacy_weapon_type"):
		stats.legacy_weapon_type = int(result["legacy_weapon_type"])
	# _special 里的效果暂不处理（如 smoke_ignore 等无直接stat对应）
	# 同步旧兼容字段
	stats.attack_damage = stats.attack_light


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
		"ally_river_bonus": "move_speed",
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


## 战斗定位固有修正（替代旧 apply_platform_innate_modifiers）
## v6.2: 防御维度与攻击维度对齐后，防御修正也改为对应维度
##       （装甲/堡垒擅长防装甲攻击 → defense_armor；空中擅长防空中攻击 → defense_air）
##       SUPPORT(2)/FORT(4) 旧值仍按其主类（LIGHT/ARMOR）处理，确保兼容未迁移数据。
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
		# 普通轻装步兵有闪避；火炮/重型支援无闪避（笨重装备）
		if sub != GC.UnitSubType.ARTILLERY:
			stats.dodge_chance = maxf(stats.dodge_chance, 0.18)
		if sub == GC.UnitSubType.SUPPORT:
			stats.max_hp *= 1.08  # 辅助单位（机枪巢/工兵）加HP
	elif is_armor:
		# 装甲擅长防装甲攻击
		stats.defense_armor += 4.0
		if sub == GC.UnitSubType.FORT:
			# 堡垒：极高HP + 额外防装甲 + 全向防御加成
			stats.defense_armor += 4.0
			stats.defense_light += 4.0
			stats.defense_air += 4.0
			stats.max_hp *= 1.15
	elif stats.combat_kind == 3:  # 空中：高机动，擅长防空中攻击
		stats.dodge_chance = maxf(stats.dodge_chance, 0.12)
		stats.defense_air += 2.0


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
#  辅助：射程/攻速描述
# ─────────────────────────────────────────────

static func _describe_weapon_range(range_px: float) -> String:
	if range_px < 95.0:
		return "短"
	if range_px < 135.0:
		return "中"
	if range_px < 175.0:
		return "长"
	if range_px < 225.0:
		return "远"
	return "极远"

static func _describe_attack_speed(interval_sec: float) -> String:
	if interval_sec <= 0.32:
		return "极快"
	if interval_sec <= 0.5:
		return "快"
	if interval_sec <= 0.95:
		return "中"
	if interval_sec <= 1.55:
		return "慢"
	return "极慢"

## 用于战斗单位卡文案
static func summarize_weapon_stats_from_card(card: CardResource, era_override: int = -1) -> String:
	var e: int = era_override if era_override >= 0 else card.era
	var atk_light: float = card.attack_light
	var atk_armor: float = card.attack_armor
	var atk_air: float = card.attack_air
	# v3：使用新字段
	var rng: float = float(card.range_value * 100.0)  # 格转像素
	var ivl: float = 1.0 / card.attack_speed if card.attack_speed > 0 else 1.0
	if e >= 0:
		var multiplier = BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
		atk_light *= multiplier
		atk_armor *= multiplier
		atk_air *= multiplier
		rng *= BattleCardV3.era_range_multiplier(clampi(e, 0, 4))
	var total_dmg = atk_light + atk_armor + atk_air
	return "伤害 %d｜射程 %s｜攻速 %s" % [int(round(total_dmg)), _describe_weapon_range(rng), _describe_attack_speed(ivl)]


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

## 旧 WeaponType → 防御值
const _WEAPON_DEFENSE: Dictionary = {
	1: 1,   # RIFLE
	5: 1,   # SHOTGUN
	8: 1,   # LASER
	2: 2,   # MG
	7: 2,   # FLAK
	3: 1,   # ROCKET
	9: 1,   # MISSILE
	10: 2,  # OMEGA_CANNON
	11: 2,  # RAIL_CANNON
}


# ─────────────────────────────────────────────
#  旧接口兼容桥接
# ─────────────────────────────────────────────

## 获取平台基础数据（旧接口兼容）
static func get_platform_base(pt: int) -> Dictionary:
	var d: Dictionary = _PLATFORM_BASE.get(pt, {})
	if d.is_empty():
		return {"speed": 80.0, "hp": 100.0, "stationary": false}
	return d.duplicate()


## 获取平台防御值（旧接口兼容）
static func get_platform_defense(pt: int) -> int:
	return int(_PLATFORM_DEFENSE.get(pt, 8))


## 获取武器防御值（旧接口兼容）
static func get_weapon_defense(wt: int) -> int:
	return int(_WEAPON_DEFENSE.get(wt, 0))


## 获取组合防御值（旧接口兼容）
static func get_combined_defense(platform_type: int, weapon_type: int) -> int:
	return get_platform_defense(platform_type) + get_weapon_defense(weapon_type)


## 获取武器基础数据（旧接口兼容）
static func get_weapon_base(wt: int, era: int = -1) -> Dictionary:
	var base: Dictionary = _WEAPON_BASE.get(wt, {"damage": 10.0, "range": 120.0, "interval": 1.0}).duplicate()
	if era < 0:
		return base
	var e: int = clampi(era, 0, 4)
	base["damage"] = float(base["damage"]) * BattleCardV3.era_damage_multiplier(e)
	base["range"] = float(base["range"]) * BattleCardV3.era_range_multiplier(e)
	return base


## 旧接口：武器统计摘要
static func summarize_weapon_stats_weapon_row(wt: int, era: int = -1) -> String:
	var w: Dictionary = get_weapon_base(wt, era)
	var dmg: int = int(round(float(w["damage"])))
	return "伤害 %d｜射程 %s｜攻速 %s" % [dmg, _describe_weapon_range(float(w["range"])), _describe_attack_speed(float(w["interval"]))]


## 从 PlatformType + WeaponType 构造临时 CardResource，再调用 build_stats_from_card
static func _make_compat_card(platform_type: int, weapon_type: int, era: int) -> CardResource:
	var p: Dictionary = _PLATFORM_BASE.get(platform_type, {"speed": 80.0, "hp": 100.0, "stationary": false})
	var w: Dictionary = _WEAPON_BASE.get(weapon_type, {"damage": 10.0, "range": 120.0, "interval": 1.0})
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = era
	c.combat_kind = int(PLATFORM_TO_COMBAT_KIND.get(platform_type, 1))
	c.platform_type = platform_type
	c.legacy_weapon_type = weapon_type
	c.weapon_type = weapon_type
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
	return c


## @deprecated 旧 build_stats(platform_type, weapon_type, era)，内部已转为调用 build_stats_from_card
static func build_stats(platform_type: int, weapon_type: int, era: int = -1) -> UnitStats:
	var card := _make_compat_card(platform_type, weapon_type, era)
	var stats := build_stats_from_card(card, era)
	stats.platform_type = platform_type
	return stats


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


## @deprecated 旧 get_platform_growth_bias，映射到新 get_combat_kind_growth_bias
static func get_platform_growth_bias(pt: int) -> Dictionary:
	var kind: int = int(PLATFORM_TO_COMBAT_KIND.get(pt, 0))
	return get_combat_kind_growth_bias(kind)
