extends Node
## 背包打开态布局验证（场景模式，autoload 齐全的真实环境）
## 用法：godot --headless --rendering-driver opengl3 --path . res://tests/backpack_layout_check.tscn
##
## 断言（对应 docs/背包设计/背包打开状态示意图.html 落地）：
##   1. 打开背包：面板左右占满（min 宽 = 视口宽，实际宽 = 视口宽）
##   2. 打开背包：TopHudBar / BattleTopStatusBar / BattleLogBar / BottomFunctionBar 隐藏，
##      BottomInstrumentBar（相位仪栏）保持可见
##   3. 关闭背包：overlay 关闭，各 HUD 恢复到打开前的可见性

var _fails: Array[String] = []

func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[BACKPACK-LAYOUT] FAIL: " + msg)

func _ready() -> void:
	# 等主场景启动噪声（prune/预热）落定后再拉起被测场景
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[BACKPACK-LAYOUT] FAIL: main.tscn 加载失败")
		get_tree().quit(1)
		return
	var main = main_scene.instantiate()
	get_tree().root.add_child(main)
	# UILazyLoader 按 current_scene 找面板父节点——测试场景里须指向 main（生产环境本就如此）
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame

	var bp_overlay: Control = main.get_node_or_null("PopupLayer/BackpackOverlay")
	var panel: Control = main.get_node_or_null("PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel")
	var top_hud: Control = main.get_node_or_null("HudLayer/TopHudBar")
	var top_status: Control = main.get_node_or_null("HudLayer/BattleTopStatusBar")
	var log_bar: Control = main.get_node_or_null("HudLayer/BattleLogBar")
	var func_bar: Control = main.get_node_or_null("HudLayer/BattleBottomBar/BottomFunctionBar")
	var inst_bar: Control = main.get_node_or_null("HudLayer/BattleBottomBar/BottomInstrumentBar")
	if bp_overlay == null or inst_bar == null:
		print("[BACKPACK-LAYOUT] FAIL: 关键节点缺失 overlay=%s inst=%s" % [bp_overlay, inst_bar])
		get_tree().quit(1)
		return
	# 启动期 prune 删了静态背包面板时按懒加载同款契约手动补（正常环境 _ensure_lazy_panel 会补）
	if panel == null:
		var bp_scene: PackedScene = load("res://scenes/ui/backpack_panel.tscn")
		var center: Node = bp_overlay.get_node_or_null("BackpackVBox/CenterRow/BackpackCenter")
		if bp_scene == null or center == null:
			print("[BACKPACK-LAYOUT] FAIL: 背包面板场景/容器缺失 bp_scene=%s center=%s" % [bp_scene, center])
			get_tree().quit(1)
			return
		panel = bp_scene.instantiate()
		center.add_child(panel)
		if panel.has_signal("closed") and not panel.closed.is_connected(main._on_panel_closed.bind("backpack")):
			panel.closed.connect(main._on_panel_closed.bind("backpack"))
		await get_tree().process_frame

	# ── 记录打开前状态 ──
	var pre := {
		"top_hud": top_hud != null and top_hud.visible,
		"top_status": top_status != null and top_status.visible,
		"log_bar": log_bar != null and log_bar.visible,
		"func_bar": func_bar != null and func_bar.visible,
	}

	# ── 打开背包 ──
	main._on_backpack_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	if not bp_overlay.visible:
		_fail("背包 overlay 未打开")
	var target_w: float = bp_overlay.size.x
	if panel.custom_minimum_size.x < target_w - 1.0:
		_fail("面板 min 宽未占满视口: min=%d vs overlay=%d" % [int(panel.custom_minimum_size.x), int(target_w)])
	if panel.size.x < target_w - 1.0:
		_fail("面板实际宽度未占满: %d vs %d" % [int(panel.size.x), int(target_w)])
	if top_hud != null and top_hud.visible:
		_fail("TopHudBar 打开背包后未隐藏")
	if top_status != null and top_status.visible:
		_fail("BattleTopStatusBar 打开背包后未隐藏")
	if log_bar != null and log_bar.visible:
		_fail("BattleLogBar 打开背包后未隐藏")
	if func_bar != null and func_bar.visible:
		_fail("BottomFunctionBar 打开背包后未隐藏")
	if not inst_bar.visible:
		_fail("BottomInstrumentBar（相位仪栏）被隐藏——拖拽装配链路必须保留")

	# 无缝检查：面板底沿应贴住相位仪栏上沿（±3px 容差），中间不允许露横条
	var panel_bottom: float = panel.global_position.y + panel.size.y
	var bar_top: float = inst_bar.global_position.y
	if absf(panel_bottom - bar_top) > 3.0:
		_fail("面板与相位仪栏之间有缝隙: panel_bottom=%d vs bar_top=%d" % [int(panel_bottom), int(bar_top)])
	if panel.global_position.y < 0.0 or panel.global_position.y > 40.0:
		_fail("面板顶部位置异常: y=%d" % int(panel.global_position.y))

	# 渲染环境下截一张游戏内实况（headless 无画面，跳过）
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img: Image = main.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			var out := "res://docs/背包设计/落地验证_游戏内截图.png"
			img.save_png(out)
			print("[BACKPACK-LAYOUT] 已保存游戏内截图: ", out)

	# ── 关闭背包（面板 _on_close → closed 信号 → main._close_overlay） ──
	if panel.has_method("_on_close"):
		panel._on_close()
	else:
		main._close_overlay(bp_overlay, "backpack")
	await get_tree().process_frame
	await get_tree().process_frame

	if bp_overlay.visible:
		_fail("背包 overlay 未关闭")
	if top_hud != null and top_hud.visible != bool(pre["top_hud"]):
		_fail("TopHudBar 可见性未恢复（应=%s）" % pre["top_hud"])
	if top_status != null and top_status.visible != bool(pre["top_status"]):
		_fail("BattleTopStatusBar 可见性未恢复（应=%s）" % pre["top_status"])
	if log_bar != null and log_bar.visible != bool(pre["log_bar"]):
		_fail("BattleLogBar 可见性未恢复（应=%s）" % pre["log_bar"])
	if func_bar != null and func_bar.visible != bool(pre["func_bar"]):
		_fail("BottomFunctionBar 可见性未恢复（应=%s）" % pre["func_bar"])

	# ── 养成/功能面板全出血：growth / modification / evolution / store / quest ──
	var panel_names := {
		"growth": "GrowthPanel", "modification": "ModificationPanel",
		"evolution": "EvolutionPanel", "store": "StorePanel", "quest": "QuestPanel",
	}
	for key in panel_names.keys():
		var ov: Control = main._overlay_for_panel_key(key)
		if ov == null:
			_fail(key + " overlay 缺失")
			continue
		main._open_overlay(ov, key)
		await get_tree().process_frame
		await get_tree().process_frame
		var p: Control = ov.get_node_or_null("CenterContainer/" + String(panel_names[key]))
		if p == null:
			p = ov.find_child(String(panel_names[key]), true, false)
		if p == null:
			_fail(key + " 面板未找到")
			main._close_overlay(ov, key)
			continue
		if not ov.visible:
			_fail(key + " overlay 未打开")
		if p.custom_minimum_size.x < target_w - 1.0:
			_fail(key + " 未横向占满: min=%d vs %d" % [int(p.custom_minimum_size.x), int(target_w)])
		if p.size.x < target_w - 1.0:
			_fail(key + " 实际宽度未占满: %d vs %d" % [int(p.size.x), int(target_w)])
		var pb: float = p.global_position.y + p.size.y
		if pb < bar_top - 3.0:
			_fail(key + " 底部未贴相位仪栏（有缝）: bottom=%d vs bar_top=%d" % [int(pb), int(bar_top)])
		elif pb > bar_top + 30.0:
			_fail(key + " 底部超出相位仪栏过多: bottom=%d vs bar_top=%d" % [int(pb), int(bar_top)])
		if key == "growth" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var gimg: Image = main.get_viewport().get_texture().get_image()
			if gimg != null and not gimg.is_empty():
				gimg.save_png("res://docs/界面一致性/面板全出血_游戏内截图.png")
				print("[BACKPACK-LAYOUT] 已保存全出血面板截图")
		main._close_overlay(ov, key)
		await get_tree().process_frame
		if ov.visible:
			_fail(key + " overlay 未关闭")

	# ── 相位师技能树（growth 面板内部打开，独立 CanvasLayer） ──
	var growth_panel: Control = main.get_node_or_null("PopupLayer/GrowthOverlay/CenterContainer/GrowthPanel")
	if growth_panel == null:
		growth_panel = main.get_node_or_null("PopupLayer/GrowthOverlay/CenterContainer").find_child("GrowthPanel", true, false)
	if growth_panel != null and growth_panel.has_method("_open_phase_master_skill_panel"):
		main._open_overlay(main._overlay_for_panel_key("growth"), "growth")
		await get_tree().process_frame
		growth_panel._open_phase_master_skill_panel()
		await get_tree().process_frame
		var skill_panel: Control = get_tree().root.get_node_or_null("PhaseMasterSkillCanvas/PhaseMasterSkillPanel")
		if skill_panel == null or not skill_panel.visible:
			_fail("技能树面板未打开")
		else:
			var sb: float = skill_panel.global_position.y + skill_panel.size.y
			if absf(sb - bar_top) > 6.0:
				_fail("技能树底部未贴相位仪栏: bottom=%d vs bar_top=%d" % [int(sb), int(bar_top)])
			if skill_panel.size.x < target_w - 1.0:
				_fail("技能树未横向占满: %d vs %d" % [int(skill_panel.size.x), int(target_w)])
		growth_panel._close_phase_master_skill_panel()
		main._close_overlay(main._overlay_for_panel_key("growth"), "growth")
		await get_tree().process_frame
	else:
		_fail("GrowthPanel 缺失，技能树断言跳过失败")

	if _fails.is_empty():
		print("[BACKPACK-LAYOUT] ALL PASS（打开占满=%d px，HUD 隐藏/恢复一致）" % int(panel.size.x))
	get_tree().quit(0 if _fails.is_empty() else 1)
