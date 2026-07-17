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
##   B. 刻印词条（15%）       — 已刻录的进化词条（含进度）
##   C. 特质强度（10%）       — 相位师固有特质
##   D. 主动技能（10%）       — 爆发与实用技能
##   E. 被动技能（10%）       — 持续战斗优势
##   F. 载卡战力（20%）        — 相位仪里装的平台卡战力（敌方=平台卡×unit_limit；玩家=卡战力×3）
##   G. 军团本体战力（15%）    — master.stats（敌方相位师本体 HP/ATK/DEF/Regen/UnitLimit）
##   H. 单符文战力（6%）        — 装备的符文（稀有度基础分 + primary/secondary effect）
##   I. 符文之语战力（6%）      — 激活的符文之语（按 TIER 加权 + effects 求和）
##      v7.x 第二轮重构：把"相位师总战力"对齐为用户设想的 4 分量（卡+相位仪+符文+载卡）。
##      第三轮：把原合并 H 维（符文+符文之语）拆成 H（单符文）+ I（符文之语）两个独立维，
##      符文和符文之语在评分表里各自有分，分别计权重。
##
## 星级：1★~7★，纯由总分决定，无等级概念

# ─────────────────────────────────────────────
#  星级定义
# ─────────────────────────────────────────────

const STAR_TIERS: Array[Dictionary] = [
	{"stars": 1, "name": "新锐",   "min_score": 0,     "max_score": 300,    "color": "#88CCFF"},
	{"stars": 2, "name": "精英",   "min_score": 300,   "max_score": 1500,   "color": "#44FF88"},
	{"stars": 3, "name": "高手",   "min_score": 1500,  "max_score": 4000,   "color": "#FFCC00"},
	{"stars": 4, "name": "大师",   "min_score": 4000,  "max_score": 8000,   "color": "#FF8800"},
	{"stars": 5, "name": "宗师",   "min_score": 8000,  "max_score": 20000,  "color": "#FF4466"},
	{"stars": 6, "name": "传说",   "min_score": 20000, "max_score": 40000,  "color": "#CC44FF"},
	{"stars": 7, "name": "神话",   "min_score": 40000, "max_score": 9999999,"color": "#FFD700"},
]
## v7.x 3 分量公式校准说明（敌我同口径：相位仪 + Σ卡战力 + Σ符文，直接相加）：
## 敌方分布：WW1师~1800(3★) / WW2师~3800(4★) / Cold师~5700(4★) / Modern师~7600(4★) / Future师~9200(5★)
## 玩家分布：新手~50(1★) / 中配~4100(4★) / 满配~55000(7★)
## 阈值按合并分布标定，让敌我星级可直接横向对比。

# ─────────────────────────────────────────────
#  维度权重（v7.x 对称化最终版：删 D维技能 / I维符文之语 单独计分）
#  用户决策：相位仪技能价值体现在相位仪战力内，符文之语价值体现在符文战力内。
#  总战力 = F维(卡真实战力) + A维(相位仪加成战力) + H维(符文固定值) + G维(本体) + 辅助维
# ─────────────────────────────────────────────

