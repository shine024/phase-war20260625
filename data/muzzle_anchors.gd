extends RefCounted
class_name MuzzleAnchors

const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")

## 弹道/枪口锚点数据（独立于 ff/hf，由 docs/enemy_fire_spawn.html 标注）
## fireX: 0~1 (0=纹理左, 0.5=中, 1=右)，相对纹理宽度
## fireY_pct: 0~100 (占纹理顶部百分比，0=顶, 100=底)
## 数据源：docs/enemy_fire_spawn (敌方卡头脚加弹道起始点).json（117 条 = 106 人工标注 + 11 派生）
## 11 条派生条目（fut_arm_omega + 10 个堡垒）从我方标注表 data/player_muzzle_anchors.gd
## 水平镜像换算（enemy fireX = 1 - player fireX，fireY_pct 不变），值为脚本换算非人工标注。
const MUZZLE: Dictionary = {
	"ww1_inf_mp18": {"fireX": 0.1963, "fireY_pct": 21.19},
	"ww1_inf_rifle": {"fireX": 0.167, "fireY_pct": 30.96},
	"ww1_inf_enfield": {"fireX": 0.3799, "fireY_pct": 29.2},
	"fut_inf_c96": {"fireX": 0.2998, "fireY_pct": 36.82},
	"platform_ww1_light": {"fireX": 0.18, "fireY_pct": 38},
	"ww1_inf_mp18_x": {"fireX": 0.2021, "fireY_pct": 35.25},
	"ww1_inf_storm_e": {"fireX": 0.1943, "fireY_pct": 30.57},
	"drop_smg_mk2": {"fireX": 0.0367, "fireY_pct": 44.8},
	"ww1_arm_rolls_mk2": {"fireX": 0.3446, "fireY_pct": 43.47},
	"platform_ww1_medium": {"fireX": 0.15, "fireY_pct": 39},
	"ww1_arm_rolls_e": {"fireX": 0.3656, "fireY_pct": 42.27},
	"ww1_boss_av7": {"fireX": 0.1143, "fireY_pct": 52.25},
	"ww1_sup_mg_nest": {"fireX": 0.1455, "fireY_pct": 37.6},
	"ww1_arty_mortar": {"fireX": 0.1611, "fireY_pct": 28.42},
	"ww1_sup_vickers": {"fireX": 0.1221, "fireY_pct": 32.71},
	"ww1_sup_ford_ambulance": {"fireX": 0.3193, "fireY_pct": 45.8},
	"platform_ww1_radar": {"fireX": 0.3656, "fireY_pct": 45.2},
	"platform_ww1_medic": {"fireX": 0.2888, "fireY_pct": 44.4},
	"platform_ww1_fort": {"fireX": 0.0367, "fireY_pct": 41.33},
	"ww1_fort_pillbox": {"fireX": 0.2607, "fireY_pct": 46.97},
	"ww1_fort_artillery": {"fireX": 0.0908, "fireY_pct": 36.23},
	"ww2_inf_thompson": {"fireX": 0.3584, "fireY_pct": 39.75},
	"ww2_inf_garand": {"fireX": 0.167, "fireY_pct": 19.04},
	"platform_ww2_light": {"fireX": 0.16, "fireY_pct": 40},
	"platform_ww2_raider": {"fireX": 0.1, "fireY_pct": 42},
	"ww2_arm_garand_para": {"fireX": 0.2021, "fireY_pct": 30.76},
	"ww2_inf_kar98k": {"fireX": 0.2002, "fireY_pct": 27.05},
	"ww2_inf_panzerschreck_e": {"fireX": 0.1338, "fireY_pct": 44.04},
	"ww2_inf_para_e": {"fireX": 0.2939, "fireY_pct": 39.94},
	"drop_phase_lance": {"fireX": 0.22, "fireY_pct": 43.73},
	"platform_ww2_medium": {"fireX": 0.049, "fireY_pct": 45.07},
	"ww2_arm_panther_e": {"fireX": 0.0869, "fireY_pct": 43.85},
	"platform_ww2_heavy": {"fireX": 0.0533, "fireY_pct": 45.87},
	"ww2_boss_kingtiger": {"fireX": 0.085, "fireY_pct": 43.46},
	"ww2_sup_gmc_truck": {"fireX": 0.1572, "fireY_pct": 46.78},
	"platform_ww2_radar": {"fireX": 0.3867, "fireY_pct": 44.67},
	"ww2_sup_mg42": {"fireX": 0.0908, "fireY_pct": 37.21},
	"ww2_arty_hummel": {"fireX": 0.1006, "fireY_pct": 37.79},
	"ww2_arty_pak40": {"fireX": 0.0693, "fireY_pct": 34.67},
	"platform_ww2_siege": {"fireX": 0.199, "fireY_pct": 40.13},
	"platform_ww2_fortress": {"fireX": 0.12, "fireY_pct": 30},
	"ww2_fort_bunker": {"fireX": 0.167, "fireY_pct": 45.41},
	"ww2_fort_flak": {"fireX": 0.165, "fireY_pct": 30.96},
	"cold_inf_m60": {"fireX": 0.249, "fireY_pct": 36.23},
	"cold_inf_ak": {"fireX": 0.2393, "fireY_pct": 40.14},
	"platform_cold_light": {"fireX": 0.3279, "fireY_pct": 44.93},
	"platform_cold_scout": {"fireX": 0.3367, "fireY_pct": 45.07},
	"cold_inf_metis": {"fireX": 0.083, "fireY_pct": 45.8},
	"cold_inf_spetsnaz_e": {"fireX": 0.1943, "fireY_pct": 39.94},
	"cold_arm_btr_e": {"fireX": 0.3037, "fireY_pct": 45.8},
	"cold_air_m113_e": {"fireX": 0.249, "fireY_pct": 43.26},
	"cold_arty_bmd1": {"fireX": 0.3779, "fireY_pct": 45.8},
	"cold_sup_bmp1_x": {"fireX": 0.3369, "fireY_pct": 47.95},
	"cold_arty_brem1": {"fireX": 0.2939, "fireY_pct": 48.54},
	"platform_cold_medium": {"fireX": 0.09, "fireY_pct": 44},
	"platform_cold_ifv": {"fireX": 0.13, "fireY_pct": 47},
	"cold_arm_t72_e": {"fireX": 0.0908, "fireY_pct": 47.36},
	"cold_arm_p18": {"fireX": 0.4209, "fireY_pct": 44.82},
	"platform_cold_radar": {"fireX": 0.18, "fireY_pct": 20},
	"drop_mega_beam_cannon": {"fireX": 0.3656, "fireY_pct": 45.6},
	"platform_cold_carrier": {"fireX": 0.2, "fireY_pct": 38},
	"cold_boss_mig": {"fireX": 0.3193, "fireY_pct": 54.39},
	"cold_fort_missile": {"fireX": 0.5186, "fireY_pct": 30.57},
	"cold_fort_radar": {"fireX": 0.3994, "fireY_pct": 29.98},
	"mod_air_technical_e": {"fireX": 0.349, "fireY_pct": 44.4},
	"platform_modern_light": {"fireX": 0.15, "fireY_pct": 40},
	"platform_modern_stealth": {"fireX": 0.4967, "fireY_pct": 55.2},
	"mod_inf_marine": {"fireX": 0.3213, "fireY_pct": 35.06},
	"mod_sup_m4_carbine": {"fireX": 0.1162, "fireY_pct": 35.25},
	"mod_inf_delta_e": {"fireX": 0.1201, "fireY_pct": 34.86},
	"drop_thunder_field": {"fireX": 0.2367, "fireY_pct": 40.67},
	"mod_arm_stryker_e": {"fireX": 0.3604, "fireY_pct": 46.58},
	"platform_modern_medium": {"fireX": 0.1177, "fireY_pct": 44.93},
	"platform_modern_guard_heavy": {"fireX": 0.08, "fireY_pct": 45},
	"mod_arm_abrams_e": {"fireX": 0.0967, "fireY_pct": 44.24},
	"mod_arm_abrams_mk2": {"fireX": 0.124, "fireY_pct": 54},
	"platform_modern_radar": {"fireX": 0.1, "fireY_pct": 44},
	"mod_arty_mlrs_e": {"fireX": 0.4229, "fireY_pct": 41.31},
	"mod_inf_patriot": {"fireX": 0.2119, "fireY_pct": 45.21},
	"mod_arm_himars": {"fireX": 0.1455, "fireY_pct": 43.46},
	"platform_modern_spg": {"fireX": 0.28, "fireY_pct": 42.4},
	"mod_arty_rq7": {"fireX": 0.2061, "fireY_pct": 48.34},
	"mod_sup_growler": {"fireX": 0.2998, "fireY_pct": 55.76},
	"mod_air_apache_e": {"fireX": 0.3271, "fireY_pct": 56.54},
	"drop_overclock_matrix": {"fireX": 0.3279, "fireY_pct": 56.53},
	"mod_boss_command": {"fireX": 0.3721, "fireY_pct": 46.78},
	"mod_fort_citadel": {"fireX": 0.1768, "fireY_pct": 51.07},
	"mod_fort_phalanx": {"fireX": 0.1553, "fireY_pct": 47.75},
	"platform_future_light": {"fireX": 0.2633, "fireY_pct": 46.4},
	"fut_inf_cyborg": {"fireX": 0.2373, "fireY_pct": 30.96},
	"fut_inf_spectre_e": {"fireX": 0.2432, "fireY_pct": 37.01},
	"fut_inf_storm_rider": {"fireX": 0.2612, "fireY_pct": 44.8},
	"fut_inf_neural": {"fireX": 0.21, "fireY_pct": 32.91},
	"fut_inf_x9": {"fireX": 0.3408, "fireY_pct": 48.73},
	"drop_railgun": {"fireX": 0.1779, "fireY_pct": 45.07},
	"fut_arm_mech_e": {"fireX": 0.87, "fireY_pct": 27},
	"fut_arm_hk07": {"fireX": 0.1006, "fireY_pct": 27.25},
	"fut_arm_sdkfz": {"fireX": 0.3955, "fireY_pct": 43.07},
	"platform_future_medium": {"fireX": 0.1, "fireY_pct": 48},
	"fut_arm_hovertank_e": {"fireX": 0.1064, "fireY_pct": 42.87},
	"platform_future_heavy": {"fireX": 0.1, "fireY_pct": 45},
	"fut_arm_colossus_e": {"fireX": 0.208, "fireY_pct": 50.68},
	"fut_arm_titan_mk2": {"fireX": 0.1885, "fireY_pct": 18.26},
	"drop_mega_particle_cannon": {"fireX": 0.1033, "fireY_pct": 44},
	"fut_boss_nexus": {"fireX": 0.3955, "fireY_pct": 39.16},
	"platform_future_radar": {"fireX": 0.1656, "fireY_pct": 40.8},
	"fut_sup_nrepair": {"fireX": 0.2217, "fireY_pct": 45.21},
	"fut_sup_ps9": {"fireX": 0.52, "fireY_pct": 42.93},
	"fut_sup_bulwark": {"fireX": 0.1162, "fireY_pct": 46.58},
	"fut_arty_hel30": {"fireX": 0.1846, "fireY_pct": 37.21},
	"fut_arty_ssc1": {"fireX": 0.6963, "fireY_pct": 25.1},
	"fut_air_drone": {"fireX": 0.0654, "fireY_pct": 42.09},
	"fut_air_regen_frame": {"fireX": 0.1924, "fireY_pct": 46},
	"fut_air_heavy_carrier": {"fireX": 0.1006, "fireY_pct": 44.63},
	"fut_arm_omega": {"fireX": 0.1033, "fireY_pct": 44},
	"fut_fort_ion": {"fireX": 0.1299, "fireY_pct": 43.07},
	"fut_fort_shield": {"fireX": 0.4893, "fireY_pct": 37.01},
	# ── v26.12 派生近似（v27 补）：八飞机敌我标注表均未标，coverage 冒烟红。
	# 航空器鼻端中线近似（对齐已标注敌机 fut_air_drone 0.066/43、heavy_carrier 0/49 的
	# 空间分布），标记"待人工标注"——AI 生图/标注流程跑过后按实际炮位覆盖。
	"ww2_air_bomber": {"fireX": 0.1318, "fireY_pct": 47.56},
	"ww2_air_dive_bomber": {"fireX": 0.0693, "fireY_pct": 50.1},
	"cold_air_strike_fighter": {"fireX": 0.0928, "fireY_pct": 53.61},
	"cold_air_bomber": {"fireX": 0.0791, "fireY_pct": 50.88},
	"mod_air_multirole": {"fireX": 0.1221, "fireY_pct": 52.83},
	"mod_air_bomber": {"fireX": 0.0967, "fireY_pct": 51.86},
	"fut_air_stealth_multirole": {"fireX": 0.0811, "fireY_pct": 51.86},
	"fut_air_stealth_bomber": {"fireX": 0.0615, "fireY_pct": 49.12},
	"foe_ww1_arty_77mm": {"fireX": 0.1201, "fireY_pct": 34.08},
	"foe_ww1_arty_m81": {"fireX": 0.0791, "fireY_pct": 30.76},
	"foe_fut_arm_prism": {"fireX": 0.1748, "fireY_pct": 45.21},
	"ww2_air_me262": {"fireX": 0.0693, "fireY_pct": 52.83},
	"ww2_air_meteor_e": {"fireX": 0.1221, "fireY_pct": 51.27},
	"foe_ww1_sup_mp18": {"fireX": 0.14, "fireY_pct": 30},
	"foe_ww1_sup_engineer": {"fireX": 0.333, "fireY_pct": 34.08},
	"foe_ww2_arm_sherman": {"fireX": 0.1025, "fireY_pct": 41.7},
	"foe_ww2_arm_tiger": {"fireX": 0.0908, "fireY_pct": 43.07},
	"foe_ww2_inf_bazooka": {"fireX": 0.1748, "fireY_pct": 46},
	"foe_cold_inf_btr60": {"fireX": 0.2646, "fireY_pct": 44.82},
	"foe_mod_arm_m1a1": {"fireX": 0.1006, "fireY_pct": 45.02},
	"foe_mod_arty_m270": {"fireX": 0.1768, "fireY_pct": 48.93},
	"foe_fut_inf_scout_mech": {"fireX": 0.2998, "fireY_pct": 35.45},
	"foe_fut_arm_nexus": {"fireX": 0.1494, "fireY_pct": 48.54},
	"xeno_swarmling": {"fireX": 0.1514, "fireY_pct": 55.18},
	"xeno_probe": {"fireX": 0.1279, "fireY_pct": 36.43},
	"xeno_zealot": {"fireX": 0.1357, "fireY_pct": 28.42},
	"xeno_stalker": {"fireX": 0.1006, "fireY_pct": 39.94},
	"xeno_adept": {"fireX": 0.2881, "fireY_pct": 40.33},
	"xeno_sentinel": {"fireX": 0.208, "fireY_pct": 43.07},
	"xeno_dragoon": {"fireX": 0.1494, "fireY_pct": 38.18},
	"xeno_plasma_bug": {"fireX": 0.1592, "fireY_pct": 44.63},
	"xeno_tripod": {"fireX": 0.2002, "fireY_pct": 41.89},
	"xeno_hunter": {"fireX": 0.2568, "fireY_pct": 24.71},
	"xeno_mimic": {"fireX": 0.3408, "fireY_pct": 42.09},
	"xeno_biomorph": {"fireX": 0.1201, "fireY_pct": 42.09},
	"xeno_dark_templar": {"fireX": 0.1865, "fireY_pct": 37.79},
	"xeno_reaver": {"fireX": 0.1162, "fireY_pct": 43.65},
	"xeno_interceptor": {"fireX": 0.1514, "fireY_pct": 39.55},
	"xeno_carrier": {"fireX": 0.1006, "fireY_pct": 50.1},
	"xeno_saucer": {"fireX": 0.5146, "fireY_pct": 59.86},
	"xeno_templar": {"fireX": 0.2803, "fireY_pct": 42.09},
	"xeno_thing": {"fireX": 0.28, "fireY_pct": 45},
	"xeno_mothership": {"fireX": 0.3193, "fireY_pct": 52.05},
	"foe_ww2_inf_panzerschrek": {"fireX": 0.208, "fireY_pct": 45.8},
	"foe_cold_arm_t55": {"fireX": 0.091, "fireY_pct": 47.2},
	"foe_cold_inf_bmp1": {"fireX": 0.13, "fireY_pct": 48.7},
	"foe_cold_sup_m113": {"fireX": 0.245, "fireY_pct": 43.9},
	"foe_cold_sup_zsu23": {"fireX": 0.171, "fireY_pct": 20.6},
	"foe_mod_arm_m1a2sep": {"fireX": 0.085, "fireY_pct": 45.0},
	"foe_fut_arm_hovertank": {"fireX": 0.142, "fireY_pct": 50.9},
}

