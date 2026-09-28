extends SceneTree
## v6.32.3 冒烟：掉落 id 解析救援 + 相位师平台静默跳过
## （--script 直跑，不依赖 autoload）
## 验证：
##   A. enemy_archetypes.json drops 全部 12 id：原解析必 miss（enemy_only），
##      EnemyCardModMap 映射目标玩家卡全部可解析（修复后全链路可发卡）
##   B. 四势力 8 个 *_basic 缴获平台：get_war_platform 命中 → grant 链会静默跳过不刷警告
## 注：card_drop_grants.gd（ManagerLazyLoader autoload 噪音）与 auto_deploy_controller.gd
##（--script 模式 load 卡死）不在此处 load，语法走编辑器/GdUnit4/--check-only 侧验证。

func _init() -> void:
	var fails: Array[String] = []

	# ── A) drops 12 id 映射链 ──
	var DC = load("res://data/default_cards.gd")
	var ECM = load("res://data/enemy_card_mod_map.gd")
	var drop_ids: Array[String] = [
		"drop_smg_mk2", "fut_arm_titan_mk2", "drop_phase_lance", "fut_inf_storm_rider",
		"fut_air_heavy_carrier", "drop_railgun", "fut_air_regen_frame", "drop_mega_beam_cannon",
		"drop_thunder_field", "mod_arm_abrams_mk2", "drop_overclock_matrix", "drop_mega_particle_cannon",
	]
	var mapped_ok: int = 0
	for id in drop_ids:
		if DC.get_card_by_id(id) != null:
			fails.append("预期 %s 原解析 miss（enemy_only），却命中了——前置认知失效，需复核" % id)
			continue
		var pid: String = ECM.get_player_card_id(id)
		if pid.is_empty():
			fails.append("drops id 无映射: %s" % id)
			continue
		if DC.get_card_by_id(pid) == null:
			fails.append("映射目标不可解析: %s -> %s" % [id, pid])
			continue
		mapped_ok += 1
	print("映射链 OK: %d/%d" % [mapped_ok, drop_ids.size()])

	# ── B) 相位师 *_basic 平台静默跳过判定 ──
	var EPE = load("res://data/enemy_phase_equipment.gd")
	var platform_ids: Array[String] = [
		"steel_fortress_basic", "steel_titan_basic",
		"flame_raider_basic", "flame_siege_basic",
		"thunter_striker_basic", "thunter_sniper_basic",
		"void_stealth_basic", "void_mage_basic",
	]
	var plat_ok: int = 0
	for pid2 in platform_ids:
		if (EPE.get_war_platform(pid2) as Dictionary).is_empty():
			fails.append("相位师平台未被 WAR_PLATFORMS 收录: %s" % pid2)
			continue
		plat_ok += 1
	print("平台静默判定 OK: %d/%d" % [plat_ok, platform_ids.size()])

	# ── 结果 ──
	if fails.is_empty():
		print("V6323_DROP_SMOKE_OK")
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("V6323_DROP_SMOKE_FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
