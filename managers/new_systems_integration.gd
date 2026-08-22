extends Node
## 新系统集成脚本：自动连接所有新系统信号

const _ScreenShake = preload("res://scenes/effects/screen_shake.gd")
const _DefaultCards = preload("res://data/default_cards.gd")

func _ready() -> void:
	await get_tree().process_frame
	_connect_signals()

func _connect_signals() -> void:
	if not SignalBus:
		return
	# T1 性能优化：移除 unit_damaged 空监听（v8.1 暴击震动迁移 BattleManager 后函数体为 pass，
	# 但每次命中仍被派发一次纯空调用，密集交火时白白占用信号派发）
	if SignalBus.has_signal("unit_died") and not SignalBus.unit_died.is_connected(_on_unit_died):
		SignalBus.unit_died.connect(_on_unit_died)
	if SignalBus.has_signal("battle_ended"):
		if not SignalBus.battle_ended.is_connected(_on_battle_ended_daily):
			SignalBus.battle_ended.connect(_on_battle_ended_daily)
		if not SignalBus.battle_ended.is_connected(_on_battle_ended_achievement):
			SignalBus.battle_ended.connect(_on_battle_ended_achievement)
	if not SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack):
		SignalBus.card_added_to_backpack.connect(_on_card_added_to_backpack)
	# v7.x 修复 B5：连接强化完成信号（CardEnhancementManager 是 lazy-load，延迟连接）
	_connect_enhancement_signal()

## v7.x: 延迟连接 CardEnhancementManager.enhancement_completed（lazy-load 安全）
func _connect_enhancement_signal() -> void:
	var cem = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		# lazy-load 未就绪，下一帧重试
		call_deferred("_connect_enhancement_signal_retry")
		return
	if cem.has_signal("enhancement_completed") and not cem.enhancement_completed.is_connected(_on_enhancement_completed):
		cem.enhancement_completed.connect(_on_enhancement_completed)

func _connect_enhancement_signal_retry() -> void:
	# 给 lazy-loader 多一点时间，仍失败则放弃（强化任务推进降级，不崩）
	await get_tree().create_timer(2.0).timeout
	_connect_enhancement_signal()

## P0 性能优化：退出时断开所有信号连接，防止场景切换后连接累积
func _exit_tree() -> void:
	if not SignalBus:
		return
	if SignalBus.has_signal("unit_died") and SignalBus.unit_died.is_connected(_on_unit_died):
		SignalBus.unit_died.disconnect(_on_unit_died)
	if SignalBus.has_signal("battle_ended"):
		if SignalBus.battle_ended.is_connected(_on_battle_ended_daily):
			SignalBus.battle_ended.disconnect(_on_battle_ended_daily)
		if SignalBus.battle_ended.is_connected(_on_battle_ended_achievement):
			SignalBus.battle_ended.disconnect(_on_battle_ended_achievement)
	if SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack):
		SignalBus.card_added_to_backpack.disconnect(_on_card_added_to_backpack)
	var cem = get_node_or_null("/root/CardEnhancementManager")
	if cem != null and cem.has_signal("enhancement_completed") and cem.enhancement_completed.is_connected(_on_enhancement_completed):
		cem.enhancement_completed.disconnect(_on_enhancement_completed)

## 单位受伤 → 暴击屏幕震动：v8.1 已迁移到 BattleManager._on_unit_damaged_combat_feedback
## （原实现因 meta 竞态失效属死逻辑）。T1 性能优化：连空监听一并移除，本处不再订阅 unit_damaged。
# v9.x（P2-7范围B）：_on_phase_law_cast（法则施放特效+USE_PHASE_LAWS 日常计数）已随法则系统退役移除

## 战斗胜利 → 更新日常任务
## v7.x 修复 B5：原只推进 BATTLE_VICTORY 一类，其余6类无入口 → 接取的日常任务永远完不成。
## 现在战斗结算同时推进 BATTLE_VICTORY/COMPLETE_LEVELS，并从结算数据补 EARN_XP/KILL_ENEMIES。
func _on_battle_ended_daily(player_won: bool) -> void:
	_ensure_lazy("daily_task")  # v7.x 性能：DailyTaskManager 延迟加载守卫
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm == null or not tm.has_method("update_task_progress"):
		return
	if not player_won:
		return
	# BATTLE_VICTORY
	tm.update_task_progress(DailyTaskManager.TaskType.BATTLE_VICTORY, 1)
	# COMPLETE_LEVELS（胜利即视为完成一关）
	tm.update_task_progress(DailyTaskManager.TaskType.COMPLETE_LEVELS, 1)
	# EARN_XP：从结算摘要取值（无则跳过）。注意：KILL_ENEMIES 已在 _on_unit_died 实时计数，
	# 此处不重复推进击杀任务，避免双计数。
	var data = _collect_battle_data_for_achievement()
	var xp = int(data.get("xp", 0))
	if xp > 0:
		tm.update_task_progress(DailyTaskManager.TaskType.EARN_XP, xp)

