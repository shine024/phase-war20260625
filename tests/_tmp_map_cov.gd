extends SceneTree
## enemy_card_mod_map（改造情报解锁映射）对长尾/全池的覆盖统计
func _init() -> void:
	var map = load("res://data/enemy_card_mod_map.gd")
	var covered: Dictionary = {}
	var arch_count := 0
	for arch in map.get_all_archetype_ids():
		arch_count += 1
		for mid in map.get_unlockable_mods(String(arch)):
			covered[String(mid)] = true
	var probe := ["eng_01_mine_sweeper", "eng_05_shovel", "eng_08_medical", "eng_10_camouflage",
		"rec_03_suppressor", "rec_05_uav", "rec_10_medkit", "rec_12_atv", "rec_18_target_database"]
	for mid in probe:
		print(mid, " -> 解锁池:", "有" if covered.has(mid) else "无")
	var reg = load("res://scripts/systems/modification_registry.gd")
	var all_ids: Array = []
	for ut in range(5):
		for mid in reg.get_for_unit_type(ut):
			if not all_ids.has(String(mid)):
				all_ids.append(String(mid))
	var unc := []
	for mid in all_ids:
		if not covered.has(String(mid)):
			unc.append(String(mid))
	print("[map] 敌形 %d 个 / 解锁池覆盖模块 %d / %d / 未覆盖 %d" % [arch_count, covered.size(), all_ids.size(), unc.size()])
	print("[map] 未覆盖样例: ", ", ".join(unc.slice(0, 16)))
	quit(0)
