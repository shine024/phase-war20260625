extends SceneTree
## v7.x 改造前缀修复冒烟测试
## 验证 9 个改造文件的 _matches_card 前缀表能正确匹配 v7.x 规范化后的卡 ID
## 运行: Godot --headless --script tests/mod_prefix_smoke.gd

const ArmorMods = preload("res://data/modification_modules/armor_mods.gd")
const AirMods = preload("res://data/modification_modules/air_mods.gd")
const AntiAirMods = preload("res://data/modification_modules/anti_air_mods.gd")
const ArtilleryMods = preload("res://data/modification_modules/artillery_mods.gd")
const EngineerMods = preload("res://data/modification_modules/engineer_mods.gd")
const InfantryMods = preload("res://data/modification_modules/infantry_mods.gd")
const ReconMods = preload("res://data/modification_modules/recon_mods.gd")
const FortMods = preload("res://data/modification_modules/fort_mods.gd")
const ModInit = preload("res://data/modification_modules/__init__.gd")

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("=== 改造前缀匹配冒烟测试 ===")
	_test_armor()
	_test_air()
	_test_anti_air()
	_test_artillery()
	_test_engineer()
	_test_infantry()
	_test_recon()
	_test_fort()
	_test_cold_m14_exclusion()
	_test_guess_combat_kind()
	print("")
	print("结果: %d PASS / %d FAIL" % [_pass, _fail])
	print("=================================")
	quit(1 if _fail > 0 else 0)

func _check(label: String, actual: bool, expected: bool) -> void:
	var ok: bool = (actual == expected)
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s — 期望 %s 实际 %s" % [label, expected, actual])

## 应匹配装甲类改造的卡（combat_kind=1）
func _test_armor() -> void:
	print("[装甲类] v7.x 新 ID 应匹配")
	for card_id in ["ww1_arm_ft17", "ww1_arm_rolls", "ww2_arm_tiger", "ww2_arm_sherman", "ww2_inf_hellcat", "cold_arm_t55", "cold_inf_btr60", "cold_inf_bmp1", "cold_t72", "cold_t62", "cold_m1", "mod_arm_m1a1", "mod_arm_m1a2sep", "mod_m1a2", "mod_leo2a6", "mod_challenger2", "fut_arm_heavy_mech", "fut_arm_omega", "fut_arm_nexus", "ww2_panther"]:
		_check("%s→装甲" % card_id, ArmorMods.get_for_card(card_id).size() > 0, true)

## 不应匹配装甲类改造的卡（步兵/炮兵/空军）
func _test_armor_negative() -> void:
	pass  # 见 _test_cold_m14_exclusion

## 应匹配空军类改造的卡（combat_kind=3）
func _test_air() -> void:
	print("[空军类] v7.x 新 ID 应匹配")
	for card_id in ["mod_inf_scout_drone", "fut_nano_drone", "fut_attack_drone", "fut_swarm", "mod_ah64", "cold_mig21", "fut_stealth_bomber"]:
		_check("%s→空军" % card_id, AirMods.get_for_card(card_id).size() > 0, true)

## 应匹配防空类改造的卡
func _test_anti_air() -> void:
	print("[防空类] v7.x 新 ID 应匹配")
	for card_id in ["cold_sup_zsu23", "mod_sup_m6", "mod_stinger", "ww1_37mm", "fut_aa_hover"]:
		_check("%s→防空" % card_id, AntiAirMods.get_for_card(card_id).size() > 0, true)

## 应匹配炮兵类改造的卡（combat_kind=2 纯炮兵/机枪）
func _test_artillery() -> void:
	print("[炮兵类] v7.x 新 ID 应匹配")
	for card_id in ["ww1_arty_m81", "ww1_arty_77mm", "ww2_arty_m81", "cold_sup_m113", "mod_arty_m270", "fut_howitzer"]:
		_check("%s→炮兵" % card_id, ArtilleryMods.get_for_card(card_id).size() > 0, true)

