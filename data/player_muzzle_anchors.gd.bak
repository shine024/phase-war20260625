extends RefCounted
class_name PlayerMuzzleAnchors

## 我方卡头脚+开火点锚点（单一真理源）
## 数据源：docs/敌我双方卡头脚和开火位置.json（117 条，用户在标注工具里调整）
##
## 与敌方 muzzle_anchors.gd 的关键区别：
## - 我方卡图(vis_player)= 敌原图(vis_enemy)的水平翻转，图朝左
## - fireX 已转换为我方图坐标（枪口在右侧，值 >= 0.5），运行时直接用，无需再镜像
## - fireY_pct / ff / hf 与敌方语义一致（翻转不改变上下位置）
##
## 查询入口（供 construct_unit_ai.gd 调用）：
## - get_anchor(card_id) -> Dictionary（含 fireX/fireY_pct/ff/hf，空字典=未标注）
## - get_fire_offset(card_id, sprite) -> Vector2（相对单位原点的像素偏移，与 MuzzleAnchors.get_fire_offset 同口径）
## - get_foot_frac(card_id) / get_head_frac(card_id) -> float（脚/头锚点比例）
const PLAYER_MUZZLE: Dictionary = {
	"guardian_ww1_ironclad": {"fireX": 1, "fireY_pct": 46, "ff": 0.3733, "hf": 0.3733},
	"ww1_105mm": {"fireX": 0.9557, "fireY_pct": 41.33, "ff": 0.3933, "hf": 0.3933},
	"ww1_37mm": {"fireX": 0.8612, "fireY_pct": 34.67, "ff": 0.3067, "hf": 0.32},
	"ww1_a7v": {"fireX": 0.9054, "fireY_pct": 49.6, "ff": 0.424, "hf": 0.424},
	"ww1_arm_ft17": {"fireX": 0.7224, "fireY_pct": 44.67, "ff": 0.4133, "hf": 0.4133},
	"ww1_arm_rolls": {"fireX": 0.6779, "fireY_pct": 43.33, "ff": 0.38, "hf": 0.38},
	"ww1_arty_77mm": {"fireX": 0.95, "fireY_pct": 40.67, "ff": 0.3733, "hf": 0.3733},
	"ww1_arty_m81": {"fireX": 0.9057, "fireY_pct": 39.33, "ff": 0.3733, "hf": 0.3733},
	"ww1_enfield": {"fireX": 0.851, "fireY_pct": 45.87, "ff": 0.3147, "hf": 0.3147},
	"ww1_flame": {"fireX": 0.7967, "fireY_pct": 45.2, "ff": 0.2813, "hf": 0.2987},
	"ww1_fort_artillery": {"fireX": 0.8724, "fireY_pct": 44.67, "ff": 0.3733, "hf": 0.3733},
	"ww1_fort_pillbox": {"fireX": 0.8445, "fireY_pct": 44.67, "ff": 0.3667, "hf": 0.3667},
	"ww1_inf_cavalry": {"fireX": 0.65, "fireY_pct": 36, "ff": 0.3267, "hf": 0.3267},
	"ww1_lanchest": {"fireX": 0.7224, "fireY_pct": 42.67, "ff": 0.3933, "hf": 0.3933},
	"ww1_m76": {"fireX": 0.8677, "fireY_pct": 39.73, "ff": 0.3627, "hf": 0.3627},
	"ww1_mark4": {"fireX": 0.9054, "fireY_pct": 49.6, "ff": 0.424, "hf": 0.424},
	"ww1_mauser": {"fireX": 0.851, "fireY_pct": 45.87, "ff": 0.3147, "hf": 0.3147},
	"ww1_mg08": {"fireX": 0.8133, "fireY_pct": 42.4, "ff": 0.396, "hf": 0.396},
	"ww1_mp18": {"fireX": 0.7967, "fireY_pct": 45.2, "ff": 0.2813, "hf": 0.2987},
	"ww1_saint": {"fireX": 0.9054, "fireY_pct": 49.6, "ff": 0.424, "hf": 0.424},
	"ww1_storm": {"fireX": 0.9633, "fireY_pct": 44.8, "ff": 0.3253, "hf": 0.3253},
	"ww1_sup_engineer": {"fireX": 0.7833, "fireY_pct": 44, "ff": 0.38, "hf": 0.38},
	"ww1_vickers": {"fireX": 0.8133, "fireY_pct": 42.4, "ff": 0.396, "hf": 0.396},
	"guardian_ww2_blitzkrieg": {"fireX": 0.9779, "fireY_pct": 47.33, "ff": 0.3867, "hf": 0.3867},
	"ww2_arm_sherman": {"fireX": 0.9167, "fireY_pct": 46.67, "ff": 0.3867, "hf": 0.3867},
	"ww2_arm_tiger": {"fireX": 0.9224, "fireY_pct": 46, "ff": 0.4133, "hf": 0.4133},
	"ww2_arty_m81": {"fireX": 0.9279, "fireY_pct": 42, "ff": 0.3667, "hf": 0.3667},
	"ww2_browning": {"fireX": 0.9177, "fireY_pct": 44, "ff": 0.4133, "hf": 0.4133},
	"ww2_fort_bunker": {"fireX": 0.8224, "fireY_pct": 45.33, "ff": 0.36, "hf": 0.36},
	"ww2_fort_flak": {"fireX": 0.8945, "fireY_pct": 48, "ff": 0.3333, "hf": 0.3333},
	"ww2_garand": {"fireX": 0.8221, "fireY_pct": 36.67, "ff": 0.32, "hf": 0.32},
	"ww2_inf_bazooka": {"fireX": 0.7224, "fireY_pct": 41.33, "ff": 0.38, "hf": 0.38},
	"ww2_inf_hellcat": {"fireX": 0.8945, "fireY_pct": 46.67, "ff": 0.3867, "hf": 0.3867},
	"ww2_inf_panzerschrek": {"fireX": 0.7167, "fireY_pct": 42.67, "ff": 0.3667, "hf": 0.3667},
	"ww2_is2": {"fireX": 0.9391, "fireY_pct": 45.33, "ff": 0.42, "hf": 0.42},
	"ww2_kingtiger": {"fireX": 0.901, "fireY_pct": 47.2, "ff": 0.428, "hf": 0.428},
	"ww2_m120": {"fireX": 0.9167, "fireY_pct": 40, "ff": 0.3867, "hf": 0.3867},
	"ww2_mg42": {"fireX": 0.9177, "fireY_pct": 44, "ff": 0.4133, "hf": 0.4133},
	"ww2_mp40": {"fireX": 0.7344, "fireY_pct": 42.67, "ff": 0.32, "hf": 0.32},
	"ww2_panther": {"fireX": 0.9221, "fireY_pct": 46.4, "ff": 0.416, "hf": 0.416},
	"ww2_ppsh": {"fireX": 0.7344, "fireY_pct": 42.67, "ff": 0.32, "hf": 0.32},
	"ww2_pz3": {"fireX": 0.9779, "fireY_pct": 44.67, "ff": 0.4133, "hf": 0.4133},
	"ww2_pz4": {"fireX": 0.9333, "fireY_pct": 44.67, "ff": 0.4, "hf": 0.4},
	"ww2_t34_76": {"fireX": 0.9391, "fireY_pct": 45.33, "ff": 0.3933, "hf": 0.3933},
	"ww2_t34_85": {"fireX": 0.9445, "fireY_pct": 45.33, "ff": 0.3867, "hf": 0.3867},
	"ww2_thompson": {"fireX": 0.7344, "fireY_pct": 42.67, "ff": 0.32, "hf": 0.32},
	"cold_ak47": {"fireX": 0.701, "fireY_pct": 45.6, "ff": 0.3173, "hf": 0.3173},
	"cold_arm_t55": {"fireX": 0.9279, "fireY_pct": 50, "ff": 0.4067, "hf": 0.4067},
	"cold_bradley": {"fireX": 0.751, "fireY_pct": 43.2, "ff": 0.408, "hf": 0.408},
	"cold_chieftain": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"cold_f4": {"fireX": 0.68, "fireY_pct": 54.4, "ff": 0.436, "hf": 0.436},
	"cold_fort_missile": {"fireX": 0.5167, "fireY_pct": 32.67, "ff": 0.3267, "hf": 0.3267},
	"cold_fort_radar": {"fireX": 0.8724, "fireY_pct": 50.67, "ff": 0.3467, "hf": 0.3467},
	"cold_inf_bmp1": {"fireX": 0.7445, "fireY_pct": 43.33, "ff": 0.4, "hf": 0.4},
	"cold_inf_btr60": {"fireX": 0.6333, "fireY_pct": 44, "ff": 0.3933, "hf": 0.3933},
	"cold_leo1": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"cold_m1": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"cold_m14": {"fireX": 0.73, "fireY_pct": 44.93, "ff": 0.3107, "hf": 0.3107},
	"cold_m60": {"fireX": 0.9177, "fireY_pct": 44, "ff": 0.4133, "hf": 0.4133},
	"cold_m60t": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"cold_mig21": {"fireX": 0.68, "fireY_pct": 54.4, "ff": 0.436, "hf": 0.436},
	"cold_rpg": {"fireX": 0.8677, "fireY_pct": 44.93, "ff": 0.384, "hf": 0.384},
	"cold_rpk": {"fireX": 0.9177, "fireY_pct": 44, "ff": 0.4133, "hf": 0.4133},
	"cold_sam7": {"fireX": 0.8667, "fireY_pct": 38.67, "ff": 0.34, "hf": 0.34},
	"cold_spetsnaz": {"fireX": 0.8221, "fireY_pct": 45.07, "ff": 0.3093, "hf": 0.3093},
	"cold_sup_m113": {"fireX": 0.7112, "fireY_pct": 44, "ff": 0.4067, "hf": 0.4067},
	"cold_sup_zsu23": {"fireX": 0.8667, "fireY_pct": 36, "ff": 0.36, "hf": 0.36},
	"cold_t62": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"cold_t72": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"guardian_cold_thunder": {"fireX": 0.85, "fireY_pct": 39.33, "ff": 0.3333, "hf": 0.3333},
	"guardian_modern_stealth": {"fireX": 0.7224, "fireY_pct": 56.67, "ff": 0.4067, "hf": 0.4067},
	"mod_ah1": {"fireX": 0.6721, "fireY_pct": 56.53, "ff": 0.4213, "hf": 0.4213},
	"mod_ah64": {"fireX": 0.6721, "fireY_pct": 56.53, "ff": 0.4213, "hf": 0.4213},
	"mod_arm_m1a1": {"fireX": 0.8724, "fireY_pct": 45.33, "ff": 0.4067, "hf": 0.4067},
	"mod_arm_m1a2sep": {"fireX": 0.9112, "fireY_pct": 46.67, "ff": 0.4133, "hf": 0.4133},
	"mod_arty_m270": {"fireX": 0.6667, "fireY_pct": 44.67, "ff": 0.3933, "hf": 0.3933},
	"mod_challenger2": {"fireX": 0.8888, "fireY_pct": 49.47, "ff": 0.4053, "hf": 0.428},
	"mod_fort_citadel": {"fireX": 0.8612, "fireY_pct": 44, "ff": 0.3533, "hf": 0.3533},
	"mod_fort_phalanx": {"fireX": 0.9167, "fireY_pct": 48.67, "ff": 0.3533, "hf": 0.3533},
	"mod_hummer_m2": {"fireX": 0.651, "fireY_pct": 44.4, "ff": 0.4227, "hf": 0.4227},
	"mod_hummer_tow": {"fireX": 0.651, "fireY_pct": 44.4, "ff": 0.4227, "hf": 0.4227},
	"mod_inf_scout_drone": {"fireX": 0.8, "fireY_pct": 55.33, "ff": 0.3933, "hf": 0.3933},
	"mod_inf_technical": {"fireX": 0.6557, "fireY_pct": 44, "ff": 0.4, "hf": 0.4},
	"mod_javelin": {"fireX": 0.9112, "fireY_pct": 39.33, "ff": 0.3333, "hf": 0.3467},
	"mod_leo2a6": {"fireX": 0.8888, "fireY_pct": 49.47, "ff": 0.4053, "hf": 0.428},
	"mod_m1a2": {"fireX": 0.8888, "fireY_pct": 49.47, "ff": 0.4053, "hf": 0.428},
	"mod_marine": {"fireX": 0.7677, "fireY_pct": 39.2, "ff": 0.3147, "hf": 0.3147},
	"mod_ranger": {"fireX": 0.7633, "fireY_pct": 40.67, "ff": 0.3067, "hf": 0.3067},
	"mod_stinger": {"fireX": 0.8557, "fireY_pct": 32.67, "ff": 0.3133, "hf": 0.3133},
	"mod_stryker_m2": {"fireX": 0.6388, "fireY_pct": 46.67, "ff": 0.38, "hf": 0.4267},
	"mod_stryker_mgs": {"fireX": 0.6388, "fireY_pct": 46.67, "ff": 0.38, "hf": 0.4267},
	"mod_sup_m6": {"fireX": 0.9724, "fireY_pct": 46.67, "ff": 0.3867, "hf": 0.3867},
	"mod_t90": {"fireX": 0.9677, "fireY_pct": 48.13, "ff": 0.432, "hf": 0.432},
	"mod_uh60": {"fireX": 0.6721, "fireY_pct": 56.53, "ff": 0.4213, "hf": 0.4213},
	"fut_aa_hover": {"fireX": 0.5721, "fireY_pct": 40.93, "ff": 0.3973, "hf": 0.3973},
	"fut_arm_heavy_mech": {"fireX": 0.9445, "fireY_pct": 48.67, "ff": 0.3133, "hf": 0.32},
	"fut_arm_hovertank": {"fireX": 0.9, "fireY_pct": 51.33, "ff": 0.4133, "hf": 0.4133},
	"fut_arm_nexus": {"fireX": 0.9891, "fireY_pct": 54.67, "ff": 0.38, "hf": 0.38},
	"fut_arm_omega": {"fireX": 0.8967, "fireY_pct": 44, "ff": 0.3067, "hf": 0.3067},
	"fut_arm_prism": {"fireX": 0.9333, "fireY_pct": 48, "ff": 0.38, "hf": 0.38},
	"fut_assault_mech": {"fireX": 0.93, "fireY_pct": 44.4, "ff": 0.4093, "hf": 0.4093},
	"fut_attack_drone": {"fireX": 0.6945, "fireY_pct": 54.67, "ff": 0.42, "hf": 0.42},
	"fut_colossus": {"fireX": 0.8967, "fireY_pct": 44, "ff": 0.3067, "hf": 0.3067},
	"fut_cyborg": {"fireX": 0.8467, "fireY_pct": 40.8, "ff": 0.312, "hf": 0.312},
	"fut_fort_ion": {"fireX": 0.9279, "fireY_pct": 52.67, "ff": 0.32, "hf": 0.32},
	"fut_fort_shield": {"fireX": 0.85, "fireY_pct": 48.67, "ff": 0.3067, "hf": 0.3067},
	"fut_heavy_trooper": {"fireX": 0.8467, "fireY_pct": 40.8, "ff": 0.312, "hf": 0.312},
	"fut_howitzer": {"fireX": 0.5721, "fireY_pct": 40.93, "ff": 0.3973, "hf": 0.3973},
	"fut_inf_scout_mech": {"fireX": 0.7833, "fireY_pct": 47.33, "ff": 0.3133, "hf": 0.3133},
	"fut_nano_drone": {"fireX": 0.8391, "fireY_pct": 52.67, "ff": 0.3427, "hf": 0.3307},
	"fut_shield": {"fireX": 0.8779, "fireY_pct": 51.33, "ff": 0.3267, "hf": 0.3267},
	"fut_space_fighter": {"fireX": 0.7, "fireY_pct": 56.0, "ff": 0.4, "hf": 0.4},
	"fut_spectre": {"fireX": 0.8844, "fireY_pct": 46.8, "ff": 0.3053, "hf": 0.3053},
	"fut_stealth_bomber": {"fireX": 0.5779, "fireY_pct": 56.0, "ff": 0.3933, "hf": 0.3933},
	"fut_stormcore": {"fireX": 0.6467, "fireY_pct": 38.8, "ff": 0.3053, "hf": 0.3053},
	"fut_swarm": {"fireX": 0.9344, "fireY_pct": 43.07, "ff": 0.3427, "hf": 0.3307},
	"guardian_future_omega": {"fireX": 0.7612, "fireY_pct": 42.67, "ff": 0.3067, "hf": 0.3067},
}

