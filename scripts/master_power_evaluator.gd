extends RefCounted
class_name MasterPowerEvaluator
## 相位师战斗力评估系统 v2
##
## 核心设计理念：
##   - 相位师没有"等级"概念，能力完全由相位仪 + 刻印 + 技能决定
##   - HP/攻击/防御/能量/单位上限 全部来自相位仪本身
##   - 不同能量场的关卡可刻录独特词条到相位仪上
##   - 刻印有进度（0.0~1.0），进度满=完整生效
##   - 我方和敌方共用同一套刻印与评估规则
##
## 评估维度（加权）：
##   A. 相位仪基础属性（15%） — 仪器的 HP/ATK/DEF/Energy/UnitLimit
##   B. 刻印词条（25%）       — 已刻录的进化词条（含进度）
##   C. 特质强度（10%）       — 相位师固有特质
##   D. 主动技能（15%）       — 爆发与实用技能
##   E. 被动技能（10%）       — 持续战斗优势
##   F. 装备槽位（25%）        — 平台/武器/能量卡种类
##
## 星级：1★~7★，纯由总分决定，无等级概念

# ─────────────────────────────────────────────
#  星级定义
# ─────────────────────────────────────────────

const STAR_TIERS: Array[Dictionary] = [
	{"stars": 1, "name": "新锐",   "min_score": 0,    "max_score": 250,   "color": "#88CCFF"},
	{"stars": 2, "name": "精英",   "min_score": 250,  "max_score": 600,   "color": "#44FF88"},
	{"stars": 3, "name": "高手",   "min_score": 600,  "max_score": 1200,  "color": "#FFCC00"},
	{"stars": 4, "name": "大师",   "min_score": 1200, "max_score": 2200,  "color": "#FF8800"},
	{"stars": 5, "name": "宗师",   "min_score": 2200, "max_score": 3800,  "color": "#FF4466"},
	{"stars": 6, "name": "传说",   "min_score": 3800, "max_score": 6000,  "color": "#CC44FF"},
	{"stars": 7, "name": "神话",   "min_score": 6000, "max_score": 99999, "color": "#FFD700"},
]

# ─────────────────────────────────────────────
#  维度权重
# ─────────────────────────────────────────────

const W_INSTRUMENT: float = 0.15   # 相位仪基础属性
const W_ENGRAVINGS: float = 0.25   # 刻印词条
const W_TRAITS: float = 0.10       # 特质
const W_ACTIVE_SPELLS: float = 0.15 # 主动技能
const W_PASSIVE_SPELLS: float = 0.10 # 被动技能
const W_EQUIPMENT_SLOTS: float = 0.25 # 装备槽位

# ─────────────────────────────────────────────
#  A. 相位仪属性评估参数
# ─────────────────────────────────────────────

## 各属性的参考基准值（取中位数仪器数据）
const REF_HP: float = 1200.0
const REF_ATTACK: float = 40.0
const REF_DEFENSE: float = 55.0
const REF_ENERGY_CAP: float = 200.0
const REF_ENERGY_REGEN: float = 2.2
const REF_UNIT_LIMIT: float = 7.0

## 属性内部权重
const SW_HP: float = 0.25
const SW_ATTACK: float = 0.25
const SW_DEFENSE: float = 0.20
const SW_ENERGY_CAP: float = 0.08
const SW_ENERGY_REGEN: float = 0.12
const SW_UNIT_LIMIT: float = 0.10

# ─────────────────────────────────────────────
#  B. 刻印评估 — 直接委托给 EnergyFieldEngravings
# ─────────────────────────────────────────────

# （刻印分值由 EnergyFieldEngravings.calc_engraving_power() 计算）

# ─────────────────────────────────────────────
#  C. 特质评估参数
# ─────────────────────────────────────────────

