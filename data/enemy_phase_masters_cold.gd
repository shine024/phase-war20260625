extends RefCounted
class_name EnemyPhaseMastersCOLDWAR

## 敌方相位师资料 - 冷战时代 (enemy_master_013 ~ enemy_master_018)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_013",
		"name": "钢铁烈焰·卡尔",
		"title": "熔铸大师",
		"level": 18,
		"faction": "steel_flame",
		"difficulty": "hard",
		"traits": [
			{
				"id": "forgemaster",
				"name": "熔铸大师",
				"description": "钢铁+烈焰协同：相邻的钢铁和烈焰单位互相增强25%伤害",
				"effects": {"synergy_boost": 0.25, "synergy_types": ["steel", "flame"]}
			}
		],
		"active_spells": [
			{
				"id": "molten_armor",
				"name": "熔岩护甲",
				"description": "友军获得熔岩护甲，受到攻击时对攻击者造成80火焰伤害",
				"cooldown": 25.0,
				"mana_cost": 150,
				"effect": "thorn_armor_fire",
				"params": {"thorn_damage": 80, "duration": 10.0}
			},
			{
				"id": "forge_hammer",
				"name": "锻锤",
				"description": "巨大的锻锤砸向地面，造成300伤害并眩晕2.5秒",
				"cooldown": 20.0,
				"mana_cost": 130,
				"effect": "hammer_smash",
				"params": {"damage": 300, "stun_duration": 2.5, "radius": 120}
			}
		],
		"passive_spells": [
			{
				"id": "heat_treatment",
				"name": "热处理",
				"description": "友军攻击有15%概率触发额外火焰爆炸",
				"effect": "proc_explosion",
				"params": {"chance": 0.15, "explosion_damage": 120}
			},
			{
				"id": "tempered",
				"name": "回火",
				"description": "友军受到火焰伤害时，攻击力提升10%，持续5秒",
				"effect": "fire_damage_boost",
				"params": {"boost": 0.1, "duration": 5.0}
			}
		],
		"equipment": {
			"phase_instrument": "hybrid_steel_flame_mk1",
			"level": 18,
			"platforms": ["steel_fortress_expert", "flame_raider_expert"],
			"weapons": ["steel_gatling_expert", "flame_thrower_expert"],
			"energy_cards": ["hybrid_energy_basic"]
		},
		"stats": {
			"max_hp": 2800,
			"attack_power": 340,
			"defense": 120,
			"energy_regen": 3.2,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_014",
		"name": "雷霆钢铁·维克多",
		"title": "电磁装甲师",
		"level": 19,
		"faction": "thunder_steel",
		"difficulty": "hard",
		"traits": [
			{
				"id": "electromagnetic_armor",
				"name": "电磁装甲师",
				"description": "雷霆+钢铁协同：护甲受到攻击时反射雷电，造成80伤害",
				"effects": {"synergy_boost": 0.20, "synergy_types": ["thunder", "steel"], "armor_reflect": 80}
			}
		],
		"active_spells": [
			{
				"id": "railgun_barrage",
				"name": "电磁炮齐射",
				"description": "发射5枚电磁炮弹，穿透路径上的所有敌人",
				"cooldown": 22.0,
				"mana_cost": 160,
				"effect": "piercing_shots",
				"params": {"shot_count": 5, "damage": 220}
			},
			{
				"id": "energize_shields",
				"name": "充能护盾",
				"description": "为所有友军施加能量护盾，吸收400点伤害",
				"cooldown": 18.0,
				"mana_cost": 120,
				"effect": "mass_shield",
				"params": {"shield_amount": 400}
			}
		],
		"passive_spells": [
			{
				"id": "conductive_armor",
				"name": "导电护甲",
				"description": "友军受到攻击时，对攻击者放电造成60伤害",
				"effect": "lightning_thorn",
				"params": {"thorn_damage": 60}
			},
			{
				"id": "overclock",
				"name": "超频",
				"description": "能量超过70%时，射速提升40%",
				"effect": "high_energy_attack_speed",
				"params": {"threshold": 0.7, "speed_boost": 0.4}
			}
		],
		"equipment": {
			"phase_instrument": "hybrid_thunder_steel_mk1",
			"level": 19,
			"platforms": ["steel_titan_expert", "thunter_striker_expert"],
			"weapons": ["steel_railcannon_advanced", "tesla_coil_expert"],
			"energy_cards": ["hybrid_energy_basic"]
		},
		"stats": {
			"max_hp": 2700,
			"attack_power": 360,
			"defense": 140,
			"energy_regen": 3.5,
			"unit_limit": 7
		}
	},
	{
		"id": "enemy_master_015",
		"name": "虚空烈焰·塞拉菲娜",
		"title": "熵增炎魔",
		"level": 20,
		"faction": "void_flame",
		"difficulty": "expert",
		"traits": [
			{
				"id": "chaos_flame_trait",
				"name": "熵增炎魔",
				"description": "烈焰+虚空协同：被燃烧的敌人能量流失速度翻倍",
				"effects": {"synergy_boost": 0.20, "synergy_types": ["flame", "void"], "burn_energy_drain_mult": 2.0}
			}
		],
		"active_spells": [
			{
				"id": "chaos_inferno",
				"name": "混沌炼狱",
				"description": "召唤混乱火焰，随机移动并每秒造成180伤害",
				"cooldown": 30.0,
				"mana_cost": 200,
				"effect": "chaos_flame",
				"params": {"duration": 8.0, "damage": 180}
			},
			{
				"id": "burning_void",
				"name": "燃烧虚空",
				"description": "在指定区域创造燃烧虚空，持续造成伤害和能量流失",
				"cooldown": 25.0,
				"mana_cost": 180,
				"effect": "burning_void_zone",
				"params": {"damage": 120, "energy_drain": 25, "duration": 8.0}
			}
		],
		"passive_spells": [
			{
				"id": "entropy_flame",
				"name": "熵增之火",
				"description": "火焰伤害有25%概率触发虚空吸取效果",
				"effect": "fire_lifesteal_chance",
				"params": {"chance": 0.25, "lifesteal_percent": 0.15}
			},
			{
				"id": "void_burn",
				"name": "虚空燃烧",
				"description": "被燃烧的敌人移动速度降低35%",
				"effect": "burn_slow",
				"params": {"slow_percent": 0.35}
			}
		],
		"equipment": {
			"phase_instrument": "hybrid_void_flame_mk1",
			"level": 20,
			"platforms": ["void_mage_expert", "flame_siege_expert"],
			"weapons": ["entropy_caster_expert", "plasma_cannon_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 2600,
			"attack_power": 380,
			"defense": 85,
			"energy_regen": 3.8,
			"unit_limit": 7
		}
	},

	# ==================== Tier 4 - 专家级相位师 (Lv22-25) ====================
	{
		"id": "enemy_master_016",
		"name": "不朽钢铁·阿特拉斯",
		"title": "世界承载者",
		"level": 22,
		"faction": "steel",
		"difficulty": "expert",
		"traits": [
			{
				"id": "immortal_will",
				"name": "不朽意志",
				"description": "友军不会受到超过30%最大HP的单次伤害；每有1个友军全体防御+5%",
				"effects": {"damage_cap": 0.30, "unit_count_defense": 0.05}
			}
		],
		"active_spells": [
			{
				"id": "world_pillar",
				"name": "世界支柱",
				"description": "创造2个巨大的钢铁支柱，拥有4000HP",
				"cooldown": 60.0,
				"mana_cost": 300,
				"effect": "permanent_structures",
				"params": {"count": 2, "hp": 4000}
			},
			{
				"id": "earthquake",
				"name": "大地震",
				"description": "全屏震动，造成500伤害并降低所有敌人40%防御",
				"cooldown": 40.0,
				"mana_cost": 250,
				"effect": "global_earthquake",
				"params": {"damage": 500, "defense_reduction": 0.4, "duration": 6.0}
			}
		],
		"passive_spells": [
			{
				"id": "unbreakable",
				"name": "不可破坏",
				"description": "友军单位不会受到超过最大生命值30%的单次伤害",
				"effect": "damage_cap",
				"params": {"max_damage_percent": 0.3}
			},
			{
				"id": "steel_mountain",
				"name": "钢铁之山",
				"description": "友军数量越多，全体防御力越高（每个单位+5%）",
				"effect": "unit_count_defense",
				"params": {"defense_per_unit": 0.05}
			}
		],
		"equipment": {
			"phase_instrument": "steel_guardian_mk4",
			"level": 22,
			"platforms": ["steel_fortress_expert", "steel_titan_expert"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 5000,
			"attack_power": 400,
			"defense": 200,
			"energy_regen": 3.5,
			"unit_limit": 9
		}
	},
	{
		"id": "enemy_master_017",
		"name": "永恒炎魔·苏尔特",
		"title": "诸神黄昏",
		"level": 23,
		"faction": "flame",
		"difficulty": "expert",
		"traits": [
			{
				"id": "ragnarok",
				"name": "诸神黄昏",
				"description": "火焰伤害+40%；友军首次死亡时自动复活，恢复30%生命值",
				"effects": {"fire_damage_boost": 0.40, "auto_revive_once": {"hp_percent": 0.30}}
			}
		],
		"active_spells": [
			{
				"id": "ragnarok_inferno",
				"name": "诸神黄昏炼狱",
				"description": "召唤火焰巨人，持续20秒",
				"cooldown": 90.0,
				"mana_cost": 500,
				"effect": "summon_fire_giant",
				"params": {"duration": 20.0}
			},
			{
				"id": "solar_flare",
				"name": "太阳耀斑",
				"description": "释放太阳耀斑，全屏800伤害并致盲所有敌人5秒",
				"cooldown": 60.0,
				"mana_cost": 400,
				"effect": "solar_flare",
				"params": {"damage": 800, "blind_duration": 5.0}
			}
		],
		"passive_spells": [
			{
				"id": "phoenix_rebirth_auto",
				"name": "凤凰重生",
				"description": "友军死亡后会在原位置以30%HP复活",
				"effect": "phoenix_rebirth_auto",
				"params": {"rebirth_hp": 0.3, "cooldown_per_unit": 30.0}
			},
			{
				"id": "time_based_hp_drain",
				"name": "热寂",
				"description": "战斗每进行30秒，所有敌人失去8%最大生命值",
				"effect": "time_based_hp_drain",
				"params": {"interval": 30.0, "drain_percent": 0.08}
			}
		],
		"equipment": {
			"phase_instrument": "flame_destroyer_mk4",
			"level": 23,
			"platforms": ["flame_raider_expert", "flame_siege_expert"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 4200,
			"attack_power": 520,
			"defense": 110,
			"energy_regen": 4.0,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_018",
		"name": "万雷之主·雷神",
		"title": "雷霆化身",
		"level": 24,
		"faction": "thunder",
		"difficulty": "expert",
		"traits": [
			{
				"id": "thunder_avatar",
				"name": "万钧雷霆",
				"description": "雷电伤害+45%，闪电链弹射额外+2次，能量满自动打击",
				"effects": {"lightning_damage_boost": 0.45, "chain_bounce_bonus": 2, "energy_full_auto_strike": true}
			}
		],
		"active_spells": [
			{
				"id": "thunder_god_avatar",
				"name": "雷神化身",
				"description": "化身为雷神，获得无限能量和无敌状态，持续8秒",
				"cooldown": 120.0,
				"mana_cost": 600,
				"effect": "avatar_mode",
				"params": {"duration": 8.0}
			},
			{
				"id": "lightning_omega",
				"name": "终极雷霆",
				"description": "释放超强力闪电，造成1200伤害并分裂为6道",
				"cooldown": 50.0,
				"mana_cost": 350,
				"effect": "ultimate_lightning",
				"params": {"damage": 1200, "splits": 6}
			}
		],
		"passive_spells": [
			{
				"id": "auto_lightning",
				"name": "无处不在的闪电",
				"description": "每5秒自动随机打击敌人，造成250伤害",
				"effect": "auto_lightning",
				"params": {"interval": 5.0, "damage": 250}
			},
			{
				"id": "global_damage_boost",
				"name": "导电世界",
				"description": "整个战场变为导电体，所有敌人受到的雷电伤害+40%",
				"effect": "global_damage_boost",
				"params": {"damage_type": "lightning", "boost": 0.4}
			}
		],
		"equipment": {
			"phase_instrument": "thunder_storm_mk4",
			"level": 24,
			"platforms": ["thunter_striker_expert", "thunter_sniper_expert"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 3800,
			"attack_power": 560,
			"defense": 95,
			"energy_regen": 4.5,
			"unit_limit": 8
		}
	},
]
