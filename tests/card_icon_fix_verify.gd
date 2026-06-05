## Card Icon Fix Verification — filesystem check
## Usage: godot --headless --rendering-driver opengl3 --path "." --script "tests/card_icon_fix_verify.gd"

extends SceneTree

func _init() -> void:
	var needs_icon: PackedStringArray = [
		"ww1_mp18", "ww1_mauser", "ww1_enfield", "ww1_mg08", "ww1_vickers",
		"ww1_m76", "ww1_storm", "ww1_lanchest", "ww1_saint", "ww1_a7v",
		"ww1_mark4", "ww1_105mm", "ww1_37mm", "ww1_flame",
		
		"ww2_thompson", "ww2_garand", "ww2_mp40", "ww2_ppsh", "ww2_mg42",
		"ww2_browning", "ww2_m120", "ww2_pz3", "ww2_pz4", "ww2_panther",
		"ww2_kingtiger", "ww2_t34_76", "ww2_t34_85", "ww2_is2",
		
		"cold_rpg", "cold_ak47", "cold_m14", "cold_m60", "cold_rpk",
		"cold_bradley", "cold_t62", "cold_t72", "cold_m60t", "cold_m1",
		"cold_leo1", "cold_chieftain", "cold_sam7", "cold_mig21", "cold_f4",
		"cold_spetsnaz",
		
		"mod_marine", "mod_ranger", "mod_javelin", "mod_stinger",
		"mod_stryker_mgs", "mod_stryker_m2", "mod_hummer_tow", "mod_hummer_m2",
		"mod_m1a2", "mod_t90", "mod_leo2a6", "mod_challenger2",
		"mod_ah64", "mod_ah1", "mod_uh60",
		
		"fut_swarm", "fut_attack_drone", "fut_cyborg", "fut_heavy_trooper",
		"fut_assault_mech", "fut_howitzer", "fut_aa_hover", "fut_stealth_bomber",
		"fut_space_fighter", "fut_spectre", "fut_nano_drone", "fut_shield",
		"fut_colossus", "fut_stormcore",
		
		"fort_ww1_pillbox", "fort_ww1_artillery", "fort_ww2_bunker",
		"fort_ww2_flak", "fort_cold_missile", "fort_cold_radar",
		"fort_modern_citadel", "fort_modern_phalanx", "fort_future_ion",
		"fort_future_shield",
	]
	
	print("\n============================================================")
	print("Card Icon Fix Verification")
	print("============================================================")
	
	var found := 0
	var missing := 0
	
	for card_id in needs_icon:
		var path := "res://assets/card_icons/%s.png" % card_id
		# Use FileAccess to check file existence (works in headless)
		if FileAccess.file_exists(path):
			found += 1
		else:
			missing += 1
			print("  MISSING: %s → %s" % [card_id, path])
	
	print("\n------------------------------------------------------------")
	print("Results: %d/%d found, %d missing" % [found, needs_icon.size(), missing])
	print("------------------------------------------------------------")
	
	if missing == 0:
		print("SUCCESS: All card icons are present!")
	else:
		print("WARNING: %d cards still missing icons" % missing)
	
	quit(0 if missing == 0 else 1)
