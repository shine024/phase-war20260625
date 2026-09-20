extends Control
## v6.20 教程聚光端到端链冒烟（场景模式，autoload 在场）：
## 实例化 truck_base → 手动挂教程步 2 overlay → 断言聚光圈住卡牌墙热区 →
## 模拟点真热区（pressed）→ 步进 3 + close-wait 挂起 + 卡仓面板开 →
## ESC 关面板 → 步 3 overlay 重现 + 聚光重现（v6.20 修的基地 close-wait 断链回归锁）。
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_v620_flow_smoke.tscn

var _fails: Array = []

func _check(cond: bool, tag: String) -> void:
	if not cond:
		_fails.append(tag)
	print("[V620F] ", ("PASS " if cond else "FAIL "), tag)

func _ready() -> void:
	var tpm := get_node_or_null("/root/TutorialProgressionManager")
	if tpm == null:
		printerr("[V620F] FAIL TutorialProgressionManager 缺失")
		get_tree().quit(1)
		return
	# 教程态钉在步 2（CARD_COLLECTION），链未暂停、无挂起面
	tpm.set("current_step", 2)
	tpm.set("chain_paused", false)
	tpm.set("pending_close_surface", "")

	var truck: Control = (load("res://scenes/bunker/truck_base.tscn") as PackedScene).instantiate()
	add_child(truck)
	for i in 4:   # 等布局帧（热区 rect/抽屉立形都 deferred）
		await get_tree().process_frame

	# 1) 手动挂教学覆盖层（镜像 overlay_requested 链的落点）
	truck._show_tutorial_overlay_local()
	await get_tree().process_frame   # 聚光挖孔在首个 _process 计算，同帧读必空
	await get_tree().process_frame
	var ov: Control = truck.get_node_or_null("TutorialOverlay")
	_check(ov != null, "步2 overlay 挂载")

	# 2) 聚光层在场，且挖孔命中卡牌墙热区
	var spot: Control = ov.get_node_or_null("TutorialSpotlight") if ov != null else null
	var btn: Button = truck.get_hotspot_button_for_key("backpack") if truck.has_method("get_hotspot_button_for_key") else null
	_check(btn != null, "卡牌墙热区按钮可查（get_hotspot_button_for_key）")
	if spot != null and btn != null:
		var hole: Rect2 = spot.get("_hole")
		_check(hole.intersects(btn.get_global_rect()), "聚光挖孔命中热区 rect")
	else:
		_check(false, "聚光层挂载（spot=%s btn=%s）" % [spot != null, btn != null])

	# 3) 模拟点真热区：面板开 + 步进 3 + close-wait 挂起 + overlay 收起
	if btn != null:
		btn.pressed.emit()
		await get_tree().process_frame
		_check(int(tpm.get("current_step")) == 3, "点真热区推进到步3（PHASE_INSTRUMENT）")
		_check(String(tpm.get("pending_close_surface")) == "backpack", "close-wait 挂起面=backpack")
		_check(ov == null or not is_instance_valid(ov) or ov.is_queued_for_deletion(), "步2 overlay 已收起")
		var wr: Dictionary = truck.get("_embed_wrappers")
		var bp_open: bool = wr.has("backpack") and wr["backpack"]["wrapper"].visible
		_check(bp_open, "卡仓面板经真热区打开")

	# 4) ESC 关面板 → 通知续链 → 步 3 overlay + 聚光重现（基地 close-wait 断链回归锁）
	if truck._close_top_embed_panel():
		await get_tree().process_frame
		var ov3: Control = truck.get_node_or_null("TutorialOverlay")
		_check(ov3 != null and not ov3.is_queued_for_deletion(), "关面板后步3 overlay 续链重现")
		if ov3 != null:
			_check(ov3.get_node_or_null("TutorialSpotlight") != null, "步3 聚光重现")
		_check(String(tpm.get("pending_close_surface")) == "", "挂起态已清空")
	else:
		_check(false, "ESC 关面板路径可达")

	for c in _fails:
		printerr("[V620F][FAIL] " + c)
	print("V620_FLOW_%s x%d" % ["OK" if _fails.is_empty() else "FAIL", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)