const TRAIT_EFFECT_WEIGHTS: Dictionary = {
	"defense_boost": 50.0, "attack_boost": 60.0, "attack_speed_boost": 55.0,
	"hp_boost": 45.0, "energy_regen_boost": 40.0, "move_speed_boost": 25.0,
	"crit_chance": 70.0,
	"fire_damage_boost": 65.0, "lightning_damage_boost": 65.0,
	"void_damage_boost": 65.0, "all_damage_boost": 80.0,
	"all_resistance_boost": 55.0, "enemy_defense_reduction": 70.0,
	"unit_limit_bonus": 100.0, "cooldown_reduction": 60.0,
	"energy_cost_reduction": 55.0, "deploy_speed_boost": 40.0,
	"energy_drain_on_hit": 45.0, "magic_power_boost": 50.0,
	"chain_bounce_bonus": 30.0, "burn_duration_bonus": 20.0,
	"damage_cap": 120.0, "unit_count_defense": 50.0,
	"deploy_shield": 80.0, "auto_spawn_interval": 100.0,
	"scaling_per_cast": 150.0,
	"auto_revive_once": 180.0, "full_resurrect_once": 200.0,
	"divine_transform": 160.0, "cheat_death_chance": 140.0,
	"global_dot": 90.0, "permanent_darkness": 100.0,
	"mass_convert_once": 200.0, "instant_delete": 220.0,
	"auto_thunder_dome": 130.0, "energy_full_auto_strike": 90.0,
	"boss_damage_boost": 40.0, "backstab_damage_boost": 50.0,
	"darkness_damage_boost": 50.0,
	"synergy_boost": 80.0, "synergy_types": 60.0, "armor_reflect": 50.0,
	"flame_trail": 30.0, "burn_energy_drain_mult": 40.0,
	"dual_damage_chance": 70.0, "time_scaling": 110.0,
	"fire_cooldown_reduction": 45.0,
}
const TRAIT_COUNT_BONUS: float = 80.0

# ─────────────────────────────────────────────
#  D. 主动技能评估参数
# ─────────────────────────────────────────────

const SPELL_EFFECT_BASE_VALUE: Dictionary = {
	"summon_units": 100, "damage_debuff": 120, "aoe_damage_over_time": 140,
	"death_explosion_buff": 110, "shield_base": 130, "summon_elites": 150,
	"chain_damage": 130, "single_damage_stun": 140, "speed_debuff": 100,
	"teleport_gates": 90, "mass_summon": 180, "mass_buff_shield": 160,
	"meteor_rain": 170, "mass_resurrect": 250, "lightning_storm": 180,
	"weapon_enchant": 120, "global_lightning": 170, "terrain_transform": 200,
	"massive_explosion": 200, "mass_shield": 130, "rapid_lightning": 190,
	"emp_stun": 160, "portal_summon": 180, "black_hole": 200,
	"thorn_armor_fire": 110, "hammer_smash": 130, "piercing_shots": 140,
	"permanent_structures": 180, "global_earthquake": 190,
	"summon_fire_giant": 220, "solar_flare": 230, "thunder_god_fury": 210,
	"electromagnetic_pulse": 180, "avatar_mode": 280, "ultimate_lightning": 250,
	"deploy_mechs": 150, "mass_repair": 140, "pyroblast": 160,
	"flame_wave": 140, "tornado_summon": 150, "wind_push": 130,
	"shadow_clones": 170, "darkness_debuff": 140, "divine_transformation": 260,
	"terrain_forge": 200, "hell_terrain": 280, "full_resurrect_all": 320,
	"god_weapon_attack": 300, "thunder_dome_shield": 220,
	"mass_conversion": 300, "instant_delete": 350,
	"perfect_fusion": 350, "combo_ultimate": 400,
	"em_fortress": 160, "lightning_buff": 130,
	"chaos_flame": 150, "burning_void_zone": 160,
	"chaos_zone": 170, "entropy_drain": 160,
}
const SPELL_DAMAGE_FACTOR: float = 0.05
const SPELL_DURATION_FACTOR: float = 15.0
const SPELL_COOLDOWN_EFFICIENCY: float = 8.0
const MAX_SPELL_SCORE: float = 600.0

# ─────────────────────────────────────────────
#  E. 被动技能评估参数
# ─────────────────────────────────────────────

