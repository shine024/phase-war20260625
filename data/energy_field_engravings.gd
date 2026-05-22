extends RefCounted
class_name EnergyFieldEngravings
## 能量场刻印系统
##
## 不同能量场的关卡可激活并刻录相位仪进化词条。
## 刻印有进度（0.0~1.0），进度满了词条完整生效。
## 可随时删除刻印（保留进度数据，重新激活不丢进度）。
## 我方和敌方共用同一套刻印规则。
##
## 数据结构：
##   能量场 (EnergyField) → 包含多个可刻印词条 (EngravingTemplate)
##   相位仪 (PhaseInstrument) → 有刻印槽位 (由稀有度决定)
##   相位师 (PhaseMaster) → 仪器上已有若干刻印 (含进度)

# ═════════════════════════════════════════════
#  能量场定义
# ═════════════════════════════════════════════

## 8种能量场，对应不同关卡环境
const ENERGY_FIELDS: Dictionary = {
	"trench_death": {
		"id": "trench_death",
		"name": "堑壕死能量场",
		"era": "ww1",
		"description": "一战堑壕中弥漫的死能量，强化防御与生存能力",
		"color": "#8B7355",
	},
	"steel_torrent": {
		"id": "steel_torrent",
		"name": "钢铁洪流能量场",
		"era": "ww2",
		"description": "二战大规模机械化战争产生的钢铁共振场，强化量产能力",
		"color": "#708090",
	},
	"nuclear_ember": {
		"id": "nuclear_ember",
		"name": "核爆余烬能量场",
		"era": "cold_war",
		"description": "核辐射残留能量，强化持续伤害与毁灭性打击",
		"color": "#CD853F",
	},
	"magnetic_storm": {
		"id": "magnetic_storm",
		"name": "磁暴能量场",
		"era": "modern",
		"description": "现代电磁环境产生的强磁场，强化雷电与控制能力",
		"color": "#4169E1",
	},
	"quantum_void": {
		"id": "quantum_void",
		"name": "量子湮灭能量场",
		"era": "near_future",
		"description": "近未来科技产生的量子扰动，强化虚空与维度操控",
		"color": "#9370DB",
	},
	"flame_purgatory": {
		"id": "flame_purgatory",
		"name": "烈焰炼狱能量场",
		"description": "极端高温环境，强化火焰伤害与爆发力",
		"color": "#FF4500",
	},
	"thunder_apocalypse": {
		"id": "thunder_apocalypse",
		"name": "雷霆风暴能量场",
		"description": "持续雷暴环境，强化攻速与闪电链",
		"color": "#00BFFF",
	},
	"void_rift": {
		"id": "void_rift",
		"name": "虚空裂缝能量场",
		"description": "维度裂缝泄露的虚空能量，强化吸取与暗杀能力",
		"color": "#483D8B",
	},
}

# ═════════════════════════════════════════════
#  刻印词条模板
# ═════════════════════════════════════════════
##
## 每个模板定义：
##   id:          唯一标识
##   name:        词条名称
##   source_field: 来源能量场
##   affix_type:  词条效果类型（用于战力评估分类）
##   category:    分类 (stat_boost / element / survival / offense / special)
##   base_value:  最低刻印值（progress=0 时）
##   max_value:   满刻印值（progress=1.0 时）
##   rarity:      词条稀有度 (common / uncommon / rare / epic / mythic)
##   description: 描述
##
## 实际效果值 = base_value + (max_value - base_value) * progress

