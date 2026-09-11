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
# v21 P1: 行为改写型传奇改造（6 个，龙崖映射，计划 §P1-2）
const GEN_CONVERTED_MUNITIONS = "gen_converted_munitions"
const GEN_EXPANSION_CHAMBER = "gen_expansion_chamber"
const GEN_OVERFLOW_SHIELD = "gen_overflow_shield"
const GEN_TRUESTRIKE_PINPOINT = "gen_truestrike_pinpoint"
const GEN_RELAY_ANTENNA = "gen_relay_antenna"
const GEN_UNIFIED_SPLASH = "gen_unified_splash"

const DATA: Dictionary = {
	"gen_01_comms" = {
		id = GEN_01_COMMS, name = "战场通讯", name_en = "Field Comms",
		icon = "res://assets/ui/icons/mod_icons/mod_comms.png",
		prototype = "SCR-536对讲机", description = "班组基础通讯。射速与暴击小幅提升。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 60, cost_install = 30,
		slot_type = "comms", conflict_group = "comms",
		# v7.x: per-slot 弹道——对轻装槽改 DIRECT 直射协调
		condition_slot = 0,
		era_band = [1, 4],
		effects = {attack_interval = -0.05, vision = 0.20, slot_weapon_type = 0},  # v7.x: 对轻装槽直射化,
		applicable_types = [0],  # LIGHT（含侦察子类，_guess_combat_kind 把 recon 归为 LIGHT）
		unlock_conditions = {required_level = 1}
	},
	"gen_02_digital" = {
		id = GEN_02_DIGITAL, name = "数字化单兵", name_en = "Digital Soldier System",
		icon = "res://assets/ui/icons/mod_icons/mod_system.png",
		prototype = "陆地勇士系统", description = "数字化单兵系统。三维防御提升 7.5%。",
		rarity = "rare",
		power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "system", conflict_group = "system",
		era_band = [3, 4],
		effects = {command_efficiency = 0.15},
		applicable_types = [0],  # LIGHT（含侦察子类）
		unlock_conditions = {required_level = 3}
	},
	"gen_03_camouflage" = {
		id = GEN_03_CAMOUFLAGE, name = "伪装迷彩", name_en = "Camouflage Pattern",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "多地形迷彩", description = "多地形伪装迷彩。闪避 +20%。",
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
		prototype = "IOTV模块化", description = "模块化战术背心。基础防护提升。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 80, cost_install = 40,
		slot_type = "armor", conflict_group = "armor",
		era_band = [2, 4],
		effects = {max_hp = 30, defense_light = 5},
		level_effects = {1: {max_hp = 30, defense_light = 5}, 2: {max_hp = 50, defense_light = 9}, 3: {max_hp = 70, defense_light = 12}},
		applicable_types = [0, 2],  # LIGHT, SUPPORT（侦察归 LIGHT 已含）
		unlock_conditions = {required_level = 1}
	},
	"gen_05_shield" = {
		id = GEN_05_SHIELD, name = "防弹盾牌", name_en = "Riot Shield",
		icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
		prototype = "防弹盾", description = "随行防护盾。防护大幅提升，速度略降。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "shield", conflict_group = "shield",
		effects = {defense_light = 40, move_speed = -10},
		level_effects = {1: {defense_light = 40, move_speed = -10}, 2: {defense_light = 70, move_speed = -10}, 3: {defense_light = 100, move_speed = -10}},
		applicable_types = [0, 2],  # LIGHT, SUPPORT
		unlock_conditions = {required_level = 2}
	},
	"gen_06_laser_designator" = {
		id = GEN_06_LASER_DESIGNATOR, name = "激光指示器", name_en = "Laser Designator",
		icon = "res://assets/ui/icons/mod_icons/mod_designator.png",
		prototype = "激光目标指示器", description = "激光指示目标。对装甲伤害 +10%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "designator", conflict_group = "designator",
		era_band = [3, 4],
		effects = {ally_arty_bonus = 0.20},
		applicable_types = [0],  # LIGHT（含侦察子类）
		unlock_conditions = {required_level = 3}
	},
	"gen_07_mine_resistant" = {
		id = GEN_07_MINE_RESISTANT, name = "防雷座椅", name_en = "Mine-Resistant Seat",
		icon = "res://assets/ui/icons/mod_icons/mod_survival.png",
		prototype = "悬挂防雷座椅", description = "强化底盘与防雷座椅。三维防御大幅提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 260, cost_install = 130,
		slot_type = "survival", conflict_group = "survival",
		era_band = [3, 4],
		effects = {mine_damage_reduction = -0.80},
		applicable_types = [1],  # ARMOR
		unlock_conditions = {required_level = 4}
	},
	"gen_08_nbc_protection" = {
		id = GEN_08_NBC_PROTECTION, name = "三防系统", name_en = "NBC Protection",
		icon = "res://assets/ui/icons/mod_icons/mod_protection.png",
		prototype = "核生化防护", description = "核生化三防。减伤 +30%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "protection", conflict_group = "protection",
		era_band = [2, 4],
		effects = {nbq_immunity = true},
		applicable_types = [1, 2, 4],  # ARMOR, SUPPORT, FORT
		unlock_conditions = {required_level = 5}
	},
	"gen_09_ir_jammer" = {
		id = GEN_09_IR_JAMMER, name = "红外干扰机", name_en = "IR Jammer",
		icon = "res://assets/ui/icons/mod_icons/mod_countermeasure.png",
		prototype = "窗帘光电干扰", description = "红外干扰机压制制导。导弹闪避提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "countermeasure", conflict_group = "countermeasure",
		era_band = [3, 4],
		effects = {missile_dodge = 0.25},
		applicable_types = [1, 3],  # ARMOR, AIR
		unlock_conditions = {required_level = 5}
	},
		"gen_10_ammo_rack" = {
			id = GEN_10_AMMO_RACK, name = "备用弹药架", name_en = "Ammo Rack",
			icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
			prototype = "外挂弹药箱", description = "外挂弹药架。持续作战能力提升。",
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
			prototype = "相位共鸣放大器", description = "独占改造。三维攻击全面提升，相位能量强化火力。",
			rarity = "legendary",
		power_mult = 1.5, cost_research = 500, cost_install = 200,
			slot_type = "phase_core", conflict_group = "phase_core",
			condition_slot = -1,
			# 用 attack_light/armor/air 三个 key（attack_damage 不在 _apply_single_mod_effects 分支）
			era_band = [4, 4],
			effects = {attack_light = 0.25, attack_armor = 0.25, attack_air = 0.25},
			applicable_types = [0, 1, 2, 3, 4],
			unlock_conditions = {required_level = 10},
			achievement_exclusive = true  # 独占标记（仅挑战大师难度奖励）
		},
		"gen_12_phase_shielding" = {
			id = GEN_12_PHASE_SHIELDING, name = "相位护盾", name_en = "Phase Shielding",
			icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
			prototype = "相位偏转护盾", description = "独占改造。减伤 +20%，生命 +30%，相位能量构造防护层。",
			rarity = "legendary",
		power_mult = 1.5, cost_research = 500, cost_install = 200,
			slot_type = "phase_core", conflict_group = "phase_core",
			condition_slot = -1,
			era_band = [4, 4],
			effects = {damage_reduction = 0.20, max_hp = 0.30},
			applicable_types = [0, 1, 2, 3, 4],
			unlock_conditions = {required_level = 10},
			achievement_exclusive = true
		},
		"gen_13_phase_overdrive" = {
			id = GEN_13_PHASE_OVERDRIVE, name = "相位过载", name_en = "Phase Overdrive",
			icon = "res://assets/ui/icons/mod_icons/mod_overdrive.png",
			prototype = "相位过载核心", description = "独占改造。攻速 +30%，暴击 +15%，相位能量过载驱动。",
			rarity = "legendary",
		power_mult = 1.5, cost_research = 600, cost_install = 250,
			slot_type = "phase_core", conflict_group = "phase_core",
			condition_slot = -1,
			era_band = [4, 4],
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
			description = "生成独立相位护盾池（2000 点）。伤害优先扣相位池，每秒回复 50 点。",
			rarity = "legendary",
			power_mult = 2.0,
			cost_research = 500,
			cost_install = 250,
			slot_type = "phase_core",
			conflict_group = "phase_core",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [4, 4],
			effects = {phase_shield = 2000.0, phase_shield_regen = 50.0},
			unlock_conditions = {required_level = 8}
		},

		"gen_15_laser_marker" = {
			id = "gen_15_laser_marker",
			name = "激光指示器",
			name_en = "Laser Marker",
			icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
			prototype = "SOFLAM 激光目标指示器",
			description = "攻击时 100% 概率标记目标。被标记目标受到 +20% 额外伤害，持续 5 秒，炮兵优先打击。",
			rarity = "epic",
			power_mult = 1.6,
			cost_research = 320,
			cost_install = 160,
			slot_type = "guidance",
			conflict_group = "guidance",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {laser_marker = true},
			unlock_conditions = {required_level = 5}
		},

		# ─── v8.6 现实/科幻伤害类型（通用）───
		"gen_16_emp_pulse" = {
			id = "gen_16_emp_pulse",
			name = "电磁脉冲装置",
			name_en = "EMP Pulse Device",
			icon = "res://assets/ui/icons/mod_icons/mod_electronics.png",
			prototype = "车载电磁脉冲发生器",
			description = "攻击 35% 概率释放电磁脉冲：目标攻速 -30%、暴击 -20%、闪避 -15%，持续 4 秒，并造成 10 点真实伤害（蓝色电弧）。",
			rarity = "epic",
			power_mult = 1.5,
			cost_research = 300,
			cost_install = 150,
			slot_type = "electronic",
			conflict_group = "electronic",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {emp_chance = 0.35, emp_true_damage = 10.0},
			unlock_conditions = {required_level = 4}
		},

		# ==================== v10 解题式玩法：转换型改造 ====================
		# 电子劫持：敌方增益光环→抵消并转移（敌方优势转我方优势）
		"gen_17_electronic_hijack" = {
			id = "gen_17_electronic_hijack",
			name = "电子劫持",
			name_en = "Electronic Hijack",
			icon = "res://assets/ui/icons/mod_icons/mod_electronics.png",
			prototype = "电子战劫持阵列",
			description = "周期性劫持半径 200 内敌方增益光环（指挥、堡垒庇护）。被劫持光环失效，增益转由本单位享有，持续 4 秒，冷却 18 秒。",
			rarity = "legendary",
			power_mult = 1.8,
			cost_research = 400,
			cost_install = 200,
			slot_type = "electronic",
			conflict_group = "electronic",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [4, 4],
			effects = {hijack_aura_radius = 200.0, hijack_aura_duration = 4.0, hijack_aura_cd = 18.0},
			level_effects = {1: {hijack_aura_radius = 200, hijack_aura_duration = 4, hijack_aura_cd = 18}, 2: {hijack_aura_radius = 260, hijack_aura_duration = 5.2, hijack_aura_cd = 23.4}, 3: {hijack_aura_radius = 340, hijack_aura_duration = 6.8, hijack_aura_cd = 30.6}},
			unlock_conditions = {required_level = 6}
		},

		# ==================== v9.1 组合技套路配套改造（7 个，通用槽） ====================
		# 套路1 助燃燃烧链：燃烧催化剂（所有燃烧 dot ×1.3）
		"gen_combustion_catalyst" = {
			id = "gen_combustion_catalyst",
			name = "燃烧催化剂",
			name_en = "Combustion Catalyst",
			icon = "res://assets/ui/icons/mod_icons/mod_combustion_catalyst.png",
			prototype = "化学催化涂层",
			description = "所有燃烧持续伤害 ×1.3。助燃燃烧链全局增益。",
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
			description = "电磁脉冲真实伤害提升。目标石墨电子损坏 ≥5 时触发电磁脉冲反射，连锁 3 个相邻敌方。电磁脉冲链触发器。",
			rarity = "legendary",
			power_mult = 1.7,
			cost_research = 380,
			cost_install = 190,
			slot_type = "electronic",
			conflict_group = "electronic",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {emp_true_damage_bonus = 8.0, emp_reflect_trigger = true},
			level_effects = {1: {emp_true_damage_bonus = 8, emp_reflect_trigger = true}, 2: {emp_true_damage_bonus = 10.4, emp_reflect_trigger = true}, 3: {emp_true_damage_bonus = 13.6, emp_reflect_trigger = true}},
			unlock_conditions = {required_level = 6}
		},
		# 套路3 纳米浓度场：纳米催化剂（感染扩散触发）
		"gen_nano_catalyst" = {
			id = "gen_nano_catalyst",
			name = "纳米催化剂",
			name_en = "Nano Catalyst",
			icon = "res://assets/ui/icons/mod_icons/mod_nano_catalyst.png",
			prototype = "自复制纳米颗粒",
			description = "纳米病毒概率提升。浓度 ≥50 时 30% 概率感染扩散至相邻敌人。纳米浓度场触发器。",
			rarity = "legendary",
			power_mult = 1.8,
			cost_research = 400,
			cost_install = 200,
			slot_type = "special",
			conflict_group = "catalyst",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [4, 4],
			effects = {nano_chance = 0.20, nano_pct = 0.015, nano_duration = 6.0, nano_spread_trigger = true},
			level_effects = {1: {nano_chance = 0.2, nano_pct = 0.015, nano_duration = 6, nano_spread_trigger = true}, 2: {nano_chance = 0.26, nano_pct = 0.019, nano_duration = 7.8, nano_spread_trigger = true}, 3: {nano_chance = 0.34, nano_pct = 0.025, nano_duration = 10.2, nano_spread_trigger = true}},
			unlock_conditions = {required_level = 6}
		},
		# 套路4 光束谐振链：光束分裂器（多重攻击触发）
		"gen_beam_splitter" = {
			id = "gen_beam_splitter",
			name = "光束分裂器",
			name_en = "Beam Splitter",
			icon = "res://assets/ui/icons/mod_icons/mod_beam_splitter.png",
			prototype = "分光棱镜组件",
			description = "光束武器命中激光谐振 ≥3 的目标时追加 2 道次级光束，每道 40% 伤害。光束谐振链触发器。",
			rarity = "legendary",
			power_mult = 1.8,
			cost_research = 400,
			cost_install = 200,
			slot_type = "optical",
			conflict_group = "optical",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [4, 4],
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
			description = "光束武器命中带激光谐振的目标时 30% 概率反射至相邻敌方，衰减 60%。光束谐振链触发器。",
			rarity = "epic",
			power_mult = 1.6,
			cost_research = 340,
			cost_install = 170,
			slot_type = "optical",
			conflict_group = "optical",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [4, 4],
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
			description = "命中同时带有无人机标记与雷达锁定的目标时触发弱点暴露，下次命中 +50% 暴击伤害。侦察链式触发器。",
			rarity = "legendary",
			power_mult = 1.7,
			cost_research = 380,
			cost_install = 190,
			slot_type = "sensor",
			conflict_group = "sensor",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
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
			description = "化学持续伤害 ×1.2。每次化学命中额外累积战场污染度。化学污染场触发器。",
			rarity = "epic",
			power_mult = 1.6,
			cost_research = 340,
			cost_install = 170,
			slot_type = "special",
			conflict_group = "catalyst",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {chem_dps_mult = 0.20, chem_pollute = 2.0},
			level_effects = {1: {chem_dps_mult = 0.2, chem_pollute = 2}, 2: {chem_dps_mult = 0.26, chem_pollute = 2.6}, 3: {chem_dps_mult = 0.34, chem_pollute = 3.4}},
			unlock_conditions = {required_level = 5}
		},

		# ==================== v21 P1 行为改写型传奇改造（6 个，计划 §P1-2）====================
		# 标定口径：对齐尾槽传奇档（gen_14: power_mult 2.0 / 500·250；gen_17: 1.8 / 400·200）。
		# 行为改写词条"改规则不加数值"，power_mult 取 1.6~2.0，按改变战法幅度分档；
		# effect key 均为注册表未知键 → 自动落入 _special（mod_special_flags meta），
		# 由各消费点读取（attack_calculator / target_selection / construct_unit_ai /
		# construct_unit.heal / unit_stats_table._extract_aura_summary_to_meta / 曲射 batch）。
		# 弹道重赋：攻击维度转换 对轻→对甲（龙崖·转属性卷轴）
		"gen_converted_munitions" = {
			id = GEN_CONVERTED_MUNITIONS,
			name = "弹道重赋",
			name_en = "Converted Munitions",
			icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
			prototype = "模块化弹药重赋系统",
			description = "攻击维度转换：对轻轴攻击整体转按对甲轴结算（武器、攻值、目标防御三维都走对甲），对甲与对空轴不变。适合对甲火力远强于对轻的载具与火炮。",
			rarity = "legendary",
			power_mult = 1.8,
			cost_research = 400,
			cost_install = 200,
			slot_type = "ammunition",
			conflict_group = "ammunition",
			applicable_types = [0, 1, 2],  # LIGHT/ARMOR/SUPPORT（对空轴不受影响，空中装无意义）
			era_band = [3, 4],
			effects = {converted_munitions = true},
			unlock_conditions = {required_level = 7}
		},
		# 扩容弹舱：同时攻击目标数 +1（龙崖·温玉戒指 单奶→群奶）
		"gen_expansion_chamber" = {
			id = GEN_EXPANSION_CHAMBER,
			name = "扩容弹舱",
			name_en = "Expansion Chamber",
			icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
			prototype = "多联装供弹机构",
			description = "同时攻击目标数 +1。每次开火额外向射程内另一敌人射击，全额伤害独立结算。",
			rarity = "legendary",
			power_mult = 1.9,
			cost_research = 450,
			cost_install = 220,
			slot_type = "ammunition",
			conflict_group = "expansion",
			applicable_types = [0, 1, 2, 4],  # 地面单位（空中单位多目标压制过强，不开放）
			effects = {expansion_chamber = true},
			unlock_conditions = {required_level = 7}
		},
		# 溢流护盾：溢出维修按比例转护盾（龙崖·治疗吸收属性）
		"gen_overflow_shield" = {
			id = GEN_OVERFLOW_SHIELD,
			name = "溢流护盾",
			name_en = "Overflow Shield",
			icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
			prototype = "再生式能量缓冲层",
			description = "溢流转化：治疗超出生命上限的部分按 60% 转化为护盾。护盾上限不变，仍为双倍生命值。",
			rarity = "legendary",
			power_mult = 1.7,
			cost_research = 420,
			cost_install = 210,
			slot_type = "protection",
			conflict_group = "protection",
			applicable_types = [0, 1, 2, 4],  # 有医疗/维修光环收益的地面位
			era_band = [4, 4],
			effects = {overflow_to_shield = 0.60},
			level_effects = {1: {overflow_to_shield = 0.6}, 2: {overflow_to_shield = 0.6}, 3: {overflow_to_shield = 0.6}},
			unlock_conditions = {required_level = 7}
		},
		# 精确制导针：无视 50% 闪避（补"命中 vs 闪避"缺失的半轴）
		"gen_truestrike_pinpoint" = {
			id = GEN_TRUESTRIKE_PINPOINT,
			name = "精确制导针",
			name_en = "Truestrike Pinpoint",
			icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
			prototype = "末端成像制导组件",
			description = "按比例无视目标 50% 闪避率。高闪避侦察与飞行单位的天敌。",
			rarity = "legendary",
			power_mult = 1.6,
			cost_research = 380,
			cost_install = 190,
			slot_type = "guidance",
			conflict_group = "guidance",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {dodge_ignore = 0.50},
			level_effects = {1: {dodge_ignore = 0.5}, 2: {dodge_ignore = 0.6}, 3: {dodge_ignore = 0.6}},
			unlock_conditions = {required_level = 6}
		},
		# 中继天线：该卡改造光环 R1→全场（联动 P0 范围化，unit_stats_table 写 range_override=-1）
		"gen_relay_antenna" = {
			id = GEN_RELAY_ANTENNA,
			name = "中继天线",
			name_en = "Relay Antenna",
			icon = "res://assets/ui/icons/mod_icons/mod_comms.png",
			prototype = "战场数据链中继塔",
			description = "改造光环（ally_* 类）影响范围扩至全场。需同时装备带光环的改造方有收益。",
			rarity = "legendary",
			power_mult = 1.6,
			cost_research = 360,
			cost_install = 180,
			slot_type = "comms",
			conflict_group = "comms",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {relay_antenna = true},
			unlock_conditions = {required_level = 6}
		},
		# 统一装药：溅射公式统一词条——曲射 batch 固定 50% 溅射改读 shooter splash_damage
		#（无则回退 0.5；MAX_AOE_TARGETS_PER_HIT=4 不变；bullet 兜底路径不动——B4 最小对齐，计划 §7 风险 5 允许）
		"gen_unified_splash" = {
			id = GEN_UNIFIED_SPLASH,
			name = "统一装药",
			name_en = "Unified Charge",
			icon = "res://assets/ui/icons/mod_icons/mod_explosion.png",
			prototype = "标准化高爆装药",
			description = "统一溅射公式：自身溅射比例 60%，曲射与命中路径共用一轴，所有命中附带 60% 溅射伤害。",
			rarity = "legendary",
			power_mult = 2.0,
			cost_research = 500,
			cost_install = 250,
			slot_type = "ammunition",
			conflict_group = "expansion",
			applicable_types = [0, 1, 2, 3, 4],
			# splash_damage 走注册表既有键（cap 0.8），命中路径 _apply_splash 自动消费；
			# 曲射 batch 的 50%→splash_damage 读取端见 simple_indirect_projectile_batch。
			effects = {splash_damage = 0.60, splash_radius = 0.15},
			unlock_conditions = {required_level = 8}
		},
		# ─── v26 轰炸时代批 ───
		"gen_stealth_coating" = {
			id = "gen_stealth_coating",
			name = "雷达吸波涂层",
			name_en = "Radar-Absorbent Coating",
			icon = "res://assets/ui/icons/mod_icons/gen_stealth_coating.png",
			prototype = "铁氧体吸波材料（RAM 涂层）",
			description = "机体与车体表面吸波涂层，降低雷达与火控锁定。闪避与对空防御提升。",
			rarity = "rare",
			power_mult = 1.3,
			cost_research = 150,
			cost_install = 75,
			slot_type = "camo",
			conflict_group = "stealth",
			applicable_types = [0, 1, 2, 3],
			era_band = [2, 4],
			effects = {dodge_chance = 0.08, defense_air = 8},
			unlock_conditions = {required_level = 3}
		},

	
		# ══════════ v27 改造2.0 批：触发式 ×2 + 团队增益 + mythic 行为改写 ×3 ══════════
		# v27 触发式：痛苦传导（受击 → 攻击者减速）。消费点 module_effect_handler.on_damage_taken（复用 _slow_aura meta）
		"gen_18_pain_conductor" = {
			id = "gen_18_pain_conductor",
			name = "痛苦传导",
			name_en = "Pain Conductor",
			icon = "res://assets/ui/icons/mod_icons/mod_protection.png",
			prototype = "诱饵应答机",
			description = "受击时向攻击者传导迟滞信号：减速 20%，持续 2 秒。",
			rarity = "uncommon",
			power_mult = 1.0,
			cost_research = 110,
			cost_install = 55,
			slot_type = "protection",
			conflict_group = "protection",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {pain_conduct_slow = 0.20, pain_conduct_duration = 2.0},
			level_effects = {1: {pain_conduct_slow = 0.20, pain_conduct_duration = 2.0}, 2: {pain_conduct_slow = 0.25, pain_conduct_duration = 2.5}, 3: {pain_conduct_slow = 0.30, pain_conduct_duration = 3.0}},
			unlock_conditions = {required_level = 2}
		},
		# v27 触发式：波次动员（新波次 → 全队护盾）。消费点 module_effect_handler.on_wave_spawned（battle_manager 波次链调用）
		"gen_19_wave_surge" = {
			id = "gen_19_wave_surge",
			name = "波次动员",
			name_en = "Wave Surge",
			icon = "res://assets/ui/icons/mod_icons/mod_command.png",
			prototype = "全员动员令",
			description = "敌方新波次来袭时全员进入戒备：全队获得 5% 最大生命的护盾。",
			rarity = "rare",
			power_mult = 1.3,
			cost_research = 180,
			cost_install = 90,
			slot_type = "comms",
			conflict_group = "comms",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {wave_surge_shield = 0.05},
			level_effects = {1: {wave_surge_shield = 0.05}, 2: {wave_surge_shield = 0.07}, 3: {wave_surge_shield = 0.09}},
			unlock_conditions = {required_level = 4}
		},
		"gen_20_squad_tablet" = {
			id = "gen_20_squad_tablet",
			name = "班组战术平板",
			name_en = "Squad Tactical Tablet",
			icon = "res://assets/ui/icons/mod_icons/mod_command.png",
			prototype = "班组态势平板",
			description = "班组级态势共享。周围友军攻击 +4%，指挥效率 +8%。",
			rarity = "rare",
			power_mult = 1.3,
			cost_research = 170,
			cost_install = 85,
			slot_type = "comms",
			conflict_group = "comms",
			applicable_types = [0, 1, 2, 3, 4],
			effects = {ally_bonus = 0.04, command_efficiency = 0.08},
			level_effects = {1: {ally_bonus = 0.04, command_efficiency = 0.08}, 2: {ally_bonus = 0.05, command_efficiency = 0.10}, 3: {ally_bonus = 0.07, command_efficiency = 0.14}},
			unlock_conditions = {required_level = 3}
		},
		# ── v27 mythic 行为改写三件（顶级追求；效果键均落 _special，消费点 module_effect_handler）──
		# 全队击杀 → 自身回复（先锋维修矩阵）
		"gen_21_vanguard_repair" = {
			id = "gen_21_vanguard_repair",
			name = "先锋维修矩阵",
			name_en = "Vanguard Repair Matrix",
			icon = "res://assets/ui/icons/mod_icons/mod_repair.png",
			prototype = "自愈维修矩阵",
			description = "全队任意成员击杀敌方时，自身回复 4% 最大生命值（不要求本人击杀）。",
			rarity = "mythic",
			power_mult = 2.2,
			cost_research = 600,
			cost_install = 300,
			slot_type = "repair",
			conflict_group = "repair",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {vanguard_repair = 0.04},
			level_effects = {1: {vanguard_repair = 0.04}, 2: {vanguard_repair = 0.05}, 3: {vanguard_repair = 0.06}},
			unlock_conditions = {required_level = 8}
		},
		# 周期性为最低血量友军补盾（神盾协议）
		"gen_22_aegis_protocol" = {
			id = "gen_22_aegis_protocol",
			name = "神盾协议",
			name_en = "Aegis Protocol",
			icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
			prototype = "自主防御协议",
			description = "每 8 秒自动为 200px 内生命比例最低的友军提供 6% 最大生命的护盾。",
			rarity = "mythic",
			power_mult = 2.0,
			cost_research = 600,
			cost_install = 300,
			slot_type = "protection",
			conflict_group = "protection",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [3, 4],
			effects = {aegis_pulse_cd = 8.0, aegis_pulse_shield = 0.06},
			level_effects = {1: {aegis_pulse_cd = 8.0, aegis_pulse_shield = 0.06}, 2: {aegis_pulse_cd = 6.5, aegis_pulse_shield = 0.08}, 3: {aegis_pulse_cd = 5.0, aegis_pulse_shield = 0.10}},
			unlock_conditions = {required_level = 8}
		},
		# 周期性引力脉冲（范围真伤 + 减速）
		"gen_23_singularity_core" = {
			id = "gen_23_singularity_core",
			name = "奇点核心",
			name_en = "Singularity Core",
			icon = "res://assets/ui/icons/mod_special.png",
			prototype = "微型奇点发生器",
			description = "每 6 秒释放引力脉冲：180px 内敌方受到自身 3% 最大生命的真实伤害并减速 20%（1.5 秒）。",
			rarity = "mythic",
			power_mult = 2.4,
			cost_research = 650,
			cost_install = 320,
			slot_type = "special",
			conflict_group = "special",
			applicable_types = [0, 1, 2, 3, 4],
			era_band = [4, 4],
			effects = {gravity_pulse_cd = 6.0, gravity_pulse_damage = 0.03, gravity_pulse_radius = 180.0},
			level_effects = {1: {gravity_pulse_cd = 6.0, gravity_pulse_damage = 0.03, gravity_pulse_radius = 180.0}, 2: {gravity_pulse_cd = 5.0, gravity_pulse_damage = 0.04, gravity_pulse_radius = 180.0}, 3: {gravity_pulse_cd = 4.0, gravity_pulse_damage = 0.05, gravity_pulse_radius = 180.0}},
			unlock_conditions = {required_level = 8}
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
