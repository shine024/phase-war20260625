extends RefCounted
class_name CardPeriodicSkills

const GC = preload("res://resources/game_constants.gd")
const AuraData = preload("res://data/aura_data.gd")

## ═══════════════════════════════════════════════════════════
##  v8.x 卡片定时技能定义（20 个）
##
##  特定平台卡部署后，按固定周期自动施放的技能。
##  触发条件：场上存在 source_tag 标签的友军单位（最少 min_source_count 个）。
##  完全自动，无需玩家操作。
##
##  由 CardPeriodicSkillEngine（新引擎，复用 PhaseInstrumentAbilities 模式）驱动。
##  技能树通过 unlocks: [{type: "card_skill", id: "..."}] 解锁。
##
##  effect.type 取值：
##    area_damage              → 对敌方密集区范围伤害（复用 artillery_barrage VFX）
##    single_target_damage     → 对单个最高威胁/HP 敌方伤害
##    global_damage            → 全图伤害（复用 nuclear_bombardment VFX）
##    debuff_target            → 对目标施加 debuff（mark/slow/armor_break）
##    debuff_area              → 对区域施加 debuff（slow_aura/minefield）
##    debuff_global            → 全图 debuff
##    buff_allies              → 全体友军 stat_bonus（护盾/治疗/净化/加速）
##    buff_single_ally         → 单个友军强化
##    summon_temp_unit         → 召唤临时单位
##    execute                  → 斩杀低 HP 敌方
##
##  family 字段：steel/flame/thunder/void，供 TacticDetector 战法条件查询
##  is_ultimate：是否为终极技能（影响 tactic_ragnarok 条件）
## ═══════════════════════════════════════════════════════════

