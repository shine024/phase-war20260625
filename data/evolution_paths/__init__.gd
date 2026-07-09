## 进化路径系统入口
## 所有兵种进化路径定义

const InfantryEvolution = preload("res://data/evolution_paths/infantry_evolution.gd")
const ArmorEvolution = preload("res://data/evolution_paths/armor_evolution.gd")
const ArtilleryEvolution = preload("res://data/evolution_paths/artillery_evolution.gd")
const AntiAirEvolution = preload("res://data/evolution_paths/anti_air_evolution.gd")
const AirEvolution = preload("res://data/evolution_paths/air_evolution.gd")
const ReconEvolution = preload("res://data/evolution_paths/recon_evolution.gd")
const EngineerEvolution = preload("res://data/evolution_paths/engineer_evolution.gd")
const FortEvolution = preload("res://data/evolution_paths/fort_evolution.gd")

## 根据 card_id 前缀匹配进化路径
static func get_evolution_path(card_id: String) -> Dictionary:
	# 步兵 (ww1_mp18, ww2_thompson, cold_ak47 等)
	if _is_infantry(card_id):
		return {
			main_line = InfantryEvolution.get_main_line(),
			hidden_branches = InfantryEvolution.get_hidden_branches(),
		}
	# 装甲 (ww1_ft17, ww1_saint, ww2_pz3, ww2_tiger, cold_t55 等)
	if _is_armor(card_id):
		return {
			main_line = ArmorEvolution.get_main_line(),
			secondary_line = ArmorEvolution.get_secondary_line(),
			hidden_branches = ArmorEvolution.get_hidden_branches(),
		}
	# 炮兵 (ww1_m81, ww2_m81, cold_m113 等)
	if _is_artillery(card_id):
		return {
			main_line = ArtilleryEvolution.get_main_line(),
			hidden_branches = ArtilleryEvolution.get_hidden_branches(),
		}
	# 防空 (ww1_37mm, cold_zsu23 等)
	if _is_anti_air(card_id):
		return {
			main_line = AntiAirEvolution.get_main_line(),
			hidden_branches = AntiAirEvolution.get_hidden_branches(),
		}
	# 空中 (cold_mig21, mod_ah1, mod_ah64 等)
	if _is_air(card_id):
		return {
			main_line = AirEvolution.get_main_line(),
			secondary_line = AirEvolution.get_secondary_line(),
			hidden_branches = AirEvolution.get_hidden_branches(),
		}
	# 侦察 (ww1_cavalry 等)
	if _is_recon(card_id):
		return {
			main_line = ReconEvolution.get_main_line(),
			hidden_branches = ReconEvolution.get_hidden_branches(),
		}
	# 工程 (ww1_engineer 等)
	if _is_engineer(card_id):
		return {
			main_line = EngineerEvolution.get_main_line(),
			hidden_branches = EngineerEvolution.get_hidden_branches(),
		}
	# 堡垒 (fort_ww1, fort_ww2, fort_cold 等)
	if _is_fort(card_id):
		return {
			main_line = FortEvolution.get_main_line(),
			secondary_line = FortEvolution.get_secondary_line(),
			hidden_branches = FortEvolution.get_hidden_branches(),
		}
	return {}

## 检查进化条件
static func check_evolution_requirements(card: Dictionary, target_card_id: String) -> Dictionary:
	var path = get_evolution_path(card.get("card_id", ""))
	if path.is_empty():
		return {passed = false, missing = ["无进化路径"]}
	# 在所有线路中查找目标节点
	for line_key in path.keys():
		var line_data = path[line_key]
		if line_data is Dictionary:
			for stage_key in line_data.keys():
				var stage_data = line_data[stage_key]
				if stage_data is Dictionary and stage_data.get("card_id", "") == target_card_id:
					var reqs = stage_data.get("requirements", {})
					var result = {passed = true, missing = []}
					var level = card.get("enhance_level", 1)
					if level < reqs.get("level", 1):
						result.passed = false
						result.missing.append("强化等级不足（需要%d，当前%d）" % [reqs.level, level])
					return result
	return {passed = false, missing = ["未找到目标进化节点"]}

## 计算进化后属性
static func calculate_evolved_stats(old_card: Dictionary, target_card_id: String) -> Dictionary:
	var path = get_evolution_path(old_card.get("card_id", ""))
	if path.is_empty():
		return {}
	for line_key in path.keys():
		var line_data = path[line_key]
		if line_data is Dictionary:
			for stage_key in line_data.keys():
				var stage_data = line_data[stage_key]
				if stage_data is Dictionary and stage_data.get("card_id", "") == target_card_id:
					return {
						max_hp = stage_data.get("max_hp", 0),
						attack_light = stage_data.get("attack_light", 0),
						attack_armor = stage_data.get("attack_armor", 0),
						attack_air = stage_data.get("attack_air", 0),
						defense_light = stage_data.get("defense_light", 0),
						defense_armor = stage_data.get("defense_armor", 0),
						defense_air = stage_data.get("defense_air", 0),
						power = stage_data.get("power", 0),
						inherit_multiplier = stage_data.get("inherit_multiplier", 0.30),
					}
	return {}

## ─────────── card_id 分类辅助 ───────────
## v7.x: 卡牌 ID 规范化后（加兵种中缀），前缀已同步更新。
## 与 modification_modules 的兵种划分保持一致。

