## 四拍 attack 帧布置实载探针(2026-10-16):headless 校验 33 卡
## anim.json(counts.attack=4)+sheet_attack.png(1024×256)可实载。
## 用法: Godot --headless --path . --script tests/_tmp_attk_deploy_probe.gd
extends SceneTree

const UIDS := [
	"cold_inf_spetsnaz_e", "mod_inf_delta_e", "fut_arm_prism", "ww1_inf_storm_e",
	"mod_arm_m1a1", "ww1_sup_mg_nest", "fut_air_heavy_carrier", "ww2_arty_pak40",
	"ww1_arty_m81", "ww1_arty_mortar", "ww1_boss_av7", "mod_air_technical_e",
	"fut_air_drone", "fut_arm_mech_e", "fut_inf_spectre_e", "fut_arm_colossus_e",
	"ww1_sup_vickers", "ww1_sup_ford_ambulance", "mod_inf_patriot", "fut_arty_hel30",
	"fut_sup_nrepair", "ww1_fort_pillbox", "ww2_fort_flak", "mod_fort_citadel",
	"xeno_tripod", "ww1_saint", "ww2_mg42", "ww2_arty_m81", "cold_sup_zsu23",
	"fut_arm_titan_mk2", "fut_inf_x9",
]

func _init() -> void:
	var root := "res://assets/effects/unit_anims/"
	var bad: Array[String] = []
	for uid in UIDS:
		var fp: String = root + str(uid) + "/anim.json"
		if not FileAccess.file_exists(fp):
			bad.append(uid + ":no json")
			continue
		var meta = JSON.parse_string(FileAccess.open(fp, FileAccess.READ).get_as_text())
		if meta == null or int(meta.get("counts", {}).get("attack", 0)) != 4:
			bad.append(uid + ":bad counts")
			continue
		var tex: Texture2D = load(root + uid + "/sheet_attack.png")
		if tex == null:
			bad.append(uid + ":tex load fail")
			continue
		if tex.get_width() != 1024 or tex.get_height() != 256:
			bad.append(uid + ":tex %dx%d" % [tex.get_width(), tex.get_height()])
	if bad.is_empty():
		print("PROBE OK: %d units" % UIDS.size())
		quit(0)
	else:
		print("PROBE BAD: ", bad)
		quit(1)
