extends Node
## 全 UI 动态态巡检（记录4 视觉体检补充）：真实路径逐一打开面板/状态 + 逐屏截图。
## 与 _tmp_ui_audit_probe（独立实例化几何检测）互补——那里看骨架，这里看内容态。
## 运行：godot --rendering-driver opengl3 --path . res://tests/_tmp_ui_states_probe.tscn
## ⚠️ 会触发 show_once/存档写盘——跑前备份 user://。

const SHOT_DIR := "res://.godot/agent_tools/ui_states/"

func _ready() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 720)
	win.content_scale_factor = 1.0
	win.position = Vector2i(60, 60)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	GameConfig.get_default().feature_gates_enabled = false
	var tpm := get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("current_step", 99)  # 出教程守卫
	_run.call_deferred()

func _run() -> void:
	await _settle(5)
	# ═══ A. main.tscn：16 个 overlay 逐个真实打开 ═══
	var main: Node = _mount("res://scenes/main.tscn")
	if main != null:
		await _settle(8)
		var overlays: Array = main._all_overlays()
		for entry in overlays:
			var ov: Control = entry.get("overlay")
			var key: String = String(entry.get("key", ""))
			if ov == null:
				continue
			main._open_overlay(ov, key)
			await _settle(12)
			if not ov.visible or ov.modulate.a < 0.5:
				# 开态自检：不可见就再等/再试一次（动画未完成或被时序吞开）
				await _settle(30)
			if not ov.visible or ov.modulate.a < 0.5:
				print("STATES_WARN retry ", key, " visible=", ov.visible, " modulate=", ov.modulate)
				main._open_overlay(ov, key)
				await _settle(20)
			print("STATES_OPEN ", key, " visible=", ov.visible, " modulate=", ov.modulate, " rect=", ov.get_global_rect())
			await _shot("main_open_" + key)
			# 地图态多看一眼弹窗（打开地图时默认有弹窗链）
			main._close_overlay(ov, key)
			await _settle(10)
		# 战斗 HUD 两态（不发真战斗，只广播信号让 HUD 组件进战斗布局）
		var sb: Node = get_node_or_null("/root/SignalBus")
		if sb != null and sb.has_signal("battle_started"):
			sb.battle_started.emit()
			await _settle(8)
			await _shot("main_battle_started")
		if sb != null and sb.has_signal("battle_ended"):
			sb.battle_ended.emit(true)
			await _settle(8)
			await _shot("main_battle_ended")
		# 结算两态（真实 create 链；先造真实战斗上下文：pending=5、5/6 已解锁）
		var mll := get_node_or_null("/root/ManagerLazyLoader")
		if mll != null:
			mll.ensure_loaded("bunker")
		var gm2 := get_node_or_null("/root/GameManager")
		var lpm2 := get_node_or_null("/root/LevelProgressManager")
		if gm2 != null:
			gm2.set("_pending_battle_level", 5)
		if lpm2 != null and lpm2.get("unlocked_levels") is Array:
			for lv in [5, 6]:
				if not (lpm2.get("unlocked_levels") as Array).has(lv):
					(lpm2.get("unlocked_levels") as Array).append(lv)
		await _settle(2)
		var mvp_script := load("res://scenes/ui/mvp_panel.gd")
		var win_panel: Control = mvp_script.create(main, true, [], 0, 1, {}, false)
		await _settle(6)
		await _shot("settlement_victory")
		win_panel.queue_free()
		await _settle(3)
		var lose_panel: Control = mvp_script.create(main, false, [], 0, 1, {}, false)
		await _settle(6)
		await _shot("settlement_defeat")
		lose_panel.queue_free()
		_unmount(main)
	# ═══ B. truck_base：全部工位真实打开 ═══
	var base: Node = _mount("res://scenes/bunker/truck_base.tscn")
	if base != null:
		await _settle(8)
		await _shot("truck_default")
		var keys: Array = (base.PANEL_SCENES as Dictionary).keys()
		keys.sort()
		keys.erase("growth")  # growth=常驻技能宿主（全屏），挪到队尾防污染后续截图
		for k in keys:
			var kid := String(k)
			_close_skill_host()
			base._open_panel(kid)
			await _settle(10)
			await _shot("truck_open_" + kid)
			var wr: Dictionary = (base._embed_wrappers as Dictionary).get(kid, {})
			var wrapper: Control = wr.get("wrapper")
			if wrapper != null:
				wrapper.visible = false
			await _settle(3)
		# growth 工位：本体=PhaseMasterSkillHost（root 级 CanvasLayer 110）
		_close_skill_host()
		base._open_panel("growth")
		await _settle(10)
		await _shot("truck_open_growth")
		_close_skill_host()
		await _settle(6)
		_unmount(base)
	# ═══ C. world_map：默认 + 关卡弹窗 ═══
	_close_skill_host()
	var wm: Node = _mount("res://scenes/world_map.tscn")
	if wm != null:
		await _settle(10)
		await _shot("worldmap_default")
		if wm.has_method("_show_level_info_popup"):
			wm.call("_show_level_info_popup", 3)
			await _settle(8)
			await _shot("worldmap_level_popup")
		_unmount(wm)
	# ═══ D. title_screen：默认 + 制作人员 ═══
	var title: Node = _mount("res://scenes/title_screen.tscn")
	if title != null:
		await _settle(10)
		await _shot("title_default")
		_press_button_by_text(title, "制 作 人 员")
		await _settle(8)
		await _shot("title_credits")
	print("STATES_PROBE_DONE")
	get_tree().quit(0)

func _mount(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[states] 加载失败 " + path)
		return null
	var inst: Node = packed.instantiate()
	# AGENTS 铁律：必须 root.add_child + current_scene 赋值——否则 PopupLayer 类
	# CanvasLayer 内容不渲染（战场 HUD 正常，极具迷惑性；本次巡检实测踩坑）
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst

func _unmount(inst: Node) -> void:
	get_tree().current_scene = null
	inst.queue_free()
	await _settle(4)

## 强关常驻相位师技能宿主（root 级 CanvasLayer 110，不随场景卸载）。
## 宿主本体是纯 Node（无 visible 属性），必须按名遍历 root 子节点找。
func _close_skill_host() -> void:
	for ch in get_tree().root.get_children():
		if String(ch.name).begins_with("PhaseMasterSkillHost"):
			if ch.has_method("close"):
				ch.call("close")
			await _settle(12)
			return

func _press_button_by_text(root: Node, text: String) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton and String((n as BaseButton).text) == text:
			(n as BaseButton).pressed.emit()
			return
		for ch in n.get_children():
			stack.push_back(ch)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + name + ".png")

func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame
