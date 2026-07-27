extends RefCounted
class_name CardPeriodicSkills
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
			"type": "summon_temp_unit",
			"summon_id": "steel_golem", "count": 3,
			"inherit_atk_pct": 0.25, "duration": 12.0,
			"death_explosion_pct_atk": 2.0, "explosion_radius": 100
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
		"trigger": "periodic", "interval": 100.0,
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
