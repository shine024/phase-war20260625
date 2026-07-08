class_name MainReward
extends RefCounted
## 战后结算/奖励逻辑（从 scenes/main.gd 提取）

## 主场景引用，由 main.gd 在 _ready 中赋值
var main: Control = null

# 注：原 BattleResultDialog 已删除——v7.x 起统一走整合结算面板（mvp_panel.gd）。
# battle_result_dialog.gd/.tscn 存在自循环 preload 依赖（.gd preload .tscn，.tscn ext_resource .gd），
# 在 Godot 4.5.1 触发 "Busy" 解析错误，且已无任何运行时引用，故彻底删除。

## 战斗结束回调：清理待处理输入、停止持续渲染
func on_battle_ended_clear_pending(_player_won: bool) -> void:
	# 性能优化：战斗结束后停止持续渲染 SubViewport
	var viewport: Node = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if SignalBus:
		BattleInputState.clear_all_pending()

## 记录本局解锁的蓝图（战斗中由 SignalBus 触发）
func on_blueprint_unlocked(card_id: String) -> void:
	if not main._blueprints_unlocked_this_battle.has(card_id):
		main._blueprints_unlocked_this_battle.append(card_id)

## 显示战斗结果弹窗（整合面板：战绩 + 奖励一次展示）
func show_battle_result(player_won: bool) -> void:
	var reward_summary: Dictionary = {}
	if GameManager != null and ("last_battle_reward_summary" in GameManager):
		reward_summary = GameManager.last_battle_reward_summary
	# 统一走整合结算面板——胜利/失败、挂机/手操都用同一面板。
	# 挂机模式跳过战绩区域（is_afk=true），直接展示奖励摘要。
	var is_afk: bool = _is_afk_running()
	var MvpPanel := preload("res://scenes/ui/mvp_panel.gd")
	MvpPanel.create(main, player_won, main._blueprints_unlocked_this_battle, \
		main._phase_field_xp_before_battle, main._phase_field_level_before_battle, \
		reward_summary, is_afk)
	main._blueprints_unlocked_this_battle.clear()


## 挂机模式是否正在运行（避免在挂机结算时弹需要玩家交互的面板）
func _is_afk_running() -> bool:
	# AFKModeManager 是非 autoload，通过 main 场景的 PopupLayer/AfkOverlay 可见性判断
	if main != null:
		var afk_panel = main.get_node_or_null("PopupLayer/AFKOverlay")
		if afk_panel != null and afk_panel.visible:
			return true
	return false

## 结果确认后返回准备界面
func on_result_confirmed() -> void:
	clear_battlefield_units()
	if SignalBus:
		BattleInputState.clear_all_pending()
	if main.bottom_function_bar:
		main.bottom_function_bar.set_start_battle_text("开始战斗")
	if GameManager:
		GameManager.return_to_prep()
	# 刷新底部仪表栏
	if main.bottom_instrument_bar and main.bottom_instrument_bar.has_method("refresh"):
		main.bottom_instrument_bar.refresh()
	main._update_level_display()

## 清理战场上的所有单位节点
func clear_battlefield_units() -> void:
	var bf: Node2D = main._get_battlefield()
	if bf == null:
		return

	var pu: Node = bf.get_node_or_null("PlayerUnits")
	if pu:
		for c in pu.get_children():
			if c:
				c.queue_free()

	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu:
		for c in eu.get_children():
			if c:
				c.queue_free()

	# 清理临时节点（须保留 BattleSlotGrid，否则下一场无法部署）
	if bf.has_method("prune_transient_children"):
		bf.prune_transient_children()
