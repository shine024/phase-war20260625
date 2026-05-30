extends RefCounted
class_name PhaseMasterRosterModern
## 现代 (Modern Era) 相位师名册
## Auto-generated from phase_master_roster.gd split

const ALL_MASTERS: Array[Dictionary] = [
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
]
