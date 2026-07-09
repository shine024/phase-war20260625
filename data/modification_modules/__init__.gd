## 改造模块系统入口
## 包含所有140+个改造模块定义

const InfantryModifications = preload("res://data/modification_modules/infantry_mods.gd")
const ArmorModifications = preload("res://data/modification_modules/armor_mods.gd")
const ArtilleryModifications = preload("res://data/modification_modules/artillery_mods.gd")
const AntiAirModifications = preload("res://data/modification_modules/anti_air_mods.gd")
const AirModifications = preload("res://data/modification_modules/air_mods.gd")
const ReconModifications = preload("res://data/modification_modules/recon_mods.gd")
const EngineerModifications = preload("res://data/modification_modules/engineer_mods.gd")
const FortModifications = preload("res://data/modification_modules/fort_mods.gd")
const UniversalModifications = preload("res://data/modification_modules/universal_mods.gd")

## 获取所有改造ID（按兵种过滤）
static func get_for_unit_type(unit_type: int) -> Array:
	var result = []
	result.append_array(InfantryModifications.get_for_unit_type(unit_type))
	result.append_array(ArmorModifications.get_for_unit_type(unit_type))
	result.append_array(ArtilleryModifications.get_for_unit_type(unit_type))
	result.append_array(AntiAirModifications.get_for_unit_type(unit_type))
	result.append_array(AirModifications.get_for_unit_type(unit_type))
	result.append_array(ReconModifications.get_for_unit_type(unit_type))
	result.append_array(EngineerModifications.get_for_unit_type(unit_type))
	result.append_array(FortModifications.get_for_unit_type(unit_type))
	result.append_array(UniversalModifications.get_for_unit_type(unit_type))
	return result

## 获取改造数据（跨所有模块）
static func get_mod_data(mod_id: String) -> Dictionary:
	var result = InfantryModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = ArmorModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = ArtilleryModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = AntiAirModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = AirModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = ReconModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = EngineerModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	result = FortModifications.get_mod_data(mod_id)
	if not result.is_empty():
		return result
	return UniversalModifications.get_mod_data(mod_id)

## 检查冲突（跨所有模块）
static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	if data_a.is_empty() or data_b.is_empty():
		return false
	var group_a = data_a.get("conflict_group", "")
	var group_b = data_b.get("conflict_group", "")
	return group_a != "" and group_a == group_b

## 按 card_id 精筛改造（方案A：替代 get_for_unit_type 的精确查询）
static func get_mods_for_card(card_id: String) -> Array:
	var result = []
	result.append_array(InfantryModifications.get_for_card(card_id))
	result.append_array(ArmorModifications.get_for_card(card_id))
	result.append_array(ArtilleryModifications.get_for_card(card_id))
	result.append_array(AntiAirModifications.get_for_card(card_id))
	result.append_array(AirModifications.get_for_card(card_id))
	result.append_array(ReconModifications.get_for_card(card_id))
	result.append_array(EngineerModifications.get_for_card(card_id))
	result.append_array(FortModifications.get_for_card(card_id))
	# 通用改造需要 combat_kind，从 card_id 推算
	var unit_type = _guess_combat_kind(card_id)
	if unit_type >= 0:
		result.append_array(UniversalModifications.get_for_unit_type(unit_type))
	return result

## 从 card_id 前缀推算 combat_kind
## v7.x: 卡牌 ID 规范化后（加兵种中缀），前缀已同步更新。
static func _guess_combat_kind(card_id: String) -> int:
	# 堡垒卡 ID 是 {era}_fort_* 中缀形式，用 find 判定（begins_with("fort_") 匹配 0 张）
	if card_id.find("_fort_") > 0: return 4
	if card_id.begins_with("cold_mig21") or card_id.begins_with("cold_f4"): return 3
	if card_id.begins_with("mod_ah") or card_id.begins_with("mod_uh60"): return 3
	if card_id.begins_with("fut_swarm") or card_id.begins_with("mod_inf_scout_drone") or card_id.begins_with("fut_attack_drone"): return 3
	if card_id.begins_with("fut_stealth_bomber") or card_id.begins_with("fut_space_fighter"): return 3
	if card_id.begins_with("fut_nano_drone"): return 3
	# Armor
	if card_id.begins_with("ww1_arm_rolls") or card_id.begins_with("ww1_lanchest") or card_id.begins_with("ww1_arm_ft17") or card_id.begins_with("ww1_saint") or card_id.begins_with("ww1_a7v") or card_id.begins_with("ww1_mark4"): return 1
	if card_id.begins_with("ww2_pz") or card_id.begins_with("ww2_panther") or card_id.begins_with("ww2_arm_tiger") or card_id.begins_with("ww2_kingtiger") or card_id.begins_with("ww2_t34") or card_id.begins_with("ww2_is2") or card_id.begins_with("ww2_arm_sherman") or card_id.begins_with("ww2_inf_hellcat"): return 1
	if card_id.begins_with("cold_inf_btr60") or card_id.begins_with("cold_inf_bmp1") or card_id.begins_with("cold_bradley"): return 1
	if card_id.begins_with("cold_arm_t") or card_id.begins_with("cold_t62") or card_id.begins_with("cold_t72") or card_id.begins_with("cold_m60t") or card_id.begins_with("cold_leo1") or card_id.begins_with("cold_chieftain"): return 1
	# cold_m1 是装甲卡，但 begins_with("cold_m1") 会误匹配 cold_m14(步兵)，需排除
	if card_id == "cold_m1" or (card_id.begins_with("cold_m1") and card_id != "cold_m14"): return 1
	if card_id.begins_with("mod_stryker") or card_id.begins_with("mod_arm_m1a") or card_id.begins_with("mod_m1a2") or card_id.begins_with("mod_t90") or card_id.begins_with("mod_leo2a6") or card_id.begins_with("mod_challenger2"): return 1
	if card_id.begins_with("fut_assault_mech") or card_id.begins_with("fut_arm_heavy_mech") or card_id.begins_with("fut_arm_hovertank") or card_id.begins_with("fut_arm_prism") or card_id.begins_with("fut_colossus") or card_id.begins_with("fut_arm_nexus") or card_id.begins_with("fut_arm_omega"): return 1
	# Support (kind=2): mg nests, mortars, aa, engineer
	if card_id.begins_with("ww1_mg08") or card_id.begins_with("ww1_vickers") or card_id.begins_with("ww1_arty_m81") or card_id.begins_with("ww1_m76") or card_id.begins_with("ww1_arty_77mm") or card_id.begins_with("ww1_105mm") or card_id.begins_with("ww1_37mm") or card_id.begins_with("ww1_sup_engineer"): return 2
	if card_id.begins_with("ww2_mg") or card_id.begins_with("ww2_browning") or card_id.begins_with("ww2_arty_m81") or card_id.begins_with("ww2_m120"): return 2
	if card_id.begins_with("cold_sup_m113") or card_id.begins_with("cold_sup_zsu23") or card_id.begins_with("cold_sam7"): return 2
	if card_id.begins_with("mod_arty_m270") or card_id.begins_with("mod_sup_m6") or card_id.begins_with("mod_stinger"): return 2
	if card_id.begins_with("fut_howitzer") or card_id.begins_with("fut_aa_hover") or card_id.begins_with("fut_shield") or card_id.begins_with("fut_stormcore"): return 2
	# Default: LIGHT (0) for infantry/recon
	return 0