const PASSIVE_EFFECT_WEIGHTS: Dictionary = {
	"armor_boost": 60.0, "death_shield": 90.0, "damage_aura": 80.0,
	"damage_boost_resistance": 85.0, "splash_damage": 55.0,
	"high_energy_bonus": 50.0, "formation_bonus": 70.0,
	"damage_vs_building": 60.0, "death_explosion": 90.0,
	"scaling_damage": 100.0, "chain_attack": 65.0,
	"full_energy_trigger": 80.0, "max_hp_drain": 75.0,
	"death_avoid_teleport": 110.0, "low_hp_defense_boost": 70.0,
	"auto_production": 100.0, "elemental_damage_boost": 75.0,
	"self_damage_aura": 80.0, "cooldown_reduction": 65.0,
	"life_energy_drain": 85.0, "armor_ignore_chance": 90.0,
	"energy_drain": 80.0, "speed_boost": 55.0,
	"death_chain_lightning": 85.0, "proc_explosion": 65.0,
	"lightning_thorn": 70.0, "high_energy_attack_speed": 55.0,
	"fire_lifesteal_chance": 80.0, "burn_slow": 45.0,
	"unbreakable": 130.0, "steel_mountain": 60.0,
	"phoenix_rebirth_auto": 200.0, "time_based_hp_drain": 120.0,
	"auto_lightning": 100.0, "global_damage_boost": 90.0,
	"void_mastery_ultimate": 110.0, "enemy_defense_reduction": 85.0,
	"synergy_boost": 75.0, "armor_chain_lightning": 70.0,
	"dual_element_boost": 90.0, "immunity": 100.0,
	"automation": 100.0, "time_based_upgrade": 120.0,
	"fire_mastery": 85.0, "ignite_chance": 60.0,
	"storm_speed": 65.0, "periodic_electric_shock": 70.0,
	"teleport_behind": 80.0, "execute_damage": 90.0,
	"cheat_death_chance": 150.0, "massive_heal_aura": 120.0,
	"auto_resurrect": 250.0, "god_mastery": 200.0,
	"energy_cost_reduction": 80.0, "goddess_mastery": 200.0,
	"permanent_darkness": 130.0, "omni_mastery": 180.0,
	"infinite_scaling": 200.0, "conductive_armor": 65.0, "overclock": 55.0,
}
const PASSIVE_COUNT_BONUS: float = 60.0

const HIGH_VALUE_PASSIVES: Array = [
	"phoenix_rebirth_auto", "auto_resurrect", "cheat_death_chance",
	"immunity", "goddess_mastery", "god_mastery", "omni_mastery",
	"infinite_scaling", "permanent_darkness", "unbreakable",
	"time_based_hp_drain", "massive_heal_aura", "auto_production",
	"time_based_upgrade",
]

# ─────────────────────────────────────────────
#  F. 装备槽位评估参数
# ─────────────────────────────────────────────

const PLATFORM_COUNT_BONUS: float = 60.0
const WEAPON_COUNT_BONUS: float = 50.0
const ENERGY_CARD_BONUS: float = 30.0

## 相位仪稀有度分值
const INSTRUMENT_RARITY_SCORE: Dictionary = {
	"common": 50, "uncommon": 120, "rare": 250, "epic": 450, "mythic": 800,
}

const EnergyFieldEngravings = preload("res://data/energy_field_engravings.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")


# ═════════════════════════════════════════════
#  主评估函数
# ═════════════════════════════════════════════

## 评估一个相位师的综合战力
## master 数据结构：
##   {
##     "id": String, "name": String, "faction": String,
##     "phase_instrument": String,     // 相位仪ID
##     "engraved_affixes": [{          // 已刻录词条列表
##       "engraving_id": String,
##       "progress": float,            // 0.0~1.0
##       "active": bool,               // 是否启用
##     }],
##     "traits": [...],                // 相位师固有特质
##     "active_spells": [...],         // 主动技能
##     "passive_spells": [...],        // 被动技能
##     "equipment": {                  // 装备
##       "platforms": [...], "weapons": [...], "energy_cards": [...]
##     }
##   }
static func evaluate(master: Dictionary) -> Dictionary:
	var scores: Dictionary = {}
	scores.instrument = _eval_instrument(master)
	scores.engravings = _eval_engravings(master)
	scores.traits = _eval_traits(master)
	scores.active_spells = _eval_active_spells(master)
	scores.passive_spells = _eval_passive_spells(master)
	scores.equipment_slots = _eval_equipment_slots(master)

	var total: float = (
		scores.instrument * W_INSTRUMENT +
		scores.engravings * W_ENGRAVINGS +
		scores.traits * W_TRAITS +
		scores.active_spells * W_ACTIVE_SPELLS +
		scores.passive_spells * W_PASSIVE_SPELLS +
		scores.equipment_slots * W_EQUIPMENT_SLOTS
	)

	var star_info: Dictionary = _score_to_stars(total)

	return {
		"total_score": total,
		"stars": star_info.stars,
		"star_name": star_info.name,
		"star_color": star_info.color,
		"scores": scores,
		"details": _build_details(master, scores, total, star_info),
	}


