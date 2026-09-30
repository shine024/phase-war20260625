extends SceneTree
## 孤儿甄别第三轮：孤儿目录的潜在归属卡实际解析落点。
## 归属卡解析为空 = 站桩 bug（孤儿目录应接线启用）；
## 解析到其他目录 = 孤儿目录是陈旧复本（删除候选）。

const OWNERS := {
	"cold_mig": ["cold_mig21"],
	"fut_hovertank": ["fut_arm_hovertank", "fut_arm_hovertank_e", "fut_aa_hover"],
	"mod_abrams": ["mod_arm_abrams_e", "mod_arm_abrams_mk2"],
	"mod_mlrs": ["mod_arty_mlrs_e"],
	"mod_technical": ["mod_inf_technical", "mod_air_technical_e"],
	"cold_btr": ["cold_inf_btr60"],
	"cold_m113": ["cold_sup_m113"],
	"fut_drone": ["fut_nano_drone", "mod_inf_scout_drone"],
	"fut_mech": ["fut_inf_scout_mech", "fut_arm_heavy_mech"],
	"mod_apache": ["mod_air_apache"],
	"ww1_mortar": ["ww1_arty_mortar"],
	"ww2_para": ["ww2_inf_para_e", "ww2_arm_garand_para"],
	"ww2_tiger": ["ww2_kingtiger"],
	"ww1_rolls": ["ww1_arm_rolls", "ww1_arm_rolls_e", "ww1_arm_rolls_mk2"],
	"vis_xeno_family": ["vis_xeno_biokin", "vis_xeno_hive", "void_stealth_basic"],
}

func _initialize() -> void:
	var ufa := load("res://scripts/battle/unit_frame_anim.gd")
	var uct := load("res://data/unified_card_table.gd")
	print("== owner resolution ==")
	for orphan in OWNERS.keys():
		var line := "  " + String(orphan) + ": "
		var parts := []
		for oid in OWNERS[orphan]:
			var exists: bool = uct.has_card(String(oid))
			var r := String(ufa.call("_resolve_key", String(oid)))
			parts.append("%s(在表=%s)->'%s'" % [oid, "Y" if exists else "N", r])
		print(line, " | ".join(parts))
	print("OWNER_CHECK_DONE")
	quit(0)
