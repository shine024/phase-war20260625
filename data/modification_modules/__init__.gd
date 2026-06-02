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
static func _guess_combat_kind(card_id: String) -> int:
	if card_id.begins_with("fort_"): return 4
	if card_id.begins_with("cold_mig21") or card_id.begins_with("cold_f4"): return 3
	if card_id.begins_with("mod_ah") or card_id.begins_with("mod_uh60"): return 3
	if card_id.begins_with("fut_swarm") or card_id.begins_with("fut_scout_drone") or card_id.begins_with("fut_attack_drone"): return 3
	if card_id.begins_with("fut_stealth_bomber") or card_id.begins_with("fut_space_fighter"): return 3
	if card_id.begins_with("fut_nano_drone"): return 3
	# Armor: ww1_rolls/lanchest/ft17/saint/a7v/mark4, ww2_tank/pz/tiger, cold_tank/bmp/bradley etc
	if card_id.begins_with("ww1_rolls") or card_id.begins_with("ww1_lanchest") or card_id.begins_with("ww1_ft17") or card_id.begins_with("ww1_saint") or card_id.begins_with("ww1_a7v") or card_id.begins_with("ww1_mark4"): return 1
	if card_id.begins_with("ww2_pz") or card_id.begins_with("ww2_tiger") or card_id.begins_with("ww2_kingtiger") or card_id.begins_with("ww2_t34") or card_id.begins_with("ww2_is2") or card_id.begins_with("ww2_sherman") or card_id.begins_with("ww2_hellcat"): return 1
	if card_id.begins_with("cold_btr60") or card_id.begins_with("cold_bmp") or card_id.begins_with("cold_bradley"): return 1
	if card_id.begins_with("cold_t") or card_id.begins_with("cold_m60t") or card_id.begins_with("cold_m1") or card_id.begins_with("cold_leo1") or card_id.begins_with("cold_chieftain"): return 1
	if card_id.begins_with("mod_stryker") or card_id.begins_with("mod_m1a") or card_id.begins_with("mod_t90") or card_id.begins_with("mod_leo2") or card_id.begins_with("mod_challenger"): return 1
	if card_id.begins_with("fut_assault_mech") or card_id.begins_with("fut_heavy_mech") or card_id.begins_with("fut_hovertank") or card_id.begins_with("fut_prism") or card_id.begins_with("fut_colossus") or card_id.begins_with("fut_nexus") or card_id.begins_with("omega_platform"): return 1
	# Support (kind=2): mg nests, mortars, aa, engineer
	if card_id.begins_with("ww1_mg08") or card_id.begins_with("ww1_vickers") or card_id.begins_with("ww1_m81") or card_id.begins_with("ww1_m76") or card_id.begins_with("ww1_77mm") or card_id.begins_with("ww1_105mm") or card_id.begins_with("ww1_37mm") or card_id.begins_with("ww1_engineer"): return 2
	if card_id.begins_with("ww2_mg") or card_id.begins_with("ww2_m81") or card_id.begins_with("ww2_m120"): return 2
	if card_id.begins_with("cold_m113") or card_id.begins_with("cold_zsu23") or card_id.begins_with("cold_sam7") or card_id.begins_with("cold_avlb"): return 2
	if card_id.begins_with("mod_m270") or card_id.begins_with("mod_m6") or card_id.begins_with("mod_m9ace"): return 2
	if card_id.begins_with("fut_howitzer") or card_id.begins_with("fut_aa_hover") or card_id.begins_with("fut_shield") or card_id.begins_with("fut_stormcore"): return 2
	# Default: LIGHT (0) for infantry/recon
	return 0
