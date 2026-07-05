"""针对性检查：旧名图/fort图/omega 是否被回退链命中"""
extends SceneTree

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")

func _init():
	# 检查这些"疑似孤儿"的旧名图是否被 resolve_card_icon_texture_path 命中
	# 堡垒新 id（如 ww1_fort_pillbox）走 resolve 会落到哪？
	var test_ids: Array = [
		"ww1_fort_pillbox", "ww1_fort_artillery", "ww2_fort_bunker", "ww2_fort_flak",
		"cold_fort_missile", "cold_fort_radar", "mod_fort_citadel", "mod_fort_phalanx",
		"fut_fort_ion", "fut_fort_shield", "fut_arm_omega"
	]
	print("=== 堡垒/omega 新 id 取图路径 ===")
	for aid in test_ids:
		var cfg = EnemyArchetypes.get_config(aid)
		var p = EnemyArchetypes.resolve_card_icon_texture_path(aid, cfg, aid)
		print("  %-22s -> %s" % [aid, p])
	quit()
