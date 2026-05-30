extends RefCounted
class_name PhaseMasterRosterCold
## 冷战 (Cold War) 相位师名册
## Auto-generated from phase_master_roster.gd split

const ALL_MASTERS: Array[Dictionary] = [
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
]
