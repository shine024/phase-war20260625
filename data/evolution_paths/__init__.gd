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
	# 防空 (ww1_37mm, ww2_flak, cold_zsu23 等)
	if _is_anti_air(card_id):
		return {
			main_line = AntiAirEvolution.get_main_line(),
			hidden_branches = AntiAirEvolution.get_hidden_branches(),
		}
	# 空中 (cold_mig21, mod_f16, mod_ah1, mod_ah64 等)
	if _is_air(card_id):
		return {
			main_line = AirEvolution.get_main_line(),
			secondary_line = AirEvolution.get_secondary_line(),
			hidden_branches = AirEvolution.get_hidden_branches(),
		}
	# 侦察 (ww1_cavalry, ww2_motorcycle 等)
	if _is_recon(card_id):
		return {
			main_line = ReconEvolution.get_main_line(),
			hidden_branches = ReconEvolution.get_hidden_branches(),
		}
	# 工程 (ww1_engineer, ww2_engineer 等)
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

static func _is_infantry(card_id: String) -> bool:
	return card_id.begins_with("ww1_mp18") or card_id.begins_with("ww1_mauser") \
		or card_id.begins_with("ww1_enfield") or card_id.begins_with("ww1_storm") \
		or card_id.begins_with("ww1_flame") or card_id.begins_with("ww2_thompson") \
		or card_id.begins_with("ww2_garand") or card_id.begins_with("ww2_mp40") \
		or card_id.begins_with("ww2_ppsh") or card_id.begins_with("cold_ak47") \
		or card_id.begins_with("cold_m14") or card_id.begins_with("mod_marine") \
		or card_id.begins_with("fut_cyborg") or card_id.begins_with("fut_heavy_trooper")

static func _is_armor(card_id: String) -> bool:
	return card_id.begins_with("ww1_ft17") or card_id.begins_with("ww1_saint") \
		or card_id.begins_with("ww2_pz3") or card_id.begins_with("ww2_tiger") \
		or card_id.begins_with("cold_t55") or card_id.begins_with("cold_t72") \
		or card_id.begins_with("cold_leo1") or card_id.begins_with("mod_m1a1") \
		or card_id.begins_with("mod_m1a2") or card_id.begins_with("fut_hovertank") \
		or card_id.begins_with("fut_heavy_mech") or card_id.begins_with("fut_prism")

static func _is_artillery(card_id: String) -> bool:
	return card_id.begins_with("ww1_m81") or card_id.begins_with("ww2_m81") \
		or card_id.begins_with("cold_m113") or card_id.begins_with("mod_m270") \
		or card_id.begins_with("fut_howitzer")

static func _is_anti_air(card_id: String) -> bool:
	return card_id.begins_with("ww1_37mm") or card_id.begins_with("ww2_flak") \
		or card_id.begins_with("cold_zsu23") or card_id.begins_with("mod_m6") \
		or card_id.begins_with("fut_aa_hover")

static func _is_air(card_id: String) -> bool:
	return card_id.begins_with("cold_mig21") or card_id.begins_with("mod_f16") \
		or card_id.begins_with("mod_ah1") or card_id.begins_with("mod_ah64") \
		or card_id.begins_with("fut_f22") or card_id.begins_with("fut_attack_drone") \
		or card_id.begins_with("fut_swarm") or card_id.begins_with("fut_space_fighter")

static func _is_recon(card_id: String) -> bool:
	return card_id.begins_with("ww1_cavalry") or card_id.begins_with("ww2_motorcycle") \
		or card_id.begins_with("cold_spetsnaz") or card_id.begins_with("mod_ranger") \
		or card_id.begins_with("fut_spectre") or card_id.begins_with("fut_scout_mech")

static func _is_engineer(card_id: String) -> bool:
	return card_id.begins_with("ww1_engineer") or card_id.begins_with("ww2_engineer") \
		or card_id.begins_with("cold_avlb") or card_id.begins_with("mod_m9ace") \
		or card_id.begins_with("fut_nano_drone")

static func _is_fort(card_id: String) -> bool:
	return card_id.begins_with("fort_")