const ENGRAVING_TEMPLATES: Dictionary = {
	# ──────── 堑壕死能量场 (防御/生存) ────────
	"trench_armor": {
		"id": "trench_armor", "name": "堑壕护甲",
		"source_field": "trench_death", "affix_type": "defense_boost",
		"category": "survival", "base_value": 0.08, "max_value": 0.25,
		"rarity": "common",
		"description": "相位仪防御力提升8%~25%",
	},
	"trench_endurance": {
		"id": "trench_endurance", "name": "堑壕耐力",
		"source_field": "trench_death", "affix_type": "hp_boost",
		"category": "survival", "base_value": 0.05, "max_value": 0.20,
		"rarity": "common",
		"description": "相位仪最大生命值提升5%~20%",
	},
	"trench_resilience": {
		"id": "trench_resilience", "name": "堑壕韧性",
		"source_field": "trench_death", "affix_type": "damage_reduction",
		"category": "survival", "base_value": 0.05, "max_value": 0.15,
		"rarity": "uncommon",
		"description": "受到的所有伤害降低5%~15%",
	},
	"death_guard": {
		"id": "death_guard", "name": "死亡守卫",
		"source_field": "trench_death", "affix_type": "cheat_death",
		"category": "special", "base_value": 0.05, "max_value": 0.20,
		"rarity": "rare",
		"description": "受到致命伤害时5%~20%概率保留1HP",
	},
	"undying_will": {
		"id": "undying_will", "name": "不死意志",
		"source_field": "trench_death", "affix_type": "auto_revive",
		"category": "special", "base_value": 0.0, "max_value": 0.30,
		"rarity": "epic",
		"description": "首次死亡时自动复活，恢复0%~30%生命值",
	},

	# ──────── 钢铁洪流能量场 (量产/钢铁) ────────
	"steel_production": {
		"id": "steel_production", "name": "钢铁量产",
		"source_field": "steel_torrent", "affix_type": "unit_limit_bonus",
		"category": "offense", "base_value": 1, "max_value": 3,
		"rarity": "uncommon",
		"description": "单位上限+1~+3",
	},
	"steel_fortification": {
		"id": "steel_fortification", "name": "钢铁强化",
		"source_field": "steel_torrent", "affix_type": "defense_boost",
		"category": "survival", "base_value": 0.10, "max_value": 0.30,
		"rarity": "common",
		"description": "相位仪防御力提升10%~30%",
	},
	"assembly_line": {
		"id": "assembly_line", "name": "流水线生产",
		"source_field": "steel_torrent", "affix_type": "deploy_speed",
		"category": "offense", "base_value": 0.10, "max_value": 0.35,
		"rarity": "uncommon",
		"description": "单位部署速度提升10%~35%",
	},
	"industrial_heal": {
		"id": "industrial_heal", "name": "工业修复",
		"source_field": "steel_torrent", "affix_type": "heal_aura",
		"category": "survival", "base_value": 0.01, "max_value": 0.03,
		"rarity": "rare",
		"description": "周围友军每秒恢复1%~3%最大生命值",
	},
	"war_machine": {
		"id": "war_machine", "name": "战争机器",
		"source_field": "steel_torrent", "affix_type": "auto_production",
		"category": "special", "base_value": 8.0, "max_value": 15.0,
		"rarity": "epic",
		"description": "每8~15秒自动生产一个战斗单位",
	},

	# ──────── 核爆余烬能量场 (持续伤害/毁灭) ────────
	"radiation_burn": {
		"id": "radiation_burn", "name": "辐射灼烧",
		"source_field": "nuclear_ember", "affix_type": "dot_damage",
		"category": "offense", "base_value": 20, "max_value": 60,
		"rarity": "common",
		"description": "攻击附带每秒20~60点持续伤害",
	},
	"radiation_penetration": {
		"id": "radiation_penetration", "name": "辐射穿透",
		"source_field": "nuclear_ember", "affix_type": "armor_ignore",
		"category": "offense", "base_value": 0.10, "max_value": 0.35,
		"rarity": "uncommon",
		"description": "攻击有10%~35%概率无视护甲",
	},
	"critical_mass": {
		"id": "critical_mass", "name": "临界质量",
		"source_field": "nuclear_ember", "affix_type": "crit_boost",
		"category": "offense", "base_value": 0.10, "max_value": 0.30,
		"rarity": "uncommon",
		"description": "暴击率提升10%~30%",
	},
	"mushroom_cloud": {
		"id": "mushroom_cloud", "name": "蘑菇云",
		"source_field": "nuclear_ember", "affix_type": "death_explosion",
		"category": "offense", "base_value": 100, "max_value": 350,
		"rarity": "rare",
		"description": "友军死亡时爆炸，造成100~350伤害",
	},
	"thermonuclear": {
		"id": "thermonuclear", "name": "热核爆发",
		"source_field": "nuclear_ember", "affix_type": "burst_damage",
		"category": "special", "base_value": 0.50, "max_value": 1.50,
		"rarity": "mythic",
		"description": "首次攻击伤害提升50%~150%（每场战斗一次）",
	},

	# ──────── 磁暴能量场 (雷电/控制) ────────
	"static_charge": {
		"id": "static_charge", "name": "静电充能",
		"source_field": "magnetic_storm", "affix_type": "attack_speed_boost",
		"category": "offense", "base_value": 0.08, "max_value": 0.25,
		"rarity": "common",
		"description": "攻击速度提升8%~25%",
	},
	"chain_conduct": {
		"id": "chain_conduct", "name": "链式传导",
		"source_field": "magnetic_storm", "affix_type": "chain_damage",
		"category": "offense", "base_value": 40, "max_value": 120,
		"rarity": "uncommon",
		"description": "攻击时电流弹射，造成40~120额外伤害",
	},
	"thunder_strike": {
		"id": "thunder_strike", "name": "落雷",
		"source_field": "magnetic_storm", "affix_type": "periodic_damage",
		"category": "offense", "base_value": 80, "max_value": 250,
		"rarity": "rare",
		"description": "每5秒对随机敌人落雷，造成80~250伤害",
	},
	"electromagnetic_shield": {
		"id": "electromagnetic_shield", "name": "电磁护盾",
		"source_field": "magnetic_storm", "affix_type": "energy_shield",
		"category": "survival", "base_value": 200, "max_value": 800,
		"rarity": "rare",
		"description": "战斗开始时获得200~800点护盾",
	},
	"emp_pulse": {
		"id": "emp_pulse", "name": "EMP脉冲",
		"source_field": "magnetic_storm", "affix_type": "stun_chance",
		"category": "special", "base_value": 0.05, "max_value": 0.15,
		"rarity": "epic",
		"description": "攻击有5%~15%概率眩晕敌人1.5秒",
	},

	# ──────── 量子湮灭能量场 (虚空/维度) ────────
	"quantum_drain": {
		"id": "quantum_drain", "name": "量子吸取",
		"source_field": "quantum_void", "affix_type": "energy_drain",
		"category": "offense", "base_value": 0.02, "max_value": 0.08,
		"rarity": "common",
		"description": "攻击吸取敌人2%~8%能量",
	},
	"dimension_shift": {
		"id": "dimension_shift", "name": "维度位移",
		"source_field": "quantum_void", "affix_type": "dodge_chance",
		"category": "survival", "base_value": 0.05, "max_value": 0.20,
		"rarity": "uncommon",
		"description": "受到攻击时5%~20%概率闪避",
	},
	"reality_tear": {
		"id": "reality_tear", "name": "现实撕裂",
		"source_field": "quantum_void", "affix_type": "true_damage",
		"category": "offense", "base_value": 0.10, "max_value": 0.30,
		"rarity": "rare",
		"description": "10%~30%攻击伤害转化为真实伤害",
	},
	"void_embrace": {
		"id": "void_embrace", "name": "虚空拥抱",
		"source_field": "quantum_void", "affix_type": "life_steal",
		"category": "survival", "base_value": 0.05, "max_value": 0.15,
		"rarity": "rare",
		"description": "攻击吸取5%~15%伤害值作为生命值",
	},
	"quantum_tunnel": {
		"id": "quantum_tunnel", "name": "量子隧道",
		"source_field": "quantum_void", "affix_type": "teleport",
		"category": "special", "base_value": 0.0, "max_value": 1.0,
		"rarity": "epic",
		"description": "满刻印后可瞬间传送友军单位至目标位置",
	},
	"timeline_collapse": {
		"id": "timeline_collapse", "name": "时间线坍缩",
		"source_field": "quantum_void", "affix_type": "time_reverse",
		"category": "special", "base_value": 0.0, "max_value": 1.0,
		"rarity": "mythic",
		"description": "满刻印后每场战斗可回溯5秒时间线（一次）",
	},

	# ──────── 烈焰炼狱能量场 (火焰/爆发) ────────
	"blazing_core": {
		"id": "blazing_core", "name": "炽焰核心",
		"source_field": "flame_purgatory", "affix_type": "attack_boost",
		"category": "offense", "base_value": 0.08, "max_value": 0.30,
		"rarity": "common",
		"description": "攻击力提升8%~30%",
	},
	"flame_ignition": {
		"id": "flame_ignition", "name": "引燃",
		"source_field": "flame_purgatory", "affix_type": "ignite_chance",
		"category": "offense", "base_value": 0.10, "max_value": 0.30,
		"rarity": "uncommon",
		"description": "攻击有10%~30%概率点燃敌人",
	},
	"inferno_aura": {
		"id": "inferno_aura", "name": "炼狱光环",
		"source_field": "flame_purgatory", "affix_type": "aura_damage",
		"category": "offense", "base_value": 15, "max_value": 50,
		"rarity": "rare",
		"description": "周围敌人每秒受到15~50火焰伤害",
	},
	"phoenix_feather": {
		"id": "phoenix_feather", "name": "凤凰之羽",
		"source_field": "flame_purgatory", "affix_type": "revive_aura",
		"category": "special", "base_value": 0.0, "max_value": 0.40,
		"rarity": "epic",
		"description": "满刻印后友军死亡时有20%~40%概率自动复活(30%HP)",
	},
	"world_burning": {
		"id": "world_burning", "name": "焚世",
		"source_field": "flame_purgatory", "affix_type": "global_burn",
		"category": "special", "base_value": 30, "max_value": 100,
		"rarity": "mythic",
		"description": "全屏每秒对所有敌人造成30~100点火焰伤害",
	},

	# ──────── 雷霆风暴能量场 (攻速/闪电链) ────────
	"storm_accel": {
		"id": "storm_accel", "name": "风暴加速",
		"source_field": "thunder_apocalypse", "affix_type": "speed_boost",
		"category": "offense", "base_value": 0.10, "max_value": 0.35,
		"rarity": "common",
		"description": "移动和攻击速度提升10%~35%",
	},
	"lightning_chain": {
		"id": "lightning_chain", "name": "闪电链",
		"source_field": "thunder_apocalypse", "affix_type": "bounce_bonus",
		"category": "offense", "base_value": 1, "max_value": 4,
		"rarity": "uncommon",
		"description": "闪电弹射次数+1~+4",
	},
	"overcharge": {
		"id": "overcharge", "name": "过载",
		"source_field": "thunder_apocalypse", "affix_type": "high_energy_burst",
		"category": "offense", "base_value": 0.20, "max_value": 0.60,
		"rarity": "rare",
		"description": "能量超过80%时攻击力提升20%~60%",
	},
	"thunder_dome": {
		"id": "thunder_dome", "name": "雷霆穹顶",
		"source_field": "thunder_apocalypse", "affix_type": "periodic_shield",
		"category": "survival", "base_value": 0.0, "max_value": 1.0,
		"rarity": "epic",
		"description": "满刻印后每45秒展开雷霆穹顶，保护友军4秒",
	},
	"divine_thunder": {
		"id": "divine_thunder", "name": "神圣雷霆",
		"source_field": "thunder_apocalypse", "affix_type": "ultimate_lightning",
		"category": "special", "base_value": 500, "max_value": 1500,
		"rarity": "mythic",
		"description": "满刻印后可召唤天雷，造成500~1500伤害",
	},

	# ──────── 虚空裂缝能量场 (吸取/暗杀) ────────
	"void_siphon": {
		"id": "void_siphon", "name": "虚空虹吸",
		"source_field": "void_rift", "affix_type": "life_energy_drain",
		"category": "offense", "base_value": 15, "max_value": 50,
		"rarity": "common",
		"description": "每秒从周围敌人吸取15~50生命值",
	},
	"shadow_step": {
		"id": "shadow_step", "name": "暗影步",
		"source_field": "void_rift", "affix_type": "backstab",
		"category": "offense", "base_value": 0.50, "max_value": 1.50,
		"rarity": "uncommon",
		"description": "对低生命值敌人伤害额外+50%~+150%",
	},
	"entropy_field": {
		"id": "entropy_field", "name": "熵增场",
		"source_field": "void_rift", "affix_type": "enemy_stat_reduction",
		"category": "offense", "base_value": 0.05, "max_value": 0.20,
		"rarity": "rare",
		"description": "周围敌人全属性降低5%~20%",
	},
	"night_eternal": {
		"id": "night_eternal", "name": "永夜",
		"source_field": "void_rift", "affix_type": "accuracy_reduction",
		"category": "survival", "base_value": 0.15, "max_value": 0.40,
		"rarity": "rare",
		"description": "敌人命中率降低15%~40%",
	},
	"void_erasure": {
		"id": "void_erasure", "name": "虚空抹除",
		"source_field": "void_rift", "affix_type": "execute",
		"category": "special", "base_value": 0.0, "max_value": 1.0,
		"rarity": "mythic",
		"description": "满刻印后每120秒可抹除一个生命值<20%的敌人",
	},
}

