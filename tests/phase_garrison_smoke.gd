extends SceneTree
## v7.x 相位师 Boss 关标记 + 第49关驻守化 验证 smoke test
## 验证项：
##   1. 驻守表有 20 个关卡（含第49关）
##   2. 第49关 → enemy_master_014
##   3. enemy_master_014 能被 get_master_by_id 查到（完整数据）
##   4. is_garrison_level 对驻守关返回 true / 非驻守关 false
##   5. 驻守关按等级递增（Lv 梯度合理）
##   6. 第49关的相位师等级介于45关(Lv18)和50关(Lv20)之间（梯度合理）

const PhaseMasterGarrison = preload("res://data/phase_master_garrison.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")

func _init() -> void:
	var pass_count: int = 0
	var fail_count: int = 0

	# ── 1. 驻守表关卡数 = 20 ──
	var all_levels: Array = PhaseMasterGarrison.get_all_garrison_levels()
	if all_levels.size() == 20:
		print("[PASS] 1. 驻守表关卡数 = 20 (实际 %d)" % all_levels.size())
		pass_count += 1
	else:
		print("[FAIL] 1. 驻守表关卡数应为 20，实际 %d" % all_levels.size())
		fail_count += 1

	# ── 2. 第49关 → enemy_master_014 ──
	var m49: String = PhaseMasterGarrison.get_garrison_master_id(49)
	if m49 == "enemy_master_014":
		print("[PASS] 2. 第49关 → enemy_master_014")
		pass_count += 1
	else:
		print("[FAIL] 2. 第49关应为 enemy_master_014，实际 %s" % m49)
		fail_count += 1

	# ── 3. enemy_master_014 能查到完整数据 ──
	var master_014: Dictionary = EnemyPhaseMasters.get_master_by_id("enemy_master_014")
	if not master_014.is_empty() and String(master_014.get("name", "")).length() > 0:
		print("[PASS] 3. enemy_master_014 数据完整 (name=%s, Lv=%d)" % [master_014.get("name"), master_014.get("level")])
		pass_count += 1
	else:
		print("[FAIL] 3. enemy_master_014 查不到或数据为空")
		fail_count += 1

	# ── 4. is_garrison_level 正确性 ──
	if PhaseMasterGarrison.is_garrison_level(49) and not PhaseMasterGarrison.is_garrison_level(48) and not PhaseMasterGarrison.is_garrison_level(1):
		print("[PASS] 4. is_garrison_level: 49关=true, 48关=false, 1关=false")
		pass_count += 1
	else:
		print("[FAIL] 4. is_garrison_level 判定错误")
		fail_count += 1

	# ── 5. 驻守关等级总体递增（允许跨时代回落 ≤2 级）──
	var levels_ok: bool = true
	var prev_lv: int = 0
	for lv in all_levels:
		var mid: String = PhaseMasterGarrison.get_garrison_master_id(lv)
		var md: Dictionary = EnemyPhaseMasters.get_master_by_id(mid)
		var master_lv: int = int(md.get("level", 0))
		# 跨时代允许回落（如关40→45 从 WW2 Boss 到 COLD 首关），回落≤2视为正常
		if prev_lv > 0 and master_lv < prev_lv - 2:
			levels_ok = false
			print("  [WARN] 关卡%d相位师Lv%d 回落过多(< 前关Lv%d-2)" % [lv, master_lv, prev_lv])
		prev_lv = master_lv
	if levels_ok:
		print("[PASS] 5. 驻守关等级总体递增 (Lv%d→Lv%d, 允许跨时代回落≤2)" % [
			int(EnemyPhaseMasters.get_master_by_id(PhaseMasterGarrison.get_garrison_master_id(all_levels[0])).get("level", 0)),
			int(EnemyPhaseMasters.get_master_by_id(PhaseMasterGarrison.get_garrison_master_id(all_levels[-1])).get("level", 0))])
		pass_count += 1
	else:
		print("[FAIL] 5. 驻守关等级回落过多")
		fail_count += 1

	# ── 6. 第49关等级梯度合理 (45关Lv18 < 49关 < 50关Lv20) ──
	var lv45: int = int(EnemyPhaseMasters.get_master_by_id(PhaseMasterGarrison.get_garrison_master_id(45)).get("level", 0))
	var lv49: int = int(EnemyPhaseMasters.get_master_by_id(PhaseMasterGarrison.get_garrison_master_id(49)).get("level", 0))
	var lv50: int = int(EnemyPhaseMasters.get_master_by_id(PhaseMasterGarrison.get_garrison_master_id(50)).get("level", 0))
	if lv45 <= lv49 and lv49 <= lv50:
		print("[PASS] 6. 梯度合理: 45关Lv%d ≤ 49关Lv%d ≤ 50关Lv%d" % [lv45, lv49, lv50])
		pass_count += 1
	else:
		print("[FAIL] 6. 梯度不合理: 45关Lv%d, 49关Lv%d, 50关Lv%d" % [lv45, lv49, lv50])
		fail_count += 1

	# ── 7. world_map 用的 Boss 关完整列表（打印供人工核对）──
	print("\n=== 全部20个驻守Boss关 ===")
	for lv in all_levels:
		var mid: String = PhaseMasterGarrison.get_garrison_master_id(lv)
		var md: Dictionary = EnemyPhaseMasters.get_master_by_id(mid)
		print("  关%3d: %-30s Lv.%d" % [lv, String(md.get("name", "?")), int(md.get("level", 0))])

	print("\n==========")
	print("结果: %d PASS / %d FAIL" % [pass_count, fail_count])
	if fail_count > 0:
		print("!!! SMOKE TEST FAILED !!!")
	quit(1 if fail_count > 0 else 0)