## 批量评估并返回排行榜（按战力降序）
## 最多返回 top_n 条
static func evaluate_ranking(masters: Array, top_n: int = 50) -> Array:
	var results: Array = []
	for m in masters:
		results.append(evaluate(m))
	results.sort_custom(func(a, b): return a.total_score > b.total_score)
	# 添加排名
	var ranked: Array = []
	for i in mini(results.size(), top_n):
		var r: Dictionary = results[i].duplicate()
		r["rank"] = i + 1
		r["master_name"] = r.details.get("master_name", "?")
		r["faction"] = r.details.get("faction", "")
		ranked.append(r)
	return ranked


## 仅获取星级
static func get_stars(master: Dictionary) -> int:
	return evaluate(master).stars


## 获取星级显示文本 "4★ 大师"
static func get_stars_display(master: Dictionary) -> String:
	var r = evaluate(master)
	return "%d★ %s" % [r.stars, r.star_name]


# ═════════════════════════════════════════════
#  A. 相位仪基础属性评估
# ═════════════════════════════════════════════

static func _eval_instrument(master: Dictionary) -> float:
	var instr_id: String = master.get("phase_instrument", "")
	if instr_id.is_empty():
		return 0.0

	var instr_data: Dictionary = _get_instrument_data(instr_id)
	if instr_data.is_empty():
		return 0.0

	var bs: Dictionary = instr_data.get("base_stats", {})
	var hp: float = float(bs.get("max_hp", 0))
	var atk: float = float(bs.get("attack_power", 0)) + float(bs.get("magic_power", 0))
	var def_f: float = float(bs.get("defense", 0))
	var ecap: float = float(bs.get("energy_capacity", 0))
	var ereg: float = float(bs.get("energy_regen", 0))
	var ulim: float = float(master.get("unit_limit", 0))
	# unit_limit 可能在 master 或 stats 子级中
	if ulim <= 0:
		ulim = float(master.get("stats", {}).get("unit_limit", 7))

	# 标准化并加权
	var score: float = 0.0
	score += (hp / REF_HP) * 500.0 * SW_HP
	score += (atk / REF_ATTACK) * 500.0 * SW_ATTACK
	score += (def_f / REF_DEFENSE) * 500.0 * SW_DEFENSE
	score += (ecap / REF_ENERGY_CAP) * 500.0 * SW_ENERGY_CAP
	score += (ereg / REF_ENERGY_REGEN) * 500.0 * SW_ENERGY_REGEN
	score += (ulim / REF_UNIT_LIMIT) * 500.0 * SW_UNIT_LIMIT

	# 非线性加成
	if hp > 2500:
		score += (hp - 2500) * 0.04
	if ulim > 9:
		score += (ulim - 9) * 80.0
	if ecap > 400:
		score += (ecap - 400) * 0.15
	if ereg > 4.0:
		score += (ereg - 4.0) * 20.0

	# 稀有度加成
	var rarity: String = instr_data.get("rarity", "common")
	score += INSTRUMENT_RARITY_SCORE.get(rarity, 50)

	# 特殊效果数量
	var effects: Array = instr_data.get("special_effects", [])
	score += effects.size() * 35.0

	return score


# ═════════════════════════════════════════════
#  B. 刻印词条评估
# ═════════════════════════════════════════════

static func _eval_engravings(master: Dictionary) -> float:
	var affixes: Array = master.get("engraved_affixes", [])
	if affixes.is_empty():
		return 0.0

	var EFE = EnergyFieldEngravings
	var total: float = 0.0

	for affix in affixes:
		if not affix.get("active", true):
			continue
		var eid: String = affix.get("engraving_id", "")
		var progress: float = float(affix.get("progress", 0.0))
		total += EFE.calc_engraving_power(eid, progress)

	# 刻印数量加成（越多越强，但递减）
	var active_count: int = 0
	for affix in affixes:
		if affix.get("active", true) and float(affix.get("progress", 0)) > 0:
			active_count += 1
	total += active_count * 25.0

	return total


# ═════════════════════════════════════════════
#  C. 特质评估
# ═════════════════════════════════════════════

static func _eval_traits(master: Dictionary) -> float:
	var traits: Array = master.get("traits", [])
	if traits.is_empty():
		return 0.0
	var score: float = 0.0
	for trait in traits:
		var effects: Dictionary = trait.get("effects", {})
		for effect_key in effects:
			var weight: float = TRAIT_EFFECT_WEIGHTS.get(effect_key, 30.0)
			var value = effects[effect_key]
			if value is float or value is int:
				score += weight * float(value)
			elif value is Dictionary:
				score += weight * 1.5
			elif value is bool:
				if value:
					score += weight
	score += traits.size() * TRAIT_COUNT_BONUS
	return score


