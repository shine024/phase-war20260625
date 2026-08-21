extends SceneTree
## v9.x 直射跨行减伤规则验证（--script 模式，秒级）
## 断言：同行全额 / 跨行直射×0.70 / 跨行曲射空射全额 / 无 meta 目标兜底同行

const Layout = preload("res://scripts/card_grid_battle_layout.gd")
const GC = preload("res://resources/game_constants.gd")

func _init() -> void:
	var fails: Array = []
	var shooter := Node2D.new()
	var same_row_t := Node2D.new()
	var cross_row_t := Node2D.new()
	var no_meta_t := Node2D.new()
	shooter.set_meta("card_grid_slot", 0)            # 我方 row0
	same_row_t.set_meta("card_grid_enemy_slot", 1)   # 敌方 row0 → 同行
	cross_row_t.set_meta("card_grid_enemy_slot", 3)  # 敌方 row1 → 跨行

	# 1) 同行直射 → 1.0
	if absf(Layout.cross_row_direct_multiplier(shooter, same_row_t, 0) - 1.0) > 0.0001:
		fails.append("同行直射应 1.0")

	# 2) 跨行直射（0 直射 / 4 手枪 / 6 狙击）→ 0.70
	for wt in [0, 4, 6]:
		var v: float = Layout.cross_row_direct_multiplier(shooter, cross_row_t, wt)
		if absf(v - 0.70) > 0.0001:
			fails.append("跨行直射 wt=%d 应 0.70 实得 %s" % [wt, str(v)])

	# 3) 跨行曲射/空射（1 曲射 / 2 空射 / 3 ROCKET·SUPPORT / 7 FLAK / 9 MISSILE）→ 1.0
	for wt in [1, 2, 3, 7, 9]:
		var v2: float = Layout.cross_row_direct_multiplier(shooter, cross_row_t, wt)
		if absf(v2 - 1.0) > 0.0001:
			fails.append("跨行曲射/空射 wt=%d 应 1.0 实得 %s" % [wt, str(v2)])

	# 4) 无 meta 目标（相位场等）→ units_in_same_row 兜底同行 → 1.0
	if absf(Layout.cross_row_direct_multiplier(shooter, no_meta_t, 0) - 1.0) > 0.0001:
		fails.append("无 meta 目标应 1.0（兜底同行）")

	# 5) 判定基线：GC.is_indirect_weapon_type 与假设一致
	if not GC.is_indirect_weapon_type(1) or GC.is_indirect_weapon_type(0):
		fails.append("GC.is_indirect_weapon_type 基线异常")

	for n in [shooter, same_row_t, cross_row_t, no_meta_t]:
		n.free()

	if fails.is_empty():
		print("[PASS] 跨行减伤规则 11 项断言全部通过（同行全额/跨行直射×0.70/曲射空射全额/无meta兜底）")
	else:
		for f in fails:
			push_error("[FAIL] " + f)
		print("[FAIL] %d 项未通过" % fails.size())
	quit(0)
