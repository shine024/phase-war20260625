extends Node
## v3 真实游戏抓帧：初始态（3 亮 11 涂黑）+ 全点亮态
## 运行（带窗口，短暂闪现）：godot --rendering-driver opengl3 --path . res://tests/_tmp_bunker_v3_shots_driver.tscn

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")

func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.reset_to_defaults()

	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")

	# 帧 1：初始态（reset 后 3 亮 11 涂黑，光点在入口大厅）
	var inst1: Control = packed.instantiate()
	add_child(inst1)
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	_capture("user://bunker_v3_initial.png")
	inst1.queue_free()
	await get_tree().process_frame

	# 帧 2：全点亮（全部 13 间可用 + 终局恒锁）
	for mid in ["enemy_master_001", "enemy_master_002", "enemy_master_003",
			"enemy_master_004", "enemy_master_005", "enemy_master_006",
			"enemy_master_008", "enemy_master_009", "enemy_master_010", "enemy_master_011"]:
		mgr.record_hero_fragment(mid)   # 荣誉室碎片门槛
	for r in BunkerRoomDefs.get_all_rooms():
		if r["id"] == "observatory":
			continue
		_force_active(mgr, r["id"])
	var inst2: Control = packed.instantiate()
	add_child(inst2)
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	_capture("user://bunker_v3_alllit.png")
	inst2.queue_free()
	get_tree().quit(0)

func _force_active(mgr: Node, rid: String) -> void:
	# 无直设接口时走正规链：给资源开工 + 战斗推进（battles 已知 ≤3）
	mgr.debug_grant_resources()
	mgr.start_repair(rid)
	for i in 3:
		if mgr.get_room_state(rid) == BunkerRoomDefs.STATE_ACTIVE:
			return
		mgr.advance_after_battle(true)

func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved: ", path, " abs: ", ProjectSettings.globalize_path(path))
	if OS.get_cmdline_user_args().has("--diag") or true:
		print("[diag] window=", DisplayServer.window_get_size(),
			" visible_rect=", get_viewport().get_visible_rect().size,
			" tex=", img.get_size(),
			" cs_factor=", get_viewport().content_scale_factor,
			" cs_size=", get_viewport().content_scale_size,
			" stretch=", ProjectSettings.get_setting("display/window/stretch/mode", "(unset)"))
		var ov: Control = get_children().back().get("_room_nodes").get("entry_hall") if get_children().back().get("_room_nodes") else null
		if ov:
			print("[diag] entry_hall overlay global_rect=", ov.get_global_rect(), " pos=", ov.position)
