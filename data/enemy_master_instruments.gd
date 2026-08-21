extends RefCounted
class_name EnemyMasterInstruments
## v18 四源重构·批次2 —— 敌方相位师大招的物理归宿（30 专属相位仪变体）
##
## 来源：原 5 个 enemy_phase_masters_*.gd 每个 master 的 active_spells 字段**原样迁入**，
## 本文件是大招数据的唯一真身（master 数据文件中该字段已删除，由本文件生成：
## tools/gen_enemy_master_instruments.py ← docs/migration_baseline.json）。
##
## 消费链（数值/行为与迁移前逐字节一致）：
##   enemy_phase_field_driver.setup() → get_master_ultimate_spells(id) → _boss_active_spells
##   → EnemyMasterSkillEngine.update() 按 cooldown 定时触发（5 类执行函数）
##
## 变体 id 规则 pi_em_001~030：不入统一相位仪池（PhaseInstruments）/不掉落池——
## 池侧消费（active_ability/atk/hp/def 加成/绿槽上限）仍按基础仪器 id 走，数值零变化。

## master_id → 大招列表（原 active_spells 原样）
const MASTER_ULTIMATES: Dictionary = {
	"enemy_master_001": [
		{
			"id": "iron_bulwark",
			"name": "钢铁壁垒",
			"description": "每28秒为自身施加20%最大生命值护盾",
			"effect": "energy_shield",
			"cooldown": 28.0,
			"params": {
				"shield_pct": 0.2
			}
		}
	],
	"enemy_master_002": [
		{
			"id": "napalm_explosion",
			"name": "烈焰风暴",
			"description": "每26秒对全体玩家单位造成火焰范围伤害",
			"effect": "napalm_explosion",
			"cooldown": 26.0,
			"params": {
				"damage_mult": 0.8
			}
		}
	],
	"enemy_master_003": [
		{
			"id": "tesla_chain",
			"name": "雷霆连锁",
			"description": "每24秒释放连锁闪电，跳跃打击最多5个玩家单位",
			"effect": "tesla_chain",
			"cooldown": 24.0,
			"params": {
				"damage_mult": 0.9
			}
		}
	],
	"enemy_master_004": [
		{
			"id": "phase_debuff",
			"name": "相位移领域",
			"description": "每25秒扭曲玩家单位，降低其攻速与暴击",
			"effect": "darkness_debuff",
			"cooldown": 25.0,
			"params": {
				"attack_speed_penalty": 0.2,
				"crit_penalty": 0.15,
				"duration": 4.0
			}
		}
	],
	"enemy_master_005": [
		{
			"id": "reinforcement_deploy",
			"name": "钢铁援军",
			"description": "每22秒召唤一批友军单位增援战场",
			"effect": "summon_reinforcement",
			"cooldown": 22.0
		}
	],
	"enemy_master_006": [
		{
			"id": "inferno_explosion",
			"name": "地狱烈焰",
			"description": "每20秒引爆全场，对所有玩家单位造成烈焰伤害",
			"effect": "hellfire_explosion",
			"cooldown": 20.0,
			"params": {
				"damage_mult": 1.0
			}
		}
	],
	"enemy_master_007": [
		{
			"id": "thunderstorm_chain",
			"name": "雷暴连锁",
			"description": "每20秒释放连锁闪电，跳跃打击玩家单位",
			"effect": "thunderstorm_chain",
			"cooldown": 20.0,
			"params": {
				"damage_mult": 1.0
			}
		}
	],
	"enemy_master_008": [
		{
			"id": "void_implosion",
			"name": "虚空内爆",
			"description": "每22秒引发虚空坍缩，对全体玩家单位造成范围伤害",
			"effect": "void_explosion",
			"cooldown": 22.0,
			"params": {
				"damage_mult": 1.0
			}
		}
	],
	"enemy_master_009": [
		{
			"id": "legion_deploy",
			"name": "军团动员",
			"description": "每19秒召唤钢铁军团单位增援",
			"effect": "deploy_legion",
			"cooldown": 19.0
		}
	],
	"enemy_master_010": [
		{
			"id": "prometheus_flame",
			"name": "普罗米修斯之焰",
			"description": "每18秒降下天火，对全体玩家单位造成烈焰伤害",
			"effect": "meteor_flame",
			"cooldown": 18.0,
			"params": {
				"damage_mult": 1.1
			}
		}
	],
	"enemy_master_011": [
		{
			"id": "zeus_lightning",
			"name": "宙斯雷霆",
			"description": "每16秒降下雷霆连锁，跳跃打击多个玩家单位",
			"effect": "lightning_chain",
			"cooldown": 16.0,
			"params": {
				"damage_mult": 1.2
			}
		},
		{
			"id": "olympus_ward",
			"name": "奥林匹斯之护",
			"description": "每24秒为自身施加18%最大生命值护盾",
			"effect": "dome_barrier",
			"cooldown": 24.0,
			"params": {
				"shield_pct": 0.18
			}
		}
	],
	"enemy_master_012": [
		{
			"id": "abyss_apocalypse",
			"name": "深渊降临",
			"description": "每18秒引发虚空灾变，对全体玩家单位造成范围伤害",
			"effect": "abyss_apocalypse",
			"cooldown": 18.0,
			"params": {
				"damage_mult": 1.2
			}
		},
		{
			"id": "devouring_void",
			"name": "虚空吞噬",
			"description": "每14秒对生命最高的玩家单位发动吞噬打击",
			"effect": "devour_single",
			"cooldown": 14.0,
			"params": {
				"damage_mult": 1.3
			}
		}
	],
	"enemy_master_013": [
		{
			"id": "molten_bombard",
			"name": "熔铁轰炸",
			"description": "每17秒对全体玩家单位倾泻熔铁弹幕",
			"effect": "bombard_explosion",
			"cooldown": 17.0,
			"params": {
				"damage_mult": 1.1
			}
		}
	],
	"enemy_master_014": [
		{
			"id": "victor_chain_lightning",
			"name": "雷霆贯穿",
			"description": "每15秒释放连锁闪电，跳跃打击玩家单位",
			"effect": "chain_lightning",
			"cooldown": 15.0,
			"params": {
				"damage_mult": 1.2
			}
		},
		{
			"id": "victor_plate",
			"name": "钢板护盾",
			"description": "每22秒为自身施加22%最大生命值护盾",
			"effect": "plate_shield",
			"cooldown": 22.0,
			"params": {
				"shield_pct": 0.22
			}
		}
	],
	"enemy_master_015": [
		{
			"id": "seraphina_void",
			"name": "虚空烈焰",
			"description": "每16秒引爆虚空烈焰，对全体玩家单位造成范围伤害",
			"effect": "void_apocalypse",
			"cooldown": 16.0,
			"params": {
				"damage_mult": 1.2
			}
		},
		{
			"id": "seraphina_curse",
			"name": "炽焰诅咒",
			"description": "每18秒削弱玩家单位，降低攻速与闪避",
			"effect": "weakness_debuff",
			"cooldown": 18.0,
			"params": {
				"attack_speed_penalty": 0.25,
				"dodge_penalty": 0.2,
				"duration": 5.0
			}
		}
	],
	"enemy_master_016": [
		{
			"id": "atlas_bulwark",
			"name": "不朽壁垒",
			"description": "每16秒为自身施加28%最大生命值护盾",
			"effect": "ward_bulwark",
			"cooldown": 16.0,
			"params": {
				"shield_pct": 0.28
			}
		},
		{
			"id": "atlas_summon",
			"name": "不朽军团",
			"description": "每20秒召唤不朽钢铁单位增援",
			"effect": "forge_summon",
			"cooldown": 20.0
		}
	],
	"enemy_master_017": [
		{
			"id": "surtr_meteor",
			"name": "诸神黄昏",
			"description": "每15秒召唤陨石雨，对全体玩家单位造成毁灭伤害",
			"effect": "meteor_apocalypse",
			"cooldown": 15.0,
			"params": {
				"damage_mult": 1.3
			}
		}
	],
	"enemy_master_018": [
		{
			"id": "thunder_lord_chain",
			"name": "万雷齐发",
			"description": "每14秒释放强力连锁闪电，跳跃打击玩家单位",
			"effect": "thunder_chain",
			"cooldown": 14.0,
			"params": {
				"damage_mult": 1.3
			}
		},
		{
			"id": "thunder_lord_judgment",
			"name": "雷神之裁",
			"description": "每16秒对生命最高的玩家单位降下雷罚",
			"effect": "god_weapon_single",
			"cooldown": 16.0,
			"params": {
				"damage_mult": 1.4
			}
		}
	],
	"enemy_master_019": [
		{
			"id": "nidhogg_void",
			"name": "虚空吞噬",
			"description": "每14秒引发虚空灾变，对全体玩家单位造成范围伤害",
			"effect": "void_apocalypse",
			"cooldown": 14.0,
			"params": {
				"damage_mult": 1.3
			}
		},
		{
			"id": "nidhogg_devour",
			"name": "龙息吞噬",
			"description": "每12秒对生命最高的玩家单位发动吞噬",
			"effect": "devour_single",
			"cooldown": 12.0,
			"params": {
				"damage_mult": 1.5
			}
		}
	],
	"enemy_master_020": [
		{
			"id": "tyr_thunder",
			"name": "钢铁雷霆",
			"description": "每13秒释放连锁闪电，跳跃打击玩家单位",
			"effect": "tesla_chain",
			"cooldown": 13.0,
			"params": {
				"damage_mult": 1.3
			}
		},
		{
			"id": "tyr_reinforce",
			"name": "战争动员",
			"description": "每16秒召唤钢铁战争机器单位增援",
			"effect": "mech_deploy",
			"cooldown": 16.0
		}
	],
	"enemy_master_021": [
		{
			"id": "kargath_inferno",
			"name": "地狱火",
			"description": "每12秒引爆烈焰风暴，对全体玩家单位造成范围伤害",
			"effect": "hell_inferno",
			"cooldown": 12.0,
			"params": {
				"damage_mult": 1.4
			}
		},
		{
			"id": "kargath_void",
			"name": "虚空裂隙",
			"description": "每15秒撕开虚空裂隙，对全体玩家单位造成虚空伤害",
			"effect": "void_apocalypse",
			"cooldown": 15.0,
			"params": {
				"damage_mult": 1.3
			}
		}
	],
	"enemy_master_022": [
		{
			"id": "iron_cavalry_summon",
			"name": "钢铁洪流",
			"description": "每13秒召唤战争机器单位增援",
			"effect": "mech_deploy",
			"cooldown": 13.0
		},
		{
			"id": "iron_cavalry_bombard",
			"name": "地毯轰炸",
			"description": "每15秒对全体玩家单位倾泻火力",
			"effect": "orbital_bombard",
			"cooldown": 15.0,
			"params": {
				"damage_mult": 1.4
			}
		}
	],
	"enemy_master_023": [
		{
			"id": "phoenix_meteor",
			"name": "凤凰陨落",
			"description": "每12秒召唤陨石雨，对全体玩家单位造成毁灭伤害",
			"effect": "meteor_apocalypse",
			"cooldown": 12.0,
			"params": {
				"damage_mult": 1.5
			}
		},
		{
			"id": "phoenix_curse",
			"name": "凤凰灼烧",
			"description": "每14秒灼烧玩家单位，大幅降低攻速",
			"effect": "emp_debuff",
			"cooldown": 14.0,
			"params": {
				"attack_speed_penalty": 0.35,
				"duration": 6.0
			}
		}
	],
	"enemy_master_024": [
		{
			"id": "cyclonus_storm",
			"name": "风暴之眼",
			"description": "每11秒释放强力连锁闪电，跳跃打击玩家单位",
			"effect": "tesla_chain",
			"cooldown": 11.0,
			"params": {
				"damage_mult": 1.5
			}
		},
		{
			"id": "cyclonus_judgment",
			"name": "风暴审判",
			"description": "每13秒对生命最高的玩家单位降下雷罚",
			"effect": "god_weapon_single",
			"cooldown": 13.0,
			"params": {
				"damage_mult": 1.6
			}
		},
		{
			"id": "cyclonus_disruption",
			"name": "电磁干扰",
			"description": "每16秒释放EMP，降低玩家单位攻速与暴击",
			"effect": "emp_pulse",
			"cooldown": 16.0,
			"params": {
				"attack_speed_penalty": 0.3,
				"crit_penalty": 0.25,
				"duration": 6.0
			}
		}
	],
	"enemy_master_025": [
		{
			"id": "abyss_void",
			"name": "深渊降临",
			"description": "每12秒引发虚空灾变，对全体玩家单位造成毁灭范围伤害",
			"effect": "void_apocalypse",
			"cooldown": 12.0,
			"params": {
				"damage_mult": 1.6
			}
		},
		{
			"id": "abyss_devour",
			"name": "深渊吞噬",
			"description": "每10秒对生命最高的玩家单位发动吞噬打击",
			"effect": "devour_single",
			"cooldown": 10.0,
			"params": {
				"damage_mult": 1.8
			}
		}
	],
	"enemy_master_026": [
		{
			"id": "hephaestus_aegis",
			"name": "神之壁垒",
			"description": "每12秒为自身施加35%最大生命值护盾",
			"effect": "ward_bulwark",
			"cooldown": 12.0,
			"params": {
				"shield_pct": 0.35
			}
		},
		{
			"id": "hephaestus_forge",
			"name": "神之熔炉",
			"description": "每14秒锻造钢铁神兵单位增援战场",
			"effect": "forge_summon",
			"cooldown": 14.0
		}
	],
	"enemy_master_027": [
		{
			"id": "hecate_inferno",
			"name": "魔神地狱火",
			"description": "每11秒引爆地狱烈焰，对全体玩家单位造成毁灭范围伤害",
			"effect": "hell_inferno",
			"cooldown": 11.0,
			"params": {
				"damage_mult": 1.7
			}
		},
		{
			"id": "hecate_apocalypse",
			"name": "末日审判",
			"description": "每14秒召唤陨石雨，对全体玩家单位造成末日伤害",
			"effect": "meteor_apocalypse",
			"cooldown": 14.0,
			"params": {
				"damage_mult": 1.6
			}
		}
	],
	"enemy_master_028": [
		{
			"id": "thor_mjolnir",
			"name": "雷霆之锤",
			"description": "每10秒释放连锁闪电，跳跃打击玩家单位",
			"effect": "tesla_chain",
			"cooldown": 10.0,
			"params": {
				"damage_mult": 1.7
			}
		},
		{
			"id": "thor_judgment",
			"name": "雷神审判",
			"description": "每12秒对生命最高的玩家单位降下雷罚",
			"effect": "god_weapon_single",
			"cooldown": 12.0,
			"params": {
				"damage_mult": 1.8
			}
		}
	],
	"enemy_master_029": [
		{
			"id": "nyx_eternal_night",
			"name": "永夜降临",
			"description": "每10秒引发虚空灾变，对全体玩家单位造成毁灭范围伤害",
			"effect": "void_apocalypse",
			"cooldown": 10.0,
			"params": {
				"damage_mult": 1.7
			}
		},
		{
			"id": "nyx_darkness",
			"name": "永恒黑暗",
			"description": "每13秒笼罩玩家单位于黑暗，大幅降低攻速暴击闪避",
			"effect": "darkness_debuff",
			"cooldown": 13.0,
			"params": {
				"attack_speed_penalty": 0.4,
				"crit_penalty": 0.3,
				"dodge_penalty": 0.25,
				"duration": 7.0
			}
		},
		{
			"id": "nyx_devour",
			"name": "虚空吞噬",
			"description": "每11秒对生命最高的玩家单位发动吞噬打击",
			"effect": "devour_single",
			"cooldown": 11.0,
			"params": {
				"damage_mult": 1.9
			}
		}
	],
	"enemy_master_030": [
		{
			"id": "omega_apocalypse",
			"name": "终末启示",
			"description": "每9秒引发终极虚空灾变，对全体玩家单位造成毁灭范围伤害",
			"effect": "void_apocalypse",
			"cooldown": 9.0,
			"params": {
				"damage_mult": 2.0
			}
		},
		{
			"id": "omega_thunder",
			"name": "终末雷霆",
			"description": "每11秒释放终极连锁闪电，跳跃打击玩家单位",
			"effect": "tesla_chain",
			"cooldown": 11.0,
			"params": {
				"damage_mult": 2.0
			}
		},
		{
			"id": "omega_judgment",
			"name": "终焉裁决",
			"description": "每10秒对生命最高的玩家单位降下终焉打击",
			"effect": "god_weapon_single",
			"cooldown": 10.0,
			"params": {
				"damage_mult": 2.0
			}
		}
	],
}

## master_id → 变体元数据（variant 专属仪器 id / base 基础仪器 id / display 展示名）
const MASTER_VARIANTS: Dictionary = {
	"enemy_master_001": {"variant": "pi_em_001", "base": "pi_steel_02", "display": "钢铁先锋·马库斯"},
	"enemy_master_002": {"variant": "pi_em_002", "base": "pi_flame_02", "display": "烈焰使者·伊格尼斯"},
	"enemy_master_003": {"variant": "pi_em_003", "base": "pi_thunder_02", "display": "雷击者·沃尔特"},
	"enemy_master_004": {"variant": "pi_em_004", "base": "pi_void_02", "display": "虚空行者·奈克萨斯"},
	"enemy_master_005": {"variant": "pi_em_005", "base": "pi_steel_03", "display": "钢铁元帅·克劳斯"},
	"enemy_master_006": {"variant": "pi_em_006", "base": "pi_flame_03", "display": "炎魔女王·赫卡特"},
	"enemy_master_007": {"variant": "pi_em_007", "base": "pi_thunder_03", "display": "雷神之子·索尔"},
	"enemy_master_008": {"variant": "pi_em_008", "base": "pi_void_03", "display": "虚空领主·萨洛斯"},
	"enemy_master_009": {"variant": "pi_em_009", "base": "pi_steel_04", "display": "钢铁军团长·费米"},
	"enemy_master_010": {"variant": "pi_em_010", "base": "pi_flame_04", "display": "炎帝·普罗米修斯"},
	"enemy_master_011": {"variant": "pi_em_011", "base": "pi_thunder_04", "display": "雷皇·宙斯"},
	"enemy_master_012": {"variant": "pi_em_012", "base": "pi_void_04", "display": "虚空虚主·阿扎托斯"},
	"enemy_master_013": {"variant": "pi_em_013", "base": "pi_steelflame_01", "display": "钢铁烈焰·卡尔"},
	"enemy_master_014": {"variant": "pi_em_014", "base": "pi_steelthunder_01", "display": "雷霆钢铁·维克多"},
	"enemy_master_015": {"variant": "pi_em_015", "base": "pi_flamevoid_01", "display": "虚空烈焰·塞拉菲娜"},
	"enemy_master_016": {"variant": "pi_em_016", "base": "pi_steel_04", "display": "不朽钢铁·阿特拉斯"},
	"enemy_master_017": {"variant": "pi_em_017", "base": "pi_flame_04", "display": "永恒炎魔·苏尔特"},
	"enemy_master_018": {"variant": "pi_em_018", "base": "pi_thunder_04", "display": "万雷之主·雷神"},
	"enemy_master_019": {"variant": "pi_em_019", "base": "pi_void_04", "display": "虚空主宰·尼德霍格"},
	"enemy_master_020": {"variant": "pi_em_020", "base": "pi_steelthunder_01", "display": "钢铁雷霆·泰尔"},
	"enemy_master_021": {"variant": "pi_em_021", "base": "pi_flamevoid_01", "display": "烈焰虚空·克尔加"},
	"enemy_master_022": {"variant": "pi_em_022", "base": "pi_steel_04", "display": "战争机器·铁骑"},
	"enemy_master_023": {"variant": "pi_em_023", "base": "pi_flame_04", "display": "火术宗师·凤凰"},
	"enemy_master_024": {"variant": "pi_em_024", "base": "pi_thunder_04", "display": "风暴使者·赛勒斯"},
	"enemy_master_025": {"variant": "pi_em_025", "base": "pi_void_04", "display": "暗影主宰·深渊"},
	"enemy_master_026": {"variant": "pi_em_026", "base": "pi_steel_05", "display": "钢铁之神·赫淮斯托斯"},
	"enemy_master_027": {"variant": "pi_em_027", "base": "pi_flame_05", "display": "炎魔之神·赫卡特"},
	"enemy_master_028": {"variant": "pi_em_028", "base": "pi_thunder_05", "display": "雷神·托尔"},
	"enemy_master_029": {"variant": "pi_em_029", "base": "pi_void_05", "display": "虚空女神·尼克斯"},
	"enemy_master_030": {"variant": "pi_em_030", "base": "pi_omega_01", "display": "全能相位师·奥米伽"},
}


