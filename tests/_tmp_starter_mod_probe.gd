extends SceneTree
## 临时探针：枚举三张 starter 卡可安装的改造（era_band 过滤后）+ 稀有度/档位门/时代带，
## 供修 v21.6 起始改造清单选件。headless --script 直跑。

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var MR = load("res://scripts/systems/modification_registry.gd")
	var MM = load("res://managers/evolution/mod_manager.gd")
	var PT = load("res://data/power_tiers.gd")
	for base in ["ww1_mauser", "ww1_arm_ft17", "ww1_arty_m81"]:
		print("== %s ==" % base)
		for mid in MR.get_installable_mods_for_card(base):
			var d: Dictionary = MR.get_data(String(mid))
			var rarity := String(d.get("rarity", "?"))
			var band = d.get("era_band", null)
			var band_txt := "全时代"
			if band != null and band is Array and (band as Array).size() == 2:
				band_txt = "era %s-%s" % [band[0], band[1]]
			var min_tier: int = MM.get_min_power_tier_for_mod(String(mid))
			print("  %s | %s | %s | 门=%s | %s" % [
				mid, rarity, band_txt, PT.get_tier_name(min_tier),
				String(d.get("display_name", d.get("name", "")))])
	quit(0)
