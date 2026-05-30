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
				"effects": {"defense_boost": 0.10, "deploy_cooldown_reduction": 0.05}
			}
		],
		"active_spells": [
			{
				"id": "steel_wall_summon",
				"name": "钢铁壁垒",
				"description": "召唤3个钢铁壁垒单位，每个拥有800血量和50防御",
				"cooldown": 15.0,
				"mana_cost": 80,
				"effect": "summon_units",
				"params": {"count": 3, "unit_type": "steel_wall", "hp": 800, "defense": 50}
			},
			{
				"id": "armor_break",
				"name": "破甲冲击",
				"description": "对前方扇形区域造成200伤害并降低30%防御，持续5秒",
				"cooldown": 12.0,
				"mana_cost": 60,
				"effect": "damage_debuff",
				"params": {"damage": 200, "defense_reduction": 0.3, "duration": 5.0, "angle": 90}
			}
		],
		"passive_spells": [
			{
				"id": "steel_skin",
				"name": "钢铁之肤",
				"description": "所有友军获得15%额外护甲",
				"effect": "armor_boost",
				"params": {"bonus": 0.15}
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
			"phase_instrument": "steel_guardian_mk1",
			"level": 5,
			"platforms": ["steel_fortress_basic", "steel_titan_basic"],
			"weapons": ["steel_machinegun_basic", "steel_cannon_basic"],
			"energy_cards": ["steel_energy_basic"]
		},
		"stats": {
			"max_hp": 1500,
			"attack_power": 120,
			"defense": 80,
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
				"description": "攻击力+10%，火焰伤害额外+10%",
				"effects": {"attack_boost": 0.10, "fire_damage_boost": 0.10}
			}
		],
		"active_spells": [
			{
				"id": "fire_storm",
				"name": "烈焰风暴",
				"description": "在指定区域召唤火焰风暴，每秒造成150伤害，持续6秒",
				"cooldown": 18.0,
				"mana_cost": 100,
				"effect": "aoe_damage_over_time",
				"params": {"damage": 150, "duration": 6.0, "radius": 120}
			},
			{
				"id": "explosive_charge",
				"name": "爆炸冲锋",
				"description": "所有己方单位获得爆炸死亡效果，死亡时对周围造成100伤害",
				"cooldown": 20.0,
				"mana_cost": 90,
				"effect": "death_explosion_buff",
				"params": {"damage": 100, "radius": 80, "duration": 8.0}
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
				"description": "火焰伤害提升20%，受到的火焰伤害减少30%",
				"effect": "damage_boost_resistance",
				"params": {"boost": 0.2, "resistance": 0.3, "damage_type": "fire"}
			}
		],
		"equipment": {
			"phase_instrument": "flame_destroyer_mk1",
			"level": 6,
			"platforms": ["flame_raider_basic", "flame_siege_basic"],
			"weapons": ["flame_thrower_basic", "incendiary_mortar_basic"],
			"energy_cards": ["flame_energy_basic"]
		},
		"stats": {
			"max_hp": 1200,
			"attack_power": 150,
			"defense": 50,
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
				"description": "攻击速度+10%，暴击率+5%",
				"effects": {"attack_speed_boost": 0.10, "crit_chance": 0.05}
			}
		],
		"active_spells": [
			{
				"id": "chain_lightning",
				"name": "连锁闪电",
				"description": "释放闪电链，弹射4次，每次造成250伤害",
				"cooldown": 14.0,
				"mana_cost": 85,
				"effect": "chain_damage",
				"params": {"damage": 250, "bounces": 4, "range": 200}
			},
			{
				"id": "thunder_strike",
				"name": "雷霆一击",
				"description": "对单个目标造成400伤害并眩晕2秒",
				"cooldown": 16.0,
				"mana_cost": 110,
				"effect": "single_damage_stun",
				"params": {"damage": 400, "stun_duration": 2.0}
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
			"phase_instrument": "thunder_storm_mk1",
			"level": 7,
			"platforms": ["thunter_striker_basic", "thunter_sniper_basic"],
			"weapons": ["tesla_coil_basic", "railgun_basic"],
			"energy_cards": ["thunder_energy_basic"]
		},
		"stats": {
			"max_hp": 1100,
			"attack_power": 160,
			"defense": 45,
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
				"description": "法术强度+15%，攻击附带3%能量吸取",
				"effects": {"magic_power_boost": 0.15, "energy_drain_on_hit": 0.03}
			}
		],
		"active_spells": [
			{
				"id": "time_warp",
				"name": "时间扭曲",
				"description": "使所有敌军速度降低50%，持续5秒",
				"cooldown": 22.0,
				"mana_cost": 120,
				"effect": "speed_debuff",
				"params": {"slow_percent": 0.5, "duration": 5.0}
			},
			{
				"id": "void_tear",
				"name": "虚空撕裂",
				"description": "在战场上开启3个虚空传送门，传送己方单位",
				"cooldown": 25.0,
				"mana_cost": 100,
				"effect": "teleport_gates",
				"params": {"gate_count": 3, "duration": 10.0}
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
			"phase_instrument": "void_walker_mk1",
			"level": 8,
			"platforms": ["void_stealth_basic", "void_mage_basic"],
			"weapons": ["void_lance_basic", "gravity_well_basic"],
			"energy_cards": ["void_energy_basic"]
		},
		"stats": {
			"max_hp": 1300,
			"attack_power": 140,
			"defense": 60,
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
				"description": "防御+20%，单位上限+1",
				"effects": {"defense_boost": 0.20, "unit_limit_bonus": 1}
			}
		],
		"active_spells": [
			{
				"id": "iron_dome",
				"name": "钢铁穹顶",
				"description": "为己方基地施加无敌护盾，吸收3000点伤害，持续8秒",
				"cooldown": 30.0,
				"mana_cost": 150,
				"effect": "shield_base",
				"params": {"shield_amount": 3000, "duration": 8.0}
			},
			{
				"id": "reinforcement_call",
				"name": "增援呼叫",
				"description": "立即召唤4个精锐钢铁战士",
				"cooldown": 22.0,
				"mana_cost": 100,
				"effect": "summon_elites",
				"params": {"count": 4, "unit_type": "steel_elite"}
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
			"phase_instrument": "steel_guardian_mk2",
			"level": 10,
			"platforms": ["steel_fortress_advanced", "steel_titan_advanced"],
			"weapons": ["steel_minigun_advanced", "steel_railcannon_advanced"],
			"energy_cards": ["steel_energy_advanced"]
		},
		"stats": {
			"max_hp": 2200,
			"attack_power": 200,
			"defense": 120,
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
				"description": "火焰伤害+20%，燃烧持续时间+2秒",
				"effects": {"fire_damage_boost": 0.20, "burn_duration_bonus": 2.0}
			}
		],
		"active_spells": [
			{
				"id": "meteor_swarm",
				"name": "流星群",
				"description": "召唤4颗流星，每颗造成350伤害并点燃区域",
				"cooldown": 25.0,
				"mana_cost": 180,
				"effect": "meteor_rain",
				"params": {"count": 4, "damage": 350, "burn_duration": 4.0}
			},
			{
				"id": "phoenix_rebirth",
				"name": "凤凰重生",
				"description": "复活所有死亡的友军单位，恢复50%生命值",
				"cooldown": 45.0,
				"mana_cost": 200,
				"effect": "mass_resurrect",
				"params": {"hp_percent": 0.5}
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
			"phase_instrument": "flame_destroyer_mk2",
			"level": 12,
			"platforms": ["flame_raider_advanced", "flame_siege_advanced"],
			"weapons": ["flame_thrower_advanced", "incendiary_cannon_advanced"],
			"energy_cards": ["flame_energy_advanced"]
		},
		"stats": {
			"max_hp": 2000,
			"attack_power": 260,
			"defense": 70,
			"energy_regen": 3.0,
			"unit_limit": 7
		}
	},
]