## 取指定 master 的大招列表（深拷贝防污染静态表；未知 id 返回空数组）
static func get_master_ultimate_spells(master_id: String) -> Array:
	var arr: Array = MASTER_ULTIMATES.get(master_id, [])
	return arr.duplicate(true) if not arr.is_empty() else []


## 取专属相位仪变体完整定义（组合：基础仪器池数据 + 大招 + enemy_only 标记）。
## 供信息卡展示/未来敌方装备 UI 用；基础数值仍走 PhaseInstruments 池按 base id 查询。
static func get_master_instrument(master_id: String) -> Dictionary:
	var meta: Dictionary = MASTER_VARIANTS.get(master_id, {})
	if meta.is_empty():
		return {}
	var base_id: String = String(meta.get("base", ""))
	var pool := preload("res://data/phase_instruments.gd")
	var base_cfg: Dictionary = pool.get_by_id(base_id)
	var variant: Dictionary = base_cfg.duplicate(true) if not base_cfg.is_empty() else {}
	variant["id"] = String(meta.get("variant", ""))
	variant["base_instrument"] = base_id
	variant["display_name"] = String(meta.get("display", ""))
	variant["acquire_rule"] = "enemy_only"
	variant["active_abilities"] = get_master_ultimate_spells(master_id)
	return variant


## 变体 id 反查 master_id（掉落过滤/调试用；非变体 id 返回空串）
static func get_master_id_by_variant(variant_id: String) -> String:
	for mid in MASTER_VARIANTS:
		if String(MASTER_VARIANTS[mid].get("variant", "")) == variant_id:
			return String(mid)
	return ""
