extends Node
## 视觉校验驱动 v21
## 拉满各种状态后抓帧，辅助排查：布局变形 / 尺寸越界 / 贴图错位 / 面板遮挡
## 运行：godot --path . res://tests/bunker_visual_audit_driver.tscn

func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr = ManagerLazyLoader.get_manager("bunker")
	mgr.debug_grant_resources()
	mgr.debug_grant_resources()
	for rid in ["war_room", "mess_hall", "reactor", "depot", "honor_hall"]:
		if mgr.get_room_state(rid) == 0:
			mgr.start_repair(rid)
	mgr.advance_after_battle(true)   # war + mess
	mgr.advance_after_battle(true)   # reactor 1/3 + depot 1/1
	mgr.advance_after_battle(true)   # reactor 2/3
	mgr.advance_after_battle(true)   # reactor 3/3
	mgr.record_hero_fragment("enemy_master_001")
	mgr.record_hero_fragment("enemy_master_002")
	# 先打第一帧
	var inst = load("res://scenes/bunker/bunker_main.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var screens := []

	# ── 截图 0：基地全景（含 7 张嵌入面板各打开一次，确认无越界/遮挡）──
	await _screenshot(screens, "00_overview")

	# ── 截图 1：背包面板（宿舍打开）──
	await _open_and_shot(inst, "backpack", screens, "10_backpack")

	# ── 截图 2：改造面板（工坊打开）──
	await _open_and_shot(inst, "modification", screens, "20_modification")

	# ── 截图 3：商店面板（通讯室打开）──
	await _open_and_shot(inst, "store", screens, "30_store")

	# ── 截图 4：AFK 面板（食堂打开）──
	await _open_and_shot(inst, "afk", screens, "40_afk")

	# ── 截图 5：英雄档案（档案室）──
	await _open_and_shot(inst, "hero_archive", screens, "50_archive")

	# ── 截图 6：纪念墙（荣誉室，11 灯点亮）──
	await _open_and_shot(inst, "memorial", screens, "60_memorial")

	# ── 截图 7：情结算面板（模拟日结算显示）──
	var summary_ui = inst.get("_day_summary")
	if summary_ui:
		summary_ui.call("open", {"day": 7, "sanity_before": 30.0, "sanity_after": 50.0,
			"completed_today": ["war_room", "reactor"], "stage": 3})
	await get_tree().create_timer(0.5).timeout
	await _capture(inst, "70_day_summary")
	if summary_ui:
		summary_ui.call("close")
	await get_tree().process_frame

	_save_json(screens)
	get_tree().quit(0)

func _screenshot(dir: Array, label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	_write(img, label)
	dir.append({"label": label, "files": ["user://bunker_" + label + ".png"]})

func _open_and_shot(inst, panel_id: String, screens: Array, label: String) -> void:
	inst._open_embedded_panel(panel_id)
	await get_tree().create_timer(0.6).timeout
	await _capture(inst, label)
	# 关（如存在 closed 信号则触发）
	var w = inst._embed_wrappers.get(panel_id, {}).get("wrapper")
	if w:
		w.visible = false
	# 清 wrapper 让下次可重开
	inst._embed_wrappers.erase(panel_id)
	await get_tree().process_frame

func _capture(inst, label: String) -> void:
	await get_tree().create_timer(0.2).timeout
	var img := get_viewport().get_texture().get_image()
	_write(img, label)

func _write(img, label: String) -> void:
	var path := "user://bunker_%s.png" % label
	img.save_png(path)
	print("  [%s] %d×%d" % [label, img.get_width(), img.get_height()])
	# 同时写 manifest 单行追加
	var mf_path := "user://bunker_audit_manifest.json"
	if FileAccess.file_exists(mf_path):
		var f := FileAccess.open(mf_path, FileAccess.READ)
		var existing := f.get_as_text()
		f.close()
		# 追加到已有数组（简单拼接）
		var new_entry := "{\"label\":\"%s\",\"files\":[\"user://bunker_%s.png\"]}" % [label, label]
		var cleaned := existing.trim_suffix("]").trim_suffix(",")
		FileAccess.open(mf_path, FileAccess.WRITE).store_string(cleaned + "," + new_entry + "]")
	else:
		FileAccess.open(mf_path, FileAccess.WRITE).store_string(
			"[{\"label\":\"" + label + "\",\"files\":[\"user://bunker_" + label + ".png\"]}]")

func _save_json(screens: Array) -> void:
	var f := FileAccess.open("user://bunker_audit_manifest.json", FileAccess.WRITE)
	f.store_line(JSON.stringify(screens))
	f.close()
	print("manifest:", ProjectSettings.globalize_path("user://bunker_audit_manifest.json"))
