extends SceneTree
## v7.x 改造前缀全量覆盖核对（112 战斗卡 × 5 主兵种改造）
## 不依赖 get_all_blueprint_ids（避开 --script 模式 autoload 限制），硬编码全部卡 ID + combat_kind
## 运行: Godot --headless --script tests/mod_prefix_full_coverage.gd

const ArmorMods = preload("res://data/modification_modules/armor_mods.gd")
const AirMods = preload("res://data/modification_modules/air_mods.gd")
const ArtilleryMods = preload("res://data/modification_modules/artillery_mods.gd")
const InfantryMods = preload("res://data/modification_modules/infantry_mods.gd")
const FortMods = preload("res://data/modification_modules/fort_mods.gd")
const ModInit = preload("res://data/modification_modules/__init__.gd")

var _pass: int = 0
var _fail: int = 0

# 全部 112 战斗卡 {card_id: combat_kind}
const CARDS := {
	# ck=0 步兵
	"cold_ak47":0, "cold_m14":0, "cold_m60":0, "cold_rpg":0, "cold_rpk":0,
	"cold_spetsnaz":0, "fut_cyborg":0, "fut_heavy_trooper":0, "fut_inf_scout_mech":0,
	"fut_spectre":0, "mod_hummer_m2":0, "mod_hummer_tow":0, "mod_inf_technical":0,
	"mod_javelin":0, "mod_marine":0, "mod_ranger":0, "ww1_enfield":0, "ww1_flame":0,
	"ww1_inf_cavalry":0, "ww1_mauser":0, "ww1_mp18":0, "ww1_storm":0, "ww2_garand":0,
	"ww2_inf_bazooka":0, "ww2_inf_panzerschrek":0, "ww2_mp40":0, "ww2_ppsh":0, "ww2_thompson":0,
	# ck=1 装甲
	"cold_arm_t55":1, "cold_bradley":1, "cold_chieftain":1, "cold_inf_bmp1":1, "cold_inf_btr60":1,
	"cold_leo1":1, "cold_m1":1, "cold_m60t":1, "cold_t62":1, "cold_t72":1,
	"fut_arm_heavy_mech":1, "fut_arm_hovertank":1, "fut_arm_nexus":1, "fut_arm_omega":1,
	"fut_arm_prism":1, "fut_assault_mech":1, "fut_colossus":1, "mod_arm_m1a1":1,
	"mod_arm_m1a2sep":1, "mod_challenger2":1, "mod_leo2a6":1, "mod_m1a2":1,
	"mod_stryker_m2":1, "mod_stryker_mgs":1, "mod_t90":1, "ww1_a7v":1, "ww1_arm_ft17":1,
	"ww1_arm_rolls":1, "ww1_lanchest":1, "ww1_mark4":1, "ww1_saint":1, "ww2_arm_sherman":1,
	"ww2_arm_tiger":1, "ww2_inf_hellcat":1, "ww2_is2":1, "ww2_kingtiger":1, "ww2_panther":1,
	"ww2_pz3":1, "ww2_pz4":1, "ww2_t34_76":1, "ww2_t34_85":1,
	# ck=2 支援(炮兵/防空/工兵)
	"cold_sam7":2, "cold_sup_m113":2, "cold_sup_zsu23":2, "fut_aa_hover":2, "fut_howitzer":2,
	"fut_shield":2, "fut_stormcore":2, "mod_arty_m270":2, "mod_stinger":2, "mod_sup_m6":2,
	"ww1_105mm":2, "ww1_37mm":2, "ww1_arty_77mm":2, "ww1_arty_m81":2, "ww1_m76":2,
	"ww1_mg08":2, "ww1_sup_engineer":2, "ww1_vickers":2, "ww2_arty_m81":2, "ww2_browning":2,
	"ww2_m120":2, "ww2_mg42":2,
	# ck=3 空军
	"cold_f4":3, "cold_mig21":3, "fut_attack_drone":3, "fut_nano_drone":3,
	"fut_space_fighter":3, "fut_stealth_bomber":3, "fut_swarm":3, "mod_ah1":3, "mod_ah64":3,
	"mod_inf_scout_drone":3, "mod_uh60":3,
	# ck=4 堡垒
	"cold_fort_missile":4, "cold_fort_radar":4, "fut_fort_ion":4, "fut_fort_shield":4,
	"mod_fort_citadel":4, "mod_fort_phalanx":4, "ww1_fort_artillery":4, "ww1_fort_pillbox":4,
	"ww2_fort_bunker":4, "ww2_fort_flak":4,
}

