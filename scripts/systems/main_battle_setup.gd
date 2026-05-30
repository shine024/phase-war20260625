class_name MainBattleSetup
extends RefCounted
## 战前准备/战斗启动逻辑（从 scenes/main.gd 提取）

## 主场景引用，由 main.gd 在 _ready 中赋值
var main: Control = null

## 处理开始战斗按钮点击
func on_start_battle() -> void:
	run_start_battle_sequence()

## 执行战斗开始序列
func run_start_battle_sequence() -> void:
	main._play_sfx("button")
	# 关闭所有弹出面板
	main._close_all_overlays()
	if main.bottom_function_bar:
		var phase_master_ui: bool = (
			GameManager
			and GameManager.has_method("is_phase_master_battle")
			and GameManager.is_phase_master_battle()
		)
		if phase_master_ui:
			main.bottom_function_bar.set_start_battle_text("战斗中")
		else:
			main.bottom_function_bar.set_start_battle_text("格子布阵")
	var tree := main.get_tree()
	if tree:
		tree.paused = false
		if main.bottom_function_bar:
			main.bottom_function_bar.set_pause_text("暂停")
	show_battle()
	var battlefield: Node2D = main._get_battlefield()
	if not battlefield:
		if main.bottom_function_bar:
			main.bottom_function_bar.set_start_battle_text("开始战斗")
		return
	var plm: Node = main.get_node_or_null("/root/PhaseLawManager")
	var actives: Array = []
	if plm and "equipped_active_laws" in plm:
		actives = plm.equipped_active_laws
	main._blueprints_unlocked_this_battle.clear()
	var pim: Node = PhaseInstrumentManager
	if pim and pim.has_method("get_phase_field_xp_progress"):
		var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
		main._phase_field_xp_before_battle = int(phase_prog.get("xp", 0))
		main._phase_field_level_before_battle = int(phase_prog.get("level", 1))
	if GameManager:
		GameManager.set_battle_scene(battlefield)
		main.call_deferred("_deferred_go_to_battle")

## 延迟进入战斗（由 call_deferred 调用）
func deferred_go_to_battle() -> void:
	if GameManager:
		GameManager.go_to_battle()

## 显示战场、清理上一场残留
func show_battle() -> void:
	if main.battle_container:
		main.battle_container.visible = true
	# 性能优化：只在战斗时持续渲染 SubViewport
	var viewport: Node = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var battlefield: Node2D = main._get_battlefield()
	if battlefield:
		if battlefield.has_method("ensure_phase_driver"):
			battlefield.ensure_phase_driver()
		var pu: Node = battlefield.get_node_or_null("PlayerUnits")
		var eu: Node = battlefield.get_node_or_null("EnemyUnits")
		if pu:
			for c in pu.get_children():
				c.queue_free()
		if eu:
			for c in eu.get_children():
				c.queue_free()
		var enemy_driver: Node = battlefield.get_node_or_null("EnemyPhaseFieldDriver")
		if enemy_driver != null and is_instance_valid(enemy_driver):
			if enemy_driver.has_method("stop_production"):
				enemy_driver.stop_production()
			enemy_driver.queue_free()