## 20 个卡片定时技能
const SKILLS: Dictionary = {
	# ═══════════ 钢铁家族（5 个）═══════════
	"cps_artillery_coord": {
		"id": "cps_artillery_coord", "name": "炮兵协调射击",
		"family": "steel", "is_ultimate": false,
		"trigger": "periodic", "interval": 15.0,
		"source_tag": "artillery", "min_source_count": 1,
		"effect": {
			"type": "area_damage",
			"target": "enemy_densest_cluster",
			"radius": 120, "damage_pct_atk": 1.5,
			"vfx": "artillery_barrage"
		}
	},
	"cps_steel_bulwark": {
		"id": "cps_steel_bulwark", "name": "钢铁壁垒",
		"family": "steel", "is_ultimate": false,
		"trigger": "periodic", "interval": 20.0,
		"source_tag": "fort", "min_source_count": 1,
		"effect": {
			"type": "buff_allies", "target": "fort_kind",
			"shield": 2000, "shield_duration": 10.0,
			"stat_bonus": {"damage_reduction": 0.10},
			"stat_bonus_duration": 10.0
		}
	},
	"cps_minefield": {
		"id": "cps_minefield", "name": "反坦克雷区",
		"family": "steel", "is_ultimate": false,
		"trigger": "periodic", "interval": 18.0,
		"source_tag": "engineer", "min_source_count": 1,
		"effect": {
			"type": "debuff_area", "target": "enemy_densest_cluster",
			"radius": 100, "debuff": "minefield_damage",
			"dps": 80, "duration": 8.0, "armor_bonus_mult": 0.50
		}
	},
	"cps_repair_aura": {
		"id": "cps_repair_aura", "name": "机械维修站",
		"family": "steel", "is_ultimate": false,
		"trigger": "periodic", "interval": 10.0,
		"source_tag": "engineer", "min_source_count": 1,
		"effect": {
			"type": "buff_allies", "target": "mechanical_tag",
			"heal_pct_max_hp": 0.03
		}
	},
	"cps_cleanse": {
		"id": "cps_cleanse", "name": "工程抢修",
		"family": "steel", "is_ultimate": false,
		"trigger": "periodic", "interval": 18.0,
		"source_tag": "engineer", "min_source_count": 1,
		"effect": {
			"type": "buff_allies", "target": "all_allies",
			"cleanse_debuffs": true, "shield": 800, "shield_duration": 6.0
		}
	},
	"cps_steel_storm": {
		"id": "cps_steel_storm", "name": "钢铁风暴",
		"family": "steel", "is_ultimate": true,
		"trigger": "periodic", "interval": 90.0,
		"source_tag": "", "min_source_count": 0,
		"effect": {
			# 原 summon_temp_unit（召唤钢铁傀儡）已废弃：battlefield 无 summon_temp_unit 方法，
			# 兜底信号也无人监听 → 静默失败。改为 buff_allies（终极版护盾+减伤，无需召唤战斗单位）。
			"type": "buff_allies", "target": "all_allies",
			"shield": 3000, "shield_duration": 10.0,
			"stat_bonus": {"damage_reduction": 0.20},
			"stat_bonus_duration": 10.0
		}
	},

	# ═══════════ 火焰家族（5 个）═══════════
	"cps_scorched_earth": {
		"id": "cps_scorched_earth", "name": "焦土政策",
		"family": "flame", "is_ultimate": false,
		"trigger": "periodic", "interval": 16.0,
		"source_tag": "flame", "min_source_count": 1,
		"effect": {
			"type": "debuff_area", "target": "enemy_densest_cluster",
			"radius": 130, "debuff": "burn_mark",
			"dps": 60, "duration": 8.0, "vulnerability_bonus": 0.15
		}
	},
	"cps_burn_city": {
		"id": "cps_burn_city", "name": "焚城",
		"family": "flame", "is_ultimate": true,
		"trigger": "periodic", "interval": 60.0,
		"source_tag": "flame", "min_source_count": 1,
		"effect": {
			"type": "global_damage", "damage_flat": 250,
			"debuff": "burn_mark", "debuff_duration": 8.0,
			"stun_chance": 0.30, "stun_duration": 1.0,
			"vfx": "nuclear_bombardment"
		}
	},
	"cps_firestorm": {
		"id": "cps_firestorm", "name": "烈焰风暴",
		"family": "flame", "is_ultimate": true,
		"trigger": "periodic", "interval": 80.0,
		"source_tag": "flame", "min_source_count": 1,
		"effect": {
			"type": "debuff_global", "debuff": "burn_mark",
			"dps": 50, "duration": 10.0,
			"extra_debuff": {"attack_speed": -0.20, "extra_duration": 10.0}
		}
	},
	"cps_solar_flare": {
		"id": "cps_solar_flare", "name": "太阳耀斑",
		"family": "flame", "is_ultimate": false,
		"trigger": "periodic", "interval": 35.0,
		"source_tag": "flame", "min_source_count": 1,
		"effect": {
			"type": "debuff_global", "debuff": "mark",
			"vulnerability_bonus": 0.25, "duration": 5.0,
			"reveal_stealth": true
		}
	},
	"cps_combustion": {
		"id": "cps_combustion", "name": "火焰传导",
		"family": "flame", "is_ultimate": false,
		"trigger": "periodic", "interval": 18.0,
		"source_tag": "flame", "min_source_count": 1,
		"effect": {
			"type": "debuff_spread", "spread_from": "burning_enemy",
			"debuff": "burn_mark", "max_targets": 5,
			"dps": 35, "duration": 4.0
		}
	},

	# ═══════════ 雷霆家族（5 个）═══════════
	"cps_emp_strike": {
		"id": "cps_emp_strike", "name": "EMP 瘫痪",
		"family": "thunder", "is_ultimate": false,
		"trigger": "periodic", "interval": 12.0,
		"source_tag": "ecm", "min_source_count": 1,
		"effect": {
			"type": "debuff_target", "target": "highest_threat",
			"debuff": "attack_speed_penalty", "value": -0.60,
			"duration": 4.0, "vfx": "emp_blast"
		}
	},
	"cps_chain_lightning": {
		"id": "cps_chain_lightning", "name": "闪电链",
		"family": "thunder", "is_ultimate": false,
		"trigger": "periodic", "interval": 10.0,
		"source_tag": "thunder", "min_source_count": 1,
		"effect": {
			"type": "chain_damage", "source": "highest_atk_ally",
			"bounces": 5, "damage_pct_atk": 0.70,
			"armor_bonus_mult": 0.50
		}
	},
	"cps_heaven_thunder": {
		"id": "cps_heaven_thunder", "name": "天罚雷阵",
		"family": "thunder", "is_ultimate": true,
		"trigger": "periodic", "interval": 100.0,
		"source_tag": "thunder", "min_source_count": 1,
		"effect": {
			"type": "global_damage", "strikes": 15,
			"damage_flat": 180, "mechanical_mult": 2.0,
			"debuff": "crit_mark", "debuff_duration": 5.0,
			"crit_mark_bonus": 0.15
		}
	},
	"cps_railgun": {
		"id": "cps_railgun", "name": "电磁轨道炮",
		"family": "thunder", "is_ultimate": false,
		"trigger": "periodic", "interval": 30.0,
		"source_tag": "sniper", "min_source_count": 1,
		"effect": {
			"type": "single_target_damage", "target": "highest_hp",
			"damage_pct_atk": 3.50, "penetration_ratio": 0.50
		}
	},
	"cps_bvr_mark": {
		"id": "cps_bvr_mark", "name": "超视距打击",
		"family": "thunder", "is_ultimate": false,
		"trigger": "periodic", "interval": 18.0,
		"source_tag": "sniper", "min_source_count": 1,
		"effect": {
			"type": "debuff_target", "target": "highest_threat",
			"debuff": "mark", "duration": 10.0,
			"vulnerability_bonus": 0.30, "crit_mark_bonus": 0.20
		}
	},

	# ═══════════ 虚空家族（5 个）═══════════
	"cps_time_slow": {
		"id": "cps_time_slow", "name": "时间迟缓",
		"family": "void", "is_ultimate": false,
		"trigger": "periodic", "interval": 30.0,
		"source_tag": "void", "min_source_count": 1,
		"effect": {
			"type": "debuff_global", "debuff": "slow_aura",
			"move_speed_mult": 0.50, "attack_speed_mult": 0.50,
			"duration": 4.0
		}
	},
	"cps_reality_collapse": {
		"id": "cps_reality_collapse", "name": "现实崩溃",
		"family": "void", "is_ultimate": false,
		"trigger": "periodic", "interval": 60.0,
		"source_tag": "void", "min_source_count": 1,
		"effect": {
			"type": "execute", "hp_threshold": 0.15,
			"elite_boss_clamp_hp_ratio": 0.15,
			"heal_block_duration": 5.0
		}
	},
	"cps_annihilate": {
		"id": "cps_annihilate", "name": "湮灭之光",
		"family": "void", "is_ultimate": true,
		"trigger": "periodic", "interval": 120.0,
		"source_tag": "void", "min_source_count": 1,
		"effect": {
			"type": "global_damage", "cast_time": 3.0,
			"damage_pct_atk": 3.00,
			"execute_threshold": 0.30
		}
	},
	"cps_time_rewind": {
		"id": "cps_time_rewind", "name": "时间回溯",
		"family": "void", "is_ultimate": true,
		"trigger": "periodic", "interval": 90.0,
		"source_tag": "void", "min_source_count": 1,
		"effect": {
			"type": "buff_allies", "target": "all_allies",
			"heal_pct_max_hp": 0.30, "cleanse_debuffs": true,
			"reset_skill_cd": true
		}
	},
	"cps_dimension_overlay": {
		"id": "cps_dimension_overlay", "name": "维度叠加",
		"family": "void", "is_ultimate": true,
		"trigger": "periodic", "interval": 150.0,
		"source_tag": "void", "min_source_count": 1,
		"effect": {
			"type": "buff_allies", "target": "all_allies",
			"stat_bonus": {"dodge_chance": 0.40, "damage_reduction": 0.30},
			"stat_bonus_duration": 12.0,
			"extra_special": "splash_attack_25"
		}
	},
}

