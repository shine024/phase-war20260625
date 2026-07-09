extends SceneTree
## v7.x 进化路径分发全量覆盖核对（112 战斗卡）
## 验证 evolution_paths/__init__.gd 的 _is_* 前缀匹配修复后，所有卡都能查到进化路径
## 运行: Godot --headless --script tests/evolution_path_coverage.gd

const EvoInit = preload("res://data/evolution_paths/__init__.gd")

var _pass: int = 0
var _fail: int = 0

# 全部 112 战斗卡 {card_id: combat_kind}
const CARDS := {
	"cold_ak47":0, "cold_m14":0, "cold_m60":0, "cold_rpg":0, "cold_rpk":0,
	"cold_spetsnaz":0, "fut_cyborg":0, "fut_heavy_trooper":0, "fut_inf_scout_mech":0,
	"fut_spectre":0, "mod_hummer_m2":0, "mod_hummer_tow":0, "mod_inf_technical":0,
	"mod_javelin":0, "mod_marine":0, "mod_ranger":0, "ww1_enfield":0, "ww1_flame":0,
	"ww1_inf_cavalry":0, "ww1_mauser":0, "ww1_mp18":0, "ww1_storm":0, "ww2_garand":0,
	"ww2_inf_bazooka":0, "ww2_inf_panzerschrek":0, "ww2_mp40":0, "ww2_ppsh":0, "ww2_thompson":0,
	"cold_arm_t55":1, "cold_bradley":1, "cold_chieftain":1, "cold_inf_bmp1":1, "cold_inf_btr60":1,
	"cold_leo1":1, "cold_m1":1, "cold_m60t":1, "cold_t62":1, "cold_t72":1,
	"fut_arm_heavy_mech":1, "fut_arm_hovertank":1, "fut_arm_nexus":1, "fut_arm_omega":1,
	"fut_arm_prism":1, "fut_assault_mech":1, "fut_colossus":1, "mod_arm_m1a1":1,
	"mod_arm_m1a2sep":1, "mod_challenger2":1, "mod_leo2a6":1, "mod_m1a2":1,
	"mod_stryker_m2":1, "mod_stryker_mgs":1, "mod_t90":1, "ww1_a7v":1, "ww1_arm_ft17":1,
	"ww1_arm_rolls":1, "ww1_lanchest":1, "ww1_mark4":1, "ww1_saint":1, "ww2_arm_sherman":1,
	"ww2_arm_tiger":1, "ww2_inf_hellcat":1, "ww2_is2":1, "ww2_kingtiger":1, "ww2_panther":1,
	"ww2_pz3":1, "ww2_pz4":1, "ww2_t34_76":1, "ww2_t34_85":1,
	"cold_sam7":2, "cold_sup_m113":2, "cold_sup_zsu23":2, "fut_aa_hover":2, "fut_howitzer":2,
	"fut_shield":2, "fut_stormcore":2, "mod_arty_m270":2, "mod_stinger":2, "mod_sup_m6":2,
	"ww1_105mm":2, "ww1_37mm":2, "ww1_arty_77mm":2, "ww1_arty_m81":2, "ww1_m76":2,
	"ww1_mg08":2, "ww1_sup_engineer":2, "ww1_vickers":2, "ww2_arty_m81":2, "ww2_browning":2,
	"ww2_m120":2, "ww2_mg42":2,
	"cold_f4":3, "cold_mig21":3, "fut_attack_drone":3, "fut_nano_drone":3,
	"fut_space_fighter":3, "fut_stealth_bomber":3, "fut_swarm":3, "mod_ah1":3, "mod_ah64":3,
	"mod_inf_scout_drone":3, "mod_uh60":3,
	"cold_fort_missile":4, "cold_fort_radar":4, "fut_fort_ion":4, "fut_fort_shield":4,
	"mod_fort_citadel":4, "mod_fort_phalanx":4, "ww1_fort_artillery":4, "ww1_fort_pillbox":4,
	"ww2_fort_bunker":4, "ww2_fort_flak":4,
}

func _init() -> void:
	print("=== 进化路径分发全量覆盖核对（112 战斗卡）===")
	print("每张卡应能查到非空进化路径（get_evolution_path 返回非空字典）")
	print("注：fut_shield（力场发生器）设计上不可进化（无进化线节点），预期无路径")
	print()
	# 设计上不可进化的卡（无进化线定义）
	const NO_PATH_CARDS := ["fut_shield"]
	var missing: Array = []
	for card_id in CARDS.keys():
		var path: Dictionary = EvoInit.get_evolution_path(card_id)
		var has_path: bool = (not path.is_empty() and path.has("main_line"))
		var expect_path: bool = not (card_id in NO_PATH_CARDS)
		_check(card_id + " (kind=" + str(CARDS[card_id]) + ")", has_path, expect_path)
		if has_path != expect_path:
			missing.append(card_id)
	print("")
	if missing.is_empty():
		print("✅ 进化路径分发与设计一致（%d 张卡，含 %d 张设计无路径）" % [CARDS.size(), NO_PATH_CARDS.size()])
	else:
		print("❌ %d 张卡路径不符: %s" % [missing.size(), str(missing)])
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