# 侦察子集卡（kind=0 但走 recon，不在 infantry；防空/护盾卡 kind=2 但走 anti_air；工兵卡 kind=2 但走 engineer）
const RECON_CARDS := ["ww1_inf_cavalry", "cold_spetsnaz", "mod_ranger", "fut_spectre", "fut_inf_scout_mech", "mod_inf_scout_drone"]
const AA_SHIELD_CARDS := ["ww1_37mm", "cold_sup_zsu23", "cold_sam7", "mod_sup_m6", "mod_stinger", "fut_aa_hover", "fut_shield"]
const ENGINEER_CARDS := ["ww1_sup_engineer"]  # 工兵卡走 engineer_mods，不算 artillery

func _init() -> void:
	print("=== 改造前缀全量覆盖核对（112 战斗卡）===")
	for card_id in CARDS.keys():
		var ck: int = CARDS[card_id]
		_check_card(card_id, ck)
	print("")
	_check_guess_all()
	print("")
	print("结果: %d PASS / %d FAIL" % [_pass, _fail])
	print("=================================")
	quit(1 if _fail > 0 else 0)

func _check(label: String, actual: bool, expected: bool) -> void:
	if actual == expected:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s — 期望 %s 实际 %s" % [label, expected, actual])

func _check_card(card_id: String, ck: int) -> void:
	var is_recon: bool = card_id in RECON_CARDS
	var is_aa: bool = card_id in AA_SHIELD_CARDS
	var is_eng: bool = card_id in ENGINEER_CARDS
	# 期望匹配
	var expect_armor: bool = (ck == 1)
	var expect_air: bool = (ck == 3)
	var expect_fort: bool = (ck == 4)
	var expect_arty: bool = (ck == 2 and not is_aa and not is_eng)  # 纯炮兵/机枪
	var expect_inf: bool = (ck == 0 and not is_recon)  # 步兵（侦察除外）
	# 实际
	var a_armor: bool = ArmorMods.get_for_card(card_id).size() > 0
	var a_air: bool = AirMods.get_for_card(card_id).size() > 0
	var a_fort: bool = FortMods.get_for_card(card_id).size() > 0
	var a_arty: bool = ArtilleryMods.get_for_card(card_id).size() > 0
	var a_inf: bool = InfantryMods.get_for_card(card_id).size() > 0
	# 漏匹配检查
	if expect_armor: _check(card_id + "→装甲(应匹配)", a_armor, true)
	if expect_air: _check(card_id + "→空军(应匹配)", a_air, true)
	if expect_fort: _check(card_id + "→堡垒(应匹配)", a_fort, true)
	if expect_arty: _check(card_id + "→炮兵(应匹配)", a_arty, true)
	if expect_inf: _check(card_id + "→步兵(应匹配)", a_inf, true)
	# 跨兵种误伤检查（装甲卡不应匹配炮兵/堡垒/空军/步兵）
	if ck == 1:
		_check(card_id + "(装甲)不应匹配步兵", a_inf, false)
		_check(card_id + "(装甲)不应匹配堡垒", a_fort, false)
		_check(card_id + "(装甲)不应匹配空军", a_air, false)
	# 步兵卡不应匹配装甲
	if ck == 0:
		_check(card_id + "(步兵)不应匹配装甲", a_armor, false)
	# 堡垒卡不应匹配装甲
	if ck == 4:
		_check(card_id + "(堡垒)不应匹配装甲", a_armor, false)

# === _guess_combat_kind 全量推断核对 ===

func _check_guess_all() -> void:
	print("=== _guess_combat_kind 全量推断核对 ===")
	for card_id in CARDS.keys():
		var expected_ck: int = CARDS[card_id]
		var actual_ck: int = ModInit._guess_combat_kind(card_id)
		# 注意：_guess_combat_kind 把侦察/工兵这类细分兵种归到主兵种（recon→0, engineer→2）
		_check(card_id + " guess=" + str(actual_ck) + " expect=" + str(expected_ck), actual_ck == expected_ck, true)
