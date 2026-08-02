extends RefCounted
class_name UniversalModifications
## 通用改造模块定义（10个）
## 可用于多个兵种

const GEN_01_COMMS = "gen_01_comms"
const GEN_02_DIGITAL = "gen_02_digital"
const GEN_03_CAMOUFLAGE = "gen_03_camouflage"
const GEN_04_VEST = "gen_04_vest"
const GEN_05_SHIELD = "gen_05_shield"
const GEN_06_LASER_DESIGNATOR = "gen_06_laser_designator"
const GEN_07_MINE_RESISTANT = "gen_07_mine_resistant"
const GEN_08_NBC_PROTECTION = "gen_08_nbc_protection"
const GEN_09_IR_JAMMER = "gen_09_ir_jammer"
const GEN_10_AMMO_RACK = "gen_10_ammo_rack"
# v8 批次5: 相位共鸣系列独占改造（仅挑战/成就奖励获得蓝图）
const GEN_11_PHASE_RESONANCE = "gen_11_phase_resonance"
const GEN_12_PHASE_SHIELDING = "gen_12_phase_shielding"
const GEN_13_PHASE_OVERDRIVE = "gen_13_phase_overdrive"

const DATA: Dictionary = {
	"gen_01_comms" = {
		id = GEN_01_COMMS, name = "战场通讯", name_en = "Field Comms",
		icon = "res://assets/ui/icons/mod_icons/mod_comms.png",
		prototype = "SCR-536对讲机", description = "基础通讯，射速和暴击微升",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 60, cost_install = 30,
		slot_type = "comms", conflict_group = "comms",
		# v7.x: per-slot 弹道——对轻装槽改 DIRECT 直射协调
		condition_slot = 0,
		effects = {attack_interval = -0.05, vision = 0.20, slot_weapon_type = 0},  # v7.x: 对轻装槽直射化,
		applicable_types = [0],  # LIGHT（含侦察子类，_guess_combat_kind 把 recon 归为 LIGHT）
		unlock_conditions = {required_level = 1}
	},
	"gen_02_digital" = {
		id = GEN_02_DIGITAL, name = "数字化单兵", name_en = "Digital Soldier System",
		icon = "res://assets/ui/icons/mod_icons/mod_system.png",
		prototype = "陆地勇士系统", description = "三维防御提升7.5%",
		rarity = "rare",
		power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "system", conflict_group = "system",
		effects = {command_efficiency = 0.15},
		applicable_types = [0],  # LIGHT（含侦察子类）
		unlock_conditions = {required_level = 3}
	},
	"gen_03_camouflage" = {
		id = GEN_03_CAMOUFLAGE, name = "伪装迷彩", name_en = "Camouflage Pattern",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "多地形迷彩", description = "伪装迷彩，闪避+20%",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 70, cost_install = 35,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {detection_reduce = -0.20},
		applicable_types = [0, 1, 2, 3, 4],  # ALL（CombatKind 合法值 0-4）
		unlock_conditions = {required_level = 1}
	},
	"gen_04_vest" = {
		id = GEN_04_VEST, name = "战术背心", name_en = "Tactical Vest",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		prototype = "IOTV模块化", description = "基础防护提升",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 80, cost_install = 40,
		slot_type = "armor", conflict_group = "armor",
		effects = {max_hp = 0.10, defense_light = 0.05},
		applicable_types = [0, 2],  # LIGHT, SUPPORT（侦察归 LIGHT 已含）
		unlock_conditions = {required_level = 1}
	},
	"gen_05_shield" = {
		id = GEN_05_SHIELD, name = "防弹盾牌", name_en = "Riot Shield",
		icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
		prototype = "防弹盾", description = "防护大幅提升，速度略降",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "shield", conflict_group = "shield",
		effects = {defense_light = 0.40, move_speed = -10},
		applicable_types = [0, 2],  # LIGHT, SUPPORT
		unlock_conditions = {required_level = 2}
	},
	"gen_06_laser_designator" = {
		id = GEN_06_LASER_DESIGNATOR, name = "激光指示器", name_en = "Laser Designator",
		icon = "res://assets/ui/icons/mod_icons/mod_designator.png",
		prototype = "激光目标指示器", description = "激光指示，对装甲伤害+10%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "designator", conflict_group = "designator",
		effects = {ally_arty_bonus = 0.20},
		applicable_types = [0],  # LIGHT（含侦察子类）
		unlock_conditions = {required_level = 3}
	},
	"gen_07_mine_resistant" = {
		id = GEN_07_MINE_RESISTANT, name = "防雷座椅", name_en = "Mine-Resistant Seat",
		icon = "res://assets/ui/icons/mod_icons/mod_survival.png",
		prototype = "悬挂防雷座椅", description = "强化底盘，三维防御大幅提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 260, cost_install = 130,
		slot_type = "survival", conflict_group = "survival",
		effects = {mine_damage_reduction = -0.80},
		applicable_types = [1],  # ARMOR
		unlock_conditions = {required_level = 4}
	},
	"gen_08_nbc_protection" = {
		id = GEN_08_NBC_PROTECTION, name = "三防系统", name_en = "NBC Protection",
		icon = "res://assets/ui/icons/mod_icons/mod_protection.png",
		prototype = "核生化防护", description = "三防系统，减伤+30%",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "protection", conflict_group = "protection",
		effects = {nbq_immunity = true},
		applicable_types = [1, 2, 4],  # ARMOR, SUPPORT, FORT
		unlock_conditions = {required_level = 5}
	},
	"gen_09_ir_jammer" = {
		id = GEN_09_IR_JAMMER, name = "红外干扰机", name_en = "IR Jammer",
		icon = "res://assets/ui/icons/mod_icons/mod_countermeasure.png",
		prototype = "窗帘光电干扰", description = "导弹闪避提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "countermeasure", conflict_group = "countermeasure",
		effects = {missile_dodge = 0.25},
		applicable_types = [1, 3],  # ARMOR, AIR
		unlock_conditions = {required_level = 5}
	},
		"gen_10_ammo_rack" = {
			id = GEN_10_AMMO_RACK, name = "备用弹药架", name_en = "Ammo Rack",
			icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
			prototype = "外挂弹药箱", description = "持续作战能力提升",
			rarity = "uncommon",
		power_mult = 1.0, cost_research = 90, cost_install = 45,
			slot_type = "ammunition", conflict_group = "ammunition",
			# v7.x: per-slot 弹道——全槽（condition_slot=-1）直射强化（弹药充足）
			condition_slot = -1,
			effects = {sustained_fire = 0.30, slot_weapon_type = 0},  # v7.x: 全槽直射弹道,
			applicable_types = [0, 1, 2, 3, 4],  # ALL（CombatKind 合法值 0-4）
			unlock_conditions = {required_level = 1}
		},
		# ══════════ v8 批次5: 相位共鸣系列独占改造（仅挑战/成就奖励获得蓝图） ══════════
		"gen_11_phase_resonance" = {
			id = GEN_11_PHASE_RESONANCE, name = "相位共鸣", name_en = "Phase Resonance",
			icon = "res://assets/ui/icons/mod_icons/mod_resonance.png",
			prototype = "相位共鸣放大器", description = "独占改造：三维攻击全面提升（相位能量强化火力）",
			rarity = "legendary",
		power_mult = 1.5, cost_research = 500, cost_install = 200,
			slot_type = "phase_core", conflict_group = "phase_core",
			condition_slot = -1,
			# 用 attack_light/armor/air 三个 key（attack_damage 不在 _apply_single_mod_effects 分支）
			effects = {attack_light = 0.25, attack_armor = 0.25, attack_air = 0.25},
			applicable_types = [0, 1, 2, 3, 4],
			unlock_conditions = {required_level = 10},
			achievement_exclusive = true  # 独占标记（仅挑战大师难度奖励）
		},
		"gen_12_phase_shielding" = {
			id = GEN_12_PHASE_SHIELDING, name = "相位护盾", name_en = "Phase Shielding",
			icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
			prototype = "相位偏转护盾", description = "独占改造：减伤 +20%，生命 +30%（相位能量构造防护层）",
			rarity = "legendary",
		power_mult = 1.5, cost_research = 500, cost_install = 200,
			slot_type = "phase_core", conflict_group = "phase_core",
			condition_slot = -1,
			effects = {damage_reduction = 0.20, max_hp = 0.30},
			applicable_types = [0, 1, 2, 3, 4],
			unlock_conditions = {required_level = 10},
			achievement_exclusive = true
		},
		"gen_13_phase_overdrive" = {
			id = GEN_13_PHASE_OVERDRIVE, name = "相位过载", name_en = "Phase Overdrive",
			icon = "res://assets/ui/icons/mod_icons/mod_overdrive.png",
			prototype = "相位过载核心", description = "独占改造：攻速 +30% + 暴击 +15%（相位能量过载驱动）",
			rarity = "legendary",
		power_mult = 1.5, cost_research = 600, cost_install = 250,
			slot_type = "phase_core", conflict_group = "phase_core",
			condition_slot = -1,
			effects = {attack_interval = -0.30, crit_chance = 0.15},
			applicable_types = [0, 1, 2, 3, 4],
			unlock_conditions = {required_level = 10},
			achievement_exclusive = true
		},

		# ─── v7.x 第二批：相位护盾 + 激光指示器 ───
		"gen_14_phase_shield_gen" = {
			id = "gen_14_phase_shield_gen",
			name = "相位护盾发生器",
			name_en = "Phase Shield Generator",
			icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
			prototype = "相位偏转护盾发生器",
			description = "生成独立相位护盾池(2000点)，伤害优先扣相位池，每秒回复50点",
			rarity = "legendary",
			power_mult = 2.0,
			cost_research = 500,
			cost_install = 250,
			slot_type = "phase_core",
			conflict_group = "phase_core",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {phase_shield = 2000.0, phase_shield_regen = 50.0},
			unlock_conditions = {required_level = 8}
		},

		"gen_15_laser_marker" = {
			id = "gen_15_laser_marker",
			name = "激光指示器",
			name_en = "Laser Marker",
			icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
			prototype = "SOFLAM 激光目标指示器",
			description = "攻击时100%概率标记目标，被标记目标受到+20%额外伤害，持续5秒（炮兵优先打击被标记目标）",
			rarity = "epic",
			power_mult = 1.6,
			cost_research = 320,
			cost_install = 160,
			slot_type = "guidance",
			conflict_group = "guidance",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {laser_marker = true},
			unlock_conditions = {required_level = 5}
		},

		# ─── v8.6 现实/科幻伤害类型（通用）───
		"gen_16_emp_pulse" = {
			id = "gen_16_emp_pulse",
			name = "电磁脉冲装置",
			name_en = "EMP Pulse Device",
			icon = "res://assets/ui/icons/mod_icons/mod_electronic.png",
			prototype = "车载电磁脉冲发生器",
			description = "攻击35%概率释放电磁脉冲：目标攻速-30%、暴击-20%、闪避-15%（4秒），并造成10点真实伤害（蓝色电弧）",
			rarity = "epic",
			power_mult = 1.5,
			cost_research = 300,
			cost_install = 150,
			slot_type = "electronic",
			conflict_group = "electronic",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {emp_chance = 0.35, emp_true_damage = 10.0},
			unlock_conditions = {required_level = 4}
		},

		# ==================== v9.1 组合技套路配套改造（7 个，通用槽） ====================
		# 套路1 助燃燃烧链：燃烧催化剂（所有燃烧 dot ×1.3）
		"gen_combustion_catalyst" = {
			id = "gen_combustion_catalyst",
			name = "燃烧催化剂",
			name_en = "Combustion Catalyst",
			icon = "res://assets/ui/icons/mod_icons/mod_combustion_catalyst.png",
			prototype = "化学催化涂层",
			description = "所有燃烧持续伤害×1.3，助燃燃烧链全局增益",
			rarity = "epic",
			power_mult = 1.5,
			cost_research = 300,
			cost_install = 150,
			slot_type = "special",
			conflict_group = "catalyst",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {burn_dps_mult = 0.30, attack_light = 0.05},
			unlock_conditions = {required_level = 5}
		},
		# 套路2 电磁脉冲链：过载电容（emp 真实伤害+电磁脉冲反射触发）
		"gen_overload_capacitor" = {
			id = "gen_overload_capacitor",
			name = "过载电容",
			name_en = "Overload Capacitor",
			icon = "res://assets/ui/icons/mod_icons/mod_overload.png",
			prototype = "储能电容阵列",
			description = "电磁脉冲真实伤害+，目标石墨电子损坏≥5时触发电磁脉冲反射（连锁3个相邻敌方）；电磁脉冲链触发器",
			rarity = "legendary",
			power_mult = 1.7,
			cost_research = 380,
			cost_install = 190,
			slot_type = "electronic",
			conflict_group = "electronic",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {emp_true_damage_bonus = 8.0, emp_reflect_trigger = true},
			unlock_conditions = {required_level = 6}
		},
		# 套路3 纳米浓度场：纳米催化剂（感染扩散触发）
		"gen_nano_catalyst" = {
			id = "gen_nano_catalyst",
			name = "纳米催化剂",
			name_en = "Nano Catalyst",
			icon = "res://assets/ui/icons/mod_icons/mod_nano_catalyst.png",
			prototype = "自复制纳米颗粒",
			description = "纳米病毒概率+，浓度≥50时 30%概率感染扩散相邻敌人；纳米浓度场触发器",
			rarity = "legendary",
			power_mult = 1.8,
			cost_research = 400,
			cost_install = 200,
			slot_type = "special",
			conflict_group = "catalyst",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {nano_chance = 0.20, nano_pct = 0.015, nano_duration = 6.0, nano_spread_trigger = true},
			unlock_conditions = {required_level = 6}
		},
		# 套路4 光束谐振链：光束分裂器（多重攻击触发）
		"gen_beam_splitter" = {
			id = "gen_beam_splitter",
			name = "光束分裂器",
			name_en = "Beam Splitter",
			icon = "res://assets/ui/icons/mod_icons/mod_beam_splitter.png",
			prototype = "分光棱镜组件",
			description = "光束武器命中带激光谐振≥3的目标追加2道次级光束（每道40%伤害）；光束谐振链触发器",
			rarity = "legendary",
			power_mult = 1.8,
			cost_research = 400,
			cost_install = 200,
			slot_type = "optical",
			conflict_group = "optical",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {beam_split_trigger = true, attack_light = 0.08},
			unlock_conditions = {required_level = 6}
		},
		# 套路4 光束谐振链：反射阵列（光束反射触发）
		"gen_reflector_array" = {
			id = "gen_reflector_array",
			name = "反射阵列",
			name_en = "Reflector Array",
			icon = "res://assets/ui/icons/mod_icons/mod_reflector.png",
			prototype = "可调反射镜组",
			description = "光束武器命中带激光谐振的目标30%概率反射到相邻敌方（衰减60%）；光束谐振链触发器",
			rarity = "epic",
			power_mult = 1.6,
			cost_research = 340,
			cost_install = 170,
			slot_type = "optical",
			conflict_group = "optical",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {beam_reflect_trigger = true, crit_chance = 0.04},
			unlock_conditions = {required_level = 5}
		},
		# 套路5 侦察链式：弱点分析仪（集火链式触发）
		"gen_weakpoint_analyzer" = {
			id = "gen_weakpoint_analyzer",
			name = "弱点分析仪",
			name_en = "Weakpoint Analyzer",
			icon = "res://assets/ui/icons/mod_icons/mod_weakpoint.png",
			prototype = "目标弱点推演模块",
			description = "命中同时有无人机标记+雷达锁定的目标触发弱点暴露（下次命中+50%暴击伤害）；侦察链式触发器",
			rarity = "legendary",
			power_mult = 1.7,
			cost_research = 380,
			cost_install = 190,
			slot_type = "sensor",
			conflict_group = "sensor",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {weakpoint_trigger = true, crit_damage_bonus = 0.10},
			unlock_conditions = {required_level = 6}
		},
		# 套路6 化学污染场：污染蓄能器（化学 dot ×1.2 + 累积浓度）
		"gen_pollution_accumulator" = {
			id = "gen_pollution_accumulator",
			name = "污染蓄能器",
			name_en = "Pollution Accumulator",
			icon = "res://assets/ui/icons/mod_icons/mod_pollution.png",
			prototype = "化学物质浓缩舱",
			description = "化学持续伤害×1.2，每次化学命中额外累积战场污染度；化学污染场触发器",
			rarity = "epic",
			power_mult = 1.6,
			cost_research = 340,
			cost_install = 170,
			slot_type = "special",
			conflict_group = "catalyst",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {chem_dps_mult = 0.20, chem_pollute = 2.0},
			unlock_conditions = {required_level = 5}
		},
	}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_card(card_id: String) -> Array:
	# v6.6: 按 applicable_types 过滤通用改造，避免向不该装的兵种展示
	# （如 gen_07_mine_resistant 仅装甲用，不应展示给步兵卡）
	# 通过 DefaultCards 反查 card_id 对应的 combat_kind
	var combat_kind: int = -1
	const DefaultCardsRef = preload("res://data/default_cards.gd")
	var card = DefaultCardsRef.get_card_by_id(card_id)
	if card != null and "combat_kind" in card:
		combat_kind = int(card.combat_kind)
	if combat_kind < 0:
		# 查不到卡的兵种（如敌方卡/未注册卡），回退全量避免漏装
		return DATA.keys()
	var result: Array = []
	for mod_id in DATA.keys():
		var mod_data = get_mod_data(mod_id)
		var applicable = mod_data.get("applicable_types", [])
		# applicable_types 为空表示适用所有兵种
		if applicable.is_empty() or combat_kind in applicable:
			result.append(mod_id)
	return result

static func get_for_unit_type(unit_type: int) -> Array:
	var result = []
	for mod_id in DATA.keys():
		var mod_data = get_mod_data(mod_id)
		var applicable = mod_data.get("applicable_types", [])
		if unit_type in applicable:
			result.append(mod_id)
	return result

static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	return data_a.get("conflict_group", "") == data_b.get("conflict_group", "") and data_a.get("conflict_group", "") != ""