## 查询单位的弹道锚点（无数据返回空字典，调用方走回退逻辑）。
## 键名四级回退——运行时 archetype_id 与标注键名存在差异：
## ① 直查 unit_id（C/D 段固定敌与池敌、堡垒）；
## ② A/B 段敌人运行时键带 foe_ 前缀而标注用本体 id：剥前缀再查（如 foe_fut_sup_bulwark → fut_sup_bulwark）；
## ③ A 段平台敌人与 platform_* 共用卡图：经 EnemyUnitManifest 映射转查（如 ww2_arm_tiger → platform_ww2_heavy）；
## ④ v27 图源回退：archetype 的 visual_id 本身是带标注卡图 id 时（星冥占位复用
##    fut_* 等现有卡图），继承该图开火点。仅新增命中——经典单位命中/兜底行为不变。
static func get_anchor(unit_id: String) -> Dictionary:
	var key := String(unit_id).strip_edges()
	var anchor: Dictionary = MUZZLE.get(key, {})
	if not anchor.is_empty():
		return anchor
	var base_key := key.substr(4) if key.begins_with("foe_") else key
	if base_key != key:
		anchor = MUZZLE.get(base_key, {})
		if not anchor.is_empty():
			return anchor
	var mapped: String = EnemyUnitManifest.platform_visual_id_for(base_key)
	if not mapped.is_empty() and mapped != base_key:
		anchor = MUZZLE.get(mapped, {})
		if not anchor.is_empty():
			return anchor
	var vis_id: String = EnemyUnitManifest.visual_id_for_archetype(base_key)
	if not vis_id.is_empty() and vis_id != base_key and vis_id != mapped:
		anchor = MUZZLE.get(vis_id, {})
	return anchor