# ═════════════════════════════════════════════
#  刻印插槽数据
# ═════════════════════════════════════════════

## 相位仪稀有度 → 可用刻印槽位数
const INSTRUMENT_SLOTS: Dictionary = {
	"common": 2,
	"uncommon": 3,
	"rare": 4,
	"epic": 5,
	"mythic": 6,
}

## 词条稀有度 → 战力评估基础分值
const AFFIX_RARITY_POWER: Dictionary = {
	"common": 30,
	"uncommon": 60,
	"rare": 120,
	"epic": 220,
	"mythic": 400,
}

## 词条分类 → 评估权重修正
const CATEGORY_WEIGHT_MOD: Dictionary = {
	"stat_boost": 0.8,
	"element": 1.0,
	"survival": 1.1,
	"offense": 1.2,
	"special": 1.5,
}


# ═════════════════════════════════════════════
#  辅助函数
# ═════════════════════════════════════════════

## 获取刻印词条模板
static func get_template(engraving_id: String) -> Dictionary:
	return ENGRAVING_TEMPLATES.get(engraving_id, {})

## 获取能量场信息
static func get_energy_field(field_id: String) -> Dictionary:
	return ENERGY_FIELDS.get(field_id, {})

## 获取相位仪可用槽位数
static func get_slot_count(instrument_rarity: String) -> int:
	return INSTRUMENT_SLOTS.get(instrument_rarity, 2)