## 根据 ID 获取技能定义
static func get_skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {}).duplicate(true)

## 获取所有技能 ID
static func get_all_skill_ids() -> Array:
	return SKILLS.keys()

## 获取指定 family 的技能 ID（供 TacticDetector 战法条件查询）
static func get_skills_by_family(family: String) -> Array:
	var result: Array = []
	for sid in SKILLS:
		if SKILLS[sid].get("family", "") == family:
			result.append(sid)
	return result

## 是否为终极技能
static func is_ultimate(skill_id: String) -> bool:
	var def: Dictionary = SKILLS.get(skill_id, {})
	return bool(def.get("is_ultimate", false))


# ═══════════════════════════════════════════════════════════
#  source_tag 派生（供 CardPeriodicSkillEngine 触发判定 + 卡牌情报面板显示）
#
#  - compute_source_tags_for_stats(stats)：从 UnitStats 派生该单位应带的全部 source_tag
#    单一映射源：construct_unit._cache_behavior_tags 与 card_info_panel 共用，避免两处分叉
#  - get_family_for_faction(faction_id)：玩家激活阵营 → 法则家族（flame/thunder/void/steel）
# ═══════════════════════════════════════════════════════════

## 玩家势力 → 法则家族（单一权威；合并 game_manager.gd:1027 战略层 + enemy_phase_field_driver.gd:319 视觉层）
## aether_dynamics 在两源冲突，按战略层（game_manager）仲裁为 thunder；若设计意图为 steel，改本表一行即可
const FACTION_TO_FAMILY := {
	"iron_wall_corp": "steel",
	"quantum_logistics": "steel",
	"nova_arms": "flame",
	"aether_dynamics": "thunder",
	"helix_recon": "thunder",
	"frontier_union": "thunder",
	"void_research": "void",
}