## 取锚点字典（空=未标注，调用方走回退）
static func get_anchor(card_id: String) -> Dictionary:
	return PLAYER_MUZZLE.get(String(card_id).strip_edges(), {})

## 是否已标注
static func has_anchor(card_id: String) -> bool:
	return PLAYER_MUZZLE.has(String(card_id).strip_edges())

## 计算开火点相对单位原点(脚部)的像素偏移。
## 与 MuzzleAnchors.get_fire_offset 同口径：x 横向(右正左负)，y 竖向(上负下正)。
## sprite 为 null 或无纹理时返回 ZERO（调用方走回退）。
## 注意：fireX 已是我方图坐标（朝左），px_x 直接用，不再镜像。
static func get_fire_offset(card_id: String, sprite) -> Vector2:
	var anchor: Dictionary = get_anchor(card_id)
	if anchor.is_empty():
		return Vector2.ZERO
	var tex_h: float = 100.0
	var tex_w: float = 100.0
	var s: float = 1.0
	if sprite != null and sprite.texture != null:
		tex_h = maxf(float(sprite.texture.get_height()), 1.0)
		tex_w = maxf(float(sprite.texture.get_width()), 1.0)
		s = absf(float(sprite.scale.y))
	var fire_x_pct: float = float(anchor.get("fireX", 0.5))
	var fire_y_pct: float = float(anchor.get("fireY_pct", 50.0))
	var px_x: float = (fire_x_pct - 0.5) * tex_w * s
	var px_y: float = -(1.0 - fire_y_pct / 100.0) * tex_h * s
	return Vector2(px_x, px_y)

## 脚部锚点比例（距纹理底部）
static func get_foot_frac(card_id: String) -> float:
	return float(PLAYER_MUZZLE.get(String(card_id).strip_edges(), {}).get("ff", 0.15))

## 头部锚点比例（距纹理顶部）
static func get_head_frac(card_id: String) -> float:
	return float(PLAYER_MUZZLE.get(String(card_id).strip_edges(), {}).get("hf", 0.15))