## 应匹配工兵类改造的卡
func _test_engineer() -> void:
	print("[工兵类] v7.x 新 ID 应匹配")
	_check("ww1_sup_engineer→工兵", EngineerMods.get_for_card("ww1_sup_engineer").size() > 0, true)
	_check("fut_nano_drone→工兵", EngineerMods.get_for_card("fut_nano_drone").size() > 0, true)

## 应匹配步兵类改造的卡（combat_kind=0，不含侦察子集）
func _test_infantry() -> void:
	print("[步兵类] v7.x 新 ID 应匹配")
	for card_id in ["ww2_inf_panzerschrek", "ww2_inf_bazooka", "mod_inf_technical", "fut_inf_scout_mech", "cold_m14", "cold_ak47"]:
		_check("%s→步兵" % card_id, InfantryMods.get_for_card(card_id).size() > 0, true)

## 应匹配侦察类改造的卡
func _test_recon() -> void:
	print("[侦察类] v7.x 新 ID 应匹配")
	for card_id in ["ww1_inf_cavalry", "fut_inf_scout_mech", "mod_inf_scout_drone", "cold_spetsnaz", "fut_spectre"]:
		_check("%s→侦察" % card_id, ReconMods.get_for_card(card_id).size() > 0, true)

## 应匹配堡垒类改造的卡（combat_kind=4）
func _test_fort() -> void:
	print("[堡垒类] 10 张卡应匹配")
	for card_id in ["ww1_fort_pillbox", "ww1_fort_artillery", "ww2_fort_bunker", "ww2_fort_flak", "cold_fort_missile", "cold_fort_radar", "mod_fort_citadel", "mod_fort_phalanx", "fut_fort_ion", "fut_fort_shield"]:
		_check("%s→堡垒" % card_id, FortMods.get_for_card(card_id).size() > 0, true)

## cold_m14（步兵）不应被装甲误匹配
func _test_cold_m14_exclusion() -> void:
	print("[边界] cold_m14 步兵不应匹配装甲")
	_check("cold_m14→装甲(应排除)", ArmorMods.get_for_card("cold_m14").size() > 0, false)

## _guess_combat_kind（通用改造兵种推断，__init__.gd）
func _test_guess_combat_kind() -> void:
	print("[_guess_combat_kind] 兵种推断")
	_check("ww2_arm_tiger→装甲(1)", ModInit._guess_combat_kind("ww2_arm_tiger") == 1, true)
	_check("cold_arm_t55→装甲(1)", ModInit._guess_combat_kind("cold_arm_t55") == 1, true)
	_check("cold_m1→装甲(1)", ModInit._guess_combat_kind("cold_m1") == 1, true)
	_check("cold_m14→步兵(0,非装甲)", ModInit._guess_combat_kind("cold_m14") == 0, true)
	_check("mod_arm_m1a1→装甲(1)", ModInit._guess_combat_kind("mod_arm_m1a1") == 1, true)
	_check("fut_arm_heavy_mech→装甲(1)", ModInit._guess_combat_kind("fut_arm_heavy_mech") == 1, true)
	_check("ww2_fort_bunker→堡垒(4)", ModInit._guess_combat_kind("ww2_fort_bunker") == 4, true)
	_check("fut_fort_shield→堡垒(4)", ModInit._guess_combat_kind("fut_fort_shield") == 4, true)
	_check("mod_inf_scout_drone→空军(3)", ModInit._guess_combat_kind("mod_inf_scout_drone") == 3, true)
	_check("ww1_sup_engineer→支援(2)", ModInit._guess_combat_kind("ww1_sup_engineer") == 2, true)
	_check("mod_arty_m270→支援(2)", ModInit._guess_combat_kind("mod_arty_m270") == 2, true)
	_check("cold_sup_zsu23→支援(2)", ModInit._guess_combat_kind("cold_sup_zsu23") == 2, true)
