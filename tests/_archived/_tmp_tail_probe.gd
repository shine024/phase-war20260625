extends SceneTree
## v6.14.3 长尾诊断：eng/rec 模块的 unit_type 归属 + 白名单 + 所在兵种池
func _init() -> void:
	var reg = load("res://scripts/systems/modification_registry.gd")
	var lo = load("res://data/enemy_fixed_loadouts.gd")
	var probe := ["eng_01_mine_sweeper", "eng_05_shovel", "eng_08_medical", "eng_10_camouflage",
		"rec_03_suppressor", "rec_05_uav", "rec_10_medkit", "rec_12_atv", "rec_18_target_database"]
	for mid in probe:
		var md: Dictionary = reg.get_data(mid)
		if md.is_empty():
			print(mid, " -> 未注册")
			continue
		var in_pools: Array = []
		for ut in range(5):
			if (reg.get_for_unit_type(ut) as Array).has(mid):
				in_pools.append(ut)
		# 白名单命中（同生成器口径）
		var eff: Dictionary = md.get("effects", {})
		if eff.is_empty():
			var le: Dictionary = md.get("level_effects", {})
			if not le.is_empty():
				var ks: Array = le.keys()
				ks.sort()
				eff = le[int(ks[ks.size() - 1])]
		var wl := false
		for k in eff.keys():
			if lo.LOADOUT_MOD_SUPPORTED_KEYS.has(String(k)):
				wl = true
				break
		var has_kit: bool = not (lo.get_loadout(mid).is_empty())
		print("%s unit_type=%s 池=%s 白名单=%s 稀有度=%s era_band=%s" % [
			mid, str(md.get("unit_type")), str(in_pools), str(wl),
			str(md.get("rarity")), str(md.get("era_band"))])
	quit(0)