## 玩家激活阵营 → 法则家族（空阵营返回空串 → flame/thunder/void 类技能休眠）
static func get_family_for_faction(faction_id: String) -> String:
	return String(FACTION_TO_FAMILY.get(faction_id, ""))

## 从 UnitStats 派生该单位应带的全部 source_tag。
## stats 需由 build_stats_from_card 路径构建（已写好 is_* meta 与 law_family meta）。
## 含 stalker+stealth：保证 bullet.gd 切到读 _behavior_tags_cached 后仍是其 stats-meta 兜底集的超集（防回归）。
## 不含 steel：无卡片技能用 steel 做 source_tag。
static func compute_source_tags_for_stats(stats) -> Array:
	var tags: Array = []
	if stats == null:
		return tags
	# ── 兵种/定位类（对应 source_tag 表）──
	if int(stats.unit_subtype) == GC.UnitSubType.ARTILLERY:
		tags.append("artillery")
	if int(stats.combat_kind) == GC.CombatKind.FORT:
		tags.append("fort")
	# v10 解题式玩法：主类派生 armored/aircraft 标签（与敌方 archetype tag 体系对齐，
	# 供 TAG_COUNTER_RULES 的 armored vs urban_infantry 等规则使用）
	if int(stats.combat_kind) == GC.CombatKind.ARMOR:
		tags.append("armored")
	if int(stats.combat_kind) == GC.CombatKind.AIR:
		tags.append("aircraft")
	if bool(stats.get_meta("is_engineer", false)):
		tags.append("engineer")
	if bool(stats.get_meta("is_ecm", false)):
		tags.append("ecm")
	if bool(stats.get_meta("is_sniper", false)):
		tags.append("sniper")
	if AuraData.is_mechanical_platform(int(stats.platform_type)):
		tags.append("mechanical")
	# ── 行为 tag（补全 bullet.gd:839-849 兜底集，防其回退失效造成回归）──
	if bool(stats.get_meta("is_stalker", false)):
		tags.append("stalker")
		tags.append("stealth")
	# ── 家族类 ──
	# 旧设计：仅由 law_family meta（玩家激活势力时写入）派生 flame/thunder/void。
	# 问题：v6.8 停用势力战斗加成后，玩家多不激活势力 → law_family 恒空 →
	#       火焰/雷霆/虚空 3 家族共 15 个卡片大招全部静默（已解锁也不触发）。
	# 修复（解耦）：保留 law_family meta 作为"势力加成来源"，同时按兵种特征兜底派生——
	#   - flame：火炮（ARTILLERY，燃烧/温压弹载体）
	#   - thunder：防空/电子战（ANTI_AIR 子类或 is_ecm meta，电磁载体）
	#   - void：狙击/渗透（is_sniper 或 is_stalker meta，虚空打击载体）
	# 这样不激活势力时，派出对应兵种单位也能触发大招；激活势力仍让对应家族全员带 tag（保留势力加成）。
	var fam: String = String(stats.get_meta("law_family", ""))
	if not fam.is_empty() and fam in ["flame", "thunder", "void"]:
		tags.append(fam)
	# 兜底派生（不重复添加已有 tag）
	if "flame" not in tags and int(stats.unit_subtype) == GC.UnitSubType.ARTILLERY:
		tags.append("flame")
	if "thunder" not in tags:
		var is_thunder_carrier := (int(stats.unit_subtype) == GC.UnitSubType.ANTI_AIR) \
		                          or bool(stats.get_meta("is_ecm", false))
		if is_thunder_carrier:
			tags.append("thunder")
	if "void" not in tags:
		var is_void_carrier := bool(stats.get_meta("is_sniper", false)) \
		                       or bool(stats.get_meta("is_stalker", false))
		if is_void_carrier:
			tags.append("void")
	return tags