# ═════════════════════════════════════════════
#  D. 主动技能评估
# ═════════════════════════════════════════════

static func _eval_active_spells(master: Dictionary) -> float:
	var spells: Array = master.get("active_spells", [])
	if spells.is_empty():
		return 0.0
	var score: float = 0.0
	for spell in spells:
		var etype: String = spell.get("effect", "")
		var params: Dictionary = spell.get("params", {})
		var cd: float = float(spell.get("cooldown", 10.0))
		var mana: float = float(spell.get("mana_cost", 100))
		var base_val: float = SPELL_EFFECT_BASE_VALUE.get(etype, 80.0)
		var ss: float = base_val
		# 伤害
		if params.has("damage"):
			ss += float(params["damage"]) * SPELL_DAMAGE_FACTOR
		if params.has("strike_count"):
			ss += float(params["strike_count"]) * 25.0
		if params.has("count"):
			ss += float(params["count"]) * 20.0
		if params.has("elite_count"):
			ss += float(params["elite_count"]) * 30.0
		if params.has("normal_count"):
			ss += float(params["normal_count"]) * 8.0
		if params.has("behemoth_count"):
			ss += float(params["behemoth_count"]) * 50.0
		if params.has("shield_amount"):
			ss += float(params["shield_amount"]) * 0.1
		# 持续时间
		if params.has("duration"):
			ss += float(params["duration"]) * SPELL_DURATION_FACTOR
		# 冷却效率
		if cd > 0:
			ss += (ss / cd) * SPELL_COOLDOWN_EFFICIENCY
		# 法力效率
		if mana > 0:
			ss += (ss / (mana / 100.0)) * 2.0
		ss = minf(ss, MAX_SPELL_SCORE)
		score += ss
	return score


# ═════════════════════════════════════════════
#  E. 被动技能评估
# ═════════════════════════════════════════════

static func _eval_passive_spells(master: Dictionary) -> float:
	var spells: Array = master.get("passive_spells", [])
	if spells.is_empty():
		return 0.0
	var score: float = 0.0
	for spell in spells:
		var etype: String = spell.get("effect", "")
		var params: Dictionary = spell.get("params", {})
		var base_w: float = PASSIVE_EFFECT_WEIGHTS.get(etype, 50.0)
		var ss: float = base_w
		for pk in params:
			var val = params[pk]
			if val is float or val is int:
				ss += float(val) * 5.0
		if HIGH_VALUE_PASSIVES.has(etype):
			ss += 100.0
		score += ss
	score += spells.size() * PASSIVE_COUNT_BONUS
	return score


# ═════════════════════════════════════════════
#  F. 装备槽位评估
# ═════════════════════════════════════════════

static func _eval_equipment_slots(master: Dictionary) -> float:
	var equip: Dictionary = master.get("equipment", {})
	var platforms: Array = equip.get("platforms", [])
	var weapons: Array = equip.get("weapons", [])
	var energy_cards: Array = equip.get("energy_cards", [])
	return (
		platforms.size() * PLATFORM_COUNT_BONUS +
		weapons.size() * WEAPON_COUNT_BONUS +
		energy_cards.size() * ENERGY_CARD_BONUS
	)


# ═════════════════════════════════════════════
#  辅助
# ═════════════════════════════════════════════

static func _get_instrument_data(instrument_id: String) -> Dictionary:
	var EPE = EnemyPhaseEquipment
	return EPE.get_phase_instrument(instrument_id)


static func _score_to_stars(score: float) -> Dictionary:
	for tier in STAR_TIERS:
		if score >= tier.min_score and score < tier.max_score:
			return tier
	return STAR_TIERS[STAR_TIERS.size() - 1]


