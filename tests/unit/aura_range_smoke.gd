# v21 P0 光环范围化 smoke test（不依赖 GdUnit，extends SceneTree 直跑）
# 验证 data/aura_data.gd 范围判定核心 + 两链插入点的源码级接线：
#   1) get_aura_params 全 6 类带 range_cells（战术=1，指挥/维修=-1 全场）
#   2) aura_range_for 星级扩列（★1=1 → ★5=2 → ★9=3；全场类别不受星级影响）
#   3) slot_grid_coords 行主序坐标
#   4) is_in_aura_range 几何（切比雪夫距离）+ 全场哨兵 + 未知槽位回退 + 总开关短路
#   5) get_mod_aura_range 默认/覆盖
#   6) unit_slot_index 双 meta 读取
#   7) 源码级接线断言（战术光环已切换范围函数；撤销仍全量扫描；延迟广播已接）
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/unit/aura_range_smoke.gd
extends SceneTree

const AuraData = preload("res://data/aura_data.gd")
const GameConfig = preload("res://resources/game_config.gd")


func _initialize() -> void:
	# v18 教训：GDScript lambda 按值捕获局部变量，用数组持有者传导失败
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	var ok := func(msg: String) -> void:
		print("  [PASS] " + msg)

	print("═══════════════════════════════════════════════════════════")
	print("  v21 P0 光环范围化验证（aura_data 核心 + 两链接线）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. get_aura_params range_cells 完整性 ══════════
	print("\n=== 1. 全 6 类光环 range_cells 字段 ===")
	for cat in range(6):
		var p: Dictionary = AuraData.get_aura_params(cat, 1)
		if not p.has("range_cells"):
			fail.call("类别 %d 缺 range_cells 字段" % cat)
		elif not p.has("is_global"):
			fail.call("类别 %d 缺 is_global 字段（结构被误改）" % cat)
	if AuraData.get_aura_params(5, 1)["range_cells"] == AuraData.AURA_RANGE_GLOBAL:
		ok.call("COMMAND_GLOBAL = 全场哨兵 -1")
	else:
		fail.call("COMMAND_GLOBAL 应为全场 -1")
	if AuraData.get_aura_params(1, 1)["range_cells"] == AuraData.AURA_RANGE_GLOBAL:
		ok.call("CARRIER_REPAIR = 全场哨兵 -1")
	else:
		fail.call("CARRIER_REPAIR 应为全场 -1")

	# ══════════ 2. 星级扩列 ══════════
	print("\n=== 2. aura_range_for 星级扩列（战术类别 MEDIC=0）===")
	if AuraData.aura_range_for(0, 1) == 1:
		ok.call("★1 → 1 格")
	else:
		fail.call("★1 应为 1 格，实得 %d" % AuraData.aura_range_for(0, 1))
	if AuraData.aura_range_for(0, 5) == 2:
		ok.call("★5 → 2 格（全带）")
	else:
		fail.call("★5 应为 2 格，实得 %d" % AuraData.aura_range_for(0, 5))
	if AuraData.aura_range_for(0, 9) == 3:
		ok.call("★9 → 3 格")
	else:
		fail.call("★9 应为 3 格，实得 %d" % AuraData.aura_range_for(0, 9))
	if AuraData.aura_range_for(0, 10) == 3:
		ok.call("★10 → 3 格（封顶）")
	else:
		fail.call("★10 应为 3 格")
	if AuraData.aura_range_for(5, 10) == AuraData.AURA_RANGE_GLOBAL:
		ok.call("全场类别不受星级影响")
	else:
		fail.call("COMMAND ★10 不应被星级改动")

	# ══════════ 3. 槽位坐标 ══════════
	print("\n=== 3. slot_grid_coords（3×3 行主序）===")
	var coord_cases := [[0, Vector2i(0, 0)], [4, Vector2i(1, 1)], [8, Vector2i(2, 2)], [5, Vector2i(2, 1)]]
	for c in coord_cases:
		var got: Vector2i = AuraData.slot_grid_coords(int(c[0]))
		if got == c[1]:
			ok.call("slot %d → %s" % [c[0], str(got)])
		else:
			fail.call("slot %d 应为 %s，实得 %s" % [c[0], str(c[1]), str(got)])
	if AuraData.slot_grid_coords(-1) == Vector2i(-9999, -9999):
		ok.call("slot -1 → 哨兵坐标")
	else:
		fail.call("slot -1 应返回哨兵坐标")

	# ══════════ 4. is_in_aura_range 几何 ══════════
	print("\n=== 4. is_in_aura_range（源 slot0=(0,0)）===")
	var geo := [
		[1, 1, true, "slot1=(1,0) 距离1"],
		[3, 1, true, "slot3=(0,1) 距离1"],
		[4, 1, true, "slot4=(1,1) 对角距离1"],
		[2, 1, false, "slot2=(2,0) 距离2 > 1"],
		[8, 1, false, "slot8=(2,2) 距离2 > 1"],
		[8, 2, true, "slot8 距离2 ≤ 2"],
		[8, -1, true, "全场哨兵恒真"],
		[-1, 1, true, "源槽位未知回退全场"],
	]
	for g in geo:
		var got_b: bool = AuraData.is_in_aura_range(0, int(g[0]), int(g[1]))
		if got_b == bool(g[2]):
			ok.call(String(g[3]) + " → " + str(got_b))
		else:
			fail.call(String(g[3]) + " 期望 " + str(g[2]) + " 实得 " + str(got_b))

	# 总开关短路
	print("\n=== 5. 回滚开关 aura_range_enabled ===")
	var cfg: GameConfig = GameConfig.get_default()
	var saved: bool = cfg.aura_range_enabled
	cfg.aura_range_enabled = false
	if AuraData.is_in_aura_range(0, 8, 1):
		ok.call("开关关闭 → 判定短路全场")
	else:
		fail.call("开关关闭应短路 true")
	if not AuraData.is_aura_ranging_enabled():
		ok.call("is_aura_ranging_enabled 同步读开关")
	else:
		fail.call("is_aura_ranging_enabled 应为 false")
	cfg.aura_range_enabled = saved
	if not AuraData.is_in_aura_range(0, 8, 1):
		ok.call("开关恢复 → 范围判定恢复")
	else:
		fail.call("开关恢复后 (0→8, r1) 应为 false")

	# ══════════ 6. 改造光环范围 ══════════
	print("\n=== 6. get_mod_aura_range ===")
	if AuraData.get_mod_aura_range({}) == 1:
		ok.call("空 summary 默认 1 格")
	else:
		fail.call("空 summary 应默认 1 格")
	if AuraData.get_mod_aura_range({"range_override": -1}) == -1:
		ok.call("range_override -1 = 全场")
	else:
		fail.call("range_override -1 应为全场")
	if AuraData.get_mod_aura_range({"crit_chance": {"op": "add", "raw": 0.1}}) == 1:
		ok.call("无 override 的普通 summary 默认 1 格")
	else:
		fail.call("普通 summary 应默认 1 格")

	# ══════════ 7. unit_slot_index 双 meta ══════════
	print("\n=== 7. unit_slot_index ===")
	var n1 := Node2D.new()
	n1.set_meta("card_grid_slot", 5)
	if AuraData.unit_slot_index(n1) == 5:
		ok.call("card_grid_slot 读取")
	else:
		fail.call("card_grid_slot 应为 5")
	var n2 := Node2D.new()
	n2.set_meta("card_grid_enemy_slot", 3)
	if AuraData.unit_slot_index(n2) == 3:
		ok.call("card_grid_enemy_slot 读取")
	else:
		fail.call("card_grid_enemy_slot 应为 3")
	var n3 := Node2D.new()
	if AuraData.unit_slot_index(n3) == -1:
		ok.call("无 meta → -1")
	else:
		fail.call("无 meta 应为 -1")
	n1.free()
	n2.free()
	n3.free()

	# ══════════ 8. 源码级接线断言 ══════════
	print("\n=== 8. 两链插入点接线（源码级）===")
	var _src := func(path: String) -> String:
		var f := FileAccess.open(path, FileAccess.READ)
		return f.get_as_text() if f != null else ""
	var cam_src: String = _src.call("res://managers/card_ability_manager.gd")
	if cam_src.contains("_get_allies_in_aura_range(unit, _get_aura_data().Category.MEDIC_HEAL"):
		ok.call("医疗 tick 已切换范围函数")
	else:
		fail.call("医疗 tick 未接入 _get_allies_in_aura_range")
	for key in ["Category.RADAR_RANGE, star, is_player", "Category.SCOUT_CRIT, star, is_player", "Category.FORTRESS_DEF, star, is_player"]:
		if cam_src.contains("_get_allies_in_aura_range(unit, _get_aura_data()." + key):
			ok.call("战术光环已切换: " + key.split(",")[0])
		else:
			fail.call("战术光环未接入范围函数: " + key)
	# 撤销仍全量扫描（remove_* 内保留 _get_nearby_allies）
	var remove_count := cam_src.count("_get_nearby_allies(unit, 300.0, is_player)")
	if remove_count >= 3:
		ok.call("撤销路径保留全量扫描（%d 处 remove_*）" % remove_count)
	else:
		fail.call("撤销路径 _get_nearby_allies 数量异常: %d" % remove_count)
	var am_src: String = _src.call("res://managers/aura_manager.gd")
	if am_src.contains("receive_auras_from_field_deferred"):
		ok.call("AuraManager 后入场补偿已帧末化")
	else:
		fail.call("AuraManager 缺 receive_auras_from_field_deferred")
	if am_src.contains("_apply_one_shot_aura_deferred"):
		ok.call("一次性光环已帧末应用")
	else:
		fail.call("一次性光环未延迟")
	var mah_src: String = _src.call("res://scripts/battle/mod_aura_handler.gd")
	if mah_src.contains("broadcast_and_receive_deferred") and mah_src.contains("range_override"):
		ok.call("ModAuraHandler 延迟广播 + range_override 就绪")
	else:
		fail.call("ModAuraHandler 接线缺失")
	var cu_src: String = _src.call("res://scenes/units/construct_unit.gd")
	if cu_src.contains("ModAuraHandler.broadcast_and_receive_deferred(self)"):
		ok.call("construct_unit.setup 已切延迟广播")
	else:
		fail.call("construct_unit.setup 仍为立即广播")
	var gc_src: String = _src.call("res://resources/game_config.gd")
	if gc_src.contains("aura_range_enabled"):
		ok.call("GameConfig 回滚开关就绪")
	else:
		fail.call("GameConfig 缺 aura_range_enabled")

	# ══════════ 收尾 ══════════
	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ✅ 全部通过")
	else:
		print("  ❌ 存在失败项（见 [FAIL]）")
	print("═══════════════════════════════════════════════════════════")
	quit(int(code[0]))
