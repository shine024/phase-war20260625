class_name CapturedCardStats
extends RefCounted

## 110 张缴获卡全量静态数据表
## 数据严格复刻 _build_captured_card 动态推导逻辑，供策划独立调整平衡
## Key: captured_<archetype_id>, Value: Dictionary

const CAPTURED_STATS: Dictionary = {
	# ==========================================
	# A 段：新时代单位 (28个)
	# ==========================================

	# 一战 (5)
	"captured_foe_ww1_rolls": {
		"display_name": "罗尔斯装甲车", "era": 0, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 25.0, "attack_armor": 40.0, "attack_air": 0.0,
		"defense_light": 18.0, "defense_armor": 22.0, "defense_air": 10.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 40.0, "power": 208,
		"weapon_label": "机枪", "type_line": "一战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_ww1_ft17": {
		"display_name": "FT-17轻型坦克", "era": 0, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 25.0, "attack_armor": 40.0, "attack_air": 0.0,
		"defense_light": 18.0, "defense_armor": 22.0, "defense_air": 10.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 40.0, "power": 208,
		"weapon_label": "机枪", "type_line": "一战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_ww1_77mm": {
		"display_name": "77mm野战炮", "era": 0, "combat_kind": 2,
		"base_hp": 260.0, "range_value": 2, "attack_speed": 2.0,
		"attack_light": 45.0, "attack_armor": 0.0, "attack_air": 25.0,
		"defense_light": 12.0, "defense_armor": 8.0, "defense_air": 10.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 197,
		"weapon_label": "机枪", "type_line": "一战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_ww1_cavalry": {
		"display_name": "骑兵斥候", "era": 0, "combat_kind": 0,
		"base_hp": 65.0, "range_value": 1, "attack_speed": 1.49,
		"attack_light": 35.0, "attack_armor": 0.0, "attack_air": 0.0,
		"defense_light": 8.0, "defense_armor": 5.0, "defense_air": 3.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 115.0, "power": 121,
		"weapon_label": "冲锋枪", "type_line": "一战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_ww1_engineer": {
		"display_name": "工兵班", "era": 0, "combat_kind": 2,
		"base_hp": 80.0, "range_value": 1, "attack_speed": 1.0,
		"attack_light": 30.0, "attack_armor": 25.0, "attack_air": 0.0,
		"defense_light": 10.0, "defense_armor": 8.0, "defense_air": 5.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 75.0, "power": 133,
		"weapon_label": "步枪", "type_line": "一战 — 缴获支援", "appear_scope": "主线波次"
	},

	# 二战 (7)
	"captured_foe_ww2_hellcat": {
		"display_name": "M18地狱猫", "era": 1, "combat_kind": 0,
		"base_hp": 90.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 7.0, "attack_armor": 3.0, "attack_air": 3.0,
		"defense_light": 7.0, "defense_armor": 5.0, "defense_air": 5.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 100.0, "power": 69,
		"weapon_label": "机枪", "type_line": "二战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_ww2_sherman": {
		"display_name": "M4谢尔曼", "era": 1, "combat_kind": 1,
		"base_hp": 110.0, "range_value": 2, "attack_speed": 1.05,
		"attack_light": 14.0, "attack_armor": 8.0, "attack_air": 7.0,
		"defense_light": 9.0, "defense_armor": 7.0, "defense_air": 7.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 75.0, "power": 103,
		"weapon_label": "步枪", "type_line": "二战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_ww2_tiger": {
		"display_name": "虎式坦克", "era": 1, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.59,
		"attack_light": 30.0, "attack_armor": 18.0, "attack_air": 15.0,
		"defense_light": 13.0, "defense_armor": 10.0, "defense_air": 10.0,
		"weapon_type": 1, "deploy_speed": 1, "base_speed": 40.0, "power": 168,
		"weapon_label": "迫击炮", "type_line": "二战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_ww2_bazooka": {
		"display_name": "巴祖卡组", "era": 1, "combat_kind": 0,
		"base_hp": 50.0, "range_value": 1, "attack_speed": 2.63,
		"attack_light": 8.0, "attack_armor": 4.0, "attack_air": 4.0,
		"defense_light": 4.0, "defense_armor": 3.0, "defense_air": 3.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 135.0, "power": 88,
		"weapon_label": "冲锋枪", "type_line": "二战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_ww2_panzerschrek": {
		"display_name": "铁拳反坦克组", "era": 1, "combat_kind": 0,
		"base_hp": 50.0, "range_value": 2, "attack_speed": 2.63,
		"attack_light": 8.0, "attack_armor": 4.0, "attack_air": 4.0,
		"defense_light": 4.0, "defense_armor": 3.0, "defense_air": 3.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 135.0, "power": 88,
		"weapon_label": "冲锋枪", "type_line": "二战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_ww2_m81": {
		"display_name": "81mm迫击炮", "era": 1, "combat_kind": 2,
		"base_hp": 260.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 7.0, "attack_armor": 3.0, "attack_air": 3.0,
		"defense_light": 20.0, "defense_armor": 16.0, "defense_air": 16.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 154,
		"weapon_label": "机枪", "type_line": "二战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_ww1_m81": {
		"display_name": "81mm迫击炮组", "era": 0, "combat_kind": 2,
		"base_hp": 260.0, "range_value": 2, "attack_speed": 2.0,
		"attack_light": 45.0, "attack_armor": 0.0, "attack_air": 25.0,
		"defense_light": 12.0, "defense_armor": 8.0, "defense_air": 10.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 197,
		"weapon_label": "机枪", "type_line": "一战 — 缴获支援", "appear_scope": "主线波次"
	},

	# 冷战 (5)
	"captured_foe_cold_btr60": {
		"display_name": "BTR-60装甲车", "era": 2, "combat_kind": 3,
		"base_hp": 140.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 7.0, "attack_armor": 4.0, "attack_air": 4.0,
		"defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 50.0, "power": 95,
		"weapon_label": "机枪", "type_line": "冷战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_cold_t55": {
		"display_name": "T-55坦克", "era": 2, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.59,
		"attack_light": 30.0, "attack_armor": 20.0, "attack_air": 16.0,
		"defense_light": 13.0, "defense_armor": 11.0, "defense_air": 10.0,
		"weapon_type": 1, "deploy_speed": 2, "base_speed": 40.0, "power": 197,
		"weapon_label": "迫击炮", "type_line": "冷战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_cold_bmp1": {
		"display_name": "BMP-1步战车", "era": 2, "combat_kind": 3,
		"base_hp": 140.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 7.0, "attack_armor": 4.0, "attack_air": 4.0,
		"defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 50.0, "power": 95,
		"weapon_label": "机枪", "type_line": "冷战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_cold_m113": {
		"display_name": "M113装甲车", "era": 2, "combat_kind": 3,
		"base_hp": 140.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 7.0, "attack_armor": 4.0, "attack_air": 5.0,
		"defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
		"weapon_type": 2, "deploy_speed": 2, "base_speed": 50.0, "power": 98,
		"weapon_label": "机枪", "type_line": "冷战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_cold_zsu23": {
		"display_name": "ZSU-23-4自行高炮", "era": 2, "combat_kind": 2,
		"base_hp": 180.0, "range_value": 2, "attack_speed": 1.05,
		"attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
		"defense_light": 11.0, "defense_armor": 9.0, "defense_air": 9.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 122,
		"weapon_label": "步枪", "type_line": "冷战 — 缴获支援", "appear_scope": "主线波次"
	},

	# 现代系统 (6)
	"captured_foe_mod_technical": {
		"display_name": "皮卡武装", "era": 3, "combat_kind": 0,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 3.33,
		"attack_light": 18.0, "attack_armor": 5.0, "attack_air": 5.0,
		"defense_light": 7.0, "defense_armor": 5.0, "defense_air": 5.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 120.0, "power": 120,
		"weapon_label": "机枪", "type_line": "现代 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_mod_m1a1": {
		"display_name": "M1A1主战坦克", "era": 3, "combat_kind": 1,
		"base_hp": 220.0, "range_value": 2, "attack_speed": 0.56,
		"attack_light": 50.0, "attack_armor": 40.0, "attack_air": 35.0,
		"defense_light": 15.0, "defense_armor": 12.0, "defense_air": 12.0,
		"weapon_type": 1, "deploy_speed": 2, "base_speed": 60.0, "power": 286,
		"weapon_label": "火炮", "type_line": "现代 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_mod_m6": {
		"display_name": "自行高炮M6", "era": 3, "combat_kind": 2,
		"base_hp": 160.0, "range_value": 3, "attack_speed": 6.67,
		"attack_light": 25.0, "attack_armor": 15.0, "attack_air": 35.0,
		"defense_light": 12.0, "defense_armor": 10.0, "defense_air": 12.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 203,
		"weapon_label": "机枪", "type_line": "现代 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_mod_m270": {
		"display_name": "M270火箭炮", "era": 3, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 4, "attack_speed": 0.4,
		"attack_light": 40.0, "attack_armor": 30.0, "attack_air": 20.0,
		"defense_light": 10.0, "defense_armor": 8.0, "defense_air": 8.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 216,
		"weapon_label": "火箭炮", "type_line": "现代 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_fut_scout_drone": {
		"display_name": "侦察无人机", "era": 3, "combat_kind": 3,
		"base_hp": 50.0, "range_value": 2, "attack_speed": 2.86,
		"attack_light": 8.0, "attack_armor": 8.0, "attack_air": 8.0,
		"defense_light": 3.0, "defense_armor": 3.0, "defense_air": 3.0,
		"weapon_type": 0, "deploy_speed": 6, "base_speed": 135.0, "power": 94,
		"weapon_label": "机枪", "type_line": "现代 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_mod_m1a2sep": {
		"display_name": "M1A2 SEP主战坦克", "era": 3, "combat_kind": 1,
		"base_hp": 240.0, "range_value": 3, "attack_speed": 0.59,
		"attack_light": 55.0, "attack_armor": 45.0, "attack_air": 40.0,
		"defense_light": 16.0, "defense_armor": 13.0, "defense_air": 13.0,
		"weapon_type": 1, "deploy_speed": 2, "base_speed": 65.0, "power": 308,
		"weapon_label": "火炮", "type_line": "现代 — 缴获装甲", "appear_scope": "主线波次"
	},

	# 近未来 (4)
	"captured_foe_fut_scout_mech": {
		"display_name": "侦察机甲", "era": 4, "combat_kind": 0,
		"base_hp": 50.0, "range_value": 2, "attack_speed": 2.0,
		"attack_light": 13.0, "attack_armor": 9.0, "attack_air": 9.0,
		"defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 115.0, "power": 98,
		"weapon_label": "光束步枪", "type_line": "近未来 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_fut_hovertank": {
		"display_name": "悬浮坦克", "era": 4, "combat_kind": 1,
		"base_hp": 90.0, "range_value": 2, "attack_speed": 2.0,
		"attack_light": 13.0, "attack_armor": 9.0, "attack_air": 9.0,
		"defense_light": 7.0, "defense_armor": 6.0, "defense_air": 6.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 100.0, "power": 110,
		"weapon_label": "光束步枪", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_fut_prism": {
		"display_name": "光棱坦克", "era": 4, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 3, "attack_speed": 0.45,
		"attack_light": 220.0, "attack_armor": 180.0, "attack_air": 160.0,
		"defense_light": 13.0, "defense_armor": 11.0, "defense_air": 10.0,
		"weapon_type": 1, "deploy_speed": 1, "base_speed": 40.0, "power": 1226,
		"weapon_label": "米加粒子炮", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_fut_heavy_mech": {
		"display_name": "重装机甲", "era": 4, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 3, "attack_speed": 0.45,
		"attack_light": 220.0, "attack_armor": 180.0, "attack_air": 160.0,
		"defense_light": 13.0, "defense_armor": 11.0, "defense_air": 10.0,
		"weapon_type": 1, "deploy_speed": 1, "base_speed": 40.0, "power": 1226,
		"weapon_label": "米加粒子炮", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_fut_nexus": {
		"display_name": "虚空领主", "era": 4, "combat_kind": 1,
		"base_hp": 240.0, "range_value": 3, "attack_speed": 0.45,
		"attack_light": 220.0, "attack_armor": 180.0, "attack_air": 160.0,
		"defense_light": 15.0, "defense_armor": 12.0, "defense_air": 11.0,
		"weapon_type": 1, "deploy_speed": 1, "base_speed": 30.0, "power": 1248,
		"weapon_label": "米加粒子炮", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},

	# ==========================================
	# B 段：特殊/精英 (6个)
	# ==========================================
	"captured_foe_bulwark": {
		"display_name": "壁垒", "era": 4, "combat_kind": 2,
		"base_hp": 300.0, "range_value": 1, "attack_speed": 1.18,
		"attack_light": 22.0, "attack_armor": 15.0, "attack_air": 13.0,
		"defense_light": 20.0, "defense_armor": 16.0, "defense_air": 16.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 181,
		"weapon_label": "霰弹枪", "type_line": "近未来 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_titan_mk2": {
		"display_name": "泰坦Mk.II", "era": 4, "combat_kind": 1,
		"base_hp": 250.0, "range_value": 2, "attack_speed": 0.5,
		"attack_light": 38.0, "attack_armor": 26.0, "attack_air": 23.0,
		"defense_light": 15.0, "defense_armor": 12.0, "defense_air": 11.0,
		"weapon_type": 1, "deploy_speed": 2, "base_speed": 35.0, "power": 202,
		"weapon_label": "导弹", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_storm_rider": {
		"display_name": "暴风骑士", "era": 4, "combat_kind": 0,
		"base_hp": 60.0, "range_value": 2, "attack_speed": 0.63,
		"attack_light": 28.0, "attack_armor": 19.0, "attack_air": 17.0,
		"defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
		"weapon_type": 2, "deploy_speed": 5, "base_speed": 120.0, "power": 125,
		"weapon_label": "狙击枪", "type_line": "近未来 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_heavy_carrier": {
		"display_name": "重装母舰", "era": 4, "combat_kind": 3,
		"base_hp": 160.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 7.0, "attack_armor": 5.0, "attack_air": 5.0,
		"defense_light": 9.0, "defense_armor": 7.0, "defense_air": 7.0,
		"weapon_type": 2, "deploy_speed": 2, "base_speed": 50.0, "power": 92,
		"weapon_label": "机枪", "type_line": "近未来 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_regen_frame": {
		"display_name": "再生骨架", "era": 4, "combat_kind": 3,
		"base_hp": 100.0, "range_value": 1, "attack_speed": 2.22,
		"attack_light": 7.0, "attack_armor": 5.0, "attack_air": 4.0,
		"defense_light": 6.0, "defense_armor": 5.0, "defense_air": 5.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 75.0, "power": 79,
		"weapon_label": "手枪", "type_line": "近未来 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_abrams_mk2": {
		"display_name": "艾布拉姆斯Mk.II", "era": 3, "combat_kind": 1,
		"base_hp": 220.0, "range_value": 2, "attack_speed": 0.61,
		"attack_light": 140.0, "attack_armor": 100.0, "attack_air": 90.0,
		"defense_light": 12.0, "defense_armor": 10.0, "defense_air": 9.0,
		"weapon_type": 1, "deploy_speed": 2, "base_speed": 65.0, "power": 769,
		"weapon_label": "轨道炮", "type_line": "现代 — 缴获装甲", "appear_scope": "主线波次"
	},

	# ==========================================
	# C 段：固定战场敌人 (36个)
	# ==========================================

	# 一战 (7)
	"captured_enemy_ww1_infantry_basic": {
		"display_name": "步兵班·MP18", "era": 0, "combat_kind": 0,
		"base_hp": 40.0, "range_value": 1, "attack_speed": 4.0,
		"attack_light": 8.0, "attack_armor": 3.2, "attack_air": 2.4,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 80.0, "power": 52,
		"weapon_label": "", "type_line": "一战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_ww1_infantry_rifle": {
		"display_name": "步兵班·步枪", "era": 0, "combat_kind": 0,
		"base_hp": 45.0, "range_value": 2, "attack_speed": 1.49,
		"attack_light": 9.6, "attack_armor": 7.2, "attack_air": 6.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 3, "base_speed": 70.0, "power": 73,
		"weapon_label": "", "type_line": "一战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_ww1_mg_nest": {
		"display_name": "机枪巢", "era": 0, "combat_kind": 2,
		"base_hp": 80.0, "range_value": 1, "attack_speed": 3.03,
		"attack_light": 30.2, "attack_armor": 16.6, "attack_air": 13.3,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 0, "base_speed": 0.0, "power": 139,
		"weapon_label": "", "type_line": "一战 — 缴获支援", "appear_scope": "任务专属"
	},
	"captured_enemy_ww1_mortar": {
		"display_name": "迫击炮组", "era": 0, "combat_kind": 2,
		"base_hp": 60.0, "range_value": 2, "attack_speed": 0.5,
		"attack_light": 80.0, "attack_armor": 48.0, "attack_air": 32.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 4, "base_speed": 40.0, "power": 241,
		"weapon_label": "", "type_line": "一战 — 缴获支援", "appear_scope": "任务专属"
	},
	"captured_elite_ww1_storm": {
		"display_name": "暴风突击队", "era": 0, "combat_kind": 0,
		"base_hp": 70.0, "range_value": 1, "attack_speed": 4.0,
		"attack_light": 36.0, "attack_armor": 14.4, "attack_air": 10.8,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 100.0, "power": 136,
		"weapon_label": "", "type_line": "一战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_elite_ww1_armored": {
		"display_name": "装甲车", "era": 0, "combat_kind": 2,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.82,
		"attack_light": 50.4, "attack_armor": 27.7, "attack_air": 22.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 60.0, "power": 193,
		"weapon_label": "", "type_line": "一战 — 缴获支援", "appear_scope": "任务专属"
	},
	"captured_boss_ww1_av7": {
		"display_name": "圣沙蒙坦克", "era": 0, "combat_kind": 1,
		"base_hp": 300.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 100.0, "attack_armor": 60.0, "attack_air": 40.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 1, "base_speed": 30.0, "power": 495,
		"weapon_label": "", "type_line": "一战 — 缴获装甲", "appear_scope": "BOSS"
	},

	# 二战 (7)
	"captured_enemy_ww2_infantry": {
		"display_name": "步兵班·汤普森", "era": 1, "combat_kind": 0,
		"base_hp": 50.0, "range_value": 1, "attack_speed": 4.55,
		"attack_light": 45.0, "attack_armor": 18.0, "attack_air": 13.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 90.0, "power": 163,
		"weapon_label": "", "type_line": "二战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_ww2_rifleman": {
		"display_name": "步枪班·加兰德", "era": 1, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 2, "attack_speed": 2.0,
		"attack_light": 48.0, "attack_armor": 28.8, "attack_air": 24.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 3, "base_speed": 70.0, "power": 178,
		"weapon_label": "", "type_line": "二战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_ww2_mg42": {
		"display_name": "MG42机枪组", "era": 1, "combat_kind": 2,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 5.0,
		"attack_light": 63.0, "attack_armor": 31.5, "attack_air": 25.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 50.0, "power": 232,
		"weapon_label": "", "type_line": "二战 — 缴获支援", "appear_scope": "任务专属"
	},
	"captured_enemy_ww2_panzerschrek": {
		"display_name": "反坦克组", "era": 1, "combat_kind": 0,
		"base_hp": 70.0, "range_value": 1, "attack_speed": 0.4,
		"attack_light": 120.0, "attack_armor": 72.0, "attack_air": 48.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 3, "base_speed": 60.0, "power": 418,
		"weapon_label": "", "type_line": "二战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_elite_ww2_paratrooper": {
		"display_name": "伞兵精英", "era": 1, "combat_kind": 0,
		"base_hp": 80.0, "range_value": 1, "attack_speed": 4.55,
		"attack_light": 73.0, "attack_armor": 29.2, "attack_air": 21.9,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 110.0, "power": 205,
		"weapon_label": "", "type_line": "二战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_elite_ww2_panther": {
		"display_name": "黑豹坦克", "era": 1, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 1.11,
		"attack_light": 168.0, "attack_armor": 100.8, "attack_air": 67.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 2, "base_speed": 50.0, "power": 779,
		"weapon_label": "", "type_line": "二战 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_boss_ww2_kingtiger": {
		"display_name": "虎王坦克", "era": 1, "combat_kind": 1,
		"base_hp": 400.0, "range_value": 2, "attack_speed": 1.0,
		"attack_light": 200.0, "attack_armor": 120.0, "attack_air": 80.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 1, "base_speed": 30.0, "power": 880,
		"weapon_label": "", "type_line": "二战 — 缴获装甲", "appear_scope": "BOSS"
	},

	# 冷战 (7)
	"captured_enemy_cold_ak": {
		"display_name": "苏军步兵", "era": 2, "combat_kind": 0,
		"base_hp": 60.0, "range_value": 2, "attack_speed": 3.03,
		"attack_light": 67.2, "attack_armor": 40.3, "attack_air": 33.6,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 4, "base_speed": 90.0, "power": 229,
		"weapon_label": "", "type_line": "冷战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_cold_m60": {
		"display_name": "美军步兵", "era": 2, "combat_kind": 0,
		"base_hp": 65.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 100.8, "attack_armor": 50.4, "attack_air": 40.3,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 4, "base_speed": 90.0, "power": 281,
		"weapon_label": "", "type_line": "冷战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_cold_btr": {
		"display_name": "BTR装甲车", "era": 2, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 3.33,
		"attack_light": 105.8, "attack_armor": 52.9, "attack_air": 42.3,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 80.0, "power": 308,
		"weapon_label": "", "type_line": "冷战 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_enemy_cold_m113": {
		"display_name": "M113装甲车", "era": 2, "combat_kind": 3,
		"base_hp": 110.0, "range_value": 1, "attack_speed": 2.86,
		"attack_light": 61.7, "attack_armor": 30.8, "attack_air": 24.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 70.0, "power": 216,
		"weapon_label": "", "type_line": "冷战 — 缴获空中", "appear_scope": "任务专属"
	},
	"captured_elite_cold_spetsnaz": {
		"display_name": "特种部队", "era": 2, "combat_kind": 0,
		"base_hp": 90.0, "range_value": 2, "attack_speed": 0.8,
		"attack_light": 112.0, "attack_armor": 89.6, "attack_air": 67.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 6, "deploy_speed": 5, "base_speed": 120.0, "power": 434,
		"weapon_label": "", "type_line": "冷战 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_elite_cold_t72": {
		"display_name": "T-72坦克", "era": 2, "combat_kind": 1,
		"base_hp": 250.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 160.0, "attack_armor": 96.0, "attack_air": 64.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 2, "base_speed": 60.0, "power": 612,
		"weapon_label": "", "type_line": "冷战 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_boss_cold_mig": {
		"display_name": "米格-29", "era": 2, "combat_kind": 3,
		"base_hp": 450.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 162.0, "attack_armor": 216.0, "attack_air": 108.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 9, "deploy_speed": 6, "base_speed": 150.0, "power": 1014,
		"weapon_label": "", "type_line": "冷战 — 缴获空中", "appear_scope": "BOSS"
	},

	# 现代 (7)
	"captured_enemy_modern_marine": {
		"display_name": "海军陆战队", "era": 3, "combat_kind": 0,
		"base_hp": 70.0, "range_value": 2, "attack_speed": 3.45,
		"attack_light": 81.9, "attack_armor": 49.1, "attack_air": 40.9,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 4, "base_speed": 100.0, "power": 284,
		"weapon_label": "", "type_line": "现代 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_modern_technical": {
		"display_name": "皮卡武装", "era": 3, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 3.33,
		"attack_light": 113.4, "attack_armor": 56.7, "attack_air": 45.4,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 4, "base_speed": 120.0, "power": 326,
		"weapon_label": "", "type_line": "现代 — 缴获空中", "appear_scope": "任务专属"
	},
	"captured_enemy_modern_stryker": {
		"display_name": "斯特赖克装甲车", "era": 3, "combat_kind": 1,
		"base_hp": 150.0, "range_value": 2, "attack_speed": 2.86,
		"attack_light": 126.0, "attack_armor": 63.0, "attack_air": 50.4,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 80.0, "power": 348,
		"weapon_label": "", "type_line": "现代 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_enemy_modern_mlrs": {
		"display_name": "火箭炮车", "era": 3, "combat_kind": 2,
		"base_hp": 100.0, "range_value": 3, "attack_speed": 0.5,
		"attack_light": 210.0, "attack_armor": 126.0, "attack_air": 84.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 4, "base_speed": 50.0, "power": 592,
		"weapon_label": "", "type_line": "现代 — 缴获支援", "appear_scope": "任务专属"
	},
	"captured_elite_modern_delta": {
		"display_name": "三角洲部队", "era": 3, "combat_kind": 0,
		"base_hp": 100.0, "range_value": 2, "attack_speed": 3.45,
		"attack_light": 133.9, "attack_armor": 80.4, "attack_air": 66.9,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 5, "base_speed": 130.0, "power": 379,
		"weapon_label": "", "type_line": "现代 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_elite_modern_abrams": {
		"display_name": "M1A2坦克", "era": 3, "combat_kind": 1,
		"base_hp": 300.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 270.0, "attack_armor": 162.0, "attack_air": 108.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 2, "base_speed": 60.0, "power": 880,
		"weapon_label": "", "type_line": "现代 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_elite_modern_apache": {
		"display_name": "阿帕奇直升机", "era": 3, "combat_kind": 3,
		"base_hp": 220.0, "range_value": 3, "attack_speed": 1.67,
		"attack_light": 266.0, "attack_armor": 177.3, "attack_air": 118.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 9, "deploy_speed": 5, "base_speed": 120.0, "power": 938,
		"weapon_label": "", "type_line": "现代 — 缴获空中", "appear_scope": "任务专属"
	},
	"captured_boss_modern_command": {
		"display_name": "指挥中枢", "era": 3, "combat_kind": 2,
		"base_hp": 700.0, "range_value": 2, "attack_speed": 0.83,
		"attack_light": 294.0, "attack_armor": 147.0, "attack_air": 117.6,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 0, "base_speed": 0.0, "power": 1211,
		"weapon_label": "", "type_line": "现代 — 缴获支援", "appear_scope": "BOSS"
	},

	# 近未来 (7)
	"captured_enemy_future_drone": {
		"display_name": "无人机群", "era": 4, "combat_kind": 3,
		"base_hp": 40.0, "range_value": 2, "attack_speed": 2.5,
		"attack_light": 120.0, "attack_armor": 120.0, "attack_air": 120.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 6, "base_speed": 150.0, "power": 550,
		"weapon_label": "", "type_line": "近未来 — 缴获空中", "appear_scope": "任务专属"
	},
	"captured_enemy_future_cyborg": {
		"display_name": "机械步兵", "era": 4, "combat_kind": 0,
		"base_hp": 100.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 132.0, "attack_armor": 132.0, "attack_air": 132.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 4, "base_speed": 100.0, "power": 624,
		"weapon_label": "", "type_line": "近未来 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_enemy_future_mech": {
		"display_name": "机甲步兵", "era": 4, "combat_kind": 1,
		"base_hp": 180.0, "range_value": 2, "attack_speed": 1.49,
		"attack_light": 126.0, "attack_armor": 126.0, "attack_air": 126.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 3, "base_speed": 80.0, "power": 729,
		"weapon_label": "", "type_line": "近未来 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_enemy_future_hovertank": {
		"display_name": "悬浮坦克", "era": 4, "combat_kind": 1,
		"base_hp": 250.0, "range_value": 3, "attack_speed": 2.0,
		"attack_light": 200.0, "attack_armor": 200.0, "attack_air": 200.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 4, "base_speed": 110.0, "power": 1062,
		"weapon_label": "", "type_line": "近未来 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_elite_future_spectre": {
		"display_name": "幽灵特工", "era": 4, "combat_kind": 0,
		"base_hp": 120.0, "range_value": 2, "attack_speed": 2.5,
		"attack_light": 210.0, "attack_armor": 210.0, "attack_air": 210.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 5, "base_speed": 140.0, "power": 812,
		"weapon_label": "", "type_line": "近未来 — 缴获轻装", "appear_scope": "任务专属"
	},
	"captured_elite_future_colossus": {
		"display_name": "巨神机甲", "era": 4, "combat_kind": 1,
		"base_hp": 400.0, "range_value": 3, "attack_speed": 1.0,
		"attack_light": 440.0, "attack_armor": 440.0, "attack_air": 440.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 1, "base_speed": 60.0, "power": 2432,
		"weapon_label": "", "type_line": "近未来 — 缴获装甲", "appear_scope": "任务专属"
	},
	"captured_boss_future_nexus": {
		"display_name": "风暴核心", "era": 4, "combat_kind": 2,
		"base_hp": 900.0, "range_value": 3, "attack_speed": 1.11,
		"attack_light": 900.0, "attack_armor": 900.0, "attack_air": 900.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 10, "deploy_speed": 0, "base_speed": 30.0, "power": 5923,
		"weapon_label": "", "type_line": "近未来 — 缴获支援", "appear_scope": "BOSS"
	},

	# ==========================================
	# D 段：补充池 (29个)
	# ==========================================
	"captured_foe_pool_001": {
		"display_name": "李-恩菲尔德志愿兵排", "era": 0, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "一战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_002": {
		"display_name": "劳斯莱斯 Mk.II 装甲车", "era": 0, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "一战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_003": {
		"display_name": "维克斯 .303 机枪阵地", "era": 0, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "一战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_004": {
		"display_name": "福特 T 型战地救护车", "era": 0, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "一战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_005": {
		"display_name": "MP18 突击队", "era": 1, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "二战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_006": {
		"display_name": "M1 加兰德伞兵班", "era": 1, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "二战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_007": {
		"display_name": "黄蜂 Hummel 自行火炮", "era": 1, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "二战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_008": {
		"display_name": "PaK 40 反坦克炮组", "era": 1, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "二战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_009": {
		"display_name": "GMC 2.5t 补给卡车", "era": 1, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "二战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_010": {
		"display_name": "毛瑟 Kar98k 狙击组", "era": 1, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "二战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_011": {
		"display_name": "BMD-1 空降战车", "era": 2, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "冷战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_012": {
		"display_name": "BMP-1 步兵战车", "era": 2, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "冷战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_013": {
		"display_name": "9K111 法特导弹组", "era": 2, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "冷战 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_014": {
		"display_name": "P-18 雷达警戒车", "era": 2, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "冷战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_015": {
		"display_name": "BREM-1 装甲抢修车", "era": 2, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "冷战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_016": {
		"display_name": "M4 卡宾特遣班", "era": 3, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "现代 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_017": {
		"display_name": "爱国者 PAC-3 发射车", "era": 3, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "现代 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_018": {
		"display_name": "HIMARS 火箭炮组", "era": 3, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "现代 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_019": {
		"display_name": "RQ-7 影子无人机班", "era": 3, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "现代 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_020": {
		"display_name": "EA-18G 电子战小组", "era": 3, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "现代 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_021": {
		"display_name": "神经接口突击兵", "era": 4, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "近未来 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_022": {
		"display_name": "HK-07 量产机兵", "era": 4, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_023": {
		"display_name": "HEL-30 激光炮阵列", "era": 4, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "近未来 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_024": {
		"display_name": "N-Repair 纳米工程车", "era": 4, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "近未来 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_025": {
		"display_name": "X-9 猎杀者渗透组", "era": 4, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "近未来 — 缴获轻装", "appear_scope": "主线波次"
	},
	"captured_foe_pool_026": {
		"display_name": "毛瑟 C96 征召兵排", "era": 0, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.11,
		"attack_light": 17.8, "attack_armor": 13.3, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 3, "base_speed": 120.0, "power": 127,
		"weapon_label": "步枪", "type_line": "一战 — 缴获装甲", "appear_scope": "主线波次"
	},
	"captured_foe_pool_027": {
		"display_name": "Sd.Kfz.251/1 半履带车", "era": 1, "combat_kind": 2,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 16.8, "attack_armor": 12.0, "attack_air": 10.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 0, "base_speed": 0.0, "power": 192,
		"weapon_label": "迫击炮", "type_line": "二战 — 缴获支援", "appear_scope": "主线波次"
	},
	"captured_foe_pool_028": {
		"display_name": "SS-C-1 岸防导弹组", "era": 2, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 2.5,
		"attack_light": 20.0, "attack_armor": 15.0, "attack_air": 12.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 120.0, "power": 153,
		"weapon_label": "手枪", "type_line": "冷战 — 缴获空中", "appear_scope": "主线波次"
	},
	"captured_foe_pool_029": {
		"display_name": "PS-9 相位中继站", "era": 3, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 1, "attack_speed": 2.0,
		"attack_light": 20.0, "attack_armor": 14.0, "attack_air": 12.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 120.0, "power": 101,
		"weapon_label": "冲锋枪", "type_line": "现代 — 缴获轻装", "appear_scope": "主线波次"
	},

	# ==========================================
	# E 段：堡垒 (10个)
	# ==========================================
	"captured_fort_ww1_pillbox": {
		"display_name": "混凝土机枪碉堡", "era": 0, "combat_kind": 4,
		"base_hp": 600.0, "range_value": 1, "attack_speed": 0.5,
		"attack_light": 60.0, "attack_armor": 0.0, "attack_air": 40.0,
		"defense_light": 50.0, "defense_armor": 60.0, "defense_air": 40.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 418,
		"weapon_label": "", "type_line": "一战 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_ww1_artillery": {
		"display_name": "要塞炮台", "era": 0, "combat_kind": 4,
		"base_hp": 500.0, "range_value": 1, "attack_speed": 3.03,
		"attack_light": 80.0, "attack_armor": 0.0, "attack_air": 0.0,
		"defense_light": 40.0, "defense_armor": 50.0, "defense_air": 30.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 481,
		"weapon_label": "", "type_line": "一战 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_ww2_bunker": {
		"display_name": "混凝土碉堡", "era": 1, "combat_kind": 4,
		"base_hp": 1000.0, "range_value": 1, "attack_speed": 0.5,
		"attack_light": 80.0, "attack_armor": 0.0, "attack_air": 60.0,
		"defense_light": 80.0, "defense_armor": 100.0, "defense_air": 60.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 780,
		"weapon_label": "", "type_line": "二战 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_ww2_flak": {
		"display_name": "88mm防空塔", "era": 1, "combat_kind": 4,
		"base_hp": 800.0, "range_value": 1, "attack_speed": 0.67,
		"attack_light": 40.0, "attack_armor": 0.0, "attack_air": 200.0,
		"defense_light": 60.0, "defense_armor": 80.0, "defense_air": 100.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 763,
		"weapon_label": "", "type_line": "二战 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_cold_missile": {
		"display_name": "导弹发射井", "era": 2, "combat_kind": 4,
		"base_hp": 1200.0, "range_value": 1, "attack_speed": 1.67,
		"attack_light": 120.0, "attack_armor": 0.0, "attack_air": 100.0,
		"defense_light": 80.0, "defense_armor": 100.0, "defense_air": 80.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 950,
		"weapon_label": "", "type_line": "冷战 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_cold_radar": {
		"display_name": "雷达站", "era": 2, "combat_kind": 4,
		"base_hp": 800.0, "range_value": 1, "attack_speed": 0.0,
		"attack_light": 0.0, "attack_armor": 0.0, "attack_air": 0.0,
		"defense_light": 60.0, "defense_armor": 80.0, "defense_air": 60.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 284,
		"weapon_label": "", "type_line": "冷战 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_modern_citadel": {
		"display_name": "要塞核心", "era": 3, "combat_kind": 4,
		"base_hp": 2000.0, "range_value": 1, "attack_speed": 1.0,
		"attack_light": 120.0, "attack_armor": 0.0, "attack_air": 80.0,
		"defense_light": 120.0, "defense_armor": 180.0, "defense_air": 100.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 1266,
		"weapon_label": "", "type_line": "现代 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_modern_phalanx": {
		"display_name": "近防炮系统", "era": 3, "combat_kind": 4,
		"base_hp": 1000.0, "range_value": 1, "attack_speed": 0.33,
		"attack_light": 50.0, "attack_armor": 0.0, "attack_air": 300.0,
		"defense_light": 80.0, "defense_armor": 100.0, "defense_air": 120.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 818,
		"weapon_label": "", "type_line": "现代 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_future_ion": {
		"display_name": "离子炮台", "era": 4, "combat_kind": 4,
		"base_hp": 2500.0, "range_value": 1, "attack_speed": 1.49,
		"attack_light": 200.0, "attack_armor": 0.0, "attack_air": 150.0,
		"defense_light": 150.0, "defense_armor": 200.0, "defense_air": 150.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 1535,
		"weapon_label": "", "type_line": "近未来 — 缴获堡垒", "appear_scope": "堡垒"
	},
	"captured_fort_future_shield": {
		"display_name": "能量护盾发生器", "era": 4, "combat_kind": 4,
		"base_hp": 3000.0, "range_value": 0, "attack_speed": 0.0,
		"attack_light": 0.0, "attack_armor": 0.0, "attack_air": 0.0,
		"defense_light": 200.0, "defense_armor": 250.0, "defense_air": 200.0,
		"weapon_type": 0, "deploy_speed": 0, "base_speed": 0.0, "power": 1050,
		"weapon_label": "", "type_line": "近未来 — 缴获堡垒", "appear_scope": "堡垒"
	},

	# ── 特殊平台 ──
	"captured_foe_omega_platform": {
		"display_name": "全装型机动舱", "era": 4, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 0.45,
		"attack_light": 220.0, "attack_armor": 180.0, "attack_air": 160.0,
		"defense_light": 13.0, "defense_armor": 11.0, "defense_air": 10.0,
		"weapon_type": 1, "deploy_speed": 1, "base_speed": 40.0, "power": 1226,
		"weapon_label": "米加粒子炮", "type_line": "近未来 — 缴获装甲", "appear_scope": "主线波次"
	},

	# ==========================================
	# C 段补充：vis_enemy_036~071 敌人原图数据（36张）
	# 这些是战场敌人原图，与缴获卡面 vis_player_036~071 不同
	# 数据来源：data/json/enemy_archetypes.json FIXED_ENEMY_IDS
	# ==========================================

	# 一战敌人原图 (7张)
	"captured_enemy_ww1_infantry_basic_v2": {
		"display_name": "步兵班·MP18（敌人原图）", "era": 0, "combat_kind": 0,
		"base_hp": 40.0, "range_value": 1, "attack_speed": 4.0,
		"attack_light": 8.0, "attack_armor": 3.2, "attack_air": 2.4,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 80.0, "power": 52,
		"weapon_label": "", "type_line": "一战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_036"
	},
	"captured_enemy_ww1_infantry_rifle_v2": {
		"display_name": "步兵班·毛瑟（敌人原图）", "era": 0, "combat_kind": 0,
		"base_hp": 45.0, "range_value": 2, "attack_speed": 1.49,
		"attack_light": 9.6, "attack_armor": 7.2, "attack_air": 6.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 3, "base_speed": 70.0, "power": 73,
		"weapon_label": "", "type_line": "一战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_037"
	},
	"captured_enemy_ww1_mg_nest_v2": {
		"display_name": "机枪巢（敌人原图）", "era": 0, "combat_kind": 2,
		"base_hp": 80.0, "range_value": 1, "attack_speed": 3.03,
		"attack_light": 30.2, "attack_armor": 16.6, "attack_air": 13.3,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 0, "base_speed": 0.0, "power": 139,
		"weapon_label": "", "type_line": "一战 — 敌人原图支援", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_038"
	},
	"captured_enemy_ww1_mortar_v2": {
		"display_name": "迫击炮组（敌人原图）", "era": 0, "combat_kind": 2,
		"base_hp": 60.0, "range_value": 2, "attack_speed": 0.5,
		"attack_light": 80.0, "attack_armor": 48.0, "attack_air": 32.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 4, "base_speed": 40.0, "power": 241,
		"weapon_label": "", "type_line": "一战 — 敌人原图支援", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_039"
	},
	"captured_elite_ww1_storm_v2": {
		"display_name": "暴风突击队（敌人原图）", "era": 0, "combat_kind": 0,
		"base_hp": 70.0, "range_value": 1, "attack_speed": 4.0,
		"attack_light": 36.0, "attack_armor": 14.4, "attack_air": 10.8,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 100.0, "power": 136,
		"weapon_label": "", "type_line": "一战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_040"
	},
	"captured_elite_ww1_armored_v2": {
		"display_name": "装甲车（敌人原图）", "era": 0, "combat_kind": 2,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 1.82,
		"attack_light": 50.4, "attack_armor": 27.7, "attack_air": 22.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 60.0, "power": 193,
		"weapon_label": "", "type_line": "一战 — 敌人原图支援", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_041"
	},
	"captured_boss_ww1_av7_v2": {
		"display_name": "圣沙蒙坦克（敌人原图）", "era": 0, "combat_kind": 1,
		"base_hp": 300.0, "range_value": 2, "attack_speed": 0.67,
		"attack_light": 100.0, "attack_armor": 60.0, "attack_air": 40.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 1, "base_speed": 30.0, "power": 495,
		"weapon_label": "", "type_line": "一战 — 敌人原图装甲", "appear_scope": "BOSS",
		"_icon_ref": "vis_enemy_042"
	},

	# 二战敌人原图 (7张)
	"captured_enemy_ww2_infantry_v2": {
		"display_name": "步兵班·汤普森（敌人原图）", "era": 1, "combat_kind": 0,
		"base_hp": 50.0, "range_value": 1, "attack_speed": 4.55,
		"attack_light": 45.0, "attack_armor": 18.0, "attack_air": 13.5,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 4, "base_speed": 90.0, "power": 163,
		"weapon_label": "", "type_line": "二战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_043"
	},
	"captured_enemy_ww2_rifleman_v2": {
		"display_name": "步枪班·加兰德（敌人原图）", "era": 1, "combat_kind": 0,
		"base_hp": 55.0, "range_value": 2, "attack_speed": 2.0,
		"attack_light": 48.0, "attack_armor": 28.8, "attack_air": 24.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 3, "base_speed": 70.0, "power": 178,
		"weapon_label": "", "type_line": "二战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_044"
	},
	"captured_enemy_ww2_mg42_v2": {
		"display_name": "MG42机枪组（敌人原图）", "era": 1, "combat_kind": 2,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 5.0,
		"attack_light": 63.0, "attack_armor": 31.5, "attack_air": 25.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 50.0, "power": 232,
		"weapon_label": "", "type_line": "二战 — 敌人原图支援", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_045"
	},
	"captured_enemy_ww2_panzerschreck_v2": {
		"display_name": "反坦克组（敌人原图）", "era": 1, "combat_kind": 0,
		"base_hp": 70.0, "range_value": 1, "attack_speed": 0.4,
		"attack_light": 120.0, "attack_armor": 72.0, "attack_air": 48.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 3, "base_speed": 60.0, "power": 418,
		"weapon_label": "", "type_line": "二战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_046"
	},
	"captured_elite_ww2_paratrooper_v2": {
		"display_name": "伞兵精英（敌人原图）", "era": 1, "combat_kind": 0,
		"base_hp": 80.0, "range_value": 1, "attack_speed": 4.55,
		"attack_light": 73.0, "attack_armor": 29.2, "attack_air": 21.9,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 0, "deploy_speed": 5, "base_speed": 110.0, "power": 205,
		"weapon_label": "", "type_line": "二战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_047"
	},
	"captured_elite_ww2_panther_v2": {
		"display_name": "黑豹坦克（敌人原图）", "era": 1, "combat_kind": 1,
		"base_hp": 200.0, "range_value": 2, "attack_speed": 1.11,
		"attack_light": 168.0, "attack_armor": 100.8, "attack_air": 67.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 2, "base_speed": 50.0, "power": 779,
		"weapon_label": "", "type_line": "二战 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_048"
	},
	"captured_boss_ww2_kingtiger_v2": {
		"display_name": "虎王坦克（敌人原图）", "era": 1, "combat_kind": 1,
		"base_hp": 400.0, "range_value": 2, "attack_speed": 1.0,
		"attack_light": 200.0, "attack_armor": 120.0, "attack_air": 80.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 1, "base_speed": 30.0, "power": 880,
		"weapon_label": "", "type_line": "二战 — 敌人原图装甲", "appear_scope": "BOSS",
		"_icon_ref": "vis_enemy_049"
	},

	# 冷战敌人原图 (7张)
	"captured_enemy_cold_ak_v2": {
		"display_name": "苏军步兵（敌人原图）", "era": 2, "combat_kind": 0,
		"base_hp": 60.0, "range_value": 2, "attack_speed": 3.03,
		"attack_light": 67.2, "attack_armor": 40.3, "attack_air": 33.6,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 4, "base_speed": 90.0, "power": 229,
		"weapon_label": "", "type_line": "冷战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_050"
	},
	"captured_enemy_cold_m60_v2": {
		"display_name": "美军步兵（敌人原图）", "era": 2, "combat_kind": 0,
		"base_hp": 65.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 100.8, "attack_armor": 50.4, "attack_air": 40.3,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 4, "base_speed": 90.0, "power": 281,
		"weapon_label": "", "type_line": "冷战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_051"
	},
	"captured_enemy_cold_btr_v2": {
		"display_name": "BTR装甲车（敌人原图）", "era": 2, "combat_kind": 1,
		"base_hp": 120.0, "range_value": 1, "attack_speed": 3.33,
		"attack_light": 105.8, "attack_armor": 52.9, "attack_air": 42.3,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 80.0, "power": 308,
		"weapon_label": "", "type_line": "冷战 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_052"
	},
	"captured_enemy_cold_m113_v2": {
		"display_name": "M113装甲车（敌人原图）", "era": 2, "combat_kind": 3,
		"base_hp": 110.0, "range_value": 1, "attack_speed": 2.86,
		"attack_light": 61.7, "attack_armor": 30.8, "attack_air": 24.7,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 70.0, "power": 216,
		"weapon_label": "", "type_line": "冷战 — 敌人原图空中", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_053"
	},
	"captured_elite_cold_spetsnaz_v2": {
		"display_name": "特种部队（敌人原图）", "era": 2, "combat_kind": 0,
		"base_hp": 90.0, "range_value": 2, "attack_speed": 0.8,
		"attack_light": 112.0, "attack_armor": 89.6, "attack_air": 67.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 6, "deploy_speed": 5, "base_speed": 120.0, "power": 434,
		"weapon_label": "", "type_line": "冷战 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_054"
	},
	"captured_elite_cold_t72_v2": {
		"display_name": "T-72坦克（敌人原图）", "era": 2, "combat_kind": 1,
		"base_hp": 250.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 160.0, "attack_armor": 96.0, "attack_air": 64.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 2, "base_speed": 60.0, "power": 612,
		"weapon_label": "", "type_line": "冷战 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_055"
	},
	"captured_boss_cold_mig_v2": {
		"display_name": "米格-29（敌人原图）", "era": 2, "combat_kind": 3,
		"base_hp": 450.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 162.0, "attack_armor": 216.0, "attack_air": 108.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 9, "deploy_speed": 6, "base_speed": 150.0, "power": 1014,
		"weapon_label": "", "type_line": "冷战 — 敌人原图空中", "appear_scope": "BOSS",
		"_icon_ref": "vis_enemy_056"
	},

	# 现代敌人原图 (7张)
	"captured_enemy_modern_marine_v2": {
		"display_name": "海军陆战队（敌人原图）", "era": 3, "combat_kind": 0,
		"base_hp": 70.0, "range_value": 2, "attack_speed": 3.45,
		"attack_light": 81.9, "attack_armor": 49.1, "attack_air": 40.9,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 4, "base_speed": 100.0, "power": 284,
		"weapon_label": "", "type_line": "现代 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_057"
	},
	"captured_enemy_modern_technical_v2": {
		"display_name": "皮卡武装（敌人原图）", "era": 3, "combat_kind": 3,
		"base_hp": 90.0, "range_value": 1, "attack_speed": 3.33,
		"attack_light": 113.4, "attack_armor": 56.7, "attack_air": 45.4,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 4, "base_speed": 120.0, "power": 326,
		"weapon_label": "", "type_line": "现代 — 敌人原图空中", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_058"
	},
	"captured_enemy_modern_stryker_v2": {
		"display_name": "斯特赖克装甲车（敌人原图）", "era": 3, "combat_kind": 1,
		"base_hp": 150.0, "range_value": 2, "attack_speed": 2.86,
		"attack_light": 126.0, "attack_armor": 63.0, "attack_air": 50.4,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 3, "base_speed": 80.0, "power": 348,
		"weapon_label": "", "type_line": "现代 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_059"
	},
	"captured_enemy_modern_mlrs_v2": {
		"display_name": "火箭炮车（敌人原图）", "era": 3, "combat_kind": 2,
		"base_hp": 100.0, "range_value": 3, "attack_speed": 0.5,
		"attack_light": 210.0, "attack_armor": 126.0, "attack_air": 84.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 4, "base_speed": 50.0, "power": 592,
		"weapon_label": "", "type_line": "现代 — 敌人原图支援", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_060"
	},
	"captured_elite_modern_delta_v2": {
		"display_name": "三角洲部队（敌人原图）", "era": 3, "combat_kind": 0,
		"base_hp": 100.0, "range_value": 2, "attack_speed": 3.45,
		"attack_light": 133.9, "attack_armor": 80.4, "attack_air": 66.9,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 1, "deploy_speed": 5, "base_speed": 130.0, "power": 379,
		"weapon_label": "", "type_line": "现代 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_061"
	},
	"captured_elite_modern_abrams_v2": {
		"display_name": "M1A2坦克（敌人原图）", "era": 3, "combat_kind": 1,
		"base_hp": 300.0, "range_value": 2, "attack_speed": 1.25,
		"attack_light": 270.0, "attack_armor": 162.0, "attack_air": 108.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 3, "deploy_speed": 2, "base_speed": 60.0, "power": 880,
		"weapon_label": "", "type_line": "现代 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_062"
	},
	"captured_elite_modern_apache_v2": {
		"display_name": "阿帕奇直升机（敌人原图）", "era": 3, "combat_kind": 3,
		"base_hp": 220.0, "range_value": 3, "attack_speed": 1.67,
		"attack_light": 266.0, "attack_armor": 177.3, "attack_air": 118.2,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 9, "deploy_speed": 5, "base_speed": 120.0, "power": 938,
		"weapon_label": "", "type_line": "现代 — 敌人原图空中", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_063"
	},
	"captured_boss_modern_command_v2": {
		"display_name": "指挥中枢（敌人原图）", "era": 3, "combat_kind": 2,
		"base_hp": 700.0, "range_value": 2, "attack_speed": 0.83,
		"attack_light": 294.0, "attack_armor": 147.0, "attack_air": 117.6,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 2, "deploy_speed": 0, "base_speed": 0.0, "power": 1211,
		"weapon_label": "", "type_line": "现代 — 敌人原图支援", "appear_scope": "BOSS",
		"_icon_ref": "vis_enemy_064"
	},

	# 近未来敌人原图 (7张)
	"captured_enemy_future_drone_v2": {
		"display_name": "无人机群（敌人原图）", "era": 4, "combat_kind": 3,
		"base_hp": 40.0, "range_value": 2, "attack_speed": 2.5,
		"attack_light": 120.0, "attack_armor": 120.0, "attack_air": 120.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 6, "base_speed": 150.0, "power": 550,
		"weapon_label": "", "type_line": "近未来 — 敌人原图空中", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_065"
	},
	"captured_enemy_future_cyborg_v2": {
		"display_name": "机械步兵（敌人原图）", "era": 4, "combat_kind": 0,
		"base_hp": 100.0, "range_value": 2, "attack_speed": 4.0,
		"attack_light": 132.0, "attack_armor": 132.0, "attack_air": 132.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 4, "base_speed": 100.0, "power": 624,
		"weapon_label": "", "type_line": "近未来 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_066"
	},
	"captured_enemy_future_mech_v2": {
		"display_name": "机甲步兵（敌人原图）", "era": 4, "combat_kind": 1,
		"base_hp": 180.0, "range_value": 2, "attack_speed": 1.49,
		"attack_light": 126.0, "attack_armor": 126.0, "attack_air": 126.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 3, "base_speed": 80.0, "power": 729,
		"weapon_label": "", "type_line": "近未来 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_067"
	},
	"captured_enemy_future_hovertank_v2": {
		"display_name": "悬浮坦克（敌人原图）", "era": 4, "combat_kind": 1,
		"base_hp": 250.0, "range_value": 3, "attack_speed": 2.0,
		"attack_light": 200.0, "attack_armor": 200.0, "attack_air": 200.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 4, "base_speed": 110.0, "power": 1062,
		"weapon_label": "", "type_line": "近未来 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_068"
	},
	"captured_elite_future_spectre_v2": {
		"display_name": "幽灵特工（敌人原图）", "era": 4, "combat_kind": 0,
		"base_hp": 120.0, "range_value": 2, "attack_speed": 2.5,
		"attack_light": 210.0, "attack_armor": 210.0, "attack_air": 210.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 5, "base_speed": 140.0, "power": 812,
		"weapon_label": "", "type_line": "近未来 — 敌人原图轻装", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_069"
	},
	"captured_elite_future_colossus_v2": {
		"display_name": "巨神机甲（敌人原图）", "era": 4, "combat_kind": 1,
		"base_hp": 400.0, "range_value": 3, "attack_speed": 1.0,
		"attack_light": 440.0, "attack_armor": 440.0, "attack_air": 440.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 8, "deploy_speed": 1, "base_speed": 60.0, "power": 2432,
		"weapon_label": "", "type_line": "近未来 — 敌人原图装甲", "appear_scope": "任务专属",
		"_icon_ref": "vis_enemy_070"
	},
	"captured_boss_future_nexus_v2": {
		"display_name": "风暴核心（敌人原图）", "era": 4, "combat_kind": 2,
		"base_hp": 900.0, "range_value": 3, "attack_speed": 1.11,
		"attack_light": 900.0, "attack_armor": 900.0, "attack_air": 900.0,
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"weapon_type": 10, "deploy_speed": 0, "base_speed": 30.0, "power": 5923,
		"weapon_label": "", "type_line": "近未来 — 敌人原图支援", "appear_scope": "BOSS",
		"_icon_ref": "vis_enemy_071"
	}
}


## 查询接口：返回指定卡 ID 的静态数据（深拷贝，防止误改常量）
static func get_stats(card_id: String) -> Dictionary:
	if CAPTURED_STATS.has(card_id):
		return CAPTURED_STATS[card_id].duplicate(true)
	return {}