const W_INSTRUMENT: float = 0.15   # A 维：相位仪（含其给卡的加成战力）
const W_ENGRAVINGS: float = 0.05   # B 维：刻印（保留，权重降低）
const W_TRAITS: float = 0.10       # C 维：特质
const W_ACTIVE_SPELLS: float = 0.0  # D 维：已删（技能价值在 A 维内）
const W_PASSIVE_SPELLS: float = 0.10 # E 维：被动技能
const W_EQUIPMENT_SLOTS: float = 0.35 # F 维：载卡战力（真实 combat_power，主导项）
const W_MASTER_STATS: float = 0.15 # G 维：军团本体战力
const W_RUNES: float = 0.10        # H 维：符文固定值（按稀有度）
const W_RUNEWORDS: float = 0.0     # I 维：已删（符文之语价值在 H 维内）
# 权重总和 = 0.15+0.05+0.10+0+0.10+0.35+0.15+0.10+0 = 1.00 ✓

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
	"phoenix_rebirth_auto": 180.0, "time_based_hp_drain": 110.0,  # v7.x: 200→180
	"auto_lightning": 100.0, "global_damage_boost": 90.0,
	"void_mastery_ultimate": 110.0, "enemy_defense_reduction": 85.0,
	"synergy_boost": 75.0, "armor_chain_lightning": 70.0,
	"dual_element_boost": 90.0, "immunity": 90.0,  # v7.x: 100→90
	"automation": 100.0, "time_based_upgrade": 110.0,  # v7.x: 120→110
	"fire_mastery": 85.0, "ignite_chance": 60.0,
	"storm_speed": 65.0, "periodic_electric_shock": 70.0,
	"teleport_behind": 80.0, "execute_damage": 90.0,
	"cheat_death_chance": 130.0, "massive_heal_aura": 110.0,  # v7.x: 150→130, 120→110
	"auto_resurrect": 200.0, "god_mastery": 170.0,  # v7.x: 250→200, 200→170
	"energy_cost_reduction": 80.0, "goddess_mastery": 170.0,  # v7.x: 200→170
	"permanent_darkness": 110.0, "omni_mastery": 150.0,  # v7.x: 130→110, 180→150
	"infinite_scaling": 170.0, "conductive_armor": 65.0, "overclock": 55.0,  # v7.x: 200→170
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
# v7.x 平衡修订：补 legendary 条目（原缺，legendary 相位仪走 fallback 得错误分）
const INSTRUMENT_RARITY_SCORE: Dictionary = {
	"common": 50, "uncommon": 120, "rare": 250, "epic": 450, "legendary": 600, "mythic": 800,
}

# ─────────────────────────────────────────────
#  G. 军团本体战力评估参数（v7.x 新增）
#     读 master.stats：max_hp/attack_power/defense/energy_regen/unit_limit
#     （敌方相位师顶层字段；我方相位师无此字段 → G 维回退 0）
# ─────────────────────────────────────────────

## 各属性参考基准值（取 30 条相位师 stats 的中位数附近，使中等相位师 G 维≈500）
const MASTER_REF_HP: float = 3000.0          # 一战1100→近未来10000，中位~3000
const MASTER_REF_ATTACK: float = 400.0       # 120→1000，中位~400
const MASTER_REF_DEFENSE: float = 100.0      # 45→230，中位~100
const MASTER_REF_ENERGY_REGEN: float = 3.5   # 2.0→8.0，中位~3.5
const MASTER_REF_UNIT_LIMIT: float = 8.0     # 5→15，中位~8

## 属性内部权重：HP/ATK 最高（时代区分度最强 9×/8×），DEF/EREG/ULIM 次之
const MSW_HP: float = 0.30
const MSW_ATTACK: float = 0.30
const MSW_DEFENSE: float = 0.15
const MSW_ENERGY_REGEN: float = 0.10
const MSW_UNIT_LIMIT: float = 0.15

