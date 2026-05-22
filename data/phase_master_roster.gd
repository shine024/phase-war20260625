extends RefCounted
class_name PhaseMasterRoster
## 统一相位师名册 -- 50名相位师（20我方/中立 + 30敌方）
##
## 用于排行榜显示（排名、名称、势力、战力）和战斗力评估。
## 相位师没有"等级"概念，能力完全由相位仪+刻印+技能决定。
##
## 我方相位师(#001~#020)：包含完整技能/特质/装备数据
## 敌方相位师(#021~#050)：从enemy_phase_masters.gd转换，保留完整数据
##   额外字段 source_id 关联原始数据，difficulty 用于战斗匹配
##
## 势力映射（敌方旧势力->新势力）：
##   steel->iron_bastion | flame->crimson_blade | thunder->sun_forge | void->void_walkers
##   混合势力保留原名 | neutral/ashen_order/frost_crown 为新增势力
## 星级分界：1*(0-250) 2*(250-600) 3*(600-1200) 4*(1200-2200) 5*(2200-3800) 6*(3800-6000) 7*(6000+)

const ALL_MASTERS: Array[Dictionary] = [
{
  "id": "player_master_001",
  "name": "初始相位师·艾拉",
  "title": "觉醒者",
  "faction": "neutral",
  "side": "player",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "newbie_luck",
      "name": "新手好运",
      "description": "首次通关每关额外获得10%资源",
    }
  ],
  "active_spells": [
{
      "id": "basic_strike",
      "name": "相位冲击",
      "cooldown": 8.0,
      "mana_cost": 30,
      "effect": "single_damage",
      "params": {
        "damage": 150,
      },
    }
  ],
  "passive_spells": [
{
      "id": "energy_saver",
      "name": "节能模式",
      "effect": "deploy_cost_reduction",
      "params": {
        "reduction": 0.1,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_basic"
    ],
    "weapons": [
      "steel_machinegun_basic"
    ],
    "energy_cards": [
      "energy_start_1"
    ],
  },
},
{
  "id": "player_master_002",
  "name": "铁壁守卫·格伦",
  "title": "磐石之心",
  "faction": "iron_bastion",
  "side": "player",
  "phase_instrument": "steel_guardian_mk2",
  "unit_limit": 6,
  "engraved_affixes": [
{
      "engraving_id": "trench_armor",
      "progress": 0.5,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "iron_wall_basic",
      "name": "铁壁之心",
      "description": "防御+15%，友军5%伤害减免",
    }
  ],
  "active_spells": [
{
      "id": "steel_barrier",
      "name": "钢铁屏障",
      "cooldown": 20.0,
      "mana_cost": 80,
      "effect": "create_barrier",
      "params": {
        "duration": 8.0,
      },
    },
{
      "id": "repair_nanites",
      "name": "修复纳米虫",
      "cooldown": 25.0,
      "mana_cost": 60,
      "effect": "heal_all",
      "params": {
        "heal_percent": 0.15,
      },
    }
  ],
  "passive_spells": [
{
      "id": "fortify",
      "name": "坚守",
      "effect": "static_defense_boost",
      "params": {
        "boost": 0.1,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_basic",
      "steel_titan_basic"
    ],
    "weapons": [
      "steel_machinegun_basic",
      "steel_cannon_basic"
    ],
    "energy_cards": [
      "energy_start_4"
    ],
  },
},
{
  "id": "player_master_003",
  "name": "烈焰舞者·莉娜",
  "title": "灼热之焰",
  "faction": "crimson_blade",
  "side": "player",
  "phase_instrument": "flame_destroyer_mk1",
  "unit_limit": 6,
  "engraved_affixes": [
{
      "engraving_id": "radiation_penetration",
      "progress": 0.3,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "flame_heart",
      "name": "炎心",
      "description": "火焰伤害+15%，攻击附带轻微燃烧",
    }
  ],
  "active_spells": [
{
      "id": "fire_bolt",
      "name": "火球术",
      "cooldown": 10.0,
      "mana_cost": 50,
      "effect": "fireball",
      "params": {
        "damage": 200,
        "burn_duration": 3.0,
      },
    },
{
      "id": "inferno_wall",
      "name": "烈焰之墙",
      "cooldown": 18.0,
      "mana_cost": 90,
      "effect": "fire_wall",
      "params": {
        "damage": 180,
        "duration": 5.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "burning_spirit",
      "name": "燃烧之魂",
      "effect": "kill_explosion",
      "params": {
        "chance": 0.2,
        "damage": 80,
        "radius": 60,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_basic"
    ],
    "weapons": [
      "flame_thrower_basic",
      "incendiary_mortar_basic"
    ],
    "energy_cards": [
      "energy_start_7"
    ],
  },
},
{
  "id": "player_master_004",
  "name": "雷鸣猎手·凯恩",
  "title": "闪电追踪者",
  "faction": "sun_forge",
  "side": "player",
  "phase_instrument": "thunder_storm_mk1",
  "unit_limit": 5,
  "engraved_affixes": [
{
      "engraving_id": "chain_conduct",
      "progress": 0.4,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "storm_eye",
      "name": "风暴之眼",
      "description": "暴击率+8%，暴击伤害+20%",
    }
  ],
  "active_spells": [
{
      "id": "lightning_bolt",
      "name": "闪电箭",
      "cooldown": 8.0,
      "mana_cost": 45,
      "effect": "single_lightning",
      "params": {
        "damage": 250,
        "stun_chance": 0.3,
      },
    },
{
      "id": "static_trap",
      "name": "静电陷阱",
      "cooldown": 15.0,
      "mana_cost": 70,
      "effect": "trap_aoe",
      "params": {
        "damage": 180,
        "slow_percent": 0.3,
      },
    }
  ],
  "passive_spells": [
{
      "id": "static_charge",
      "name": "静电蓄能",
      "effect": "attack_speed_stack",
      "params": {
        "per_hit": 0.05,
        "max_stacks": 10,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_basic"
    ],
    "weapons": [
      "tesla_coil_basic"
    ],
    "energy_cards": [
      "energy_start_5"
    ],
  },
},
{
  "id": "player_master_005",
  "name": "虚空窥视者·莫恩",
  "title": "维度旅行者",
  "faction": "void_walkers",
  "side": "player",
  "phase_instrument": "void_walker_mk1",
  "unit_limit": 5,
  "engraved_affixes": [
{
      "engraving_id": "quantum_drain",
      "progress": 0.6,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "void_insight",
      "name": "虚空洞察",
      "description": "法术强度+12%，能量吸取+3%",
    }
  ],
  "active_spells": [
{
      "id": "phase_shift_p",
      "name": "相位转移",
      "cooldown": 12.0,
      "mana_cost": 40,
      "effect": "teleport_ally",
    },
{
      "id": "time_dilation",
      "name": "时间膨胀",
      "cooldown": 20.0,
      "mana_cost": 80,
      "effect": "slow_all",
      "params": {
        "slow_percent": 0.3,
        "duration": 4.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "void_lurk",
      "name": "虚空潜伏",
      "effect": "stealth_bonus",
      "params": {
        "bonus": 0.15,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_basic"
    ],
    "weapons": [
      "void_lance_basic"
    ],
    "energy_cards": [
      "energy_start_2"
    ],
  },
},
{
  "id": "player_master_006",
  "name": "灰烬贤者·维恩",
  "title": "余烬守望",
  "faction": "ashen_order",
  "side": "player",
  "phase_instrument": "steel_guardian_mk2",
  "unit_limit": 7,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 0.8,
      "active": true,
    },
{
      "engraving_id": "trench_armor",
      "progress": 0.4,
      "active": false,
    }
  ],
  "traits": [
{
      "id": "ashen_persistence",
      "name": "灰烬不灭",
      "description": "友军死亡时3秒后恢复20%HP重生一次",
    }
  ],
  "active_spells": [
{
      "id": "ash_storm",
      "name": "灰烬风暴",
      "cooldown": 22.0,
      "mana_cost": 100,
      "effect": "aoe_dot",
      "params": {
        "damage": 100,
        "duration": 6.0,
      },
    },
{
      "id": "ember_shield",
      "name": "余烬护盾",
      "cooldown": 28.0,
      "mana_cost": 80,
      "effect": "shield_break_damage",
      "params": {
        "shield_amount": 300,
        "break_damage": 100,
      },
    }
  ],
  "passive_spells": [
{
      "id": "slow_burn",
      "name": "缓燃",
      "effect": "damage_reduction",
      "params": {
        "reduction": 0.08,
      },
    },
{
      "id": "ash_recall",
      "name": "灰烬召回",
      "effect": "auto_heal_lowest",
      "params": {
        "interval": 30.0,
        "heal_percent": 0.1,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_basic",
      "steel_titan_basic"
    ],
    "weapons": [
      "steel_machinegun_basic",
      "steel_cannon_basic"
    ],
    "energy_cards": [
      "energy_start_4",
      "energy_start_1"
    ],
  },
},
{
  "id": "player_master_007",
  "name": "赤刃战士·绯樱",
  "title": "血色锋芒",
  "faction": "crimson_blade",
  "side": "player",
  "phase_instrument": "flame_destroyer_mk2",
  "unit_limit": 6,
  "engraved_affixes": [
{
      "engraving_id": "radiation_penetration",
      "progress": 0.7,
      "active": true,
    },
{
      "engraving_id": "void_siphon",
      "progress": 0.2,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "crimson_blade_trait",
      "name": "赤刃本能",
      "description": "攻击力+18%，击杀时攻速+5%（可叠加8层）",
    }
  ],
  "active_spells": [
{
      "id": "crimson_slash",
      "name": "赤刃斩",
      "cooldown": 12.0,
      "mana_cost": 70,
      "effect": "cone_execute",
      "params": {
        "damage": 350,
      },
    },
{
      "id": "blood_fury",
      "name": "血怒",
      "cooldown": 25.0,
      "mana_cost": 100,
      "effect": "team_buff",
      "params": {
        "attack_speed_boost": 0.4,
        "duration": 6.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "lifesteal_aura",
      "name": "吸血光环",
      "effect": "lifesteal",
      "params": {
        "percent": 0.08,
      },
    },
{
      "id": "berserk",
      "name": "狂化",
      "effect": "low_hp_atk_boost",
      "params": {
        "threshold": 0.4,
        "boost": 0.25,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_basic",
      "flame_raider_advanced"
    ],
    "weapons": [
      "flame_thrower_basic",
      "flame_thrower_advanced"
    ],
    "energy_cards": [
      "energy_start_7",
      "flame_energy_basic"
    ],
  },
},
{
  "id": "player_master_008",
  "name": "铁壁将领·奥利弗",
  "title": "不破之阵",
  "faction": "iron_bastion",
  "side": "player",
  "phase_instrument": "steel_guardian_mk3",
  "unit_limit": 8,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "trench_armor",
      "progress": 0.9,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "iron_command",
      "name": "铁壁指挥",
      "description": "防御+20%，每有1个存活友军全体防御+3%",
    }
  ],
  "active_spells": [
{
      "id": "iron_dome_p",
      "name": "铁穹",
      "cooldown": 35.0,
      "mana_cost": 120,
      "effect": "base_shield",
      "params": {
        "shield_amount": 2000,
      },
    },
{
      "id": "rally",
      "name": "集结号",
      "cooldown": 30.0,
      "mana_cost": 100,
      "effect": "rally_buff",
      "params": {
        "all_stat_boost": 0.15,
      },
    },
{
      "id": "artillery_strike",
      "name": "火力覆盖",
      "cooldown": 25.0,
      "mana_cost": 140,
      "effect": "artillery_barrage",
      "params": {
        "damage_per_hit": 300,
        "hits": 5,
      },
    }
  ],
  "passive_spells": [
{
      "id": "formation_bonus_p",
      "name": "方阵",
      "effect": "adjacent_defense",
      "params": {
        "bonus": 0.1,
      },
    },
{
      "id": "siege_resist_p",
      "name": "攻城抵抗",
      "effect": "damage_reduction_vs_type",
      "params": {
        "reduction": 0.3,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_basic",
      "steel_titan_basic",
      "steel_fortress_advanced"
    ],
    "weapons": [
      "steel_machinegun_basic",
      "steel_cannon_basic",
      "steel_minigun_advanced"
    ],
    "energy_cards": [
      "energy_start_5",
      "steel_energy_basic"
    ],
  },
},
{
  "id": "player_master_009",
  "name": "霜冠法师·艾莎",
  "title": "凛冬之息",
  "faction": "frost_crown",
  "side": "player",
  "phase_instrument": "thunder_storm_mk2",
  "unit_limit": 6,
  "engraved_affixes": [
{
      "engraving_id": "emp_pulse",
      "progress": 0.6,
      "active": true,
    },
{
      "engraving_id": "timeline_collapse",
      "progress": 0.2,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "frost_heart",
      "name": "冰霜之心",
      "description": "攻击附带减速15%持续2秒",
    }
  ],
  "active_spells": [
{
      "id": "blizzard",
      "name": "暴风雪",
      "cooldown": 24.0,
      "mana_cost": 110,
      "effect": "aoe_slow_damage",
      "params": {
        "damage": 120,
        "slow": 0.4,
        "duration": 6.0,
      },
    },
{
      "id": "ice_wall",
      "name": "冰墙",
      "cooldown": 16.0,
      "mana_cost": 60,
      "effect": "ice_barrier",
      "params": {
        "duration": 8.0,
      },
    },
{
      "id": "frozen_orb",
      "name": "寒冰宝珠",
      "cooldown": 18.0,
      "mana_cost": 90,
      "effect": "projectile_freeze",
      "params": {
        "damage": 300,
        "freeze_duration": 2.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "cold_aura",
      "name": "寒气",
      "effect": "slow_aura",
      "params": {
        "attack_speed_slow": 0.15,
      },
    },
{
      "id": "shatter",
      "name": "碎冰",
      "effect": "frozen_vulnerability",
      "params": {
        "damage_boost": 0.3,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_basic",
      "thunter_sniper_basic"
    ],
    "weapons": [
      "tesla_coil_basic",
      "railgun_basic"
    ],
    "energy_cards": [
      "energy_start_4",
      "thunder_energy_basic"
    ],
  },
},
{
  "id": "player_master_010",
  "name": "阳光铸师·赫利俄斯",
  "title": "光辉锻造者",
  "faction": "sun_forge",
  "side": "player",
  "phase_instrument": "thunder_storm_mk3",
  "unit_limit": 7,
  "engraved_affixes": [
{
      "engraving_id": "chain_conduct",
      "progress": 0.9,
      "active": true,
    },
{
      "engraving_id": "static_charge",
      "progress": 0.5,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "solar_radiance",
      "name": "太阳光辉",
      "description": "能量回复+20%，主动技能伤害+10%",
    }
  ],
  "active_spells": [
{
      "id": "solar_beam",
      "name": "太阳光束",
      "cooldown": 15.0,
      "mana_cost": 80,
      "effect": "piercing_beam",
      "params": {
        "damage": 400,
      },
    },
{
      "id": "radiance_burst",
      "name": "光辉爆发",
      "cooldown": 20.0,
      "mana_cost": 100,
      "effect": "aoe_heal_damage",
      "params": {
        "damage": 250,
        "heal": 100,
      },
    }
  ],
  "passive_spells": [
{
      "id": "energy_link",
      "name": "能量链接",
      "effect": "energy_share",
      "params": {
        "share_percent": 0.1,
      },
    },
{
      "id": "radiant_armor",
      "name": "光辉护甲",
      "effect": "hp_regen",
      "params": {
        "percent_per_sec": 0.01,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_basic",
      "thunter_striker_advanced",
      "thunter_sniper_advanced"
    ],
    "weapons": [
      "tesla_coil_basic",
      "tesla_coil_advanced",
      "railgun_expert"
    ],
    "energy_cards": [
      "energy_start_5",
      "energy_start_6"
    ],
  },
},
{
  "id": "player_master_011",
  "name": "虚空编织者·洛克",
  "title": "命运之线",
  "faction": "void_walkers",
  "side": "player",
  "phase_instrument": "void_walker_mk2",
  "unit_limit": 6,
  "engraved_affixes": [
{
      "engraving_id": "quantum_drain",
      "progress": 0.8,
      "active": true,
    },
{
      "engraving_id": "dimension_shift",
      "progress": 0.4,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "fate_weave",
      "name": "命运编织",
      "description": "技能冷却-10%，法术强度+15%",
    }
  ],
  "active_spells": [
{
      "id": "dimension_door",
      "name": "维度之门",
      "cooldown": 30.0,
      "mana_cost": 120,
      "effect": "mass_teleport",
    },
{
      "id": "entropy_field",
      "name": "熵增力场",
      "cooldown": 25.0,
      "mana_cost": 100,
      "effect": "stat_drain_zone",
      "params": {
        "drain_per_sec": 0.03,
        "duration": 6.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "phase_shift_passive",
      "name": "相位飘移",
      "effect": "periodic_dodge",
      "params": {
        "interval": 15.0,
      },
    },
{
      "id": "void_regen",
      "name": "虚空再生",
      "effect": "zone_heal_boost",
      "params": {
        "boost": 2.0,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_basic",
      "void_stealth_advanced",
      "void_mage_basic"
    ],
    "weapons": [
      "void_lance_basic",
      "void_lance_advanced",
      "gravity_well_basic"
    ],
    "energy_cards": [
      "energy_start_2",
      "void_energy_basic"
    ],
  },
},
{
  "id": "player_master_012",
  "name": "灰烬使者·诺亚",
  "title": "末日预言",
  "faction": "ashen_order",
  "side": "player",
  "phase_instrument": "hybrid_steel_flame_mk1",
  "unit_limit": 7,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "radiation_penetration",
      "progress": 0.5,
      "active": true,
    },
{
      "engraving_id": "void_siphon",
      "progress": 0.3,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "doomsayer",
      "name": "末日预言",
      "description": "战斗时间越长全队伤害越高（每20秒+10%，最高50%）",
    }
  ],
  "active_spells": [
{
      "id": "ash_judgment",
      "name": "灰烬审判",
      "cooldown": 30.0,
      "mana_cost": 150,
      "effect": "execution_aoe",
      "params": {
        "base_damage": 200,
      },
    },
{
      "id": "rebirth_flame",
      "name": "重生之焰",
      "cooldown": 60.0,
      "mana_cost": 200,
      "effect": "mass_resurrect",
      "params": {
        "hp_percent": 0.3,
      },
    }
  ],
  "passive_spells": [
{
      "id": "last_stand_p",
      "name": "最后立场",
      "effect": "last_unit_buff",
      "params": {
        "boost": 0.5,
      },
    },
{
      "id": "ash_economy",
      "name": "灰烬经济",
      "effect": "kill_energy",
      "params": {
        "energy_per_kill": 5,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_advanced",
      "flame_raider_advanced"
    ],
    "weapons": [
      "steel_gatling_expert",
      "flame_thrower_advanced"
    ],
    "energy_cards": [
      "energy_start_5",
      "hybrid_energy_basic"
    ],
  },
},
{
  "id": "player_master_013",
  "name": "铸锤大师·托林",
  "title": "百炼成钢",
  "faction": "iron_bastion",
  "side": "player",
  "phase_instrument": "steel_guardian_mk4",
  "unit_limit": 9,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "trench_armor",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "steel_production",
      "progress": 0.7,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "master_forge",
      "name": "大师锻造",
      "description": "防御+25%，每20秒自动为友军附加+5%全属性",
    }
  ],
  "active_spells": [
{
      "id": "forge_hammer_p",
      "name": "锻锤重击",
      "cooldown": 22.0,
      "mana_cost": 130,
      "effect": "hammer_smash",
      "params": {
        "damage": 450,
        "stun_duration": 3.0,
      },
    },
{
      "id": "iron_legion",
      "name": "钢铁军团",
      "cooldown": 35.0,
      "mana_cost": 180,
      "effect": "summon_units",
      "params": {
        "count": 5,
        "unit_type": "steel_elite",
      },
    },
{
      "id": "fortress_mode_p",
      "name": "要塞模式",
      "cooldown": 40.0,
      "mana_cost": 200,
      "effect": "mass_buff_shield",
      "params": {
        "defense_boost": 0.5,
        "shield_amount": 1500,
      },
    }
  ],
  "passive_spells": [
{
      "id": "formation_bonus_p2",
      "name": "方阵",
      "effect": "adjacent_defense",
      "params": {
        "bonus": 0.1,
      },
    },
{
      "id": "siege_resist_p2",
      "name": "攻城抵抗",
      "effect": "damage_reduction_vs_type",
      "params": {
        "reduction": 0.3,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_basic",
      "steel_titan_basic",
      "steel_fortress_advanced"
    ],
    "weapons": [
      "steel_machinegun_basic",
      "steel_cannon_basic",
      "steel_gatling_expert",
      "steel_artillery_expert"
    ],
    "energy_cards": [
      "energy_start_5",
      "steel_energy_basic",
      "steel_energy_expert"
    ],
  },
},
{
  "id": "player_master_014",
  "name": "炎凰·苏菲亚",
  "title": "不灭之翼",
  "faction": "crimson_blade",
  "side": "player",
  "phase_instrument": "flame_destroyer_mk3",
  "unit_limit": 8,
  "engraved_affixes": [
{
      "engraving_id": "radiation_penetration",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "radiation_burn",
      "progress": 0.6,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "phoenix_will",
      "name": "凤凰意志",
      "description": "火焰伤害+25%；友军首次死亡时自动复活(30%HP)",
    }
  ],
  "active_spells": [
{
      "id": "pyroblast_p",
      "name": "炎爆术",
      "cooldown": 18.0,
      "mana_cost": 160,
      "effect": "pyroblast",
      "params": {
        "damage": 600,
        "radius": 100,
      },
    },
{
      "id": "phoenix_resurrect",
      "name": "浴火重生",
      "cooldown": 90.0,
      "mana_cost": 250,
      "effect": "mass_resurrect",
      "params": {
        "hp_percent": 0.5,
      },
    }
  ],
  "passive_spells": [
{
      "id": "fire_mastery_p",
      "name": "火焰精通",
      "effect": "elemental_mastery",
      "params": {
        "element": "fire",
        "damage_boost": 0.35,
      },
    },
{
      "id": "ignite_p",
      "name": "点燃",
      "effect": "ignite_chance",
      "params": {
        "chance": 0.2,
        "burn_damage": 45,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_basic",
      "flame_raider_advanced",
      "flame_raider_expert"
    ],
    "weapons": [
      "flame_thrower_basic",
      "flame_thrower_advanced",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "energy_start_7",
      "flame_energy_basic",
      "flame_energy_expert"
    ],
  },
},
{
  "id": "player_master_015",
  "name": "霜将·伊万",
  "title": "永冻之壁",
  "faction": "frost_crown",
  "side": "player",
  "phase_instrument": "steel_guardian_mk4",
  "unit_limit": 8,
  "engraved_affixes": [
{
      "engraving_id": "emp_pulse",
      "progress": 0.9,
      "active": true,
    },
{
      "engraving_id": "timeline_collapse",
      "progress": 0.7,
      "active": true,
    },
{
      "engraving_id": "trench_armor",
      "progress": 0.5,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "permafrost",
      "name": "永久冻土",
      "description": "友军被攻击时减速攻击者15%（叠加到45%）",
    }
  ],
  "active_spells": [
{
      "id": "absolute_zero",
      "name": "绝对零度",
      "cooldown": 35.0,
      "mana_cost": 150,
      "effect": "freeze_all",
      "params": {
        "duration": 3.0,
      },
    },
{
      "id": "glacier_wall",
      "name": "冰川壁垒",
      "cooldown": 20.0,
      "mana_cost": 100,
      "effect": "ice_barrier",
      "params": {
        "duration": 12.0,
        "hp": 3000,
      },
    }
  ],
  "passive_spells": [
{
      "id": "frost_armor",
      "name": "霜甲",
      "effect": "thorn_slow",
      "params": {
        "slow": 0.15,
        "damage": 30,
      },
    },
{
      "id": "cold_stare",
      "name": "冰凝视线",
      "effect": "freeze_chance",
      "params": {
        "chance": 0.05,
        "duration": 1.5,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_advanced",
      "steel_fortress_expert",
      "thunter_sniper_advanced"
    ],
    "weapons": [
      "steel_minigun_advanced",
      "railgun_expert",
      "sniper_basic"
    ],
    "energy_cards": [
      "energy_start_5",
      "steel_energy_expert"
    ],
  },
},
{
  "id": "player_master_016",
  "name": "阳光先锋·阿里斯",
  "title": "晨曦之矛",
  "faction": "sun_forge",
  "side": "player",
  "phase_instrument": "thunder_storm_mk4",
  "unit_limit": 7,
  "engraved_affixes": [
{
      "engraving_id": "chain_conduct",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "static_charge",
      "progress": 0.8,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "dawn_strike",
      "name": "晨曦突袭",
      "description": "开场10秒内攻击+50%，能量回复+30%",
    }
  ],
  "active_spells": [
{
      "id": "solar_flare_p",
      "name": "太阳耀斑",
      "cooldown": 25.0,
      "mana_cost": 120,
      "effect": "aoe_blind",
      "params": {
        "damage": 350,
        "blind_duration": 4.0,
      },
    },
{
      "id": "lightning_rain",
      "name": "雷雨倾泻",
      "cooldown": 20.0,
      "mana_cost": 100,
      "effect": "random_lightning",
      "params": {
        "damage": 180,
        "count": 8,
      },
    }
  ],
  "passive_spells": [
{
      "id": "first_light",
      "name": "第一缕光",
      "effect": "first_strike_bonus",
      "params": {
        "damage_boost": 0.3,
      },
    },
{
      "id": "overcharge_passive",
      "name": "过载充能",
      "effect": "energy_overflow",
      "params": {
        "threshold": 90,
        "atk_boost": 0.2,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_advanced",
      "thunter_striker_expert"
    ],
    "weapons": [
      "tesla_coil_advanced",
      "railgun_expert",
      "thunder_lance_expert"
    ],
    "energy_cards": [
      "energy_start_6",
      "thunder_energy_basic",
      "thunder_energy_expert"
    ],
  },
},
{
  "id": "player_master_017",
  "name": "虚空行者·泽恩",
  "title": "暗影步",
  "faction": "void_walkers",
  "side": "player",
  "phase_instrument": "void_walker_mk3",
  "unit_limit": 7,
  "engraved_affixes": [
{
      "engraving_id": "quantum_drain",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "dimension_shift",
      "progress": 0.8,
      "active": true,
    },
{
      "engraving_id": "timeline_collapse",
      "progress": 0.5,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "shadow_step",
      "name": "暗影步",
      "description": "单位部署后2秒内隐身；首次攻击伤害+40%",
    }
  ],
  "active_spells": [
{
      "id": "shadow_assault",
      "name": "暗影突袭",
      "cooldown": 15.0,
      "mana_cost": 90,
      "effect": "teleport_strike",
      "params": {
        "damage": 500,
      },
    },
{
      "id": "void_collapse",
      "name": "虚空坍缩",
      "cooldown": 30.0,
      "mana_cost": 140,
      "effect": "black_hole",
      "params": {
        "damage": 350,
        "pull_range": 120,
        "duration": 3.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "void_stealth",
      "name": "虚空隐匿",
      "effect": "stealth_duration",
      "params": {
        "duration_bonus": 2.0,
      },
    },
{
      "id": "dim_shift",
      "name": "维度偏移",
      "effect": "damage_reduction",
      "params": {
        "reduction": 0.15,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_advanced",
      "void_stealth_expert",
      "void_mage_advanced"
    ],
    "weapons": [
      "void_lance_advanced",
      "gravity_well_advanced",
      "void_blade_expert"
    ],
    "energy_cards": [
      "energy_start_2",
      "void_energy_basic",
      "void_energy_expert"
    ],
  },
},
{
  "id": "player_master_018",
  "name": "灰烬圣女·希露薇",
  "title": "净化之焰",
  "faction": "ashen_order",
  "side": "player",
  "phase_instrument": "hybrid_steel_flame_mk2",
  "unit_limit": 8,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "radiation_burn",
      "progress": 0.8,
      "active": true,
    },
{
      "engraving_id": "radiation_penetration",
      "progress": 0.6,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "purifying_flame",
      "name": "净化之焰",
      "description": "治疗友军时移除1个负面效果；治疗效果+20%",
    }
  ],
  "active_spells": [
{
      "id": "purify",
      "name": "净化",
      "cooldown": 18.0,
      "mana_cost": 80,
      "effect": "cleanse_heal",
      "params": {
        "heal_percent": 0.2,
        "debuffs_removed": 2,
      },
    },
{
      "id": "ash_blessing",
      "name": "灰烬祝福",
      "cooldown": 25.0,
      "mana_cost": 100,
      "effect": "team_heal_shield",
      "params": {
        "heal": 200,
        "shield": 150,
      },
    },
{
      "id": "final_prayer",
      "name": "最终祈祷",
      "cooldown": 60.0,
      "mana_cost": 200,
      "effect": "invincibility",
      "params": {
        "duration": 4.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "devotion",
      "name": "虔诚",
      "effect": "heal_boost",
      "params": {
        "boost": 0.25,
      },
    },
{
      "id": "martyr",
      "name": "殉道",
      "effect": "death_heal",
      "params": {
        "heal_percent": 0.4,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_advanced",
      "flame_raider_advanced",
      "ash_altar_basic"
    ],
    "weapons": [
      "steel_gatling_expert",
      "flame_thrower_advanced",
      "ash_staff_basic"
    ],
    "energy_cards": [
      "energy_start_5",
      "hybrid_energy_basic",
      "hybrid_energy_expert"
    ],
  },
},
{
  "id": "player_master_019",
  "name": "铁壁元帅·瓦伦",
  "title": "钢铁雄心",
  "faction": "iron_bastion",
  "side": "player",
  "phase_instrument": "steel_guardian_mk5",
  "unit_limit": 10,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "trench_armor",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "steel_production",
      "progress": 1.0,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "iron_will",
      "name": "钢铁意志",
      "description": "全属性+10%；友军HP低于30%时自动获得护盾",
    }
  ],
  "active_spells": [
{
      "id": "total_fortress",
      "name": "全面要塞",
      "cooldown": 45.0,
      "mana_cost": 250,
      "effect": "base_shield",
      "params": {
        "shield_amount": 5000,
        "duration": 15.0,
      },
    },
{
      "id": "steel_tsunami",
      "name": "钢铁海啸",
      "cooldown": 30.0,
      "mana_cost": 200,
      "effect": "summon_units",
      "params": {
        "count": 10,
        "unit_type": "steel_elite",
      },
    },
{
      "id": "iron_judgment",
      "name": "钢铁审判",
      "cooldown": 25.0,
      "mana_cost": 180,
      "effect": "artillery_barrage",
      "params": {
        "damage_per_hit": 500,
        "hits": 8,
      },
    }
  ],
  "passive_spells": [
{
      "id": "unbreakable",
      "name": "不破",
      "effect": "max_hp_shield",
      "params": {
        "threshold": 0.3,
        "shield_percent": 0.2,
      },
    },
{
      "id": "iron_momentum",
      "name": "铁之动量",
      "effect": "sustain_combat",
      "params": {
        "per_10s_atk_boost": 0.05,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_advanced",
      "steel_fortress_expert",
      "steel_titan_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "steel_minigun_advanced",
      "steel_artillery_expert",
      "steel_railgun_expert"
    ],
    "energy_cards": [
      "energy_start_6",
      "steel_energy_basic",
      "steel_energy_expert"
    ],
  },
},
{
  "id": "player_master_020",
  "name": "万相之主·艾拉(觉醒)",
  "title": "万物归一",
  "faction": "neutral",
  "side": "player",
  "phase_instrument": "omni_phase_mk1",
  "unit_limit": 12,
  "engraved_affixes": [
{
      "engraving_id": "trench_endurance",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "radiation_penetration",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "chain_conduct",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "quantum_drain",
      "progress": 1.0,
      "active": true,
    },
{
      "engraving_id": "timeline_collapse",
      "progress": 0.8,
      "active": true,
    },
{
      "engraving_id": "void_siphon",
      "progress": 0.5,
      "active": true,
    }
  ],
  "traits": [
{
      "id": "omni_resonance",
      "name": "万相共鸣",
      "description": "所有属性+15%；每次施放技能后下一个技能伤害+20%",
    }
  ],
  "active_spells": [
{
      "id": "phase_cascade",
      "name": "相位瀑布",
      "cooldown": 20.0,
      "mana_cost": 120,
      "effect": "multi_element_burst",
      "params": {
        "damage": 500,
        "elements": [
          "fire",
          "thunder",
          "void"
        ],
      },
    },
{
      "id": "temporal_anchor",
      "name": "时间锚点",
      "cooldown": 35.0,
      "mana_cost": 150,
      "effect": "rewind_ally",
      "params": {
        "hp_percent": 0.5,
      },
    },
{
      "id": "omni_barrier",
      "name": "万相屏障",
      "cooldown": 40.0,
      "mana_cost": 200,
      "effect": "ultimate_shield",
      "params": {
        "shield_amount": 4000,
        "duration": 10.0,
        "reflect": 0.3,
      },
    }
  ],
  "passive_spells": [
{
      "id": "resonance_chain",
      "name": "共鸣链",
      "effect": "spell_synergy",
      "params": {
        "per_spell_type": 0.1,
        "max": 0.5,
      },
    },
{
      "id": "phase_adapt",
      "name": "相位适应",
      "effect": "elemental_resist",
      "params": {
        "resist_all": 0.2,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "flame_raider_expert",
      "void_stealth_expert"
    ],
    "weapons": [
      "steel_railgun_expert",
      "plasma_cannon_expert",
      "gravity_well_expert",
      "void_blade_expert"
    ],
    "energy_cards": [
      "energy_start_6",
      "hybrid_energy_expert",
      "omni_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_001",
  "name": "钢铁先锋·马库斯",
  "title": "钢铁防线守卫",
  "faction": "iron_bastion",
  "side": "enemy",
  "source_id": "enemy_master_001",
  "difficulty": "easy",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "recruit_commander",
      "name": "新兵教官",
      "description": "所有友军防御+10%，部署冷却-5%",
    }
  ],
  "active_spells": [
{
      "id": "steel_wall_summon",
      "name": "钢铁壁垒",
      "cooldown": 15.0,
      "mana_cost": 80,
      "effect": "summon_units",
      "params": {
        "count": 3,
        "unit_type": "steel_wall",
        "hp": 800,
        "defense": 50,
      },
    },
{
      "id": "armor_break",
      "name": "破甲冲击",
      "cooldown": 12.0,
      "mana_cost": 60,
      "effect": "damage_debuff",
      "params": {
        "damage": 200,
        "defense_reduction": 0.3,
        "duration": 5.0,
        "angle": 90,
      },
    }
  ],
  "passive_spells": [
{
      "id": "steel_skin",
      "name": "钢铁之肤",
      "effect": "armor_boost",
      "params": {
        "bonus": 0.15,
      },
    },
{
      "id": "fortress_mind",
      "name": "堡垒思维",
      "effect": "death_shield",
      "params": {
        "shield_percent": 0.05,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_basic",
      "steel_titan_basic"
    ],
    "weapons": [
      "steel_machinegun_basic",
      "steel_cannon_basic"
    ],
    "energy_cards": [
      "steel_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_002",
  "name": "烈焰使者·伊格尼斯",
  "title": "火焰狂暴者",
  "faction": "crimson_blade",
  "side": "enemy",
  "source_id": "enemy_master_002",
  "difficulty": "easy",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "first_flame",
      "name": "初燃之心",
      "description": "攻击力+10%，火焰伤害额外+10%",
    }
  ],
  "active_spells": [
{
      "id": "fire_storm",
      "name": "烈焰风暴",
      "cooldown": 18.0,
      "mana_cost": 100,
      "effect": "aoe_damage_over_time",
      "params": {
        "damage": 150,
        "duration": 6.0,
        "radius": 120,
      },
    },
{
      "id": "explosive_charge",
      "name": "爆炸冲锋",
      "cooldown": 20.0,
      "mana_cost": 90,
      "effect": "death_explosion_buff",
      "params": {
        "damage": 100,
        "radius": 80,
        "duration": 8.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "burning_aura",
      "name": "燃烧光环",
      "effect": "damage_aura",
      "params": {
        "damage": 30,
        "radius": 100,
      },
    },
{
      "id": "fire_adaptation",
      "name": "火焰适应",
      "effect": "damage_boost_resistance",
      "params": {
        "boost": 0.2,
        "resistance": 0.3,
        "damage_type": "fire",
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_basic",
      "flame_siege_basic"
    ],
    "weapons": [
      "flame_thrower_basic",
      "incendiary_mortar_basic"
    ],
    "energy_cards": [
      "flame_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_003",
  "name": "雷击者·沃尔特",
  "title": "闪电链大师",
  "faction": "sun_forge",
  "side": "enemy",
  "source_id": "enemy_master_003",
  "difficulty": "medium",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "first_thunder",
      "name": "初雷之印",
      "description": "攻击速度+10%，暴击率+5%",
    }
  ],
  "active_spells": [
{
      "id": "chain_lightning",
      "name": "连锁闪电",
      "cooldown": 14.0,
      "mana_cost": 85,
      "effect": "chain_damage",
      "params": {
        "damage": 250,
        "bounces": 4,
        "range": 200,
      },
    },
{
      "id": "thunder_strike",
      "name": "雷霆一击",
      "cooldown": 16.0,
      "mana_cost": 110,
      "effect": "single_damage_stun",
      "params": {
        "damage": 400,
        "stun_duration": 2.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "static_field",
      "name": "静电场",
      "effect": "splash_damage",
      "params": {
        "splash_percent": 0.3,
        "radius": 60,
      },
    },
{
      "id": "overcharge",
      "name": "过载",
      "effect": "high_energy_bonus",
      "params": {
        "threshold": 0.8,
        "attack_speed_boost": 0.4,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_basic",
      "thunter_sniper_basic"
    ],
    "weapons": [
      "tesla_coil_basic",
      "railgun_basic"
    ],
    "energy_cards": [
      "thunder_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_004",
  "name": "虚空行者·奈克萨斯",
  "title": "时空操纵者",
  "faction": "void_walkers",
  "side": "enemy",
  "source_id": "enemy_master_004",
  "difficulty": "medium",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "void_sense",
      "name": "虚空初感",
      "description": "法术强度+15%，攻击附带3%能量吸取",
    }
  ],
  "active_spells": [
{
      "id": "time_warp",
      "name": "时间扭曲",
      "cooldown": 22.0,
      "mana_cost": 120,
      "effect": "speed_debuff",
      "params": {
        "slow_percent": 0.5,
        "duration": 5.0,
      },
    },
{
      "id": "void_tear",
      "name": "虚空撕裂",
      "cooldown": 25.0,
      "mana_cost": 100,
      "effect": "teleport_gates",
      "params": {
        "gate_count": 3,
        "duration": 10.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "entropy_aura",
      "name": "熵增光环",
      "effect": "max_hp_drain",
      "params": {
        "drain_percent": 0.01,
        "radius": 150,
      },
    },
{
      "id": "phase_shift",
      "name": "相位移",
      "effect": "death_avoid_teleport",
      "params": {
        "chance": 0.3,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_basic",
      "void_mage_basic"
    ],
    "weapons": [
      "void_lance_basic",
      "gravity_well_basic"
    ],
    "energy_cards": [
      "void_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_005",
  "name": "钢铁元帅·克劳斯",
  "title": "不可破之盾",
  "faction": "iron_bastion",
  "side": "enemy",
  "source_id": "enemy_master_005",
  "difficulty": "medium",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "iron_wall_command",
      "name": "铁壁指挥",
      "description": "防御+20%，单位上限+1",
    }
  ],
  "active_spells": [
{
      "id": "iron_dome",
      "name": "钢铁穹顶",
      "cooldown": 30.0,
      "mana_cost": 150,
      "effect": "shield_base",
      "params": {
        "shield_amount": 3000,
        "duration": 8.0,
      },
    },
{
      "id": "reinforcement_call",
      "name": "增援呼叫",
      "cooldown": 22.0,
      "mana_cost": 100,
      "effect": "summon_elites",
      "params": {
        "count": 4,
        "unit_type": "steel_elite",
      },
    }
  ],
  "passive_spells": [
{
      "id": "formation_master",
      "name": "阵型大师",
      "effect": "formation_bonus",
      "params": {
        "adjacent_count": 3,
        "damage_boost": 0.2,
      },
    },
{
      "id": "siege_breaker",
      "name": "攻城破坏者",
      "effect": "damage_vs_building",
      "params": {
        "bonus_damage": 0.5,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_advanced",
      "steel_titan_advanced"
    ],
    "weapons": [
      "steel_minigun_advanced",
      "steel_railcannon_advanced"
    ],
    "energy_cards": [
      "steel_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_006",
  "name": "炎魔女王·赫卡特",
  "title": "毁灭之焰",
  "faction": "crimson_blade",
  "side": "enemy",
  "source_id": "enemy_master_006",
  "difficulty": "medium",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "flame_authority",
      "name": "炎之权柄",
      "description": "火焰伤害+20%，燃烧持续时间+2秒",
    }
  ],
  "active_spells": [
{
      "id": "meteor_swarm",
      "name": "流星群",
      "cooldown": 25.0,
      "mana_cost": 180,
      "effect": "meteor_rain",
      "params": {
        "count": 4,
        "damage": 350,
        "burn_duration": 4.0,
      },
    },
{
      "id": "phoenix_rebirth",
      "name": "凤凰重生",
      "cooldown": 45.0,
      "mana_cost": 200,
      "effect": "mass_resurrect",
      "params": {
        "hp_percent": 0.5,
      },
    }
  ],
  "passive_spells": [
{
      "id": "eternal_flame",
      "name": "永恒之火",
      "effect": "death_explosion",
      "params": {
        "damage": 200,
        "radius": 100,
      },
    },
{
      "id": "heat_wave",
      "name": "热浪",
      "effect": "scaling_damage",
      "params": {
        "interval": 10.0,
        "boost_per_stack": 0.1,
        "max_stacks": 5,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_advanced",
      "flame_siege_advanced"
    ],
    "weapons": [
      "flame_thrower_advanced",
      "incendiary_cannon_advanced"
    ],
    "energy_cards": [
      "flame_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_007",
  "name": "雷神之子·索尔",
  "title": "万钧雷霆",
  "faction": "sun_forge",
  "side": "enemy",
  "source_id": "enemy_master_007",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "storm_child",
      "name": "风暴之子",
      "description": "雷电伤害+20%，闪电链弹射+1次",
    }
  ],
  "active_spells": [
{
      "id": "lightning_storm",
      "name": "雷暴",
      "cooldown": 20.0,
      "mana_cost": 160,
      "effect": "global_lightning",
      "params": {
        "damage": 300,
        "strike_count": 6,
      },
    },
{
      "id": "electrify",
      "name": "充能",
      "cooldown": 18.0,
      "mana_cost": 140,
      "effect": "weapon_enchant",
      "params": {
        "bonus_damage": 100,
        "duration": 10.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "conductive",
      "name": "传导",
      "effect": "chain_attack",
      "params": {
        "jump_count": 2,
        "jump_damage": 80,
      },
    },
{
      "id": "storm_caller",
      "name": "风暴召唤者",
      "effect": "full_energy_trigger",
      "params": {
        "trigger_spell": "chain_lightning",
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_advanced",
      "thunter_sniper_advanced"
    ],
    "weapons": [
      "tesla_coil_advanced",
      "railgun_advanced"
    ],
    "energy_cards": [
      "thunder_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_008",
  "name": "虚空领主·萨洛斯",
  "title": "维度撕裂者",
  "faction": "void_walkers",
  "side": "enemy",
  "source_id": "enemy_master_008",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "dimension_perception",
      "name": "维度感知",
      "description": "虚空伤害+20%，相位仪能量恢复+30%",
    }
  ],
  "active_spells": [
{
      "id": "dimension_rift",
      "name": "维度裂隙",
      "cooldown": 35.0,
      "mana_cost": 200,
      "effect": "portal_summon",
      "params": {
        "duration": 12.0,
        "spawn_interval": 2.0,
      },
    },
{
      "id": "black_hole",
      "name": "黑洞",
      "cooldown": 28.0,
      "mana_cost": 180,
      "effect": "black_hole",
      "params": {
        "damage": 200,
        "duration": 6.0,
        "radius": 150,
      },
    }
  ],
  "passive_spells": [
{
      "id": "reality_tear",
      "name": "现实撕裂",
      "effect": "armor_ignore_chance",
      "params": {
        "chance": 0.2,
      },
    },
{
      "id": "void_embrace",
      "name": "虚空拥抱",
      "effect": "energy_drain",
      "params": {
        "drain_percent": 0.05,
        "radius": 200,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_advanced",
      "void_mage_advanced"
    ],
    "weapons": [
      "void_lance_advanced",
      "gravity_well_advanced"
    ],
    "energy_cards": [
      "void_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_009",
  "name": "钢铁军团长·费米",
  "title": "钢铁军团统帅",
  "faction": "iron_bastion",
  "side": "enemy",
  "source_id": "enemy_master_009",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "industrial_commander",
      "name": "工业统帅",
      "description": "单位生产速度+30%，存活单位每10秒获得+5%全属性",
    }
  ],
  "active_spells": [
{
      "id": "legion_call",
      "name": "军团召唤",
      "cooldown": 40.0,
      "mana_cost": 220,
      "effect": "mass_summon",
      "params": {
        "elite_count": 3,
        "normal_count": 7,
      },
    },
{
      "id": "fortress_mode",
      "name": "要塞模式",
      "cooldown": 35.0,
      "mana_cost": 200,
      "effect": "mass_buff_shield",
      "params": {
        "defense_boost": 0.5,
        "shield_amount": 1500,
      },
    }
  ],
  "passive_spells": [
{
      "id": "iron_will",
      "name": "钢铁意志",
      "effect": "low_hp_defense_boost",
      "params": {
        "threshold": 0.3,
        "defense_multiplier": 2.0,
      },
    },
{
      "id": "auto_production",
      "name": "自动化生产",
      "effect": "auto_production",
      "params": {
        "interval": 12.0,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "steel_titan_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "steel_artillery_expert"
    ],
    "energy_cards": [
      "steel_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_010",
  "name": "炎帝·普罗米修斯",
  "title": "永恒烈焰",
  "faction": "crimson_blade",
  "side": "enemy",
  "source_id": "enemy_master_010",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "eternal_inferno",
      "name": "永恒烈焰",
      "description": "火焰伤害+30%，友军移动路径留下燃烧轨迹",
    }
  ],
  "active_spells": [
{
      "id": "world_inferno",
      "name": "世界炼狱",
      "cooldown": 50.0,
      "mana_cost": 300,
      "effect": "terrain_transform",
      "params": {
        "damage": 80,
        "duration": 12.0,
      },
    },
{
      "id": "supernova",
      "name": "超新星",
      "cooldown": 45.0,
      "mana_cost": 280,
      "effect": "massive_explosion",
      "params": {
        "damage": 700,
        "radius": 200,
        "burn_duration": 6.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "hellfire",
      "name": "地狱火",
      "effect": "elemental_damage_boost",
      "params": {
        "boost": 0.4,
        "element": "fire",
      },
    },
{
      "id": "immolation",
      "name": "自焚",
      "effect": "self_damage_aura",
      "params": {
        "aura_damage": 40,
        "self_damage": 15,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_expert",
      "flame_siege_expert"
    ],
    "weapons": [
      "flame_thrower_expert",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "flame_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_011",
  "name": "雷皇·宙斯",
  "title": "雷霆主宰",
  "faction": "sun_forge",
  "side": "enemy",
  "source_id": "enemy_master_011",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "thunder_domination",
      "name": "雷霆主宰",
      "description": "雷电伤害+35%，能量满时自动触发闪电链打击",
    }
  ],
  "active_spells": [
{
      "id": "thunder_god_fury",
      "name": "雷神之怒",
      "cooldown": 30.0,
      "mana_cost": 250,
      "effect": "rapid_lightning",
      "params": {
        "strike_count": 8,
        "damage": 450,
      },
    },
{
      "id": "electromagnetic_pulse",
      "name": "电磁脉冲",
      "cooldown": 40.0,
      "mana_cost": 200,
      "effect": "emp_stun",
      "params": {
        "duration": 4.0,
        "target_type": "all",
      },
    }
  ],
  "passive_spells": [
{
      "id": "lightning_speed",
      "name": "闪电速度",
      "effect": "speed_boost",
      "params": {
        "move_speed": 0.3,
        "attack_speed": 0.3,
      },
    },
{
      "id": "static_overload",
      "name": "静电过载",
      "effect": "death_chain_lightning",
      "params": {
        "damage": 180,
        "bounces": 3,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_expert",
      "thunter_sniper_expert"
    ],
    "weapons": [
      "tesla_coil_expert",
      "railgun_expert"
    ],
    "energy_cards": [
      "thunder_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_012",
  "name": "虚空虚主·阿扎托斯",
  "title": "虚空君王",
  "faction": "void_walkers",
  "side": "enemy",
  "source_id": "enemy_master_012",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "void_mastery",
      "name": "虚空精通",
      "description": "虚空伤害+35%，所有技能冷却-20%，能量吸取效果+50%",
    }
  ],
  "active_spells": [
{
      "id": "reality_collapse",
      "name": "现实崩塌",
      "cooldown": 60.0,
      "mana_cost": 350,
      "effect": "instant_kill_zone",
      "params": {
        "radius": 100,
        "cast_time": 3.0,
        "hp_threshold": 0.2,
      },
    },
{
      "id": "void_army",
      "name": "虚空大军",
      "cooldown": 45.0,
      "mana_cost": 280,
      "effect": "summon_void_army",
      "params": {
        "normal_count": 10,
        "behemoth_count": 2,
      },
    }
  ],
  "passive_spells": [
{
      "id": "cooldown_mastery",
      "name": "冷却精通",
      "effect": "cooldown_reduction",
      "params": {
        "reduction": 0.25,
      },
    },
{
      "id": "dimension_siphon",
      "name": "维度虹吸",
      "effect": "life_energy_drain",
      "params": {
        "hp_drain": 40,
        "energy_drain": 15,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_expert",
      "void_mage_expert"
    ],
    "weapons": [
      "void_lance_expert",
      "entropy_caster_expert"
    ],
    "energy_cards": [
      "void_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_013",
  "name": "钢铁烈焰·卡尔",
  "title": "熔铸大师",
  "faction": "steel_flame",
  "side": "enemy",
  "source_id": "enemy_master_013",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "forgemaster",
      "name": "熔铸大师",
      "description": "钢铁+烈焰协同：相邻的钢铁和烈焰单位互相增强25%伤害",
    }
  ],
  "active_spells": [
{
      "id": "molten_armor",
      "name": "熔岩护甲",
      "cooldown": 25.0,
      "mana_cost": 150,
      "effect": "thorn_armor_fire",
      "params": {
        "thorn_damage": 80,
        "duration": 10.0,
      },
    },
{
      "id": "forge_hammer",
      "name": "锻锤",
      "cooldown": 20.0,
      "mana_cost": 130,
      "effect": "hammer_smash",
      "params": {
        "damage": 300,
        "stun_duration": 2.5,
        "radius": 120,
      },
    }
  ],
  "passive_spells": [
{
      "id": "heat_treatment",
      "name": "热处理",
      "effect": "proc_explosion",
      "params": {
        "chance": 0.15,
        "explosion_damage": 120,
      },
    },
{
      "id": "tempered",
      "name": "回火",
      "effect": "fire_damage_boost",
      "params": {
        "boost": 0.1,
        "duration": 5.0,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "flame_raider_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "flame_thrower_expert"
    ],
    "energy_cards": [
      "hybrid_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_014",
  "name": "雷霆钢铁·维克多",
  "title": "电磁装甲师",
  "faction": "thunder_steel",
  "side": "enemy",
  "source_id": "enemy_master_014",
  "difficulty": "hard",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "electromagnetic_armor",
      "name": "电磁装甲师",
      "description": "雷霆+钢铁协同：护甲受到攻击时反射雷电，造成80伤害",
    }
  ],
  "active_spells": [
{
      "id": "railgun_barrage",
      "name": "电磁炮齐射",
      "cooldown": 22.0,
      "mana_cost": 160,
      "effect": "piercing_shots",
      "params": {
        "shot_count": 5,
        "damage": 220,
      },
    },
{
      "id": "energize_shields",
      "name": "充能护盾",
      "cooldown": 18.0,
      "mana_cost": 120,
      "effect": "mass_shield",
      "params": {
        "shield_amount": 400,
      },
    }
  ],
  "passive_spells": [
{
      "id": "conductive_armor",
      "name": "导电护甲",
      "effect": "lightning_thorn",
      "params": {
        "thorn_damage": 60,
      },
    },
{
      "id": "overclock",
      "name": "超频",
      "effect": "high_energy_attack_speed",
      "params": {
        "threshold": 0.7,
        "speed_boost": 0.4,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_titan_expert",
      "thunter_striker_expert"
    ],
    "weapons": [
      "steel_railcannon_advanced",
      "tesla_coil_expert"
    ],
    "energy_cards": [
      "hybrid_energy_basic"
    ],
  },
},
{
  "id": "enemy_master_015",
  "name": "虚空烈焰·塞拉菲娜",
  "title": "熵增炎魔",
  "faction": "void_flame",
  "side": "enemy",
  "source_id": "enemy_master_015",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "chaos_flame_trait",
      "name": "熵增炎魔",
      "description": "烈焰+虚空协同：被燃烧的敌人能量流失速度翻倍",
    }
  ],
  "active_spells": [
{
      "id": "chaos_inferno",
      "name": "混沌炼狱",
      "cooldown": 30.0,
      "mana_cost": 200,
      "effect": "chaos_flame",
      "params": {
        "duration": 8.0,
        "damage": 180,
      },
    },
{
      "id": "burning_void",
      "name": "燃烧虚空",
      "cooldown": 25.0,
      "mana_cost": 180,
      "effect": "burning_void_zone",
      "params": {
        "damage": 120,
        "energy_drain": 25,
        "duration": 8.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "entropy_flame",
      "name": "熵增之火",
      "effect": "fire_lifesteal_chance",
      "params": {
        "chance": 0.25,
        "lifesteal_percent": 0.15,
      },
    },
{
      "id": "void_burn",
      "name": "虚空燃烧",
      "effect": "burn_slow",
      "params": {
        "slow_percent": 0.35,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_mage_expert",
      "flame_siege_expert"
    ],
    "weapons": [
      "entropy_caster_expert",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "hybrid_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_016",
  "name": "不朽钢铁·阿特拉斯",
  "title": "世界承载者",
  "faction": "iron_bastion",
  "side": "enemy",
  "source_id": "enemy_master_016",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "immortal_will",
      "name": "不朽意志",
      "description": "友军不会受到超过30%最大HP的单次伤害；每有1个友军全体防御+5%",
    }
  ],
  "active_spells": [
{
      "id": "world_pillar",
      "name": "世界支柱",
      "cooldown": 60.0,
      "mana_cost": 300,
      "effect": "permanent_structures",
      "params": {
        "count": 2,
        "hp": 4000,
      },
    },
{
      "id": "earthquake",
      "name": "大地震",
      "cooldown": 40.0,
      "mana_cost": 250,
      "effect": "global_earthquake",
      "params": {
        "damage": 500,
        "defense_reduction": 0.4,
        "duration": 6.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "unbreakable",
      "name": "不可破坏",
      "effect": "damage_cap",
      "params": {
        "max_damage_percent": 0.3,
      },
    },
{
      "id": "steel_mountain",
      "name": "钢铁之山",
      "effect": "unit_count_defense",
      "params": {
        "defense_per_unit": 0.05,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "steel_titan_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "steel_artillery_expert"
    ],
    "energy_cards": [
      "steel_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_017",
  "name": "永恒炎魔·苏尔特",
  "title": "诸神黄昏",
  "faction": "crimson_blade",
  "side": "enemy",
  "source_id": "enemy_master_017",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "ragnarok",
      "name": "诸神黄昏",
      "description": "火焰伤害+40%；友军首次死亡时自动复活，恢复30%生命值",
    }
  ],
  "active_spells": [
{
      "id": "ragnarok_inferno",
      "name": "诸神黄昏炼狱",
      "cooldown": 90.0,
      "mana_cost": 500,
      "effect": "summon_fire_giant",
      "params": {
        "duration": 20.0,
      },
    },
{
      "id": "solar_flare",
      "name": "太阳耀斑",
      "cooldown": 60.0,
      "mana_cost": 400,
      "effect": "solar_flare",
      "params": {
        "damage": 800,
        "blind_duration": 5.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "phoenix_rebirth_auto",
      "name": "凤凰重生",
      "effect": "phoenix_rebirth_auto",
      "params": {
        "rebirth_hp": 0.3,
        "cooldown_per_unit": 30.0,
      },
    },
{
      "id": "time_based_hp_drain",
      "name": "热寂",
      "effect": "time_based_hp_drain",
      "params": {
        "interval": 30.0,
        "drain_percent": 0.08,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_expert",
      "flame_siege_expert"
    ],
    "weapons": [
      "flame_thrower_expert",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "flame_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_018",
  "name": "万雷之主·雷神",
  "title": "雷霆化身",
  "faction": "sun_forge",
  "side": "enemy",
  "source_id": "enemy_master_018",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "thunder_avatar",
      "name": "万钧雷霆",
      "description": "雷电伤害+45%，闪电链弹射额外+2次，能量满自动打击",
    }
  ],
  "active_spells": [
{
      "id": "thunder_god_avatar",
      "name": "雷神化身",
      "cooldown": 120.0,
      "mana_cost": 600,
      "effect": "avatar_mode",
      "params": {
        "duration": 8.0,
      },
    },
{
      "id": "lightning_omega",
      "name": "终极雷霆",
      "cooldown": 50.0,
      "mana_cost": 350,
      "effect": "ultimate_lightning",
      "params": {
        "damage": 1200,
        "splits": 6,
      },
    }
  ],
  "passive_spells": [
{
      "id": "auto_lightning",
      "name": "无处不在的闪电",
      "effect": "auto_lightning",
      "params": {
        "interval": 5.0,
        "damage": 250,
      },
    },
{
      "id": "global_damage_boost",
      "name": "导电世界",
      "effect": "global_damage_boost",
      "params": {
        "damage_type": "lightning",
        "boost": 0.4,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_expert",
      "thunter_sniper_expert"
    ],
    "weapons": [
      "tesla_coil_expert",
      "railgun_expert"
    ],
    "energy_cards": [
      "thunder_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_019",
  "name": "虚空主宰·尼德霍格",
  "title": "世界吞噬者",
  "faction": "void_walkers",
  "side": "enemy",
  "source_id": "enemy_master_019",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "world_devourer",
      "name": "世界吞噬者",
      "description": "虚空伤害+45%；敌方护盾和护甲效果降低30%",
    }
  ],
  "active_spells": [
{
      "id": "devour_all",
      "name": "世界吞噬",
      "cooldown": 80.0,
      "mana_cost": 500,
      "effect": "devour_all",
      "params": {
        "heal_percent": 0.4,
        "hp_threshold": 0.25,
      },
    },
{
      "id": "void_apocalypse",
      "name": "虚空末日",
      "cooldown": 60.0,
      "mana_cost": 450,
      "effect": "void_apocalypse",
      "params": {
        "damage": 180,
        "duration": 12.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "void_lord",
      "name": "虚空领主",
      "effect": "void_mastery_ultimate",
      "params": {
        "damage_boost": 0.8,
        "cooldown_reduction": 0.25,
      },
    },
{
      "id": "enemy_defense_reduction",
      "name": "现实崩溃",
      "effect": "enemy_defense_reduction",
      "params": {
        "reduction": 0.4,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_expert",
      "void_mage_expert"
    ],
    "weapons": [
      "void_lance_expert",
      "entropy_caster_expert"
    ],
    "energy_cards": [
      "void_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_020",
  "name": "钢铁雷霆·泰尔",
  "title": "电磁战神",
  "faction": "steel_thunder",
  "side": "enemy",
  "source_id": "enemy_master_020",
  "difficulty": "expert",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "em_war_god",
      "name": "电磁战神",
      "description": "钢铁+雷霆协同：部署时单位获得闪电护盾，反弹200伤害",
    }
  ],
  "active_spells": [
{
      "id": "electromagnetic_fortress",
      "name": "电磁堡垒",
      "cooldown": 45.0,
      "mana_cost": 300,
      "effect": "em_fortress",
      "params": {
        "damage": 200,
        "duration": 15.0,
      },
    },
{
      "id": "lightning_assault",
      "name": "雷霆突击",
      "cooldown": 30.0,
      "mana_cost": 250,
      "effect": "lightning_buff",
      "params": {
        "attack_speed": 0.4,
        "shield_damage": 120,
      },
    }
  ],
  "passive_spells": [
{
      "id": "synergy_boost",
      "name": "导电钢铁",
      "effect": "synergy_boost",
      "params": {
        "boost": 0.25,
        "types": [
          "steel",
          "thunder"
        ],
      },
    },
{
      "id": "armor_chain_lightning",
      "name": "雷霆护甲",
      "effect": "armor_chain_lightning",
      "params": {
        "chain_count": 3,
        "damage": 100,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "thunter_striker_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "tesla_coil_expert"
    ],
    "energy_cards": [
      "hybrid_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_021",
  "name": "烈焰虚空·克尔加",
  "title": "混沌炎魔",
  "faction": "flame_void",
  "side": "enemy",
  "source_id": "enemy_master_021",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "chaos_inferno_trait",
      "name": "混沌炎魔",
      "description": "烈焰+虚空协同：被燃烧的敌人随机传送，有20%概率双重伤害",
    }
  ],
  "active_spells": [
{
      "id": "chaos_zone",
      "name": "混沌虚空炼狱",
      "cooldown": 50.0,
      "mana_cost": 350,
      "effect": "chaos_zone",
      "params": {
        "damage": 250,
        "duration": 12.0,
      },
    },
{
      "id": "entropy_drain",
      "name": "熵增烈焰",
      "cooldown": 40.0,
      "mana_cost": 280,
      "effect": "entropy_drain",
      "params": {
        "hp_drain": 80,
        "energy_drain": 40,
        "duration": 8.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "dual_element_boost",
      "name": "混沌之火",
      "effect": "dual_element_boost",
      "params": {
        "boost": 0.4,
        "dual_chance": 0.15,
      },
    },
{
      "id": "immunity",
      "name": "混沌免疫",
      "effect": "immunity",
      "params": {
        "effects": [
          "burn",
          "void_drain"
        ],
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_siege_expert",
      "void_mage_expert"
    ],
    "weapons": [
      "plasma_cannon_expert",
      "entropy_caster_expert"
    ],
    "energy_cards": [
      "hybrid_energy_advanced"
    ],
  },
},
{
  "id": "enemy_master_022",
  "name": "战争机器·铁骑",
  "title": "钢铁风暴",
  "faction": "iron_bastion",
  "side": "enemy",
  "source_id": "enemy_master_022",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "automated_warfare",
      "name": "自动化战争",
      "description": "每10秒自动生产一个战斗单位；单位每存活10秒获得一层升级(+8%属性)",
    }
  ],
  "active_spells": [
{
      "id": "deploy_mechs",
      "name": "机械军团",
      "cooldown": 30.0,
      "mana_cost": 180,
      "effect": "deploy_mechs",
      "params": {
        "count": 6,
        "mech_type": "battle_robot",
      },
    },
{
      "id": "mass_repair",
      "name": "修复蜂群",
      "cooldown": 25.0,
      "mana_cost": 150,
      "effect": "mass_repair",
      "params": {
        "heal_percent": 0.25,
      },
    }
  ],
  "passive_spells": [
{
      "id": "automation",
      "name": "自动化",
      "effect": "auto_production_fast",
      "params": {
        "interval": 12.0,
      },
    },
{
      "id": "modular_upgrade",
      "name": "模块化升级",
      "effect": "time_based_upgrade",
      "params": {
        "interval": 10.0,
        "boost_per_level": 0.08,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "steel_titan_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "steel_artillery_expert"
    ],
    "energy_cards": [
      "steel_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_023",
  "name": "火术宗师·凤凰",
  "title": "不死鸟",
  "faction": "crimson_blade",
  "side": "enemy",
  "source_id": "enemy_master_023",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "phoenix_trait",
      "name": "不死鸟",
      "description": "火焰技能冷却-30%；全队每场战斗可触发一次完全复活",
    }
  ],
  "active_spells": [
{
      "id": "pyroblast",
      "name": "炎爆术",
      "cooldown": 18.0,
      "mana_cost": 160,
      "effect": "pyroblast",
      "params": {
        "damage": 600,
        "radius": 100,
        "burn_duration": 6.0,
      },
    },
{
      "id": "flame_wave",
      "name": "烈焰波",
      "cooldown": 16.0,
      "mana_cost": 140,
      "effect": "flame_wave",
      "params": {
        "damage": 400,
        "knockback": 150,
      },
    }
  ],
  "passive_spells": [
{
      "id": "fire_mastery",
      "name": "火焰精通",
      "effect": "elemental_mastery",
      "params": {
        "element": "fire",
        "damage_boost": 0.35,
        "cooldown_reduction": 0.2,
      },
    },
{
      "id": "ignite",
      "name": "点燃",
      "effect": "ignite_chance",
      "params": {
        "chance": 0.2,
        "burn_damage": 45,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_expert",
      "flame_siege_expert"
    ],
    "weapons": [
      "flame_thrower_expert",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "flame_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_024",
  "name": "风暴使者·赛勒斯",
  "title": "疾风迅雷",
  "faction": "sun_forge",
  "side": "enemy",
  "source_id": "enemy_master_024",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "storm_rush",
      "name": "超级突袭",
      "description": "移动速度+50%；对首领级目标造成+100%伤害",
    }
  ],
  "active_spells": [
{
      "id": "tornado_summon",
      "name": "龙卷风链",
      "cooldown": 28.0,
      "mana_cost": 200,
      "effect": "tornado_summon",
      "params": {
        "count": 3,
        "damage": 160,
        "duration": 10.0,
      },
    },
{
      "id": "wind_blast",
      "name": "风之冲击",
      "cooldown": 22.0,
      "mana_cost": 170,
      "effect": "wind_push",
      "params": {
        "damage": 280,
        "push_distance": 200,
      },
    }
  ],
  "passive_spells": [
{
      "id": "storm_speed",
      "name": "风暴骑手",
      "effect": "storm_speed",
      "params": {
        "move_speed": 0.5,
        "attack_speed": 0.25,
      },
    },
{
      "id": "periodic_electric_shock",
      "name": "电场",
      "effect": "periodic_electric_shock",
      "params": {
        "interval": 3.0,
        "damage": 100,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_expert",
      "thunter_sniper_expert"
    ],
    "weapons": [
      "tesla_coil_expert",
      "railgun_expert"
    ],
    "energy_cards": [
      "thunder_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_025",
  "name": "暗影主宰·深渊",
  "title": "暗影之王",
  "faction": "void_walkers",
  "side": "enemy",
  "source_id": "enemy_master_025",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "shadow_realm",
      "name": "暗影领域",
      "description": "暗影中敌人受到伤害+50%；背刺伤害+200%",
    }
  ],
  "active_spells": [
{
      "id": "shadow_clones",
      "name": "暗影军团",
      "cooldown": 35.0,
      "mana_cost": 220,
      "effect": "shadow_clones",
      "params": {
        "count": 8,
        "duration": 15.0,
      },
    },
{
      "id": "eclipse",
      "name": "日蚀",
      "cooldown": 40.0,
      "mana_cost": 180,
      "effect": "darkness_debuff",
      "params": {
        "accuracy_reduction": 0.4,
        "duration": 10.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "teleport_behind",
      "name": "暗影步",
      "effect": "teleport_behind",
      "params": {
        "cooldown": 8.0,
      },
    },
{
      "id": "execute_damage",
      "name": "暗杀",
      "effect": "execute_damage",
      "params": {
        "threshold": 0.3,
        "damage_boost": 1.0,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_expert",
      "void_mage_expert"
    ],
    "weapons": [
      "void_lance_expert",
      "entropy_caster_expert"
    ],
    "energy_cards": [
      "void_energy_expert"
    ],
  },
},
{
  "id": "enemy_master_026",
  "name": "钢铁之神·赫淮斯托斯",
  "title": "锻造之神",
  "faction": "iron_bastion",
  "side": "enemy",
  "source_id": "enemy_master_026",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "divine_forging",
      "name": "神圣锻造",
      "description": "每场战斗可使用一次神圣变身：全队全属性+80%持续15秒",
    },
{
      "id": "cheat_death",
      "name": "神之庇护",
      "description": "友军受到致命伤害时，有40%概率保留1点生命值（每单位一次）",
    }
  ],
  "active_spells": [
{
      "id": "divine_transformation",
      "name": "神圣锻造",
      "cooldown": 90.0,
      "mana_cost": 600,
      "effect": "divine_transformation",
      "params": {
        "duration": 15.0,
        "stat_boost": 0.8,
      },
    },
{
      "id": "terrain_forge",
      "name": "世界锻造",
      "cooldown": 120.0,
      "mana_cost": 800,
      "effect": "terrain_forge",
      "params": {
        "fortress_count": 3,
      },
    }
  ],
  "passive_spells": [
{
      "id": "cheat_death_chance",
      "name": "神圣庇护",
      "effect": "cheat_death_chance",
      "params": {
        "chance": 0.4,
      },
    },
{
      "id": "massive_heal_aura",
      "name": "神之光环",
      "effect": "massive_heal_aura",
      "params": {
        "heal_percent": 0.04,
        "radius": 250,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_fortress_expert",
      "steel_titan_expert"
    ],
    "weapons": [
      "steel_gatling_expert",
      "steel_artillery_expert"
    ],
    "energy_cards": [
      "steel_energy_god"
    ],
  },
},
{
  "id": "enemy_master_027",
  "name": "炎魔之神·赫卡特",
  "title": "炼狱女王",
  "faction": "crimson_blade",
  "side": "enemy",
  "source_id": "enemy_master_027",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "hell_queen",
      "name": "炼狱女王",
      "description": "火焰伤害+60%；全队单位死亡后3秒自动复活(50%HP)",
    },
{
      "id": "global_burn",
      "name": "世界燃烧",
      "description": "每秒对所有敌人造成150伤害",
    }
  ],
  "active_spells": [
{
      "id": "hell_terrain",
      "name": "地狱降临",
      "cooldown": 100.0,
      "mana_cost": 700,
      "effect": "hell_terrain",
      "params": {
        "damage": 400,
        "duration": 15.0,
      },
    },
{
      "id": "full_resurrect_all",
      "name": "凤凰涅槃",
      "cooldown": 150.0,
      "mana_cost": 1000,
      "effect": "full_resurrect_all",
      "params": {
        "hp_percent": 0.7,
      },
    }
  ],
  "passive_spells": [
{
      "id": "auto_resurrect",
      "name": "不朽之火",
      "effect": "auto_resurrect",
      "params": {
        "resurrect_delay": 3.0,
        "resurrect_hp": 0.5,
      },
    },
{
      "id": "global_dot",
      "name": "世界燃烧",
      "effect": "global_dot",
      "params": {
        "damage": 150,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "flame_raider_expert",
      "flame_siege_expert"
    ],
    "weapons": [
      "flame_thrower_expert",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "flame_energy_god"
    ],
  },
},
{
  "id": "enemy_master_028",
  "name": "雷神·托尔",
  "title": "雷霆之神",
  "faction": "sun_forge",
  "side": "enemy",
  "source_id": "enemy_master_028",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "god_of_thunder",
      "name": "雷霆之神",
      "description": "雷电伤害+150%，技能冷却-40%，能量消耗-60%",
    },
{
      "id": "thunder_dome",
      "name": "雷霆穹顶",
      "description": "每60秒自动展开雷霆穹顶，保护友军5秒",
    }
  ],
  "active_spells": [
{
      "id": "god_weapon_attack",
      "name": "雷神之锤",
      "cooldown": 80.0,
      "mana_cost": 800,
      "effect": "god_weapon_attack",
      "params": {
        "damage": 1500,
        "stun_duration": 4.0,
      },
    },
{
      "id": "thunder_dome_shield",
      "name": "雷霆穹顶",
      "cooldown": 60.0,
      "mana_cost": 600,
      "effect": "thunder_dome_shield",
      "params": {
        "duration": 12.0,
        "shock_damage": 250,
      },
    }
  ],
  "passive_spells": [
{
      "id": "god_mastery",
      "name": "雷霆之神",
      "effect": "god_mastery",
      "params": {
        "damage_boost": 1.5,
        "cooldown_reduction": 0.4,
        "element": "lightning",
      },
    },
{
      "id": "energy_cost_reduction",
      "name": "无限能量",
      "effect": "energy_cost_reduction",
      "params": {
        "reduction": 0.6,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "thunter_striker_expert",
      "thunter_sniper_expert"
    ],
    "weapons": [
      "tesla_coil_expert",
      "railgun_expert"
    ],
    "energy_cards": [
      "thunder_energy_god"
    ],
  },
},
{
  "id": "enemy_master_029",
  "name": "虚空女神·尼克斯",
  "title": "夜之女神",
  "faction": "void_walkers",
  "side": "enemy",
  "source_id": "enemy_master_029",
  "difficulty": "legendary",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "void_goddess_trait",
      "name": "夜之女神",
      "description": "虚空伤害+200%；永久黑暗(敌方命中率-60%)；可转化1个敌方单位",
    },
{
      "id": "reality_erasure",
      "name": "现实抹除",
      "description": "每90秒可抹除1个敌方单位",
    }
  ],
  "active_spells": [
{
      "id": "mass_conversion",
      "name": "虚空转化",
      "cooldown": 120.0,
      "mana_cost": 900,
      "effect": "mass_conversion",
      "params": {
        "duration": 12.0,
        "target_count": 2,
      },
    },
{
      "id": "instant_delete",
      "name": "现实抹除",
      "cooldown": 90.0,
      "mana_cost": 700,
      "effect": "instant_delete",
      "params": {
        "cast_time": 2.0,
      },
    }
  ],
  "passive_spells": [
{
      "id": "goddess_mastery",
      "name": "虚空女神",
      "effect": "goddess_mastery",
      "params": {
        "damage_boost": 2.0,
      },
    },
{
      "id": "permanent_darkness",
      "name": "永恒之夜",
      "effect": "permanent_darkness",
      "params": {
        "accuracy_reduction": 0.6,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "void_stealth_expert",
      "void_mage_expert"
    ],
    "weapons": [
      "void_lance_expert",
      "entropy_caster_expert"
    ],
    "energy_cards": [
      "void_energy_god"
    ],
  },
},
{
  "id": "enemy_master_030",
  "name": "全能相位师·奥米伽",
  "title": "完美融合",
  "faction": "all",
  "side": "enemy",
  "source_id": "enemy_master_030",
  "difficulty": "ultimate",
  "phase_instrument": "steel_guardian_mk1",
  "unit_limit": 5,
  "engraved_affixes": [],
  "traits": [
{
      "id": "master_of_all",
      "name": "万物主宰",
      "description": "所有伤害类型+80%，所有抗性+40%，每使用技能全属性+8%(无上限)",
    },
{
      "id": "infinite_potential",
      "name": "无限潜能",
      "description": "能量回复+100%，单位上限+3",
    }
  ],
  "active_spells": [
{
      "id": "perfect_fusion",
      "name": "完美和谐",
      "cooldown": 120.0,
      "mana_cost": 1000,
      "effect": "perfect_fusion",
      "params": {
        "duration": 25.0,
        "all_boost": 1.5,
      },
    },
{
      "id": "combo_ultimate",
      "name": "奥米茄打击",
      "cooldown": 180.0,
      "mana_cost": 1500,
      "effect": "combo_ultimate",
      "params": {
        "skill_count": 4,
      },
    }
  ],
  "passive_spells": [
{
      "id": "omni_mastery",
      "name": "万物主宰",
      "effect": "omni_mastery",
      "params": {
        "damage_boost": 0.8,
        "resistance_boost": 0.4,
      },
    },
{
      "id": "infinite_scaling",
      "name": "无限潜能",
      "effect": "infinite_scaling",
      "params": {
        "boost_per_cast": 0.08,
      },
    }
  ],
  "equipment": {
    "platforms": [
      "steel_titan_expert",
      "flame_siege_expert"
    ],
    "weapons": [
      "railgun_expert",
      "plasma_cannon_expert"
    ],
    "energy_cards": [
      "hybrid_energy_god"
    ],
  },
}
]

## 查找相位师 by id
static func find_by_id(master_id: String) -> Dictionary:
	for m in ALL_MASTERS:
		if m.get("id", "") == master_id:
			return m
	return {}

## 获取某方全部相位师
static func get_by_side(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS:
		if m.get("side", "") == side:
			result.append(m)
	return result

## 获取某势力全部相位师
static func get_by_faction(faction: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS:
		if m.get("faction", "") == faction:
			result.append(m)
	return result

## 获取排行榜数据 (id, name, faction, estimated_power)
## 实际战力由 MasterPowerEvaluator 计算
static func get_leaderboard() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS:
		result.append({
			"id": m.get("id", ""),
			"name": m.get("name", ""),
			"title": m.get("title", ""),
			"faction": m.get("faction", ""),
			"side": m.get("side", ""),
		})
	return result