static func _build_details(master: Dictionary, scores: Dictionary,
		total: float, star_info: Dictionary) -> Dictionary:
	# 从相位仪读取实际属性
	var instr_id: String = master.get("phase_instrument", "")
	var instr_data: Dictionary = _get_instrument_data(instr_id)
	var bs: Dictionary = instr_data.get("base_stats", {})
	var max_hp: int = int(bs.get("max_hp", 0))
	var atk: int = int(bs.get("attack_power", 0)) + int(bs.get("magic_power", 0))
	var defense: int = int(bs.get("defense", 0))
	var ecap: int = int(bs.get("energy_capacity", 0))
	var ereg: float = float(bs.get("energy_regen", 0))
	var ulim: int = int(master.get("unit_limit", 0))
	if ulim <= 0:
		ulim = int(master.get("stats", {}).get("unit_limit", 7))

	# 刻印数
	var engraving_list: Array = master.get("engraved_affixes", [])
	var active_engravings: int = 0
	var completed_engravings: int = 0
	for a in engraving_list:
		if a.get("active", true):
			active_engravings += 1
			if float(a.get("progress", 0)) >= 1.0:
				completed_engravings += 1

	return {
		"master_name": master.get("name", "?"),
		"title": master.get("title", ""),
		"faction": master.get("faction", ""),
		"phase_instrument": instr_data.get("name", instr_id),
		"instrument_rarity": instr_data.get("rarity", ""),
		# 来自相位仪的属性
		"hp": max_hp, "attack": atk, "defense": defense,
		"energy_capacity": ecap, "energy_regen": ereg, "unit_limit": ulim,
		# 刻印信息
		"active_engravings": active_engravings,
		"completed_engravings": completed_engravings,
		"total_engravings": engraving_list.size(),
		# 各维度分数
		"instrument_score": roundf(scores.instrument),
		"engravings_score": roundf(scores.engravings),
		"traits_score": roundf(scores.traits),
		"active_spells_score": roundf(scores.active_spells),
		"passive_spells_score": roundf(scores.passive_spells),
		"equipment_slots_score": roundf(scores.equipment_slots),
	}


# ═════════════════════════════════════════════
#  排行榜打印
# ═════════════════════════════════════════════

## 打印排行榜（调试用）
static func print_ranking(ranking: Array) -> void:
	print("\n╔══════════════════════════════════════════════════════════════════════╗")
	print("║                    相位师战力排行榜 TOP %d                       ║" % ranking.size())
	print("╠══════════════════════════════════════════════════════════════════════╣")
	print("║ 排名  星级   战力     势力    相位师                        刻印  ║")
	print("╠══════════════════════════════════════════════════════════════════════╣")
	for r in ranking:
		var d: Dictionary = r.details
		var rank_str: String = "%2d" % r.rank
		var star_str: String = "%d★%-4s" % [r.stars, r.star_name]
		var score_str: String = "%7.0f" % r.total_score
		var faction_str: String = "%-8s" % _faction_short(d.faction)
		var name_str: String = "%-28s" % d.master_name.substr(0, 28)
		var eng_str: String = "%d/%d" % [d.completed_engravings, d.active_engravings]
		print("║ %s  %s  %s  %s  %s  %s ║" % [
			rank_str, star_str, score_str, faction_str, name_str, eng_str])
	print("╚══════════════════════════════════════════════════════════════════════╝\n")


## 势力简称映射
static func _faction_short(faction: String) -> String:
	var map: Dictionary = {
		"steel": "钢铁", "flame": "烈焰", "thunder": "雷霆", "void": "虚空",
		"steel_flame": "钢炎", "thunder_steel": "雷钢", "void_flame": "虚炎",
		"steel_thunder": "钢雷", "flame_void": "炎虚", "all": "全能",
	}
	return map.get(faction, faction)


## 打印单个相位师详细评估
static func print_detail(master: Dictionary) -> void:
	var r: Dictionary = evaluate(master)
	var d: Dictionary = r.details
	print("\n═══ %s 「%s」═══" % [d.master_name, d.title])
	print("  势力: %s  |  相位仪: %s [%s]" % [
		_faction_short(d.faction), d.phase_instrument, d.instrument_rarity])
	print("  HP: %d  |  ATK: %d  |  DEF: %d  |  EN: %d(+%.1f/s)  |  单位上限: %d" % [
		d.hp, d.attack, d.defense, d.energy_capacity, d.energy_regen, d.unit_limit])
	print("  刻印: %d激活 / %d完成 / %d总计" % [
		d.active_engravings, d.completed_engravings, d.total_engravings])
	print("  ─────────────────────────────────")
	print("  仪器基础属性:  %6.0f" % d.instrument_score)
	print("  刻印词条:      %6.0f" % d.engravings_score)
	print("  特质:          %6.0f" % d.traits_score)
	print("  主动技能:      %6.0f" % d.active_spells_score)
	print("  被动技能:      %6.0f" % d.passive_spells_score)
	print("  装备槽位:      %6.0f" % d.equipment_slots_score)
	print("  ─────────────────────────────────")
	print("  ★★★ 总战力: %.0f  |  %d★ %s ★★★" % [r.total_score, r.stars, r.star_name])
	print()
