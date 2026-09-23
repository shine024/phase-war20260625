extends SceneTree
## v28b 结算弹窗面材验收（临时）：offline + afk 两个弹窗逐个实拍。
## 用法：godot --rendering-driver opengl3 --path . --script tests/_tmp_settlement_dialogs_shot.gd

func _initialize() -> void:
	_run()

func _shot_one(panel: Node, tag: String) -> void:
	root.add_child(panel)
	for i in 30:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("res://.godot/agent_tools/t4_dialog_%s.png" % tag)
		print("[DlgShot] saved ", tag)
	panel.queue_free()
	for i in 5:
		await process_frame

func _run() -> void:
	await process_frame
	await process_frame
	var offline = load("res://scenes/ui/offline_reward_dialog.gd")
	var fake_offline: Dictionary = {
		"capped_sec": 7200, "battles": 14, "level": 12,
		"currencies": {"energy_block": 180, "nano_materials": 640},
		"drop_preview_count": 9, "phase_field_xp": 320,
		"levels_unlocked": [13, 14],
	}
	await _shot_one(offline.create(root, fake_offline), "offline")
	var afk = load("res://scenes/ui/afk_settlement_dialog.gd")
	var fake_afk: Dictionary = {
		"failed": false, "wins": 7, "losses": 2,
		"rewards": {"energy_block": 96, "nano_materials": 410},
	}
	await _shot_one(afk.create(root, fake_afk), "afk")
	quit(0)
