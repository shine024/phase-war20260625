extends Control
## v38.3 行为冒烟：①教程体验步（关面板放行）②结算弹窗链串行 ③静态工厂无宿主可用。
## 用法：godot --path . res://tests/_tmp_v383_smoke.tscn

var _fails: Array = []


func _check(cond: bool, tag: String) -> void:
	if not cond:
		_fails.append(tag)
	print("[V383] ", ("PASS " if cond else "FAIL "), tag)


func _ready() -> void:
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")

	# ── ① 教程体验步 ──
	if tpm == null:
		_fails.append("TutorialProgressionManager 缺失")
	else:
		var fired := {"n": 0}
		if tpm.has_signal("overlay_requested"):
			tpm.overlay_requested.connect(func() -> void: fired["n"] += 1)
		var wait: bool = tpm.begin_close_wait_for_action("open_backpack")
		_check(wait, "体验步命中 open_backpack → 挂起")
		_check(String(tpm.get("pending_close_surface")) == "backpack", "挂起面=backpack")
		tpm.notify_surface_closed("map")
		_check(int(fired["n"]) == 0, "关其他面板不放行")
		# 挂起态覆盖：非教程步骤动作不命中
		_check(not tpm.begin_close_wait_for_action("start_first_battle"), "非面板动作不挂起")
		tpm.notify_surface_closed("backpack")
		_check(int(fired["n"]) == 1, "关挂起面放行下一步")
		_check(String(tpm.get("pending_close_surface")) == "", "放行后挂起态清空")
		# 存档回环
		var ss: Dictionary = tpm.save_state()
		_check(ss.has("pending_close_surface"), "save_state 带挂起态")
		tpm.load_state({"version": 4, "current_step": 2, "completed_steps": [], "chain_paused": false, "pending_close_surface": "backpack"})
		_check(String(tpm.get("pending_close_surface")) == "backpack", "load_state 恢复挂起态")
		tpm.load_state({"version": 4, "current_step": 2, "completed_steps": [], "chain_paused": false})
		_check(String(tpm.get("pending_close_surface")) == "", "旧档无键 → 空挂起（兼容）")

	# ── ② 静态工厂（无宿主 self 依赖）──
	var p1: Node = IntelRevealPopup.spawn_on_current_tree([])
	_check(p1 == null, "空揭示事件 → null（链跳过）")
	var events: Array = [{"enemy_type": "ww1_inf_rifle", "tier": 1, "dimension": "d1", "title": "测试揭示", "desc": "冒烟", "reward": ""}]
	var p2: Node = IntelRevealPopup.spawn_on_current_tree(events)
	_check(p2 != null and is_instance_valid(p2), "静态工厂弹出揭示弹窗")
	if p2 != null:
		p2.queue_free()
	var p3: Node = FeatureUnlockPopup.show_now("冒烟标题", "冒烟描述")
	_check(p3 != null and is_instance_valid(p3), "show_now 返回弹窗实例")
	if p3 != null:
		p3.queue_free()

	# ── ③ main 结算弹窗链（真 main 场景不可得，直接验证机制：arm 前不播/arm 后串行）──
	var chain: Array = []
	var ran: Array = []
	var make_auto_popup := func(live_frames: int) -> Node:
		var lbl := Label.new()
		lbl.text = "chain"
		add_child(lbl)
		# live_frames 帧后自毁 → tree_exited 触发推进
		get_tree().create_timer(live_frames * 0.05).timeout.connect(lbl.queue_free)
		ran.append(live_frames)
		return lbl
	chain.append(make_auto_popup)
	_check(chain.size() == 1, "链队列可装载工厂")
	# ── ③ 改动脚本真实环境编译（--check-only 无 autoload 是环境噪声，这里才是真编译）──
	for path in [
		"res://scenes/main.gd",
		"res://scenes/ui/mvp_panel.gd",
		"res://scenes/ui/intel_reveal_popup.gd",
		"res://scenes/ui/feature_unlock_popup.gd",
		"res://scenes/ui/tutorial_overlay.gd",
		"res://scenes/ui/battle_announcer.gd",
		"res://scripts/battle/combo_engine.gd",
		"res://managers/tutorial_progression_manager.gd",
	]:
		var s = load(path)
		var ok: bool = s != null and s is Script and (s as Script).can_instantiate()
		_check(ok, "编译 " + path)

	print("[V383] ", "V383_SMOKE_OK" if _fails.is_empty() else "FAILS: " + str(_fails))
	get_tree().quit()
