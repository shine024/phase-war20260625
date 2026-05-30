extends RefCounted
class_name PhaseMasterRosterWw2
## 二战 (World War II) 相位师名册
## Auto-generated from phase_master_roster.gd split

const ALL_MASTERS: Array[Dictionary] = [
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
]
