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
		"active_spells": [],
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
			"phase_instrument": "pi_steelflame_01",
			"level": 18,
			"platforms": ["cold_arm_t72_e", "cold_arm_t72_e", "cold_arm_btr_e", "cold_air_m113_e", "cold_inf_ak"],
			"weapons": ["steel_gatling_expert", "flame_thrower_expert"],
			"energy_cards": ["hybrid_energy_basic"]
		},
		"stats": {
			"max_hp": 9450,
			"attack_power": 121,
			"defense": 37,
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
		"active_spells": [],
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
			"phase_instrument": "pi_steelthunder_01",
			"level": 19,
			"platforms": ["cold_arm_t72_e", "cold_arm_btr_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_boss_mig"],
			"weapons": ["steel_railcannon_advanced", "tesla_coil_expert"],
			"energy_cards": ["hybrid_energy_basic"]
		},
		"stats": {
			"max_hp": 9550,
			"attack_power": 124,
			"defense": 46,
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
		"active_spells": [],
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
			"phase_instrument": "pi_flamevoid_01",
			"level": 20,
			"platforms": ["cold_boss_mig", "cold_arm_t72_e", "cold_arm_t72_e", "cold_air_m113_e", "cold_inf_spetsnaz_e"],
			"weapons": ["entropy_caster_expert", "plasma_cannon_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 9700,
			"attack_power": 126,
			"defense": 29,
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
		"active_spells": [],
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
			"phase_instrument": "pi_steel_04",
			"level": 22,
			"platforms": ["cold_boss_mig", "cold_arm_t72_e", "cold_arm_t72_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_arm_btr_e"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 9900,
			"attack_power": 131,
			"defense": 36,
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
				"description": "三维攻击+15%；友军首次死亡时自动复活，恢复30%生命值",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15, "auto_revive_once": {"hp_percent": 0.30}}
			}
		],
		"active_spells": [],
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
			"phase_instrument": "pi_flame_04",
			"level": 23,
			"platforms": ["cold_arm_t72_e", "cold_inf_ak", "cold_boss_mig", "cold_arm_btr_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 10000,
			"attack_power": 133,
			"defense": 24,
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
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [],
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
				"description": "三维攻击+8%",
				"effect": "global_damage_boost",
				"params": {"damage_type": "lightning", "boost": 0.08}
			}
		],
		"equipment": {
			"phase_instrument": "pi_thunder_04",
			"level": 24,
			"platforms": ["cold_boss_mig", "cold_boss_mig", "cold_arm_t72_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_arm_btr_e"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 10150,
			"attack_power": 136,
			"defense": 23,
			"energy_regen": 4.5,
			"unit_limit": 8
		}
	},
]
