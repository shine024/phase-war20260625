extends RefCounted
class_name PhaseMasterRosterFuture
## 近未来 (Near Future) 相位师名册
## Auto-generated from phase_master_roster.gd split

const ALL_MASTERS: Array[Dictionary] = [
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