## 战斗胜利 → 记录统计并检查成就
## v7.x 修复 B2/B3：原调用了不存在的 check_achievement（has_method 恒 false 静默跳过），
## 且 record_battle_victory 等统计方法全项目无调用者 → 战斗/收集/进度类成就永远不解锁。
## 改为调用 record_battle_victory（累计胜利数 + 自动触发 _check_all_battle_achievements）。
func _on_battle_ended_achievement(player_won: bool) -> void:
	_ensure_lazy("achievement")  # v7.x 性能：AchievementManager 延迟加载守卫
	var am = get_node_or_null("/root/AchievementManager")
	if am == null or not am.has_method("record_battle_victory"):
		return
	if player_won:
		am.record_battle_victory(_collect_battle_data_for_achievement())
	else:
		if am.has_method("record_battle_defeat"):
			am.record_battle_defeat()

## v7.x: 从战场收集战斗数据（供成就统计用）。无战场数据时返回空字典（仅累计基础胜利数）。
func _collect_battle_data_for_achievement() -> Dictionary:
	var data: Dictionary = {}
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return data
	# 尝试从 GameManager 的战斗结算摘要取数据（字段名防御性 .get）
	if gm.get("last_battle_reward_summary") != null:
		var summary = gm.get("last_battle_reward_summary")
		if summary is Dictionary:
			data["kills"] = int(summary.get("kills", 0))
			data["damage_dealt"] = int(summary.get("damage_dealt", 0))
			data["battle_time"] = float(summary.get("battle_time", 999))
			if bool(summary.get("no_damage", false)):
				data["no_damage"] = true
			var pm_raw = gm.get("_current_phase_master_id")
			var pm: String = String(pm_raw) if pm_raw != null else ""
			if not pm.is_empty():
				data["defeated_master"] = pm
	return data

## 卡牌入包 → 更新收集 + 记录收集成就统计
## 2026-08-22：蓝图解锁体系移除后改接 card_added_to_backpack（掉落/购买/奖励入包全触发）。
## 收集口径 = 拥有过的卡种（base card_id 去重，见 AchievementManager.record_collection）。
func _on_card_added_to_backpack(card: CardResource) -> void:
	if card == null:
		return
	var card_id: String = String(card.card_id)
	if card_id.is_empty():
		return
	_ensure_lazy("card_collection")
	_ensure_lazy("achievement")
	_ensure_lazy("daily_task")
	var cm = get_node_or_null("/root/CardCollectionManager")
	if cm and cm.has_method("update_card_status"):
		cm.update_card_status(card_id)
	# 记录收集成就统计（rarity 直接取实例卡，取不到回退查模板）
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("record_collection"):
		var rarity: String = String(card.rarity)
		if rarity.is_empty():
			var tpl = _DefaultCards.get_card_by_id(card_id)
			rarity = String(tpl.rarity) if tpl != null else "common"
		am.record_collection(card_id, rarity)
	# v7.x 修复 B5：收集卡牌推进 COLLECT_CARDS 日常任务
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.COLLECT_CARDS, 1)

## v7.x 修复 B5：强化/改造完成 → 推进 UPGRADE_CARDS 日常任务
## enhancement_completed(success, card_id, action, message)
func _on_enhancement_completed(success: bool, _card_id: String, _action: String, _message: String) -> void:
	if not success:
		return
	_ensure_lazy("daily_task")  # v7.x 性能：DailyTaskManager 延迟加载守卫
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.UPGRADE_CARDS, 1)

## 单位死亡 → 日常任务击杀计数
## v7.x 修复 B5：敌方单位死亡时推进 KILL_ENEMIES 日常任务（实时计数，不依赖结算摘要）
## v9.x 清理：BattleFeedbackManager 从未注册（恒 null），死亡反馈委托块删除
func _on_unit_died(unit: Node, is_player_unit: bool) -> void:
	# 仅敌方单位死亡计入击杀任务（is_player 为 true 表示死者是我方）
	if is_player_unit:
		return
	_ensure_lazy("daily_task")  # v7.x 性能：DailyTaskManager 延迟加载守卫
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.KILL_ENEMIES, 1)

func _find_battlefield(node: Node) -> Node:
	if not node:
		return null
	if node.name == "Battlefield":
		return node
	for child in node.get_children():
		var result = _find_battlefield(child)
		if result:
			return result
	return null

## v7.x 性能：统一确保延迟加载的 manager 已实例化（成就/日常任务延迟化后的守卫）
func _ensure_lazy(manager_id: String) -> void:
	var _mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if _mll and _mll.has_method("ensure_loaded"):
		_mll.ensure_loaded(manager_id)