## 计算弹道点相对单位原点(脚部)的像素偏移。
## 返回 Vector2：x 横向偏移(右正左负)，y 竖向偏移(上负下正，与 global_position+UP 口径一致)。
## 基于单位 Sprite2D 的纹理尺寸 + scale 把百分比换算为像素。
## sprite 为 null 或无纹理时返回 (0, -30) 兜底（约胸部高度）。
static func get_fire_offset(unit_id: String, sprite) -> Vector2:
	var anchor: Dictionary = get_anchor(unit_id)
	if anchor.is_empty():
		return Vector2.ZERO  # 无标注，调用方走 entity_top_y*0.5 回退
	var tex_h: float = 100.0
	var tex_w: float = 100.0
	var s: float = 1.0
	if sprite != null and sprite.texture != null:
		tex_h = maxf(float(sprite.texture.get_height()), 1.0)
		tex_w = maxf(float(sprite.texture.get_width()), 1.0)
		s = absf(float(sprite.scale.y))
	var fire_x_pct: float = float(anchor.get("fireX", 0.5))
	var fire_y_pct: float = float(anchor.get("fireY_pct", 50.0))
	# X: 0~1 → 像素，以纹理中线为 0
	var px_x: float = (fire_x_pct - 0.5) * tex_w * s
	# Y: 原点是脚线（apply_uniform_card_sprite 的 foot offset 对齐）不是纹理底边。
	# fireY_pct 从纹理顶部量，纹理底边在脚线下方 ff×图高处，须先扣 ff 再换算
	# （漏 ff = 弹道点/枪口火浮空 ff×图高）。敌方表无 ff 字段，按 archetype→icon
	# 基名反查扫描表 CardFootAnchors.FOOT_FRAC（未收录图标回退 0.0=旧口径）。
	var px_y: float = -(1.0 - _foot_frac_for_unit(unit_id) - fire_y_pct / 100.0) * tex_h * s
	return Vector2(px_x, px_y)


## archetype_id → icon 基名（vis_enemy_NNN 或同名卡图）→ 扫描脚部锚点。
## 键解析与 get_anchor 同起点（剥 foe_ 前缀），帧动画单位同样适用
## （ff 是每卡数据，帧内容占比已与卡图 bbox 归一）。
## A/B 段平台敌（如 ww2_arm_tiger）图标经 platform 映射目标反查（与 get_anchor 步骤③同源）。
static func _foot_frac_for_unit(unit_id: String) -> float:
	var key := String(unit_id).strip_edges()
	if key.begins_with("foe_"):
		key = key.substr(4)
	var icon: String = EnemyUnitManifest.visual_id_for_archetype(key)
	if icon.is_empty() or icon == key:
		var mapped: String = EnemyUnitManifest.platform_visual_id_for(key)
		if not mapped.is_empty() and mapped != key:
			var m_icon: String = EnemyUnitManifest.visual_id_for_archetype(mapped)
			icon = m_icon if not m_icon.is_empty() else mapped
	if icon.is_empty():
		icon = key
	return CardFootAnchors.get_foot_frac(icon)
