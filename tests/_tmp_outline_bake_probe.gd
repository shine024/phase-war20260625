extends SceneTree
## v6.15.1 探针：is_outline_baked 三分支验证（sheet 单位 / boss 逐帧目录 / 未命中 id）

func _init() -> void:
	var ufa := preload("res://scripts/battle/unit_frame_anim.gd")
	var fails := 0
	# ① sheet 单位（烘焙过）→ true
	var r1: bool = ufa.is_outline_baked("cold_ak")
	print("sheet unit cold_ak -> ", r1, " (expect true)")
	if not r1: fails += 1
	# ② boss 逐帧目录（--bake-boss-frames 标记）→ true
	var r2: bool = ufa.is_outline_baked("cold_boss_mig")
	var r3: bool = ufa.is_outline_baked("fut_boss_nexus")
	print("boss cold_boss_mig -> ", r2, " (expect true)")
	print("boss fut_boss_nexus -> ", r3, " (expect true)")
	if not r2: fails += 1
	if not r3: fails += 1
	# ③ 未命中 id（无任何目录）→ false，继续走 shader
	var r4: bool = ufa.is_outline_baked("no_such_unit_xyz")
	print("miss no_such_unit_xyz -> ", r4, " (expect false)")
	if r4: fails += 1
	# ④ 缴获 boss 卡（vis_player 卡图回退，无帧资产）→ false，静态卡图必须吃 shader
	var r5: bool = ufa.is_outline_baked("captured_cold_boss_mig")
	print("captured boss -> ", r5, " (expect false)")
	if r5: fails += 1
	# ⑤ 空串 → false
	var r6: bool = ufa.is_outline_baked("")
	print("empty -> ", r6, " (expect false)")
	if r6: fails += 1
	if fails == 0:
		print("OUTLINE_BAKE_PROBE: ALL PASS")
	else:
		print("OUTLINE_BAKE_PROBE: FAIL x%d" % fails)
	quit(1 if fails > 0 else 0)