const EnergyFieldEngravings = preload("res://data/energy_field_engravings.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const RuneDefinitions = preload("res://data/runes.gd")
const RunewordDefinitions = preload("res://data/runewords.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")


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
	# v7.x 统一公式（敌我同口径，直接相加，无加权系数）：
	#   相位师总战力 = 相位仪战力(A) + Σ装备卡战力(F) + Σ符文战力(H)
	# 玩家侧：assembler 在 evaluate_player_stars 里重写 A/F 用 get_current_power()，
	#         此函数算出的是敌方口径；玩家口径见 master_player_assembler.gd。
	# 删掉的旧维度（B刻印/C特质/D技能/E被动/G军团本体/I符文之语）：
	#   - 玩家侧本就为 0 或兜底，删除不损失
	#   - 敌方侧这些维度稀释了真实战力（玩家看到总战力远小于卡战力之和）
	var scores: Dictionary = {}
	scores.instrument = _eval_instrument(master)          # A 相位仪战力
	scores.equipment_slots = _eval_equipment_slots(master) # F 装备卡战力（直接相加）
	scores.runes = _eval_runes(master)                     # H 符文战力（固定值求和）

	# 3 分量直接相加（无权重系数）
	var total: float = scores.instrument + scores.equipment_slots + scores.runes

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
	# v7.x 统一公式：相位仪战力 = 仪器给所有装备卡的加成战力。
	# 玩家侧：assembler 在 _player_inst_bonus_total 预算「加成后战力 - 加成前战力」之和，优先读。
	# 敌方侧：从 phase_instrument 的 atk_bonus/hp_bonus/def_bonus 派生（仪器给产兵的加成）。
	# 路径修复：旧版读 master.phase_instrument（顶层，敌方恒空→A=0），现回退读 equipment.phase_instrument。
	var player_bonus: float = float(master.get("_player_inst_bonus_total", 0.0))
	if master.has("_player_inst_bonus_total"):
		return player_bonus

	var instr_id: String = String(master.get("phase_instrument", ""))
	if instr_id.is_empty():
		# 回退：敌方相位仪 id 存在 equipment.phase_instrument（旧版路径 bug 导致所有敌方 A=0）
		var equip: Dictionary = master.get("equipment", {})
		instr_id = String(equip.get("phase_instrument", ""))
	if instr_id.is_empty():
		return 0.0

	var instr_data: Dictionary = _get_instrument_data(instr_id)
	if instr_data.is_empty():
		return 0.0

	# v7.x: 统一池无 atk_bonus/hp_bonus/def_bonus（选 B：properties 按 star 重算）。
	# 评分基于 star（确定性梯度）+ active_ability 加成。量级与原公式相近（star3~360 / star7~1960+）。
	var star: int = int(instr_data.get("star", 1))
	var bonus_sum: float = float(star * star)   # star3=9 / star5=25 / star6=36 / star7=49
	var ab: Dictionary = instr_data.get("active_ability", {})
	if not ab.is_empty():
		bonus_sum += 15.0   # 有主动能力的相位仪额外加分
	var card_count: int = 2  # 敌方标准 2 张装备卡
	var base_card_power: float = 200.0  # 敌方产兵卡平均 power
	# 加成战力 = bonus_sum × base_card_power × card_count × 0.1
	return bonus_sum * base_card_power * card_count * 0.1


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
	for t_def in traits:
		var effects: Dictionary = t_def.get("effects", {})
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
	var high_value_count: int = 0  # v7.x: 高收益被动计数（用于组合惩罚）
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
			high_value_count += 1
		score += ss
	score += spells.size() * PASSIVE_COUNT_BONUS
	# v7.x: 高收益被动组合惩罚（超过2个高收益被动时，每多一个扣40分）
	# 防止复活+无敌+无限成长等组合导致战力虚高
	if high_value_count > 2:
		score -= (high_value_count - 2) * 40.0
	return maxf(0.0, score)


# ═════════════════════════════════════════════
#  F. 装备槽位评估
# ═════════════════════════════════════════════

static func _eval_equipment_slots(master: Dictionary) -> float:
	# v7.x 统一公式：装备卡战力 = 每张卡的 power 直接相加（不×3、不×unit_limit、无权重）。
	# 玩家侧：assembler 在 _player_platform_powers 预算每张卡 get_current_power()，优先读。
	# 敌方侧：platforms 是 archetype id，从 UnifiedCardTable.get_entry(id).power 取真实卡 power。
	# 删掉的旧逻辑：_platform_power_light（读 get_war_platform 恒返回空→fallback 300，已废）。
	var player_powers: Array = master.get("_player_platform_powers", [])
	if not player_powers.is_empty():
		var psum: float = 0.0
		for p in player_powers:
			psum += float(p)
		return psum

	var equip: Dictionary = master.get("equipment", {})
	var platforms: Array = equip.get("platforms", [])
	if platforms.is_empty():
		return 0.0
	var UCT = preload("res://data/unified_card_table.gd")
	var card_power_sum: float = 0.0
	for pid_var in platforms:
		var pid: String = String(pid_var)
		if pid.is_empty():
			continue
		var entry: Dictionary = UCT.get_entry(pid)
		if entry.is_empty():
			card_power_sum += 100.0  # 查不到给基础分（兜底，不崩）
			continue
		card_power_sum += float(entry.get("power", 100))
	return card_power_sum


# ═════════════════════════════════════════════
#  G. 军团本体战力评估（v7.x 新增）
#     读 master.stats 五项，复用 A 维的"标准化×500×内部权重 + 非线性加成"模式。
#     我方相位师无 master.stats 字段时返回 0（行为零变化）。
# ═════════════════════════════════════════════

static func _eval_master_stats(master: Dictionary) -> float:
	var stats: Dictionary = master.get("stats", {})
	if stats.is_empty():
		# 兼容：少数数据可能把属性放在顶层（unit_limit 已在 A 维兜底），无则返回 0
		return 0.0
	var hp: float = float(stats.get("max_hp", 0))
	var atk: float = float(stats.get("attack_power", 0))
	var def_f: float = float(stats.get("defense", 0))
	var ereg: float = float(stats.get("energy_regen", 0))
	var ulim: float = float(stats.get("unit_limit", 0))

	var score: float = 0.0
	score += (hp / MASTER_REF_HP) * 500.0 * MSW_HP
	score += (atk / MASTER_REF_ATTACK) * 500.0 * MSW_ATTACK
	score += (def_f / MASTER_REF_DEFENSE) * 500.0 * MSW_DEFENSE
	score += (ereg / MASTER_REF_ENERGY_REGEN) * 500.0 * MSW_ENERGY_REGEN
	score += (ulim / MASTER_REF_UNIT_LIMIT) * 500.0 * MSW_UNIT_LIMIT

	# 非线性加成：极高属性额外加分（一战→近未来拉开差距）
	if hp > 5000.0:
		score += (hp - 5000.0) * 0.03
	if atk > 600.0:
		score += (atk - 600.0) * 0.20
	if ulim > 10.0:
		score += (ulim - 10.0) * 60.0

	return score


# ═════════════════════════════════════════════
#  H. 符文 + 符文之语战力评估（v7.x 新增）
#     读 master.equipment.runes（ID数组）或顶层 runes。
#     单符文：primary_effect.value × RUNE_STAT_WEIGHT + 稀有度基础分。
#     符文之语：RunewordMatcher 查激活词，按 TIER 加权（T2×100/T3×200/T4×350/T5×600）
#              + 各 effect.value 求和 × RUNEWORD_EFFECT_WEIGHT。
#     敌方 _derive_runes 经 v7.x 改造后必然组成符文之语，故 H 维对敌方有效。
# ═════════════════════════════════════════════

## 符文之语 TIER 基础分（越高 TIER 加成越大）
const RUNEWORD_TIER_BASE: Dictionary = {
	2: 100.0,   # TIER_2
	3: 200.0,   # TIER_3
	4: 350.0,   # TIER_4
	5: 600.0,   # TIER_5
}
## 单符文属性 effect 权重（primary_effect.value 通常 0.05~0.20，×200=10~40/项，合理量级）
const RUNE_STAT_WEIGHT: float = 200.0
## 符文战力固定值（v7.x 对称化最终版：按稀有度固定，玩家可口算）
## 用户决策：符文基数要够大，让"6卡4符文"和"4卡6符文"都是顶级战力。
const RUNE_RARITY_POWER: Dictionary = {
	"common": 800.0, "rare": 1500.0, "epic": 3000.0, "legendary": 5000.0, "mythic": 7000.0,
}
## 符文之语 effect 权重（数值加成项 value 求和）—— I 维用（已删，保留常量兼容）
const RUNEWORD_EFFECT_WEIGHT: float = 150.0

## H 维：符文战力（v7.x 对称化最终版：按稀有度固定值，不再用公式推导）
## 每个符文按稀有度给固定战力分，玩家可直接口算。
## 符文之语的价值已包含在符文战力内（能凑符文之语说明符文搭配好）。
static func _eval_runes(master: Dictionary) -> float:
	# 符文ID列表：优先 equipment.runes（敌方 enriched），回退顶层 runes
	var equip: Dictionary = master.get("equipment", {})
	var rune_ids: Array = equip.get("runes", [])
	if rune_ids.is_empty():
		rune_ids = master.get("runes", [])
	if rune_ids.is_empty():
		return 0.0

	var score: float = 0.0
	for rid_var in rune_ids:
		var rid: String = String(rid_var)
		if rid.is_empty():
			continue
		var rd: Dictionary = RuneDefinitions.get_rune(rid)
		if rd.is_empty():
			score += 800.0  # 查不到按 common 兜底
			continue
		var rarity: String = String(rd.get("rarity", "common"))
		score += RUNE_RARITY_POWER.get(rarity, 800.0)
	return score


## I 维：符文之语战力（v7.x 新增，与 H 维单符文独立计分）。
## RunewordMatcher 查激活词，按 TIER 加权（T2×100/T3×200/T4×350/T5×600）
## + 各 effect.value 求和 × RUNEWORD_EFFECT_WEIGHT。clamp 600 上限防多词叠加爆分。
static func _eval_runewords(master: Dictionary) -> float:
	var equip: Dictionary = master.get("equipment", {})
	var rune_ids: Array = equip.get("runes", [])
	if rune_ids.is_empty():
		rune_ids = master.get("runes", [])
	if rune_ids.is_empty():
		return 0.0

	var slot_count: int = maxi(rune_ids.size(), 2)
	var active_words: Array[Dictionary] = RunewordMatcher.check_active_runewords(rune_ids, slot_count)
	if active_words.is_empty():
		return 0.0

	var score: float = 0.0
	for rw in active_words:
		var tier: int = int(rw.get("tier", 2))
		score += RUNEWORD_TIER_BASE.get(tier, 100.0)
		# 符文之语 effects 求和（数值加成项）
		for effect in rw.get("effects", []):
			if effect.has("value"):
				score += float(effect["value"]) * RUNEWORD_EFFECT_WEIGHT
	return minf(score, 600.0)


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
	# v7.x: 3 分量公式，scores 只有 instrument/equipment_slots/runes 三个键
	# 从相位仪读取实际属性
	var instr_id: String = String(master.get("phase_instrument", ""))
	if instr_id.is_empty():
		instr_id = String(master.get("equipment", {}).get("phase_instrument", ""))
	var instr_data: Dictionary = _get_instrument_data(instr_id)
	# v7.x: 统一池相位仪无 base_stats（玩家 schema）。展示属性改读 master.stats（相位师本体属性，真实）。
	var ms: Dictionary = master.get("stats", {})
	var max_hp: int = int(ms.get("max_hp", 0))
	var atk: int = int(ms.get("attack_power", 0))
	var defense: int = int(ms.get("defense", 0))
	var ecap: int = 0   # 统一池无 energy_capacity（相位仪能量由 star 决定）
	var ereg: float = float(ms.get("energy_regen", 0.0))
	var ulim: int = int(master.get("unit_limit", 0))
	if ulim <= 0:
		ulim = int(master.get("stats", {}).get("unit_limit", 7))

	# 装备卡信息
	var equip: Dictionary = master.get("equipment", {})
	var platforms: Array = equip.get("platforms", [])

	return {
		"master_name": master.get("name", "?"),
		"title": master.get("title", ""),
		"faction": master.get("faction", ""),
		"phase_instrument": instr_data.get("name", instr_id),
		"instrument_rarity": instr_data.get("rarity", ""),
		"hp": max_hp, "attack": atk, "defense": defense,
		"energy_capacity": ecap, "energy_regen": ereg, "unit_limit": ulim,
		"platform_count": platforms.size(),
		# 3 分量分数（v7.x 统一公式）
		"instrument_score": roundf(float(scores.get("instrument", 0.0))),
		"equipment_slots_score": roundf(float(scores.get("equipment_slots", 0.0))),
		"runes_score": roundf(float(scores.get("runes", 0.0))),
	}


# ═════════════════════════════════════════════
#  排行榜打印
# ═════════════════════════════════════════════

## 打印排行榜（调试用）— disabled in production
static func print_ranking(ranking: Array) -> void:
	push_warning("[MasterPowerEvaluator] print_ranking() is disabled in production")


## 势力简称映射
static func _faction_short(faction: String) -> String:
	var map: Dictionary = {
		"steel": "钢铁", "flame": "烈焰", "thunder": "雷霆", "void": "虚空",
		"steel_flame": "钢炎", "thunder_steel": "雷钢", "void_flame": "虚炎",
		"steel_thunder": "钢雷", "flame_void": "炎虚", "all": "全能",
	}
	return map.get(faction, faction)


## 打印单个相位师详细评估 — disabled in production
static func print_detail(master: Dictionary) -> void:
	push_warning("[MasterPowerEvaluator] print_detail() is disabled in production")