static func _is_infantry(card_id: String) -> bool:
	# cold_m60(步兵机枪) 与 cold_m60t(装甲坦克) 前缀冲突，排除装甲卡
	if card_id == "cold_m60t":
		return false
	return card_id.begins_with("ww1_mp18") or card_id.begins_with("ww1_mauser") \
		or card_id.begins_with("ww1_enfield") or card_id.begins_with("ww1_storm") \
		or card_id.begins_with("ww1_flame") or card_id.begins_with("ww2_thompson") \
		or card_id.begins_with("ww2_garand") or card_id.begins_with("ww2_mp40") \
		or card_id.begins_with("ww2_ppsh") or card_id.begins_with("ww2_inf_panzerschrek") \
		or card_id.begins_with("ww2_inf_bazooka") or card_id.begins_with("cold_ak47") \
		or card_id.begins_with("cold_m14") or card_id.begins_with("cold_m60") \
		or card_id.begins_with("cold_rpk") or card_id.begins_with("cold_rpg") \
		or card_id.begins_with("mod_marine") or card_id.begins_with("mod_javelin") \
		or card_id.begins_with("mod_inf_technical") or card_id.begins_with("mod_hummer_m2") \
		or card_id.begins_with("mod_hummer_tow") or card_id.begins_with("fut_cyborg") \
		or card_id.begins_with("fut_heavy_trooper")

static func _is_armor(card_id: String) -> bool:
	# cold_m1(装甲) 与 cold_m14(步兵) 前缀冲突，排除步兵卡
	if card_id == "cold_m14":
		return false
	return card_id.begins_with("ww1_arm_rolls") or card_id.begins_with("ww1_lanchest") \
		or card_id.begins_with("ww1_arm_ft17") or card_id.begins_with("ww1_saint") \
		or card_id.begins_with("ww1_a7v") or card_id.begins_with("ww1_mark4") \
		or card_id.begins_with("ww2_pz3") or card_id.begins_with("ww2_pz4") \
		or card_id.begins_with("ww2_panther") or card_id.begins_with("ww2_arm_tiger") \
		or card_id.begins_with("ww2_kingtiger") or card_id.begins_with("ww2_t34") \
		or card_id.begins_with("ww2_is2") or card_id.begins_with("ww2_arm_sherman") \
		or card_id.begins_with("ww2_inf_hellcat") or card_id.begins_with("cold_inf_btr60") \
		or card_id.begins_with("cold_inf_bmp1") or card_id.begins_with("cold_bradley") \
		or card_id.begins_with("cold_arm_t55") or card_id.begins_with("cold_t62") \
		or card_id.begins_with("cold_t72") or card_id.begins_with("cold_m60t") \
		or card_id.begins_with("cold_m1") or card_id.begins_with("cold_leo1") \
		or card_id.begins_with("cold_chieftain") or card_id.begins_with("mod_stryker") \
		or card_id.begins_with("mod_arm_m1a") or card_id.begins_with("mod_m1a2") \
		or card_id.begins_with("mod_t90") or card_id.begins_with("mod_leo2a6") \
		or card_id.begins_with("mod_challenger2") or card_id.begins_with("fut_assault_mech") \
		or card_id.begins_with("fut_arm_heavy_mech") or card_id.begins_with("fut_arm_hovertank") \
		or card_id.begins_with("fut_arm_prism") or card_id.begins_with("fut_colossus") \
		or card_id.begins_with("fut_arm_nexus") or card_id.begins_with("fut_arm_omega")

static func _is_artillery(card_id: String) -> bool:
	return card_id.begins_with("ww1_arty_m81") or card_id.begins_with("ww1_m76") \
		or card_id.begins_with("ww1_arty_77mm") or card_id.begins_with("ww1_105mm") \
		or card_id.begins_with("ww1_mg08") or card_id.begins_with("ww1_vickers") \
		or card_id.begins_with("ww2_arty_m81") or card_id.begins_with("ww2_m120") \
		or card_id.begins_with("ww2_mg42") or card_id.begins_with("ww2_browning") \
		or card_id.begins_with("cold_sup_m113") or card_id.begins_with("mod_arty_m270") \
		or card_id.begins_with("fut_howitzer") or card_id.begins_with("fut_stormcore")

static func _is_anti_air(card_id: String) -> bool:
	return card_id.begins_with("ww1_37mm") \
		or card_id.begins_with("cold_sup_zsu23") or card_id.begins_with("cold_sam7") \
		or card_id.begins_with("mod_sup_m6") or card_id.begins_with("mod_stinger") \
		or card_id.begins_with("fut_aa_hover")

static func _is_air(card_id: String) -> bool:
	# 注：fut_nano_drone 虽 combat_kind=3，但属工兵进化线终点，走 _is_engineer（分发顺序 air 在 engineer 前，此处不放）
	return card_id.begins_with("cold_mig21") or card_id.begins_with("cold_f4") \
		or card_id.begins_with("mod_ah1") or card_id.begins_with("mod_ah64") \
		or card_id.begins_with("mod_uh60") or card_id.begins_with("fut_attack_drone") \
		or card_id.begins_with("fut_swarm") or card_id.begins_with("mod_inf_scout_drone") \
		or card_id.begins_with("fut_space_fighter") or card_id.begins_with("fut_stealth_bomber")

static func _is_recon(card_id: String) -> bool:
	return card_id.begins_with("ww1_inf_cavalry") \
		or card_id.begins_with("cold_spetsnaz") or card_id.begins_with("mod_ranger") \
		or card_id.begins_with("fut_spectre") or card_id.begins_with("fut_inf_scout_mech")

static func _is_engineer(card_id: String) -> bool:
	return card_id.begins_with("ww1_sup_engineer") \
		or card_id.begins_with("fut_nano_drone")

static func _is_fort(card_id: String) -> bool:
	# 堡垒卡 ID 是 {era}_fort_* 中缀形式（如 ww1_fort_pillbox），用 find 判定
	return card_id.find("_fort_") > 0
