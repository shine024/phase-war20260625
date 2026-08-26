extends Node
## 余烬要塞 P1.5 截图驱动：预置混合房间状态后抓一帧基地全景。
## 运行（带窗口，短暂闪现）：godot --path . res://tests/bunker_screenshot_driver.tscn
## 输出：user://bunker_p15_screenshot.png

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")

func _ready() -> void:
	# 预置状态：部分房间可用（暖光+贴图全彩），部分修复中，反应堆上线
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.debug_grant_resources()
	mgr.debug_grant_resources()
	for rid in ["war_room", "mess_hall", "reactor", "depot"]:
		if mgr.get_room_state(rid) == BunkerRoomDefs.STATE_LOCKED:
			mgr.start_repair(rid)
	# war_room/mess_hall(1场) 完成；reactor(3场)+depot(1场) 完成后再让 archive 进修复中
	mgr.advance_after_battle(true)   # war_room ✓ mess_hall ✓
	mgr.advance_after_battle(true)   # reactor 1/3
	mgr.advance_after_battle(true)   # reactor 2/3
	mgr.advance_after_battle(true)   # reactor 3/3 ✓ depot ✓
	if mgr.get_room_state("archive") == BunkerRoomDefs.STATE_LOCKED:
		mgr.start_repair("archive")
	mgr.advance_after_battle(true)   # archive 1/1 → ACTIVE…（battles=1，直接完成）

	var inst = load("res://scenes/bunker/bunker_main.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout

	# P3 复核：预置 11 碎片 → 打开纪念墙抓帧（灯阵点亮效果）
	for mid in ["enemy_master_001", "enemy_master_002", "enemy_master_003",
			"enemy_master_004", "enemy_master_005", "enemy_master_006",
			"enemy_master_007", "enemy_master_008", "enemy_master_009",
			"enemy_master_010", "enemy_master_012"]:
		mgr.record_hero_fragment(mid)
	inst._open_embedded_panel("memorial")
	await get_tree().create_timer(0.8).timeout

	var img := get_viewport().get_texture().get_image()
	var path := "user://bunker_p15_screenshot.png"
	img.save_png(path)
	print("screenshot saved: ", path)
	# 打印绝对路径便于查找
	print("abs: ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)
