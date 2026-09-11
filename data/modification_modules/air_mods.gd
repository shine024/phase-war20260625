extends RefCounted
class_name AirModifications
## 空中单位改造模块定义（14个）

const AIR_01_TURBOFAN = "air_01_turbofan"
const AIR_02_VECTOR_THRUST = "air_02_vector_thrust"
const AIR_03_STEALTH_COATING = "air_03_stealth_coating"
const AIR_04_AESA = "air_04_aesa"
const AIR_05_HELMET_SIGHT = "air_05_helmet_sight"
const AIR_06_BVR_MISSILE = "air_06_bvr_missile"
const AIR_07_DOGFIGHT_MISSILE = "air_07_dogfight_missile"
const AIR_08_ECM = "air_08_ecm"
const AIR_09_AIR_REFUEL = "air_09_air_refuel"
const AIR_10_DROP_TANK = "air_10_drop_tank"
const AIR_11_WEAPON_RACK = "air_11_weapon_rack"
const AIR_12_DATA_LINK = "air_12_data_link"
const AIR_13_EJECTION_SEAT = "air_13_ejection_seat"
const AIR_14_SWING_WING = "air_14_swing_wing"

const DATA: Dictionary = {
	"air_01_turbofan" = {
		id = AIR_01_TURBOFAN, name = "涡扇发动机", name_en = "Turbofan Engine",
		icon = "res://assets/ui/icons/mod_icons/mod_engine.png",
		prototype = "F100-PW-220", description = "大推力涡扇换装。部署加速 60%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "engine", conflict_group = "engine",
		era_band = [3, 4],
		effects = {move_speed = 30},
		unlock_conditions = {required_level = 4}
	},
	"air_02_vector_thrust" = {
		id = AIR_02_VECTOR_THRUST, name = "矢量推力", name_en = "Thrust Vectoring",
		icon = "res://assets/ui/icons/mod_icons/mod_thrust.png",
		prototype = "F-22/F-35", description = "推力矢量喷管。机动性大幅提升。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 450, cost_install = 225,
		slot_type = "thrust", conflict_group = "thrust",
		era_band = [3, 4],
		effects = {dodge_chance = 0.15},
		unlock_conditions = {required_level = 7}
	},
	"air_03_stealth_coating" = {
		id = AIR_03_STEALTH_COATING, name = "隐身涂层", name_en = "Stealth Coating",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "RAM吸波材料", description = "雷达吸波隐身涂层。闪避 +40%。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 500, cost_install = 250,
		slot_type = "stealth", conflict_group = "stealth",
		era_band = [3, 4],
		effects = {lock_reduction = -0.40},
		unlock_conditions = {required_level = 8}
	},
	"air_04_aesa" = {
		id = AIR_04_AESA, name = "有源相控阵雷达", name_en = "AESA Radar",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "AN/APG-77", description = "多目标锁定。大范围溅射与射程提升。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 480, cost_install = 240,
		slot_type = "radar", conflict_group = "radar",
		# v7.x: per-slot 弹道——对装甲槽改 ROCKET 集束炸弹
		condition_slot = 1,
		era_band = [3, 4],
		effects = {splash_damage = 0.5, splash_radius = 0.5, attack_range = 60, slot_weapon_type = 3},  # v7.x: 对装甲槽火箭（集束）,
		unlock_conditions = {required_level = 7}
	},
	"air_05_helmet_sight" = {
		id = AIR_05_HELMET_SIGHT, name = "头盔瞄准具", name_en = "Helmet Mounted Sight",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		prototype = "苏-27/阿帕奇", description = "头盔瞄准具离轴发射。射速提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "optics", conflict_group = "optics",
		era_band = [2, 4],
		effects = {attack_interval = -0.40},
		unlock_conditions = {required_level = 5}
	},
	"air_06_bvr_missile" = {
		id = AIR_06_BVR_MISSILE, name = "超视距导弹", name_en = "BVR Missile",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon_air.png",
		prototype = "AIM-120C", description = "超视距空空导弹。射程与暴击伤害提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 350, cost_install = 175,
		slot_type = "missile", conflict_group = "missile",
		# v7.x: per-slot 弹道——对空槽改 MISSILE 空空导弹
		condition_slot = 2,
		era_band = [3, 4],
		effects = {attack_range = 90, accuracy_bonus = 0.25, slot_weapon_type = 9},  # v7.x: 对空槽导弹（空战）,
		unlock_conditions = {required_level = 6}
	},
	"air_07_dogfight_missile" = {
		id = AIR_07_DOGFIGHT_MISSILE, name = "格斗弹舱", name_en = "Dogfight Missile",
		icon = "res://assets/ui/icons/mod_icons/mod_missile.png",
		prototype = "AIM-9X", description = "红外格斗导弹。暴击伤害提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "missile", conflict_group = "missile",
		# v7.x: per-slot 弹道——对空槽改 MISSILE 格斗导弹
		condition_slot = 2,
		era_band = [3, 4],
		effects = {close_accuracy = 0.35, slot_weapon_type = 9},  # v7.x: 对空槽导弹（近距格斗）,
		unlock_conditions = {required_level = 5}
	},
	"air_08_ecm" = {
		id = AIR_08_ECM, name = "电子对抗系统", name_en = "ECM Suite",
		icon = "res://assets/ui/icons/mod_icons/mod_ecm.png",
		prototype = "AN/ALQ-211", description = "电子对抗干扰。导弹闪避提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 380, cost_install = 190,
		slot_type = "ecm", conflict_group = "ecm",
		era_band = [2, 4],
		effects = {missile_dodge = 0.30},
		unlock_conditions = {required_level = 6}
	},
	"air_09_air_refuel" = {
		id = AIR_09_AIR_REFUEL, name = "空中加油口", name_en = "Aerial Refueling",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "伙伴加油", description = "空中加油补给。攻速 +50%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 220, cost_install = 110,
		slot_type = "logistics", conflict_group = "logistics",
		era_band = [1, 4],
		effects = {sustained_combat = 0.50},
		level_effects = {1: {sustained_combat = 0.5}, 2: {sustained_combat = 0.6}, 3: {sustained_combat = 0.6}},
		unlock_conditions = {required_level = 4}
	},
	"air_10_drop_tank" = {
		id = AIR_10_DROP_TANK, name = "副油箱", name_en = "Drop Tank",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "增加燃料", description = "外挂副油箱增加燃料。暴击率提升。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 100, cost_install = 50,
		slot_type = "logistics", conflict_group = "logistics",
		effects = {combat_range = 0.40},
		level_effects = {1: {combat_range = 0.4}, 2: {combat_range = 0.52}, 3: {combat_range = 0.6}},
		unlock_conditions = {required_level = 2}
	},
	"air_11_weapon_rack" = {
		id = AIR_11_WEAPON_RACK, name = "外挂武器架", name_en = "Weapon Rack",
		icon = "res://assets/ui/icons/mod_icons/mod_weapons.png",
		prototype = "复合挂架", description = "复合挂架外挂武器。攻速 +50%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "weapons", conflict_group = "weapons",
		effects = {ammo_capacity = 0.50},
		unlock_conditions = {required_level = 4}
	},
	"air_12_data_link" = {
		id = AIR_12_DATA_LINK, name = "数据链系统", name_en = "Data Link",
		icon = "res://assets/ui/icons/mod_icons/mod_command.png",
		prototype = "Link 16", description = "数据链编队协同：自身三维攻击 +7.5%，周围友军三维攻击 +7.5%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 340, cost_install = 170,
		slot_type = "command", conflict_group = "command",
		era_band = [3, 4],
		effects = {formation_bonus = 0.15},
		unlock_conditions = {required_level = 6}
	},
	"air_13_ejection_seat" = {
		id = AIR_13_EJECTION_SEAT, name = "钛合金浴缸座舱", name_en = "Titanium Bathtub Cockpit",
		icon = "res://assets/ui/icons/mod_icons/mod_survival.png",
		prototype = "A-10钛合金装甲浴缸", description = "钛合金装甲包裹座舱。抗弹能力大幅提升。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 120, cost_install = 60,
		slot_type = "survival", conflict_group = "survival",
		era_band = [3, 4],
		effects = {defense_armor = 25, max_hp = 30},
		level_effects = {1: {defense_armor = 25, max_hp = 30}, 2: {defense_armor = 44, max_hp = 50}, 3: {defense_armor = 62, max_hp = 70}},
		unlock_conditions = {required_level = 2}
	},
	"air_14_swing_wing" = {
		id = AIR_14_SWING_WING, name = "可变后掠翼", name_en = "Swing Wing",
		icon = "res://assets/ui/icons/mod_icons/mod_aerodynamics.png",
		prototype = "F-14雄猫", description = "可变后掠翼。部署加速 40%，闪避 +10%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 360, cost_install = 180,
		slot_type = "aerodynamics", conflict_group = "aerodynamics",
		era_band = [2, 4],
		effects = {move_speed = 20, dodge_chance = 0.10},
		unlock_conditions = {required_level = 5}
	},

	# ─── v7.x 新机制改造 ───

	# 连击型：加力燃烧室（攻击 3 次后爆发 +40% 攻速）
	"air_15_afterburner" = {
		id = "air_15_afterburner",
		name = "加力燃烧室",
		name_en = "Afterburner",
		icon = "res://assets/ui/icons/mod_icons/mod_thrust.png",
		prototype = "F-119 推力矢量引擎",
		description = "连续攻击激活加力：每 3 次命中触发爆发，本次额外造成 40% 伤害",
		rarity = "legendary",
		power_mult = 1.7,
		cost_research = 380,
		cost_install = 190,
		slot_type = "special",
		conflict_group = "special",
		era_band = [2, 4],
		effects = {combo_system = 3, combo_bonus = 0.40},
		level_effects = {1: {combo_system = 3, combo_bonus = 0.4}, 2: {combo_system = 4, combo_bonus = 0.52}, 3: {combo_system = 5, combo_bonus = 0.6}},
		unlock_conditions = {required_level = 6}
	},

	# ==================== v9.1 组合技套路配套改造（3 个） ====================
	# 套路1 助燃燃烧链：温压弹（化学爆发的范围扩散触发器）
	"air_thermolite_bomb" = {
		id = "air_thermolite_bomb",
		name = "温压弹",
		name_en = "Thermobaric Bomb",
		icon = "res://assets/ui/icons/mod_icons/mod_thermolite.png",
		prototype = "云爆弹战斗部",
		description = "命中 30% 概率挂燃烧。层数 ≥8 时触发化学爆发，半径 80 内感染 3 个相邻敌人。助燃燃烧链触发器。",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 400,
		cost_install = 200,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		era_band = [3, 4],
		effects = {burn_chance = 0.30, burn_dps = 10.0, chem_burst_trigger = true, attack_air = 0.08},
		level_effects = {1: {burn_chance = 0.3, burn_dps = 10, chem_burst_trigger = true, attack_air = 0.08}, 2: {burn_chance = 0.39, burn_dps = 13, chem_burst_trigger = true, attack_air = 0.104}, 3: {burn_chance = 0.51, burn_dps = 17, chem_burst_trigger = true, attack_air = 0.136}},
		applicable_types = [3],
		unlock_conditions = {required_level = 6}
	},
	# 套路2 电磁脉冲链：反辐射导弹（对高 charge 目标斩杀）
	"air_antiradiation_missile" = {
		id = "air_antiradiation_missile",
		name = "反辐射导弹",
		name_en = "Anti-Radiation Missile",
		icon = "res://assets/ui/icons/mod_icons/mod_missile.png",
		prototype = "AGM-88 HARM",
		description = "电磁伤害提升。目标石墨电子损坏层数越高伤害越高，每层 +15%。电磁脉冲链触发器。",
		rarity = "legendary",
		power_mult = 1.9,
		cost_research = 420,
		cost_install = 210,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		era_band = [3, 4],
		effects = {emp_chance = 0.45, emp_true_damage = 15.0, graphite_execute = true, attack_air = 0.10},
		applicable_types = [3],
		unlock_conditions = {required_level = 6}
	},
	# 套路4 光束谐振链：瞄准激光（强化 resonance 标记）
	"air_targeting_laser" = {
		id = "air_targeting_laser",
		name = "瞄准激光",
		name_en = "Targeting Laser",
		icon = "res://assets/ui/icons/mod_icons/mod_targeting_laser.png",
		prototype = "机载激光指示吊舱",
		description = "命中 60% 概率挂激光谐振层数，累积 ≥3 触发多重攻击。光束谐振链触发器。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 340,
		cost_install = 170,
		slot_type = "sensor",
		conflict_group = "sensor",
		era_band = [3, 4],
		effects = {laser_resonance_chance = 0.60, laser_resonance_stacks = 1, crit_chance = 0.05},
		applicable_types = [3],
		unlock_conditions = {required_level = 5}
	},

	# ==================== v10 解题式玩法：转换型改造 ====================
	# 相位偏移：受暴击→下次必暴（敌方暴击优势转为我方反击优势）
	"air_16_phase_shift" = {
		id = "air_16_phase_shift",
		name = "相位偏移",
		name_en = "Phase Shift",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "相位偏移装甲板",
		description = "受到暴击时相位偏移引擎储能。下次攻击必定暴击，敌方暴击优势转化为我方反击。",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 400,
		cost_install = 200,
		slot_type = "special",
		conflict_group = "special",
		effects = {phase_shift_counter = 1},
		level_effects = {1: {phase_shift_counter = 1}, 2: {phase_shift_counter = 1}, 3: {phase_shift_counter = 2}},
		applicable_types = [3],
		unlock_conditions = {required_level = 6}
	},
	# ─── v26 轰炸机/多用途主题批（era1-4，敌方配装 + 玩家通用）───
	"air_17_bombsight" = {
		id = "air_17_bombsight",
		name = "轰炸瞄准具",
		name_en = "Bombsight",
		icon = "res://assets/ui/icons/mod_icons/air_17_bombsight.png",
		prototype = "诺顿瞄准具（Norden M-9）",
		description = "机械陀螺瞄准计算机，高空精确投弹——暴击与真实伤害提升",
		rarity = "uncommon",
		power_mult = 1.1,
		cost_research = 90,
		cost_install = 45,
		slot_type = "optics",
		conflict_group = "optics",
		era_band = [1, 3],
		effects = {crit_chance = 0.06, true_damage = 10},
		unlock_conditions = {required_level = 2}
	},

	"air_18_heavy_rack" = {
		id = "air_18_heavy_rack",
		name = "重载挂架",
		name_en = "Heavy Bomb Rack",
		icon = "res://assets/ui/icons/mod_icons/air_18_heavy_rack.png",
		prototype = "B-17 载弹挂架（单机 8 吨载弹量）",
		description = "强化挂架结构与机体承重——耐久与对装甲投弹量提升",
		rarity = "uncommon",
		power_mult = 1.1,
		cost_research = 100,
		cost_install = 50,
		slot_type = "hardpoint",
		conflict_group = "hardpoint",
		era_band = [1, 4],
		effects = {max_hp = 25, attack_armor_pct = 0.10},
		unlock_conditions = {required_level = 2}
	},

	"air_19_cluster_dispenser" = {
		id = "air_19_cluster_dispenser",
		name = "集束布撒器",
		name_en = "Cluster Dispenser",
		icon = "res://assets/ui/icons/mod_icons/air_19_cluster_dispenser.png",
		prototype = "CBU-87 集束炸弹 / SUU-64 布撒器",
		description = "一次投弹覆盖大片地面目标。溅射比例与溅射范围提升，轰炸机核心配置。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		era_band = [2, 4],
		effects = {splash_damage = 0.25, splash_radius = 0.30},
		unlock_conditions = {required_level = 3}
	},

	"air_20_standoff_missile" = {
		id = "air_20_standoff_missile",
		name = "防区外导弹",
		name_en = "Standoff Missile",
		icon = "res://assets/ui/icons/mod_icons/air_20_standoff_missile.png",
		prototype = "AGM-158 JASSM",
		description = "防区外发射的隐身巡航导弹——射程与对装甲伤害大幅提升",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 260,
		cost_install = 130,
		slot_type = "weapon",
		conflict_group = "weapon",
		era_band = [3, 4],
		effects = {attack_range = 40, attack_armor_pct = 0.20},
		level_effects = {1: {attack_range = 40, attack_armor_pct = 0.2}, 2: {attack_range = 52, attack_armor_pct = 0.26}, 3: {attack_range = 68, attack_armor_pct = 0.34}},
		unlock_conditions = {required_level = 4}
	},

	"air_21_terrain_radar" = {
		id = "air_21_terrain_radar",
		name = "地形跟随雷达",
		name_en = "Terrain-Following Radar",
		icon = "res://assets/ui/icons/mod_icons/air_21_terrain_radar.png",
		prototype = "F-111 TFR / 德州仪器 AN/APQ-116",
		description = "自动贴地飞行规避雷达锁定——闪避提升",
		rarity = "uncommon",
		power_mult = 1.1,
		cost_research = 100,
		cost_install = 50,
		slot_type = "system",
		conflict_group = "system",
		era_band = [2, 4],
		effects = {dodge_chance = 0.08},
		unlock_conditions = {required_level = 2}
	},

	"air_22_countermeasure" = {
		id = "air_22_countermeasure",
		name = "干扰弹布撒器",
		name_en = "Countermeasure Dispenser",
		icon = "res://assets/ui/icons/mod_icons/air_22_countermeasure.png",
		prototype = "AN/ALE-47 箔条/曳光弹",
		description = "来袭导弹与防空火力的软杀伤对抗——闪避与减伤提升",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 140,
		cost_install = 70,
		slot_type = "countermeasure",
		conflict_group = "cm",
		era_band = [2, 4],
		effects = {dodge_chance = 0.06, damage_reduction = 0.08},
		unlock_conditions = {required_level = 3}
	},


	# ══════════ v27 改造2.0 批：普及档 + 机动/生存强化 ══════════
	"air_23_cockpit_armor" = {
		id = "air_23_cockpit_armor",
		name = "座舱装甲",
		name_en = "Cockpit Armor",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		prototype = "浴缸座舱装甲",
		description = "飞行员座舱装甲板。生命 +30，暴击抗性 +5%。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {max_hp = 30, crit_resist = 0.05},
		level_effects = {1: {max_hp = 30, crit_resist = 0.05}, 2: {max_hp = 39, crit_resist = 0.05}, 3: {max_hp = 51, crit_resist = 0.05}},
		unlock_conditions = {required_level = 1}
	},
	"air_24_canard" = {
		id = "air_24_canard",
		name = "鸭翼前置",
		name_en = "Canard Foreplanes",
		icon = "res://assets/ui/icons/mod_icons/mod_aerodynamics.png",
		prototype = "鸭式气动布局",
		description = "鸭翼增升机动。闪避 +6%，移动 +8px/s。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "aerodynamics",
		conflict_group = "aerodynamics",
		effects = {dodge_chance = 0.06, move_speed = 8},
		level_effects = {1: {dodge_chance = 0.06, move_speed = 8}, 2: {dodge_chance = 0.08, move_speed = 10}, 3: {dodge_chance = 0.10, move_speed = 14}},
		unlock_conditions = {required_level = 2}
	},
	"air_25_dual_mode_seeker" = {
		id = "air_25_dual_mode_seeker",
		name = "双模导引头",
		name_en = "Dual-Mode Seeker",
		icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
		prototype = "雷达/红外双模导引",
		description = "双模导引抗干扰。对轻装伤害 +10%，暴击率 +4%。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "guidance",
		conflict_group = "guidance",
		era_band = [2, 4],
		effects = {attack_light = 0.10, crit_chance = 0.04},
		level_effects = {1: {attack_light = 0.10, crit_chance = 0.04}, 2: {attack_light = 0.13, crit_chance = 0.05}, 3: {attack_light = 0.17, crit_chance = 0.07}},
		unlock_conditions = {required_level = 3}
	},
	"air_26_drone_wingman" = {
		id = "air_26_drone_wingman",
		name = "蜂群僚机",
		name_en = "Drone Wingman",
		icon = "res://assets/ui/icons/mod_icons/mod_drone.png",
		prototype = "伴随无人机群",
		description = "僚机群掩护与指示。暴击率 +7%，闪避 +5%。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "special",
		conflict_group = "special",
		era_band = [3, 4],
		effects = {crit_chance = 0.07, dodge_chance = 0.05},
		level_effects = {1: {crit_chance = 0.07, dodge_chance = 0.05}, 2: {crit_chance = 0.09, dodge_chance = 0.065}, 3: {crit_chance = 0.12, dodge_chance = 0.085}},
		unlock_conditions = {required_level = 5}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 3: return DATA.keys()  # AIR
	return []

static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	return data_a.get("conflict_group", "") == data_b.get("conflict_group", "") and data_a.get("conflict_group", "") != ""

## 按 card_id 精筛（优先于 get_for_unit_type）
static func get_for_card(card_id: String) -> Array:
	if _matches_card(card_id):
		return DATA.keys()
	return []

static func _matches_card(card_id: String) -> bool:
	for prefix in _CARD_PREFIXES:
		if card_id.begins_with(prefix):
			return true
	return false

# v7.x: fut_scout_drone 已重命名为 mod_inf_scout_drone；补 fut_nano_drone(combat_kind=3)
const _CARD_PREFIXES: Array = ["cold_mig21", "cold_f4", "mod_ah64", "mod_ah1", "mod_uh60", "fut_swarm", "mod_inf_scout_drone", "fut_attack_drone", "fut_stealth_bomber", "fut_space_fighter", "fut_nano_drone"]
