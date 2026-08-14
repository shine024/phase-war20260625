extends RefCounted
class_name EnemyPhaseMastersWW1

## 敌方相位师资料 - 一战时代 (enemy_master_001 ~ enemy_master_006)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_001",
		"name": "钢铁先锋·马库斯",
		"title": "钢铁防线守卫",
		"level": 5,
		"faction": "steel",
		"difficulty": "easy",
		"traits": [
			{
				"id": "recruit_commander",
				"name": "新兵教官",
				"description": "所有友军防御+10%，部署冷却-5%",
				"effects": {"def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}
			}
		],
		"active_spells": [
			{
				"id": "iron_bulwark",
				"name": "钢铁壁垒",
				"description": "每28秒为自身施加20%最大生命值护盾",
				"effect": "energy_shield",
				"cooldown": 28.0,
				"params": {"shield_pct": 0.20}
			}
		],
		"passive_spells": [
			{
				"id": "steel_skin",
				"name": "钢铁之肤",
				"description": "所有友军获得12%额外护甲",
				"effect": "armor_boost",
				"params": {"bonus": 0.12}
			},
			{
				"id": "fortress_mind",
				"name": "堡垒思维",
				"description": "每当友军单位死亡时，获得5%最大生命值护盾",
				"effect": "death_shield",
				"params": {"shield_percent": 0.05}
			}
		],
		"equipment": {
			"phase_instrument": "pi_steel_02",
			"level": 5,
			"platforms": ["steel_fortress_basic", "steel_titan_basic"],
			"weapons": ["steel_machinegun_basic", "steel_cannon_basic"],
			"energy_cards": ["steel_energy_basic"]
		},
		"stats": {
			"max_hp": 2900,
			"attack_power": 36,
			"defense": 32,
			"energy_regen": 2.0,
			"unit_limit": 5
		}
	},
	{
		"id": "enemy_master_002",
		"name": "烈焰使者·伊格尼斯",
		"title": "火焰狂暴者",
		"level": 6,
		"faction": "flame",
		"difficulty": "easy",
		"traits": [
			{
				"id": "first_flame",
				"name": "初燃之心",
				"description": "攻击力+8%",
				"effects": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}
			}
		],
		"active_spells": [
			{
				"id": "napalm_explosion",
				"name": "烈焰风暴",
				"description": "每26秒对全体玩家单位造成火焰范围伤害",
				"effect": "napalm_explosion",
				"cooldown": 26.0,
				"params": {"damage_mult": 0.8}
			}
		],
		"passive_spells": [
			{
				"id": "burning_aura",
				"name": "燃烧光环",
				"description": "周围敌人每秒受到30点火焰伤害",
				"effect": "damage_aura",
				"params": {"damage": 30, "radius": 100}
			},
			{
				"id": "fire_adaptation",
				"name": "火焰适应",
				"description": "攻击力提升8%",
				"effect": "damage_boost_resistance",
				"params": {"boost": 0.08, "resistance": 0.3, "damage_type": "fire"}
			}
		],
		"equipment": {
			"phase_instrument": "pi_flame_02",
			"level": 6,
			"platforms": ["flame_raider_basic", "flame_siege_basic"],
			"weapons": ["flame_thrower_basic", "incendiary_mortar_basic"],
			"energy_cards": ["flame_energy_basic"]
		},
		"stats": {
			"max_hp": 2950,
			"attack_power": 37,
			"defense": 25,
			"energy_regen": 2.5,
			"unit_limit": 6
		}
	},
	{
		"id": "enemy_master_003",
		"name": "雷击者·沃尔特",
		"title": "闪电链大师",
		"level": 7,
		"faction": "thunder",
		"difficulty": "medium",
		"traits": [
			{
				"id": "first_thunder",
				"name": "初雷之印",
				"description": "暴击率+8%，闪避+5%",
				"effects": {"crit_chance": 0.08, "dodge_chance": 0.05}
			}
		],
		"active_spells": [
			{
				"id": "tesla_chain",
				"name": "雷霆连锁",
				"description": "每24秒释放连锁闪电，跳跃打击最多5个玩家单位",
				"effect": "tesla_chain",
				"cooldown": 24.0,
				"params": {"damage_mult": 0.9}
			}
		],
		"passive_spells": [
			{
				"id": "static_field",
				"name": "静电场",
				"description": "攻击时对目标周围造成30%溅射伤害",
				"effect": "splash_damage",
				"params": {"splash_percent": 0.3, "radius": 60}
			},
			{
				"id": "overcharge",
				"name": "过载",
				"description": "能量超过80%时，攻击速度提升40%",
				"effect": "high_energy_bonus",
				"params": {"threshold": 0.8, "attack_speed_boost": 0.4}
			}
		],
		"equipment": {
			"phase_instrument": "pi_thunder_02",
			"level": 7,
			"platforms": ["thunter_striker_basic", "thunter_sniper_basic"],
			"weapons": ["tesla_coil_basic", "railgun_basic"],
			"energy_cards": ["thunder_energy_basic"]
		},
		"stats": {
			"max_hp": 2950,
			"attack_power": 38,
			"defense": 25,
			"energy_regen": 3.0,
			"unit_limit": 5
		}
	},
	{
		"id": "enemy_master_004",
		"name": "虚空行者·奈克萨斯",
		"title": "时空操纵者",
		"level": 8,
		"faction": "void",
		"difficulty": "medium",
		"traits": [
			{
				"id": "void_sense",
				"name": "虚空初感",
				"description": "攻击力+8%",
				"effects": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}
			}
		],
		"active_spells": [
			{
				"id": "phase_debuff",
				"name": "相位移领域",
				"description": "每25秒扭曲玩家单位，降低其攻速与暴击",
				"effect": "darkness_debuff",
				"cooldown": 25.0,
				"params": {"attack_speed_penalty": 0.20, "crit_penalty": 0.15, "duration": 4.0}
			}
		],
		"passive_spells": [
			{
				"id": "entropy_aura",
				"name": "熵增光环",
				"description": "周围敌人持续失去生命值，最大值每秒减少1%",
				"effect": "max_hp_drain",
				"params": {"drain_percent": 0.01, "radius": 150}
			},
			{
				"id": "phase_shift",
				"name": "相位移",
				"description": "受到致命伤害时，有30%概率避免并瞬移到安全位置",
				"effect": "death_avoid_teleport",
				"params": {"chance": 0.3}
			}
		],
		"equipment": {
			"phase_instrument": "pi_void_02",
			"level": 8,
			"platforms": ["void_stealth_basic", "void_mage_basic"],
			"weapons": ["void_lance_basic", "gravity_well_basic"],
			"energy_cards": ["void_energy_basic"]
		},
		"stats": {
			"max_hp": 3000,
			"attack_power": 39,
			"defense": 29,
			"energy_regen": 2.8,
			"unit_limit": 5
		}
	},

	# ==================== Tier 2 - 中级相位师 (Lv10-14) ====================
	{
		"id": "enemy_master_005",
		"name": "钢铁元帅·克劳斯",
		"title": "不可破之盾",
		"level": 10,
		"faction": "steel",
		"difficulty": "medium",
		"traits": [
			{
				"id": "iron_wall_command",
				"name": "铁壁指挥",
				"description": "HP+15%，三维防御+10%",
				"effects": {"hp": 0.15, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}
			}
		],
		"active_spells": [
			{
				"id": "reinforcement_deploy",
				"name": "钢铁援军",
				"description": "每22秒召唤一批友军单位增援战场",
				"effect": "summon_reinforcement",
				"cooldown": 22.0
			}
		],
		"passive_spells": [
			{
				"id": "formation_master",
				"name": "阵型大师",
				"description": "每3个相邻友军提供20%伤害加成",
				"effect": "formation_bonus",
				"params": {"adjacent_count": 3, "damage_boost": 0.2}
			},
			{
				"id": "siege_breaker",
				"name": "攻城破坏者",
				"description": "对建筑类目标造成50%额外伤害",
				"effect": "damage_vs_building",
				"params": {"bonus_damage": 0.5}
			}
		],
		"equipment": {
			"phase_instrument": "pi_steel_03",
			"level": 10,
			"platforms": ["ww1_boss_av7", "ww1_boss_av7", "ww1_arm_rolls_e", "ww1_inf_storm_e"],
			"weapons": ["steel_minigun_advanced", "steel_railcannon_advanced"],
			"energy_cards": ["steel_energy_advanced"]
		},
		"stats": {
			"max_hp": 3100,
			"attack_power": 41,
			"defense": 35,
			"energy_regen": 2.5,
			"unit_limit": 7
		}
	},
	{
		"id": "enemy_master_006",
		"name": "炎魔女王·赫卡特",
		"title": "毁灭之焰",
		"level": 12,
		"faction": "flame",
		"difficulty": "medium",
		"traits": [
			{
				"id": "flame_authority",
				"name": "炎之权柄",
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [
			{
				"id": "inferno_explosion",
				"name": "地狱烈焰",
				"description": "每20秒引爆全场，对所有玩家单位造成烈焰伤害",
				"effect": "hellfire_explosion",
				"cooldown": 20.0,
				"params": {"damage_mult": 1.0}
			}
		],
		"passive_spells": [
			{
				"id": "eternal_flame",
				"name": "永恒之火",
				"description": "友军单位死亡时爆炸，对周围造成200伤害",
				"effect": "death_explosion",
				"params": {"damage": 200, "radius": 100}
			},
			{
				"id": "heat_wave",
				"name": "热浪",
				"description": "战斗每进行10秒，所有友军攻击力提升10%",
				"effect": "scaling_damage",
				"params": {"interval": 10.0, "boost_per_stack": 0.1, "max_stacks": 5}
			}
		],
		"equipment": {
			"phase_instrument": "pi_flame_03",
			"level": 12,
			"platforms": ["ww1_boss_av7", "ww1_arm_rolls_e", "ww1_arm_rolls_e", "ww1_inf_storm_e"],
			"weapons": ["flame_thrower_advanced", "incendiary_cannon_advanced"],
			"energy_cards": ["flame_energy_advanced"]
		},
		"stats": {
			"max_hp": 3400,
			"attack_power": 48,
			"defense": 23,
			"energy_regen": 3.0,
			"unit_limit": 7
		}
	},
]