## 计算刻印词条的实际效果值
## value = base_value + (max_value - base_value) * progress
static func calc_engraving_value(engraving_id: String, progress: float) -> float:
	var tmpl: Dictionary = ENGRAVING_TEMPLATES.get(engraving_id, {})
	if tmpl.is_empty():
		return 0.0
	var base: float = float(tmpl.get("base_value", 0))
	var max_val: float = float(tmpl.get("max_value", 0))
	progress = clampf(progress, 0.0, 1.0)
	return base + (max_val - base) * progress

## 计算刻印词条的战力贡献分
static func calc_engraving_power(engraving_id: String, progress: float) -> float:
	var tmpl: Dictionary = ENGRAVING_TEMPLATES.get(engraving_id, {})
	if tmpl.is_empty():
		return 0.0
	var rarity: String = tmpl.get("rarity", "common")
	var category: String = tmpl.get("category", "stat_boost")
	var base_power: float = float(AFFIX_RARITY_POWER.get(rarity, 30))
	var cat_mod: float = float(CATEGORY_WEIGHT_MOD.get(category, 1.0))
	progress = clampf(progress, 0.0, 1.0)
	return base_power * cat_mod * (0.3 + 0.7 * progress)

## 获取指定能量场的所有可用刻印词条
static func get_field_engravings(field_id: String) -> Array:
	var result: Array = []
	for eid in ENGRAVING_TEMPLATES:
		var tmpl: Dictionary = ENGRAVING_TEMPLATES[eid]
		if tmpl.get("source_field", "") == field_id:
			result.append(tmpl)
	return result

## 获取所有能量场ID列表
static func get_all_field_ids() -> Array:
	return ENERGY_FIELDS.keys()

## 获取所有刻印词条ID列表
static func get_all_engraving_ids() -> Array:
	return ENGRAVING_TEMPLATES.keys()
