extends RefCounted
class_name MuzzleAnchors

const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")

## 弹道/枪口锚点数据（独立于 ff/hf，由 docs/enemy_fire_spawn.html 标注）
## fireX: 0~1 (0=纹理左, 0.5=中, 1=右)，相对纹理宽度
## fireY_pct: 0~100 (占纹理顶部百分比，0=顶, 100=底)
## 数据源：docs/enemy_fire_spawn (敌方卡头脚加弹道起始点).json（117 条 = 106 人工标注 + 11 派生）
## 11 条派生条目（fut_arm_omega + 10 个堡垒）从我方标注表 data/player_muzzle_anchors.gd
## 水平镜像换算（enemy fireX = 1 - player fireX，fireY_pct 不变），值为脚本换算非人工标注。
const MUZZLE: Dictionary = {
	"ww1_inf_mp18": {"fireX": 0.2033, "fireY_pct": 45.2},
	"ww1_inf_rifle": {"fireX": 0.149, "fireY_pct": 45.87},
	"ww1_inf_enfield": {"fireX": 0.1946, "fireY_pct": 47.87},
	"fut_inf_c96": {"fireX": 0.2867, "fireY_pct": 45.33},
	"platform_ww1_light": {"fireX": 0.23, "fireY_pct": 37.07},
	"ww1_inf_mp18_x": {"fireX": 0.1946, "fireY_pct": 44.67},
	"ww1_inf_storm_e": {"fireX": 0.0367, "fireY_pct": 44.8},
	"drop_smg_mk2": {"fireX": 0.0367, "fireY_pct": 44.8},
	"ww1_arm_rolls_mk2": {"fireX": 0.3446, "fireY_pct": 43.47},
	"platform_ww1_medium": {"fireX": 0.37, "fireY_pct": 43.6},
	"ww1_arm_rolls_e": {"fireX": 0.3656, "fireY_pct": 42.27},
	"ww1_boss_av7": {"fireX": 0.0946, "fireY_pct": 49.6},
	"ww1_sup_mg_nest": {"fireX": 0.1867, "fireY_pct": 42.4},
	"ww1_arty_mortar": {"fireX": 0.1323, "fireY_pct": 39.73},
	"ww1_sup_vickers": {"fireX": 0.1112, "fireY_pct": 41.73},
	"ww1_sup_ford_ambulance": {"fireX": 0.32, "fireY_pct": 45.87},
	"platform_ww1_radar": {"fireX": 0.3656, "fireY_pct": 45.2},
	"platform_ww1_medic": {"fireX": 0.2888, "fireY_pct": 44.4},
	"platform_ww1_fort": {"fireX": 0.0367, "fireY_pct": 41.33},
	"ww1_fort_pillbox": {"fireX": 0.1054, "fireY_pct": 44.93},
	"ww1_fort_artillery": {"fireX": 0.1177, "fireY_pct": 45.6},
	"ww2_inf_thompson": {"fireX": 0.2656, "fireY_pct": 42.67},
	"ww2_inf_garand": {"fireX": 0.1779, "fireY_pct": 36.67},
	"platform_ww2_light": {"fireX": 0.2633, "fireY_pct": 43.47},
	"platform_ww2_raider": {"fireX": 0.151, "fireY_pct": 45.47},
	"ww2_arm_garand_para": {"fireX": 0.1279, "fireY_pct": 41.47},
	"ww2_inf_kar98k": {"fireX": 0.1367, "fireY_pct": 38.27},
	"ww2_inf_panzerschreck_e": {"fireX": 0.1323, "fireY_pct": 44.93},
	"ww2_inf_para_e": {"fireX": 0.2279, "fireY_pct": 44.93},
	"drop_phase_lance": {"fireX": 0.22, "fireY_pct": 43.73},
	"platform_ww2_medium": {"fireX": 0.049, "fireY_pct": 45.07},
	"ww2_arm_panther_e": {"fireX": 0.0779, "fireY_pct": 46.4},
	"platform_ww2_heavy": {"fireX": 0.0533, "fireY_pct": 45.87},
	"ww2_boss_kingtiger": {"fireX": 0.099, "fireY_pct": 47.2},
	"ww2_sup_gmc_truck": {"fireX": 0.2612, "fireY_pct": 47.2},
	"platform_ww2_radar": {"fireX": 0.3867, "fireY_pct": 44.67},
	"ww2_sup_mg42": {"fireX": 0.0823, "fireY_pct": 44},
	"ww2_arty_hummel": {"fireX": 0.0612, "fireY_pct": 45.33},
	"ww2_arty_pak40": {"fireX": 0, "fireY_pct": 45.47},
	"platform_ww2_siege": {"fireX": 0.199, "fireY_pct": 40.13},
	"platform_ww2_fortress": {"fireX": 0.0779, "fireY_pct": 40.8},
	"ww2_fort_bunker": {"fireX": 0.1677, "fireY_pct": 45.33},
	"ww2_fort_flak": {"fireX": 0.1221, "fireY_pct": 46.67},
	"cold_inf_m60": {"fireX": 0.27, "fireY_pct": 44.93},
	"cold_inf_ak": {"fireX": 0.299, "fireY_pct": 45.6},
	"platform_cold_light": {"fireX": 0.3279, "fireY_pct": 44.93},
	"platform_cold_scout": {"fireX": 0.3367, "fireY_pct": 45.07},
	"cold_inf_metis": {"fireX": 0.0823, "fireY_pct": 45.73},
	"cold_inf_spetsnaz_e": {"fireX": 0.1779, "fireY_pct": 45.07},
	"cold_arm_btr_e": {"fireX": 0.3033, "fireY_pct": 45.87},
	"cold_air_m113_e": {"fireX": 0.249, "fireY_pct": 43.2},
	"cold_arty_bmd1": {"fireX": 0.3779, "fireY_pct": 45.87},
	"cold_sup_bmp1_x": {"fireX": 0.3367, "fireY_pct": 47.33},
	"cold_arty_brem1": {"fireX": 0.299, "fireY_pct": 45.33},
	"platform_cold_medium": {"fireX": 0.0633, "fireY_pct": 48.53},
	"platform_cold_ifv": {"fireX": 0.3677, "fireY_pct": 42},
	"cold_arm_t72_e": {"fireX": 0.0323, "fireY_pct": 48.13},
	"cold_arm_p18": {"fireX": 0.4612, "fireY_pct": 44.8},
	"platform_cold_radar": {"fireX": 0.1367, "fireY_pct": 37.6},
	"drop_mega_beam_cannon": {"fireX": 0.3656, "fireY_pct": 45.6},
	"platform_cold_carrier": {"fireX": 0.33, "fireY_pct": 44.13},
	"cold_boss_mig": {"fireX": 0.32, "fireY_pct": 54.4},
	"cold_fort_missile": {"fireX": 0.5177, "fireY_pct": 30.53},
	"cold_fort_radar": {"fireX": 0.0721, "fireY_pct": 48.53},
	"mod_air_technical_e": {"fireX": 0.349, "fireY_pct": 44.4},
	"platform_modern_light": {"fireX": 0.3177, "fireY_pct": 44.53},
	"platform_modern_stealth": {"fireX": 0.4967, "fireY_pct": 55.2},
	"mod_inf_marine": {"fireX": 0.2323, "fireY_pct": 39.2},
	"mod_sup_m4_carbine": {"fireX": 0.1946, "fireY_pct": 39.2},
	"mod_inf_delta_e": {"fireX": 0.2367, "fireY_pct": 40.67},
	"drop_thunder_field": {"fireX": 0.2367, "fireY_pct": 40.67},
	"mod_arm_stryker_e": {"fireX": 0.3612, "fireY_pct": 46.67},
	"platform_modern_medium": {"fireX": 0.1177, "fireY_pct": 44.93},
	"platform_modern_guard_heavy": {"fireX": 0.1054, "fireY_pct": 44.93},
	"mod_arm_abrams_e": {"fireX": 0.1112, "fireY_pct": 49.47},
	"mod_arm_abrams_mk2": {"fireX": 0.0867, "fireY_pct": 47.6},
	"platform_modern_radar": {"fireX": 0.101, "fireY_pct": 46.67},
	"mod_arty_mlrs_e": {"fireX": 0.4279, "fireY_pct": 40.93},
	"mod_inf_patriot": {"fireX": 0.3533, "fireY_pct": 41.07},
	"mod_arm_himars": {"fireX": 0.4823, "fireY_pct": 41.07},
	"platform_modern_spg": {"fireX": 0.28, "fireY_pct": 42.4},
	"mod_arty_rq7": {"fireX": 0.2033, "fireY_pct": 47.2},
	"mod_sup_growler": {"fireX": 0.299, "fireY_pct": 55.87},
	"mod_air_apache_e": {"fireX": 0.3279, "fireY_pct": 56.53},
	"drop_overclock_matrix": {"fireX": 0.3279, "fireY_pct": 56.53},
	"mod_boss_command": {"fireX": 0.3656, "fireY_pct": 46.67},
	"mod_fort_citadel": {"fireX": 0.101, "fireY_pct": 48.4},
	"mod_fort_phalanx": {"fireX": 0.0721, "fireY_pct": 48.4},
	"platform_future_light": {"fireX": 0.2633, "fireY_pct": 46.4},
	"fut_inf_cyborg": {"fireX": 0.1533, "fireY_pct": 40.8},
	"fut_inf_spectre_e": {"fireX": 0.1156, "fireY_pct": 46.8},
	"fut_inf_storm_rider": {"fireX": 0.2612, "fireY_pct": 44.8},
	"fut_inf_neural": {"fireX": 0.17, "fireY_pct": 42.27},
	"fut_inf_x9": {"fireX": 0.2656, "fireY_pct": 45.6},
	"drop_railgun": {"fireX": 0.1779, "fireY_pct": 45.07},
	"fut_arm_mech_e": {"fireX": 0.07, "fireY_pct": 44.4},
	"fut_arm_hk07": {"fireX": 0.099, "fireY_pct": 40.4},
	"fut_arm_sdkfz": {"fireX": 0.3946, "fireY_pct": 43.07},
	"platform_future_medium": {"fireX": 0.1467, "fireY_pct": 54.8},
	"fut_arm_hovertank_e": {"fireX": 0.0656, "fireY_pct": 47.87},
	"platform_future_heavy": {"fireX": 0.0721, "fireY_pct": 48.8},
	"fut_arm_colossus_e": {"fireX": 0.1033, "fireY_pct": 44},
	"fut_arm_titan_mk2": {"fireX": 0.199, "fireY_pct": 35.33},
	"drop_mega_particle_cannon": {"fireX": 0.1033, "fireY_pct": 44},
	"fut_boss_nexus": {"fireX": 0.3533, "fireY_pct": 38.8},
	"platform_future_radar": {"fireX": 0.1656, "fireY_pct": 40.8},
	"fut_sup_nrepair": {"fireX": 0.2112, "fireY_pct": 45.47},
	"fut_sup_ps9": {"fireX": 0.52, "fireY_pct": 42.93},
	"fut_sup_bulwark": {"fireX": 0.0656, "fireY_pct": 48.93},
	"fut_arty_hel30": {"fireX": 0.1279, "fireY_pct": 41.6},
	"fut_arty_ssc1": {"fireX": 0.7533, "fireY_pct": 35.73},
	"fut_air_drone": {"fireX": 0.0656, "fireY_pct": 43.07},
	"fut_air_regen_frame": {"fireX": 0.1946, "fireY_pct": 45.73},
	"fut_air_heavy_carrier": {"fireX": 0, "fireY_pct": 49.07},
	"fut_arm_omega": {"fireX": 0.1033, "fireY_pct": 44},
	"fut_fort_ion": {"fireX": 0.051, "fireY_pct": 50.93},
	"fut_fort_shield": {"fireX": 0.4888, "fireY_pct": 36.93},
}

## 查询单位的弹道锚点（无数据返回空字典，调用方走回退逻辑）。
## 键名三级回退——运行时 archetype_id 与标注键名存在两类差异：
## ① 直查 unit_id（C/D 段固定敌与池敌、堡垒）；
## ② A/B 段敌人运行时键带 foe_ 前缀而标注用本体 id：剥前缀再查（如 foe_fut_sup_bulwark → fut_sup_bulwark）；
## ③ A 段平台敌人与 platform_* 共用卡图：经 EnemyUnitManifest 映射转查（如 ww2_arm_tiger → platform_ww2_heavy）。
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
	# Y: 0=顶部 → 负偏移（向上），100=底部 → 接近 0
	var px_y: float = -(1.0 - fire_y_pct / 100.0) * tex_h * s
	return Vector2(px_x, px_y)
