extends Node
## 验证 v22.1 修复后的"进入基地"路径：无档自动开新档 → 基地应有 starter 配置 + 兵棋室点亮

func _ready() -> void:
	await get_tree().process_frame
	var sm: Node = get_node("/root/SaveManager")
	var ir: Node = get_node("/root/InstanceRegistry")
	var pim: Node = get_node("/root/PhaseInstrumentManager")

	# 标题屏脚本可实例化（解析 _on_enter_bunker 改动无语法错）
	var title: PackedScene = load("res://scenes/title_screen.tscn")
	var t: Control = title.instantiate()
	add_child(t)
	await get_tree().process_frame
	print("[probe] title_screen 实例化 OK，进入基地按钮=", t.has_node("CenterContainer/MainVBox/ButtonsVBox/EnterBunkerButton"))
	t.queue_free()
	await get_tree().process_frame

	# 模拟修复后的按钮逻辑：无档 → start_new_game → 进基地
	if not sm.has_save_slot(sm.get_slot()):
		sm.start_new_game()
	else:
		print("[probe] 当前槽位已有存档——走读档分支（与修复后按钮一致）")
		sm.load_game()
	for i in 5:
		await get_tree().process_frame

	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	var bunker: Control = packed.instantiate()
	add_child(bunker)
	await get_tree().create_timer(0.5).timeout

	var errs := 0
	if _green(pim) != 3:
		print("[probe][FAIL] 绿槽应 3 卡，实际 ", _green(pim)); errs += 1
	if ir.get_all_instance_ids().size() < 3:
		print("[probe][FAIL] 实例应 ≥3，实际 ", ir.get_all_instance_ids().size()); errs += 1
	if pim.get_owned_runes().size() < 2:
		print("[probe][FAIL] 符文应 ≥2，实际 ", pim.get_owned_runes().size()); errs += 1
	if _mgr().get_room_state("war_room") != 2:
		print("[probe][FAIL] 兵棋室应 ACTIVE，实际 ", _mgr().get_room_state("war_room")); errs += 1
	if _mgr().get_room_state("phase_lab") != 2:
		print("[probe][FAIL] 相位实验室应 ACTIVE，实际 ", _mgr().get_room_state("phase_lab")); errs += 1
	if errs == 0:
		print("[probe] ALL PASS：绿槽3卡/实例3/符文2/兵棋室+相位实验室点亮 —— 进入基地入口状态完整")
	get_tree().quit(0)

func _green(pim: Node) -> int:
	var arr: Array = pim.get("instrument_slots").get("green", [])
	var n := 0
	for c in arr:
		if c is CardResource:
			n += 1
	return n

func _mgr() -> Node:
	ManagerLazyLoader.ensure_loaded("bunker")
	return ManagerLazyLoader.get_manager("bunker")
